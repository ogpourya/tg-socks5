# tg-socks5

A temporary, Telegram-only SOCKS5 proxy that lives while your terminal is open — and vanishes when you close it.

```
socks5://user:pass@your-ip:1080
```

---

## How it works

- Fetches Telegram's [live CIDR list](https://core.telegram.org/resources/cidr.txt) on every run
- Spins up a [3proxy](https://github.com/3proxy/3proxy) container via Docker
- Generates random credentials unless you override them
- Destroys the container the moment the script exits

No persistence. No leftover containers. No manual cleanup.

---

## Requirements

- [`docker`](https://docs.docker.com/get-docker/)
- [`gum`](https://github.com/charmbracelet/gum)

```bash
# macOS
brew install gum

# Linux (go)
go install github.com/charmbracelet/gum@latest

# Arch
pacman -S gum
```

---

## Usage

```bash
bash tg-socks5.sh
```

The script will prompt you for port, username, and password — all optional. Leave any blank to get a random value.

Press `Ctrl+C` to stop. The container is gone instantly.

---

## Environment overrides

```bash
SOCKS_PORT=9050 PROXY_USER=me PROXY_PASS=secret bash tg-socks5.sh
```

| Variable | Default | Description |
|---|---|---|
| `SOCKS_PORT` | `1080` | SOCKS5 listen port |
| `PROXY_USER` | `tg_<random>` | SOCKS5 username |
| `PROXY_PASS` | `<random 24 chars>` | SOCKS5 password |
| `UPSTREAM_PROXY` | _(none)_ | Upstream proxy URL to chain through |

### Upstream proxy

You can chain the SOCKS5 through another proxy. Specify a URL like:

```
socks5://user:pass@upstream-host:1080
http://upstream-host:3128
https://user:pass@upstream-host:8080
socks4://upstream-host:1080
```

Supported protocols: `socks5`, `socks4`, `http`, `https`.

If the upstream host is on the same machine, use `host.docker.internal` (Docker Desktop) or the Docker gateway IP (e.g. `172.17.0.1` on Linux) instead of `127.0.0.1`, since 3proxy runs inside a container.

---

## What gets blocked

Everything that isn't Telegram. The allowlist is pulled fresh from Telegram's official CIDR file each run — both IPv4 and IPv6. All other traffic hits a `deny *` rule.

---

## License

MIT

---

> [github.com/ogpourya/tg-socks5](https://github.com/ogpourya/tg-socks5)
