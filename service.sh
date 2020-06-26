#!/system/bin/sh
# enable apps with Settings.Secure.ANDROID_ID (SSAID)

modDir=${0%/*}
$modDir/system/bin/migrator --ssaid
