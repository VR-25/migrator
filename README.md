# Migrator - A Backup Solution and Data Migration Utility for Android


Install as a regular Magisk module (no reboot required, though).
If `M` and `migrator` executables are unavailable before a reboot, use `/dev/M` or `/dev/migrator`.

`migrator.sh` can be extracted from the root of the zip and used as is (e.g., `su -c sh migrator.sh`).

Busybox is required on systems not rooted with Magisk.
The binary can simply be placed in `/data/adb/bin/`.


---
## CHANGELOG

```
v2020.9.24-beta (202009240)

- Do not remount / rw if it's not tmpfs.
- Fixed backup import issue.


v2020.9.13-beta.1 (202009131)

- Enhanced system data backup and restore logic.
- General fixes & optimizations
- Parse "codePath" from /data/system/package.xml.
- Updated data migration tutorial.

Release Notes
  - Please test whether system data backup and restore work as expected.
  - This version fixes several issues that affected encrypted devices and Android 11 in particular.
  - Nothing was done in regards to the "MIUI 12" bootloop issue. The root cause is still unknown.


v2020.9.11-beta (202009110)

- "-m" option and M sub-option (as in -beM) to move hard link backups to internal sdcard, so that they survive factory resets.
When launched without the -m (move) option, Migrator automatically moves hard link backups back to /data/migrator/local/, for convenience.
/data/migrator/ is inconvenient, but more private than /data/media/ and /data/media/0/.

- Auto-generate sample /sdcard/Download/migrator/packages.list.

- Backup/restore LineageOS-specific Android settings as well.

- copy README.md to /sdcard/Download/migrator/.

- Enforce Unix line endings (LF) in /data/migrator.conf before parsing it.
This ensures config files written on Windows Notepad or other CRLF-loving editors still work as expected.

- Exported backups are now imported to local/ as opposed to imported/ in /data/migrator/.
This means the "i" flag, as in -ri is no longer necessary/valid.

- Fixed: "migrator" executable inaccessible or not found.

- Removed long options (e.g., --backup --app) to reduce overhead.
Other performance enhancements were made on top of that.

- System data (D) is no longer hard-linked.
Regular copies are made instead.
Android dislikes otherwise.

- Two flags changed: A --> b (both (app and data)), E --> e (everything).

- Updated documentation.
This includes data migrator tutorial, flag mnemonics (e.g., -rb = restore both (app and data)) and more.
As hard as the text may seem, read the damn thing anyway and give me some feedback on it... please!

Release Notes
  - MIUI users who face the "reboot to fastboot" issue should refrain from flashing the zip for now.
  - I recommend extracting zip_file/migrator.sh and running it as is - until the cause of that issue is identified and eliminated.
  - Usage example: "su -c sh /path/to/migrator.sh -be"
  - An alias can be appended to Termux's .bashrc to save time and effort, e.g., alias M="su -c sh /sdcard/Download/migrator.sh".
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
## --help

```
Migrator v2020.9.24-beta (202009240)
A Backup Solution and Data Migration Utility for Android
Copyright 2018-2020, VR25
License: GPLv3+


ZERO warranties, use at your own risk!
This is still in beta. Backup your data before using.


USAGE

migrator (wizard)
migrator [option...] [arg...]

[p=<"password for encryption/decryption">] migrator [option...] [arg...]

M is a migrator alias.


OPTIONS[flags]

Backup
-b[abdDemMns] [regex|-v regex] [[+ file or full pkg names] | [/path/to/list] | [-- for /sdcard/Download/migrator/packages.list]]

Delete local backups
-d <"bkp name (wildcards supported)" ...>

Export backups
-e[i] [regex|-v regex] [-d <destination directory>] [-c <"compression method" or "-" (none, default)>]

Import backups
-i [regex|-v regex] [-d <source directory>] [-c <"decompression method" or "-" (none)>]
-ii [regex|-v regex] [-c <"decompression method" or "-" (none)>]

List backups
-l [regex|-v regex]

Export logs to /sdcard/Download/migrator/migrator.log.bz2
-L

Make hard link backups immune to factory resets
-m

Force all apps to reregister for push notifications (Google Cloud Messaging)
-n

Restore backups
-r[abdDemns] [regex|-v regex]

Manually enable SSAID apps
-s


FLAG MNEMONICS

a: app
d: data
b: both (app and data)
D: system data
m: magisk data
M: move /data/migrator to internal sdcard
s: settings (global, secure and system)
e: everything (-be = -bADms, -re = -rAms)
i: interactive (-ei, -ii)
n: not backed up (-bn) or not installed (-rn)


USAGE EXAMPLES

Backup only packages not yet backed up
migrator -bn

Backup Facebook Lite and Instagram (apps and data)
migrator -b ook.lite,instagram

Backup all user apps and data, plus two system apps, excluding APKs outside /data/app/
migrator -b + com.android.vending com.android.inputmethod.latin

Backup data (d) of pkgs in /sdcard/list.txt
migrator -bd /sdcard/list.txt

Backup Magisk data (m) and generic Android settings (s)
migrator -bms

Backup everything
migrator -be + $(pm list packages -s | sed 's/^package://')

Backup everything, except system apps and move /data/migrator to internal sdcard, so that hard link backups survive factory resets
When launched without the -m (move) option, Migrator automatically moves hard link backups back to /data/migrator/local, for convenience
migrator -beM

Backup all users apps' data (d)
migrator -bd

Delete all backups
migrator -d \*

Delete Facebook Lite and Instagram backups
migrator -d "*facebook.lite*" "*instag*"

Export all backups to /sdcard/Download/migrator/exported/
migrator -e

... To /storage/XXXX-XXXX/migrator_exported
migrator -e -d /storage/XXXX-XXXX

Interactive export
migrator -ei

Import all backups from /sdcard/Download/migrator/exported
migrator -i

... From /storage/XXXX-XXXX/migrator_exported
migrator -i -d /storage/XXXX-XXXX/migrator_exported

Interactive import
migrator -ii -d /sdcard/m

Export backup, encrypted
p="my super secret password" migrator -e instagr

Import encrypted backup
p="my super secret password" migrator -i instagr

List all backups
migrator -l

List backups (filtered)
migrator -l facebook.lite

Restore only app data of matched packages
migrator -rd facebook.lite

Restore generic Android settings
migrator -rs

Restore system data (e.g., Wi-Fi, Bluetooth)
migrator -rD

Restore Magisk data (everything in /data/adb/, except magisk/)
migrator -rm

Restore everything, except system data (D), which is usually incompatible)
migrator -re

Restore not installed user apps+data
migrator -rn


Migrator can backup/restore apps (a), respective data (d) and runtime permissions.

The order of secondary options is irrelevent (e.g., -rda = -rad, "a" and "d" are secondary options).

Everything in /data/adb/, except magisk/ is considered "Magisk data" (m).
After restoring such data, one has to launch Magisk Manager and disable/remove all modules that are or may be incompatible with the [new] ROM.

Accounts, call logs, contacts and SMS/MMS, other telephony and system data (D) restore is not fully guaranteed nor generally recommended.
These are complex databases and often found in variable locations.
You may want to export contacts to a vCard file or use a third-party app to backup/restore all telephony data.

Backups of uninstalled packages are automatically removed at the end of backup and export operations.

For greater compatibility and safety, system apps are not backed up, unless specified as "extras" (see examples).
No APK outside /data/app/ is ever backed up.
Data of specified system apps is always backed up.

Migrator itself is included in backups and exported alongside backup archives.

Backups are stored in /data/migrator/local/.
These take virtually no extra storage space (hard links).

Backups can be exported as individual [compressed] archives (highly recommended).
Data is exported to /sdcard/Download/migrator/exported/ by default - and imported to "/data/migrator/local/".
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
# This is a script that daemonizes "migrator -B" to automate backups.
/path/to/busybox start-stop-daemon -bx /path/to/migrator -S -- -B
exit 0

Config for Magisk and init.d
# /data/migrator.conf
# Default config, same as a blank file
# Note: this is not created automatically.
cmd="migrator -be && migrator -e" # Commands to run
freq=24 # Every 24 hours
delay=60 # Starting 60 minutes after boot

Sample Tasker Script
#!/system/bin/sh
# /data/my-tasker-script
# su -c /data/my-tasker-script
# This requires read and execute permissions to run
(migrator -be
migrator -e -d /storage/XXXX-XXXX &)

Debugging
Verbose is redirected to "/dev/migrator.log".


FULL DATA MIGRATION STEPS AND NOTES

Notes
- If you have to format data, export backups to external storage after step 1 below (-e -d /storage/XXXX-XXXX) and later import with -i -d storage/XXXX-XXXX).
- If you use a different root method, ignore Magisk-related steps.
- In "-beM", the "M" sub-option means "move hard link backups to internal sdcard, so that they survive factory resets".
  When launched without the -m (move) option (i.e., migrator -m), Migrator automatically moves hard link backups back to /data/migrator/local/, for convenience.
- Using a terminal emulator app other than NetHunter means you have to exclude it from backups/restores or detach migrator from it.

1. Backup everything, except system apps: "migrator -beM".

2. Install the [new] ROM (factory reset implied), addons as desired - and root it.

3. Once Android boots, flash migrator from Magisk Manager.
Rebooting is not required.

6. Restore all apps+data, settings and Magisk data: "migrator -re".

7. Launch Magisk Manager and disable/remove all restored modules that are or may be incompatible with the [new] ROM.

8. Reboot.


SYSTEM DATA (D)

If you find any issue after restoring system data (-rD), remove the associated files with "su -c rm <line>".

/data/system_?e/0/accounts_?e.db*
/data/misc/adb/adb_keys
/data/misc/bluedroid/bt_config.conf
/data/misc/wifi/WifiConfigStore.xml
/data/misc/wifi/softap.conf
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

rsync can be used in auto-backup config to sync backups over an SSH tunnel.
e.g., cmd="migrator -be && rsync -a --del $bkp_dir vr25@192.168.1.33:migrator"
```
