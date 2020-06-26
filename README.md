Migrator - Android Backup Solution and ROM Migration Utility

It can backup/restore apps (including split APKs and SSAIDs) with respective data and runtime permissions, system and Magisk data (including settings).

ZERO warranties, use at your own risk!

Install as a regular Magisk module (no reboot needed afterwards, though).
Alternatively, you can extract `system/bin/migrator` from the zip and run it as `sh filepath` (yes, no Magisk installation required).

The documentation is bundled.
Refer to `migrator --help` or `M -h`.
It can be exported to a file: `M -h > file`

If these executables aren't readily available (before a reboot), use `/dev/migrator` or `/dev/M`.


v2020.6.26-beta (202006260)

Backup app data modes (ditch hard-coded values).
Backup battery optimization whitelist (deviceidle.xml) as part of system data.
Backup Magisk data modes and ownership.
Fixed wifi hotspot settings backup not working.
General optimizations
Perform stricter safety checks during SSAIDs restore.

WARNING
  This version will fail to restore data backed up with previous versions.
  Use the backup creator (backed itself up too): `/data/media/migrator/bkp*/migrator.sh`.


v2020.6.25-beta (202006250)

Restore app specific Android IDs.
Fixed accounts backup not working.
Optimized parsing of options to avoid conflicts with certain package names.


v2020.6.24-beta (202006240)

Backup/restore accounts, call logs, contacts and SMS/MMS as well.
Backup runtime permissions directly from the dedicated XML file.
Fixed mkdir issue.
Backup app specific Android IDs. Restore is WIP.
More modular system data backup method
Use `more` instead of `less` (buggy scrolling) for displaying the help text.
