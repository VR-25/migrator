# Migrator - A Backup Solution and ROM Migration Utility for Android


Install as a regular Magisk module (no reboot required, though).
Alternatively, `system/bin/migrator` can be extracted from the zip and ran as `sh filepath`.

Busybox is required on systems not rooted with Magisk.
The binary can simply be placed in `/data/adb/bin/`.


---
## CHANGELOG

```
v2020.7.20-beta (202007200)

Workaround for Termux backup size issue

Optionally export backups AES256-encrypted with ccrypt.

lzma|xz, zip and zst|zstd archives are also known by migrator.
This means, specifying the extraction method is optional if <program> is available and in $PATH.
Among the supported programs, only pigz and zstd are not generally available in Android/Busybox at this point.
However, since pigz is most often used as a gzip alternative (faster), its .gz archives can also be extracted by gzip itself.


v2020.7.18-beta (202007180)

General fixes & optimizations

The default compression method is <none> (faster, output: .tar file). Method here refers to "<program> <options>" (e.g., "zstd -1v").
The decompression/extraction method to use is automatically determined based on file extension (supported extensions: tar, tar.bz*, tar.gz* and tar.lzo*). The user can supply an alternate method for decompressing other archive types.

--list shows install status as well.
Option to restore only apps that are not installed: "-rn".
Updated data migration tutorial and Tasker setup instructions - export/import to/from external storage included.

Cleaner export/import interface.
Export/import uncompressed archives (-c -).
Fixed settings restore.

Using /data/migrator/ as the new data directory. Android 10 complains when it's placed anywhere in /data/media/.
$version is included in verbose.

NOTE

To restore backups from the old location, use the version that made such backups (/data/media/migrator/local/migrator.sh).
Alternatively, you can move migrator's data folder to the new location (mv /data/media/migrator /data/).

WARNING

The ROM migration process has two additional steps to account for the new backup location.
Failing to follow the instructions carefully will lead to data loss!
```

---
## LICENSE


Copyright 2018-2020, VR25 (patreon.com/vr25)

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see <https://www.gnu.org/licenses/>.


---
## --HELP

```
Migrator v2020.7.20-beta (202007200)
A Backup Solution and ROM Migration Utility for Android
Copyright 2018-2020, VR25 (patreon.com/vr25)
License: GPLv3+


ZERO warranties, use at your own risk!
This is still in beta. Backup your data before using.


USAGE

migrator <option...> [arg...]


OPTIONS

-b[aAdDms]|--backup [--app] [--all] [--data] [--magisk] [--settings] [--sysdata] [regex|-v regex] [+ extra pkgs (full names)]

-d|--delete <"bkp name (wildcards supported)" ...>

[p=<"password for encryption">] -e[i]|--export[i] [regex|-v regex] [-d|--dir <destination directory>] [-c|--compressor <"compression method" or "-" (none, default)>]

[p=<"password for decryption">] -i[i]|--import[i] [regex|-v regex] [-d|--dir <source directory>] [-c|--compressor <"decompression method" or "-" (none)>]

-l|--list [regex|-v regex]

-L|--log

-r[aAdimsD]|--restore [--app] [--all] [--data] [--imported] [--magisk] [--settings] [--sysdata] [regex|-v regex]

-s|--ssaid


EXAMPLES

migrator -b "ook.lite|instagram" (backup Facebook Lite and Instagram's APKs+data)

migrator -b + com.android.vending com.android.inputmethod.latin (backup APKs and data of all user, plus two system apps, excluding APKs outside /data/app/)

migrator -bms (backup Magisk data (m) and generic Android settings (s))

migrator -bAmsD + $(pm list packages -s | sed 's/^package://') (backup everything)

migrator -bAmsD (backup everything, except system apps)

migrator -bd (backup only users apps' data (d))

migrator --delete \* (all backups)

migrator -d "*facebook.lite*" "*instag*"

migrator --export (all to /sdcard/migrator/)

migrator -e -d /storage/XXXX-XXXX/migrator (export all to /storage/XXXX-XXXX/migrator/)

migrator -ei (interactive --export)

migrator --import (from /sdcard/migrator/)

migrator -i -d /storage/XXXX-XXXX/migrator

migrator -ii -d /sdcard/m (interactive --import)

p="my super secret password" ${0##*/} -e instagr (export backup, encrypted)

p="my super secret password" ${0##*/} -i instagr (import encrypted backup)

migrator --list

migrator -l facebook.lite

migrator --restore --data facebook.lite

migrator -r --imported --app --data facebook.lite

migrator -rs (restore generic Android settings)

migrator -rD (restore system data)

migrator -rm (restore magisk data)

migrator -rAms (restore everything, except system data (D, usually incompatible))

migrator -s (enable apps with Settings.Secure.ANDROID_ID (SSAID) after rebooting)

migrator -L (export /dev/migrator.log to /sdcard/migrator.log.bz2)


Migrator can backup/restore apps (a), respective data (d) and runtime permissions.

The order of secondary options is irrelevent (e.g., -rda = -rad, "a" and "d" are secondary options).

Everything in /data/adb/, except magisk/ is considered "Magisk data" (m).
After restoring such data, one has to launch Magisk Manager and disable/remove all modules that are or may be incompatible with the [new] ROM.

Accounts, call logs, contacts and SMS/MMS, other telephony and system data (D) restore is not fully guaranteed.
These are complex databases and often found in variable locations.
You may want to export contacts to a vCard file or use a third-party app to backup/restore all telephony data.

Backups of uninstalled apps are automatically removed when a backup command is issued.

For greater compatibility and safety, system apps are not backed up, unless specified as "extras" (see examples).
No APK outside /data/app/ is ever backed up.
Data of specified system apps is always backed up.

Migrator itself is included in backups and exported alongside backup archives.

Backups are stored in /data/migrator/local/.

These backups take virtually no extra storage space (hard links).

Backups can be exported as indivudual [compressed] archives (recommended).
Data is exported to /sdcard/migrator/ by default - and imported to "/data/migrator/imported".
The default compression method is <none> (faster, output: .tar file).
Method here refers to "<program> <options>" (e.g., "zstd -1").
The decompression/extraction method to use is automatically determined based on file extension.
Supported archives are tar, tar.bz*, tar.gz*, tar.lzma, tar.lzo*, tar.pigz, tar.xz, tar.zip and tar.zst*.
The user can supply an alternate method for decompressing other archive types.
Among the supported programs, only pigz and zstd are not generally available in Android/Busybox at this point.
However, since pigz is most often used as a gzip alternative (faster), its .gz archives can also be extracted by gzip itself.

The Magisk module variant installs NetHunter Terminal.
Highly recommended, it's always excluded from backups.
If you use another terminal, it MUST BE EXCLUDED manually (e.g., "migrator -bA -v termux").
This is because apps being backed up are temporarily suspended.
Before restore, they are terminated.
Thus, not excluding the terminal that runs migrator will lead to incomplete backup/restore.

Having a terminal ready out of the box also adds convenience.
Users don't have to install a terminal to get started, especially after migrating to another ROM.

But why "NetHunter Terminal"?
It's free and open source, VERY light and regularly updated.
The homepage is https://store.nethunter.com/en/packages/com.offsec.nhterm .
You can always compare the package signatures and/or checksums.

The Magisk module variant also ships with ccrypt v1.11 binaries for AES256 encryption.
These are from Termux's repo: https://dl.bintray.com/termux/termux-packages-24/ .
Non-Magisk users can place a static ccrypt binary in /data/adb/bin/ or use Termux.
Note: the included binaries may only work on Android 7.0+.


AUTOMATING BACKUPS

"init.d" Script
#!/system/bin/sh
# This is a script that daemonizes "migrator --boot" to automate backups.
/path/to/busybox start-stop-daemon -bx /path/to/migrator -S -- --boot
exit 0

Config for Magisk and init.d
Create "/data/migrator.conf" with "bkp="[sub options] [args]"", "cmd="post bkp cmd"", "freq=[hours]" and "delay=[minutes].
e.g., "bkp=ADms; freq=24; delay=60" (defaults, used when $config exists but is empty or values are null)
The first backup starts $delay minutes after boot.
The config can be updated without rebooting.
Changes take efect in the next loop iteration.
Logs are saved to "/dev/migrator.log".
Note: the config file is saved in /data and is not created automatically for obvious reasons. A factory reset wipes /data. After migrating to another ROM or performing a factory reset, you do not want your backups overwritten before the data is restored.

Tasker or Similar
Backup everything, except system apps - and export to external storage: "(migrator -bADms && migrator -e -d /storage/XXXX-XXXX/my-backups &)".
Verbose is redirected to "/dev/migrator.log".


ROM MIGRATION STEPS AND NOTES

1. Backup everything, except system apps: "migrator -bADms".

1.1. Export the backups to external storage (highly recommended): "migrator -e -d /storage/XXXX-XXXX/my-backups".

2. Move local (hard link type) backups to /data/media/0/: "mv /data/migrator /data/media/0)".
Otherwise, wiping /data (excluding /data/media) will remove the backups as well.
Data loss WARNING: do NOT move to /sdcard/! It has a different filesystem.

3. Install the [new] ROM (factory reset implied), addons as desired - and root it.

4. Move backups back to /data/: "mv /data/media/0/migrator /data/".

4.1. If something goes wrong, import the backups from external storage: "migrator -i -d /storage/XXXX-XXXX/my-backups".

5. Once Android boots, flash migrator from Magisk Manager.
Rebooting is not required.

6. Launch NetHunter Terminal (bundled), select "AndroidSu" shell and run "migrator -rADms" or "/dev/migrator -rADms" to restore data.

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
That's the first field in migrator's $PATH.

"regex" and "-v regex" are grep syntax. "-E" is always implied.

Most operations work in recovery environments as well.
One can either flash the Magisk module [again] to have migrator and M commands available, or run "/data/M".
```
