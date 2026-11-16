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

The demo exposes `internal-notes.txt` over FTP, SMB, rsync, and NFS. Other records appear in the SSH and SMTP banners, SNMP system location, POP3 and IMAP mailboxes, and DNS zone transfer. The SNMP contact still reveals the training mailbox credentials, and a mailbox message reveals the training SSH account. The demo SSH account is `demo_operator` with a separate password; the participant target keeps its `operator` account. Run `scripts/verify-services.sh` for the original `week5` target.

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

The host-only addresses (`192.168.56.50` and `192.168.56.51`) remain on the VMs. Bridging adds another interface whose IP comes from the classroom network and may change. During provisioning, Ansible detects that IP and publishes it in the `ns1.wri.local` and `target.wri.local` DNS A records. The host-only reverse DNS zone still maps `.50` or `.51` to `target.wri.local`; the classroom router owns reverse DNS for the bridged subnet. Give participants the current bridged IP for their first scan or DNS query.

Keep `WRI_LAB_BRIDGE_INTERFACE` set whenever you run `vagrant reload` or `vagrant provision`; Ansible uses it to enable listeners and access from the classroom network. If DHCP later changes the bridge IP, rerun provisioning with the same variable so the DNS A records are updated. Resolver caches may retain the previous A record for up to 60 seconds:

```bash
WRI_LAB_BRIDGE_INTERFACE="wlp3s0" vagrant provision week5_demo
```

If the VM was already created without a bridge, apply the new network configuration and rerun Ansible with the interface variable set:

```bash
WRI_LAB_BRIDGE_INTERFACE="wlp3s0" vagrant reload week5_demo --provision
```

For `week5`, replace `week5_demo` in these commands with `week5`. To check services and DNS through a bridged address, pass that address to the verifier:

```bash
scripts/verify-services.sh <bridged-ip> week5_demo
scripts/verify-services.sh <bridged-ip> week5
```

Both Week 5 targets support this opt-in bridge. Use it only on a dedicated classroom VLAN or isolated lab router.
