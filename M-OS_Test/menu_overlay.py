#!/usr/bin/env python3
import json
import os
import shlex
import subprocess
import sys
import time
from pathlib import Path
from tkinter import Tk, Label, Button, Frame

CONFIG_PATH = Path(__file__).with_name("config.json")

def load_config():
    try:
        return json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
    except Exception as e:
        print(f"[overlay] No pude leer config.json: {e}", file=sys.stderr)
        return {}

def run_cmd(cmd: str) -> int:
    """Run shell command safely (string), return exit code."""
    try:
        proc = subprocess.run(cmd, shell=True, check=False)
        return proc.returncode
    except Exception as e:
        print(f"[overlay] Error ejecutando comando: {cmd} -> {e}", file=sys.stderr)
        return 1

def is_flatpak_running(app_id: str) -> bool:
    try:
        out = subprocess.check_output(["flatpak", "ps"], text=True, stderr=subprocess.DEVNULL)
        return app_id in out
    except Exception:
        return False

class OverlayMenu:
    def __init__(self):
        self.cfg = load_config()
        self.esde_command = self.cfg.get("esde_command", "es-de")
        self.title = self.cfg.get("overlay_title", "Overlay Menu")

        self.volume_step = int(self.cfg.get("audio", {}).get("volume_step_percent", 5))
        self.discord_id = self.cfg.get("flatpak", {}).get("discord_app_id", "com.discordapp.Discord")

        # procesos de dummy windows (toggle)
        self.wifi_proc = None
        self.bt_proc = None

        self.root = Tk()
        self.root.title(self.title)

        # Fullscreen + topmost (Wayland/Weston: ayuda)
        self.root.attributes("-fullscreen", True)
        self.root.attributes("-topmost", True)

        # Escape para salir (útil debug)
        self.root.bind("<Escape>", lambda e: self.close_overlay())

        self._build_ui()

    def _build_ui(self):
        self.root.configure(bg="#000000")

        title = Label(
            self.root,
            text=self.title,
            font=("Arial", 24, "bold"),
            bg="#000000",
            fg="#1E6BFF"
        )
        title.pack(pady=20)

        container = Frame(self.root, bg="#000000")
        container.pack(pady=10)

        def mk_btn(text, cmd):
            return Button(
                container,
                text=text,
                command=cmd,
                font=("Arial", 18),
                bg="#111111",
                fg="white",
                activebackground="#1E6BFF",
                activeforeground="white",
                width=28,
                height=2,
                relief="flat"
            )

        mk_btn("Volver a ES-DE", self.go_to_esde).pack(pady=8)
        mk_btn("Volver (cerrar menú)", self.close_overlay).pack(pady=8)

        mk_btn(f"Subir volumen (+{self.volume_step}%)", self.volume_up).pack(pady=8)
        mk_btn(f"Bajar volumen (-{self.volume_step}%)", self.volume_down).pack(pady=8)

        mk_btn("WiFi (toggle)", self.toggle_wifi).pack(pady=8)
        mk_btn("Bluetooth (toggle)", self.toggle_bluetooth).pack(pady=8)

        mk_btn("Discord (toggle)", self.toggle_discord).pack(pady=8)
        mk_btn("Apagar sistema", self.shutdown).pack(pady=8)

        hint = Label(
            self.root,
            text="ESC = cerrar (debug)",
            font=("Arial", 12),
            bg="#000000",
            fg="#B0B0B0"
        )
        hint.pack(side="bottom", pady=20)

    # ---------- acciones ----------
    def close_overlay(self):
        # NO matamos dummies acá; toggle los maneja el usuario
        self.root.destroy()

    def go_to_esde(self):
        """
        En Wayland no podés forzar foco como en X11.
        Lo más robusto es: lanzar ES-DE (si ya está, no pasa nada grave),
        y cerrar el overlay.
        """
        # Si tu amigo tiene un wrapper/servicio distinto, cambia esde_command en config.json
        run_cmd(shlex.quote(self.esde_command) if " " not in self.esde_command else self.esde_command)
        self.close_overlay()

    def shutdown(self):
        # En sistemas embebidos puede ser poweroff directamente
        run_cmd("systemctl poweroff || poweroff")
        self.close_overlay()

    def volume_up(self):
        # PipeWire/PulseAudio
        code = run_cmd(f"pactl set-sink-volume @DEFAULT_SINK@ +{self.volume_step}%")
        if code != 0:
            # Fallback ALSA
            run_cmd(f"amixer -D pulse sset Master {self.volume_step}%+ || amixer sset Master {self.volume_step}%+")
        self.close_overlay()

    def volume_down(self):
        code = run_cmd(f"pactl set-sink-volume @DEFAULT_SINK@ -{self.volume_step}%")
        if code != 0:
            run_cmd(f"amixer -D pulse sset Master {self.volume_step}%- || amixer sset Master {self.volume_step}%-")
        self.close_overlay()

    def toggle_discord(self):
        if is_flatpak_running(self.discord_id):
            run_cmd(f"flatpak kill {shlex.quote(self.discord_id)}")
        else:
            # --branch/--arch si hiciera falta (se agrega en config o acá)
            run_cmd(f"flatpak run {shlex.quote(self.discord_id)} &")
        self.close_overlay()

    def _toggle_dummy(self, which: str):
        """
        Por ahora WiFi/BT son dummy windows (Tkinter) como en tu idea original.
        Esto cumple el requisito de "simular" si no está el configurador real.
        """
        dummy_path = Path(__file__).with_name("dummy_settings.py")
        if not dummy_path.exists():
            print("[overlay] dummy_settings.py no existe", file=sys.stderr)
            return

        if which == "wifi":
            proc_attr = "wifi_proc"
            title = "WiFi Settings (dummy)"
        else:
            proc_attr = "bt_proc"
            title = "Bluetooth Settings (dummy)"

        proc = getattr(self, proc_attr)

        # Si está corriendo, lo cerramos (toggle)
        if proc is not None and proc.poll() is None:
            try:
                proc.terminate()
            except Exception:
                pass
            setattr(self, proc_attr, None)
            return

        # Si no está, lo abrimos
        new_proc = subprocess.Popen([sys.executable, str(dummy_path), title])
        setattr(self, proc_attr, new_proc)

    def toggle_wifi(self):
        self._toggle_dummy("wifi")
        self.close_overlay()

    def toggle_bluetooth(self):
        self._toggle_dummy("bt")
        self.close_overlay()

    def run(self):
        self.root.mainloop()

if __name__ == "__main__":
    OverlayMenu().run()
