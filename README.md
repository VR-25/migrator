# Migrator - A Backup Solution and ROM Migration Utility for Android


Install as a regular Magisk module (no reboot required, though).
Alternatively, `system/bin/migrator` can be extracted from the zip and ran as `sh filepath`.

Busybox is required on systems not rooted with Magisk.
The binary can simply be placed in `/data/adb/bin/`.


---
## CHANGELOG

```
v2020.7.8-beta (202007080)

Automatic backups (Magisk, init.d and Tasker flavors)
Customizable first backup (after boot) delay (default: 60 minutes)
/dev/migrator.log can be exported to /sdcard/migrator.log.bz2 with `M -L`.
Major fixes & optimizations
More comprehensive `--list`
System data backup/restore sub-option is now D (formerly S).
README.md has a copy of the help text.
Updated documentation (ROM migration instructions, automatic backup configuration and more).
Verbose is redirected to /dev/migrator.log.
Works in recovery environments (particularly useful for emergency backups).


v2020.7.1-beta.4 (202007014)

General fixes & optimizations
Backup/restore magisk data's SELinux contexts (ditch the hard-coded `u:object_r:system_file:s0`).
Mark all restored apps as installed from Google Play Store.

WARNING
This version will fail to restore magisk data backed up with previous builds.
Use the backup creator (backed itself up too): `/data/media/migrator/*/migrator.sh`.


v2020.7.1-beta.3 (202007013)

Backups are no longer moved to bkp.old/.
Major fixes & optimizations
More flexible backup/restore options (e.g., app only, data only)
New backups replace old ones.
Updated help text.
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
ZERO warranties, use at your own risk!
This is still in beta. Backup your data before using.


USAGE

${0##*/} <option...> [arg...]


OPTIONS

-b[aAdDms]|--backup [--app] [--all] [--data] [--magisk] [--settings] [--sysdata] [regex|-v regex] [+ extra pkgs (full names)]

-d|--delete <"bkp name (wildcards supported)" ...>

-e[i]|--export[i] [regex|-v regex] [-d|--dir <destination directory>] [-c|--compressor <"compression method">]

-i[i]|--import[i] [regex|-v regex] [-d|--dir <source directory>] [-c|--compressor <"decompression method">]

-l|--list [regex|-v regex]

-L|--log

-r[aAdimsD]|--restore [--app] [--all] [--data] [--imported] [--magisk] [--settings] [--sysdata] [regex|-v regex]

-s|--ssaid


EXAMPLES

${0##*/} -b "ook.lite|instagram" (backup Facebook Lite and Instagram's APKs+data)

${0##*/} -b + com.android.vending com.android.inputmethod.latin (backup APKs and data of all user, plus two system apps, excluding APKs outside /data/app/)

${0##*/} -bms (backup Magisk data (m) and generic Android settings (s))

${0##*/} -bAmsD + \$(pm list packages -s | sed 's/^package://') (backup everything)

${0##*/} -bAmsD (backup everything, except system apps)

${0##*/} -bd (backup only users apps' data (d))

${0##*/} --delete \\* (all backups)

${0##*/} -d "*facebook.lite*" "*instag*"

${0##*/} --export (all to /sdcard/migrator/)

${0##*/} -e -d /storage/XXXX-XXXX/migrator (export all to /storage/XXXX-XXXX/migrator/)

${0##*/} -ei (interactive --export)

${0##*/} --import (from /sdcard/migrator/)

${0##*/} -i -d /storage/XXXX-XXXX/migrator

${0##*/} -ii -d /sdcard/m (interactive --import)

${0##*/} --list

${0##*/} -l facebook.lite

${0##*/} --restore --data facebook.lite

${0##*/} -r --imported --app --data facebook.lite

${0##*/} -rs (restore generic Android settings)

${0##*/} -rD (restore system data)

${0##*/} -rm (restore magisk data)

${0##*/} -rAms (restore everything, except system data (D, usually incompatible))

${0##*/} -s (enable apps with Settings.Secure.ANDROID_ID (SSAID) after rebooting)

${0##*/} -L (export $log to /sdcard/migrator.log.bz2)


Migrator can backup/restore apps (a), respective data (d) and runtime permissions.

The order of secondary options is irrelevent (e.g., -rda = -rad, "a" and "d" are secondary options).

Everything in /data/adb/, except magisk/ is considered "Magisk data" (m).
After restoring such data, one has to launch Magisk Manager and disable/remove all modules that are or may be incompatible with the [new] ROM.

Accounts, call logs, contacts and SMS/MMS, other telephony and system data (D) restore is not fully guaranteed.
These are complex files and often found in variable locations.
Thus, restoring such data is not generally recommended to regular users.
You may want to export contacts to a vCard file or use a third-party app to backup/restore all telephony data.

Backups of uninstalled apps are automatically removed when a backup command is issued.

For greater compatibility and safety, system apps are not backed up, unless specified as "extras" (see examples).
No APK outside /data/app/ is ever backed up.
Data of specified system apps is always backed up.

Migrator itself is included in backups and exported alongside backup archives.

Backups are stored in $bkp_dir/.

These backups take virtually no extra storage space (hard links).

Backups can be exported as compressed archives.
The default export/import directory is /sdcard/migrator.
"lzop -1v" is the default compression method.
Method here refers to "<program> <options>".
Imported backups are stored in "/data/media/migrator/imported/".

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


AUTOMATING BACKUPS

"init.d" Script
#!/system/bin/sh
# This is a script that daemonizes "migrator --boot" to automate backups.
/path/to/busybox start-stop-daemon -bx /path/to/migrator -S -- --boot
exit 0

Config for Magisk and init.d
Create "/data/migrator.conf" with "bkp="[sub options] [args]"", "freq=[hours]" and "delay=[minutes].
e.g., "bkp=ADms; freq=24; delay=60" (defaults, used when \$config exists but is empty or values are null)
The first backup starts \$delay minutes after boot.
The config can be updated without rebooting.
Changes take efect on the next loop iteration.
Logs are saved to "$log".
Note: the config file is saved in /data and is not created automatically for obvious reasons. A factory reset wipes /data. After migrating to another ROM or performing a factory reset, you do not want your backups overwritten before the data is restored.

Tasker or Similar
"start-stop-daemon -bx ${0##*/} -S -- -bADms"
If you don't have busybox installed system-wide, prepend it to the command line above.
e.g., "/data/adb/magisk/busybox start-stop-daemon -bx ${0##*/} -S -- -bADms"
Logs are saved to "$log".


ROM MIGRATION STEPS AND NOTES

1. Backup everything, except system apps: "${0##*/} -bADms".

2. Install the [new] ROM (factory reset implied), addons as desired - and root it.

3. Once booted, flash Migrator from Magisk Manager (no reboot needed afterwards).

4. Launch NetHunter Terminal (bundled), select "AndroidSu" shell and run "${0##*/} -rAms" or "/dev/${0##*/} -rAms".

5. Launch Magisk Manager and disable/remove all restored modules that are or may be incompatible with the [new] ROM.

6. Reboot.

Restoring system data (D, listed below) is not recommended to users who don't know how to find their way around potential issues.

If you use a different root method, just ignore Magisk-related steps.

Remember that using a terminal other than NetHunter means you have to exclude it from backups/restores or detach migrator from it.


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
That's the first field in migrator's \$PATH.

"regex" and "-v regex" are grep syntax. "-E" is always implied.

Most operations work in recovery environments as well.
One can either flash the Magisk module [again] to have migrator and M commands available, or run "/data/M".
```
