"""L'arredo del corridoio in fondo alla scala del fiume (riscontro dell'utente sulla v0.3.16, "c'è un corridoio vuoto prima
della zona del fiume"; scelta A+C del 30 ottobre, docs/proposte/corridoio_fiume/LEGGIMI.md): il corridoio di servizio.
- Due tubi delle pompe lungo il muro ovest, sopra i 2 m: escono dal muro della sala pompe (a sud, dietro la scala),
  corrono fino a 2 m prima della porta del capannone ed entrano nel suo muro (è l'acqua che fa girare il fiume); collari
  ogni 2 m e la valvola a volantino sul tubo grosso.
- Sotto, contro il muro ovest (al più 50 cm di profondità): il quadro elettrico spento, i fusti, il secchio, il carrello
  degli attrezzi (modelli Meshy già nel gioco: ambienti tecnici e risalita), la griglia di scolo per terra (quella del
  fiume) e il cartello a disegni verso il fiume (onda, ciambella, freccia).
- Liberi: la curva in fondo alla scala, il tratto bagnato davanti all'oblò (muffa, pozza e gocce le mette il gioco,
  scripts/risalita/risalita_gioco.gd), gli ultimi 2 m prima della porta (la porta e la strada del bambino).
Coordinate del gioco (la Risalita sta nell'origine della sala); in Blender (x, -z, y). I muri e il pavimento del
corridoio qui ci sono solo come sostegni per Posa (non si esportano): le misure sono quelle di risalita_gioco.gd.
Uso: /home/user/tools/blender-venv/bin/python tools/blender/corridoio_fiume.py
Uscita: godot/assets/ambienti_tecnici/corridoio_fiume/corridoio_fiume.gltf"""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Vector
import ambienti2_comune as C
import ambienti1_hq as HQ
import posa as Posa

HQ.LINK[0] = C._link
for _c in (('tappa7_arredo',), ('fiume_lento', 'meshy')):
    HQ.CARTELLE.append(os.path.join(C.RADICE, 'assets_src', *_c))
USCITA = os.path.join(C.RADICE, 'godot', 'assets', 'ambienti_tecnici', 'corridoio_fiume', 'corridoio_fiume.gltf')
CARTELLO = os.path.join(C.RADICE, 'assets_src', 'corridoio_fiume', 'cartello_fiume.jpg')
R_ = math.radians

# le misure di risalita_gioco.gd (_scala_fiume): Y, CORRIDOIO_FIUME_X, SCALA_FIUME_Z, la porta del capannone
Y = -5.4
MURO_O = -5.9            # la faccia del muro ovest (il muro va da -6,1 a -5,9)
MURO_E = -3.9
SOFFITTO = Y + 2.6
MURO_S = 48.2            # la faccia del muro della sala pompe, in fondo al pianerottolo (z)
PORTA0 = 65.3
FINE_ARREDO = PORTA0 - 2.0
# i tubi: [raggio, quota del centro]; a 8 mm dal muro, i collari a 2 mm
TUBI = [(0.07, Y + 2.25), (0.05, Y + 2.45)]
STACCO_TUBO = 0.008


def g(x, y, z):
    """Un punto del gioco in Blender."""
    return Vector((x, -z, y))


def sostegni():
    """Il pavimento, i muri e il soffitto del corridoio e del pianerottolo, solo per Posa."""
    s = []
    s.append(C.box('_pavimento', g(-4.9, Y - 0.1, 57.0), (2.0, 20.0, 0.2)))
    s.append(C.box('_muro_o', g(MURO_O - 0.1, Y + 1.3, 57.0), (0.2, 20.0, 2.6)))
    s.append(C.box('_muro_s', g(-4.9, Y + 1.3, MURO_S - 0.1), (2.0, 0.2, 2.6)))
    s.append(C.box('_soffitto', g(-4.9, SOFFITTO + 0.1, 57.0), (2.0, 20.0, 0.2)))
    return s


def tubi(obs):
    acciaio = C.mat_pbr('tubi_pompe', base=(0.33, 0.37, 0.36), roughness=0.45, metallic=0.75)
    rosso = C.mat_pbr('volantino_rosso', base=(0.55, 0.06, 0.04), roughness=0.5, metallic=0.4)
    for k, (r, y) in enumerate(TUBI):
        x = MURO_O + r + STACCO_TUBO
        # dal muro della sala pompe (3 cm dentro: il controllo riconosce un capo infilato entro 5 cm da una faccia) a 2 m
        # prima della porta, poi nel muro ovest (10 cm dentro)
        z1 = FINE_ARREDO + 0.1 + 0.15 * k
        pezzi = [C.tubo(f'tubo_pompe_{k}_tubo', [g(x, y, MURO_S - 0.03), g(x, y, z1), g(MURO_O - 0.1, y, z1)], r, acciaio, rc=2.2 * r)]
        # i rosoni sui due muri dove il tubo entra, con quattro bulloni: si legge subito che il tubo passa nel muro
        # (ricontrollo di grafica del 30 ottobre: dalla porta il gomito sembrava un tubo che finiva tondo); raggio
        # r + 3,5 cm, così i due rosoni del muro della sala pompe (centri a 20 cm) restano staccati di 1 cm
        rr = r + 0.035
        # (sul muro della sala pompe il tubo corre nell'angolo col muro ovest: lì la piastra è quadrata e parte dalla
        # faccia del muro ovest, un rosone tondo ci entrava di 3 cm)
        x0 = MURO_O + 0.001
        pezzi.append(C.box(f'tubo_pompe_{k}_rosone_s', g((x0 + x + rr) * 0.5, y, MURO_S + 0.006), (x + rr - x0, 0.012, 2 * rr), acciaio))
        # (sul muro ovest più grande: i centri sono a 25 cm, e dalla porta il rosone deve spuntare attorno al gomito)
        pezzi.append(C.cilindro(f'tubo_pompe_{k}_rosone_o', g(MURO_O + 0.01, y, z1), r + 0.06, 0.02, acciaio, asse=(1, 0, 0), seg=32))
        for a in (45, 135, 225, 315):
            du, dv = math.cos(R_(a)) * (r + 0.02), math.sin(R_(a)) * (r + 0.02)
            pezzi.append(C.cilindro('rosone_bullone', g(x + du, y + dv, MURO_S + 0.015), 0.007, 0.008, acciaio, asse=(0, 1, 0)))
            du2, dv2 = math.cos(R_(a)) * (r + 0.04), math.sin(R_(a)) * (r + 0.04)
            pezzi.append(C.cilindro('rosone_bullone', g(MURO_O + 0.023, y + dv2, z1 + du2), 0.008, 0.008, acciaio, asse=(1, 0, 0)))
        z = MURO_S + 1.3
        while z < z1 - 0.4:
            pezzi.append(C.cilindro(f'tubo_pompe_{k}_collare', g(x, y, z), r + STACCO_TUBO - 0.002, 0.05, acciaio,
                                    asse=(0, 1, 0)))
            z += 2.0
        if k == 0:
            # la valvola a volantino sopra i fusti: il corpo sul tubo (3 mm dal muro), lo stelo e il volantino verso
            # il corridoio, sopra i 2 m
            zv = 54.0
            pezzi.append(C.sfera('valvola_corpo', g(x + 0.012, y, zv), 0.085, acciaio, scala=(1, 1.5, 1)))
            for dz in (-0.14, 0.14):
                pezzi.append(C.cilindro('valvola_flangia', g(x, y, zv + dz), r + 0.004, 0.03, acciaio, asse=(0, 1, 0)))
            xs = x + 0.012 + 0.08
            pezzi.append(C.cilindro('valvola_stelo', g(xs + 0.06, y, zv), 0.016, 0.14, acciaio, asse=(1, 0, 0)))
            xr = xs + 0.13
            pezzi.append(C.toro('volantino', g(xr, y, zv), 0.1, 0.013, rosso, asse=(1, 0, 0)))
            pezzi.append(C.cilindro('volantino_mozzo', g(xr, y, zv), 0.025, 0.04, rosso, asse=(1, 0, 0)))
            for a in (0, 60, 120):
                d = Vector((0, math.cos(R_(a)), math.sin(R_(a))))
                pezzi.append(C.cilindro('volantino_razza', g(xr, y, zv), 0.008, 0.2, rosso, asse=d))
        obs.append(C.unisci(f'tubo_pompe_{k}', pezzi))


def metti(nome, file, centro_base, alto=None, largo=None, rz=0.0, prof_max=None):
    """Un modello Meshy con la base in centro_base (gioco), girato di rz gradi (0: il fronte guarda a -Y di Blender,
    cioè +z del gioco); prof_max: la profondità dal muro (x del gioco) al più questa."""
    d = HQ.dimensioni(file)
    k = alto / d.z if alto else largo / d.x
    prof = (d.y if round(rz) % 180 != 0 else d.x) * k
    if prof_max and prof > prof_max:
        k *= prof_max / prof
    return HQ.metti(nome, file, g(*centro_base), (d.x * k, d.y * k, d.z * k), rot_z=R_(rz))


def a_muro_e_a_terra(o, terra=True):
    """Il retro sul muro ovest (Posa) e, per le cose a terra, la base sul pavimento."""
    if terra:
        Posa.appoggia_a_terra(o)
    Posa.fissa_al_muro(o, (1, 0, 0))
    # 2 mm staccato dal muro: tocca (entro 5 mm) senza entrarci
    o.location.x += 0.002


def arredi(obs):
    # il quadro elettrico spento, fra 1,15 e 1,9 m, girato verso il corridoio (+x), al più 22 cm di sporgenza
    q = metti('quadro_elettrico', 'quadro_elettrico', (MURO_O + 0.15, Y + 1.15, 52.4), alto=0.75, rz=90, prof_max=0.22)
    a_muro_e_a_terra(q, terra=False)
    obs.append(q)
    # due bidoni di plastica blu sotto la valvola, appoggiati al muro (il modello Meshy dei fusti è un gruppo di tre,
    # largo quanto alto: non si stacca un fusto solo), alti 88 cm, larghi 48
    blu = C.mat_pbr('bidone_blu', base=(0.05, 0.16, 0.42), roughness=0.55)
    bianco = C.mat_pbr('bidone_tappo', base=(0.8, 0.8, 0.76), roughness=0.6)
    f = []
    for k, z in enumerate((53.62, 54.16)):
        f.append(bidone(f'bidone_{k}', g(MURO_O + 0.002 + 0.24, Y, z), blu, bianco, 25 + 60 * k))
    for o in f:
        a_muro_e_a_terra(o)
        obs.append(o)
    # il secchio di lamiera accanto ai fusti
    zinco = C.mat_pbr('secchio_zinco', base=(0.52, 0.54, 0.53), roughness=0.4, metallic=0.85)
    s = C.unisci('secchio', [C.cilindro('secchio_corpo', g(MURO_O + 0.2, Y + 0.14, 54.85), 0.12, 0.28, zinco, r2=0.15, seg=28),
                             C.toro('secchio_bordo', g(MURO_O + 0.2, Y + 0.28, 54.85), 0.15, 0.008, zinco)])
    Posa.appoggia_a_terra(s)
    obs.append(s)
    # il carrello degli attrezzi, di fianco lungo il muro
    c = metti('carrello_attrezzi', 'carrello_attrezzi', (MURO_O + 0.3, Y, 56.0), alto=1.0, rz=90, prof_max=0.5)
    a_muro_e_a_terra(c)
    obs.append(c)
    # la griglia di scolo per terra, dove finisce la pozza (il gioco mette la pozza fra le gocce e la griglia)
    # (il modello è un blocco alto un terzo della larghezza: schiacciato a 2,5 cm, resta il disegno della griglia)
    d = HQ.dimensioni('griglia_scolo')
    gr = HQ.metti('griglia_scolo', 'griglia_scolo', g(MURO_O + 0.3, Y, 60.3), (0.4, 0.4 * d.y / d.x, 0.025))
    Posa.appoggia_a_terra(gr)
    obs.append(gr)
    # il cartello a disegni (onda, ciambella, freccia verso la porta), 50 cm, a 1,5 m, avvitato al muro
    lam = C.mat_pbr('cartello_lamiera', base=(0.5, 0.52, 0.52), roughness=0.5, metallic=0.7)
    st = C.mat_pbr('cartello_fiume', color=CARTELLO, roughness=0.6)
    xc = MURO_O + 0.002
    lastra = C.box('cartello_fiume_lastra', g(xc + 0.006, Y + 1.5, 62.3), (0.012, 0.5, 0.5), lam)
    faccia = C.quad('cartello_fiume_faccia', g(xc + 0.0125, Y + 1.5, 62.3), 0.49, 0.49, normale=(1, 0, 0), mat=st)
    obs.append(C.unisci('cartello_fiume', [lastra, faccia]))
    return [q, *f, c]


def bidone(nome, base, blu, bianco, rz):
    """Un bidone di plastica (fusto da 200 l): il corpo con due nervature, l'orlo in cima e i due tappi."""
    r, h = 0.235, 0.88          # (con le nervature 49 cm di diametro)
    pezzi = [C.cilindro(nome + '_corpo', base + Vector((0, 0, h / 2)), r, h, blu, seg=40)]
    for t in (0.33, 0.66):
        pezzi.append(C.toro(nome + '_nervatura', base + Vector((0, 0, h * t)), r, 0.012, blu, seg=40))
    pezzi.append(C.toro(nome + '_orlo', base + Vector((0, 0, h - 0.01)), r - 0.006, 0.014, blu, seg=40))
    for dx, rt in ((0.12, 0.035), (-0.13, 0.022)):
        a = R_(rz)
        q = base + Vector((math.cos(a) * dx, math.sin(a) * dx, h + 0.012))
        pezzi.append(C.cilindro(nome + '_tappo', q, rt, 0.024, bianco, seg=16))
    return C.unisci(nome, pezzi)


def collisioni(obs, grandi):
    for o in grandi:
        lo, hi = _scatola(o)
        obs.append(C.collisione_box(o.name + '_col', lo, hi))
    s = bpy.data.objects['secchio']
    lo, hi = _scatola(s)
    obs.append(C.collisione_box('secchio_col', lo, hi))


def _scatola(o):
    ps = [o.matrix_world @ Vector(c) for c in o.bound_box]
    return (Vector([min(p[i] for p in ps) for i in range(3)]), Vector([max(p[i] for p in ps) for i in range(3)]))


def controlla(obs):
    """Le misure delle regole (LEGGIMI): profondità dal muro, niente sotto 2 m sopra il corridoio oltre i 50 cm, gli
    ultimi 2 m liberi."""
    for o in obs:
        if o.name.endswith('-convcolonly') or o.name.startswith('_'):
            continue
        lo, hi = _scatola(o)
        prof = hi.x - MURO_O
        z0, z1 = -hi.y, -lo.y
        y0, y1 = lo.z - Y, hi.z - Y
        basso = y0 < 2.0
        print('MISURA %-22s prof %.2f  z %.2f-%.2f  altezza %.2f-%.2f  %s' % (o.name, prof, z0, z1, y0, y1,
              'tocca' if Posa.tocca(o) else 'NON TOCCA'))
        if basso and prof > 0.5 + 1e-3:
            print('  TROPPO PROFONDO')
        if basso and z1 > FINE_ARREDO + 1e-3:
            print('  OLTRE LA FINE DELL\'ARREDO')


def esporta(obs):
    os.makedirs(os.path.dirname(USCITA), exist_ok=True)
    for im in bpy.data.images:
        lim = 1024
        if im.size[0] > lim:
            im.scale(lim, lim)
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
    tubi(obs)
    grandi = arredi(obs)
    collisioni(obs, grandi)
    controlla(obs)
    for o in sost:
        bpy.data.objects.remove(o)
    esporta(obs)
