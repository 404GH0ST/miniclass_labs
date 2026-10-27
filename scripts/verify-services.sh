#!/usr/bin/env bash
set -euo pipefail

target="${1:-192.168.56.50}"
tmp_dir="$(mktemp -d)"
flags=()

cleanup() {
  rm -f "$tmp_dir/smb.txt" "$tmp_dir/rsync-flag.txt"
  rmdir "$tmp_dir"
}
trap cleanup EXIT

if [[ ! "$target" =~ ^[0-9a-fA-F:.]+$ ]]; then
  printf '[FAIL] Target must be an IPv4 or IPv6 address.\n' >&2
  exit 1
fi

for command in curl dig nc rsync smbclient snmpget snmpwalk showmount vagrant; do
  command -v "$command" >/dev/null || {
    printf '[FAIL] Required command is missing: %s\n' "$command" >&2
    exit 1
  }
done

check_tcp() {
  local port="$1"
  local name="$2"
  nc -z -w 3 "$target" "$port"
  printf '[OK] %s TCP/%s\n' "$name" "$port"
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

check_tcp 21 FTP
check_tcp 22 SSH
check_tcp 25 SMTP
check_tcp 53 DNS
check_tcp 110 POP3
check_tcp 139 SMB
check_tcp 143 IMAP
check_tcp 445 SMB
check_tcp 873 Rsync
check_tcp 2049 NFS

record_flag FTP "$(curl --connect-timeout 5 --max-time 15 --fail --silent "ftp://${target}/pub/flag.txt")"
record_flag SSH "$(nc -w 3 "$target" 22 || true)"
smtp_result="$(printf 'EHLO verify.wri.local\r\nQUIT\r\n' | nc -w 3 "$target" 25)"
grep -q 'WRI-MAILGATE' <<<"$smtp_result"
record_flag SMTP "$smtp_result"

smbclient -N "//${target}/public" -c "get flag.txt $tmp_dir/smb.txt" >/dev/null
record_flag SMB "$(<"$tmp_dir/smb.txt")"

rsync "rsync://${target}/" | grep -q '^public'
rsync "rsync://${target}/public/flag.txt" "$tmp_dir/rsync-flag.txt" >/dev/null
record_flag RSYNC "$(<"$tmp_dir/rsync-flag.txt")"

record_flag SNMP "$(snmpget -v2c -c public "$target" 1.3.6.1.2.1.1.6.0)"
snmp_system_info="$(snmpwalk -v2c -c public "$target")"
grep -q '/opt/wri-mail-lab.py --username analyst --password MailLab-Only-2026' <<<"$snmp_system_info"
printf '[OK] Default SNMP walk exposes the valid IMAP/POP3 lab credential.\n'
dns_axfr="$(dig "@${target}" wri.local AXFR)"
grep -q 'intranet\.wri\.local\.' <<<"$dns_axfr"
record_flag 'DNS AXFR' "$(grep 'replica-catalog\.wri\.local\.' <<<"$dns_axfr")"

pop3_result="$(printf 'USER analyst\r\nPASS MailLab-Only-2026\r\nRETR 2\r\nQUIT\r\n' | nc -w 3 "$target" 110)"
record_flag POP3 "$pop3_result"
pop3_ssh_mail="$(printf 'USER analyst\r\nPASS MailLab-Only-2026\r\nRETR 3\r\nQUIT\r\n' | nc -w 3 "$target" 110)"
grep -q 'SSH username: operator' <<<"$pop3_ssh_mail"
grep -q 'SSH password: LlYcvWqWdJKvvnNmlruUY/bb' <<<"$pop3_ssh_mail"

imap_result="$(printf 'a1 LOGIN analyst MailLab-Only-2026\r\na2 SELECT INBOX\r\na3 FETCH 2 BODY[]\r\na4 LOGOUT\r\n' | nc -w 3 "$target" 143)"
record_flag IMAP "$imap_result"
imap_ssh_mail="$(printf 'a1 LOGIN analyst MailLab-Only-2026\r\na2 SELECT INBOX\r\na3 FETCH 3 BODY[]\r\na4 LOGOUT\r\n' | nc -w 3 "$target" 143)"
grep -q 'SSH username: operator' <<<"$imap_ssh_mail"
grep -q 'SSH password: LlYcvWqWdJKvvnNmlruUY/bb' <<<"$imap_ssh_mail"

nfs_content="$(vagrant ssh week5 -c \
  "mount_dir=\$(mktemp -d); sudo mount -t nfs -o ro ${target}:/srv/nfs/public \"\$mount_dir\"; cat \"\$mount_dir/flag.txt\"; sudo umount \"\$mount_dir\"; rmdir \"\$mount_dir\"" \
  2>/dev/null)"
record_flag NFS "$nfs_content"

dig +short "@${target}" target.wri.local A | grep -qx "$target"
dig +short "@${target}" intranet.wri.local A | grep -qx "$target"
dig +short "@${target}" -x "$target" | grep -qx 'target.wri.local.'
showmount -e "$target" | grep -q '/srv/nfs/public'

unique_count="$(printf '%s\n' "${flags[@]}" | sort -u | wc -l | tr -d ' ')"
test "$unique_count" -eq 10

printf '[OK] All 10 services returned unique deployment-specific MD5 flags.\n'

if nc -z -w 3 "$target" 80; then
  printf '[FAIL] HTTP must be absent from the Week 5 target.\n' >&2
  exit 1
fi

printf '[OK] HTTP is absent from the Week 5 target.\n'
