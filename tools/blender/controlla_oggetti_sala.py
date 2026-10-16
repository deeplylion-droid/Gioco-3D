"""Controllo degli oggetti della sala principale che galleggiano o entrano nello sfondo (riscontro C3 dell'utente:
"gonfiabile azzurro incastrato nella scala. Controllare meglio che non ci siano altri oggetti compenetrati con
lo sfondo"). Lavora sui GLB del gioco, come li vede Godot: carica i pezzi della sala e ci rimette sopra gli
oggetti di scena (sala_oggetti.glb e le offerte della vasca) e i 1000 e più posti del kit di dettagli
(posizionamento.json). Per ogni oggetto guarda:
  - ENTRA: quanto i suoi vertici stanno dentro i solidi dello sfondo. I solidi sono le forme di collisione
    dei GLB (-colonly / -convcolonly: muri, pavimento, bordi delle vasche, scale, pedane, cordone...):
    sono loro a dire dov'è il "pieno". Si segnala oltre 3 cm.
  - GALLEGGIA: la distanza fra l'oggetto e la superficie più vicina (sfondo, acqua o un altro oggetto).
    Se non tocca niente entro 3 cm è sospeso nel vuoto.
  - INTERSECA: i triangoli dell'oggetto tagliano quelli dello sfondo visibile (anche dove non c'è una
    collisione: ringhiere, scivoli, pali) e i suoi vertici passano dall'altra parte di oltre 3 cm.
Ispirato a tools/blender/controlla_oggetti.py di ambienti-1 (branch lavoro/ambienti-1).

Con --correggi sistema i posti del kit di dettagli che hanno un problema (in tutte e due le copie di
posizionamento.json): quelli a terra si appoggiano alla superficie sotto di loro, inclinati come lei (sul
fondo in pendenza della piscina restavano dritti e mezzi sepolti); quelli che entrano in un muro o in un
bordo escono dalla faccia più vicina (di lato, se si può). Le lampade a muro (applique) non si toccano: la
loro piastra sta 4 cm dentro il muro e non si vede. Gli oggetti di scena si sistemano in ambiente_sala.py.

Uso (dalla radice): /home/user/tools/blender-venv/bin/python tools/blender/controlla_oggetti_sala.py \
        [--glb godot/assets/ambiente/sala] [--dettagli godot/assets/ambiente/dettagli] [--json uscita.json] [--correggi]
Esce con 1 se trova problemi.
"""
import argparse, json, math, os, sys
import bpy
import numpy as np
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

RADICE = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))
STRUTTURE = ['sala_architettura', 'sala_piscina', 'sala_area_bimbi', 'sala_vasca_centrale', 'sala_torre_scivoli',
             'sala_interattivi']
ACQUA = 'sala_acqua'
OGGETTI = 'sala_oggetti'
SOGLIA_ENTRA = 0.03
SOGLIA_GALLEGGIA = 0.03
# Godot (Y in alto) -> Blender (Z in alto): (x, y, z) -> (x, -z, y)
C = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))


def e_collisione(o):
    return '-colonly' in o.name or '-convcolonly' in o.name


def importa(percorso):
    prima = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=percorso)
    return [o for o in bpy.data.objects if o not in prima]


def vertici_mondo(o):
    me = o.data
    co = np.empty(len(me.vertices) * 3, dtype=np.float64)
    me.vertices.foreach_get('co', co)
    co = co.reshape(-1, 3)
    mw = np.array(o.matrix_world)
    return co @ mw[:3, :3].T + mw[:3, 3]


def campione(co, n=1500, estremi=25):
    """Un sottoinsieme dei vertici: a caso, più gli estremi lungo i tre assi (lì si tocca)."""
    if len(co) <= n:
        return co
    rng = np.random.default_rng(1)
    idx = set(rng.choice(len(co), n, replace=False).tolist())
    for a in range(3):
        o = np.argsort(co[:, a])
        idx.update(o[:estremi].tolist()); idx.update(o[-estremi:].tolist())
    return co[sorted(idx)]


def bvh_di(obs, con_dati=False):
    vs, fs, chi = [], [], []
    for o in obs:
        co = vertici_mondo(o)
        b = len(vs)
        vs += [Vector(v) for v in co]
        fs += [tuple(b + i for i in p.vertices) for p in o.data.polygons]
        chi.append((len(fs), o.name))
    t = BVHTree.FromPolygons(vs, fs) if fs else None
    return (t, vs, fs, chi) if con_dati else t


class Solido:
    """Forma di collisione dello sfondo. Le convesse (-convcolonly) sono solidi: piani con la normale verso
    fuori. Le concave (-colonly: il pavimento della sala e la vasca della piscina) sono superfici calpestabili:
    un punto è "dentro" se, guardando in su, la prima cosa che trova è il retro della superficie (sta sotto
    il pavimento o sotto il fondo della piscina), fino a 1 m."""
    def __init__(self, o):
        from scipy.spatial import ConvexHull
        co = vertici_mondo(o)
        self.nome = o.name.replace('-convcolonly', '').replace('-colonly', '')
        self.lo, self.hi = co.min(axis=0), co.max(axis=0)
        self.superficie = None
        self.piani = None
        if '-convcolonly' in o.name:
            try:
                self.piani = ConvexHull(co).equations          # n . p + d <= 0 dentro
            except Exception:
                pass
        else:
            self.superficie = bvh_di([o])
            self.lo = self.lo - np.array([0.0, 0.0, 1.0])          # sotto la superficie si guarda fino a 1 m

    def profondita(self, pts):
        """Per ogni punto: quanto sta dentro (>0) o fuori (<=0)."""
        if self.superficie is not None:
            out = np.full(len(pts), -1.0)
            su = Vector((0, 0, 1))
            for i, v in enumerate(pts):
                r = self.superficie.ray_cast(Vector(v), su, 1.0)
                if r[0] is not None and r[1].dot(su) > 0:
                    out[i] = r[3]
            return out
        if self.piani is None:
            return np.full(len(pts), -1.0)
        s = pts @ self.piani[:, :3].T + self.piani[:, 3]
        return -s.max(axis=1)

    def uscita(self, p):
        """Da dove esce prima il punto p (dentro il solido): (normale della faccia, distanza). Si preferiscono
        le facce di lato: un oggetto a terra che entra in un bordo si sposta di lato, non in su."""
        s = p @ self.piani[:, :3].T + self.piani[:, 3]
        laterali = np.abs(self.piani[:, 2]) < 0.5
        k = int(np.argmax(np.where(laterali, s, -1e9))) if laterali.any() else int(np.argmax(s))
        return Vector(self.piani[k, :3]), float(-s[k])


def carica(cartella_glb, cartella_det):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    gruppi = {}
    for nome in STRUTTURE + [ACQUA, OGGETTI]:
        p = os.path.join(cartella_glb, nome + '.glb')
        if os.path.exists(p):
            gruppi[nome] = [o for o in importa(p) if o.type == 'MESH']
    bpy.context.view_layer.update()
    strutt, solidi, oggetti = [], [], []
    for nome, obs in gruppi.items():
        for o in obs:
            if e_collisione(o):
                if nome != OGGETTI and nome != ACQUA and not o.name.startswith(('ogg_', 'cordone_vasca_')):
                    solidi.append(o)      # (le scatole degli oggetti di scena non sono sfondo; i muri del cordone sono invisibili)
            elif o.name.startswith('ogg_'):
                oggetti.append(('oggetto', o.name, o, None))
            elif nome not in (OGGETTI, ACQUA):
                strutt.append(o)
    # i dettagli del kit, istanziati come in DettagliSala (solo la mesh, con la trasformazione del posto)
    pos = json.load(open(os.path.join(cartella_det, 'posizionamento.json')))['posti']
    sorgenti = {}
    for f in sorted(os.listdir(os.path.join(cartella_det, 'gltf'))):
        if f.endswith('.gltf'):
            for o in importa(os.path.join(cartella_det, 'gltf', f)):
                if o.type == 'MESH':
                    sorgenti[o.name.split('.')[0]] = o
                    o.hide_set(True)
    for i, q in enumerate(pos):
        src = sorgenti.get(q['nodo'])
        if src is None:
            print('dettaglio mancante:', q['nodo'])
            continue
        b = q['basis']
        Bg = Matrix(((b[0][0], b[1][0], b[2][0]), (b[0][1], b[1][1], b[2][1]), (b[0][2], b[1][2], b[2][2])))
        pg = Vector(q['posizione'])
        M = (C @ Bg @ C.inverted()).to_4x4()
        M.translation = C @ pg
        o = bpy.data.objects.new(f"{q['nodo']}#{i}", src.data)
        bpy.context.scene.collection.objects.link(o)
        o.matrix_world = M
        oggetti.append(('dettaglio', f"{q['nodo']} ({q.get('zona', '')})", o, i))
    bpy.context.view_layer.update()
    acqua = gruppi.get(ACQUA, [])
    return strutt, acqua, solidi, oggetti, pos


def in_godot(v):
    return [round(float(v[0]), 2), round(float(v[2]), 2), round(float(-v[1]), 2)]


def controlla(cartella_glb, cartella_det, correggi=False):
    strutt, acqua, solidi_ob, oggetti, posti = carica(cartella_glb, cartella_det)
    print(f'strutture {len(strutt)}, solidi {len(solidi_ob)}, acqua {len(acqua)}, oggetti e dettagli {len(oggetti)}')
    appoggi = bvh_di(strutt + acqua)
    sfondo, _, _, chi_sfondo = bvh_di([o for o in strutt if 'colature' not in o.name and 'pozzanghere' not in o.name
                                       and 'piastrelle_mancanti' not in o.name], con_dati=True)
    fine_sfondo = [k for k, _ in chi_sfondo]
    def nome_sfondo(i):
        import bisect
        return chi_sfondo[bisect.bisect_right(fine_sfondo, i)][1]
    solidi = [Solido(o) for o in solidi_ob]
    lo_s = np.array([s.lo for s in solidi]); hi_s = np.array([s.hi for s in solidi])
    dati = []
    for tipo, nome, o, indice in oggetti:
        co = vertici_mondo(o)
        if len(co) == 0:
            continue
        lo, hi = co.min(axis=0), co.max(axis=0)
        dati.append(dict(tipo=tipo, nome=nome, ob=o, co=co, lo=lo, hi=hi, indice=indice))
    bvh_ogg = {}
    def bvh_ogg_di(d):
        k = d['ob'].name
        if k not in bvh_ogg:
            bvh_ogg[k] = bvh_di([d['ob']])
        return bvh_ogg[k]
    problemi = []
    for d in dati:
        co, lo, hi = d['co'], d['lo'], d['hi']
        pts = campione(co)
        # --- entra nei solidi dello sfondo?
        vicini = np.where(np.all(lo_s <= hi + 0.01, axis=1) & np.all(hi_s >= lo - 0.01, axis=1))[0]
        peggio, dove, quanti, solido, punto = 0.0, None, 0, None, None
        for k in vicini:
            p = solidi[k].profondita(pts)
            m = p.max()
            quanti = max(quanti, int((p > SOGLIA_ENTRA).sum()))
            if m > peggio:
                peggio, dove, solido, punto = m, solidi[k].nome, solidi[k], pts[int(np.argmax(p))]
        if peggio > SOGLIA_ENTRA:
            problemi.append(dict(problema='ENTRA', tipo=d['tipo'], nome=d['nome'], cm=round(peggio * 100, 1), in_=dove,
                                 vertici=quanti, centro_godot=in_godot((lo + hi) / 2), dim=[round(float(x), 2) for x in hi - lo],
                                 _d=d, _solido=solido, _punto=punto))
        # --- interseca lo sfondo visibile? (triangoli che si tagliano, poi quanto i vertici passano dall'altra parte)
        bo, vs_o, fs_o, _ = bvh_di([d['ob']], con_dati=True)
        coppie = bo.overlap(sfondo) if bo else []
        if coppie:
            peggio, dove, normale = 0.0, None, None
            visti = set()
            for (io, js) in coppie[:400]:
                for vi in fs_o[io]:
                    if vi in visti:
                        continue
                    visti.add(vi)
                    v = vs_o[vi]
                    r = sfondo.find_nearest(v, 0.5)
                    if r[0] is not None and (v - r[0]).dot(r[1]) < 0 and r[3] > peggio:
                        peggio, dove, normale = r[3], nome_sfondo(r[2]), r[1].normalized()
            if peggio > SOGLIA_ENTRA:
                problemi.append(dict(problema='INTERSECA', tipo=d['tipo'], nome=d['nome'], cm=round(peggio * 100, 1), in_=dove,
                                     vertici=len(visti), centro_godot=in_godot((lo + hi) / 2), dim=[round(float(x), 2) for x in hi - lo],
                                     _d=d, _normale=normale))
        # --- galleggia? (distanza minima da sfondo, acqua o altri oggetti)
        dmin = 9.0
        for v in pts:
            r = appoggi.find_nearest(Vector(v), SOGLIA_GALLEGGIA)
            if r[0] is not None:
                dmin = min(dmin, r[3])
                break
        if dmin > SOGLIA_GALLEGGIA:
            for e in dati:
                if e is d or np.any(e['lo'] > hi + SOGLIA_GALLEGGIA) or np.any(e['hi'] < lo - SOGLIA_GALLEGGIA):
                    continue
                b = bvh_ogg_di(e)
                for v in pts:
                    r = b.find_nearest(Vector(v), SOGLIA_GALLEGGIA)
                    if r[0] is not None:
                        dmin = min(dmin, r[3])
                        break
                if dmin <= SOGLIA_GALLEGGIA:
                    break
        if dmin > SOGLIA_GALLEGGIA:
            # quanto è lontano: la superficie più vicina in assoluto
            dist = min(appoggi.find_nearest(Vector(v))[3] for v in campione(co, 300, 10))
            problemi.append(dict(problema='GALLEGGIA', tipo=d['tipo'], nome=d['nome'], cm=round(dist * 100, 1),
                                 centro_godot=in_godot((lo + hi) / 2), dim=[round(float(x), 2) for x in hi - lo], _d=d))
    corretti = sistema_dettagli(problemi, strutt, posti) if correggi else {}
    for p in problemi:
        for k in [k for k in p if k.startswith('_')]:
            del p[k]
    return problemi, len(dati), corretti, posti


def sistema_dettagli(problemi, strutt, posti):
    """Nuovi posti (posizione e basis in Godot) per i dettagli con un problema. Restituisce {indice: motivo}."""
    pavimento = bvh_di(strutt)          # senza l'acqua: si appoggia sul fondo vero
    su, giu = Vector((0, 0, 1)), Vector((0, 0, -1))
    Ci = C.inverted()
    fatti = {}
    for pr in problemi:
        d = pr.get('_d')
        if d is None or d['tipo'] != 'dettaglio' or d['indice'] in fatti:
            continue
        q = posti[d['indice']]
        if 'applique' in q['nodo']:
            continue
        o = d['ob']
        B = o.matrix_world.to_3x3()
        t = o.matrix_world.translation.copy()
        solido = pr.get('_solido')
        if pr['problema'] == 'INTERSECA' and abs(pr['_normale'].z) < 0.5:
            n = pr['_normale']
            B2, t2 = B, t + Vector((n.x, n.y, 0.0)).normalized() * (pr['cm'] / 100 + 0.005)
            motivo = f"tagliava {pr['cm']} cm {pr['in_']}: spostato fuori di {round(pr['cm'] + 0.5, 1)} cm"
        elif pr['problema'] == 'ENTRA' and solido is not None and solido.superficie is None:
            n, dist = solido.uscita(np.array(pr['_punto']))
            B2, t2 = B, t + n * (dist + 0.005)
            motivo = f"entrava {pr['cm']} cm in {pr['in_']}: spostato fuori di {round((dist + 0.005) * 100, 1)} cm"
        else:
            r = pavimento.ray_cast(t + su * 0.6, giu, 3.0)
            if r[0] is None or r[1].dot(su) < 0.5:
                print('  non sistemato (sotto non c\'è un pavimento):', pr['nome'])
                continue
            p, n = r[0], r[1].normalized()
            R = su.rotation_difference(n).to_matrix()
            B2 = R @ B
            me = o.data
            loc = np.empty(len(me.vertices) * 3); me.vertices.foreach_get('co', loc)
            w = loc.reshape(-1, 3) @ np.array(B2).T
            s_ = -float((w @ np.array(n)).min())
            t2 = p + n * s_
            # sul fondo curvo (la conca dello scarico) il piano sotto il centro non basta: si alza ancora quanto
            # serve perché nessun vertice resti sotto la superficie che ha davvero sotto di sé
            alza = 0.0
            for v in campione(w, 400, 10) + np.array(t2):
                r2 = pavimento.ray_cast(Vector(v) + su * 0.5, giu, 1.0)
                if r2[0] is not None:
                    alza = max(alza, r2[0].z - float(v[2]))
            if alza > 0.003:
                t2 = t2 + su * (alza + 0.003)
            motivo = (f"{'entrava' if pr['problema'] == 'ENTRA' else 'galleggiava'} {pr['cm']} cm: appoggiato sul pavimento sotto"
                      + (f", inclinato di {round(math.degrees(su.angle(n)), 1)} gradi come lui" if su.angle(n) > math.radians(1) else ''))
        Bg = Ci @ B2 @ C
        tg = Ci @ t2
        q['posizione'] = [round(float(v), 3) for v in tg]
        q['basis'] = [[round(float(Bg[r][c]), 4) for r in range(3)] for c in range(3)]
        fatti[d['indice']] = motivo
    return fatti


def main():
    argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:]
    ap = argparse.ArgumentParser()
    ap.add_argument('--glb', default=os.path.join(RADICE, 'godot', 'assets', 'ambiente', 'sala'))
    ap.add_argument('--dettagli', default=os.path.join(RADICE, 'godot', 'assets', 'ambiente', 'dettagli'))
    ap.add_argument('--json', default='')
    ap.add_argument('--correggi', action='store_true', help='sistema i posti del kit di dettagli con un problema')
    a = ap.parse_args(argv)
    problemi, n, corretti, posti = controlla(a.glb, a.dettagli, a.correggi)
    problemi.sort(key=lambda p: (p['problema'], -p['cm']))
    print(f'\n{n} oggetti controllati, {len(problemi)} problemi')
    for p in problemi:
        extra = f" in {p['in_']} ({p['vertici']} vertici)" if p['problema'] in ('ENTRA', 'INTERSECA') else ''
        print(f"  {p['problema']:9s} {p['cm']:6.1f} cm  {p['tipo']:9s} {p['nome']:48s} centro Godot {p['centro_godot']}{extra}")
    if a.json:
        with open(a.json, 'w') as f:
            json.dump(problemi, f, indent=1, ensure_ascii=False)
    if corretti:
        print(f'\nsistemati {len(corretti)} posti del kit di dettagli:')
        for i, m in sorted(corretti.items()):
            print(f"  #{i} {posti[i]['nodo']}: {m}")
        copie = [os.path.join(a.dettagli, 'posizionamento.json'),
                 os.path.join(RADICE, 'assets_src', 'ambiente_dettagli', 'posizionamento.json')]
        for pj in copie:
            if not os.path.exists(pj):
                continue
            dj = json.load(open(pj))
            if len(dj['posti']) != len(posti):
                print('ATTENZIONE: copia diversa, non la tocco:', pj)
                continue
            for i in corretti:
                dj['posti'][i]['posizione'] = posti[i]['posizione']
                dj['posti'][i]['basis'] = posti[i]['basis']
            with open(pj, 'w') as f:
                json.dump(dj, f, indent=1, ensure_ascii=False)
            print('scritto', pj)
    sys.exit(1 if problemi else 0)


if __name__ == '__main__':
    main()
