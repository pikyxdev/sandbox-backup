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
- TOOLCHAIN: never backed up as files (683 MB) - it is rebuilt in ~55 s by
  tc-bootstrap.sh; see TOOLCHAIN_SYNC_GUIDE.md for the one-line boot.

## Repo contents
- tc-bootstrap.sh - pinned clang-17.0.6 toolchain installer
- TOOLCHAIN_SYNC_GUIDE.md - one-line boot flow, token-cost notes, fallbacks
- SYNC_TEST.md - backup/restore round-trip proof (canary)
- BACKUP_MANIFEST.md - this file
- env_check.sh - environment inventory (regenerates sandbox_binaries.txt)
- net_speed_test.sh - network throughput test
- PIKY.md - user note
- sandbox_binaries.txt is intentionally NOT stored: regenerable via
  env_check.sh, and pushing ~2,300 lines through the chat would waste a
  large amount of tokens for near-zero value.

## Public mirror
tc-bootstrap.sh is also hosted as plain text for one-liner bootstrap:
https://paste.rs/XORhh
sha256: 9daf45eb0ca8109fe7373c1e430ead1c48c145aad527505fceb938d47271a277
If it dies: this repo is the fallback source; the guide describes the
permanent public-repo option (pikyxdev/sandbox-tools).

## Environment snapshot (2026-11-25)
- Linux x86_64, user z, 4 GB RAM, ~8 GB free disk
- git 2.47.3, Python 3.12.16, Node v24.22.3, npm 11.19.1, bun
- ffmpeg, LibreOffice (soffice), pandoc, pdftoppm, jq, gcc/g++/make
- 2,309 executables in PATH (regenerate with env_check.sh)
- No rclone, gh, cloud CLIs or ssh - all cloud sync goes through plugins
- Network: ~530 Mbps down / ~356 Mbps up (measured 2026-11-25)

## Verification log
- 2026-11-25: SYNC_TEST.md round trip verified (canary + git blob SHA match)
- 2026-11-25: tc-bootstrap.sh blob SHA verified after push (19f3d0e5...)
- 2026-11-25: cold install 55 s / warm < 1 s / --check pass / corruption
  correctly reported FAIL
- 2026-11-25: public mirror uploaded, byte-identical round trip; the full
  one-liner (curl + sha256 -c + bash) run verbatim in-sandbox: exit 0, 1 s
