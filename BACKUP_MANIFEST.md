# Sandbox Backup Manifest

Repo: pikyxdev/sandbox-backup (private)
Created: 2026-11-25
Purpose: durable copy of work done in the Z.ai sandbox. The sandbox is
ephemeral and gets recycled; files under /home/z/my-project/ do not
survive a recycle, so this repo is the source of truth for finished work.

## How backups work
- BACKUP: ask the assistant to "back up my project" - files under
  /home/z/my-project/ (download/, scripts/) are committed here via the
  GitHub plugin. Auth is handled outside the sandbox, nothing to re-login.
- RESTORE: from any fresh sandbox, ask to "restore my project from
  sandbox-backup" - files are pulled back into /home/z/my-project/.

## Environment snapshot (2026-11-25)
- Linux x86_64, user z, 4 GB RAM, ~8 GB free disk
- git 2.47.3, Python 3.12.16, Node v24.22.3, npm 11.19.1, bun
- ffmpeg, LibreOffice (soffice), pandoc, pdftoppm, jq, gcc/g++/make
- 2,309 executables in PATH (full inventory: sandbox_binaries.txt)
- No rclone, gh, cloud CLIs or ssh - all cloud sync goes through plugins
- Network: ~530 Mbps down / ~356 Mbps up (measured 2026-11-25)

## Verification log
- 2026-11-25: SYNC_TEST.md round trip verified (canary + git blob SHA match)
