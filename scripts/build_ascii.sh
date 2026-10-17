#!/usr/bin/env bash
# O CMake do Android quebra se o caminho do projeto tem acento.
# Se o caminho real ainda tiver caractere fora do ASCII, o build roda
# numa cópia em ~/builds/controleSaude e o resultado volta para cá.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd -P)"
mirror="${EXAMEFACIL_BUILD_MIRROR:-$HOME/builds/controleSaude}"

if [[ $# -lt 1 ]]; then
  echo "Uso: scripts/build_ascii.sh flutter build web --release" >&2
  exit 1
fi

needs_mirror() {
  python3 - "$root" << 'PY'
import sys
sys.exit(0 if not sys.argv[1].isascii() else 1)
PY
}

if ! needs_mirror; then
  cd "$root"
  exec "$@"
fi

if [[ "$root" == "$mirror" ]]; then
  cd "$root"
  exec "$@"
fi

mkdir -p "$mirror"
echo "Caminho com acento. Compilando em ${mirror}" >&2

rsync -a --delete \
  --exclude '.git/' \
  --exclude 'build/' \
  --exclude '.dart_tool/' \
  --exclude 'android/.gradle/' \
  --exclude '.playwright-mcp/' \
  "$root/" "$mirror/"

(
  cd "$mirror"
  "$@"
)

if [[ -d "$mirror/build" ]]; then
  mkdir -p "$root/build"
  rsync -a "$mirror/build/" "$root/build/"
fi
