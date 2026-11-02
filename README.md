# Miniclass Cybersecurity Labs

This project provides a disposable Vagrant target for the Week 3 and Week 5
cybersecurity miniclass. Each target runs Ubuntu 24.04 with its own Ansible
configuration, host-only IP address, and reset boundary.

## Requirements

- Vagrant 2.4 or newer
- VirtualBox 7
- Ansible Core on the host
- Week 3: 1 GB RAM and 1 CPU core
- Week 5: 4 GB RAM and 2 CPU cores

## Setup

From this directory, validate the configuration and start a target:

```bash
vagrant validate
vagrant up week3
```

The VMs use a host-only address for local administration and testing:

| Week | Address |
|---|---:|
| `week3` | `192.168.56.30` |
| `week5` | `192.168.56.50` |

Start a target explicitly with `vagrant up week3` or `vagrant up week5`.
A bare `vagrant up` starts nothing; every machine sets `autostart: false`.

### Project directory on NTFS/exFAT

If the repository lives on an NTFS or exFAT mount, `chmod` is a no-op there and
`vagrant up` fails with a "private key ... invalid permissions" error. The
Vagrantfile refuses to start in that situation and points at the remedies:

```bash
# Option 1: wrapper that redirects Vagrant state to $HOME (recommended)
scripts/lab.sh up week3
scripts/lab.sh ssh week3
scripts/lab.sh destroy week3 --force

# Option 2: export the data directory yourself
export VAGRANT_DOTFILE_PATH="$HOME/.vagrant"
vagrant up week3
```

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

Weeks 3 and 5 support this opt-in bridge. Use it only on a dedicated classroom VLAN or isolated lab router.
