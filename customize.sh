extract_libs() {
  mkdir -p $lib_dir/$1
  unzip -j $apk "lib/${2:-$1}/*" -d $lib_dir/$1 >&2
}

lib_dir=$MODPATH/system/app/com.offsec.nhterm/lib
apk=$MODPATH/system/app/com.offsec.nhterm/com.offsec.nhterm.apk

# extract NetHunter Terminal's libraries
case $ARCH in
  arm) extract_libs arm armeabi-v7a;;
  arm64) extract_libs arm64 arm64-v8a;;
  x86|x64) extract_libs x86;;
esac


# create symlinks

mkdir $MODPATH/system/bin
ln -s /data/adb/modules/migrator/migrator.sh $MODPATH/system/bin/
ln -s /data/adb/modules/migrator/migrator.sh $MODPATH/system/bin/M
$BOOTMODE && ln -sf $MODPATH/migrator.sh /data/adb/modules/migrator/migrator.sh 2>/dev/null

exec_file=$MODPATH/migrator.sh
sed 's|^#\!/.*|#\!/sbin/sh|' $exec_file > /data/M
set_perm /data/M 0 0 0755
if $BOOTMODE; then
  ln -fs $exec_file /dev/
  ln -fs $exec_file /dev/M
  test -d /sbin && {
    /system/bin/mount -o remount,rw / 2>/dev/null \
      || mount -o remount,rw /
    ln -fs $exec_file /sbin 2>/dev/null \
      && ln -fs $exec_file /sbin/M
  }
else
  ln -sf /data/M /sbin/migrator 2>/dev/null \
    && ln -sf /data/M /sbin/
fi


# remove leftovers
rm $MODPATH/License.md $MODPATH/TODO.txt

# set permissions
set_perm_recursive $MODPATH 0 0 0755 0644
set_perm $MODPATH/migrator.sh 0 0 0755

# ccrypt
if test -d $MODPATH/bin; then
  cd $MODPATH/bin
  case $ARCH in
    arm*) rm ccrypt-x86;;
    x86*|x64) rm ccrypt-arm;;
    *) rm -rf $MODPATH/bin;;
  esac
  mv ccrypt* ccrypt 2>/dev/null && \
    set_perm ccrypt 0 0 0755
  cd /
else
  mkdir $MODPATH/bin
  ln -s /data/data/com.termux/files/usr/bin/ccrypt $MODPATH/bin/
fi

# make NetHunter Terminal readily available
$BOOTMODE && ! test -d /data/data/com.offsec.nhterm && {
  sestatus=$(getenforce)
  setenforce 0
  trap '[ .$sestatus == .Enforcing ] && setenforce 1; exit 0' EXIT
  ui_print "- Installing NetHunter Terminal"
  pm install $MODPATH/system/app/com.offsec.nhterm/com.offsec.nhterm.apk > /dev/null
}
