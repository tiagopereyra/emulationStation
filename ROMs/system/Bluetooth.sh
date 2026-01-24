#!/usr/bin/env python3
import tkinter as tk
import subprocess
import threading
import time
import math
import pygame
import re
import sys

# ============================================================
# ESTADO GLOBAL
# ============================================================

devices = {}  # mac -> {"name":..., "connected":..., "has_real_name":...}
visible_list = []

ITEMS_PER_PAGE = 5
current_page = 0
selected_row = 0
submenu_open = False
submenu_col = 0

feedback = ""
feedback_time = 0
stop_threads = False

pygame.init()
pygame.joystick.init()
joystick = None

def init_joystick():
    global joystick
    if pygame.joystick.get_count() > 0:
        joystick = pygame.joystick.Joystick(0)
        joystick.init()
        print(f"[🎮] Joystick detectado: {joystick.get_name()}")

init_joystick()

def refresh_joystick():
    global joystick
    pygame.joystick.quit()
    pygame.joystick.init()
    if pygame.joystick.get_count() > 0:
        joystick = pygame.joystick.Joystick(0)
        joystick.init()
        print(f"[🎮] Joystick re-detectado: {joystick.get_name()}")

# ============================================================
# BLUETOOTH BACKEND
# ============================================================

class BTManager:
    def __init__(self):
        self.proc = None
        self.lock = threading.Lock()

    def send(self, cmd):
        if self.proc and self.proc.stdin:
            try:
                with self.lock:
                    self.proc.stdin.write(cmd + "\n")
                    self.proc.stdin.flush()
            except Exception as e:
                print(f"[❌] Error al enviar comando: {e}")

    def listen(self):
        print("[📡] Iniciando Bluetooth...")
        # Forzar encendido
        subprocess.run(["bluetoothctl", "power", "on"], capture_output=True)
        
        self.proc = subprocess.Popen(
            ["bluetoothctl"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1
        )

        # Configuración inicial
        self.send("agent KeyboardOnly")
        self.send("default-agent")
        self.send("scan on")
        self.send("devices")

        # --- BARRIDO INICIAL PARA SABER QUIÉN ESTÁ CONECTADO ---
        out = subprocess.run(["bluetoothctl", "devices"], capture_output=True, text=True).stdout

        for line in out.splitlines():
            mac_match = re.search(r"Device ([0-9A-F:]{17}) (.+)", line)
            if not mac_match:
                continue

            mac = mac_match.group(1)
            name = mac_match.group(2).strip()

            devices[mac] = {
                "name": name,
                "connected": False,
                "has_real_name": True
            }

            # Consultar estado real
            info = subprocess.run(["bluetoothctl", "info", mac], capture_output=True, text=True).stdout
            if "Connected: yes" in info:
                devices[mac]["connected"] = True

        update_visible_list()
        # --- FIN BARRIDO INICIAL ---


        while not stop_threads:
            line = self.proc.stdout.readline()
            if not line: break
            
            # Debug: ver qué está leyendo el script (puedes comentarlo luego)
            # print(f"DEBUG: {line.strip()}") 

            mac_match = re.search(r"Device ([0-9A-F:]{17})", line)
            if mac_match:
                mac = mac_match.group(1)
                
                if mac not in devices:
                    devices[mac] = {"name": mac, "connected": False, "has_real_name": False}
                    print(f"[✨] Nuevo dispositivo detectado: {mac}")

                # Lógica de nombres
                name_match = re.search(r"Device [0-9A-F:]{17} (.+)", line)
                if name_match:
                    new_name = name_match.group(1).strip()
                    # Filtros para no romper el nombre
                    is_garbage = any(x in new_name for x in ["Connected:", "RSSI:", "Paired:", "ServicesResolved:"])
                    
                    if not is_garbage:
                        # Si es la primera vez o el nombre actual es solo la MAC, actualizamos
                        if not devices[mac]["has_real_name"] or devices[mac]["name"] == mac:
                            devices[mac]["name"] = new_name
                            if new_name != mac:
                                devices[mac]["has_real_name"] = True
                                print(f"[📝] Nombre fijado: {mac} -> {new_name}")

                if "Connected: yes" in line: 
                    devices[mac]["connected"] = True
                    refresh_joystick()
                if "Connected: no" in line: devices[mac]["connected"] = False
                
                update_visible_list()

    def connection_sequence(self, mac):
        global feedback, feedback_time
        feedback = "Emparejando..."
        feedback_time = time.time()
        
        print(f"[🔗] Iniciando secuencia para {mac}")
        self.send(f"trust {mac}")
        self.send(f"pair {mac}")
        time.sleep(2)
        self.send(f"connect {mac}")
        time.sleep(3)
        
        # Verificación final
        res = subprocess.run(["bluetoothctl", "info", mac], capture_output=True, text=True)
        if "Connected: yes" in res.stdout:
            feedback = "✅ ¡CONECTADO!"
            refresh_joystick()
            print(f"[🎉] Éxito con {mac}")
        else:
            feedback = "❌ Error de conexión"
            print(f"[⚠️] Fallo al conectar {mac}")
        feedback_time = time.time()

bt_manager = BTManager()

# ============================================================
# UI LOGIC & DRAW
# ============================================================

def update_visible_list():
    global visible_list
    temp = []

    # Construir lista base
    for mac, info in devices.items():
        name = info["name"]
        is_ctrl = any(k in name.lower() for k in ["controller", "wireless", "shock", "gamepad"])
        temp.append((name, mac, is_ctrl, info["connected"]))

    # Ordenar: conectados → mandos → alfabético
    temp.sort(key=lambda x: (not x[3], not x[2], x[0].lower()))

    # --- AGREGAR SUFIJOS A NOMBRES DUPLICADOS ---
    name_count = {}
    final = []

    for name, mac, is_ctrl, connected in temp:
        if name not in name_count:
            name_count[name] = 1
            final_name = name
        else:
            name_count[name] += 1
            final_name = f"{name} ({name_count[name]})"

        final.append((final_name, mac))

    visible_list = final


def activate_button():
    page = get_visible_page()
    if not page: return
    name, mac = page[selected_row]
    if submenu_col == 0:
        threading.Thread(target=bt_manager.connection_sequence, args=(mac,), daemon=True).start()
    elif submenu_col == 1:
        bt_manager.send(f"disconnect {mac}")
    elif submenu_col == 2:
        bt_manager.send(f"remove {mac}")
        if mac in devices: del devices[mac]
        update_visible_list()

root = tk.Tk()
root.attributes('-fullscreen', True)
root.configure(bg="#0D1117")

WIDTH = root.winfo_screenwidth()
HEIGHT = root.winfo_screenheight()
scale = WIDTH / 1920

canvas = tk.Canvas(root, bg="#0D1117", highlightthickness=0)
canvas.pack(fill="both", expand=True)

FONT_TITLE = ("Roboto", int(45*scale), "bold")
FONT_ITEM = ("Roboto", int(28*scale))
FONT_SMALL = ("Roboto", int(18*scale))

def get_total_pages(): return max(1, math.ceil(len(visible_list) / ITEMS_PER_PAGE))
def get_visible_page(): return visible_list[current_page*ITEMS_PER_PAGE : (current_page+1)*ITEMS_PER_PAGE]

def draw():
    canvas.delete("all")
    global feedback
    
    # Título decorativo
    canvas.create_text(WIDTH//2, 80, text="GESTIÓN DE DISPOSITIVOS BT", fill="#58A6FF", font=FONT_TITLE)
    
    if feedback and time.time() - feedback_time < 3:
        canvas.create_text(WIDTH//2, HEIGHT-100, text=feedback, fill="#3FB950", font=FONT_SMALL)

    page = get_visible_page()
    if not page:
        canvas.create_text(WIDTH//2, HEIGHT//2, text="Buscando dispositivos...", fill="#8B949E", font=FONT_ITEM)
    
    for i, (name, mac) in enumerate(page):
        is_sel = (i == selected_row)
        info = devices.get(mac, {})
        y = 220 + (i * 125)
        
        # Color: verde si conectado, blanco si no
        color = "#3FB950" if info.get("connected") else "#FFFFFF"

        # Flecha de selección
        selector = "> " if is_sel and not submenu_open else "  "

        # Icono según tipo
        prefix = "🎮 " if any(k in name.lower() for k in ["controller", "wireless"]) else "🎧 " if "head" in name.lower() else "📱 "

        canvas.create_text(
            WIDTH//2,
            y,
            text=f"{selector}{prefix}{name}",
            fill=color,
            font=("Roboto", int(35*scale))
        )


        if submenu_open and is_sel:
            draw_submenu(y + 50)

    # Ayuda visual inferior
    canvas.create_text(WIDTH//2, HEIGHT-30, text=f"Página {current_page+1}/{get_total_pages()} | [X] Seleccionar | [O] Atrás | L1/R1 Cambiar Página", fill="#484F58", font=FONT_SMALL)

def draw_submenu(y):
    opts = ["Vincular", "Desconectar", "Olvidar"]
    for i, txt in enumerate(opts):
        x = WIDTH//2 + (i-1)*200
        bg = "#1f6feb" if (submenu_col == i) else "#21262D"
        canvas.create_rectangle(x-85, y-20, x+85, y+20, fill=bg, outline="#58A6FF")
        canvas.create_text(x, y, text=txt, fill="white", font=FONT_SMALL)

def update_loop():
    handle_input()
    draw()
    root.after(30, update_loop)

def handle_input():
    global selected_row, submenu_open, submenu_col, current_page

    # --- JOYSTICK ---
    for event in pygame.event.get():

        # Botones
        if event.type == pygame.JOYBUTTONDOWN:
            if event.button == 0:  # X
                if not submenu_open:
                    submenu_open = True
                    submenu_col = 0
                else:
                    activate_button()

            elif event.button == 1:  # O / Círculo
                if submenu_open:
                    submenu_open = False
                else:
                    root.destroy()
                    sys.exit(0)

            elif event.button == 4:  # L1
                current_page = max(0, current_page - 1)
                selected_row = 0

            elif event.button == 5:  # R1
                current_page = min(get_total_pages() - 1, current_page + 1)
                selected_row = 0

        # D-PAD
        if event.type == pygame.JOYHATMOTION:
            hx, hy = event.value

            if not submenu_open:
                if hy == -1:  # Abajo
                    selected_row = min(len(get_visible_page()) - 1, selected_row + 1)
                elif hy == 1:  # Arriba
                    selected_row = max(0, selected_row - 1)

            else:
                if hx == 1:  # Derecha
                    submenu_col = min(2, submenu_col + 1)
                elif hx == -1:  # Izquierda
                    submenu_col = max(0, submenu_col - 1)


def handle_key(event):
    global selected_row, submenu_open, submenu_col, current_page

    # Navegación vertical
    if event.keysym == "Down":
        if not submenu_open:
            selected_row = min(len(get_visible_page()) - 1, selected_row + 1)

    elif event.keysym == "Up":
        if not submenu_open:
            selected_row = max(0, selected_row - 1)

    # Navegación horizontal en submenú
    elif event.keysym == "Left" and submenu_open:
        submenu_col = max(0, submenu_col - 1)

    elif event.keysym == "Right" and submenu_open:
        submenu_col = min(2, submenu_col + 1)

    # Abrir submenú
    elif event.keysym in ("Return", "space"):
        if not submenu_open:
            submenu_open = True
            submenu_col = 0
        else:
            activate_button()

    # Cerrar submenú
    elif event.keysym == "Escape":
        if submenu_open:
            submenu_open = False
        else:
            root.destroy()
            sys.exit(0)

    # Cambiar página
    elif event.keysym == "Left" and not submenu_open:
        current_page = max(0, current_page - 1)
        selected_row = 0

    elif event.keysym == "Right" and not submenu_open:
        current_page = min(get_total_pages() - 1, current_page + 1)
        selected_row = 0



# Iniciar procesos
threading.Thread(target=bt_manager.listen, daemon=True).start()
root.bind_all("<Key>", handle_key)
root.after(100, update_loop)
root.mainloop()
stop_threads = True