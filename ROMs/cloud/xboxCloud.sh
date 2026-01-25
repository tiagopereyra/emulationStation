#!/usr/bin/env python3
import os
import subprocess
import shutil
import sys
import subprocess

def register_app(identifier):
    subprocess.run(["/usr/bin/register_app", str(identifier)])

FLATPAK_ID = "com.google.Chrome"
URL = "https://www.xbox.com/play"

HOME = os.environ.get("HOME", "/home/muser")

FLATPAK_PERMS = [
    "--share=network",
    "--socket=wayland",
    "--socket=pulseaudio",
    "--socket=session-bus",
    "--device=dri",
    f"--filesystem={HOME}/.var/app/com.google.Chrome:rw",
]

CHROME_ARGS = [
    "--ozone-platform=wayland",
    "--enable-features=UseOzonePlatform,VaapiVideoDecoder,GamepadExtensions",
    "--use-gl=egl",
    "--ignore-gpu-blocklist",
    "--kiosk",
    "--no-first-run",
    "--no-default-browser-check",
    "--disable-infobars",
    "--disable-translate",
    "--disable-extensions",
    "--autoplay-policy=no-user-gesture-required",

    # ESCALADO PARA TV 4K
    "--force-device-scale-factor=1.75",

    URL,
]

def main():
    if not shutil.which("flatpak"):
        print("flatpak no está instalado. Qué optimista de tu parte.")
        sys.exit(1)

    cmd = ["flatpak", "run"] + FLATPAK_PERMS + [FLATPAK_ID] + CHROME_ARGS

    register_app("chromium")

    if shutil.which("dbus-run-session"):
        cmd = ["dbus-run-session", "--"] + cmd

    os.execvp(cmd[0], cmd)

if __name__ == "__main__":
    main()
