#!/usr/bin/env python3
import json
import subprocess
import sys
import time
from pathlib import Path

try:
    from evdev import InputDevice, ecodes, list_devices
except ImportError:
    print("Falta evdev. Instalar con: sudo apt install python3-evdev", file=sys.stderr)
    sys.exit(1)

import selectors

BASE_DIR = Path(__file__).resolve().parent
CONFIG_PATH = BASE_DIR / "config.json"
OVERLAY_UI = BASE_DIR / "menu_overlay.py"


# ---------- helpers ----------

def load_config():
    try:
        return json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
    except Exception as e:
        print(f"[daemon] Error leyendo config.json: {e}", file=sys.stderr)
        return {}


def spawn_overlay():
    """Lanza el overlay si no está ya corriendo."""
    try:
        out = subprocess.check_output(
            ["pgrep", "-f", OVERLAY_UI.name],
            text=True,
            stderr=subprocess.DEVNULL
        )
        if out.strip():
            return
    except subprocess.CalledProcessError:
        pass  # no está corriendo

    subprocess.Popen(
        [sys.executable, str(OVERLAY_UI)],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL
    )


def find_input_devices():
    devices = []
    for path in list_devices():
        try:
            devices.append(InputDevice(path))
        except Exception:
            pass
    return devices


def matches_combo(pressed, hold_list, tap_key):
    for key in hold_list:
        if key not in pressed:
            return False
    return tap_key in pressed


# ---------- main ----------

def main():
    cfg = load_config()
    trigger = cfg.get("trigger", {})

    cooldown_ms = int(trigger.get("cooldown_ms", 800))
    cooldown = cooldown_ms / 1000.0

    kb = trigger.get("keyboard", {})
    kb_enabled = kb.get("enabled", True)
    kb_hold = kb.get("hold_keys", [])
    kb_tap = kb.get("tap_key", "KEY_M")

    js = trigger.get("joystick", {})
    js_enabled = js.get("enabled", True)
    js_hold = js.get("hold_buttons", [])
    js_tap = js.get("tap_button", "BTN_START")

    devices = find_input_devices()
    if not devices:
        print("[daemon] No se detectaron dispositivos de input.", file=sys.stderr)
        sys.exit(1)

    print("[daemon] Dispositivos detectados:")
    for dev in devices:
        print(f"  - {dev.path} | {dev.name}")

    selector = selectors.DefaultSelector()

    for dev in devices:
        selector.register(dev.fd, selectors.EVENT_READ, dev)

    pressed = set()
    last_fire = 0.0

    while True:
        events = selector.select(timeout=1.0)
        for key, _ in events:
            dev = key.data
            try:
                for event in dev.read():
                    if event.type != ecodes.EV_KEY:
                        continue

                    key_name = ecodes.KEY.get(event.code, f"KEY_{event.code}")

                    # value: 1 press, 0 release, 2 repeat
                    if event.value == 1:
                        pressed.add(key_name)
                    elif event.value == 0:
                        pressed.discard(key_name)

                    now = time.time()
                    if now - last_fire < cooldown:
                        continue

                    fired = False

                    if kb_enabled and matches_combo(pressed, kb_hold, kb_tap):
                        fired = True

                    if not fired and js_enabled and matches_combo(pressed, js_hold, js_tap):
                        fired = True

                    if fired:
                        last_fire = now
                        spawn_overlay()

            except BlockingIOError:
                continue
            except OSError:
                continue


if __name__ == "__main__":
    main()

