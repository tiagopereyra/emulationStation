#!/usr/bin/env python3
import os
import subprocess
import shutil
import sys

def register_app(identifier):
    subprocess.run(["/usr/bin/register_app", str(identifier)])

FLATPAK_ID = "com.stremio.Stremio"

HOME = os.environ.get("HOME", "/home/muser")

FLATPAK_PERMS = [
    "--share=network",
    "--socket=wayland",
    "--socket=pulseaudio",
    "--socket=session-bus",
    "--device=dri",
    f"--filesystem={HOME}/.var/app/{FLATPAK_ID}:rw",
]

STREMIO_ARGS = [
    "--ozone-platform=wayland",
    "--enable-features=UseOzonePlatform,VaapiVideoDecoder",
    "--use-gl=egl",
    "--ignore-gpu-blocklist",

    # ESCALADO PARA TV 4K
    "--force-device-scale-factor=1.75",
]

# Variables que ayudan a activar la UI de TV
ENV = {
    "STREMIO_TV": "1",
    "ELECTRON_OZONE_PLATFORM_HINT": "wayland",
    "XDG_SESSION_TYPE": "wayland",
}

def main():
    if not shutil.which("flatpak"):
        print("flatpak no está instalado.")
        sys.exit(1)

    # Exportar variables de entorno
    for k, v in ENV.items():
        os.environ[k] = v

    cmd = ["flatpak", "run"] + FLATPAK_PERMS + [FLATPAK_ID] + STREMIO_ARGS

    register_app("stremio-tv")

    if shutil.which("dbus-run-session"):
        cmd = ["dbus-run-session", "--"] + cmd

    os.execvp(cmd[0], cmd)

if __name__ == "__main__":
    main()
