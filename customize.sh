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

# create migrator alias for lazy typing
ln $MODPATH/system/bin/migrator $MODPATH/system/bin/M

# make executables readily available
exec_file=$MODPATH/system/bin/migrator
sed 's|^#\!/.*|#\!/sbin/sh|' $exec_file > /data/M
chmod 0755 /data/M
if $BOOTMODE; then
  ln -fs $exec_file /dev/
  ln -fs $exec_file /dev/M
  ln -fs $exec_file /sbin 2>/dev/null && ln -fs $exec_file /sbin/M
else
  ln -sf /data/M /sbin/migrator 2>/dev/null && ln -sf /data/M /sbin/
fi

# remove leftovers
rm $MODPATH/License.md $MODPATH/TODO.txt

# set permissions
set_perm_recursive $MODPATH 0 0 0755 0644
set_perm_recursive $MODPATH/system/bin 0 0 0755 0755

# make NetHunter Terminal readily available
$BOOTMODE && ! test -d /data/data/com.offsec.nhterm && {
  sestatus=$(getenforce)
  setenforce 0
  trap '[ .$sestatus == .Enforcing ] && setenforce 1; exit 0' EXIT
  ui_print "- Installing NetHunter Terminal"
  pm install $MODPATH/system/app/com.offsec.nhterm/com.offsec.nhterm.apk > /dev/null
}
