# Comandi veri sul display (XTEST). Uso: python xin.py :99 <cartella scatti> "cmd; cmd; ..."
#  k Tasto [n]   premi il tasto n volte (nomi X: Down, Right, Return, Escape, F9...)
#  c x y         clic sinistro in (x, y)          m x y   muovi il mouse
#  d x0 y0 x1 y1 trascina col tasto sinistro      w s     aspetta s secondi
#  h Tasto s     tieni premuto il tasto s secondi
#  s nome        scatto della finestra (import -window root) in <cartella>/nome.png
import sys, time, subprocess, os
from Xlib import display, X, XK
from Xlib.ext import xtest
disp, cart, script = sys.argv[1], sys.argv[2], sys.argv[3]
d = display.Display(disp)
def tasto(nome):
    kc = d.keysym_to_keycode(XK.string_to_keysym(nome))
    xtest.fake_input(d, X.KeyPress, kc); d.sync(); time.sleep(0.08)
    xtest.fake_input(d, X.KeyRelease, kc); d.sync()
def muovi(x, y):
    xtest.fake_input(d, X.MotionNotify, x=int(x), y=int(y)); d.sync()
for cmd in [c.strip() for c in script.split(';') if c.strip()]:
    p = cmd.split()
    if p[0] == 'k':
        for _ in range(int(p[2]) if len(p) > 2 else 1):
            tasto(p[1]); time.sleep(0.45)
    elif p[0] == 'c':
        muovi(p[1], p[2]); time.sleep(0.15)
        xtest.fake_input(d, X.ButtonPress, 1); d.sync(); time.sleep(0.08)
        xtest.fake_input(d, X.ButtonRelease, 1); d.sync(); time.sleep(0.4)
    elif p[0] == 'm':
        muovi(p[1], p[2]); time.sleep(0.2)
    elif p[0] == 'd':
        muovi(p[1], p[2]); time.sleep(0.1)
        xtest.fake_input(d, X.ButtonPress, 1); d.sync()
        for t in range(1, 11):
            muovi(int(p[1]) + (int(p[3]) - int(p[1])) * t / 10, int(p[2]) + (int(p[4]) - int(p[2])) * t / 10); time.sleep(0.05)
        xtest.fake_input(d, X.ButtonRelease, 1); d.sync(); time.sleep(0.3)
    elif p[0] == 'h':
        kc = d.keysym_to_keycode(XK.string_to_keysym(p[1]))
        xtest.fake_input(d, X.KeyPress, kc); d.sync(); time.sleep(float(p[2]))
        xtest.fake_input(d, X.KeyRelease, kc); d.sync(); time.sleep(0.3)
    elif p[0] == 'w':
        time.sleep(float(p[1]))
    elif p[0] == 's':
        os.makedirs(cart, exist_ok=True)
        subprocess.run(['import', '-display', disp, '-window', 'root', os.path.join(cart, p[1] + '.png')])
    print('fatto:', cmd, flush=True)
