#!/usr/bin/env python3
import os
import subprocess
import shutil
import sys

def register_app(identifier):
    subprocess.run(["/usr/bin/register_app", str(identifier)])

FLATPAK_ID = "com.opera.Opera"

HOME = os.environ.get("HOME", "/home/muser")

FLATPAK_PERMS = [
    "--share=network",
    "--socket=wayland",
    "--socket=pulseaudio",
    "--socket=session-bus",
    "--device=dri",
    f"--filesystem={HOME}/.var/app/{FLATPAK_ID}:rw",
]

OPERA_ARGS = [
    "--ozone-platform=wayland",
    "--enable-features=UseOzonePlatform,VaapiVideoDecoder,GamepadExtensions",
    "--use-gl=egl",
    "--ignore-gpu-blocklist",

    # ESCALADO PARA TV 4K
    "--force-device-scale-factor=1.75",
]

def main():
    if not shutil.which("flatpak"):
        print("flatpak no está instalado.")
        sys.exit(1)

    cmd = ["flatpak", "run"] + FLATPAK_PERMS + [FLATPAK_ID] + OPERA_ARGS

    register_app("opera-browser")

    if shutil.which("dbus-run-session"):
        cmd = ["dbus-run-session", "--"] + cmd

    os.execvp(cmd[0], cmd)

if __name__ == "__main__":
    main()
