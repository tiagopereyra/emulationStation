#!/usr/bin/env python3
import subprocess
import signal
import time
import sys
import subprocess

def register_app(identifier):
    subprocess.run(["/usr/bin/register_app", str(identifier)])

# MATCHBOX = ["matchbox-window-manager", "-use_titlebar", "no", "-use_cursor", "no"]
VACUUMTUBE = ["flatpak", "run", "rocks.shy.VacuumTube"]

processes = []

def cleanup(*args):
    print("Cerrando procesos...")
    for p in processes:
        try:
            p.terminate()
        except:
            pass
    time.sleep(1)
    for p in processes:
        try:
            p.kill()
        except:
            pass
    sys.exit(0)

signal.signal(signal.SIGINT, cleanup)
signal.signal(signal.SIGTERM, cleanup)

try:
    print("Iniciando VacuumTube fullscreen…")
    p_vt = subprocess.Popen(VACUUMTUBE)
    processes.append(p_vt)
    register_app("vacuumtube")
    # Esperar a que VacuumTube termine
    p_vt.wait()

except KeyboardInterrupt:
    cleanup()
