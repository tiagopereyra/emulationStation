#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
M-OS Overlay v3 — Dashboard con Iconos Reales (PNG/JPG).
Requiere: sudo apt install python3-pil python3-pil.imagetk
"""

import subprocess
import sys
import os
import time
import tkinter as tk
from tkinter import font as tkfont
from PIL import Image, ImageTk  # Necesario para manejar las imágenes

# ==========================
# 🎨 Configuración Visual
# ==========================

APP_TITLE = "M-OS Overlay"
WINDOW_ALPHA = 0.96

# Colores (Tu paleta Dark Blue)
C_BG_MAIN = "#000000"       
C_CARD_BG = "#111111"       
C_CARD_HOVER = "#1E6BFF"    
C_TEXT_MAIN = "#FFFFFF"     
C_TEXT_SEC = "#AAAAAA"      
C_DANGER = "#CF0000"        

# Tamaño de los iconos (en pixeles)
ICON_SIZE = 48 

# Ruta de las imágenes (Busca una carpeta 'assets' al lado del script)
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
ASSETS_DIR = os.path.join(BASE_DIR, "assets")

# ==========================
# ⚙️ Funciones
# ==========================

def run_cmd(cmd):
    try:
        subprocess.Popen(cmd)
    except Exception as e:
        print(f"[Error] {cmd}: {e}")

# Acciones
def action_es(): run_cmd(["emulationstation"])
def action_steam(): run_cmd(["flatpak", "run", "com.valvesoftware.Steam"])
def action_waydroid(): run_cmd(["waydroid", "show-full-ui"])
# Nota: Ajusta los comandos de Chrome según tus scripts .sh si es necesario
def action_xbox(): run_cmd(["flatpak", "run", "com.google.Chrome", "--kiosk", "https://www.xbox.com/play"])
def action_youtube(): run_cmd(["flatpak", "run", "com.google.Chrome", "--kiosk", "https://www.youtube.com/tv"])

def action_vol_up(): run_cmd(["pactl", "set-sink-volume", "@DEFAULT_SINK@", "+5%"])
def action_vol_down(): run_cmd(["pactl", "set-sink-volume", "@DEFAULT_SINK@", "-5%"])
def action_wifi(): subprocess.Popen([sys.executable, os.path.join(BASE_DIR, "dummy_settings.py"), "wifi"])
def action_reboot(): run_cmd(["systemctl", "reboot"])
def action_shutdown(): run_cmd(["systemctl", "poweroff"])

# ==========================
# 📋 Menú Configurado (5 Apps + Sistema)
# ==========================

MENU_ITEMS = [
    # --- APLICACIONES (Las 5 pedidas) ---
    {"type": "header", "label": "APLICACIONES"},
    
    {"img": "es.jpg", "label": "EmulationStation", "desc": "Volver al sistema principal", "fn": action_es},
    {"img": "steam.png", "label": "Steam Mode", "desc": "Lanzar Big Picture", "fn": action_steam},
    {"img": "waydroid.png", "label": "Waydroid", "desc": "Contenedor Android", "fn": action_waydroid},
    {"img": "xboxcloud.png", "label": "Xbox Cloud", "desc": "Juego en la nube", "fn": action_xbox},
    {"img": "youtube.png", "label": "YouTube", "desc": "Ver videos online", "fn": action_youtube},

    # --- CONTROL RÁPIDO ---
    {"type": "header", "label": "SISTEMA"},
    
    # Usamos emojis como fallback si no hay imagen, o puedes poner iconos genéricos
    {"icon": "🔊", "label": "Subir Volumen", "desc": "+5%", "fn": action_vol_up},
    {"icon": "🔉", "label": "Bajar Volumen", "desc": "-5%", "fn": action_vol_down},
    {"icon": "📡", "label": "Wi-Fi", "desc": "Configurar red", "fn": action_wifi},

    # --- ENERGÍA ---
    {"type": "header", "label": "ENERGÍA"},
    
    {"icon": "♻️", "label": "Reiniciar", "desc": "Reboot system", "fn": action_reboot, "danger": True},
    {"icon": "⏻", "label": "Apagar", "desc": "Shutdown system", "fn": action_shutdown, "danger": True},
]

# ==========================
# 🖥️ UI Class
# ==========================

class DashboardCard(tk.Frame):
    def __init__(self, parent, data, font_main, font_sub, on_click):
        super().__init__(parent, bg=C_BG_MAIN, highlightthickness=0)
        self.data = data
        self.on_click = on_click
        self.is_selected = False

        # Contenedor interno
        self.inner = tk.Frame(self, bg=C_CARD_BG, bd=0)
        self.inner.pack(fill="x", pady=2, padx=0, ipady=8)

        # --- LOGICA DE IMAGEN VS EMOJI ---
        self.icon_label = None
        
        # 1. Intentar cargar imagen si existe en la data
        if "img" in data:
            img_path = os.path.join(ASSETS_DIR, data["img"])
            if os.path.exists(img_path):
                try:
                    # Cargar y redimensionar con Pillow
                    pil_img = Image.open(img_path)
                    # Mantener relación de aspecto o forzar cuadrado? Forzamos cuadrado para uniformidad
                    pil_img = pil_img.resize((ICON_SIZE, ICON_SIZE), Image.Resampling.LANCZOS)
                    self.photo = ImageTk.PhotoImage(pil_img) # Guardar referencia!
                    
                    self.icon_label = tk.Label(self.inner, image=self.photo, bg=C_CARD_BG, bd=0)
                    self.icon_label.pack(side="left", padx=(15, 10))
                except Exception as e:
                    print(f"Error cargando {img_path}: {e}")

        # 2. Si falló la imagen o no tiene, usar emoji/texto
        if self.icon_label is None:
            text_icon = data.get("icon", "•")
            self.icon_label = tk.Label(self.inner, text=text_icon, font=(font_main, 20),
                                     bg=C_CARD_BG, fg=C_TEXT_MAIN, width=4)
            self.icon_label.pack(side="left")

        # Texto y Descripción
        text_frame = tk.Frame(self.inner, bg=C_CARD_BG)
        text_frame.pack(side="left", fill="both", expand=True)

        fg_color = C_DANGER if data.get("danger") else C_TEXT_MAIN
        self.lbl_title = tk.Label(text_frame, text=data["label"], font=(font_main, 14, "bold"),
                                  bg=C_CARD_BG, fg=fg_color, anchor="w")
        self.lbl_title.pack(fill="x", pady=(2,0))

        self.lbl_desc = tk.Label(text_frame, text=data["desc"], font=(font_sub, 10),
                                 bg=C_CARD_BG, fg=C_TEXT_SEC, anchor="w")
        self.lbl_desc.pack(fill="x")

        # Bindings
        for w in [self.inner, self.icon_label, self.lbl_title, self.lbl_desc, text_frame]:
            w.bind("<Enter>", lambda e: self.set_highlight(True))
            w.bind("<Leave>", lambda e: self.set_highlight(False))
            w.bind("<Button-1>", lambda e: self.execute())

    def set_highlight(self, active):
        if self.is_selected == active: return
        self.is_selected = active
        
        bg = C_CARD_HOVER if active else C_CARD_BG
        if active and self.data.get("danger"): bg = C_DANGER

        self.inner.configure(bg=bg)
        self.icon_label.configure(bg=bg) # El fondo de la imagen transparente tomará este color
        self.lbl_title.configure(bg=bg, fg=C_TEXT_MAIN if active else (C_DANGER if self.data.get("danger") else C_TEXT_MAIN))
        self.lbl_desc.configure(bg=bg, fg=C_TEXT_MAIN if active else C_TEXT_SEC)

    def execute(self):
        self.on_click(self.data["fn"])


class OverlayApp:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title(APP_TITLE)
        self.root.attributes("-fullscreen", True)
        self.root.configure(bg=C_BG_MAIN)
        try: self.root.attributes("-alpha", WINDOW_ALPHA)
        except: pass

        self.font_main = "Segoe UI" if os.name == "nt" else "Inter" # Fallback simple
        
        # Layout principal
        self.main_frame = tk.Frame(self.root, bg=C_BG_MAIN)
        self.main_frame.place(relx=0.5, rely=0.5, anchor="center", width=800, relheight=1.0) # Ancho fijo para prolijidad

        self.build_header()

        self.scroll_frame = tk.Frame(self.main_frame, bg=C_BG_MAIN)
        self.scroll_frame.pack(fill="both", expand=True, padx=20, pady=10)

        self.cards = []
        self.selected_index = 0
        self.build_menu()
        
        # Footer
        tk.Label(self.main_frame, text="ESC: Cerrar  |  ENTER: Seleccionar", bg=C_BG_MAIN, fg="#444", font=(self.font_main, 10)).pack(side="bottom", pady=20)

        # Teclas
        self.root.bind("<Escape>", lambda e: self.root.destroy())
        self.root.bind("<Up>", lambda e: self.move_selection(-1))
        self.root.bind("<Down>", lambda e: self.move_selection(1))
        self.root.bind("<Return>", lambda e: self.trigger_selected())

        self.update_selection_visuals()
        self.update_clock()

    def build_header(self):
        h = tk.Frame(self.main_frame, bg=C_BG_MAIN)
        h.pack(fill="x", pady=(40, 20), padx=20)
        tk.Label(h, text="M-OS", font=(self.font_main, 28, "bold"), fg=C_CARD_HOVER, bg=C_BG_MAIN).pack(side="left")
        self.clock = tk.Label(h, text="00:00", font=(self.font_main, 24), fg=C_TEXT_MAIN, bg=C_BG_MAIN)
        self.clock.pack(side="right")

    def build_menu(self):
        for item in MENU_ITEMS:
            if item.get("type") == "header":
                tk.Label(self.scroll_frame, text=item["label"], fg=C_CARD_HOVER, bg=C_BG_MAIN, font=(self.font_main, 9, "bold")).pack(anchor="w", pady=(15, 5))
                tk.Frame(self.scroll_frame, bg="#333", height=1).pack(fill="x", pady=(0, 5))
            else:
                card = DashboardCard(self.scroll_frame, item, self.font_main, self.font_main, self.run_action)
                card.pack(fill="x", pady=3)
                self.cards.append(card)

    def update_clock(self):
        self.clock.config(text=time.strftime("%H:%M"))
        self.root.after(1000, self.update_clock)

    def move_selection(self, d):
        self.selected_index = (self.selected_index + d) % len(self.cards)
        self.update_selection_visuals()

    def update_selection_visuals(self):
        for i, c in enumerate(self.cards): c.set_highlight(i == self.selected_index)

    def trigger_selected(self): self.cards[self.selected_index].execute()

    def run_action(self, fn):
        if fn: 
            fn()
            self.root.destroy()

if __name__ == "__main__":
    OverlayApp().root.mainloop()