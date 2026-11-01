"""L'arredo della stanza delle pozze colorate (GDD, "La stanza delle pozze colorate", scelte dell'utente del 31 ottobre):
la stanza di servizio delle pozze, sulla linea delle pompe riaccese. La passerella di grigliato (1,2 m) resta libera:
sui muri solo cose profonde al più 30 cm, a terra solo il secchio col mocio in un angolo.
- Muro est: il collettore delle pompe, due tubi che escono dal muro nord sopra i 2 m, corrono lungo il muro e
  nell'angolo sud-est scendono nel pavimento (sotto ci sono le pozze); la valvola a volantino sul tubo grosso, il
  pannello dei manometri collegato al collettore.
- Muro ovest: il quadro elettrico delle luci con la canalina fino al soffitto, il cartello del pavimento bagnato (solo
  il disegno), l'estintore vicino alla porta stagna.
- Muro nord, a est della porta: le due taniche del cloro a terra contro il muro, il retino delle pozze appeso sopra, la
  griglia dell'aria in alto.
- Angolo sud-ovest: il secchio col mocio appoggiato al muro.
Coordinate della stanza (scripts/risalita/stanza_pozze.gd: origine al centro della griglia delle pozze, sul pavimento,
muri a +-4 m, soffitto a 3,6); in Blender (x, -z, y). I muri, il pavimento e il soffitto qui ci sono solo come sostegni
per Posa (non si esportano). Il muro sud a est di x -1,1 è quello dell'infermeria: lì non entra niente.
Uso: /home/user/tools/blender-venv/bin/python tools/blender/stanza_pozze.py
Uscita: godot/assets/ambienti_tecnici/stanza_pozze/stanza_pozze.gltf"""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Vector
import ambienti2_comune as C
import ambienti1_hq as HQ
import posa as Posa

HQ.LINK[0] = C._link
USCITA = os.path.join(C.RADICE, 'godot', 'assets', 'ambienti_tecnici', 'stanza_pozze', 'stanza_pozze.gltf')
R_ = math.radians

M = 4.0                  # le facce interne dei muri
ALTA = 3.6
PORTA_X = -1.7           # la porta stagna nel muro nord, larga 0,9 (telaio fino a 0,57 dall'asse)
PROF_MAX = 0.3           # sui muri, sotto i 2 m
# il collettore: [raggio, quota, distanza del centro dal muro est, dove scende (z)]
TUBO_GROSSO = (0.08, 2.45, 0.088, 3.78)
TUBO_PICCOLO = (0.045, 2.8, 0.25, 3.38)


def g(x, y, z):
    """Un punto della stanza in Blender."""
    return Vector((x, -z, y))


def sostegni():
    s = []
    s.append(C.box('_pavimento', g(0, -0.1, 0), (2 * M, 2 * M, 0.2)))
    s.append(C.box('_soffitto', g(0, ALTA + 0.1, 0), (2 * M, 2 * M, 0.2)))
    s.append(C.box('_muro_o', g(-M - 0.1, ALTA / 2, 0), (0.2, 2 * M, ALTA)))
    s.append(C.box('_muro_e', g(M + 0.1, ALTA / 2, 0), (0.2, 2 * M, ALTA)))
    s.append(C.box('_muro_n', g(0, ALTA / 2, -M - 0.1), (2 * M, 0.2, ALTA)))
    s.append(C.box('_muro_s', g(0, ALTA / 2, M + 0.1), (2 * M, 0.2, ALTA)))
    return s


def collettore(obs, acciaio, rosso, verde):
    for k, (r, y, d, zg) in enumerate((TUBO_GROSSO, TUBO_PICCOLO)):
        x = M - d
        # dal muro nord (3 cm dentro: il controllo riconosce un capo infilato entro 5 cm da una faccia) lungo il muro
        # est, poi giù nel pavimento (3 cm dentro)
        pezzi = [C.tubo(f'collettore_{k}_tubo', [g(x, y, -M - 0.03), g(x, y, zg), g(x, -0.03, zg)], r, acciaio, rc=2.5 * r)]
        # i collari (grosso, a 8 mm dal muro) o le staffe fino al muro (piccolo, a 20 cm), ogni 1,8 m e due sul tratto giù
        punti = [(x, y, z) for z in (-3.0, -1.2, 0.6, 2.4)] + [(x, yy, zg) for yy in (0.7, 1.8)]
        for (px, py, pz) in punti:
            verticale = abs(pz - zg) < 1e-6
            asse = (0, 0, 1) if verticale else (0, 1, 0)
            pezzi.append(C.cilindro(f'collettore_{k}_collare', g(px, py, pz), r + 0.006, 0.05, acciaio, asse=asse))
            braccio = d - r - 0.006
            if braccio > 0.004:
                pezzi.append(C.box(f'collettore_{k}_staffa', g(M - braccio / 2, py, pz), (braccio, 0.04, 0.03), acciaio))
        if k == 0:
            # la valvola a volantino sul tratto che scende, a 1,25 m, col volantino verso la stanza
            yv = 1.25
            pezzi.append(C.sfera('valvola_corpo', g(x - 0.01, yv, zg), 0.11, acciaio, scala=(1, 1, 1.4)))
            for dy in (-0.16, 0.16):
                pezzi.append(C.cilindro('valvola_flangia', g(x, yv + dy, zg), r + 0.02, 0.03, acciaio))
            xs = x - 0.09
            pezzi.append(C.cilindro('valvola_stelo', g(xs - 0.04, yv, zg), 0.016, 0.1, acciaio, asse=(1, 0, 0)))
            xr = xs - 0.085
            pezzi.append(C.toro('volantino', g(xr, yv, zg), 0.11, 0.013, rosso, asse=(1, 0, 0)))
            pezzi.append(C.cilindro('volantino_mozzo', g(xr, yv, zg), 0.025, 0.04, rosso, asse=(1, 0, 0)))
            for a in (0, 60, 120):
                dd = Vector((0, math.cos(R_(a)), math.sin(R_(a))))
                pezzi.append(C.cilindro('volantino_razza', g(xr, yv, zg), 0.008, 0.22, rosso, asse=dd))
            # le fascette verdi della linea delle pompe riaccese, vicino al muro nord e prima di scendere
            for z in (-3.6, 3.2):
                pezzi.append(C.cilindro('fascetta', g(x, y, z), r + 0.003, 0.06, verde, asse=(0, 1, 0)))
        obs.append(C.unisci(f'collettore_{k}', pezzi))


def metti(nome, file, centro_base, alto=None, largo=None, rz=0.0, prof_max=None):
    """Un modello Meshy con la base in centro_base (stanza), girato di rz gradi (0: il fronte guarda a -Y di Blender,
    cioè +z della stanza); prof_max: la sporgenza dal muro al più questa."""
    d = HQ.dimensioni(file)
    k = alto / d.z if alto else largo / d.x
    prof = d.y * k              # (girato di 90 gradi la profondità del modello va lungo x: è sempre d.y)
    if prof_max and prof > prof_max:
        k *= prof_max / prof
    return HQ.metti(nome, file, g(*centro_base), (d.x * k, d.y * k, d.z * k), rot_z=R_(rz))


def al_muro(o, verso, terra=False):
    if terra:
        Posa.appoggia_a_terra(o)
    Posa.fissa_al_muro(o, verso)
    # 2 mm staccato dal muro: tocca (entro 5 mm) senza entrarci
    o.location += Vector(verso).normalized() * 0.002


def muro_est(obs, acciaio):
    # il pannello dei manometri a 1,3-1,9 m, collegato al collettore con due tubetti che salgono e ci entrano
    p = metti('pannello_manometri', 'quadro_strumenti', (M - 0.1, 1.3, -1.0), alto=0.6, rz=-90, prof_max=0.16)
    al_muro(p, (-1, 0, 0))
    obs.append(p)
    lo, hi = _scatola(p)
    xt = M - 0.035
    for k, dz in enumerate((-0.12, 0.12)):
        z = -1.0 + dz
        top = hi.z - 0.03
        obs.append(C.cilindro(f'tubetto_manometri_{k}', g(xt, (top + TUBO_GROSSO[1] - 0.05) / 2, z), 0.012,
                              TUBO_GROSSO[1] - 0.05 - top, acciaio))
    return [p]


def muro_ovest(obs, acciaio):
    out = []
    # il quadro elettrico delle luci (1,15-1,9 m) con la canalina grigia fino al soffitto
    q = metti('quadro_elettrico', 'quadro_elettrico', (-M + 0.15, 1.15, 0.6), alto=0.75, rz=90, prof_max=0.22)
    al_muro(q, (1, 0, 0))
    obs.append(q)
    out.append(q)
    lo, hi = _scatola(q)
    grigio = C.mat_pbr('canalina', base=(0.62, 0.63, 0.6), roughness=0.6)
    y0 = hi.z            # (dalla cima del quadro: ci si appoggia sopra)
    obs.append(C.box('canalina_quadro', g(-M + 0.022, (y0 + ALTA + 0.02) / 2, 0.6), (0.04, 0.07, ALTA + 0.02 - y0), grigio))
    # il cartello del pavimento bagnato (solo il disegno), a 1,6 m
    c = metti('cartello_bagnato', 'cartello_pericolo', (-M + 0.05, 1.45, 2.0), alto=0.38, rz=90, prof_max=0.03)
    al_muro(c, (1, 0, 0))
    obs.append(c)
    # l'estintore vicino alla porta stagna, la base a 30 cm
    e = metti('estintore', 'estintore_staffa', (-M + 0.12, 0.3, -2.7), alto=0.62, rz=90, prof_max=0.22)
    al_muro(e, (1, 0, 0))
    obs.append(e)
    out.append(e)
    return out


def muro_nord(obs, acciaio):
    out = []
    # le due taniche del cloro, bianche col tappo blu, a terra contro il muro (35 cm, 22 di sporgenza)
    bianco = C.mat_pbr('tanica', base=(0.86, 0.86, 0.82), roughness=0.55)
    blu = C.mat_pbr('tanica_tappo', base=(0.08, 0.2, 0.5), roughness=0.5)
    for k, x in enumerate((2.55, 2.95)):
        t = tanica(f'tanica_{k}', g(x, 0, -M + 0.11), bianco, blu)
        al_muro(t, (0, -1, 0), terra=True)      # (il muro nord guarda a +z della stanza: -y in Blender)
        obs.append(t)
        out.append(t)
    # il retino delle pozze appeso orizzontale su due ganci, a 1,75 m (4 cm dal muro)
    alluminio = C.mat_pbr('retino_asta', base=(0.7, 0.72, 0.72), roughness=0.35, metallic=0.85)
    rete = C.mat_pbr('retino_rete', base=(0.12, 0.3, 0.25), roughness=0.8)
    y = 1.75
    zr = -M + 0.045
    pezzi = [C.cilindro('retino_asta', g(1.2, y, zr), 0.014, 2.2, alluminio, asse=(1, 0, 0))]
    pezzi.append(C.toro('retino_cerchio', g(2.55, y, zr), 0.21, 0.01, alluminio, asse=(0, 1, 0)))
    pezzi.append(C.cilindro('retino_rete', g(2.55, y, zr), 0.2, 0.012, rete, asse=(0, 1, 0)))
    # i ganci: la piastra al muro, il braccio che sporge 7 cm con l'asta appoggiata sopra e la punta che la tiene
    yb = y - 0.014 - 0.006
    # (un oggetto solo col retino: appeso ai ganci avvitati al muro)
    for k, x in enumerate((0.4, 1.8)):
        pezzi += [C.box('gancio_piastra', g(x, yb, -M + 0.004), (0.05, 0.008, 0.08), acciaio),
                  C.box('gancio_braccio', g(x, yb, -M + 0.035), (0.012, 0.07, 0.012), acciaio),
                  C.box('gancio_punta', g(x, yb + 0.006 + 0.015, -M + 0.064), (0.012, 0.012, 0.03), acciaio)]
    obs.append(C.unisci('retino', pezzi))
    # la griglia dell'aria in alto (3 m), con le lamelle
    pezzi = [C.box('griglia_aria_telaio', g(1.4, 3.05, -M + 0.012), (0.6, 0.024, 0.34), acciaio)]
    scuro = C.mat_pbr('griglia_aria_buio', base=(0.03, 0.03, 0.03), roughness=0.9)
    pezzi.append(C.box('griglia_aria_fondo', g(1.4, 3.05, -M + 0.026), (0.54, 0.004, 0.28), scuro))
    for k in range(6):
        pezzi.append(C.box('griglia_aria_lamella', g(1.4, 2.93 + k * 0.047, -M + 0.03), (0.54, 0.03, 0.006), acciaio,
                           rot=(R_(30), 0, 0)))
    obs.append(C.unisci('griglia_aria', pezzi))
    return out


def tanica(nome, base, bianco, blu):
    w, d, h = 0.26, 0.2, 0.36
    pezzi = [C.box(nome + '_corpo', base + Vector((0, 0, h / 2)), (w, d, h), bianco, smussa=0.03)]
    pezzi.append(C.box(nome + '_maniglia', base + Vector((-0.04, 0, h + 0.03)), (0.12, 0.03, 0.04), bianco, smussa=0.01))
    pezzi.append(C.cilindro(nome + '_tappo', base + Vector((0.08, 0, h + 0.02)), 0.03, 0.04, blu))
    return C.unisci(nome, pezzi)


def angolo_so(obs):
    # il secchio col mocio nell'angolo sud-ovest (lascia 80 cm per girare l'angolo), il manico appoggiato al muro sud
    zinco = C.mat_pbr('secchio_zinco', base=(0.52, 0.54, 0.53), roughness=0.4, metallic=0.85)
    legno = C.mat_pbr('mocio_manico', base=(0.55, 0.42, 0.26), roughness=0.6)
    straccio = C.mat_pbr('mocio_frange', base=(0.75, 0.73, 0.66), roughness=0.95)
    xb, zb = -M + 0.22, M - 0.24
    s = C.unisci('secchio', [C.cilindro('secchio_corpo', g(xb, 0.14, zb), 0.13, 0.28, zinco, r2=0.16, seg=28),
                             C.toro('secchio_bordo', g(xb, 0.28, zb), 0.16, 0.008, zinco)])
    Posa.appoggia_a_terra(s)
    obs.append(s)
    # il mocio: le frange nel secchio, il manico fino al muro sud a 1,25 m
    a = g(xb + 0.03, 0.12, zb - 0.02)
    b = g(xb + 0.18, 1.25, M - 0.012)
    pezzi = [C.tubo('mocio_manico', [a, b], 0.013, legno)]
    pezzi.append(C.sfera('mocio_frange', a + Vector((0, 0, -0.02)), 0.09, straccio, scala=(1, 1, 0.8)))
    obs.append(C.unisci('mocio', pezzi))
    return [s]


def collisioni(obs, cose):
    for o in cose:
        lo, hi = _scatola(o)
        obs.append(C.collisione_box(o.name + '_col', lo, hi))
    # il tratto del collettore che scende fino a terra
    for (r, y, d, zg) in (TUBO_GROSSO, TUBO_PICCOLO):
        x = M - d
        obs.append(C.collisione_box('collettore_giu_col', g(x - r, 0, zg + r), g(x + r, 2.0, zg - r)))


def _scatola(o):
    ps = [o.matrix_world @ Vector(c) for c in o.bound_box]
    return (Vector([min(p[i] for p in ps) for i in range(3)]), Vector([max(p[i] for p in ps) for i in range(3)]))


def controlla(obs):
    """Sporgenza dai muri sotto i 2 m (al più 30 cm), niente davanti alla porta stagna, tocca."""
    for o in obs:
        if o.name.endswith('-convcolonly') or o.name.startswith('_'):
            continue
        lo, hi = _scatola(o)
        x0, x1, z0, z1, y0, y1 = lo.x, hi.x, -hi.y, -lo.y, lo.z, hi.z
        prof = min(x0 + M if x0 < 0 else 99, M - x1 if x1 > 0 else 99, z0 + M, M - z1)
        sporg = min(x1 + M, M - x0, z1 + M, M - z0)
        print('MISURA %-20s x %.2f/%.2f z %.2f/%.2f y %.2f/%.2f sporgenza %.2f %s' % (o.name, x0, x1, z0, z1, y0, y1,
              sporg, 'tocca' if Posa.tocca(o) else 'NON TOCCA'))
        if y0 < 2.0 and sporg > PROF_MAX + 0.005 and not o.name.startswith(('secchio', 'mocio')):
            print('  SPORGE TROPPO')
        if z0 < -M + 0.6 and abs((x0 + x1) / 2 - PORTA_X) < 0.57 + (x1 - x0) / 2 and y0 < 2.4:
            print('  DAVANTI ALLA PORTA')


def esporta(obs):
    os.makedirs(os.path.dirname(USCITA), exist_ok=True)
    for im in bpy.data.images:
        if im.size[0] > 1024:
            im.scale(1024, 1024)
    bpy.ops.object.select_all(action='DESELECT')
    for o in obs:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=USCITA, export_format='GLTF_SEPARATE', export_texture_dir='texture',
                              use_selection=True, export_apply=True, export_lights=False, export_cameras=False,
                              export_yup=True, export_image_format='JPEG', export_jpeg_quality=88)
    print('esportato', USCITA, len(obs), 'oggetti', flush=True)


if __name__ == '__main__':
    C.reset()
    sost = sostegni()
    obs = []
    acciaio = C.mat_pbr('tubi_pompe', base=(0.33, 0.37, 0.36), roughness=0.45, metallic=0.75)
    rosso = C.mat_pbr('volantino_rosso', base=(0.55, 0.06, 0.04), roughness=0.5, metallic=0.4)
    verde = C.mat_pbr('fascetta_verde', base=(0.1, 0.42, 0.18), roughness=0.5)
    collettore(obs, acciaio, rosso, verde)
    cose = muro_est(obs, acciaio) + muro_ovest(obs, acciaio) + muro_nord(obs, acciaio) + angolo_so(obs)
    collisioni(obs, cose)
    controlla(obs)
    for o in sost:
        bpy.data.objects.remove(o)
    esporta(obs)
