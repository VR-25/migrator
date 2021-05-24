#!/system/bin/sh
# Migrator
# A Backup Solution and Data Migration Utility for Android
# Copyright 2018-2020, VR25
# License: GPLv3+


echo
set -u
umask 0077


ssaid=false
log=/dev/migrator.log
tmp=/dev/migrator.tmp
bkp_dir=/data/migrator/local
data_dir=/sdcard/Download/migrator
packages=/data/system/packages.
version="v2020.9.24-beta (202009240)"
ssaid_xml_tmp=/dev/.settings_ssaid.xml.tmp
settings=/data/system/users/0/settings_
ssaid_xml=${settings}ssaid.xml
ssaid_boot_script=${bkp_dir%/*}/enable-ssaid-apps.sh

sysdata="/data/system_?e/0/accounts_?e.db*
/data/system/sync/accounts.xml
/data/misc/adb/adb*_keys*
/data/misc/bluedroid/bt_config.*
/data/misc/wifi/WifiConfigStore.xml
/data/misc/wifi/softap.conf
/data/system/xlua/xlua.db*
/data/system/users/0/photo.png
/data/system/users/0/wallpaper*
/data/user*/0/com.android.*provider*/databases/*.db*
/data/system/deviceidle.xml"


get_apk_dir() {
  grep " name=\"$1\" codePath=" ${packages}xml \
    | awk '{print $3}' \
    | sed -e 's/codePath=\"//' -e s/\"//
}


mv_bkps() {
  t -d /data/media/0/.migrator || {
    mv ${bkp_dir%/*} /data/media/0/.migrator 2>/dev/null \
      || mv ${bkp_dir%/*} /data/media/.migrator
  }
}


parse_params() {
  regex=..
  compressor=-
  dir=$data_dir/exported
  while t -n "${1-}"; do
    case "$1" in
      -d)
        dir="$2"
        shift 2
      ;;
      -c)
        compressor="$2"
        shift 2
      ;;
      -v)
        regex="$1 \"$(echo "$2" | sed 's/\,/\|/g')\""
        shift 2
      ;;
      *)
        regex="$(echo "$1" | sed 's/\,/\|/g')"
        shift
      ;;
    esac
  done
}


# test
t() { test "$@"; }


# extended test
tt() {
  eval "case \"$1\" in
    $2) return 0;;
  esac"
  return 1
}


# verbose
tt "${1-}" "-B|-L" || {
  touch $log
  t $(du -m $log | cut -f1) -ge 2 && date > $log || date >> $log
  echo "$version" >> $log
  set -x >> $log 2>&1
}


# prepare busybox and extra executables

bin_dir=/data/adb/bin
busybox_dir=/dev/.busybox
magisk_busybox=/data/adb/magisk/busybox

[ -x $busybox_dir/ls ] || {
  mkdir -p $busybox_dir
  chmod 0700 $busybox_dir
  if [ -f $bin_dir/busybox ]; then
    [ -x $bin_dir/busybox ] || chmod -R 0700 $bin_dir
    $bin_dir/busybox --install -s $busybox_dir
  elif [ -f $magisk_busybox ]; then
    [ -x $magisk_busybox ] || chmod 0700 $magisk_busybox
    $magisk_busybox --install -s $busybox_dir
  elif which busybox > /dev/null; then
    eval "$(which busybox) --install -s $busybox_dir"
  else
    echo "(!) Install busybox or simply place it in $bin_dir/"
    exit 3
  fi
}

export PATH="$bin_dir:$busybox_dir:/data/adb/modules_update/migrator/bin:/data/adb/modules/migrator/bin:$PATH"
unset bin_dir busybox_dir magisk_busybox


param1=${1-}
t -n "$param1" && shift


# set up recovery environment
recovery_mode=false
pgrep -f zygote > /dev/null || {
  set +x
  clear
  recovery_mode=true
  trap 'exit_code=$?; set +x; rm ${tmp}* 2>/dev/null; echo; exit $exit_code' EXIT
  tt "$param1" "-[Brs]*" && {
    echo "This option is not meant for recovery environments"
    exit 1
  }
}


$recovery_mode || {
  # temporarily disable SELinux
  sestatus=$(getenforce || exit)
  setenforce 0 || exit
  exxit() {
    local exit_code=$?
    t .$sestatus = .Enforcing && setenforce 1
    set +x
    $ssaid && {
      printf "Reboot $(t -f /data/adb/modules/migrator/service.sh \
        || echo "& run \"${0##*/} -s\" ")"
      printf "to enable apps with Settings.Secure.ANDROID_ID (SSAID)\n"
    }
    rm /data/.__hltest /dev/._split ${tmp}* 2>/dev/null
    echo
    exit $exit_code
  }
  trap exxit EXIT
}


tt "$param1" "-[br]|-[br]*[bMn]*" && both=true || both=false


if t -n "${p-}"; then
  p_="$p"
  encryption=true
  which ccrypt > /dev/null || {
    echo "ccrypt not found"
    exit 1
  }
else
  encryption=false
fi


: > $tmp


# move the backup directory back to where it belongs
! tt "$param1" "-m" && ! t -d /data/migrator && {
  mv /data/media/0/.migrator /data/migrator \
    || mv /data/media/.migrator /data/migrator
} 2>/dev/null


case "$param1" in

  -b*) # backup

    echo "Backing up"

    extras="$(echo "$*" | grep -o '\+.*' | sed 's/\+ //')"
    set -- $(echo "$@" | sed 's/\+.*//')
    tt "$*" "*-v*" && v=v || v=

    regex="$(echo "$*" | sed -E 's/ |-v//g' | sed 's/\,/\|/g')"

    no_list=false

    if tt "$regex" "/*"; then
      set -e
      grep -Ev '^#|^$' $regex | dos2unix > $tmp
      set +e
    elif tt "$regex" "--"; then
      set -e
      grep -Ev '^#|^$' $data_dir/packages.list | dos2unix > $tmp
      set +e
    else
      no_list=true
      if $recovery_mode; then
        grep 'name=.*codePath="/data/app/' ${packages}xml \
          | grep -v com.offsec.nhterm \
          | grep -E$v "${regex:-..}" \
          | awk '{print $2}' | tr -d \" \
          | sed 's/^name=//' > $tmp
      else
        pm list packages -3 \
          | sed 's/^package://' \
          | grep -v com.offsec.nhterm \
          | grep -E$v "${regex:-..}" > $tmp
      fi
    fi

    $no_list || {
      # parse regex and generate full package names
      (set +x
      cut -d ' ' -f 1 ${packages}list > ${tmp}1
      : > ${tmp}2
      while IFS= read -r l; do
       grep -E "$l" ${tmp}1 >> ${tmp}2
      done < $tmp
      mv -f ${tmp}2 $tmp)
    }

    unset regex
    mkdir -p $bkp_dir

    t -f /data/system/users/0/runtime-permissions.xml \
      && bkp_runtime_perms=true \
      || bkp_runtime_perms=false

    t -n "$extras" && {
      if tt "$extras" "*/*"; then
        grep -Ev '^#|^$' $extras | dos2unix >> $tmp
        echo >> $tmp
      else
        echo "$extras" | sed 's/ /\n/g' >> $tmp
      fi
    }

    sort -u $tmp | sed -e 's/ //g' -e '/^$/d' > ${tmp}1 \
      && mv -f ${tmp}1 $tmp

    t -n "$extras" && {
      # filter out unistalled packages
      (set +x
      while IFS= read -r l; do
        grep -q "^$l " ${packages}list || sed -i "/^$l$/d" $tmp
      done < $tmp)
    }

    tt "$param1" "-b*n*" && {
      # exclude already backed up
      while IFS= read -r l; do
        tt "$l" "*[a-z]*" || continue
        t -d $bkp_dir/$l && sed -i "/^$l$/d" $tmp
      done < $tmp
    }

    checked=false

    while IFS= read -r pkg; do

      tt "$pkg" "*[a-z]*" || continue

      $checked || {
        checked=true
        { $both || tt "$param1" "-b*[ade]*"; } || break
      }

      mkdir -p $bkp_dir/$pkg

      # backup app
      app=false
      if $both || tt "$param1" "-b*[ae]*"; then
        rm $bkp_dir/$pkg/*.apk
        ln $(get_apk_dir $pkg)/*.apk $bkp_dir/$pkg/ && {
          app=true
          printf "  $pkg\n    App\n"
        }
      fi 2>/dev/null

      # backup data
      if $both || tt "$param1" "-b*[de]*"; then
        $app && echo "    Data" || printf "  $pkg\n    Data\n"
        killall -STOP $pkg > /dev/null 2>&1
        rm -rf $bkp_dir/$pkg/$pkg $bkp_dir/$pkg/${pkg}_de $bkp_dir/$pkg/${pkg}_media 2>/dev/null
        mkdir $bkp_dir/$pkg/$pkg $bkp_dir/$pkg/${pkg}_de $bkp_dir/$pkg/${pkg}_media
        : > $bkp_dir/$pkg/modes.txt
        for e in /data/data/${pkg}::$pkg /data/user_de/0/${pkg}::${pkg}_de /data/media/0/Android/data/${pkg}::${pkg}_media; do
          echo $e
          ls -1d ${e%::*}/* ${e%::*}/.* 2>/dev/null \
            | grep -Ev '/\.$|/\.\.$|/app_optimized|/app_tmp|/cache$|/code_cache$|/dex$|/lib$|oat$' | \
            while IFS= read -r i; do
              t -z "$i" && continue
              cp -dlR "$i" $bkp_dir/$pkg/${e#*::}/
              find "$i" -print0 2>/dev/null | xargs -0 -n 10 stat -c "%a %n" \
                >> $bkp_dir/$pkg/modes.txt
            done
        done

        # backup SSAID
        grep -q $pkg $ssaid_xml 2>/dev/null \
          && grep $pkg $ssaid_xml > $bkp_dir/$pkg/ssaid.txt

        # ensure restored $pkg can use Google Clould Messaging
        rm -f $bkp_dir/$pkg/${pkg}*/shared_prefs/com.google.android.gms.appid.xml 2>/dev/null
      fi

      # backup runtime permissions
      $bkp_runtime_perms && {
        sed -n "/$pkg/,/\<\//p" /data/system/users/0/runtime-permissions.xml \
          | grep 'granted=\"true\"' \
          | grep -o 'android.permission.*[A-Z]' > $bkp_dir/$pkg/runtime-perms.txt
      }
      killall -CONT $pkg > /dev/null 2>&1

    done < $tmp

    # backup migrator itself
    cp $(readlink -f "$0") $bkp_dir/migrator.sh

    # backup Android settings
    if tt "$param1" "-b*[es]*"; then
      echo "  Generic Android settings"
      rm -rf $bkp_dir/_settings 2>/dev/null
      mkdir $bkp_dir/_settings
      if $recovery_mode; then
        for i in global secure system; do
          awk '{print $3,$4}' ${settings}$i.xml | tr -d \" \
            | sed -e s/name=// -e 's/ value//' -e '/^$/d' -e '/ standalone=/d' -e '/^ /d' > $bkp_dir/_settings/$i.txt
        done
        cp -l /data/user_de/0/org.cyanogenmod.cmsettings/databases/cmsettings.db \
          /data/user_de/0/org.lineageos.lineagesettings/databases/lineagesettings.db \
          $bkp_dir/_settings/ 2>/dev/null
      else
        for i in global secure system; do
          settings list $i > $bkp_dir/_settings/$i.txt
        done
        # CM/Lineage-specific settings
        if t -f /data/user_de/0/org.cyanogenmod.cmsettings/databases/cmsettings.db \
          || t -f /data/user_de/0/org.lineageos.lineagesettings/databases/lineagesettings.db
        then
          t -f /data/user_de/0/org.lineageos.lineagesettings/databases/lineagesettings.db \
            && flag="-lineage" \
            || flag="-cm"
          rm -rf $bkp_dir/_settings-* 2>/dev/null
          mkdir $bkp_dir/_settings$flag
          for i in global secure system; do
            settings -$flag list $i > $bkp_dir/_settings$flag/$i.txt 2>/dev/null || {
              rm -rf $bkp_dir/_settings$flag
              break
            }
          done
        fi
      fi
    fi

    # backup system data
    if tt "$param1" "-b*[De]*"; then
      echo "  System data"
      rm -rf $bkp_dir/_sysdata 2>/dev/null
      mkdir $bkp_dir/_sysdata
      echo "$sysdata" > $tmp
      while IFS= read -r l; do
        for i in $l; do
          cp $i $bkp_dir/_sysdata/ 2>/dev/null || continue
          echo "[ -f $i ] && cat $bkp_dir/_sysdata/${i##*/} > $i" >> $bkp_dir/_sysdata/restore.sh
        done
      done < $tmp
    fi

    # backup magisk data
    if tt "$param1" "-b*[em]*"; then
      echo "  Magisk data"
      rm -rf $bkp_dir/_magisk; 2>/dev/null
      mkdir $bkp_dir/_magisk
      ls -1d /data/adb/* /data/adb/.* 2>/dev/null | grep -Ev '/\.$|/\.\.$|/magisk$' | \
        while IFS= read -r i; do
          cp -dlR "$i" $bkp_dir/_magisk/
          find "$i" -print0 2>/dev/null | xargs -0 -n 10 stat -c "chown %U:%G %n; chmod %a %n" \
            >> $bkp_dir/_magisk/restore-attributes.sh
          find "$i" -print0 2>/dev/null | xargs -0 -n 10 ls -1dZ 2>/dev/null | sed 's/^/chcon /' \
            >> $bkp_dir/_magisk/restore-attributes.sh
        done
    fi

    # remove backups of uninstalled packages
    set +x
    ls -1 $bkp_dir 2>/dev/null \
      | grep -Ev '^_magisk$|^migrator.sh$|^_settings|^_sysdata$' | \
      while IFS= read -r pkg; do
        grep -q "^$pkg " ${packages}list || rm -rf $bkp_dir/$pkg
      done

    # make hard link backups immune to factory resets
    tt "$param1" "*M*" && mv_bkps
  ;;


# enable apps with Settings.Secure.ANDROID_ID (SSAID) and start automatic backups (if enabled)
  -B|-s)

    t $param1 = -B && ssaid_only=false || ssaid_only=true

    until t -d /sdcard/Download \
      && t .$(getprop sys.boot_completed 2>/dev/null) = .1 \
      && pm list packages -s > /dev/null 2>&1
    do
      sleep 15
    done

    t -f $ssaid_boot_script && {
      . $ssaid_boot_script
      rm $ssaid_boot_script
    }

    $ssaid_only && exit 0

    cmd="${0##*/} -be && ${0##*/} -e" # Commands to run
    freq=24 # Every 24 hours
    delay=60 # Starting 60 minutes after boot
    config=/data/migrator.conf

    t -f $config && {
      dos2unix $config
      . $config
      sleep $(( $delay * 60 ))
      while :; do
        eval "$cmd"
        sleep $(( $freq * 60 * 60 ))
        dos2unix $config && . $config || exit
        set +x
      done
    }
  ;;


  -d) # delete
    tt "$*" "*/*" || {
      l="$(cd $bkp_dir && { ls -1dp $* | sed 's/^/  /' | sort -u | grep -v '\./'; })"
      t -n "$l" && printf "Removing\n$l\n" || echo "No matches"
      cd $bkp_dir && eval rm -rf "$@"
    } 2>/dev/null
  ;;


  -e*) # export

    cd $bkp_dir || exit

    case $param1 in
      -*e*i*) # interactive mode
        clear
        echo
        ls -1 | grep -v '^migrator.sh$'
        echo
        echo '[regex (default: "..") | -v regex] [-d <base directory, default (full): $data_dir/exported>] [-c <"compression method" | "-" (none, default)>]'
        echo
        printf ": "
        read params
        eval parse_params $params
      ;;
      *)
        parse_params "$@"
      ;;
    esac

    case "$compressor" in
      bzip2*) extension=.tar.bz2;;
      gzip*|pigz*) extension=.tar.gz;;
      lzop*) extension=.tar.lzo;;
      xz*) extension=.tar.xz;;
      zip*) extension=.tar.zip;;
      zstd*) extension=.tar.zst;;
      *) extension=.tar.${compressor%% *};;
    esac

    t $dir = $data_dir/exported || dir=$dir/migrator_exported
    mkdir -p $dir
    echo "Exporting"

    # workaround for Termux backup size issue
    rm -rf com.termux/com.termux/files/home/storage/ 2>/dev/null

    ls -1 | grep -v '^migrator.sh$' | grep -E "$regex" | \
      while IFS= read -r bkp; do
        echo "  $bkp"
        rm $dir/${bkp}.tar* 2>/dev/null
        if t "$compressor" != -; then
          if $encryption; then
            tar -c $bkp | $compressor | ccrypt -E p > $dir/${bkp}${extension}.cpt
            export p="$p_"
          else
            tar -c $bkp | $compressor > $dir/${bkp}$extension
          fi
        else
          if $encryption; then
            tar -c $bkp | ccrypt -E p > $dir/${bkp}.tar.cpt
            export p="$p_"
          else
            tar -cf $dir/${bkp}.tar $bkp
          fi
        fi
      done

    cp $(readlink -f "$0") $dir/migrator.sh

    # remove backups of uninstalled packages
    set +x
    ls -1 $dir 2>/dev/null \
      | grep -Ev '^_magisk\.|^migrator.sh$|^_settings.*\.|^_sysdata\.' | \
        while IFS= read -r bkp; do
          t -d $bkp_dir/${bkp%.tar*} || rm $dir/$bkp
        done
  ;;


  -i*) # import

    mkdir -p $bkp_dir
    parse_params "$@"
    cd $dir || exit

    tt "$param1" "-*i*i*" && { # interactive mode
      clear
      echo
      ls -1 | grep -v '^migrator.sh$'
      echo
      echo '[regex (default: "..") | -v regex] [-c <"compression method" | "-" (none, default)>]'
      echo
      printf ": "
      read params
      eval parse_params $params
    }

    decrypt() {
      if $encryption; then
        ccrypt -dcE p $bkp | $@
        export p="$p_"
      else
        $@ $bkp
      fi
    }

    echo "Importing"
    ls -1 | grep -v '^migrator.sh$' | grep -E "$regex" | \
      while IFS= read -r bkp; do
        tt "$bkp" "*[a-z]*" || continue
        echo "  ${bkp%.tar*}"
        rm -f $bkp_dir /${bkp%.tar*} 2>/dev/null
        case ${bkp##*.tar.} in
          bz2*|bzip2*) decrypt bzip2 -cd | tar -xf - -C $bkp_dir ;;
          gz*|pigz*) decrypt gzip -cd | tar -xf - -C $bkp_dir ;;
          lzo*) decrypt lzop -cd $bkp | tar -xf - -C $bkp_dir ;;
          xz*|lzma*) decrypt xz -cd | tar -xf - -C $bkp_dir ;;
          zip*) decrypt unzip -p | tar -xf - -C $bkp_dir ;;
          zst*) decrypt zstd -cd | tar -xf - -C $bkp_dir ;;
          *.tar|cpt)
            if $encryption; then
              ccrypt -dcE p $bkp | tar -xf - -C $bkp_dir
              export p="$p_"
            else
              tar -xf $bkp -C $bkp_dir
            fi
          ;;
          *) decrypt $compressor | tar -xf - -C $bkp_dir;;
        esac
      done
    cp -f migrator.sh $bkp_dir/
  ;;


  -l) # list
    regex="$(echo "$*" | sed 's/\,/\|/g')"
    list_bkps() {
      echo $1/
      ls -1 $1 2>/dev/null | sed -En -e '/^migrator.sh/d' -e "/${regex:-..}/p" | \
        while IFS= read -r i; do
          t -n "$i" || continue
          printf "  $i"
          tt "$i" "_*" && echo || {
            grep -q "$i " ${packages}list && echo " (installed)" || echo
          }
          if t -f $1/$i/base.apk; then
            if ls -d $1/$i/$i/* > /dev/null 2>&1; then
              echo "    App and data"
            else
              echo "    App only"
            fi
          else
            echo "    Data only"
          fi
        done
    }
    list_bkps $bkp_dir
  ;;


  -L) # export (L)ogs
    mkdir -p $data_dir
    bzip2 -9 < $log > $data_dir/${log##*/}.bz2 \
      && echo "$data_dir/${log##*/}.bz2"
  ;;


  -m) # make hard link backups immune to factory resets
    mv_bkps
  ;;


  -n) # fix push notifications
    rm /data/data/*/shared_prefs/com.google.android.gms.appid.xml 2>/dev/null
  ;;


  -r*) # restore

    echo "Restoring"

    tt "$*" "*-v*" && v=v || v=

    regex="$(echo "$*" | sed -E 's/ |-v//g' | sed 's/\,/\|/g')"

    ls -d $bkp_dir/* > /dev/null && cd $bkp_dir || exit

    params="$@"

    if $both || tt "$param1" "-r*[ade]*"; then

      # set the stage for SSAIDs restore
      if grep -q '^com.google.android.gms ' ${packages}list \
        && t -f $ssaid_xml && ls */ssaid.txt > /dev/null 2>&1
      then
        no_ssaid=false
        id=$(grep -Eo 'id=.*name=' $ssaid_xml | grep -Eo '[0-9]+' | sort -n | tail -n 1)
        grep -v '</settings>' $ssaid_xml > $ssaid_xml_tmp
      else
        no_ssaid=true
      fi


      # enable "unknown sources" and disable package verification
      if $both || tt "$param1" "-r*[ae]*"; then
        settings put secure install_non_market_apps 1
        settings put global verifier_verify_adb_installs 0
        settings put global package_verifier_enable 0
      fi


      ls -1 $bkp_dir 2>/dev/null \
        | grep -Ev '^_magisk$|^migrator.sh$|^_settings|^_sysdata$' \
        | grep -E$v "${regex:-..}" > $tmp

      tt "$param1" "-r*n*" && {
        # exclude installed apps
        while IFS= read -r i; do
          tt "$i" "*[a-z]*" || continue
          grep -q "$i " ${packages}list && sed -i "/^$i$/d" $tmp
        done < $tmp
      }

      touch /data/.__hltest

      while IFS= read -r pkg; do

        tt "$pkg" "*[a-z]*" || continue

        # restore app
        app=false
        if t -f $pkg/base.apk && \
          { $both || tt "$param1" "-r*[ae]*"; }
        then
          app=true
          printf "  $pkg\n    App\n"
          # base APK
          pm install -r  -i com.android.vending $pkg/base.apk > /dev/null && {
            rm $pkg/base.apk
            ln $(get_apk_dir $pkg)/base.apk $pkg/
            # split APKs
            ls $pkg/split_*.apk > /dev/null 2>&1 && {
              for pkg_ in $pkg/split_*.apk; do
                pm install -r -i com.android.vending -p $pkg $pkg_ > /dev/null && {
                  rm $pkg_
                  ln $(get_apk_dir $pkg)/${pkg_##*/} $pkg/
                }
              done
            }
          }
        fi

        { t -d /data/data/$pkg && \
          { ls -d $pkg/$pkg/* > /dev/null 2>&1 \
            || ls -d $pkg/${pkg}_de/* > /dev/null 2>&1; }
        } || continue

        if $both || tt "$param1" "-r*[de]*"; then
          $app && echo "    Data" || printf "  $pkg\n    Data\n"
          killall $pkg > /dev/null 2>&1
          # restore Settings.Secure.ANDROID_ID (SSAID)
          ! $no_ssaid && t -f $ssaid_xml && t -f $pkg/ssaid.txt && {
            ssaid=true
            killall $pkg > /dev/null 2>&1
            pm suspend $pkg > /dev/null 2>&1 || pm disable $pkg > /dev/null
            grep -q " $pkg " $ssaid_boot_script 2>/dev/null \
              || echo "pm unsuspend $pkg 2>/dev/null || pm enable $pkg" >> $ssaid_boot_script
            set -- $(cat $pkg/ssaid.txt)
            id=$(( id + 1 ))
            f2="id=\"$id\""
            f3="name=\"$(stat -c %u /data/data/$pkg)\""
            sed -i "/\"$pkg\"/d" $ssaid_xml_tmp
            echo "${@}" | sed 's/^/  /' | sed -e "s/$2/$f2/" -e "s/$3/$f3/" >> $ssaid_xml_tmp
          }

          # restore data
          ls -d $pkg/${pkg}_de/* > /dev/null 2>&1 \
            && de=/data/user_de/0/${pkg}::${pkg}_de || de=
          for i in /data/data/${pkg}::$pkg $de; do
            lib_dir=$(readlink ${i%::*}/lib)
            set -- $(stat -c "%u:%g %a" ${i%::*})
            rm -rf ${i%::*} 2>/dev/null
            if ln /data/.__hltest ${i%::*} 2>/dev/null; then
              rm ${i%::*}
              cp -dlR $pkg/${i#*::} ${i%::*}
            else
              cp -dR $pkg/${i#*::} ${i%::*} && {
                rm -rf $pkg/${i#*::}
                cp -dlR ${i%::*} $pkg/${i#*::}
              }
            fi
            t -n "$lib_dir" && ln -sf $lib_dir ${i%::*}/lib
            # restore attributes
            chown -R $1 ${i%::*}
            chmod $2 ${i%::*}
          done
          rm -rf /dev/._split 2>/dev/null
          mkdir /dev/._split
          sed 's/^/chmod /' $pkg/modes.txt | split -l 1000 - /dev/._split/
          ls  -1 /dev/._split | while IFS= read -r f; do
            t -f /dev/._split/$f && .  /dev/._split/$f 2>/dev/null
          done
          /system/bin/restorecon -R /data/data/$pkg > /dev/null 2>&1
          /system/bin/restorecon -R /data/user*/0/$pkg > /dev/null 2>&1
        fi

        # restore runtime permissions
        for perm in $(cat $pkg/runtime-perms.txt); do
          pm grant $pkg $perm 2>/dev/null
        done
      done < $tmp
    fi

    # commit changes to $ssaid_xml
    $ssaid && {
      echo "</settings>" >> $ssaid_xml_tmp
      cat $ssaid_xml_tmp > $ssaid_xml
    }

    # restore Android settings
    if t -d $bkp_dir/_settings \
      && { tt "$param1" "-r*[es]*"; }
    then
      echo "  Generic Android Settings"
      for path in $bkp_dir/_settings*; do
        t -d $path || break
        flag=
        if t $path = $bkp_dir/_settings-cm \
          && t -f /data/user_de/0/org.cyanogenmod.cmsettings/databases/cmsettings.db
        then
          flag="--cm"
        elif t $path = $bkp_dir/_settings-lineage \
          && t -f /data/user_de/0/org.cyanogenmod.cmsettings/databases/cmsettings.db
        then
          flag="--lineage"
        fi
        for namespace in global secure system; do
          t -f $path/${namespace}.txt || continue
          settings $flag list $namespace > $tmp 2>/dev/null || continue
          grep -q '\$' $path/${namespace}.txt \
            && sed -i 's/\$/\\$/g' $path/${namespace}.txt
          while IFS= read -r setting; do
            tt "$setting" "*[a-z]*" || continue
            grep -q "^${setting%%=*}" $tmp && {
              echo "    ${setting%%=*}=${setting#*=}"
              settings $flag put ${namespace} "${setting%%=*}" "${setting#*=}"
            }
          done < $path/${namespace}.txt
        done
      done
    fi

    # restore system data
    if t -f $bkp_dir/_sysdata/restore.sh && tt "$param1" "-r*D*"; then
      echo "  System Data"
      grep -q '^eu.faircode.xlua ' ${packages}list \
        && mkdir /data/system/xlua 2>/dev/null && {
          chown 1000:1000 /data/system/xlua
          chmod 0770 /data/system/xlua
        }
      . $bkp_dir/_sysdata/restore.sh > /dev/null 2>&1
    fi

    # restore magisk data
    if t -d $bkp_dir/_magisk \
      && { tt "$param1" "-r*[em]*"; }
    then
      echo "  Magisk Data"
      ls -1d $bkp_dir/_magisk/* $bkp_dir/_magisk/.* | grep -Ev '/\.$|/\.\.$|/restore-attributes.sh$' | \
        while IFS= read -r i; do
          rm -rf "/data/adb/${i##*/}"
          cp -dlR "$i" /data/adb/
        done 2>/dev/null
      rm -rf /dev/._split 2>/dev/null
      mkdir /dev/._split
      split -l 1000 $bkp_dir/_magisk/restore-attributes.sh /dev/._split/
      for f in /dev/._split/*; do
        . $f 2>/dev/null
      done
    fi 2>/dev/null
  ;;


  wip) ### wizard

    exit 0

    select_() {

      local item=""
      local list=""
      local n=""
      local _var_="$1"

      shift
      [ $# -gt 9 ] || n="-n 1"

      for item in "$@"; do
        list="$(printf "$list\n$item")"
      done

      list="$(echo "$list" | grep -v '^$' | nl -s ") " -w 1)"
      printf "$list\n\n${PS3:-#? }"
      read $n item
      list="$(echo "$list" | sed -n "s|^${item}. ||p")"
      list="$_var_=\"$list\""
      eval "$list"
    }

    options
      backup
        User apps
          all
          specify comma-separated regex
        Packages from a list
          default
          specify
        new
      delete
        all
        specify
      export
        all
          defaults
          dir
          compress
          encrypt
        specify
      import
        default
        dir
      log
      restore
        all
        specify
        not intalled
      help
  ;;



  *) # help text
    TMPDIR=/dev
    cd $TMPDIR
    cat <<EOF | more
Migrator $version
A Backup Solution and Data Migration Utility for Android
Copyright 2018-2020, VR25
License: GPLv3+


ZERO warranties, use at your own risk!
This is still in beta. Backup your data before using.


USAGE

${0##*/} (wizard)
${0##*/} [option...] [arg...]

[p=<"password for encryption/decryption">] ${0##*/} [option...] [arg...]

M is a migrator alias.


OPTIONS[flags]

Backup
-b[abdDemMns] [regex|-v regex] [[+ file or full pkg names] | [/path/to/list] | [-- for $data_dir/packages.list]]

Delete local backups
-d <"bkp name (wildcards supported)" ...>

Export backups
-e[i] [regex|-v regex] [-d <destination directory>] [-c <"compression method" or "-" (none, default)>]

Import backups
-i [regex|-v regex] [-d <source directory>] [-c <"decompression method" or "-" (none)>]
-ii [regex|-v regex] [-c <"decompression method" or "-" (none)>]

List backups
-l [regex|-v regex]

Export logs to $data_dir/migrator.log.bz2
-L

Make hard link backups immune to factory resets
-m

Force all apps to reregister for push notifications (Google Cloud Messaging)
-n

Restore backups
-r[abdDemns] [regex|-v regex]

Manually enable SSAID apps
-s


FLAG MNEMONICS

a: app
d: data
b: both (app and data)
D: system data
m: magisk data
M: move ${bkp_dir%/*} to internal sdcard
s: settings (global, secure and system)
e: everything (-be = -bADms, -re = -rAms)
i: interactive (-ei, -ii)
n: not backed up (-bn) or not installed (-rn)


USAGE EXAMPLES

Backup only packages not yet backed up
${0##*/} -bn

Backup Facebook Lite and Instagram (apps and data)
${0##*/} -b ook.lite,instagram

Backup all user apps and data, plus two system apps, excluding APKs outside /data/app/
${0##*/} -b + com.android.vending com.android.inputmethod.latin

Backup data (d) of pkgs in /sdcard/list.txt
${0##*/} -bd /sdcard/list.txt

Backup Magisk data (m) and generic Android settings (s)
${0##*/} -bms

Backup everything
${0##*/} -be + \$(pm list packages -s | sed 's/^package://')

Backup everything, except system apps and move ${bkp_dir%/*} to internal sdcard, so that hard link backups survive factory resets
When launched without the -m (move) option, Migrator automatically moves hard link backups back to $bkp_dir, for convenience
${0##*/} -beM

Backup all users apps' data (d)
${0##*/} -bd

Delete all backups
${0##*/} -d \\*

Delete Facebook Lite and Instagram backups
${0##*/} -d "*facebook.lite*" "*instag*"

Export all backups to $data_dir/exported/
${0##*/} -e

... To /storage/XXXX-XXXX/migrator_exported
${0##*/} -e -d /storage/XXXX-XXXX

Interactive export
${0##*/} -ei

Import all backups from $data_dir/exported
${0##*/} -i

... From /storage/XXXX-XXXX/migrator_exported
${0##*/} -i -d /storage/XXXX-XXXX/migrator_exported

Interactive import
${0##*/} -ii -d /sdcard/m

Export backup, encrypted
p="my super secret password" ${0##*/} -e instagr

Import encrypted backup
p="my super secret password" ${0##*/} -i instagr

List all backups
${0##*/} -l

List backups (filtered)
${0##*/} -l facebook.lite

Restore only app data of matched packages
${0##*/} -rd facebook.lite

Restore generic Android settings
${0##*/} -rs

Restore system data (e.g., Wi-Fi, Bluetooth)
${0##*/} -rD

Restore Magisk data (everything in /data/adb/, except magisk/)
${0##*/} -rm

Restore everything, except system data (D), which is usually incompatible)
${0##*/} -re

Restore not installed user apps+data
${0##*/} -rn


Migrator can backup/restore apps (a), respective data (d) and runtime permissions.

The order of secondary options is irrelevent (e.g., -rda = -rad, "a" and "d" are secondary options).

Everything in /data/adb/, except magisk/ is considered "Magisk data" (m).
After restoring such data, one has to launch Magisk Manager and disable/remove all modules that are or may be incompatible with the [new] ROM.

Accounts, call logs, contacts and SMS/MMS, other telephony and system data (D) restore is not fully guaranteed nor generally recommended.
These are complex databases and often found in variable locations.
You may want to export contacts to a vCard file or use a third-party app to backup/restore all telephony data.

Backups of uninstalled packages are automatically removed at the end of backup and export operations.

For greater compatibility and safety, system apps are not backed up, unless specified as "extras" (see examples).
No APK outside /data/app/ is ever backed up.
Data of specified system apps is always backed up.

Migrator itself is included in backups and exported alongside backup archives.

Backups are stored in $bkp_dir/.
These take virtually no extra storage space (hard links).

Backups can be exported as individual [compressed] archives (highly recommended).
Data is exported to $data_dir/exported/ by default - and imported to "$bkp_dir/".
The default compression method is <none> (.tar file).
Method here refers to "<program> <options>" (e.g., "zstd -1").
The decompression/extraction method to use is automatically determined based on file extension.
Supported archives are tar, tar.bz*, tar.gz*, tar.lzma, tar.lzo*, tar.pigz, tar.xz, tar.zip and tar.zst*.
The user can supply an alternate method for decompressing other archive types.
Among the supported programs, only pigz and zstd are not generally available in Android/Busybox at this point.
However, since pigz is most often used as a gzip alternative (faster), its archives can generally be extracted with "gzip -cd" as well.

The Magisk module variant installs NetHunter Terminal.
Highly recommended, it's always excluded from backups.
If you use another terminal, it MUST BE EXCLUDED manually (e.g., "migrator -bA -v termux").
This is because apps being backed up are temporarily suspended.
Before restore, they are terminated.
Thus, not excluding the app that runs migrator will lead to incomplete backup/restore.

Having a terminal ready out of the box also adds convenience.
Users don't have to install a terminal to get started, especially after migrating to another ROM.

But why "NetHunter Terminal"?
It's free and open source, VERY light and regularly updated.
The homepage is https://store.nethunter.com/en/packages/com.offsec.nhterm .
You can always compare the package signatures and/or checksums.


ENCRYPTION

Migrator uses ccrypt for encryption, but it does not ship with it.
I'm looking for suitable static ccrypt binaries to bundle.
There's a package available for Termux: "pkg install ccrypt".
Once installed, non-Magisk users have to symlink ccrypt to /data/adb/bin/: "su -c "mkdir -p /data/adb/bin; ln -sf /data/data/com/termux/files/usr/bin/ccrypt /data/adb/bin/".
Magisk users need not do anything else besides installing the ccrypt Termux package.
Alternatively (no Termux), a static ccrypt binary can be placed in /data/adb/bin/.


AUTOMATING BACKUPS

"init.d" Script (Magisk users don't need this)
#!/system/bin/sh
# This is a script that daemonizes "migrator -B" to automate backups.
/path/to/busybox start-stop-daemon -bx /path/to/migrator -S -- -B
exit 0

Config for Magisk and init.d
# /data/migrator.conf
# Default config, same as a blank file
# Note: this is not created automatically.
cmd="${0##*/} -be && ${0##*/} -e" # Commands to run
freq=24 # Every 24 hours
delay=60 # Starting 60 minutes after boot

Sample Tasker Script
#!/system/bin/sh
# /data/my-tasker-script
# su -c /data/my-tasker-script
# This requires read and execute permissions to run
(${0##*/} -be
${0##*/} -e -d /storage/XXXX-XXXX &)

Debugging
Verbose is redirected to "$log".


FULL DATA MIGRATION STEPS AND NOTES

Notes
- If you have to format data, export backups to external storage after step 1 below (-e -d /storage/XXXX-XXXX) and later import with -i -d storage/XXXX-XXXX).
- If you use a different root method, ignore Magisk-related steps.
- In "-beM", the "M" sub-option means "move hard link backups to internal sdcard, so that they survive factory resets".
  When launched without the -m (move) option (i.e., migrator -m), Migrator automatically moves hard link backups back to /data/migrator/local/, for convenience.
- Using a terminal emulator app other than NetHunter means you have to exclude it from backups/restores or detach migrator from it.

1. Backup everything, except system apps: "${0##*/} -beM".

2. Install the [new] ROM (factory reset implied), addons as desired - and root it.

3. Once Android boots, flash migrator from Magisk Manager.
Rebooting is not required.

6. Restore all apps+data, settings and Magisk data: "${0##*/} -re".

7. Launch Magisk Manager and disable/remove all restored modules that are or may be incompatible with the [new] ROM.

8. Reboot.


SYSTEM DATA (D)

If you find any issue after restoring system data (-rD), remove the associated files with "su -c rm <line>".

/data/system_?e/0/accounts_?e.db*
/data/misc/adb/adb_keys
/data/misc/bluedroid/bt_config.conf
/data/misc/wifi/WifiConfigStore.xml
/data/misc/wifi/softap.conf
/data/system/xlua/xlua.db*
/data/system/users/0/photo.png
/data/system/users/0/wallpaper*
/data/user*/0/com.android.*provider*/databases/*.db*
/data/system/deviceidle.xml


ASSORTED NOTES & TIPS

Busybox and extra binaries can be placed in /data/adb/bin/.
That's the first field in migrator's \$PATH.

"regex" and "-v regex" are grep syntax. "-E" is always implied.

Most operations work in recovery environments as well.
One can either flash the Magisk module [again] to have migrator and M commands available, or run "/data/M".

rsync can be used in auto-backup config to sync backups over an SSH tunnel.
e.g., cmd="${0##*/} -be && rsync -a --del \$bkp_dir vr25@192.168.1.33:migrator"
EOF
  ;;
esac
exit 0
