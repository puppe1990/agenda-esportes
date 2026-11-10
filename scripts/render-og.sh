#!/usr/bin/env bash
# Rasteriza public/og.html em public/og.png (1200×630).
# Uso: bash scripts/render-og.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/public/og.png"
SHOTS="/Users/matheuspuppe/Desktop/Projetos/.playwright-cli"
SESSION="agenda-og"
PLAYWRIGHT_STARTED=0

cleanup() {
  if [[ "$PLAYWRIGHT_STARTED" == 1 ]]; then
    playwright-cli -s="$SESSION" close >/dev/null 2>&1 || true
  fi
  if [[ -n "${http_pid:-}" ]]; then
    kill "$http_pid" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

mkdir -p "$SHOTS"

port="$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')"
if [[ "$port" == "8765" ]]; then
  echo "porta 8765 reservada" >&2
  exit 1
fi

python3 -m http.server "$port" --bind 127.0.0.1 --directory "$ROOT/public" >/dev/null 2>&1 &
http_pid=$!
sleep 0.3

# playwright-cli grava em <cwd>/.playwright-cli — o workspace é Projetos/.
(
  cd /Users/matheuspuppe/Desktop/Projetos
  playwright-cli -s="$SESSION" open "http://127.0.0.1:${port}/og.html" >/dev/null
)
PLAYWRIGHT_STARTED=1
playwright-cli -s="$SESSION" resize 1200 630 >/dev/null
playwright-cli -s="$SESSION" eval "async () => { await document.fonts.ready; return document.fonts.status; }" >/dev/null
(
  cd /Users/matheuspuppe/Desktop/Projetos
  playwright-cli -s="$SESSION" screenshot "#og" --filename=".playwright-cli/agenda-esportes-og.png" >/dev/null
)
cp "$SHOTS/agenda-esportes-og.png" "$OUT"

python3 - <<PY
from pathlib import Path
p = Path("$OUT")
d = p.read_bytes()
w = int.from_bytes(d[16:20], "big")
h = int.from_bytes(d[20:24], "big")
if w != 1200 or h != 630:
    raise SystemExit(f"og.png {w}x{h}, esperado 1200x630")
print(f"og.png {w}x{h} {p.stat().st_size} bytes")
PY
