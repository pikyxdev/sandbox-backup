#!/usr/bin/env bash
# env_check.sh - Sandbox environment & binary inventory
# Writes the full executable list to /home/z/my-project/download/sandbox_binaries.txt

OUT=/home/z/my-project/download/sandbox_binaries.txt
mkdir -p /home/z/my-project/download

echo "=== NOW ==="
date
echo

echo "=== SYSTEM ==="
echo "user   : $(whoami)"
echo "kernel : $(uname -sr)"
echo "arch   : $(uname -m)"
echo

echo "=== PATH DIRECTORIES ==="
echo "$PATH" | tr ':' '\n' | sed '/^$/d'
echo

echo "=== CLOUD / SYNC TOOLS ==="
for tool in rclone rsync restic borg borgbackup unison lsyncd inotifywait git git-annex gh hub gcloud gsutil aws s3cmd az megatools kopia duplicity; do
  if command -v "$tool" >/dev/null 2>&1; then
    printf "  FOUND  : %-12s %s\n" "$tool" "$(command -v "$tool")"
  else
    printf "  missing: %s\n" "$tool"
  fi
done
echo

echo "=== DEV / MEDIA / OFFICE TOOLS ==="
for tool in python3 pip3 pip node npm npx yarn pnpm bun deno go rustc cargo gcc g++ make cmake jq yq sqlite3 psql mysql ffmpeg ffprobe convert magick soffice libreoffice pdftoppm pandoc wkhtmltopdf zip unzip tar xz 7z gzip tmux screen htop curl wget ssh scp sftp docker podman; do
  if command -v "$tool" >/dev/null 2>&1; then
    printf "  FOUND  : %-12s %s\n" "$tool" "$(command -v "$tool")"
  else
    printf "  missing: %s\n" "$tool"
  fi
done
echo

echo "=== PACKAGE MANAGERS / PRIVILEGE ==="
for tool in apt apt-get dpkg snap brew conda mamba nix; do
  command -v "$tool" >/dev/null 2>&1 && echo "  FOUND  : $tool"
done
echo "  sudo  : $(command -v sudo 2>/dev/null || echo 'not available')"
echo "  uid   : $(id -u)"
echo

echo "=== KEY VERSIONS ==="
git --version 2>/dev/null || echo "git    : n/a"
python3 --version 2>/dev/null || echo "python3: n/a"
node --version 2>/dev/null || echo "node   : n/a"
npm --version 2>/dev/null || echo "npm    : n/a"
echo

echo "=== DISK & MEMORY ==="
df -h / | sed -n '2p'
free -h | sed -n '2p'
echo

echo "=== FULL BINARY INVENTORY ==="
BIN_COUNT=0
{
  for d in $(echo "$PATH" | tr ':' '\n' | sed '/^$/d' | sort -u); do
    if [ -d "$d" ] && [ -x "$d" ]; then
      printed_header=0
      for f in "$d"/*; do
        if [ -f "$f" ] && [ -x "$f" ]; then
          if [ "$printed_header" -eq 0 ]; then
            echo "### $d"
            printed_header=1
          fi
          printf '%s\n' "$(basename "$f")"
          BIN_COUNT=$((BIN_COUNT+1))
        fi
      done
      if [ "$printed_header" -eq 1 ]; then
        echo
      fi
    fi
  done
} > "$OUT"
echo "Executables in PATH: $BIN_COUNT"
echo "Full list written to: $OUT"
