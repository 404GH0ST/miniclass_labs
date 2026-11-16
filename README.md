# Miniclass Cybersecurity Labs

This project provides disposable Vagrant targets for the Week 5 cybersecurity miniclass. Each target runs Ubuntu 24.04 with its own host-only IP address and reset boundary.

## Requirements

- Vagrant 2.4 or newer
- VirtualBox 7
- Ansible Core on the host
- Week 5: 4 GB RAM and 2 CPU cores

## Setup

From this directory, validate the configuration and start the Week 5 target:

```bash
vagrant validate
vagrant up week5
```

The VM uses a host-only address for local administration and testing:

| Week | Address |
|---|---:|
| `week5` | `192.168.56.50` |
| `week5_demo` | `192.168.56.51` |

Start each target explicitly. `week5` is the participant challenge with deployment-specific flags. `week5_demo` uses the same ten enumeration services and replaces their flags with synthetic sensitive records, such as passwords, recovery codes, and API keys. The demo values are examples, not real credentials.

```bash
vagrant up week5_demo
scripts/verify-services.sh 192.168.56.51 week5_demo
```

The demo exposes `internal-notes.txt` over FTP, SMB, rsync, and NFS. Other records appear in the SSH and SMTP banners, SNMP system location, POP3 and IMAP mailboxes, and DNS zone transfer. The SNMP contact still reveals the training mailbox credentials, and a mailbox message reveals the training SSH account. Run `scripts/verify-services.sh` for the original `week5` target.

## Optional Classroom Network

To give participants on an isolated classroom LAN access to a target, set `WRI_LAB_BRIDGE_INTERFACE` to the exact VirtualBox adapter name before starting it:

```bash
WRI_LAB_BRIDGE_INTERFACE="wlp3s0" vagrant up week5_demo
```

On PowerShell:

```powershell
$env:WRI_LAB_BRIDGE_INTERFACE = "Intel(R) Wi-Fi 6 AX201 160MHz"
vagrant up week5_demo
```

Find the bridged address after startup:

```bash
vagrant ssh week5_demo -c "ip -4 -brief address"
```

Both Week 5 targets support this opt-in bridge. Use it only on a dedicated classroom VLAN or isolated lab router.
