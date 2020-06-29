#!/system/bin/sh
# enable apps with Settings.Secure.ANDROID_ID (SSAID)

modDir=${0%/*}
start-stop-daemon -bx $modDir/system/bin/migrator -S -- --ssaid
exit 0
