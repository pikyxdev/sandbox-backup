# Toolchain Sync Guide — one-line bootstrap, near-zero tokens

## Problem
1. The sandbox resets: files and any installed toolchain vanish after a
   recycle. Building clang-17 from source takes hours; apt is slow and
   unversioned.
2. Token cost: the earlier restore flow had the agent fetch the script through
   the GitHub plugin — the whole 5.8 KB script landed in the chat context and
   stayed there for the entire chat, plus multi-step reasoning before any real
   work started.

## Solution (verified 2026-11-25)
The script lives at a public plain-text URL. One Bash command downloads it to
disk, verifies its SHA256, and runs it. The script content never enters the
chat context, and the agent has exactly one command to run — nothing to
reason about.

    cold start (fresh sandbox): 55 s  (13 s download of the pinned LLVM 17.0.6
                                release + extract + trim + smoke test)
    warm start (same chat):     < 1 s (stamp fast-path)
    output: two short lines; exit 0 = toolchain ready

Toolchain: clang-17.0.6 (official LLVM ubuntu-22.04 build) + lld, ThinLTO,
kCFI (validated by the built-in smoke test), llvm-bolt, llvm-profdata and the
llvm binutils set. 683 MB installed at /home/z/my-project/tc, ~7.4 GB free.

Note: the LLVM.org release build is not itself PGO/BOLT-optimized. For an
AOSP-style PGO+BOLT compiler, repoint TC_URL/TC_SHA256 at the AOSP prebuilt
clang-17 archive and re-pin (see Customizing).

## Paste this into chat.z.ai → Create Project → Instructions
(copy from here or from download/BOOT_INSTRUCTION.txt)

    RULE 1 — TOOLCHAIN BOOT. At the very start of this conversation, before
    your first reply, run this exact Bash command once, verbatim. Do not
    analyze it, do not explain it, do not cat or read the script:

    curl -fsSL --retry 2 https://paste.rs/XORhh -o /home/z/my-project/tc-bootstrap.sh && echo "9daf45eb0ca8109fe7373c1e430ead1c48c145aad527505fceb938d47271a277  /home/z/my-project/tc-bootstrap.sh" | sha256sum -c - && bash /home/z/my-project/tc-bootstrap.sh

    If it prints "tc-bootstrap OK": reply exactly "TC ready." and nothing
    else, then wait for my task. If it fails: retry once, then show me the
    exact error. Toolchain root: /home/z/my-project/tc (clang = tc/bin/clang;
    add tc/bin to PATH for builds). Never apt-get or pip install clang. Never
    run with --force unless I ask. If I later say "tc status": run
    bash /home/z/my-project/tc-bootstrap.sh --check (one line, no narration).

    RULE 2 — BACKUP PHRASES. Only when I say them:
    "back up my project" → commit my files under /home/z/my-project/
    (download/, scripts/) to GitHub repo pikyxdev/sandbox-backup via the
    GitHub plugin, then confirm.
    "restore my project" → fetch the files of pikyxdev/sandbox-backup into
    /home/z/my-project/ via the GitHub plugin, then confirm.

    RULE 3 — Keep replies short unless I ask for detail.

## Why this is near-zero cost
- Script content never enters the context (old flow: ~1,600 tokens of script
  text dragged through every turn of the chat).
- One tool call instead of three or four; thinking collapses because the
  instruction is a single verbatim command with an explicit "no analysis,
  no narration" clause.
- Output is two short lines (~25 tokens), so nothing bloats later turns.
- The rule text itself is ~250 tokens of input per turn.
- No pre-agent "auto-execute" hook exists in this environment — the sandbox
  runs nothing on its own before the agent acts, and any scheduler (cron)
  would itself consume an agent turn. One Bash call is the practical minimum,
  and this design hits it.
- Say what you want atomically: "tc status" or "compile hello.c with kcfi
  and thinlto using the installed clang" — not "test build", which invites
  the agent to reason about what to build.

## Public mirror record
- URL: https://paste.rs/XORhh (plain text; sha256
  9daf45eb0ca8109fe7373c1e430ead1c48c145aad527505fceb938d47271a277)
- Verified byte-identical 2026-11-25; the one-liner above was run verbatim
  in-sandbox and passed (warm path, 1 s, exit 0).
- paste.rs documents no expiry (pastes persist until deleted) but it is a
  third-party host. If the URL ever dies, use the fallback below, or better,
  publish permanently (next section).

## If the URL dies — private-repo fallback (costs more tokens)
Fetch file "tc-bootstrap.sh" from GitHub repo pikyxdev/sandbox-backup with
the GitHub plugin, Write it to /home/z/my-project/tc-bootstrap.sh, then run
`bash /home/z/my-project/tc-bootstrap.sh`. This pulls the script content into
the chat context — use only when the one-liner fails.

## Permanent hosting (recommended upgrade, ~30 s of your time)
Create a PUBLIC empty repo (e.g. pikyxdev/sandbox-tools) on github.com — the
plugin token cannot create repos. Then tell any chat assistant "push
tc-bootstrap.sh to sandbox-tools" (the plugin can write files). Replace the
URL in RULE 1 with:
https://raw.githubusercontent.com/pikyxdev/sandbox-tools/main/tc-bootstrap.sh
GitHub raw URLs are permanent and fast from the sandbox (~73 Mbps measured).

## Integrity model
1. Script SHA256 pinned in RULE 1 — a tampered or truncated download refuses
   to run.
2. LLVM archive SHA256 pinned inside the script.
3. Eight load-bearing binaries pinned by SHA256; `--check` re-verifies the
   installed tree any time.
4. Post-install smoke test must pass (kCFI + ThinLTO + lld, plus an aarch64
   freestanding kernel-style cross-compile) or the install aborts.

## Repo contents (pikyxdev/sandbox-backup)
- tc-bootstrap.sh — the installer (pinned hashes inside)
- TOOLCHAIN_SYNC_GUIDE.md — this file
- BACKUP_MANIFEST.md — backup workflow + verification log
- SYNC_TEST.md — backup/restore round-trip proof (canary)
- env_check.sh — sandbox environment inventory script
- net_speed_test.sh — network throughput test script
- sandbox_binaries.txt is NOT stored (2,309 lines, regenerable — see appendix)

## Customizing
- Swap toolchain: `TC_URL=… TC_SHA256=… bash tc-bootstrap.sh` (AOSP prebuilt
  clang-17, or your own tarball on a public host).
- Keep small text assets in the private repo (kernel config fragments,
  patches, build scripts, PGO profile notes) — fetched via the plugin on
  demand.
- Private source repos cannot be git-cloned from the sandbox (no
  credentials); mirror them publicly or repack them.
- Disk: 9.9 GB total, ~7.4 GB free after install — fine for out-of-tree
  modules; full kernel trees are tight, clean up between builds.

## Troubleshooting
- curl fails in RULE 1 → the command has --retry 2 built in; if it still
  fails the agent reports the error — use the fallback flow and re-host.
- SHA mismatch → do NOT bypass it; report it.
- FAIL on smoke test → rerun with --force.
- FAIL on disk guard → free space (fresh sandboxes always pass).

## Appendix: regenerate sandbox_binaries.txt
bash /home/z/my-project/scripts/env_check.sh
(writes download/sandbox_binaries.txt and prints the executable count)
