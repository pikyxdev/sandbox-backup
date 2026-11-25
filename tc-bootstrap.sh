#!/usr/bin/env bash
# tc-bootstrap.sh - one-shot clang-17 kernel toolchain for the Z.ai sandbox
#
# Spec covered: clang-17.0.6 | ThinLTO + kCFI validated by smoke test |
#               llvm-bolt + llvm-profdata included (BOLT / PGO tooling)
# Default mode is SELF-CONTAINED: downloads the official LLVM release,
# verifies its SHA256, extracts, trims to kernel-build essentials,
# smoke-tests the exact spec flags, and stamps the install.
# Override TC_URL + TC_SHA256 env vars to point at your own repacked
# tarball (e.g. a GitHub Release asset in a public repo of yours).
#
# Idempotent: warm start exits in under 1 second via the stamp file.
# Prints one line. Exit 0 = toolchain ready at $TC_DIR.
#
# Usage: bash tc-bootstrap.sh [--check|--force]
#   (no arg)  install if needed, fast-exit when already verified
#   --check   verify only (8 pinned binary hashes), never downloads
#   --force   wipe and reinstall from scratch
set -euo pipefail

TC_URL_DEFAULT="https://github.com/llvm/llvm-project/releases/download/llvmorg-17.0.6/clang%2Bllvm-17.0.6-x86_64-linux-gnu-ubuntu-22.04.tar.xz"
TC_SHA256_DEFAULT="884ee67d647d77e58740c1e645649e29ae9e8a6fe87c1376be0f3a30f3cc9ab3"
TC_DIR_DEFAULT="/home/z/my-project/tc"
TC_ID="clang-17.0.6-kernel-min"
TC_URL="${TC_URL:-$TC_URL_DEFAULT}"
TC_SHA256="${TC_SHA256:-$TC_SHA256_DEFAULT}"
TC_DIR="${TC_DIR:-$TC_DIR_DEFAULT}"
TC_KEEP_CACHE="${TC_KEEP_CACHE:-0}"
CACHE_DIR="/home/z/my-project/tc-cache"
CACHE="$CACHE_DIR/tc.tar.xz"
STAMP="$TC_DIR/.tc-stamp"
SELFTEST="/home/z/my-project/scripts/tc-selftest"

# kernel-build keep-set (NOTE: includes symlink targets like llvm-readobj)
KEEP_BIN="clang clang++ clang-17 lld ld.lld llvm-readobj llvm-readelf llvm-ar llvm-ranlib llvm-nm llvm-objcopy llvm-strip llvm-objdump llvm-strings llvm-profdata llvm-bolt llvm-bolt-heatmap merge-fdata llvm-symbolizer"

# pinned SHA256 of the 8 load-bearing binaries (sha256sum -c format)
MANIFEST="d8e993285cc7a68bb6c6e4010206213964e4fa7e6b70197f04c8bffa5ed8a414  clang-17
ad72ab9175d4890687c13674065cbb76881502b028078ed3443a8f899c6e169e  lld
4ed851739c360116f133485d1a6c11abc40f8ebc64d815b729561ffc9fecfa94  llvm-bolt
5a150170f3f89fa3008c21f857ab25ae80b3ab58ac79315c95fda3f58c3533a7  llvm-ar
70a5d3f9bc94b0f9b837b5d807f66367a3dd6650f0106f1a07bad93811114255  llvm-nm
e1eceaf6e5d5bdcaf7cd5db13701194588dd6d593668a838120eae2d2749b8c1  llvm-objcopy
ff75a9523ddf944e744efb141eac0512ce38c9036768a9fbabd9a19deea52ad8  llvm-readobj
4f2395374b851be8f2db282cfe1e9b94b184428586745b8d76b8da65a4e4eb43  llvm-profdata"

MODE="${1:-}"

die() { echo "tc-bootstrap FAIL: $*" >&2; exit 1; }
ok()   { echo "tc-bootstrap OK: $*"; exit 0; }

glibc_ok() {
  V=$(ldd --version 2>&1 | sed -n '1s/.* \([0-9][0-9.]*\)$/\1/p')
  awk -v v="$V" 'BEGIN{split("2.35",m,".");split(v,a,".");exit !(a[1]>m[1]||(a[1]==m[1]&&a[2]>=m[2]))}'
}

verify_tree() {
  local sha name
  while read -r sha name; do
    [ -x "$TC_DIR/bin/$name" ] || return 1
    printf '%s  %s\n' "$sha" "$TC_DIR/bin/$name" | sha256sum -c - >/dev/null 2>&1 || return 1
  done <<EOF
$MANIFEST
EOF
}

smoke() {
  mkdir -p "$SELFTEST"
  printf '#include <stdarg.h>\n#include <stddef.h>\nint main(void){va_list v;(void)v;size_t z=0;(void)z;return 0;}\n' > "$SELFTEST/hello.c"
  printf 'int mod_init(void){return 0;}\n' > "$SELFTEST/xmod.c"
  "$TC_DIR/bin/clang" -target x86_64-linux-gnu -B"$TC_DIR/bin/" -fuse-ld=lld \
    -fsanitize=kcfi -flto=thin "$SELFTEST/hello.c" -o "$SELFTEST/hello_lto" >/dev/null 2>&1
  "$TC_DIR/bin/clang" -target aarch64-linux-gnu -fsanitize=kcfi -flto=thin \
    -ffreestanding -fno-stack-protector -c "$SELFTEST/xmod.c" -o "$SELFTEST/xmod.o" >/dev/null 2>&1
}

trim_tc() {
  local f k keep e
  for f in "$TC_DIR"/bin/*; do
    keep=no
    for k in $KEEP_BIN; do
      if [ "$(basename "$f")" = "$k" ]; then keep=yes; fi
    done
    if [ "$keep" = "no" ]; then rm -f "$f"; fi
  done
  for e in "$TC_DIR"/lib/*; do
    case "$(basename "$e")" in
      clang) ;;
      *) rm -rf "$e" ;;
    esac
  done
  rm -rf "$TC_DIR/include" "$TC_DIR/share" "$TC_DIR/local"
}

install_tc() {
  glibc_ok || die "sandbox glibc too old (this build needs >= 2.35)"
  AVAIL_MB=$(df -Pm / | awk 'NR==2{print $4}')
  if [ "$AVAIL_MB" -lt 7500 ]; then die "need ~7.5GB free during install, have ${AVAIL_MB}MB"; fi
  mkdir -p "$CACHE_DIR" "$TC_DIR"
  if ! printf '%s  %s\n' "$TC_SHA256" "$CACHE" | sha256sum -c - >/dev/null 2>&1; then
    curl -fsSL --retry 3 --retry-delay 2 -o "$CACHE.dl" "$TC_URL" >/dev/null 2>&1 || die "download failed: $TC_URL"
    printf '%s  %s\n' "$TC_SHA256" "$CACHE.dl" | sha256sum -c - >/dev/null 2>&1 || die "archive SHA256 mismatch (expected $TC_SHA256)"
    mv -f "$CACHE.dl" "$CACHE"
  fi
  rm -rf "${TC_DIR:?}"/*
  if xz -dc -T0 "$CACHE" 2>/dev/null | tar -x -C "$TC_DIR" --strip-components=1; then
    :
  else
    tar -xJf "$CACHE" -C "$TC_DIR" --strip-components=1 || die "extract failed"
  fi
  trim_tc
  smoke || die "post-install smoke test failed (kCFI/ThinLTO/lld)"
  printf '%s\n' "$TC_ID|$TC_SHA256" > "$STAMP"
  if [ "$TC_KEEP_CACHE" != "1" ]; then rm -f "$CACHE"; fi
}

case "$MODE" in
  --check)
    verify_tree || die "toolchain missing or binary hash mismatch (run without args to install)"
    ok "verified $TC_ID - all 8 pinned binary hashes match"
    ;;
  --force)
    install_tc
    ok "installed $TC_ID (cold install, smoke-tested)"
    ;;
  *)
    if [ -f "$STAMP" ] && [ -x "$TC_DIR/bin/clang-17" ]; then
      CUR=""
      read -r CUR < "$STAMP" || true
      if [ "$CUR" = "$TC_ID|$TC_SHA256" ]; then
        ok "$TC_ID (warm - stamp valid)"
      fi
    fi
    if verify_tree; then
      printf '%s\n' "$TC_ID|$TC_SHA256" > "$STAMP"
      ok "$TC_ID (verified 8 binary hashes, stamp refreshed)"
    fi
    install_tc
    ok "installed $TC_ID (cold install, smoke-tested)"
    ;;
esac
