extract_libs() {
  mkdir -p $libDir/$1
  unzip -j $apk "lib/${2:-$1}/*" -d $libDir/$1 >&2
}

libDir=$MODPATH/system/app/com.offsec.nhterm/lib
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
execFile=$MODPATH/system/bin/migrator
ln -fs $execFile /dev/
ln -fs $execFile /dev/M
test -d /sbin && /system/bin/mount -o remount,rw / 2>/dev/null && {
ln -fs $execFile /sbin
ln -fs $execFile /sbin/M
} 2>/dev/null && /system/bin/mount -o remount,ro /

# remove leftovers
rm $MODPATH/License.md $MODPATH/TODO.txt

# set permissions
set_perm_recursive $MODPATH 0 0 0755 0644
set_perm_recursive $MODPATH/system/bin 0 0 0755 0755

# make NetHunter Terminal readily available
if $BOOTMODE && ! test -d /data/data/com.offsec.nhterm; then
  sestatus=$(getenforce)
  setenforce 0
  trap '[ $sestatus != Permissive ] && setenforce 1' EXIT
  ui_print "- Installing NetHunter Terminal"
  pm install $MODPATH/system/app/com.offsec.nhterm/com.offsec.nhterm.apk > /dev/null
fi
