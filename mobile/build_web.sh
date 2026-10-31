#!/usr/bin/env bash
# Gera o site do app (usado pelo Render). Precisa da variável API_URL,
# ex.: API_URL=https://fauna-urbana-api.onrender.com
set -euo pipefail

FLUTTER_VERSION="3.47.9"
FLUTTER_DIR="${FLUTTER_DIR:-$HOME/flutter}"

if [ -z "${API_URL:-}" ]; then
  echo "Defina a variável API_URL com o endereço da API." >&2
  exit 1
fi

if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  git clone --depth 1 --branch "$FLUTTER_VERSION" https://github.com/flutter/flutter.git "$FLUTTER_DIR"
fi

"$FLUTTER_DIR/bin/flutter" config --no-analytics >/dev/null
"$FLUTTER_DIR/bin/flutter" pub get
"$FLUTTER_DIR/bin/flutter" build web --release --dart-define=API_URL="$API_URL"
