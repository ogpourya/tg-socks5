#!/usr/bin/env bash
set -euo pipefail

# Check gum
if ! command -v gum &>/dev/null; then
  echo "gum is not installed. Install it from: https://github.com/charmbracelet/gum"
  echo "  brew install gum  /  go install github.com/charmbracelet/gum@latest  /  your distro's package manager"
  exit 1
fi

gum style \
  --border rounded \
  --border-foreground 12 \
  --padding "1 2" \
  --margin "1 0" \
  --bold \
  "🔒 Telegram SOCKS5 Proxy"

# Port: env > prompt
if [ -n "${SOCKS_PORT:-}" ]; then
  gum log --level info "Using port from env: ${SOCKS_PORT}"
else
  SOCKS_PORT="$(gum input --placeholder "SOCKS5 port (default: 1080)" --prompt "  Port › " --value "1080")"
  SOCKS_PORT="${SOCKS_PORT:-1080}"
fi

# User: env > prompt
if [ -n "${PROXY_USER:-}" ]; then
  gum log --level info "Using username from env: ${PROXY_USER}"
else
  PROXY_USER="$(gum input --placeholder "Username (leave blank = random)" --prompt "  User › ")"
  PROXY_USER="${PROXY_USER:-tg_$(openssl rand -hex 3)}"
fi

# Pass: env > prompt
if [ -n "${PROXY_PASS:-}" ]; then
  gum log --level info "Using password from env"
else
  PROXY_PASS="$(gum input --placeholder "Password (leave blank = random)" --prompt "  Pass › " --password)"
  if [ -z "$PROXY_PASS" ]; then
    PROXY_PASS="$(openssl rand -base64 24 | tr -dc 'A-Za-z0-9')"
    PROXY_PASS="${PROXY_PASS:0:24}"
  fi
fi

CONTAINER_NAME="tg-socks5"

gum spin --spinner dot --title "Fetching Telegram CIDR list..." -- sleep 0 &
CIDR_RAW="$(curl -fsS https://core.telegram.org/resources/cidr.txt)"
wait
IPV4_NETS="$(echo "$CIDR_RAW" | grep -E '^[0-9]')"
IPV6_NETS="$(echo "$CIDR_RAW" | grep -E '^[0-9a-fA-F:]')"
gum log --level info "Telegram CIDRs loaded ✓"

TMPCONFIG="$(mktemp /tmp/3proxy-XXXXXX.cfg)"

{
  echo "nserver 1.1.1.1"
  echo "nserver 8.8.8.8"
  echo "nscache 65536"
  echo "timeouts 1 5 30 60 180 1800 15 60"
  echo "log /dev/stdout"
  echo "auth strong"
  echo "users ${PROXY_USER}:CL:${PROXY_PASS}"
  echo "flush"
  while IFS= read -r net; do
    [ -z "$net" ] && continue
    echo "allow ${PROXY_USER} * ${net}"
  done <<< "$IPV4_NETS"
  while IFS= read -r net; do
    [ -z "$net" ] && continue
    echo "allow ${PROXY_USER} * ${net}"
  done <<< "$IPV6_NETS"
  echo "deny *"
  echo "socks -p${SOCKS_PORT}"
} > "$TMPCONFIG"

docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true

gum spin --spinner dot --title "Pulling 3proxy image..." -- docker pull 3proxy/3proxy:latest >/dev/null 2>&1
gum log --level info "Image ready ✓"

SERVER_IP="$(curl -fsS https://api.ipify.org 2>/dev/null || echo '<server-ip>')"

gum style \
  --border rounded \
  --border-foreground 10 \
  --padding "1 2" \
  --margin "1 0" \
  "$(gum style --foreground 10 --bold '✅ Proxy is live')
$(gum style --foreground 8 'Closes automatically when you exit this script')

$(gum style --foreground 12 --bold 'Host  ') ${SERVER_IP}
$(gum style --foreground 12 --bold 'Port  ') ${SOCKS_PORT}
$(gum style --foreground 12 --bold 'User  ') ${PROXY_USER}
$(gum style --foreground 12 --bold 'Pass  ') ${PROXY_PASS}
$(gum style --foreground 12 --bold 'URL   ') socks5://${PROXY_USER}:${PROXY_PASS}@${SERVER_IP}:${SOCKS_PORT}"

cleanup() {
  echo ""
  gum log --level warn "Shutting down proxy..."
  docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
  rm -f "$TMPCONFIG"
  gum log --level info "Container destroyed. Bye 👋"
  exit 0
}

trap cleanup INT TERM

docker run --rm \
  --name "$CONTAINER_NAME" \
  -p "${SOCKS_PORT}:${SOCKS_PORT}/tcp" \
  -p "${SOCKS_PORT}:${SOCKS_PORT}/udp" \
  -v "${TMPCONFIG}:/3proxy.cfg:ro" \
  3proxy/3proxy:latest \
  3proxy /3proxy.cfg

cleanup
