# Week 3: Demo Nmap untuk Instruktur

Target `week3_demo` mengikuti urutan materi **Miniclass Cyber - Active Recon
and Network Scanning.pdf** sebelum sesi hands-on. Tidak ada flag challenge
di VM ini. Opsi Nmap seperti `-sV` dan `-sC` tetap digunakan untuk demo.

`week3` (`192.168.56.30`) tetap menjadi target practice peserta pada sesi
akhir. Demo memakai role, disk, dan konfigurasi tersendiri; hostname guest
adalah `week3-demo`.

## Menyiapkan target

```bash
vagrant up week3_demo
# Atau, untuk LAN kelas:
WRI_LAB_BRIDGE_INTERFACE="wlan0" vagrant up week3_demo
vagrant ssh week3_demo -c "ip -4 -brief address"
```

Jalankan perintah scan dari laptop, bukan dari dalam target. Contoh berikut
memakai Bash di Linux dengan Nmap terpasang. Di Windows gunakan alamat IP
langsung dan jalankan terminal sebagai Administrator untuk scan yang
memerlukan raw packets.

```bash
TARGET=192.168.56.31
SUBNET=192.168.56.0/24
```

Untuk demo via LAN, ganti `TARGET` dengan IP bridged VM dan `SUBNET` dengan
subnet lab yang digunakan. Netmask mengikuti output IP, jangan selalu
menganggap `/24`. Gunakan subnet yang memang disediakan untuk kelas.

| Layanan | Port | Hasil yang diharapkan |
|---|---|---|
| OpenSSH | TCP 22 | Banner standar OpenSSH dan SSH host keys |
| DNS dnsmasq | TCP/UDP 53 | Layanan DNS lokal untuk demo `-sU` |
| nginx | TCP 80 | Judul halaman `WRI Nmap Demo` |
| Samba | TCP 139, 445 | Share guest read-only `public`, berisi `readme.txt` |
| Samba NetBIOS | UDP 137, 138 | Name service dan datagram NetBIOS dari `nmbd` |
| nginx status | TCP 8080 | Judul halaman `WRI Demo Status` |
| Tidak ada listener | TCP 65000 | `closed` pada jaringan lab tanpa filtering |

DNS melayani record A `demo.wri.test` ke IP host-only `192.168.56.31` dan
record TXT `WRI Nmap Demo DNS`. Tidak ada DHCP atau forwarding DNS eksternal.
Saat memakai bridge, akses HTTP langsung melalui IP bridged; record A demo
tetap menunjuk IP host-only.

## Bagian 3: Host discovery

```bash
# Listing tanpa reverse DNS: tidak mengirim probe ke target atau query DNS.
nmap -sL -n "$SUBNET"

# Temukan host aktif pada subnet lab.
nmap -sn -n "$SUBNET"

# ARP: berlaku ketika scanner dan target berada di segmen Ethernet yang sama.
sudo nmap -sn -PR -n "$TARGET"

# Paksa probe IP agar discovery lokal tidak digantikan ARP.
sudo nmap -sn -PE --send-ip -n "$TARGET"
sudo nmap -sn -PP --send-ip -n "$TARGET"
sudo nmap -sn -PM --send-ip -n "$TARGET"
sudo nmap -sn -PU53 --send-ip -n "$TARGET"
```

Tidak semua OS merespons ICMP timestamp/netmask. Hasil probe berbeda tidak
otomatis berarti VM mati. `-sL` sendiri masih bisa mengirim query reverse
DNS; tambahan `-n` menonaktifkannya.

## Bagian 4: Port scanning

```bash
nmap "$TARGET"                         # default: top 1000 TCP ports
nmap -p 22,53,80,445,8080 "$TARGET"     # port tertentu
nmap -p 1-1024 "$TARGET"               # rentang
nmap -p- "$TARGET"                     # semua 65535 TCP ports
nmap --top-ports 10 "$TARGET"           # 10 port paling umum
nmap -sT -p 22,80,445 "$TARGET"         # TCP connect, tanpa sudo
sudo nmap -sS -p 22,80,445 "$TARGET"    # SYN scan
sudo nmap -sU -sV -p 53 "$TARGET"       # UDP DNS
nmap -p 80,65000 --reason "$TARGET"     # bandingkan open dan closed
```

Tidak ada aturan firewall buatan di demo ini: `filtered` bergantung pada
filtering jaringan yang dilalui. UDP dapat terlihat `open|filtered` jika
respons tidak diterima; `-sV` membantu mengonfirmasi layanan. Label layanan
dari scan dasar mengikuti tabel nomor port; `-sV` memeriksa layanan aktual.

## Bagian 5: OS dan services

```bash
sudo nmap -O -p 22,80,65000 "$TARGET"
nmap -sV -p 22,53,80,139,445,8080 "$TARGET"
nmap -sC -sV -p 22,80,445,8080 "$TARGET"
sudo nmap -A -p 22,53,80,139,445,8080,65000 "$TARGET"
```

Deteksi OS adalah perkiraan fingerprint jaringan; hasilnya dapat berupa
keluarga Linux atau rentang versi kernel. Port terbuka dan tertutup membantu
deteksi; jangan mengharapkan versi Ubuntu/kernel yang persis sama.

## Bagian 6: NSE dan timing

```bash
nmap -sV --script http-title,http-headers -p 80,8080 "$TARGET"
nmap --script ssh-hostkey -p 22 "$TARGET"
nmap --script smb-os-discovery,smb-protocols -p 445 "$TARGET"
nmap -sT -T3 -p 1-1024 "$TARGET"
nmap -sT -T4 -p 1-1024 "$TARGET"
nmap -sT --min-rate 100 -p 1-1024 "$TARGET"
```

Bandingkan durasi dan kelengkapan hasil. `--min-rate` mengatur batas bawah
laju pengiriman probe; menaikkannya dapat mengurangi keandalan hasil.

## Verifikasi dan pergantian ke practice

```bash
scripts/verify-week3-demo.sh              # host-only
scripts/verify-week3-demo.sh <ip-bridged> # dari jaringan kelas
vagrant up week3                        # sesi hands-on terakhir
```

Verifier memeriksa port, fingerprint/NSE, DNS UDP/TCP, halaman HTTP,
banner SSH, dan file share SMB, serta menolak penanda flag challenge pada
respons tersebut. `week3_demo` tidak memakai role pembuat flag practice.

Referensi: [opsi Nmap](https://nmap.org/book/man-briefoptions.html),
[host discovery](https://nmap.org/book/man-host-discovery.html),
[dnsmasq](https://thekelleys.org.uk/dnsmasq/docs/dnsmasq-man.html).
