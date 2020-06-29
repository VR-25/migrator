Migrator - Android Backup Solution and ROM Migration Utility

It can backup/restore apps (including split APKs and SSAIDs) with respective data and runtime permissions, Magisk data and generic Android settings.

ZERO warranties, use at your own risk!
This is still in beta. Backup your data before using.

Install as a regular Magisk module (no reboot needed afterwards, though).
Alternatively, you can extract `system/bin/migrator` from the zip and run it as `sh filepath` (yes, no Magisk installation required).

The documentation is bundled.
Refer to `migrator --help` or `M -h`.
It can be exported to a file: `M -h > file`

If these executables aren't readily available (before a reboot), use `/dev/migrator` or `/dev/M`.


v2020.6.29-beta.1 (202006291)

Fixed "lzop, parameter not set" and SSAID related issues.

WARNING
This version will fail to restore data backed up with previous versions.
Use the backup creator (backed itself up too): `/data/media/migrator/bkp*/migrator.sh`.


v2020.6.29-beta (202006290)

`--export` and `--import` are more advanced and flexible. Refer to the help text for details.
`--export` creates individual archives for each backup.
Automatic `M --ssaid` runs syncronously.
Enhanced SSAID restore.
Major fixes & optimizations
Updated help text.


v2020.6.26-beta (202006260)

Backup app data modes (ditch hard-coded values).
Backup battery optimization whitelist (deviceidle.xml) as part of system data.
Backup Magisk data modes and ownership.
Fixed wifi hotspot settings backup not working.
General optimizations
Perform stricter safety checks during SSAIDs restore.
