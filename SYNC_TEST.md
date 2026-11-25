# Sandbox <-> GitHub Sync Test

- Date: 2026-11-25 (sandbox clock 09:15 UTC)
- Sandbox: Linux x86_64, user z, session web-857f2b2d
- Repo: pikyxdev/sandbox-backup (private)
- Path: sandbox -> GitHub MCP plugin -> GitHub -> read-back verification

## Round-trip protocol
1. This file was written inside the sandbox and pushed via the GitHub plugin.
2. It was immediately read back from GitHub.
3. The git blob SHA of the remote file must equal `git hash-object` of the
   local original (byte-for-byte integrity proof).
4. The canary below must survive unchanged.

CANARY: zai-sync-7f3b9c2e1a

If this canary and the blob SHA check out, the backup pipeline is proven:
after any sandbox wipe, files pushed here can be restored intact.
