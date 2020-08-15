#!/system/bin/sh
# Migrator
# A Backup Solution and Data Migration Utility for Android
# Copyright 2018-2020, VR25 (patreon.com/vr25)
# License: GPLv3+


echo
set -u
umask 0077


ssaid=false
log=/dev/migrator.log
tmp=/dev/migrator.tmp
bkp_dir=/data/migrator/local
packages=/data/system/packages
data_dir=/sdcard/Download/migrator
imports_dir=${bkp_dir%/*}/imported
version="v2020.8.15-beta (202008150)"
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


parse_params() {
  regex=..
  compressor=-
  dir=$data_dir/exported
  while t -n "${1-}"; do
    case "$1" in
      -d|--dir)
        dir="$2"
        shift 2
      ;;
      -c|--compressor)
        compressor="$2"
        shift 2
      ;;
      -v)
        regex="$1 \"$2\""
        shift 2
      ;;
      *)
        regex="$1"
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
tt "${1-}" "-L|--log|--boot" || {
  date > $log
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
export PATH=$bin_dir:$busybox_dir:/data/adb/modules_update/migrator/bin:/data/adb/modules/migrator/bin:$PATH
unset bin_dir busybox_dir magisk_busybox


param1=${1-}
t -n "$param1" && shift


# set up recovery environment
recovery_mode=false
pgrep -f zygote > /dev/null || {
  set +x
  clear
  recovery_mode=true
  trap 'exit_code=$?; set +x; echo; exit $exit_code' EXIT
  tt "$param1" "-*r*|-s|--ssaid|--boot|--restore" && {
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
      printf "Reboot $(t -f /data/adb/modules/migrator/service.sh || echo "& run \"${0##*/} -s\" ")"
      printf "to enable apps with Settings.Secure.ANDROID_ID (SSAID)\n"
    }
    rm /data/.__hltest /dev/._split 2>/dev/null
    echo
    exit $exit_code
  }
  trap exxit EXIT
}


all=false
tt "$param1" "-[br]|-[br][in]|-[br][in][in]|-[br]*A*" && all=true
tt "$*" "*--all*" && all=true

everything=false
tt "$param1" "-*E*" && everything=true
tt "$*" "*--everything*" && everything=true


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


case "$param1" in

  -b*|--ba*) # backup

    echo "Backing up"

    extras="$(echo "$*" | grep -o '\+.*' | sed 's/\+ //')"
    set -- $(echo "$@" | sed 's/\+.*//')
    tt "$*" "*-v*" && v=v || v=
    regex="$(echo "$*" | sed -E 's/ |-v|--(app|data|everything|magisk|settings|sysdata)//g')"

    pkg_list="$(grep 'name=.*codePath="/data/app/' ${packages}.xml \
      | grep -E$v "${regex:-..}" | grep -v com.offsec.nhterm \
      | awk '{print $2}' | tr -d \" | sed 's/^name=//')"

    unset regex
    mkdir -p $bkp_dir

    # remove backups of uninstalled apps
    (set +x
    ls -1 $bkp_dir 2>/dev/null \
      | grep -Ev '^_magisk$|^migrator.sh$|^_settings$|^_sysdata$' | \
      while IFS= read -r pkg; do
        grep -q "^$pkg " ${packages}.list || rm -rf $bkp_dir/$pkg
      done)

    t -f /data/system/users/0/runtime-permissions.xml \
      && bkp_runtime_perms=true \
      || bkp_runtime_perms=false

    echo "$pkg_list" > $tmp

    t -n "$extras" && {
      if tt "$extras" "*/*"; then
        cat $extras | dos2unix >> $tmp
        echo >> $tmp
      else
        echo "$extras" | sed 's/ /\n/g' >> $tmp
      fi
    }

    sort -u $tmp | sed -e 's/ //g' -e '/^$/d' > ${tmp}.tmp \
      && mv -f ${tmp}.tmp $tmp

    checked=false

    while IFS= read -r pkg; do

      tt "$pkg" "*[a-z]*" || continue

      $checked || {
        checked=true
        { $everything || $all || tt "$param1" "-b*[ad]*" || tt "$*" "*--app*|*--data*"; } || break
      }

      mkdir -p $bkp_dir/$pkg

      # backup app
      app=false
      if $everything || $all || tt "$param1" "-b*a*" || tt "$*" "*--app*"; then
        rm $bkp_dir/$pkg/*.apk
        ln /data/app/${pkg}-*/*.apk $bkp_dir/$pkg/ && {
          app=true
          printf "  $pkg\n    App\n"
        }
      fi 2>/dev/null

      # backup data
      if $everything || $all || tt "$param1" "-b*d*" || tt "$*" "*--data*"; then
        $app && echo "    Data" || printf "  $pkg\n    Data\n"
        killall -STOP $pkg > /dev/null 2>&1
        rm -rf $bkp_dir/$pkg/$pkg $bkp_dir/$pkg/${pkg}_de 2>/dev/null
        mkdir $bkp_dir/$pkg/$pkg $bkp_dir/$pkg/${pkg}_de
        : > $bkp_dir/$pkg/modes.txt
        for e in /data/data/${pkg}::$pkg /data/user_de/0/${pkg}::${pkg}_de; do
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
    if $everything || tt "$param1" "-b*s*" || tt "$*" "*--settings*"; then
      echo "  Generic Android settings"
      rm -rf $bkp_dir/_settings 2>/dev/null
      mkdir $bkp_dir/_settings
      for i in global secure system; do
        awk '{print $3,$4}' ${settings}$i.xml | tr -d \" \
          | sed -e s/name=// -e 's/ value//' -e '/^$/d' -e '/ standalone=/d' -e '/^ /d' > $bkp_dir/_settings/$i.txt
      done
    fi

    # backup system data
    if tt "$param1" "-b*D*" || tt "$*" "*--sysdata*"; then
      echo "  System data"
      rm -rf $bkp_dir/_sysdata 2>/dev/null
      mkdir $bkp_dir/_sysdata
      echo "$sysdata" > $tmp
      while IFS= read -r l; do
        for i in $l; do
          ln $i $bkp_dir/_sysdata/ 2>/dev/null || continue
          stat -c "rm %n; ln $bkp_dir/_sysdata/${i##*/} %n && { chown %U:%G %n; chmod %a %n; /system/bin/restorecon %n; }" \
            $i >> $bkp_dir/_sysdata/restore.sh
        done
      done < $tmp
    fi

    # backup magisk data
    if $everything || tt "$param1" "-b*m*" || tt "$*" "*--magisk*"; then
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
  ;;


  *-d*) # delete
    tt "$*" "*/*" || {
      l="$({ cd $bkp_dir && ls -1dp $*; cd $imports_dir && ls -1dp $*; } | sed 's/^/  /' | sort -u | grep -v '\./')"
      t -n "$l" && printf "Removing\n$l\n" || echo "No matches"
      cd $bkp_dir && eval rm -rf "$@"
      cd $imports_dir && eval rm -rf "$@"
    } 2>/dev/null
  ;;


  *-e*) # export

    cd $bkp_dir || exit

    case $param1 in
      -*e*i) # interactive mode
        clear
        echo
        ls -1 | grep -v '^migrator.sh$'
        echo
        echo '[regex, default: ".."|-v regex] [-d <destination directory, default: $data_dir/exported>] [-c <"compression method" or "-" (none, default)>]'
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
  ;;


  *-i*) # import

    mkdir -p $imports_dir
    parse_params "$@"
    cd $dir || exit

    tt "$param1" "-*i*i*" && { # interactive mode
      clear
      echo
      ls -1 | grep -v '^migrator.sh$'
      echo
      echo '[regex, default: ".."|-v regex] [-c <"compression method" or "-" (none, default)>]'
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
        rm -f $imports_dir/${bkp%.tar*} 2>/dev/null
        case ${bkp##*.tar.} in
          bz2*|bzip2*) decrypt bzip2 -cd | tar -xf - -C $imports_dir;;
          gz*|pigz*) decrypt gzip -cd | tar -xf - -C $imports_dir;;
          lzo*) decrypt lzop -cd $bkp | tar -xf - -C $imports_dir;;
          xz*|lzma*) decrypt xz -cd | tar -xf - -C $imports_dir;;
          zip*) decrypt unzip -p | tar -xf - -C $imports_dir;;
          zst*) decrypt zstd -cd | tar -xf - -C $imports_dir;;
          *.tar|cpt)
            if $encryption; then
              ccrypt -dcE p $bkp | tar -xf - -C $imports_dir
              export p="$p_"
            else
              tar -xf $bkp -C $imports_dir
            fi
          ;;
          *) decrypt $compressor | tar -xf - -C $imports_dir;;
        esac
      done
    cp -f migrator.sh $imports_dir/
  ;;


  *-l*) # list
    regex="$*"
    list_bkps() {
      echo $1/
      ls -1 $1 2>/dev/null | sed -En -e '/^migrator.sh/d' -e "/${regex:-..}/p" | \
        while IFS= read -r i; do
          t -n "$i" || continue
          printf "  $i"
          tt "$i" "_*" && echo || {
            grep -q "$i " ${packages}.list && echo " (installed)" || echo
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
    echo
    list_bkps $imports_dir
  ;;


  -L|--log)
    mkdir -p $data_dir
    bzip2 -9 < $log > $data_dir/${log##*/}.bz2 \
      && echo "$data_dir/${log##*/}.bz2"
  ;;


  *-r*) # restore

    echo "Restoring"

    tt "$*" "*-v*" && v=v || v=

    regex="$(echo "$*" | sed -E 's/ |-v|--(app|data|everything|imported|magisk|not-installed|settings|sysdata)//g')"

    if tt "$param1" "-r*i*" || tt "$*" "*--imported*"; then
      bkp_dir=$imports_dir
    fi

    ls -d $bkp_dir/* > /dev/null && cd $bkp_dir || exit

    params="$@"

    if $everything || $all || tt "$param1" "-r*[ad]*" \
      || tt "$*" "*--app*" || tt "$*" "*--data*"
    then

      # set the stage for SSAIDs restore
      if grep -q '^com.google.android.gms ' ${packages}.list \
        && t -f $ssaid_xml && ls */ssaid.txt > /dev/null 2>&1
      then
        no_ssaid=false
        id=$(grep -Eo 'id=.*name=' $ssaid_xml | grep -Eo '[0-9]+' | sort -n | tail -n 1)
        grep -v '</settings>' $ssaid_xml > $ssaid_xml_tmp
      else
        no_ssaid=true
      fi


      # enable "unknown sources" and disable package verification

      if grep -q ' name="install_non_market_apps" ' ${settings}secure.xml \
        && ! grep -q ' name="install_non_market_apps" value="1" ' ${settings}secure.xml
      then
        settings put secure install_non_market_apps 1
      fi

      if grep -q ' name="verifier_verify_adb_installs" ' ${settings}global.xml \
        && ! grep -q ' name="verifier_verify_adb_installs" value="0" ' ${settings}global.xml
      then
        settings put global verifier_verify_adb_installs 0
      fi

      if grep -q ' name="package_verifier_enable" ' ${settings}global.xml \
        && ! grep -q ' name="package_verifier_enable" value="0" ' ${settings}global.xml
      then
        settings put global package_verifier_enable 0
      fi


      ls -1 $bkp_dir 2>/dev/null \
        | grep -Ev '^_magisk$|^migrator.sh$|^_settings$|^_sysdata$' \
        | grep -E$v "${regex:-..}" > $tmp

      if tt "$param1" "-r*n*" || tt "$*" "*--not-installed*"; then
        # exclude installed apps
        while IFS= read -r i; do
          tt "$i" "*[a-z]*" || continue
          grep -q "$i " ${packages}.list && sed -i /$i$/d $tmp
        done < $tmp
      fi

      touch /data/.__hltest

      while IFS= read -r pkg; do

        tt "$pkg" "*[a-z]*" || continue

        # restore app
        app=false
        if t -f $pkg/base.apk && { $everything || $all || tt "$param1" "-r*a*" || tt "$params" "*--app*"; }; then
          app=true
          printf "  $pkg\n    App\n"
          # base APK
          pm install -r  -i com.android.vending $pkg/base.apk > /dev/null && {
            rm $pkg/base.apk
            ln /data/app/${pkg}-*/base.apk $pkg/
            # split APKs
            ls $pkg/split_*.apk > /dev/null 2>&1 && {
              for pkg_ in $pkg/split_*.apk; do
                pm install -r -i com.android.vending -p $pkg $pkg_ > /dev/null && {
                  rm $pkg_
                  ln /data/app/${pkg}-*/${pkg_##*/} $pkg/
                }
              done
            }
          }
        fi

        { t -d /data/data/$pkg && ls -d $pkg/$pkg/* > /dev/null 2>&1; } || continue

        if $everything || $all || tt "$param1" "-r*d*" || tt "$params" "*--data*"; then
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
            sed -i /$pkg/d $ssaid_xml_tmp
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
    if $everything || tt "$param1" "-r*s*" || tt "$params" "*--settings*"; then
      echo "  Generic Android Settings"
      for namespace in global secure system; do
        while IFS= read -r setting; do
          tt "$setting" "*[a-z]*" || continue
          grep -q " name=\"${setting%%=*}\" " ${settings}$namespace.xml && {
            echo "    ${setting%%=*}="${setting#*=}""
            settings put $namespace ${setting%%=*} "${setting#*=}"
          }
        done < $bkp_dir/_settings/$namespace.txt
      done
    fi

    # restore system data
    if tt "$param1" "-r*D*" || tt "$params" "*--sysdata*"; then
      echo "  System Data"
      mkdir /data/system/xlua 2>/dev/null && {
        chown 1000:1000 /data/system/xlua
        chmod 0770 /data/system/xlua
      }
      t -f $bkp_dir/_sysdata/restore.sh && . $bkp_dir/_sysdata/restore.sh
    fi

    # restore magisk data
    if $everything || tt "$param1" "-r*m*" || tt "$params" "*--magisk*"; then
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


  # enable apps with Settings.Secure.ANDROID_ID (SSAID) and start automatic backups (if enabled)
  --boot|-*s*)

    ssaid_only=true
    t $param1 = --boot && ssaid_only=false

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

    bkp=E
    config=/data/migrator.conf

    t -f $config && {
      . $config
      sleep $(( ${delay:-60} * 60 ))
      while true; do
        $0 -b$bkp || break
        eval "${cmd-}"
        sleep $(( ${freq:-24} * 60 * 60 ))
        . $config
      done
    }
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

${0##*/} <option...> [arg...]


OPTIONS

Backup
-b[aAdDEms]|--backup [--app] [--all] [--data] [--everything] [--magisk] [--settings] [--sysdata] [regex|-v regex] [+ file or full pkg names]

Delete backups (local and imported)
-d|--delete <"bkp name (wildcards supported)" ...>

Export backups
[p=<"password for encryption">] -e[i]|--export[i] [regex|-v regex] [-d|--dir <destination directory>] [-c|--compressor <"compression method" or "-" (none, default)>]

Import backups
[p=<"password for decryption">] -i[i]|--import[i] [regex|-v regex] [-d|--dir <source directory>] [-c|--compressor <"decompression method" or "-" (none)>]

List backups
-l|--list [regex|-v regex]

Export logs to $data_dir/migrator.log.bz2
-L|--log

Restore backups
-r[aAdEimnsD]|--restore [--app] [--all] [--data] [--everything] [--imported] [--magisk] [--not-installed] [--settings] [--sysdata] [regex|-v regex]

Manually enable SSAID apps
-s|--ssaid


EXAMPLES

Backup Facebook Lite and Instagram (apps and data)
${0##*/} -b "ook.lite|instagram"

Backup all user apps and data, plus two system apps, excluding APKs outside /data/app/
${0##*/} -b + com.android.vending com.android.inputmethod.latin

Backup data (d) of pkgs in /sdcard/list.txt
${0##*/} -bd -v . + /sdcard/list.txt

Backup Magisk data (m) and generic Android settings (s)
${0##*/} -bms

Backup everything, except system data (D)
${0##*/} -bE + \$(pm list packages -s | sed 's/^package://')

Backup everything, except system data (D) and system apps
${0##*/} -bE

Backup all users apps' data (d)
${0##*/} -bd

Delete all backups
${0##*/} --delete \\*

Delete Facebook Lite and Instagram backups
${0##*/} -d "*facebook.lite*" "*instag*"

Export all backups to $data_dir/exported/
${0##*/} --export

... To /storage/XXXX-XXXX/migrator/
${0##*/} -e -d /storage/XXXX-XXXX/migrator

Interactive --export
${0##*/} -ei

Import all backups from $data_dir/exported
${0##*/} --import

... From /storage/XXXX-XXXX/migrator
${0##*/} -i -d /storage/XXXX-XXXX/migrator

Interactive --import
${0##*/} -ii -d /sdcard/m

Export backup, encrypted
p="my super secret password" ${0##*/} -e instagr

Import encrypted backup
p="my super secret password" ${0##*/} -i instagr

List all backups
${0##*/} --list

List backups (filtered)
${0##*/} -l facebook.lite

Restore only data of matched packages
${0##*/} --restore --data facebook.lite

Restore matched imported backups (app and data)
${0##*/} -r --imported --app --data facebook.lite

Restore generic Android settings
${0##*/} -rs

Restore system data (e.g., Wi-Fi, Bluetooth)
${0##*/} -rD

Restore magisk data (everything in /data/adb/, except magisk/)
${0##*/} -rm

Restore everything, except system data (D), which is usually incompatible)
${0##*/} -rE

Restore not-installed user apps+data)
${0##*/} -rn


Migrator can backup/restore apps (a), respective data (d) and runtime permissions.

The order of secondary options is irrelevent (e.g., -rda = -rad, "a" and "d" are secondary options).

Everything in /data/adb/, except magisk/ is considered "Magisk data" (m).
After restoring such data, one has to launch Magisk Manager and disable/remove all modules that are or may be incompatible with the [new] ROM.

Accounts, call logs, contacts and SMS/MMS, other telephony and system data (D) restore is not fully guaranteed nor generally recommended.
These are complex databases and often found in variable locations.
You may want to export contacts to a vCard file or use a third-party app to backup/restore all telephony data.

Backups of uninstalled apps are automatically removed whenever a backup command is executed.

For greater compatibility and safety, system apps are not backed up, unless specified as "extras" (see examples).
No APK outside /data/app/ is ever backed up.
Data of specified system apps is always backed up.

Migrator itself is included in backups and exported alongside backup archives.

Backups are stored in $bkp_dir/.
These take virtually no extra storage space (hard links).

Backups can be exported as indivudual [compressed] archives (highly recommended).
Data is exported to $data_dir/exported/ by default - and imported to "$imports_dir/".
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
# This is a script that daemonizes "migrator --boot" to automate backups.
/path/to/busybox start-stop-daemon -bx /path/to/migrator -S -- --boot
exit 0

Config for Magisk and init.d
Create "/data/migrator.conf" (refer to "sample config file" below).
The first backup starts \$delay minutes after boot.
The config can be updated without rebooting.
Changes take efect in the next loop iteration.
Logs are saved to "$log".
Note: the config file is saved in /data and is not created automatically for obvious reasons. A factory reset wipes /data. After migrating to another ROM or performing a factory reset, you do not want your backups overwritten before the data is restored.

Sample Config File
# /data/migrator.conf
bkp=E
freq=24
delay=60
cmd="M -e -d /storage/XXXX-XXXX/my-backups"

Tasker
Backup everything and export to external storage
"${0##*/} -bE && ${0##*/} -e -d /storage/XXXX-XXXX/my-backups"
Verbose is redirected to "$log".


FULL DATA MIGRATION STEPS AND NOTES

1. Backup everything, except system apps: "${0##*/} -bE".

1.1. Export the backups to external storage: "${0##*/} -e -d /storage/XXXX-XXXX/my-backups".
This is highly recommended - and particularly important if the data partition is encrypted.
Following this renders steps 2 and 4 optional.

2. Move local (hard link type) backups to /data/media/0/: "mv ${bkp_dir%/*} /data/media/0)".
Otherwise, wiping /data (excluding /data/media) will remove the backups as well.
Data loss WARNING: do NOT move to /sdcard/! It has a different filesystem.

3. Install the [new] ROM (factory reset implied), addons as desired - and root it.

4. Move hard link backups back to /data/: "mv /data/media/0/migrator /data/".

4.1. If something goes wrong with the moving process, import the backups from external storage: "${0##*/} -i -d /storage/XXXX-XXXX/my-backups".

5. Once Android boots, flash migrator from Magisk Manager.
Rebooting is not required.

6. Launch NetHunter Terminal (bundled), select "AndroidSu" shell and run "${0##*/} -rE" or "/dev/${0##*/} -rE" to restore data.
Notes: if you followed step 4.1, specify the "i" or "--imported" flag (e.g, -rAims) to restore imported backups.

7. Launch Magisk Manager and disable/remove all restored modules that are or may be incompatible with the [new] ROM.

8. Reboot.

If you use a different root method, ignore Magisk-related steps.

Remember that using a terminal emulator app other than NetHunter means you have to exclude it from backups/restores or detach migrator from it.


SYSTEM DATA (D)

/data/system_?e/0/accounts_?e.db*
/data/misc/adb/adb_keys
/data/misc/bluedroid/bt_config.conf
/data/misc/wifi/WifiConfigStore.xml
/data/misc/wifi softap.conf
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
EOF
  ;;
esac
exit 0
