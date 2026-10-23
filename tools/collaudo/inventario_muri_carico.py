import json, sys, os, numpy as np
from PIL import Image, ImageFilter
G = '/home/user/wt/collaudo/godot/'
S = sys.argv[1]
R = json.load(open(f'{S}/tex/riassunto.json'))
visti = {}
for o in R:
    if o['area_verticale'] < 8:
        continue
    m = o['esempio']
    if m['classe'] == 'ShaderMaterial':
        p = m.get('parametri', {})
        al = p.get('albedo_tex') or p.get('base_albedo') or p.get('scrostata_albedo') or ''
        nr = p.get('normal_tex') or p.get('base_normal') or p.get('scrostata_normal') or ''
    else:
        al, nr = m.get('albedo', ''), m.get('normal', '')
    if not al.startswith('res://') or al in visti:
        continue
    f = G + al[6:]
    if not os.path.exists(f):
        continue
    im = Image.open(f).convert('L'); w, h = im.size
    sm = im.resize((512, 512))
    a = np.asarray(sm, dtype=np.float32) / 255
    blur = np.asarray(sm.filter(ImageFilter.GaussianBlur(8)), dtype=np.float32) / 255
    fine = np.asarray(sm.filter(ImageFilter.GaussianBlur(1.5)), dtype=np.float32) / 255
    contrasto = a.std()
    dettaglio = (fine - blur).std()      # macchie e dettagli medi-piccoli
    rumore = (a - fine).std()            # grana fine
    rilievo = None
    if nr.startswith('res://') and os.path.exists(G + nr[6:]):
        n = np.asarray(Image.open(G + nr[6:]).convert('RGB').resize((512, 512)), dtype=np.float32) / 127.5 - 1
        rilievo = float(np.sqrt(n[..., 0] ** 2 + n[..., 1] ** 2).mean())
    visti[al] = {'albedo': al, 'normal': nr, 'px': f'{w}x{h}', 'contrasto': round(float(contrasto), 3), 'dettaglio': round(float(dettaglio), 3),
                 'grana': round(float(rumore), 3), 'rilievo_normal': round(rilievo, 3) if rilievo is not None else None,
                 'area_verticale': o['area_verticale'], 'zone': list(o['zone'])[:3]}
L = sorted(visti.values(), key=lambda x: -(x['dettaglio'] + x['grana']))
json.dump(L, open(f'{S}/tex/carico.json', 'w'), indent=1)
for x in L:
    print(f"{x['dettaglio']:.3f} dett {x['grana']:.3f} grana {x['contrasto']:.3f} contr  normal {x['rilievo_normal']}  {x['px']:9s} {x['area_verticale']:7.1f} m²  {x['albedo'][6:]}")
