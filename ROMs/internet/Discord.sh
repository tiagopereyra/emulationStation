#!/usr/bin/env python3
import os
import subprocess
import shutil
import sys

def register_app(identifier):
    subprocess.run(["/usr/bin/register_app", str(identifier)])

FLATPAK_ID = "com.discordapp.Discord"

HOME = os.environ.get("HOME", "/home/muser")

# Permisos necesarios para que Discord funcione bien
FLATPAK_PERMS = [
    "--share=network",
    "--socket=x11",            # Fuerza X11
    "--socket=pulseaudio",
    "--socket=session-bus",
    "--device=dri",
    "--allow=devel",
    f"--filesystem={HOME}/.var/app/{FLATPAK_ID}:rw",
]

# Flags para forzar X11 en Electron
DISCORD_ARGS = [
    "--ozone-platform=x11",
    "--disable-features=UseOzonePlatform",
    "--use-gl=desktop",
    "--disable-gpu-sandbox",
    "--disable-wayland-ime",
]

# Variables de entorno para engañar a Electron
ENV = {
    "DISABLE_WAYLAND": "1",
    "ELECTRON_OZONE_PLATFORM_HINT": "x11",
    "XDG_SESSION_TYPE": "x11",
    "GDK_BACKEND": "x11",
}

def main():
    if not shutil.which("flatpak"):
        print("flatpak no está instalado.")
        sys.exit(1)

    # Exportar variables de entorno
    for k, v in ENV.items():
        os.environ[k] = v

    cmd = ["flatpak", "run"] + FLATPAK_PERMS + [FLATPAK_ID] + DISCORD_ARGS

    register_app("discord-x11")

    if shutil.which("dbus-run-session"):
        cmd = ["dbus-run-session", "--"] + cmd

    os.execvp(cmd[0], cmd)

if __name__ == "__main__":
    main()
