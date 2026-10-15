"""Le tre disposizioni dell'area bimbi proposte all'utente (15 ottobre 2026), senza soppalco.

Scrive godot/proposte/sala/disposizioni_bimbi.json (coordinate Godot) per godot/tests/proposte_sala.gd.
Le misure sono in coordinate di pianta (x est, y nord = -z di Godot), come in tools/blender/ambiente_sala.py.
La VascaBimbi1 con la fossa della tappa 8 resta dov'è; la scia della tappa 8 lungo il muro ovest resta libera.
Uso: python3 tools/proposte/disposizioni_bimbi.py
"""
import json, math, os

RADICE = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
STRUTTURA_OGGI = (-13.0, 16.0)          # centro della struttura nel GLB (ambiente_sala.STRUTTURA)
VB2_OGGI = (-15.3, 12.4)

# struttura: centro (x, y) e rotazione in gradi (antioraria vista dall'alto, come in Blender e in Godot)
# vb2: centro dell'acqua (2,8 x 2,8; con il bordo 3,4 x 3,4); funghi: (x, y, quale, rotazione) con
# quale = 27 (Ø 2,1 m) o 28 (Ø 1,6 m); festone: punti (x, y, quota)
DISPOSIZIONI = {
    'L1': dict(titolo="1 · Struttura nell'angolo",
               idea="struttura nell'angolo nord-ovest con la scala verso di te; lo scivolo scende nella vasca piccola, verso la spiaggia; piazza libera al centro",
               struttura=(-14.6, 19.6, 0.0), vb2=(-9.6, 18.2),
               funghi=[(-17.8, 12.2, 27, 20.0), (-12.2, 14.4, 28, 75.0)],
               festone=[(-20.0, 13.0, 4.2), (-15.9, 19.65, 7.35), (-12.9, 19.65, 7.35), (-8.0, 24.0, 4.2)]),
    'L2': dict(titolo='2 · Tutto intorno alla vasca',
               idea="struttura girata con il secchio verso di te; lo scivolo scende nella vasca a scacchi grande; vasca piccola con un fungo contro il muro ovest, l'altro fungo nella vasca grande",
               struttura=(-13.0, 15.6, -90.0), vb2=(-18.0, 11.8),
               funghi=[(-11.6, 9.6, 27, 20.0), (-18.0, 11.8, 28, 75.0)],
               festone=[(-20.0, 15.6, 4.2), (-12.95, 13.9, 7.35), (-9.85, 13.9, 7.35), (-9.0, 24.0, 4.2)]),
    'L3': dict(titolo='3 · Piazza e viale dei funghi',
               idea="struttura in fondo con il secchio sull'angolo davanti; lo scivolo scende a ovest nella vasca piccola; i due funghi in fila lungo il muro ovest; piazza libera davanti",
               struttura=(-14.0, 17.5, 180.0), vb2=(-18.0, 18.8),
               funghi=[(-18.4, 12.4, 27, 20.0), (-18.4, 15.2, 28, 75.0)],
               festone=[(-20.0, 10.5, 4.2), (-15.7, 14.35, 7.35), (-12.7, 14.35, 7.35), (-8.0, 24.0, 4.2)]),
}

# oggetti di scena sparsi nell'area bimbi da togliere (nodi di sala_oggetti.glb); restano i funghi e il salvagente sul muro
TOGLI_OGGETTI = ['ogg_balena_gonfiabile_sgonfia_26', 'ogg_cannoncino_acqua_29', 'ogg_cannoncino_acqua_30', 'ogg_cannoncino_acqua_31',
                 'ogg_cartello_pavimento_bagnato_92', 'ogg_cestino_pesce_87', 'ogg_lettino_plastica_75', 'ogg_orsacchiotto_grande_35',
                 'ogg_pallone_spiaggia_33', 'ogg_pallone_spiaggia_53', 'ogg_pallone_spiaggia_67', 'ogg_paperella_gigante_32',
                 'ogg_paperella_gigante_34', 'ogg_paperella_gigante_60', 'ogg_tubi_galleggianti_46']


def g(x, y, z=0.0):
    return [round(x, 3), round(z, 3), round(-y, 3)]


def ruota(cx, cy, a, dx, dy):
    c, s = math.cos(math.radians(a)), math.sin(math.radians(a))
    return (cx + dx * c - dy * s, cy + dx * s + dy * c)


def ingombri(L):
    """Rettangoli (x0, y0, x1, y1) occupati: per togliere i dettagli che ci finirebbero dentro."""
    cx, cy, a = L['struttura']
    r = []
    for (x0, y0, x1, y1) in ((-4.05, -2.65, 1.65, 3.05), (-3.3, -4.92, -1.9, -2.4)):   # torri e scala
        pts = [ruota(cx, cy, a, x, y) for x in (x0, x1) for y in (y0, y1)]
        r.append([min(p[0] for p in pts), min(p[1] for p in pts), max(p[0] for p in pts), max(p[1] for p in pts)])
    vx, vy = L['vb2']
    r.append([vx - 1.75, vy - 1.75, vx + 1.75, vy + 1.75])
    for (fx, fy, q, _) in L['funghi']:
        rr = 0.45 if q == 27 else 0.35
        r.append([fx - rr, fy - rr, fx + rr, fy + rr])
    return r


def main():
    out = {'nota': "Disposizioni dell'area bimbi (proposte, 15 ottobre 2026). Coordinate Godot. Scritto da tools/proposte/disposizioni_bimbi.py.",
           'struttura_oggi_godot': g(*STRUTTURA_OGGI), 'vb2_oggi_godot': g(*VB2_OGGI), 'togli_oggetti': TOGLI_OGGETTI,
           'area_godot': dict(x=[-20.0, -7.4], z=[-24.0, -3.0]), 'disposizioni': {}}
    for k, L in DISPOSIZIONI.items():
        cx, cy, a = L['struttura']
        secchio = ruota(cx, cy, a, 0.2, 1.6)
        out['disposizioni'][k] = dict(
            titolo=L['titolo'], idea=L['idea'],
            struttura=dict(centro_godot=g(cx, cy), rotazione_gradi=a),
            secchio_godot=g(*secchio, 7.1),
            vb2_godot=g(*L['vb2'], 0.02),
            funghi=[dict(nodo=f'ogg_fungo_fontana_{q}', pos_godot=g(x, y), rotazione_gradi=r) for (x, y, q, r) in L['funghi']],
            festone_godot=[g(x, y, z) for (x, y, z) in L['festone']],
            plafoniera_godot=g(secchio[0] + 2.5, secchio[1] - 6.5, 9.2), mira_plafoniera_godot=g(secchio[0], secchio[1] - 0.8, 4.4),
            ingombri_godot=[[x0, -y1, x1, -y0] for (x0, y0, x1, y1) in ingombri(L)])
    p = os.path.join(RADICE, 'godot', 'proposte', 'sala', 'disposizioni_bimbi.json')
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, 'w') as f:
        json.dump(out, f, indent=1, ensure_ascii=False)
    print('->', p)


if __name__ == '__main__':
    main()
