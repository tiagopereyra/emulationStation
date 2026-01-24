#!/usr/bin/env python3
"""
wifi_config_joystick.py

Interfaz de configuración Wi-Fi en Tkinter controlada por joystick (pygame) y teclado físico,
utilizando nmcli para la gestión de red.
"""

import tkinter as tk
import subprocess
import pygame
import time
import math
import threading
import sys

# --- Variables Globales de Estado ---
proceso_wifi = None
stop_thread = False
joystick_detected = False 
# Variables de Estado de Mando
joystick = None
last_hat = (0, 0) 
last_press_time = {}
last_dpad_move_time = 0
is_on_connect_button = False

# --- Constantes ---
OPTIONS_BUTTON_INDEX = 9 # Botón Options (Start) - DEBEMOS CONFIRMAR ESTE INDICE CON DEBUG
DEBOUNCE_DELAY_BUTTON = 0.2
DEBOUNCE_DELAY_DPAD = 0.2 

# --- Inicialización Joystick ---
pygame.init()
pygame.joystick.init()

def try_connect_button():
    global show_keyboard, feedback, feedback_time

    if len(password) >= 8:
        show_keyboard = False
        start_connection_thread(redes[selected_index], password)
    else:
        feedback = "⚠️ Contraseña debe tener al menos 8 caracteres"
        feedback_time = time.time()

def init_joystick(device_index=0):
    """Inicializa un mando específico y actualiza el estado global."""
    global joystick, joystick_detected, last_hat
    
    pygame.joystick.quit() 
    pygame.joystick.init()
    
    try:
        if pygame.joystick.get_count() > 0:
            joystick = pygame.joystick.Joystick(device_index)
            joystick.init()
            joystick_detected = True
            last_hat = (0, 0)
            print(f"DEBUG: Mando detectado: {joystick.get_name()}")
            return True
        else:
            joystick = None
            joystick_detected = False
            last_hat = (0, 0)
            return False
    except pygame.error as e:
        print(f"Error al inicializar Pygame/Joystick: {e}", file=sys.stderr)
        joystick = None
        joystick_detected = False
        last_hat = (0, 0)
        return False

# Intentar inicializar al inicio (usando el índice 0 por defecto)
init_joystick()

# --- Funciones Wi-Fi ---
def ensure_wifi_enabled():
    try:
        subprocess.run(['nmcli', 'radio', 'wifi', 'on'], check=False, capture_output=True)
        subprocess.run(['nmcli', 'dev', 'reapply', 'wlan0'], check=False, capture_output=True)
    except Exception as e:
        print(f"Advertencia: No se pudo asegurar el estado ON del Wi-Fi: {e}", file=sys.stderr)

def listar_redes():
    try:
        result = subprocess.run(
            ['nmcli', '-t', '-f', 'SSID,SIGNAL', 'dev', 'wifi'], 
            capture_output=True, text=True, check=True, timeout=10
        )
        redes_raw = [r.strip() for r in result.stdout.split('\n') if r.strip()]
        redes_parsed = {}
        for line in redes_raw:
            parts = line.split(':')
            if len(parts) >= 2:
                ssid = parts[0]
                signal = int(parts[1]) if parts[1].isdigit() else 0
                if ssid not in redes_parsed:
                    redes_parsed[ssid] = signal
        
        redes_ordenadas = sorted(
            redes_parsed.keys(), 
            key=lambda ssid: (redes_parsed[ssid], ssid), 
            reverse=True
        )
        return redes_ordenadas if redes_ordenadas else ["No se encontraron redes Wi-Fi"]
    except subprocess.CalledProcessError:
        return ["Error al listar redes (nmcli)"]
    except Exception:
        return ["Error de sistema al listar redes"]

def start_connection_thread(ssid, pwd):
    global is_loading, feedback, feedback_time, stop_thread
    
    is_loading = True
    feedback = "Intentando conectar... Presiona Círculo/Escape para Cancelar."
    feedback_time = time.time()
    
    stop_thread = False
    thread = threading.Thread(target=conectar_wifi_threaded, args=(ssid, pwd,))
    thread.start()

def conectar_wifi_threaded(ssid, pwd):
    global is_loading, feedback, feedback_time, proceso_wifi, stop_thread

    try:
        proceso_wifi = subprocess.Popen(
            ['nmcli', 'dev', 'wifi', 'connect', ssid, 'password', pwd, 'ifname', 'wlan0', '--timeout', '30'], 
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True
        )

        while proceso_wifi.poll() is None and not stop_thread:
            time.sleep(0.1) 

        if stop_thread:
            proceso_wifi.terminate()
            try:
                proceso_wifi.wait(timeout=1)
            except subprocess.TimeoutExpired:
                proceso_wifi.kill()
            feedback = f"🛑 Conexión a '{ssid}' CANCELADA."
            feedback_time = time.time()
        
        elif proceso_wifi.returncode == 0:
            feedback = f"✅ Conectado a '{ssid}'!"
            feedback_time = time.time()
        else:
            stderr_output = proceso_wifi.stderr.read()
            if "Secrets were required" in stderr_output or "password" in stderr_output:
                 feedback = f"❌ Contraseña incorrecta para '{ssid}'."
            else:
                 feedback = f"❌ Error de nmcli (código {proceso_wifi.returncode})."
            feedback_time = time.time()
            
    except Exception as e:
        feedback = f"❌ Error interno de proceso: {e}"
        feedback_time = time.time()
    finally:
        is_loading = False
        proceso_wifi = None

# --- Tkinter UI y Lógica de Navegación ---
root = tk.Tk()
root.configure(bg="#00D62E")
root.geometry("800x600")
root.overrideredirect(False) 

WIDTH = root.winfo_screenwidth()
HEIGHT = root.winfo_screenheight()

canvas = tk.Canvas(root, bg="#0D1117", highlightthickness=0)
canvas.pack(fill="both", expand=True)

# PADDING DE BORDES (Escalado)
PADDING = int(30 * (WIDTH / 1920)) 
CANVAS_LEFT = PADDING
CANVAS_RIGHT = WIDTH - PADDING
CANVAS_TOP = PADDING
CANVAS_BOTTOM = HEIGHT - PADDING

# Escalado y Fuentes
scale = WIDTH / 1920
FONT_TITLE = ("Roboto", int(60 * scale), "bold")
FONT_HEADING = ("Roboto", int(36 * scale), "bold")
FONT_TEXT = ("Roboto", int(28 * scale))
FONT_SMALL = ("Roboto", int(20 * scale))
FONT_KEY = ("Roboto Mono", int(38 * scale), "bold") 

KEY_WIDTH = int(90 * scale)
KEY_HEIGHT = int(70 * scale)
KEY_PADDING_X = int(20 * scale)
KEY_PADDING_Y = int(20 * scale)

# Colores (ajustados a un tema oscuro)
TEXT_NORMAL = "#C9D1D9" 
TEXT_HIGHLIGHT = "#58A6FF" 
TEXT_ALERT = "#FF4B4B" 
TEXT_SUCCESS = "#3FB950" 

# Variables de estado
redes = []
selected_index = 0
show_keyboard = False
password = ""
scroll_offset = 0
item_height_with_padding = int(50 * scale) 
list_start_y = int(HEIGHT * 0.3)
scroll_max = max(1, int((HEIGHT - list_start_y - CANVAS_TOP - 100) / item_height_with_padding)) 
keyboard_page = 0
key_x, key_y = 0, 0
feedback = ""
feedback_time = 0
loading_animation_angle = 0
is_loading = False 

# Layouts de teclado (CONECTAR añadido como última fila)
keys_pages = [
    [list("ABCDEFGHIJ"), list("KLMNOPQRST"), list("UVWXYZ0123"), list("456789!@#$")],
    [list("abcdefghij"), list("klmnopqrst"), list("uvwxyz.-_?"), list("&*/+=<>(){}[]")],
    [list("áéíóúüñ¿¡"), list("ªº€¢£¥§¶"), list("ΑΒΓΔΕΖΗΘΙΚ"), list("АБГДЕЖЗИЙК")]
]

def handle_key_selection():
    global password, key_x, key_y, show_keyboard, feedback, feedback_time, is_loading
    current_page = keys_pages[keyboard_page]
    
    # 1. Manejar el botón CONECTAR
    if key_y == len(current_page) - 1 and current_page[key_y][key_x] == "CONECTAR":
        if len(password) >= 8:
            show_keyboard = False
            start_connection_thread(redes[selected_index], password)
        else:
            feedback = "⚠️ Contraseña debe tener al menos 8 caracteres"; feedback_time = time.time()
        return

    # 2. Manejar caracteres normales
    if 0 <= key_y < len(current_page) and 0 <= key_x < len(current_page[key_y]):
        selected_char = current_page[key_y][key_x]
        if len(password) < 64: 
            password += selected_char

def handle_page_change(direction):
    global keyboard_page, key_x, key_y
    new_page = keyboard_page + direction
    if 0 <= new_page < len(keys_pages):
        keyboard_page = new_page
        current_page = keys_pages[keyboard_page]
        if key_y >= len(current_page):
            key_y = len(current_page) - 1
        if key_x >= len(current_page[key_y]):
            key_x = len(current_page[key_y]) - 1

def handle_navigation(nav_x, nav_y):
    global selected_index, scroll_offset, key_x, key_y
    
    if not show_keyboard: 
        if nav_y == 1 and selected_index > 0: selected_index -= 1
        elif nav_y == -1 and selected_index < len(redes)-1: selected_index += 1
        
        if selected_index < scroll_offset: scroll_offset = selected_index
        elif selected_index >= scroll_offset + scroll_max: scroll_offset = selected_index - scroll_max + 1
    else:
        current_page = keys_pages[keyboard_page]
        max_y = len(current_page)  # una fila extra para el botón

        # Mover en X
        if nav_x == 1:
            if key_y < len(current_page):
                key_x = min(key_x + 1, len(current_page[key_y]) - 1)
        elif nav_x == -1:
            key_x = max(key_x - 1, 0)

        # Mover en Y
        if nav_y == 1:  # arriba
            key_y = max(key_y - 1, 0)
        elif nav_y == -1:  # abajo
            key_y = min(key_y + 1, max_y)

        # Si estamos en el botón, no hay X
        if key_y == max_y:
            key_x = 0



def handle_key_event(event):
    global show_keyboard, selected_index, password, feedback, feedback_time, key_x, key_y, stop_thread, keyboard_page, is_loading, redes
    
    if is_loading:
        if event.keysym in ('Escape', 'b'): 
            global proceso_wifi
            if proceso_wifi and proceso_wifi.poll() is None:
                stop_thread = True 
            is_loading = False
            show_keyboard = False
            return

    if not is_loading:
        if event.keysym in ('Up', 'Down', 'Left', 'Right'):
            nav_y = 1 if event.keysym == 'Up' else (-1 if event.keysym == 'Down' else 0)
            nav_x = 1 if event.keysym == 'Right' else (-1 if event.keysym == 'Left' else 0)
            handle_navigation(nav_x, nav_y)
            return

        if not show_keyboard:
            if event.keysym in ('Return', 'x'): 
                if redes and redes[selected_index] not in ["Error al listar redes (nmcli)", "Error de sistema al listar redes", "No se encontraron redes Wi-Fi"]:
                    show_keyboard = True
                    key_x, key_y = 0, 0
                else:
                    feedback = "Selecciona una red válida."; feedback_time = time.time()
            elif event.keysym in ('t', 'y', 'Escape'): 
                root.destroy(); return
            elif event.keysym in ('r', 'l', 'R', 'L'): 
                feedback = "🔄 Buscando redes..."; feedback_time = time.time()
                redes[:] = listar_redes() 
                selected_index = 0
                scroll_offset = 0
        else: 
            if event.keysym == 'Return':
                if key_y == len(keys_pages[keyboard_page]):
                    try_connect_button()
                else:
                    handle_key_selection()
            elif event.char and event.char.isprintable() and event.char not in ('\r', '\n', '\t'): 
                if len(password) < 64: 
                    password += event.char
                
            elif event.keysym in ('BackSpace', 'q'): 
                password = password[:-1]
                
            # Eliminamos Space/Start para conexión, ahora se usa el botón CONECTAR
            
            elif event.keysym in ('Escape', 'b'): 
                show_keyboard = False
                feedback = "Volviendo a la lista de redes"; feedback_time = time.time()
            elif event.keysym in ('t', 'y'): 
                root.destroy(); return
            elif event.keysym in ('R', 'r', 'Page_Down'): handle_page_change(1) 
            elif event.keysym in ('L', 'l', 'Page_Up'): handle_page_change(-1) 
        
root.bind('<Key>', handle_key_event) 


# --- Dibujar ---
def draw_loading_animation():
    global loading_animation_angle
    if not is_loading: return
    center_x, center_y = WIDTH // 2, HEIGHT // 2
    radius = int(50 * scale)
    dot_radius = int(8 * scale)
    canvas.create_oval(center_x - radius, center_y - radius,
                       center_x + radius, center_y + radius,
                       outline="#21262D", width=int(2*scale))
    angle_rad = math.radians(loading_animation_angle)
    dot_x = center_x + radius * math.cos(angle_rad)
    dot_y = center_y + radius * math.sin(angle_rad)
    canvas.create_oval(dot_x - dot_radius, dot_y - dot_radius,
                       dot_x + dot_radius, dot_y + dot_radius,
                       fill=TEXT_HIGHLIGHT, outline="")
    loading_animation_angle = (loading_animation_angle + 10) % 360 

def draw():
    canvas.delete("all")
    global feedback, feedback_time, is_loading, joystick_detected

    if feedback and time.time() - feedback_time < 3: 
        color = TEXT_SUCCESS if "Conectado" in feedback else (TEXT_ALERT if "Error" in feedback or "CANCELADA" in feedback else TEXT_HIGHLIGHT)
        canvas.create_text( WIDTH // 4, HEIGHT // 2 + 320, text=feedback, 
                           fill=color, font=FONT_TEXT, anchor="n", justify="left")
        
    if is_loading:
        draw_loading_animation()
        canvas.create_text(WIDTH//2, CANVAS_BOTTOM - int(50*scale),
                            text="Presiona Círculo/Escape para CANCELAR Conexión",
                            fill=TEXT_HIGHLIGHT, font=FONT_SMALL)
        root.after(16, update)
        return

    title_y = CANVAS_TOP + int(40*scale)
    list_start_y = int(HEIGHT * 0.3)
    
    if not show_keyboard:
        canvas.create_text(WIDTH//2, title_y, text="Redes Wi-Fi Disponibles",
                            fill=TEXT_HIGHLIGHT, font=FONT_TITLE)
        
        item_height = int(50*scale)
        visible_redes_count = min(scroll_max, len(redes) - scroll_offset)
        
        for i in range(visible_redes_count):
            network_idx = scroll_offset + i
            color = TEXT_HIGHLIGHT if network_idx == selected_index else TEXT_NORMAL
            y_pos = list_start_y + i * item_height
            
            text = redes[network_idx]
            canvas.create_text(WIDTH//2, y_pos + int(5*scale),
                                text=text, fill=color, font=FONT_HEADING, anchor="center")
        
        if scroll_offset > 0:
            canvas.create_text(WIDTH//2, list_start_y - int(30*scale), text="▲", fill=TEXT_NORMAL, font=FONT_SMALL, anchor="s")
        if scroll_offset + scroll_max < len(redes):
            canvas.create_text(WIDTH//2, list_start_y + visible_redes_count * item_height + int(30*scale), text="▼", fill=TEXT_NORMAL, font=FONT_SMALL, anchor="n")

        instructions = "X/Enter = Contraseña | Triángulo/Escape = Salir | L1/R1 = Refrescar"
        if not joystick_detected:
             instructions = "Enter = Contraseña | Escape = Salir | R = Refrescar"
        canvas.create_text(WIDTH//2, CANVAS_BOTTOM - int(10*scale),
                            text=instructions,
                            fill=TEXT_NORMAL, font=FONT_SMALL)
    else:
        canvas.create_text(WIDTH//2, CANVAS_TOP + int(40*scale), 
                            text=f"🔑 Contraseña para {redes[selected_index]}",
                            fill=TEXT_HIGHLIGHT, font=FONT_HEADING)
        
        # MOSTRAR CONTRASEÑA SIN CENSURAR
        canvas.create_text(WIDTH//2, CANVAS_TOP + int(120*scale), 
                            text=password if password else "Ingresa tu contraseña...",
                            fill=TEXT_NORMAL if password else "#6A737D", font=FONT_TEXT)

        current_page = keys_pages[keyboard_page]
        keyboard_start_x = CANVAS_LEFT + KEY_WIDTH/2
        keyboard_start_y = int(HEIGHT*0.35 + KEY_HEIGHT/2)

        for y,row in enumerate(current_page):
            for x,k in enumerate(row):
                if x >= len(row): continue 
                
                # Manejar el botón CONECTAR (última fila)
                if k == "CONECTAR":
                    pos_x = WIDTH // 2 
                    pos_y = keyboard_start_y + y*(KEY_HEIGHT + KEY_PADDING_Y)
                    
                    if x==key_x and y==key_y:
                        canvas.create_rectangle(
                            pos_x - KEY_WIDTH * 2 - int(5*scale), 
                            pos_y - KEY_HEIGHT/2 - int(5*scale),
                            pos_x + KEY_WIDTH * 2 + int(5*scale),
                            pos_y + KEY_HEIGHT/2 + int(5*scale),
                            outline=TEXT_HIGHLIGHT, 
                            width=int(3*scale) 
                        )
                    
                    text_color = TEXT_HIGHLIGHT if x==key_x and y==key_y else TEXT_SUCCESS
                    canvas.create_text(pos_x, pos_y,
                                        text=k, fill=text_color, font=FONT_KEY)
                    break 
                
                # Dibujo de caracteres normales
                pos_x = keyboard_start_x + x*(KEY_WIDTH + KEY_PADDING_X)
                pos_y = keyboard_start_y + y*(KEY_HEIGHT + KEY_PADDING_Y)
                
                text_color = TEXT_NORMAL

                if x==key_x and y==key_y:
                    canvas.create_rectangle(
                        pos_x - KEY_WIDTH/2 - int(5*scale), 
                        pos_y - KEY_HEIGHT/2 - int(5*scale),
                        pos_x + KEY_WIDTH/2 + int(5*scale),
                        pos_y + KEY_HEIGHT/2 + int(5*scale),
                        outline=TEXT_HIGHLIGHT, 
                        width=int(3*scale) 
                    )
                    text_color = TEXT_HIGHLIGHT
                
                canvas.create_text(pos_x, pos_y,
                                    text=k, fill=text_color, font=FONT_KEY)
        
        page_info = f"Página {keyboard_page+1}/{len(keys_pages)}"
        # ============================
        # BOTÓN CONECTAR (FIJO)
        # ============================
        btn_w = int(300 * scale)
        btn_h = int(90 * scale)
        btn_x1 = WIDTH - btn_w - int(40 * scale) - 100
        btn_y1 = HEIGHT - btn_h - int(60 * scale) - 100
        btn_x2 = btn_x1 + btn_w
        btn_y2 = btn_y1 + btn_h

        is_selected = (key_y == len(current_page))  # última fila virtual

        canvas.create_rectangle(
            btn_x1, btn_y1, btn_x2, btn_y2,
            fill="#3381FF" if is_selected else "#0947B9",
            outline="#ffffff",
            width=int(4 * scale)
        )

        canvas.create_text(
            (btn_x1 + btn_x2)//2,
            (btn_y1 + btn_y2)//2,
            text="CONECTAR",
            fill="white",
            font=FONT_HEADING
        )

        canvas.create_text(CANVAS_LEFT, keyboard_start_y + len(current_page) * (KEY_HEIGHT + KEY_PADDING_Y) + int(20 * scale), 
                            text=page_info, fill=TEXT_NORMAL, font=FONT_SMALL, anchor='w')

        instructions_keyboard = "X/Enter = Seleccionar | Cuadrado/Backspace = Borrar | Círculo/Escape = Volver | Triángulo = Salir | L1/R1 = Cambiar Página"
        if not joystick_detected:
            instructions_keyboard = "Enter = Seleccionar | Backspace = Borrar | Escape = Volver | Letras/Números = Entrada Directa"

        canvas.create_text(WIDTH//2, HEIGHT - 100,
                            text=instructions_keyboard,
                            fill="#BBBBBB", font=FONT_SMALL)

    root.after(16, update)

# ----------------------------------------------------------------------
# --- Lógica Joystick (MODO DEBUG ACTIVO) ---
# ----------------------------------------------------------------------

def is_button_pressed(button_id, delay=DEBOUNCE_DELAY_BUTTON):
    """Verifica si un botón fue presionado con debounce de tiempo."""
    global last_press_time
    current_time = time.time()
    
    if joystick and button_id < joystick.get_numbuttons() and joystick.get_button(button_id):
        if current_time - last_press_time.get(button_id, 0) > delay:
            last_press_time[button_id] = current_time
            return True
    return False

def check_options_button():
    """Verifica el botón Options (Start) usando el índice 9."""
    return is_button_pressed(OPTIONS_BUTTON_INDEX)

def check_joystick_status():
    """Actualiza el estado del joystick y usa pump()."""
    global joystick, joystick_detected
    
    pygame.event.pump() 

    if joystick is None and pygame.joystick.get_count() > 0:
        print("Intentando reconectar el mando...")
        init_joystick(0)
    
    if joystick is None:
        joystick_detected = False
    else:
        joystick_detected = True


def update():
    """Bucle principal de actualización de UI y lectura de joystick (MODO DEBUG)."""
    global redes, selected_index, scroll_offset, show_keyboard, password, key_x, key_y, last_hat, last_dpad_move_time, feedback, feedback_time, keyboard_page, is_loading, stop_thread, joystick
    
    check_joystick_status()

    # 1. Manejar Carga/Cancelación (Prioridad Alta)
    if is_loading and joystick and is_button_pressed(1, delay=0.5): # Botón 1 es Círculo/B
        global proceso_wifi
        if proceso_wifi and proceso_wifi.poll() is None:
            stop_thread = True 
        is_loading = False
        show_keyboard = False
        draw()
        return
    # 2. Lógica del Mando (Solo si NO está cargando Y hay joystick)
    if not is_loading and joystick:
        
        current_time = time.time()
        nav_processed = False 

       # --- LECTURA CORRECTA DEL D-PAD (HAT) ---
        pygame.event.pump()  

        if joystick.get_numhats() > 0:
            hat_x, hat_y = joystick.get_hat(0)

        if (hat_x, hat_y) != (0, 0):
            print(f"DEBUG: D-Pad movido: {(hat_x, hat_y)}")

        # Debounce + movimiento
        if (hat_x, hat_y) != last_hat and (hat_x, hat_y) != (0, 0):
            if current_time - last_dpad_move_time > DEBOUNCE_DELAY_DPAD:
                handle_navigation(hat_x, hat_y)
                last_dpad_move_time = current_time

        last_hat = (hat_x, hat_y)


        # --- B. MODO DEBUG BOTONES (Para encontrar Options/Start) ---
        for i in range(joystick.get_numbuttons()):
            if i not in [0, 1, 2, 3, 4, 5]: # Ignoramos los botones de acción para no spammear
                if joystick.get_button(i) and current_time - last_press_time.get(i, 0) > DEBOUNCE_DELAY_BUTTON:
                    print(f"DEBUG: BOTÓN PRESIONADO: {i}")
                    last_press_time[i] = current_time

        # --- C. Lógica de Botones ---
        
        if not show_keyboard:
            # Lista de Redes
            if is_button_pressed(0): # X/A: Ingresar contraseña
                if redes and redes[selected_index] not in ["Error..."]:
                    show_keyboard = True
                    key_x, key_y = 0, 0
                else:
                    feedback = "Selecciona una red válida."; feedback_time = time.time()
            elif is_button_pressed(2): root.destroy(); return # Triángulo/Y: Salir
            elif is_button_pressed(4) or is_button_pressed(5): # L1/R1: Refrescar Lista
                feedback = "🔄 Buscando redes..."; feedback_time = time.time()
                redes[:] = listar_redes()
                selected_index = 0
                scroll_offset = 0
        else:
            # Teclado
            if is_button_pressed(0):  # X
                if key_y == len(keys_pages[keyboard_page]):
                    try_connect_button()
                else:
                    handle_key_selection()
 # X/A: Seleccionar carácter o CONECTAR
            elif is_button_pressed(3): password = password[:-1] # Cuadrado/X: Borrar
            
            # NOTA: La conexión ahora se hace con X/A seleccionando el botón CONECTAR
            
            elif is_button_pressed(1): # Círculo/B: Volver
                show_keyboard = False
                feedback = "Volviendo a la lista de redes"; feedback_time = time.time()
            elif is_button_pressed(3): root.destroy(); return # Triángulo/Y: Salir
            elif is_button_pressed(5): handle_page_change(1) # R1: Siguiente Página
            elif is_button_pressed(4): handle_page_change(-1) # L1: Página Anterior

    draw()

# --- Ejecución ---
if __name__ == "__main__":
    ensure_wifi_enabled()
    
    try:
        feedback = "Buscando redes Wi-Fi..."; feedback_time = time.time()
        is_loading = True
        
        canvas.create_text(WIDTH//2, HEIGHT//2,
                           text="Buscando redes Wi-Fi...",
                           fill=TEXT_HIGHLIGHT, font=FONT_HEADING)
        root.update()
        
        redes = listar_redes()
        is_loading = False
        feedback = ""

        root.after(0, update)
        root.mainloop()

    except tk.TclError:
        pass
    except Exception as e:
        print(f"Error fatal: {e}", file=sys.stderr)
    finally:
        pygame.quit()