Migrator - Android Backup Solution and ROM Migration Utility

It can backup/restore apps (including split APKs) with respective data and runtime permissions, system and Magisk data (including settings).

ZERO warranties, use at your own risk!

Install as a regular Magisk module (no reboot needed afterwards, though).
Alternatively, you can extract `system/bin/migrator` from the zip and run it as `sh filepath` (yes, no Magisk installation required).

The documentation is bundled.
Refer to `migrator --help` or `M -h`.
It can be exported to a file: `M -h > file`

If these executables aren't readily available (before a reboot), use `/dev/migrator` or `/dev/M`.


v2020.6.24-beta (202006240)

Backup/restore accounts, call logs, contacts and SMS/MMS as well.
Backup runtime permissions directly from the dedicated XML file.
Fixed mkdir issue.
Backup app specific Android IDs. Restore is WIP.
More modular system data backup method
Use `more` instead of `less` (buggy scrolling) for displaying the help text.


v2020.6.22-beta (202006220)

Exclude code_cache/ from app data backups.
Fixed app data lib symlink issue.
General optimizations
Refresh APK snapshots after successful restore.
Updated help text.


v2020.6.21-beta (202006210)

Rewritten from scratch.
