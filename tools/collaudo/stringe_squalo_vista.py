import json, sys, numpy as np
sys.argv = [sys.argv[0].replace('stringe_squalo_vista.py','analisi_squalo.py'), sys.argv[1], sys.argv[2], 'x']
exec(open(sys.argv[0]).read().split('res = {')[0])
for fi in range(0, len(fot), 3):
    t = fot[fi]['t']
    if t < 9.8 or t > 11.6: continue
    sk = np.concatenate(pelle(fi)); cam = np.array(fot[fi]['camera'])
    c = sk.mean(0); v = c - cam; v[1] = 0; dist = np.linalg.norm(v); v /= dist
    lat = np.array([-v[2], 0, v[0]])
    m = sk[:, 0] < 22.15  # solo la parte ancora di qua dal muro della porta
    if m.sum() < 100: print(f"t {t:5.2f} oltre la porta"); continue
    p = sk[m]
    w = p @ lat; h = p[:, 1]
    # larghezza e altezza viste (angoli), della parte di qua
    print(f"t {t:5.2f} dist {dist:4.1f} m  largo {w.max()-w.min():.2f} m  alto {h.max()-h.min():.2f} m  rapporto {(w.max()-w.min())/(h.max()-h.min()):.2f}  vertici di qua {m.mean()*100:.0f}%")
