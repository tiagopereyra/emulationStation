#!/usr/bin/env python3
"""
steam_launch_fullscreen.py

Splash fullscreen moderno en Tkinter (sin PNG),
muestra logs en vivo y lanza steam -tenfoot.
El splash no desaparece hasta detectar señales en los logs que indican
que Steam ya terminó de inicializar la UI.
"""

import os
import time
import threading
import subprocess
import tkinter as tk
import tkinter.font as tkfont
import subprocess

def register_app(identifier):
    subprocess.run(["/usr/bin/register_app", str(identifier)])

# -------------------------
# CONFIG
# -------------------------
# Log que queremos tailear (ajustar si tu ruta es otra)
STEAM_LOG = os.path.expanduser("~/.local/share/Steam/logs/console-linux.txt")

# Comando para lanzar tenfoot (sin gamescope)
STEAM_CMD = ["steam", "-tenfoot"]

# Patrones de logs que consideramos "steam listo".
READY_PATTERNS = [
    "Set percent complete: -1",
]

# Número de apariciones consecutivas para confirmar
READY_CONFIRM_COUNT = 3

# Cuántas líneas de logs mostrar en la ventana de splash
MAX_LOG_LINES = 12

# -------------------------
# SPLASH (Tkinter)
# -------------------------
class Splash:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("Cargando Steam")
        self.root.attributes("-fullscreen", True)
        self.root.configure(bg="#0b0f14")

        self.root.bind("<Escape>", lambda e: None)
        self.root.bind("<Alt-F4>", lambda e: None)

        title_font = tkfont.Font(family="Sans", size=48, weight="bold")
        subtitle_font = tkfont.Font(family="Sans", size=18)

        self.title = tk.Label(self.root, text="Iniciando Steam", fg="white", bg="#0b0f14", font=title_font)
        self.title.pack(pady=(40, 6))

        self.subtitle = tk.Label(self.root, text="Cargando componentes y verificando actualizaciones…",
                                 fg="#cbd5e1", bg="#0b0f14", font=subtitle_font)
        self.subtitle.pack(pady=(0, 30))

        self.canvas = tk.Canvas(self.root, width=420, height=140, bg="#0b0f14", highlightthickness=0)
        self.canvas.pack()
        self.arc = self.canvas.create_arc(20, 20, 120, 120, start=0, extent=90,
                                          width=6, style="arc", outline="#66c2ff")

        frame = tk.Frame(self.root, bg="#071018")
        frame.pack(pady=(30, 40), padx=40, fill="x")

        self.logbox = tk.Text(frame, height=MAX_LOG_LINES, wrap="none",
                              bg="#071018", fg="#cfeefd", bd=0, highlightthickness=0)
        self.logbox.pack(side="left", fill="x", expand=True)
        self.logbox.configure(state="disabled", font=("Courier", 12))

        self.hint = tk.Label(self.root,
                             text="Verificando actualizaciones de Steam. Por favor, espere.",
                             fg="#8fa7b6", bg="#0b0f14", font=("Sans", 12))
        self.hint.pack(side="bottom", pady=20)

        self.running = True
        self._spinner_angle = 0

        self._animate()

    def _animate(self):
        if not self.running:
            return
        self._spinner_angle = (self._spinner_angle + 10) % 360
        self.canvas.itemconfigure(self.arc, start=self._spinner_angle)
        self.root.after(30, self._animate)

    def append_log(self, line):
        self.logbox.configure(state="normal")
        self.logbox.insert("end", line.rstrip() + "\n")
        lines = int(self.logbox.index('end - 1 line').split('.')[0])
        if lines > MAX_LOG_LINES:
            self.logbox.delete("1.0", f"{lines - MAX_LOG_LINES}.0")
        self.logbox.see("end")
        self.logbox.configure(state="disabled")

    def fade_out_and_close(self):
        for i in range(20):
            alpha = 1.0 - (i+1)/20.0
            try:
                self.root.attributes("-alpha", alpha)
            except Exception:
                pass
            time.sleep(0.02)
        self.running = False
        try:
            self.root.destroy()
        except Exception:
            pass

    def start_mainloop(self):
        try:
            self.root.attributes("-alpha", 0.0)
            for i in range(20):
                try:
                    self.root.attributes("-alpha", (i+1)/20.0)
                except Exception:
                    pass
                time.sleep(0.01)
        except Exception:
            pass
        self.root.mainloop()

# -------------------------
# LOG TAILER + READY CHECK
# -------------------------
def tail_log_and_detect(splash, stop_event):
    while not stop_event.is_set():
        if os.path.exists(STEAM_LOG):
            break
        splash.append_log("[info] esperando que exista el log: " + STEAM_LOG)
        time.sleep(3.5)

    try:
        f = open(STEAM_LOG, "r", errors="ignore")
        f.seek(0, os.SEEK_END)
    except Exception as e:
        splash.append_log("[error] no puedo abrir log: " + str(e))
        return False

    while not stop_event.is_set():
        where = f.tell()
        line = f.readline()
        if not line:
            time.sleep(0.2)
            f.seek(where)
        else:
            splash.append_log(line.rstrip())
            if "Steam Runtime Launch Service: starting steam-runtime-launcher-service" in line:
                splash.append_log("[señal] Steam está inicializando la UI…")
                register_app("steam")
                time.sleep(1.0)
                return True
    return False

# -------------------------
# LAUNCHERS
# -------------------------
def launch_steam():
    try:
        return subprocess.Popen(STEAM_CMD,
                                stdout=subprocess.DEVNULL,
                                stderr=subprocess.DEVNULL)
    except Exception as e:
        print("No pude lanzar steam:", e)
        return None

# -------------------------
# MAIN
# -------------------------
def main():
    splash = Splash()

    splash.append_log("[info] lanzando Steam (tenfoot)…")
    steam_proc = launch_steam()
    if steam_proc is None:
        splash.append_log("[error] steam no pudo iniciarse")
        time.sleep(3)
        splash.fade_out_and_close()
        return

    stop_event = threading.Event()

    def tailer():
        try:
            ready = tail_log_and_detect(splash, stop_event)
            if ready:
                splash.fade_out_and_close()
            else:
                splash.append_log("[info] tailer terminado sin detectar ready")
        finally:
            stop_event.set()

    t = threading.Thread(target=tailer, daemon=True)
    t.start()

    try:
        splash.start_mainloop()
    except Exception:
        pass

    try:
        steam_proc.wait()
    except Exception:
        pass

if __name__ == "__main__":
    main()
