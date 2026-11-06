# Chiude la finestra di Godot come la X della finestra (WM_DELETE_WINDOW), sul display dato.
import sys
from Xlib import display, X, protocol
d = display.Display(sys.argv[1])
root = d.screen().root
WM_PROTOCOLS = d.intern_atom('WM_PROTOCOLS')
WM_DELETE = d.intern_atom('WM_DELETE_WINDOW')
def tutte(w):
    out = [w]
    for c in w.query_tree().children:
        out += tutte(c)
    return out
n = 0
for w in tutte(root):
    try:
        nome = w.get_wm_name() or ''
        prot = w.get_wm_protocols() or []
    except Exception:
        continue
    cl = None
    try:
        cl = w.get_wm_class()
    except Exception:
        pass
    if WM_DELETE in prot or (cl and cl[0] == 'Godot_Engine'):
        ev = protocol.event.ClientMessage(window=w, client_type=WM_PROTOCOLS, data=(32, [WM_DELETE, X.CurrentTime, 0, 0, 0]))
        w.send_event(ev, event_mask=0)
        print('chiusa', hex(w.id), nome)
        n += 1
d.flush()
print('finestre', n)
