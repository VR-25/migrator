#!/system/bin/sh
# enable apps with Settings.Secure.ANDROID_ID (SSAID)

modDir=${0%/*}
while test .$(getprop sys.boot_completed 2>/dev/null) != .1; do
  sleep 10
done
$modDir/system/bin/migrator --ssaid
