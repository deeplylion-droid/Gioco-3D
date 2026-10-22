"""Correzioni al kit di dettagli della sala per il controllo di posizionamento del 22 ottobre sera (elenco di
ambienti-2, docs/tecnico/posizionamento/elenchi/ambienti-2.md, "96 casi in più", la parte Sala/Dettagli):
  - le corse di tubi lungo i muri finivano a mezz'aria ai due capi: a ogni capo un gomito che rientra nel muro
    (posti 'det_tubo_rientro_inizio' / 'det_tubo_rientro_fine', con 'sorgente' = il tubo della corsa: la mesh la
    fa DettagliSala, con il materiale del tubo);
  - fogli e alghe sul fondo in pendenza della piscina a onde: inclinati come il fondo e appoggiati;
  - fogli, carte, giocattoli e griglie qualche millimetro sopra il pavimento: appoggiati;
  - le cassette aperte sui muri (sportello all'altezza della testa): alzate sopra i 2 m, o tolte se lì sopra c'è
    una corsa di tubi;
  - carte, piastrelle e giocattoli finiti dentro palloni, scatoloni, colonnine e bordi: tolti (non hanno un posto
    vero sotto la pila), con il motivo in posizionamento_tolti_2026-10-22_sera.json (niente si perde).
Lavora su tutte e due le copie di posizionamento.json. Si può rilanciare (riconosce i posti già corretti).
Uso (dalla radice): python3 tools/dettagli_sala_22ottobre_sera.py
"""
import json, math, os, collections

RADICE = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
COPIE = [os.path.join(RADICE, 'godot', 'assets', 'ambiente', 'dettagli', 'posizionamento.json'),
         os.path.join(RADICE, 'assets_src', 'ambiente_dettagli', 'posizionamento.json')]
GLTF = os.path.join(RADICE, 'godot', 'assets', 'ambiente', 'dettagli', 'gltf')
TOLTI = os.path.join(RADICE, 'assets_src', 'ambiente_dettagli', 'posizionamento_tolti_2026-10-22_sera.json')

# (nodo, indice fra i posti di quel nodo, posizione attesa x z per riconoscerlo, motivo)
TOGLI = [
    ('det_barchetta', 0, (13.10, 18.27), 'dentro un pallone del mucchio (angolo dei palloni)'),
    ('det_carta_accartocciata_1', 3, (-18.00, 19.38), 'dentro uno scatolone'),
    ('det_carta_accartocciata_3', 10, (-16.77, 18.37), 'dentro uno scatolone'),
    ('det_ciabatta', 6, (-4.09, 12.80), 'dentro una colonnina del cordone della vasca'),
    ('det_foglio_1', 13, (13.03, 17.73), 'sotto un pallone del mucchio'),
    ('det_foglio_1', 14, (12.38, 17.81), 'sotto un pallone del mucchio'),
    ('det_foglio_2', 7, (14.88, 18.67), 'dentro un pallone del mucchio'),
    ('det_mucchio_piastrelle_1', 0, (-19.34, 19.21), 'dentro uno scatolone'),
    ('det_mucchio_piastrelle_1', 15, (14.90, 15.09), 'dentro un pallone del mucchio'),
    ('det_mucchio_piastrelle_3', 13, (12.01, 18.58), 'dentro un pallone del mucchio'),
    ('det_mucchio_piastrelle_3', 5, (13.22, 19.41), 'dentro due palloni del mucchio'),
    ('det_mucchio_piastrelle_3', 8, (-17.61, 18.62), 'dentro uno scatolone'),
    ('det_paletta', 1, (-18.63, 18.67), 'dentro uno scatolone'),
    ('det_piastrella_rotta_1', 17, (-8.81, 1.47), 'dentro il bordo dell\'arrivo dello scivolo'),
    ('det_piastrella_rotta_2', 5, (12.97, 19.66), 'dentro un pallone del mucchio'),
    ('det_piastrella_rotta_4', 2, (12.66, 19.22), 'dentro un pallone del mucchio'),
    ('det_piastrella_rotta_5', 21, (12.88, 18.00), 'dentro un pallone del mucchio'),
    ('det_piastrella_rotta_6', 20, (-8.85, -2.34), 'dentro il bordo dell\'arrivo dello scivolo'),
    ('det_secchiello', 1, (14.19, 19.57), 'dentro un pallone del mucchio'),
    ('det_vetri_rotti_3', 3, (18.49, 16.15), 'sotto un pallone del mucchio'),
    ('det_pannello_lamiera', 7, (-3.14, 17.17), 'lamiera alzata da terra in mezzo al passaggio dell\'ingresso'),
    ('det_foglio_1', 28, (-4.56, -1.13), 'a cavallo del punto dove il fondo della piscina comincia a salire: non poggia tutto'),
    ('det_alghe_secche_mucchio_1', 11, (-1.87, 2.26), 'nella conca dello scarico: il mucchio, piatto sotto, o restava sollevato o entrava nel fondo curvo'),
    ('det_alghe_secche_mucchio_2', 8, (0.35, 3.56), 'nella conca dello scarico: il mucchio, piatto sotto, o restava sollevato o entrava nel fondo curvo'),
    ('det_pannello_lamiera', 0, (-16.18, 19.11), 'sotto la pila di scatoloni (lo scatolone in fondo ci entrava)'),
    ('det_piastrella_rotta_6', 7, (-17.06, 19.27), 'sotto la pila di scatoloni'),
    ('det_applique_emergenza_spenta', 1, (17.70, 20.0), 'sommersa dal mucchio di palloni: non si vedeva (collaudo, punto 9)'),
    ('det_applique_emergenza_rotta', 0, (20.0, -0.59), 'a 20 cm da un\'altra applique: sembrava un doppione (collaudo, punto 11)'),
    ('det_cassetta_aperta', 4, (-11.44, -24.0), 'sportello aperto all\'altezza della testa e, sopra, la corsa di tubi: non si può alzare'),
]
# sul fondo in pendenza della piscina a onde: inclinati come il fondo e appoggiati
PISCINA = [('det_foglio_1', 19, (5.95, -12.77)), ('det_foglio_1', 27, (1.70, -8.66)),
           ('det_foglio_2', 37, (-0.98, -10.92)), ('det_foglio_4', 20, (0.94, -1.24))]
# qualche millimetro sopra il pavimento piatto: giù di quanto manca (m)
ABBASSA = [('det_barchetta', 7, (4.55, 12.95), 0.006), ('det_carta_accartocciata_3', 11, (-15.80, 18.65), 0.005),
           ('det_carta_accartocciata_3', 21, (5.42, 15.43), 0.005), ('det_carta_accartocciata_3', 24, (-9.58, 17.98), 0.005),
           ('det_foglio_1', 10, (4.50, 12.70), 0.005), ('det_foglio_2', 10, (-12.48, -22.56), 0.005),
           ('det_foglio_3', 28, (5.43, 17.25), 0.005), ('det_griglia_caduta', 6, (11.13, 14.35), 0.005),
           ('det_maschera_sub', 0, (-19.33, 4.66), 0.005), ('det_pesce_gomma', 9, (-17.67, 4.00), 0.006),
           ('det_pistola_acqua', 11, (8.89, -21.26), 0.021),
           ('det_asciugamano_3', 2, (-17.43, 3.24), 0.018)]    # (sopra la pozzanghera: collaudo, punto 14)
# spostati (nodo, indice, posizione attesa x z, spostamento x y z)
SPOSTA = [('det_applique_emergenza_rotta', 1, (20.0, 4.45), (0.0, 0.0, 0.6)),   # stava sopra la bocchetta tonda (collaudo, punto 10)
          ('det_macchia_ruggine_colata_muro', 12, (19.99, 15.01), (0.0145, 0.0, 0.0))]   # 1,5 cm staccata dal muro (punto 15)
# cassette aperte sui muri: lo sportello aperto (fino a 0,75 m sotto l'origine) sopra i 2 m
ALZA = [('det_cassetta_aperta', i, xz) for i, xz in ((0, (-1.67, 20.0)), (1, (20.0, 12.59)), (3, (-13.39, 20.0)), (5, (20.0, -5.42)))]
Y_CASSETTA = 2.78

# la piscina a onde (ambiente_sala.py, PISCINA e piscina_onde.zf), in coordinate Godot: x, z = -y Blender
P = dict(x0=-7.0, x1=7.0, y0=-5.0, y1=13.0, prof=2.0, y_pendenza=1.0, scarico=(0.0, -2.0))


def zf(x, z):
    y = -z
    if y <= P['y_pendenza']:
        h = -P['prof']
    else:
        h = -P['prof'] + P['prof'] * (y - P['y_pendenza']) / (P['y1'] - P['y_pendenza'])
    d = math.hypot(x - P['scarico'][0], y - P['scarico'][1])
    t = max(0.0, min(1.0, d / 4.6))
    return h - 0.24 * (1 - t * t * (3 - 2 * t))


def limiti():
    """Ingombro (min, max) di ogni nodo del kit, dai glTF."""
    out = {}
    for f in os.listdir(GLTF):
        if not f.endswith('.gltf'):
            continue
        g = json.load(open(os.path.join(GLTF, f)))
        for n in g['nodes']:
            if 'mesh' not in n:
                continue
            pr = g['meshes'][n['mesh']]['primitives']
            lo = [min(g['accessors'][p['attributes']['POSITION']]['min'][i] for p in pr) for i in range(3)]
            hi = [max(g['accessors'][p['attributes']['POSITION']]['max'][i] for p in pr) for i in range(3)]
            out[n['name']] = (lo, hi)
    return out


def mul(B, v):      # B = colonne
    return [B[0][i] * v[0] + B[1][i] * v[1] + B[2][i] * v[2] for i in range(3)]


def norm(v):
    L = math.sqrt(sum(c * c for c in v))
    return [c / L for c in v]


def cross(a, b):
    return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]


def ruota_su(B, n):
    """La basis B con l'asse su (Y) portato sulla normale n (rotazione minima)."""
    u = [0.0, 1.0, 0.0]
    a = cross(u, n)
    s = math.sqrt(sum(c * c for c in a))
    c = sum(u[i] * n[i] for i in range(3))
    if s < 1e-9:
        return B
    k = [x / s for x in a]
    ang = math.atan2(s, c)
    co, si = math.cos(ang), math.sin(ang)

    def rot(v):
        kv = cross(k, v)
        kd = sum(k[i] * v[i] for i in range(3))
        return [v[i] * co + kv[i] * si + k[i] * kd * (1 - co) for i in range(3)]
    return [rot(col) for col in B]


def trova(per, nodo, i, xz, chiave):
    lst = per.get(nodo, [])
    # già corretto in un giro prima: riconosciuto dal segno lasciato
    for q in lst:
        if q.get('corretto_22_sera') == chiave:
            return q
    if i >= len(lst):
        raise SystemExit(f'{nodo}[{i}] non c\'è')
    q = lst[i]
    if math.hypot(q['posizione'][0] - xz[0], q['posizione'][2] - xz[1]) > 0.8:
        raise SystemExit(f'{nodo}[{i}] è in {q["posizione"]}, non vicino a {xz}')
    return q


def main():
    lim = limiti()
    tolti = json.load(open(TOLTI)) if os.path.exists(TOLTI) else []
    for path in COPIE:
        if not os.path.exists(path):
            continue
        d = json.load(open(path))
        per = collections.defaultdict(list)
        for q in d['posti']:
            if not q['nodo'].startswith('det_tubo_rientro'):
                per[q['nodo']].append(q)
        # 1. i posti da togliere (prima di tutto si trovano, poi si toglie: gli indici restano quelli del controllo)
        via = []
        for nodo, i, xz, motivo in TOGLI:
            if any(t.get('chiave') == f'{nodo} {i}' for t in tolti):
                continue        # tolto in un giro prima
            via.append((trova(per, nodo, i, xz, f'via {nodo} {i}'), motivo, f'{nodo} {i}'))
        # 2. sul fondo della piscina
        for nodo, i, xz in PISCINA:
            q = trova(per, nodo, i, xz, f'piscina {nodo} {i}')
            if q.get('corretto_22_sera'):
                continue
            x, _, z = q['posizione']
            e = 0.05
            n = norm([-(zf(x + e, z) - zf(x - e, z)) / (2 * e), 1.0, -(zf(x, z + e) - zf(x, z - e)) / (2 * e)])
            B = ruota_su(q['basis'], n)
            lo, hi = lim[nodo]
            # il punto più basso della mesh, sopra il fondo in ogni angolo dell'ingombro
            y = -1e9
            for cx in (lo[0], hi[0]):
                for cz in (lo[2], hi[2]):
                    w = mul(B, [cx, lo[1], cz])
                    y = max(y, zf(x + w[0], z + w[2]) - w[1])
            q['basis'] = [[round(c, 4) for c in col] for col in B]
            q['posizione'][1] = round(y + 0.001, 4)
            q['corretto_22_sera'] = f'piscina {nodo} {i}'
        # 3. giù sul pavimento
        for nodo, i, xz, dy in ABBASSA:
            q = trova(per, nodo, i, xz, f'giu {nodo} {i}')
            if q.get('corretto_22_sera'):
                continue
            q['posizione'][1] = round(q['posizione'][1] - dy + 0.001, 4)
            q['corretto_22_sera'] = f'giu {nodo} {i}'
        for nodo, i, xz, dp in SPOSTA:
            q = trova(per, nodo, i, xz, f'sposta {nodo} {i}')
            if q.get('corretto_22_sera'):
                continue
            q['posizione'] = [round(q['posizione'][k] + dp[k], 4) for k in range(3)]
            q['corretto_22_sera'] = f'sposta {nodo} {i}'
        # 4. cassette aperte sopra i 2 m
        for nodo, i, xz in ALZA:
            q = trova(per, nodo, i, xz, f'su {nodo} {i}')
            q['posizione'][1] = Y_CASSETTA
            q['corretto_22_sera'] = f'su {nodo} {i}'
        ids = {id(q) for q, _, _ in via}
        for q, motivo, chiave in via:
            if path == COPIE[-1] and not any(t.get('chiave') == chiave for t in tolti):
                tolti.append({'posto': q, 'motivo': motivo, 'chiave': chiave})
        d['posti'] = [q for q in d['posti'] if id(q) not in ids and not q['nodo'].startswith('det_tubo_rientro')]
        # 5. i gomiti ai capi delle corse di tubi
        corse = collections.defaultdict(list)
        for q in d['posti']:
            if q['nodo'].startswith(('det_tubo_muro', 'det_tubi_paralleli')) and str(q.get('gruppo', '')).startswith('corsa'):
                corse[q['gruppo']].append(q)
        nuovi = []
        for g, lst in corse.items():
            primo, ultimo = lst[0], lst[-1]
            L = lim[ultimo['nodo']][1][0]
            fine = [ultimo['posizione'][k] + ultimo['basis'][0][k] * L for k in range(3)]
            for verso, q, pos in (('inizio', primo, primo['posizione']), ('fine', ultimo, fine)):
                nuovi.append({'nodo': f'det_tubo_rientro_{verso}', 'glb': q['glb'], 'sorgente': q['nodo'], 'zona': q.get('zona'),
                              'gruppo': g, 'posizione': [round(c, 4) for c in pos], 'rotazione_y_gradi': q.get('rotazione_y_gradi'),
                              'basis': q['basis']})
        d['posti'] += nuovi
        print(os.path.relpath(path, RADICE), 'tolti', len(via), 'gomiti', len(nuovi), 'posti', len(d['posti']))
        with open(path, 'w') as f:
            json.dump(d, f, ensure_ascii=False, indent=1)
    with open(TOLTI, 'w') as f:
        json.dump(tolti, f, ensure_ascii=False, indent=1)


if __name__ == '__main__':
    main()
