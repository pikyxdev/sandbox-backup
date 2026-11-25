#!/usr/bin/env bash
# net_speed_test.sh - sandbox network throughput test
# 1) Download from user-provided VirtualBox URL (30s sustained sample)
# 2) Download from GitHub codeload (the backup/restore path, 15s sample)
# 3) Upload via POST to a public echo endpoint (httpbin, fallback postman-echo)
set +e

VBOX="https://download.virtualbox.org/virtualbox/7.2.22/VirtualBox-7.2.22-175245-Win.exe"

echo "=== 1. Target check: download.virtualbox.org (user-provided URL) ==="
curl -sSI --max-time 15 "$VBOX" | sed -n '1,5p'
echo

echo "--- 30-second sustained download sample ---"
S=$(curl -sS -o /dev/null --max-time 30 -w '%{speed_download} %{size_download} %{time_total} %{time_connect} %{time_starttransfer}' "$VBOX")
RC=$?
echo "curl exit: $RC (28 = stopped at the 30s cap on purpose)"
if [ -n "$S" ]; then
  echo "$S" | awk '{printf "connect: %.2fs | first byte: %.2fs | transferred: %.1f MB in %.1fs\n", $4, $5, $2/1048576, $3}'
  echo "$S" | awk '{printf "DOWNLOAD (VirtualBox): %.2f MB/s = %.1f Mbps\n", $1/1048576, $1*8/1000000}'
else
  echo "no data returned"
fi
echo

echo "=== 2. GitHub codeload (the restore/download path for backups) ==="
S2=$(curl -sSL -o /dev/null --max-time 15 -w '%{speed_download} %{size_download} %{time_total}' "https://codeload.github.com/git/git/zip/refs/heads/master")
RC2=$?
echo "curl exit: $RC2 (28 = stopped at the 15s cap on purpose)"
if [ -n "$S2" ]; then
  echo "$S2" | awk '{printf "transferred: %.1f MB in %.1fs\n", $2/1048576, $3}'
  echo "$S2" | awk '{printf "DOWNLOAD (GitHub): %.2f MB/s = %.1f Mbps\n", $1/1048576, $1*8/1000000}'
else
  echo "no data returned"
fi
echo

echo "=== 3. UPLOAD test (POST to public speed-test endpoints) ==="
UPLOAD_OK=0
for TARGET in "https://speed.cloudflare.com/__up|8" "https://httpbin.org/post|1" "https://postman-echo.com/post|2"; do
  EP="${TARGET%|*}"; SZ="${TARGET#*|}"
  dd if=/dev/urandom of=/tmp/upload_test.bin bs=1M count="$SZ" status=none
  U=$(curl -sS -o /dev/null --max-time 90 -w '%{speed_upload} %{size_upload} %{time_total}' -X POST --data-binary @/tmp/upload_test.bin -H 'Content-Type: application/octet-stream' "$EP" 2>/dev/null)
  SPD=$(echo "$U" | awk '{print int($1)}')
  COMPLETE=$(echo "$U" | awk -v sz="$SZ" '{print ($2 >= sz*1048576*0.8) ? 1 : 0}')
  if [ -n "$U" ] && [ "${SPD:-0}" -gt 0 ] && [ "${COMPLETE:-0}" -eq 1 ]; then
    echo "$U" | awk -v ep="$EP" -v sz="$SZ" '{printf "endpoint: %s (%s MB payload)\n", ep, sz; printf "sent: %.1f MB in %.1fs\n", $2/1048576, $3; printf "UPLOAD: %.2f MB/s = %.1f Mbps\n", $1/1048576, $1*8/1000000}'
    UPLOAD_OK=1
    break
  else
    echo "  (endpoint failed or truncated the payload: $EP - trying next)"
  fi
done
[ "$UPLOAD_OK" -eq 0 ] && echo "public upload endpoints unreachable; upload capability will be judged from the GitHub push test instead"
rm -f /tmp/upload_test.bin
echo
echo "=== done ==="
