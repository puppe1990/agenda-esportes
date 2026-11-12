#!/usr/bin/env bash
# Rasteriza public/favicon.svg nos PNGs da PWA.
# Uso: bash scripts/render-icons.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SVG="$ROOT/public/favicon.svg"

raster() {
  local size="$1"
  local out="$2"
  local bg="${3:-}"
  if [[ -n "$bg" ]]; then
    rsvg-convert -w "$size" -h "$size" --background-color="$bg" "$SVG" -o "$out"
  else
    rsvg-convert -w "$size" -h "$size" "$SVG" -o "$out"
  fi
}

raster 192 "$ROOT/public/icon-192.png"
raster 512 "$ROOT/public/icon-512.png"
# iOS round-rects the icon; opaque fill keeps the mint calendar off a white plate.
raster 180 "$ROOT/public/apple-touch-icon.png" "#0b0e14"

python3 - <<PY
from pathlib import Path
root = Path("$ROOT") / "public"
want = {"icon-192.png": 192, "icon-512.png": 512, "apple-touch-icon.png": 180}
for name, size in want.items():
    p = root / name
    d = p.read_bytes()
    w = int.from_bytes(d[16:20], "big")
    h = int.from_bytes(d[20:24], "big")
    if w != size or h != size:
        raise SystemExit(f"{name} {w}x{h}, esperado {size}x{size}")
    print(f"{name} {w}x{h} {p.stat().st_size} bytes")
PY
