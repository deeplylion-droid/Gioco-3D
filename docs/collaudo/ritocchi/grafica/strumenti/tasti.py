# Tasti veri sul display dato (XTEST): python tasti.py :78 Down Down Return ...  (pausa di 0,6 s fra un tasto e l'altro)
import sys, time
from Xlib import display, X, XK
from Xlib.ext import xtest
d = display.Display(sys.argv[1])
s = d.screen()
xtest.fake_input(d, X.MotionNotify, x=s.width_in_pixels // 2, y=s.height_in_pixels // 2)
d.sync()
for nome in sys.argv[2:]:
    kc = d.keysym_to_keycode(XK.string_to_keysym(nome))
    xtest.fake_input(d, X.KeyPress, kc); d.sync(); time.sleep(0.15)
    xtest.fake_input(d, X.KeyRelease, kc); d.sync(); time.sleep(0.6)
    print('tasto', nome, kc)
