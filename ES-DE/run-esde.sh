#!/usr/bin/env bash
set -e

ESDE_APPIMAGE="$HOME/Apps/ES-DE.AppImage"
SPLASH_IMG="$HOME/ES-DE/splash/splash.png"

SPLASH_TIME=4  

# Mostrar splash en Wayland (mpv nativo)
mpv --fs \
    --no-audio \
    --force-window=yes \
    --image-display-duration=inf \
    "$SPLASH_IMG" &
SPLASH_PID=$!

# Arrancar ES-DE sin splash interno
"$ESDE_APPIMAGE" --no-splash &

# Mantener splash el tiempo deseado
sleep "$SPLASH_TIME"

# Cerrar splash
kill "$SPLASH_PID" 2>/dev/null || true
