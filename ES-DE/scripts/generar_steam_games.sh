#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="$HOME/ROMs/steam_games"
mkdir -p "$OUT_DIR"

# Posibles ubicaciones de Steam (nativo y Flatpak)
CANDIDATES=(
  "$HOME/.local/share/Steam/steamapps"
  "$HOME/.steam/steam/steamapps"
  "$HOME/.var/app/com.valvesoftware.Steam/data/Steam/steamapps"   # Flatpak
)

STEAMAPPS=""
for p in "${CANDIDATES[@]}"; do
  if [ -d "$p" ]; then
    STEAMAPPS="$p"
    break
  fi
done

if [ -z "$STEAMAPPS" ]; then
  echo "No encuentro steamapps en ubicaciones comunes."
  echo "Probá: find ~ -maxdepth 8 -type d -name steamapps"
  exit 1
fi

echo "Steamapps base: $STEAMAPPS"

# Obtener todas las librerías desde libraryfolders.vdf (si existe)
LIBS=()
LIBS+=("$STEAMAPPS")

VDF="$STEAMAPPS/libraryfolders.vdf"
if [ -f "$VDF" ]; then
  # Extrae paths tipo: "path"  "/algo/SteamLibrary"
  while IFS= read -r line; do
    path="$(echo "$line" | sed -nE 's/.*"path"[[:space:]]+"([^"]+)".*/\1/p')"
    if [ -n "$path" ]; then
      # En vdf a veces viene con \\ como escape
      path="${path//\\\\/\\}"
      if [ -d "$path/steamapps" ]; then
        LIBS+=("$path/steamapps")
      fi
    fi
  done < <(grep -E '"path"' "$VDF" || true)
fi

# Deduplicar
uniq_libs=()
for l in "${LIBS[@]}"; do
  skip=0
  for u in "${uniq_libs[@]}"; do
    [ "$l" = "$u" ] && skip=1 && break
  done
  [ $skip -eq 0 ] && uniq_libs+=("$l")
done

echo "Librerías detectadas:"
for l in "${uniq_libs[@]}"; do echo " - $l"; done

# Limpiar accesos anteriores
rm -f "$OUT_DIR"/*.desktop

# Crear .desktop por cada appmanifest en todas las librerías
count=0
for lib in "${uniq_libs[@]}"; do
  for f in "$lib"/appmanifest_*.acf; do
    [ -e "$f" ] || continue

    APPID="$(basename "$f" | sed -E 's/appmanifest_([0-9]+)\.acf/\1/')"
    NAME="$(grep -m1 '"name"' "$f" | sed -E 's/.*"name"[[:space:]]+"([^"]+)".*/\1/' || true)"

    [ -z "${NAME:-}" ] && continue

    SAFE="$(echo "$NAME" | tr '/' '-' | tr -d ':\"'\''')"

    cat > "$OUT_DIR/$SAFE.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$NAME
Exec=steam -applaunch $APPID
Terminal=false
Categories=Game;
EOF
    chmod +x "$OUT_DIR/$SAFE.desktop"
    count=$((count+1))
  done
done

echo "Listo: $count juegos exportados a $OUT_DIR"
