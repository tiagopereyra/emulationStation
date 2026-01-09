#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import subprocess
import sys
import os
import time
import socket
import threading
import tkinter as tk
from PIL import Image, ImageTk

# =========================
# CONFIG COMPORTAMIENTO
# =========================
WRAP_AROUND = False  # <- CAMBIÁ a True si querés que vuelva arriba/abajo al pasar el límite

# ==========================================
# 🔎 LECTURA DE ESTADO
# ==========================================

def get_volume_text():
    try:
        res = subprocess.check_output(["pactl", "get-sink-volume", "@DEFAULT_SINK@"], text=True)
        for part in res.replace("/", " ").replace(",", " ").split():
            if part.endswith("%") and part[:-1].isdigit():
                return f"Volumen: {part}"
        return "Volumen: --"
    except:
        return "Volumen: N/A"

def get_brightness_text():
    try:
        curr = int(subprocess.check_output(["brightnessctl", "g"], text=True))
        max_b = int(subprocess.check_output(["brightnessctl", "m"], text=True))
        if max_b == 0:
            return "Brillo: --"
        percent = int((curr / max_b) * 100)
        return f"Brillo: {percent}%"
    except:
        try:
            val = float(subprocess.check_output(["light", "-G"], text=True).strip())
            return f"Brillo: {int(val)}%"
        except:
            return "Nivel de Brillo"

def get_wifi_text():
    try:
        cmd = "nmcli -t -f active,ssid dev wifi | grep '^yes'"
        res = subprocess.check_output(cmd, shell=True, text=True, timeout=1).strip()
        ssid = res.split(":", 1)[1].strip() if ":" in res else ""
        return f"Conectado a: {ssid}" if ssid else "Wi-Fi: Desconectado"
    except:
        return "Wi-Fi: Sin datos"

def get_bt_text():
    try:
        res = subprocess.check_output(["bluetoothctl", "show"], text=True, timeout=1)
        return "Bluetooth: Encendido" if "Powered: yes" in res else "Bluetooth: Apagado"
    except:
        return "Bluetooth: N/A"

def get_night_light_state():
    try:
        res = subprocess.check_output(
            ["gsettings", "get", "org.gnome.settings-daemon.plugins.color", "night-light-enabled"],
            text=True
        ).strip()
        return res == "true"
    except:
        return False

# ==========================================
# 🎨 CONFIGURACIÓN VISUAL
# ==========================================

APP_TITLE = "M-OS Overlay"
WINDOW_ALPHA = 1.0  # más estable (evita glitches en algunos compositores)

C_BG_MAIN = "#000000"
C_CARD_BG = "#111111"
C_CARD_HOVER = "#1E6BFF"
C_TEXT_MAIN = "#FFFFFF"
C_TEXT_SEC = "#AAAAAA"
C_DANGER = "#CF0000"
ACCENT = "#22c55e"
BORDER = "#333333"

UI_SCALE = 1.0
ICON_SIZE_BASE = 48

def sc(x: int) -> int: return max(1, int(x * UI_SCALE))
def fs(x: int) -> int: return max(10, int(x * UI_SCALE))
def get_icon_size() -> int: return max(24, int(ICON_SIZE_BASE * UI_SCALE))

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
ASSETS_DIR = os.path.join(BASE_DIR, "assets")

# ==========================================
# ⚙️ EJECUCIÓN
# ==========================================

def run_fast(cmd):
    try:
        subprocess.Popen(cmd, start_new_session=True)
    except Exception as e:
        print(f"[Err] {cmd}: {e}")

def run_threaded_action(cmd_list, on_finish=None):
    def worker():
        for cmd in cmd_list:
            try:
                subprocess.run(cmd, check=True)
                break
            except Exception:
                pass
        if on_finish:
            on_finish()
    threading.Thread(target=worker, daemon=True).start()

# --- ACCIONES ---

def action_vol_up(): return [["pactl", "set-sink-volume", "@DEFAULT_SINK@", "+5%"]]
def action_vol_down(): return [["pactl", "set-sink-volume", "@DEFAULT_SINK@", "-5%"]]
def action_bri_up(): return [["brightnessctl", "set", "5%+"], ["light", "-A", "5"]]
def action_bri_down(): return [["brightnessctl", "set", "5%-"], ["light", "-U", "5"]]

def action_toggle_night_light():
    curr = get_night_light_state()
    new_state = "false" if curr else "true"
    return [[
        "gsettings", "set",
        "org.gnome.settings-daemon.plugins.color", "night-light-enabled",
        new_state
    ]]

def action_es(): run_fast(["es-de"]); return "hide"
def action_steam(): run_fast(["flatpak", "run", "com.valvesoftware.Steam"]); return "hide"
def action_waydroid(): run_fast(["waydroid", "show-full-ui"]); return "hide"
def action_xbox(): run_fast(["flatpak", "run", "com.google.Chrome", "--kiosk", "https://www.xbox.com/play"]); return "hide"
def action_youtube(): run_fast(["flatpak", "run", "com.google.Chrome", "--kiosk", "https://www.youtube.com/tv"]); return "hide"
def action_files(): run_fast(["nautilus"]); return "hide"
def action_back(): return "hide"
def action_discord(): run_fast(["flatpak", "run", "com.discordapp.Discord"]); return "hide"

def action_wifi():
    run_fast([sys.executable, os.path.join(BASE_DIR, "dummy_settings.py"), "wifi"])
    return "hide"

def action_bt():
    run_fast([sys.executable, os.path.join(BASE_DIR, "dummy_settings.py"), "bluetooth"])
    return "hide"

def action_reboot(): run_fast(["systemctl", "reboot"])
def action_shutdown(): run_fast(["systemctl", "poweroff"])

# ==========================================
# 📋 MENÚ
# ==========================================

MENU_ITEMS = [
    {"type": "header", "label": "APLICACIONES"},
    {"icon": "🏠", "label": "EmulationStation", "desc": "Volver al sistema principal", "fn": action_es},
    {"img": "steam.png", "label": "Steam Mode", "desc": "Lanzar Big Picture", "fn": action_steam},
    {"img": "waydroid.png", "label": "Waydroid", "desc": "Contenedor Android", "fn": action_waydroid},
    {"img": "xboxcloud.png", "label": "Xbox Cloud", "desc": "Juego en la nube", "fn": action_xbox},
    {"img": "youtube.png", "label": "YouTube", "desc": "Ver videos online", "fn": action_youtube},
    {"icon": "📁", "label": "Explorador de Archivos", "desc": "Gestionar archivos", "fn": action_files},

    {"type": "header", "label": "SISTEMA"},
    {"icon": "🎮", "label": "Volver al juego", "desc": "Ocultar menú", "fn": action_back},

    {"icon": "🔊", "label": "Subir Volumen", "desc_fn": get_volume_text, "fn": action_vol_up, "tag": "volume"},
    {"icon": "🔉", "label": "Bajar Volumen", "desc_fn": get_volume_text, "fn": action_vol_down, "tag": "volume"},

    {"icon": "☀", "label": "Subir Brillo", "desc_fn": get_brightness_text, "fn": action_bri_up, "tag": "bright"},
    {"icon": "🌙", "label": "Bajar Brillo", "desc_fn": get_brightness_text, "fn": action_bri_down, "tag": "bright"},

    {"icon": "🔵", "label": "Filtro Luz Azul", "desc": "Descanso visual",
     "fn": action_toggle_night_light, "tag": "night", "switch": True, "switch_val": get_night_light_state},

    {"icon": "📡", "label": "Wi-Fi", "desc_fn": get_wifi_text, "fn": action_wifi},
    {"icon": "🔵", "label": "Bluetooth", "desc_fn": get_bt_text, "fn": action_bt},
    {"icon": "💬", "label": "Discord", "desc": "Abrir chat de voz", "fn": action_discord},

    {"type": "header", "label": "ENERGÍA"},
    {"icon": "♻️", "label": "Reiniciar", "desc": "Reboot system", "fn": action_reboot, "danger": True},
    {"icon": "⏻", "label": "Apagar", "desc": "Shutdown system", "fn": action_shutdown, "danger": True},
]

# ==========================================
# 🧩 UI COMPONENTS
# ==========================================

class ToggleSwitch(tk.Canvas):
    def __init__(self, parent, width=50, height=26, bg=C_CARD_BG):
        super().__init__(parent, width=width, height=height, bg=bg, highlightthickness=0)
        self.state = False
        self.w, self.h = width, height

    def set_state(self, state):
        self.state = bool(state)
        self.draw()

    def draw(self):
        self.delete("all")
        track_col = ACCENT if self.state else BORDER
        pad = 4
        self.create_oval(0, 0, self.h, self.h, fill=track_col, outline="")
        self.create_oval(self.w-self.h, 0, self.w, self.h, fill=track_col, outline="")
        self.create_rectangle(self.h/2, 0, self.w-self.h/2, self.h, fill=track_col, outline="")
        d = self.h - (pad*2)
        x = (self.w - d - pad) if self.state else pad
        self.create_oval(x, pad, x+d, pad+d, fill="#FFFFFF", outline="")

class DashboardCard(tk.Frame):
    def __init__(self, parent, data, font_main, font_sub, on_click):
        super().__init__(parent, bg=C_BG_MAIN, highlightthickness=0)
        self.data = data
        self.on_click = on_click
        self.is_selected = False
        self.switch_widget = None

        self.inner = tk.Frame(self, bg=C_CARD_BG, bd=0)
        self.inner.pack(fill="x", pady=sc(2), padx=0, ipady=sc(8))

        self._setup_icon(data, font_main)

        text_frame = tk.Frame(self.inner, bg=C_CARD_BG)
        text_frame.pack(side="left", fill="both", expand=True)

        if data.get("switch"):
            self.switch_widget = ToggleSwitch(self.inner, width=sc(50), height=sc(26), bg=C_CARD_BG)
            self.switch_widget.pack(side="right", padx=sc(20))

        fg = C_DANGER if data.get("danger") else C_TEXT_MAIN
        self.lbl_title = tk.Label(text_frame, text=data["label"], font=(font_main, fs(14), "bold"),
                                  bg=C_CARD_BG, fg=fg, anchor="w")
        self.lbl_title.pack(fill="x", pady=(sc(2), 0))

        init_desc = data.get("desc", "...")
        self.lbl_desc = tk.Label(text_frame, text=init_desc, font=(font_sub, fs(10)),
                                 bg=C_CARD_BG, fg=C_TEXT_SEC, anchor="w")
        self.lbl_desc.pack(fill="x")

        widgets = [self.inner, self.icon_lbl, self.lbl_title, self.lbl_desc, text_frame]
        if self.switch_widget:
            widgets.append(self.switch_widget)
        for w in widgets:
            w.bind("<Enter>", lambda e: self.set_highlight(True))
            w.bind("<Leave>", lambda e: self.set_highlight(False))
            w.bind("<Button-1>", lambda e: self.execute())

    def _setup_icon(self, data, font):
        self.icon_lbl = None
        if "img" in data:
            path = os.path.join(ASSETS_DIR, data["img"])
            if os.path.exists(path):
                try:
                    img = Image.open(path)
                    sz = get_icon_size()
                    img.thumbnail((sz, sz), Image.Resampling.LANCZOS)
                    self.photo = ImageTk.PhotoImage(img)
                    self.icon_lbl = tk.Label(self.inner, image=self.photo, bg=C_CARD_BG, bd=0)
                    self.icon_lbl.pack(side="left", padx=(sc(15), sc(10)))
                except:
                    pass
        if not self.icon_lbl:
            txt = data.get("icon", "•")
            self.icon_lbl = tk.Label(self.inner, text=txt, font=(font, fs(20)),
                                     bg=C_CARD_BG, fg=C_TEXT_MAIN, width=max(3, int(4 * UI_SCALE)))
            self.icon_lbl.pack(side="left")

    def update_data(self):
        if "desc_fn" in self.data:
            self.lbl_desc.config(text=self.data["desc_fn"]())
        if self.switch_widget and "switch_val" in self.data:
            self.switch_widget.set_state(self.data["switch_val"]())
        try:
            self.inner.update_idletasks()
        except:
            pass

    def set_highlight(self, active):
        if self.is_selected == active:
            return
        self.is_selected = active
        bg = C_CARD_HOVER if active else C_CARD_BG
        if active and self.data.get("danger"):
            bg = C_DANGER

        self.inner.configure(bg=bg)
        self.icon_lbl.configure(bg=bg)
        self.lbl_title.configure(bg=bg, fg=C_TEXT_MAIN if active else (C_DANGER if self.data.get("danger") else C_TEXT_MAIN))
        self.lbl_desc.configure(bg=bg, fg=C_TEXT_MAIN if active else C_TEXT_SEC)

        if self.switch_widget:
            self.switch_widget.configure(bg=bg)
            self.switch_widget.draw()

    def execute(self):
        self.on_click(self)

# ==========================================
# 🖥️ APP PRINCIPAL
# ==========================================

class OverlayApp:
    def __init__(self):
        global UI_SCALE
        self.root = tk.Tk()
        self.root.title(APP_TITLE)

        self.root.withdraw()
        self.root.configure(bg=C_BG_MAIN)
        try:
            self.root.attributes("-alpha", WINDOW_ALPHA)
        except:
            pass

        sw, sh = self.root.winfo_screenwidth(), self.root.winfo_screenheight()
        UI_SCALE = max(1.0, min(min(sw/1920, sh/1080), 1.8))
        self.font = "Segoe UI" if os.name == "nt" else "Inter"

        self.main = tk.Frame(self.root, bg=C_BG_MAIN)
        self.main.place(relx=0.5, rely=0.5, anchor="center", width=sc(800), relheight=1.0)

        self._build_header()

        self.canvas = tk.Canvas(self.main, bg=C_BG_MAIN, highlightthickness=0, bd=0)
        self.canvas.pack(fill="both", expand=True, padx=sc(20), pady=sc(10))
        self.scroll_inner = tk.Frame(self.canvas, bg=C_BG_MAIN)
        self.win_id = self.canvas.create_window((0, 0), window=self.scroll_inner, anchor="nw")

        self.scroll_inner.bind("<Configure>", self._on_frame_configure)
        self.canvas.bind("<Configure>", self._on_canvas_configure)

        self.cards = []
        self.idx = 0
        self._build_menu()

        tk.Label(self.main, text="ESC: Cerrar  |  ENTER: Seleccionar  |  CONTROL+M: Abrir el menu",
                 bg=C_BG_MAIN, fg="#444", font=(self.font, fs(10))).pack(side="bottom", pady=sc(20))

        self.root.bind("<Escape>", lambda e: self.root.destroy())
        self.root.bind("<Up>", lambda e: self.move_sel(-1))
        self.root.bind("<Down>", lambda e: self.move_sel(1))
        self.root.bind("<Return>", lambda e: self.trigger())
        self.canvas.bind_all("<Button-4>", lambda e: self.canvas.yview_scroll(-3, "units"))
        self.canvas.bind_all("<Button-5>", lambda e: self.canvas.yview_scroll(3, "units"))
        self.canvas.bind_all("<MouseWheel>", self._on_mousewheel)

        self.update_vis()
        self.update_clock()
        self._start_socket()

        self.root.after(0, self.refresh_all_cards)
        self.periodic_refresh()

        self.root.after(2000, self.reveal_window)

    def _sync_scrollregion(self):
        self.scroll_inner.update_idletasks()
        self.canvas.update_idletasks()
        self.canvas.configure(scrollregion=self.canvas.bbox("all"))

    def scroll_to_top(self):
        self._sync_scrollregion()
        self.canvas.yview_moveto(0.0)

    def initial_position(self):
        self.idx = 0
        self.update_vis()
        self.scroll_to_top()

    def reveal_window(self):
        self.root.deiconify()
        self.root.attributes("-fullscreen", True)
        self.root.after(80, self.initial_position)

    def _on_frame_configure(self, event=None):
        self.canvas.configure(scrollregion=self.canvas.bbox("all"))

    def _on_canvas_configure(self, event):
        self.canvas.itemconfig(self.win_id, width=event.width)

    def refresh_all_cards(self):
        for c in self.cards:
            try:
                c.update_data()
            except:
                pass
        try:
            self.root.update_idletasks()
        except:
            pass

    def periodic_refresh(self):
        self.refresh_all_cards()
        self.root.after(2500, self.periodic_refresh)

    def _on_mousewheel(self, event):
        try:
            self.canvas.yview_scroll(int(-1 * (event.delta / 120)), "units")
        except:
            pass

    def _build_header(self):
        h = tk.Frame(self.main, bg=C_BG_MAIN)
        h.pack(fill="x", pady=(sc(40), sc(20)), padx=sc(20))
        tk.Label(h, text="M-OS", font=(self.font, fs(28), "bold"), fg=C_CARD_HOVER, bg=C_BG_MAIN).pack(side="left")
        self.clock = tk.Label(h, text="00:00", font=(self.font, fs(24)), fg=C_TEXT_MAIN, bg=C_BG_MAIN)
        self.clock.pack(side="right")

    def _build_menu(self):
        for item in MENU_ITEMS:
            if item.get("type") == "header":
                tk.Label(self.scroll_inner, text=item["label"], fg=C_CARD_HOVER, bg=C_BG_MAIN,
                         font=(self.font, fs(9), "bold")).pack(anchor="w", pady=(sc(15), sc(5)))
                tk.Frame(self.scroll_inner, bg="#333", height=1).pack(fill="x", pady=(0, sc(5)))
            else:
                c = DashboardCard(self.scroll_inner, item, self.font, self.font, self.on_card_click)
                c.pack(fill="x", pady=sc(3))
                self.cards.append(c)

        tk.Frame(self.scroll_inner, bg=C_BG_MAIN, height=sc(50)).pack(fill="x")

    def on_card_click(self, card):
        fn = card.data["fn"]
        res = fn()

        if res == "hide":
            self.root.withdraw()
            return

        if isinstance(res, list):
            tag = card.data.get("tag")

            def on_done_ui():
                if tag:
                    self.refresh_all_cards()

            run_threaded_action(res, on_finish=lambda: self.root.after(0, on_done_ui))

    def update_clock(self):
        self.clock.config(text=time.strftime("%H:%M"))
        self.root.after(1000, self.update_clock)

    # ✅ FIX DEFINITIVO: SIN WRAP (no salta arriba/abajo)
    def move_sel(self, d):
        if not self.cards:
            return

        n = len(self.cards)
        prev = self.idx

        if WRAP_AROUND:
            self.idx = (self.idx + d) % n
        else:
            # clamp
            self.idx = max(0, min(n - 1, self.idx + d))

        if self.idx == prev:
            return  # no cambió, no hacer nada

        self.update_vis()
        self.ensure_visible()

    def ensure_visible(self):
        if not self.cards:
            return
        card = self.cards[self.idx]

        self._sync_scrollregion()
        canvas_h = self.canvas.winfo_height()
        inner_h = self.scroll_inner.winfo_height()
        if inner_h <= canvas_h:
            return

        card_y = card.winfo_y()
        card_h = card.winfo_height()

        target_center = card_y + (card_h / 2)
        view_top = target_center - (canvas_h / 2)

        max_scroll = inner_h - canvas_h
        if view_top < 0:
            view_top = 0
        if view_top > max_scroll:
            view_top = max_scroll

        fraction = 0.0 if max_scroll <= 0 else (view_top / max_scroll)
        self.canvas.yview_moveto(max(0.0, min(1.0, fraction)))

    def update_vis(self):
        for i, c in enumerate(self.cards):
            c.set_highlight(i == self.idx)

    def trigger(self):
        self.cards[self.idx].execute()

    def _start_socket(self):
        p = "/tmp/mos_overlay.sock"
        if os.path.exists(p):
            try:
                os.unlink(p)
            except:
                pass

        def srv():
            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            s.bind(p)
            s.listen(1)
            try:
                os.chmod(p, 0o666)
            except:
                pass

            while True:
                try:
                    c, _ = s.accept()
                    msg = c.recv(1024).decode(errors="ignore")
                    if "toggle" in msg:
                        def do_toggle():
                            if self.root.state() == "withdrawn":
                                self.root.deiconify()
                                self.root.attributes("-fullscreen", True)
                                self.root.after(80, self.initial_position)
                            else:
                                self.root.withdraw()
                        self.root.after(0, do_toggle)
                    c.close()
                except:
                    pass

        threading.Thread(target=srv, daemon=True).start()

if __name__ == "__main__":
    if "--toggle" in sys.argv:
        try:
            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            s.connect("/tmp/mos_overlay.sock")
            s.sendall(b"toggle")
            s.close()
        except:
            pass
        sys.exit()

    OverlayApp().root.mainloop()
