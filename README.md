# Miniclass Cybersecurity Labs

This project provides a disposable Vagrant target for the Week 5 cybersecurity miniclass. The target runs Ubuntu 24.04 with its own Ansible configuration, host-only IP address, and reset boundary.

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

Start the target explicitly with `vagrant up week5`.

## Optional Classroom Network

To give participants on an isolated classroom LAN access to a target, set `WRI_LAB_BRIDGE_INTERFACE` to the exact VirtualBox adapter name before starting it:

```bash
WRI_LAB_BRIDGE_INTERFACE="wlp3s0" vagrant up week5
```

On PowerShell:

```powershell
$env:WRI_LAB_BRIDGE_INTERFACE = "Intel(R) Wi-Fi 6 AX201 160MHz"
vagrant up week5
```

Find the bridged address after startup:

```bash
vagrant ssh week5 -c "ip -4 -brief address"
```

Week 5 supports this opt-in bridge. Use it only on a dedicated classroom VLAN or isolated lab router.
