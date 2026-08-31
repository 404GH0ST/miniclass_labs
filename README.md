# Miniclass Cybersecurity Labs

This project provides disposable Vagrant targets for the Week 3–8 cybersecurity miniclass. Each week has its own Ubuntu 24.04 VM, Ansible configuration, host-only IP address, and reset boundary.

Weeks 1 and 2 do not use Vagrant.

## Requirements

- Vagrant 2.4 or newer
- VirtualBox 7
- Ansible Core on the host
- Week 4: 4 GB RAM and 2 CPU cores
- Week 8: 8 GB RAM and 4 CPU cores

## Setup

From this directory, validate the configuration and start the required week by name:

```bash
vagrant validate
vagrant up week4
```

Each VM uses a host-only address for local administration and testing:

| Week | Address |
|---|---:|
| `week3` | `192.168.56.30` |
| `week4` | `192.168.56.40` |
| `week5` | `192.168.56.50` |
| `week6` | `192.168.56.60` |
| `week7` | `192.168.56.70` |
| `week8` | `192.168.56.80` |

Start additional targets explicitly when needed:

```bash
vagrant up week4 week5
```

Do not use a bare `vagrant up`; weekly targets are intentionally opt-in.

## Optional Classroom Network

To give participants on an isolated classroom LAN access to a target, set `WRI_LAB_BRIDGE_INTERFACE` to the exact VirtualBox adapter name before starting it:

```bash
WRI_LAB_BRIDGE_INTERFACE="wlp3s0" vagrant up week4
```

On PowerShell:

```powershell
$env:WRI_LAB_BRIDGE_INTERFACE = "Intel(R) Wi-Fi 6 AX201 160MHz"
vagrant up week4
```

Find the bridged address after startup:

```bash
vagrant ssh week4 -c "ip -4 -brief address"
```

Both Week 4 and Week 8 support this opt-in bridge. Use it only on a dedicated classroom VLAN or isolated lab router. Week 8 intentionally exposes unauthenticated RCE through its HTTP challenge, so never bridge either target to campus, home, public Wi-Fi, or an internet-routed network.
