#!/system/bin/sh
# enable apps with Settings.Secure.ANDROID_ID (SSAID) and start automatic backups (if enabled)

/data/adb/magisk/busybox start-stop-daemon -bx ${0%/*}/migrator.sh -S -- -B
exit 0
