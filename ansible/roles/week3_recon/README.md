# Week 3: Active Reconnaissance

The `week3` target exposes four services on `192.168.56.30`, each hiding one
deployment-specific `WRI{...}` flag. Discover them with a port scan, then
enumerate each service:

| Service | Port | Flag location |
|---|---:|---|
| SSH | 22 | `VersionAddendum` in the pre-auth banner |
| HTTP | 80 | `staging/notes.txt` on the `blog.wri.test` virtual host (hinted by `robots.txt`) |
| SMB | 445 | `flag.txt` inside the guest-accessible `public` share |
| Status service | 11279 | HTML source of the uncommon status page |

The HTTP flag lives at `blog.wri.test/staging/notes.txt`. The placeholder page
served on the bare IP hints that sites use names under `wri.test`; the
subdomain for this lab is `blog`. Before browsing, add it to your host's
`/etc/hosts` (or `C:\Windows\System32\drivers\etc\hosts` on Windows):

```
192.168.56.30 blog.wri.test
```

Then browse to <http://blog.wri.test/>, check `robots.txt`, and enumerate the
unlisted paths. The bare IP serves a placeholder page instead, so finding the
flag requires the subdomain plus virtual-host and content enumeration.

Verify a deployment end-to-end from the host:

```bash
scripts/verify-week3.sh [target-ip]
```
