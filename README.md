# Migrator - A Backup Solution and Data Migration Utility for Android


Install as a regular Magisk module (no reboot required, though).
If `M` and `migrator` executables are unavailable before a reboot, use `/dev/M` or `/dev/migrator`.

`migrator.sh` can be extracted from the root of the zip and used as is (e.g., `su -c sh migrator.sh`).

Busybox is required on systems not rooted with Magisk.
The binary can simply be placed in `/data/adb/bin/`.


---
## CHANGELOG

```
v2020.8.17-beta (202008170)

Enhanced auto-backup logic
General fixes & optimizations
More intuitive auto-backup config syntax
Updated backup automation info (config, Tasker script and more)


v2020.8.15-beta (202008150)

Do not restore SSAIDs if com.google.android.gms is not installed.
General fixes & optimizations
Fixed bootloop caused by SSAID handling issues.
"E", as in "-bE", no longer implies "D" (system data).
Updated documentation


v2020.8.12-beta (202008120)

"E|--everything" flag for backup and restore can be used in place of "ADms" (e.g., "M -bE" or "M --backup --everything").

General fixes
Major optimizations
Save migrator's data in /sdcard/Download/migrator/.
Updated documentation
```

---
## LICENSE


Copyright 2018-2020, VR25

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
Migrator v2020.8.17-beta (202008170)
A Backup Solution and Data Migration Utility for Android
Copyright 2018-2020, VR25
License: GPLv3+


ZERO warranties, use at your own risk!
This is still in beta. Backup your data before using.


USAGE

migrator <option...> [arg...]


OPTIONS

Backup
-b[aAdDEms]|--backup [--app] [--all] [--data] [--everything] [--magisk] [--settings] [--sysdata] [regex|-v regex] [+ file or full pkg names]

Delete backups (local and imported)
-d|--delete <"bkp name (wildcards supported)" ...>

Export backups
[p=<"password for encryption">] -e[i]|--export[i] [regex|-v regex] [-d|--dir <destination directory>] [-c|--compressor <"compression method" or "-" (none, default)>]

Import backups
[p=<"password for decryption">] -i[i]|--import[i] [regex|-v regex] [-d|--dir <source directory>] [-c|--compressor <"decompression method" or "-" (none)>]

List backups
-l|--list [regex|-v regex]

Export logs to /sdcard/Download/migrator/migrator.log.bz2
-L|--log

Restore backups
-r[aAdEimnsD]|--restore [--app] [--all] [--data] [--everything] [--imported] [--magisk] [--not-installed] [--settings] [--sysdata] [regex|-v regex]

Manually enable SSAID apps
-s|--ssaid


EXAMPLES

Backup Facebook Lite and Instagram (apps and data)
migrator -b "ook.lite|instagram"

Backup all user apps and data, plus two system apps, excluding APKs outside /data/app/
migrator -b + com.android.vending com.android.inputmethod.latin

Backup data (d) of pkgs in /sdcard/list.txt
migrator -bd -v . + /sdcard/list.txt

Backup Magisk data (m) and generic Android settings (s)
migrator -bms

Backup everything, except system data (D)
migrator -bE + $(pm list packages -s | sed 's/^package://')

Backup everything, except system data (D) and system apps
migrator -bE

Backup all users apps' data (d)
migrator -bd

Delete all backups
migrator --delete \*

Delete Facebook Lite and Instagram backups
migrator -d "*facebook.lite*" "*instag*"

Export all backups to /sdcard/Download/migrator/exported/
migrator --export

... To /storage/XXXX-XXXX/migrator/
migrator -e -d /storage/XXXX-XXXX/migrator

Interactive --export
migrator -ei

Import all backups from /sdcard/Download/migrator/exported
migrator --import

... From /storage/XXXX-XXXX/migrator
migrator -i -d /storage/XXXX-XXXX/migrator

Interactive --import
migrator -ii -d /sdcard/m

Export backup, encrypted
p="my super secret password" migrator -e instagr

Import encrypted backup
p="my super secret password" migrator -i instagr

List all backups
migrator --list

List backups (filtered)
migrator -l facebook.lite

Restore only data of matched packages
migrator --restore --data facebook.lite

Restore matched imported backups (app and data)
migrator -r --imported --app --data facebook.lite

Restore generic Android settings
migrator -rs

Restore system data (e.g., Wi-Fi, Bluetooth)
migrator -rD

Restore magisk data (everything in /data/adb/, except magisk/)
migrator -rm

Restore everything, except system data (D), which is usually incompatible)
migrator -rE

Restore not-installed user apps+data)
migrator -rn


Migrator can backup/restore apps (a), respective data (d) and runtime permissions.

The order of secondary options is irrelevent (e.g., -rda = -rad, "a" and "d" are secondary options).

Everything in /data/adb/, except magisk/ is considered "Magisk data" (m).
After restoring such data, one has to launch Magisk Manager and disable/remove all modules that are or may be incompatible with the [new] ROM.

Accounts, call logs, contacts and SMS/MMS, other telephony and system data (D) restore is not fully guaranteed nor generally recommended.
These are complex databases and often found in variable locations.
You may want to export contacts to a vCard file or use a third-party app to backup/restore all telephony data.

Backups of uninstalled apps are automatically removed whenever a backup command is executed.

For greater compatibility and safety, system apps are not backed up, unless specified as "extras" (see examples).
No APK outside /data/app/ is ever backed up.
Data of specified system apps is always backed up.

Migrator itself is included in backups and exported alongside backup archives.

Backups are stored in /data/migrator/local/.
These take virtually no extra storage space (hard links).

Backups can be exported as indivudual [compressed] archives (highly recommended).
Data is exported to /sdcard/Download/migrator/exported/ by default - and imported to "/data/migrator/imported/".
The default compression method is <none> (.tar file).
Method here refers to "<program> <options>" (e.g., "zstd -1").
The decompression/extraction method to use is automatically determined based on file extension.
Supported archives are tar, tar.bz*, tar.gz*, tar.lzma, tar.lzo*, tar.pigz, tar.xz, tar.zip and tar.zst*.
The user can supply an alternate method for decompressing other archive types.
Among the supported programs, only pigz and zstd are not generally available in Android/Busybox at this point.
However, since pigz is most often used as a gzip alternative (faster), its archives can generally be extracted with "gzip -cd" as well.

The Magisk module variant installs NetHunter Terminal.
Highly recommended, it's always excluded from backups.
If you use another terminal, it MUST BE EXCLUDED manually (e.g., "migrator -bA -v termux").
This is because apps being backed up are temporarily suspended.
Before restore, they are terminated.
Thus, not excluding the app that runs migrator will lead to incomplete backup/restore.

Having a terminal ready out of the box also adds convenience.
Users don't have to install a terminal to get started, especially after migrating to another ROM.

But why "NetHunter Terminal"?
It's free and open source, VERY light and regularly updated.
The homepage is https://store.nethunter.com/en/packages/com.offsec.nhterm .
You can always compare the package signatures and/or checksums.


ENCRYPTION

Migrator uses ccrypt for encryption, but it does not ship with it.
I'm looking for suitable static ccrypt binaries to bundle.
There's a package available for Termux: "pkg install ccrypt".
Once installed, non-Magisk users have to symlink ccrypt to /data/adb/bin/: "su -c "mkdir -p /data/adb/bin; ln -sf /data/data/com/termux/files/usr/bin/ccrypt /data/adb/bin/".
Magisk users need not do anything else besides installing the ccrypt Termux package.
Alternatively (no Termux), a static ccrypt binary can be placed in /data/adb/bin/.


AUTOMATING BACKUPS

"init.d" Script (Magisk users don't need this)
#!/system/bin/sh
# This is a script that daemonizes "migrator --boot" to automate backups.
/path/to/busybox start-stop-daemon -bx /path/to/migrator -S -- --boot
exit 0

Config for Magisk and init.d
# /data/migrator.conf
# Default config, same as a blank file
# Note: this is not created automatically.
cmd="migrator -bE && migrator -e" # Commands to run
freq=24 # Every 24 hours
delay=60 # Starting 60 minutes after boot

Sample Tasker Script
#!/system/bin/sh
# /data/my-tasker-script
# su -c /data/my-tasker-script
# This requires read and execute permissions to run
migrator -bE
migrator -e -d /mnt/media_rw/XXXX-XXXX/my-backups

Debugging
Verbose is redirected to "/dev/migrator.log".


FULL DATA MIGRATION STEPS AND NOTES

1. Backup everything, except system apps: "migrator -bE".

1.1. Export the backups to external storage: "migrator -e -d /storage/XXXX-XXXX/my-backups".
This is highly recommended - and particularly important if the data partition is encrypted.
Following this renders steps 2 and 4 optional.

2. Move local (hard link type) backups to /data/media/0/: "mv /data/migrator /data/media/0)".
Otherwise, wiping /data (excluding /data/media) will remove the backups as well.
Data loss WARNING: do NOT move to /sdcard/! It has a different filesystem.

3. Install the [new] ROM (factory reset implied), addons as desired - and root it.

4. Move hard link backups back to /data/: "mv /data/media/0/migrator /data/".

4.1. If something goes wrong with the moving process, import the backups from external storage: "migrator -i -d /storage/XXXX-XXXX/my-backups".

5. Once Android boots, flash migrator from Magisk Manager.
Rebooting is not required.

6. Launch NetHunter Terminal (bundled), select "AndroidSu" shell and run "migrator -rE" or "/dev/migrator -rE" to restore data.
Notes: if you followed step 4.1, specify the "i" or "--imported" flag (e.g, -rAims) to restore imported backups.

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
