#!/system/bin/sh
# enable apps with Settings.Secure.ANDROID_ID (SSAID) and start automatic backups (if enabled)

modDir=${0%/*}
start-stop-daemon -bx $modDir/system/bin/migrator -S -- --boot
exit 0
