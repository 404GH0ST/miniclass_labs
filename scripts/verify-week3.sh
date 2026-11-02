#!/usr/bin/env bash
set -euo pipefail

target="${1:-192.168.56.30}"
tmp_dir="$(mktemp -d)"
flags=()

cleanup() {
  rm -f "$tmp_dir/smb.txt" "$tmp_dir/blog.html" "$tmp_dir/status.html"
  rmdir "$tmp_dir"
}
trap cleanup EXIT

if [[ ! "$target" =~ ^[0-9a-fA-F:.]+$ ]]; then
  printf '[FAIL] Target must be an IPv4 or IPv6 address.\n' >&2
  exit 1
fi

for command in curl nc smbclient ssh; do
  command -v "$command" >/dev/null || {
    printf '[FAIL] Required command is missing: %s\n' "$command" >&2
    exit 1
  }
done

check_tcp() {
  local port="$1"
  local name="$2"
  nc -z -w 3 "$target" "$port"
  printf '[OK] %s TCP/%s open\n' "$name" "$port"
}

record_flag() {
  local service="$1"
  local content="$2"
  local flag
  flag="$(grep -Eo 'WRI\{[0-9a-f]{32}\}' <<<"$content" | sed -n '1p')"
  test -n "$flag"
  flags+=("$flag")
  printf '[OK] %s flag: %s\n' "$service" "$flag"
}

check_tcp 22 SSH
check_tcp 80 HTTP
check_tcp 445 SMB
check_tcp 11279 'Status service'

record_flag SSH "$(nc -w 3 "$target" 22 || true)"

curl --connect-timeout 5 --max-time 15 --fail --silent \
  --resolve "blog.wri.test:80:${target}" http://blog.wri.test/staging/notes.txt \
  >"$tmp_dir/blog.html"
record_flag HTTP "$(<"$tmp_dir/blog.html")"

curl --connect-timeout 5 --max-time 15 --fail --silent \
  --resolve "blog.wri.test:80:${target}" http://blog.wri.test/ >"$tmp_dir/index.html"
if grep -q 'WRI{' "$tmp_dir/index.html"; then
  printf '[FAIL] The blog landing page must not leak the flag.\n' >&2
  exit 1
fi
printf '[OK] Blog landing page is clean; the flag needs /staging/ enumeration.\n'

placeholder="$(curl --connect-timeout 5 --max-time 15 --fail --silent \
  "http://${target}/")"
if ! grep -q 'wri.test' <<<"$placeholder"; then
  printf '[FAIL] Placeholder page must hint at the wri.test domain.\n' >&2
  exit 1
fi
if grep -q 'WRI{' <<<"$placeholder"; then
  printf '[FAIL] The placeholder vhost must not leak any flag.\n' >&2
  exit 1
fi
printf '[OK] Placeholder hints at wri.test without leaking flags.\n'

smbclient -N "//${target}/public" -c "get flag.txt $tmp_dir/smb.txt" >/dev/null
record_flag SMB "$(<"$tmp_dir/smb.txt")"

curl --connect-timeout 5 --max-time 15 --fail --silent \
  "http://${target}:11279/" >"$tmp_dir/status.html"
record_flag STATUS "$(<"$tmp_dir/status.html")"

unique_count="$(printf '%s\n' "${flags[@]}" | sort -u | wc -l | tr -d ' ')"
test "$unique_count" -eq 4

printf '[OK] All 4 services returned unique deployment-specific MD5 flags.\n'
