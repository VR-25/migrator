#!/system/bin/sh
# enable apps with Settings.Secure.ANDROID_ID (SSAID) and start backup daemon (if enabled)

start-stop-daemon -bx ${0%/*}/migrator.sh -S -- -B || (${0%/*}/migrator.sh -B) &
exit 0
