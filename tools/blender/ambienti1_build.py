"""Costruisce gli ambienti interni dell'inizio del capitolo 1 e li esporta in GLB per Godot.
  1. corridoio di servizio del ponte inferiore (risveglio, cartellone, porta sala pompe, porta tagliafuoco)
  2. spogliatoi (armadietti, panche, docce, corridoio con vasca lava-piedi, tornello, saracinesca con turbina)
  3. stanzino dei bagnini (fischietti, salvagenti, pronto soccorso, bacheca, sedia, radio, rastrelliera dello zaino)
Uso: /home/user/tools/blender-venv/bin/python tools/blender/ambienti1_build.py [--no-export]
Uscita: assets_src/ambienti_interni/ambienti1.blend e assets_src/ambienti_interni/glb/*.glb
Misure in metri, Z in alto (in Godot diventa Y), pavimento a quota 0. Pianta e nomi in assets_src/ambienti_interni/README.md."""
import math, os, random, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Vector, Matrix, Euler
import ambienti1_lib as L

AI = L.AI
MESHY = os.path.join(AI, 'meshy')
POSTER = os.path.join(AI, 'poster')
R = math.radians


def materiali():
    M = {n: L.mat_tex(n) for n in L.SCALA_UV}
    M.update(L.materiali_base())
    M['salvagente'] = L.mat_tex('salvagente')
    M['cartellone'] = L.mat_immagine('cartellone_medusa', os.path.join(POSTER, 'cartellone_medusa_vecchio.jpg'), rough=0.55)
    M['cartello_regole'] = L.mat_immagine('cartello_regole', os.path.join(POSTER, 'cartello_regole_vecchio.jpg'), rough=0.5)
    M['poster_bagnino'] = L.mat_immagine('poster_bagnino', os.path.join(POSTER, 'poster_bagnino_vecchio.jpg'), rough=0.7)
    M['pulsante'] = L.mat_colore('pulsante_rosso', (0.7, 0.03, 0.02), rough=0.35, emiss=(1, 0.05, 0.02), forza=4.0)
    M['pulsante_verde'] = L.mat_colore('pulsante_verde', (0.05, 0.5, 0.1), rough=0.35, emiss=(0.1, 1, 0.2), forza=8.0)
    M['impronte'] = L.mat_colore('impronte_bagnate', (0.02, 0.02, 0.02), rough=0.05)
    M['polaroid'] = L.mat_colore('polaroid_retro', (0.82, 0.8, 0.74), rough=0.6)
    return M


def prop(nome, file, loc, rot_z=0.0, dim=None, asse='max', rot=(0, 0, 0)):
    return L.importa_prop(nome, os.path.join(MESHY, file + '.glb'), loc, R(rot_z), dim, asse, rot)


def copia(ob, nome, loc, rot_z=None, rot=None):
    o = ob.copy(); o.name = nome
    L._link(o); o.location = loc
    if rot_z is not None:
        o.rotation_euler = (0, 0, R(rot_z))
    if rot is not None:
        o.rotation_euler = rot
    return o


def pozza(nome, centro, rx, ry, M, seme=0, z=0.004):
    """Pozza d'acqua: poligono irregolare appena sopra il pavimento (oggetto separato, il livello si puo' animare)."""
    import bmesh
    rnd = random.Random(seme)
    bm = bmesh.new(); n = 28
    fase = [rnd.uniform(0, 6.28) for _ in range(3)]
    vs = []
    for i in range(n):
        a = 2 * math.pi * i / n
        k = 1 + 0.18 * math.sin(3 * a + fase[0]) + 0.12 * math.sin(5 * a + fase[1]) + 0.08 * math.sin(7 * a + fase[2])
        vs.append(bm.verts.new((centro[0] + rx * k * math.cos(a), centro[1] + ry * k * math.sin(a), z)))
    bm.faces.new(vs)
    ob = L._ob_da_bm(nome, bm, M['acqua'])
    L.uv_scatola(ob, 1.0)
    ob.visible_shadow = False   # nei render Cycles l'acqua non deve fare ombra sul pavimento
    return ob


def cornice_porta(nome, lato, a, b, za, piano_muro, M, mat=None, s=0.08, sporge=0.04, entrambi=True):
    """Telaio attorno a un'apertura nella parete. lato N/S: a,b lungo x; E/W lungo y. piano_muro: coord della faccia interna."""
    mat = mat or M['porta_lamiera']
    parti = []
    facce = [(piano_muro, 1 if lato in ('S', 'W') else -1)]
    if entrambi:
        spess = 0.2
        facce.append((piano_muro - spess if lato in ('S', 'W') else piano_muro + spess, -1 if lato in ('S', 'W') else 1))
    for p, verso in facce:
        p0, p1 = (p, p + verso * sporge) if verso > 0 else (p + verso * sporge, p)
        pezzi = [((a - s, za), (a, 0)), ((b, za), (b + s, 0)), ((a - s, za + s), (b + s, za))]
        for (u0, z1), (u1, z0) in pezzi:
            if lato in ('N', 'S'):
                parti.append(L.scatola(nome, (u0, p0, z0), (u1, p1, z1), mat))
            else:
                parti.append(L.scatola(nome, (p0, u0, z0), (p1, u1, z1), mat))
    return L.unisci(nome, parti)


def costole(nome, x0, x1, y0, y1, h, passo, M, salta_s=(), salta_n=()):
    """Costole della nave (rinforzi verticali sulle pareti lunghe e travi sul soffitto).
    salta_s / salta_n: intervalli di x liberi (porte, cartelloni) sulla parete sud / nord."""
    parti = []
    libero = lambda x, salta: all(not (a - 0.1 < x < b + 0.1) for a, b in salta)
    if True:
        x = x0 + passo
        while x < x1 - 0.3:
            if libero(x, salta_s):
                parti.append(L.scatola(nome, (x - 0.06, y0, 0), (x + 0.06, y0 + 0.07, h), M['lamiera_crema']))
            if libero(x, salta_n):
                parti.append(L.scatola(nome, (x - 0.06, y1 - 0.07, 0), (x + 0.06, y1, h), M['lamiera_crema']))
            parti.append(L.scatola(nome, (x - 0.06, y0, h - 0.16), (x + 0.06, y1, h), M['lamiera_crema']))
            x += passo
    return L.unisci(nome, parti)


def grata_parete(nome, centro, w, h, normale, M):
    """Griglia di ventilazione a lamelle sulla parete."""
    n = Vector(normale); parti = []
    parti.append(L.scatola(nome, (-w / 2, -h / 2, 0), (w / 2, h / 2, 0.02), M['metallo_grezzo'], uv=False))
    k = int(h / 0.04)
    for i in range(k):
        z = -h / 2 + 0.02 + i * 0.04
        parti.append(L.scatola(nome, (-w / 2 + 0.02, z, 0.02), (w / 2 - 0.02, z + 0.012, 0.035), M['nero'], uv=False))
    ob = L.unisci(nome, parti)
    q = n.to_track_quat('Z', 'Y')
    ob.matrix_world = Matrix.Translation(centro) @ q.to_matrix().to_4x4()
    L.uv_scatola(ob, 0.5)
    return ob


# =====================================================================================
# 1. CORRIDOIO DEL PONTE INFERIORE   x 0..22, y 0..2.6, h 2.7
# =====================================================================================
def corridoio(M):
    L.usa_collezione('corridoio')
    X0, X1, Y0, Y1, H = 0.0, 22.0, 0.0, 2.6, 2.7
    mats = dict(pav=M['piastrelle_pavimento'], sof=M['soffitto_lamiera'], muro=M['lamiera_crema'], muro_basso=M['lamiera_petrolio'])
    ap = {
        'E': [(0.7, 1.9, 0, 2.1)],          # porta tagliafuoco (alle spalle del giocatore)
        'S': [(17.0, 18.0, 0, 2.05)],       # porta della sala pompe
        'N': [(6.0, 7.6, 0, 2.2)],          # passaggio verso gli spogliatoi
        'W': [(0.8, 1.8, 0, 2.05)],         # porta di servizio chiusa in fondo
    }
    statico = L.stanza('corridoio', X0, Y0, X1, Y1, H, mats, ap)
    statico.append(costole('corridoio_costole', X0, X1, Y0, Y1, H, 2.5, M, salta_s=[(13.6, 15.6), (16.9, 18.1)], salta_n=[(5.9, 7.7)]))
    # telai delle porte
    statico.append(cornice_porta('telaio_tagliafuoco', 'E', 0.7, 1.9, 2.1, X1, M, M['vernice_rossa']))
    statico.append(cornice_porta('telaio_pompe', 'S', 17.0, 18.0, 2.05, Y0, M, M['vernice_gialla']))
    statico.append(cornice_porta('telaio_spogliatoi', 'N', 6.0, 7.6, 2.2, Y1, M, entrambi=False))
    statico.append(cornice_porta('telaio_servizio', 'W', 0.8, 1.8, 2.05, X0, M))
    # strisce gialle e nere sulla soglia della sala pompe
    statico.append(L.scatola('soglia_pompe', (17.0, -0.2, 0), (18.0, 0.04, 0.03), M['vernice_gialla']))

    # tubi sul soffitto, lato nord, per tutta la lunghezza; uno scende vicino al passaggio
    tubi = [
        L.tubo_percorso('tubo_grande', [(0, 2.32, 2.38), (22, 2.32, 2.38)], 0.085, M['ruggine'], passo_flange=2.2),
        L.tubo_percorso('tubo_rosso', [(0, 2.12, 2.48), (22, 2.12, 2.48)], 0.05, M['vernice_rossa'], passo_flange=3.0),
        L.tubo_percorso('tubo_piccolo', [(0, 2.48, 2.12), (8.2, 2.48, 2.12), (8.2, 2.48, 0.25), (8.2, 2.2, 0.25), (8.2, 2.2, -0.05)], 0.035, M['metallo_grezzo'], passo_flange=1.5),
        L.tubo_percorso('tubo_sud', [(0, 0.22, 2.45), (16.4, 0.22, 2.45), (16.4, 0.22, 2.3), (22, 0.22, 2.3)], 0.06, M['metallo_grezzo'], passo_flange=2.5),
    ]
    staffe = []
    for x in [1.2 + 2.5 * i for i in range(9)]:
        staffe.append(L.scatola('staffa', (x - 0.03, 2.0, 2.3), (x + 0.03, 2.6, 2.56), M['metallo_grezzo']))
        staffe.append(L.scatola('staffa', (x - 0.03, 0.0, 2.36), (x + 0.03, 0.32, 2.4), M['metallo_grezzo']))
    statico += tubi + [L.unisci('staffe_tubi', staffe)]
    # canalina dei cavi sul lato sud
    statico.append(L.scatola('canalina_cavi', (0, 0.0, 2.05), (22, 0.12, 2.1), M['metallo_grezzo']))
    # griglie di ventilazione
    statico.append(grata_parete('grata_vent_1', (4.0, 2.595, 2.0), 0.5, 0.35, (0, -1, 0), M))
    statico.append(grata_parete('grata_vent_2', (11.5, 0.005, 1.95), 0.5, 0.35, (0, 1, 0), M))
    statico.append(grata_parete('grata_vent_3', (20.0, 2.595, 0.35), 0.6, 0.3, (0, -1, 0), M))

    # ---- porta tagliafuoco (cardine sul lato y=0.7; in Godot parte aperta e si chiude da sola)
    pt = [L.scatola('porta_tagliafuoco', (21.93, 0.72, 0.01), (22.0, 1.88, 2.08), M['vernice_rossa'])]
    pt.append(L.scatola('pt_vetro_cornice', (21.91, 1.15, 1.35), (21.93, 1.45, 1.75), M['metallo_grezzo']))
    pt.append(L.cilindro('pt_maniglia', (21.85, 1.72, 1.05), (21.93, 1.72, 1.05), 0.02, M['cromo']))
    pt.append(L.cilindro('pt_leva', (21.85, 1.72, 1.05), (21.85, 1.55, 1.02), 0.015, M['cromo']))
    pt.append(L.scatola('pt_chiudiporta', (21.85, 0.8, 1.98), (21.93, 1.3, 2.05), M['metallo_grezzo']))
    porta_tf = L.unisci('porta_tagliafuoco', pt)
    L.ammacca(porta_tf, 0.004, 2.0, 3.0, 3)
    L.origine(porta_tf, (21.965, 0.72, 0))
    vtf = L.scatola('porta_tagliafuoco_vetro', (21.915, 1.17, 1.37), (21.925, 1.43, 1.73), M['vetro_sporco'], uv=False)
    L.figlio(vtf, porta_tf)
    # oltre la porta: un tratto di corridoio buio da cui si e' arrivati
    statico += L.stanza('corridoio_oltre', 22.2, 0.4, 25.0, 2.2, 2.4, mats, {'W': [(0.4, 2.2, 0, 2.4)]})

    # ---- porta della sala pompe (cardine x=17; maniglione antipanico sul lato della sala pompe, y<0)
    pp = [L.scatola('porta_sala_pompe', (17.02, -0.13, 0.01), (17.98, -0.07, 2.03), M['porta_lamiera'])]
    pp.append(L.scatola('pp_piastra', (17.75, -0.07, 0.95), (17.9, -0.06, 1.25), M['cromo']))           # lato corridoio: solo una piastra
    pp.append(L.scatola('pp_oblo_cornice', (17.3, -0.06, 1.35), (17.7, -0.05, 1.8), M['metallo_grezzo']))
    pp.append(L.scatola('pp_maniglione', (17.15, -0.24, 0.98), (17.85, -0.2, 1.04), M['vernice_rossa']))   # lato sala pompe
    for x in (17.12, 17.88):
        pp.append(L.scatola('pp_supporto', (x - 0.025, -0.2, 0.97), (x + 0.025, -0.13, 1.05), M['metallo_grezzo']))
    porta_pp = L.unisci('porta_sala_pompe', pp)
    L.ammacca(porta_pp, 0.004, 2.5, 5.0, 3)
    L.origine(porta_pp, (17.02, -0.1, 0))
    vpp = L.scatola('porta_sala_pompe_vetro', (17.33, -0.075, 1.38), (17.67, -0.065, 1.77), M['vetro_sporco'], uv=False)
    L.figlio(vpp, porta_pp)
    # pianerottolo e scala che scende verso la sala pompe (si collega al piano sotto)
    pian = L.stanza('scala_pompe', 16.2, -3.9, 18.8, -0.2, 2.7, dict(pav=M['cemento'], sof=M['soffitto_lamiera'], muro=M['lamiera_crema'], muro_basso=M['lamiera_petrolio']),
                    {'N': [(17.0, 18.0, 0, 2.05)]}, pavimento=False)
    L.raccogli(True)
    pian.append(L.scatola('scala_pompe_pian', (16.0, -1.4, -0.2), (19.0, 0.0, 0), M['cemento']))
    L.raccogli(False)
    # collisione della scala: una rampa (36 gradi) invece dei gradini
    rampa = L.scatola('scala_pompe_rampa-colonly', (16.4, -1.25, -0.1), (18.6, 1.25, 0.0), None, uv=False)
    rampa.data.transform(Matrix.Rotation(math.atan2(1.8, 2.5), 4, 'X'))
    rampa.location = (0, -2.65, -0.9); rampa.hide_render = True; rampa.display_type = 'WIRE'
    for i in range(10):
        y = -1.4 - i * 0.25; z = -0.18 * (i + 1)
        pian.append(L.scatola('gradino', (16.4, y - 0.25, z - 0.2), (18.6, y, z), M['lamiera_grata']))
    pian.append(L.tubo_percorso('corrimano_scala', [(18.55, -1.3, 0.95), (18.55, -3.9, -0.95)], 0.025, M['vernice_gialla'], flange=False))
    statico += pian
    # porta di servizio in fondo, chiusa a chiave
    ps = [L.scatola('porta_servizio', (0.0, 0.82, 0.01), (0.06, 1.78, 2.03), M['porta_lamiera'])]
    ps.append(L.scatola('ps_oblo', (0.06, 1.1, 1.35), (0.075, 1.5, 1.8), M['metallo_grezzo']))
    ps.append(L.cilindro('ps_maniglia', (0.06, 1.65, 1.0), (0.13, 1.65, 1.0), 0.02, M['cromo']))
    porta_s = L.unisci('porta_servizio', ps); L.ammacca(porta_s, 0.005, 2.0, 9.0, 3)
    L.col_scatola((0.0, 0.8, 0.0), (0.08, 1.8, 2.05))
    statico.append(L.scatola('porta_servizio_vetro', (0.074, 1.13, 1.38), (0.078, 1.47, 1.77), M['vetro_sporco'], uv=False))

    # ---- cartellone della mascotte (accanto alla porta della sala pompe, lato sud)
    cx, cz, cw, ch = 14.6, 1.3, 1.5, 2.0
    statico.append(L.piano('cartellone_medusa', (cx, 0.016, cz), cw, ch, M['cartellone'], rot=(R(90), 0, 0)))
    cor = [L.scatola('cornice', (cx - cw / 2 - 0.05, 0, cz - ch / 2 - 0.05), (cx + cw / 2 + 0.05, 0.03, cz - ch / 2), M['vernice_gialla']),
           L.scatola('cornice', (cx - cw / 2 - 0.05, 0, cz + ch / 2), (cx + cw / 2 + 0.05, 0.03, cz + ch / 2 + 0.05), M['vernice_gialla']),
           L.scatola('cornice', (cx - cw / 2 - 0.05, 0, cz - ch / 2), (cx - cw / 2, 0.03, cz + ch / 2), M['vernice_gialla']),
           L.scatola('cornice', (cx + cw / 2, 0, cz - ch / 2), (cx + cw / 2 + 0.05, 0.03, cz + ch / 2), M['vernice_gialla'])]
    statico.append(L.unisci('cornice_cartellone', cor))
    # le costole passano davanti al cartellone? no: il cartellone sta tra x=12.5 e 15 (costole a 12.5 e 15)

    # ---- luci: rosse d'emergenza e neon quasi tutti spenti
    luci = []
    for i, (p, n) in enumerate([((3.0, 2.58, 2.2), (0, -1, 0)), ((10.8, 2.58, 2.2), (0, -1, 0)), ((19.2, 2.58, 2.2), (0, -1, 0)),
                                ((17.5, 0.02, 2.35), (0, 1, 0)), ((21.98, 1.3, 2.4), (-1, 0, 0)), ((0.02, 1.3, 2.35), (1, 0, 0)),
                                ((7.5, 0.02, 2.2), (0, 1, 0)), ((17.5, 2.58, 2.25), (0, -1, 0))]):
        c, v, l = L.lampada_emergenza(f'luce_emergenza_{i + 1:02d}', p, n, M, watt=32 if i != 4 else 22)
        luci += [c, v]
    for i, (x, stato, app) in enumerate([(4.5, 'spento', 0), (10.0, 'sfarfalla', 0), (15.5, 'spento', 0.35), (20.0, 'spento', 0)]):
        c, t, l = L.neon_soffitto(f'neon_corridoio_{i + 1}', (x, 1.3, 0), 1.2, M, H, stato, watt=90, appeso=app, rot_z=0)
        luci += [c, t]

    # ---- acqua sul pavimento (pozze separate: in Godot possono avere lo shader dell'acqua)
    pz = [pozza('pozza_corridoio_1', (13.5, 1.0, 0), 2.2, 0.75, M, 1), pozza('pozza_corridoio_2', (9.0, 1.6, 0), 1.3, 0.6, M, 2),
          pozza('pozza_corridoio_3', (19.6, 1.5, 0), 1.0, 0.55, M, 3), pozza('pozza_corridoio_4', (4.0, 1.2, 0), 1.5, 0.7, M, 4),
          pozza('pozza_corridoio_5', (17.4, 0.5, 0), 0.6, 0.4, M, 5)]
    L.unisci('acqua_pozze_corridoio', pz)
    L.vuoto('emit_goccia_corridoio_1', (13.2, 2.32, 2.29))     # gocciolio dal tubo sopra la pozza
    L.vuoto('emit_goccia_corridoio_2', (19.4, 2.32, 2.29))

    # ---- oggetti
    prop('estintore', 'estintore', (9.6, 0.12, 0.9), 0, 0.55, 'z')
    prop('cestino', 'cestino', (5.3, 2.3, 0), 30, 0.55, 'z')
    prop('paperella', 'paperella', (13.9, 1.2, 0.0), 140, 0.09)
    prop('pallone', 'pallone', (2.2, 0.6, 0), 0, 0.42)
    prop('asciugamano_corridoio', 'asciugamano', (8.4, 0.7, 0), 75, 0.8)

    # ---- punti per il gioco
    L.vuoto('marker_risveglio', (20.4, 1.25, 0.0), (0, 0, R(90)), 'ARROWS', 0.5)    # sdraiato, guarda verso ovest (-X)
    L.vuoto('marker_polaroid_P1', (20.9, 0.55, 0.005), (0, 0, R(20)), 'CUBE', 0.05)
    L.vuoto('marker_porta_tagliafuoco_cardine', (21.965, 0.72, 0), dim=0.3)
    L.unisci('corridoio_statico', statico)
    L.crea_collisione('corridoio', 'corridoio')


# =====================================================================================
# 2. SPOGLIATOI   x 3..11, y 3..11, h 2.9  + docce, corridoio lava-piedi, gabbiotto
# =====================================================================================
def armadietto(nome, x, y, faccia, M, stato='chiuso', ang=0, mat_anta=None, seme=0, w=0.4, d=0.5, h=1.8):
    """Un armadietto. faccia: +1 se l'anta guarda verso +x, -1 verso -x. Ritorna (corpo, anta)."""
    zb = 0.12
    # corpo costruito con l'anta verso +x, poi specchiato
    parti = [
        L.scatola(nome, (0, 0, zb), (0.02, w, zb + h), M['armadietto_verde']),               # fondo
        L.scatola(nome, (0, 0, zb), (d, 0.015, zb + h), M['armadietto_verde']),              # fianco
        L.scatola(nome, (0, w - 0.015, zb), (d, w, zb + h), M['armadietto_verde']),
        L.scatola(nome, (0, 0, zb + h - 0.02), (d, w, zb + h), M['armadietto_verde']),       # cielo
        L.scatola(nome, (0, 0, zb), (d, w, zb + 0.02), M['armadietto_verde']),
        L.scatola(nome, (0, 0.015, zb + 1.45), (d - 0.03, w - 0.015, zb + 1.47), M['armadietto_verde']),  # ripiano
        L.cilindro(nome, (0.25, 0.03, zb + 1.38), (0.25, w - 0.03, zb + 1.38), 0.008, M['cromo'], seg=6),   # asta appendiabiti
    ]
    corpo = L.unisci(nome + '_corpo', parti)
    ma = mat_anta or M['armadietto_verde']
    ap = [L.scatola(nome, (d - 0.02, 0.01, zb + 0.02), (d, w - 0.01, zb + h - 0.02), ma)]
    for zz in (zb + 1.55, zb + 1.6, zb + 1.65, zb + 0.15, zb + 0.2, zb + 0.25):
        ap.append(L.scatola(nome, (d - 0.001, 0.09, zz), (d + 0.004, w - 0.09, zz + 0.018), M['nero'], uv=False))
    ap.append(L.scatola(nome, (d, w - 0.07, zb + 0.95), (d + 0.03, w - 0.045, zb + 1.1), M['cromo'], uv=False))  # maniglia
    ap.append(L.scatola(nome, (d, 0.12, zb + 1.3), (d + 0.003, w - 0.12, zb + 1.36), M['plastica_bianca'], uv=False))  # targhetta vuota
    anta = L.unisci(nome + '_anta', ap)
    L.ammacca(anta, 0.006, 4.0, seme, 4)
    L.origine(anta, (d, 0.01, 0))
    anta.rotation_euler = (0, 0, R(-ang))
    zoc = L.scatola(nome + '_zoccolo', (0.03, 0, 0), (d - 0.03, w, zb), M['lamiera_petrolio'])
    for o in (corpo, anta, zoc):
        if faccia < 0:
            o.matrix_world = Matrix.Translation((x, y, 0)) @ Matrix.Rotation(R(180), 4, 'Z') @ Matrix.Translation((0, -w, 0)) @ o.matrix_world
        else:
            o.matrix_world = Matrix.Translation((x, y, 0)) @ o.matrix_world
    corpo = L.unisci(nome + '_corpo', [corpo, zoc])
    for o in (corpo,):
        L.uv_scatola(o)
    if stato == 'mancante':
        bpy.data.objects.remove(anta); anta = None
    return corpo, anta


def fila_armadietti(prefisso, x, y0, n, faccia, M, stati, seme=0):
    corpi, ante, speciali = [], [], {}
    colori = {3: M['vernice_gialla'], 9: M['vernice_rossa'], 14: M['vernice_gialla']}
    for i in range(n):
        st, ang = stati.get(i, ('chiuso', random.uniform(0, 3)))
        c, a = armadietto(f'{prefisso}_{i:02d}', x, y0 + i * 0.4, faccia, M, st, ang, colori.get((i + seme) % 17), seme + i)
        corpi.append(c)
        if a is not None:
            if st == 'speciale':
                speciali[i] = a
            else:
                ante.append(a)
    return L.unisci(prefisso + '_corpi', corpi), (L.unisci(prefisso + '_ante', ante) if ante else None), speciali


def panca(nome, x0, y0, x1, y1, M, rotta=False):
    """Panca di legno a tre doghe su gambe di metallo, lungo l'asse y."""
    parti = []; cx = (x0 + x1) / 2
    for k in range(3):
        xa = x0 + k * (x1 - x0) / 3 + 0.01; xb = x0 + (k + 1) * (x1 - x0) / 3 - 0.01
        if rotta and k == 2:
            ym = (y0 + y1) / 2
            parti.append(L.scatola(nome, (xa, y0, 0.42), (xb, ym - 0.1, 0.45), M['legno_panca']))
            d = L.scatola(nome, (xa, ym + 0.1, 0.42), (xb, y1, 0.45), M['legno_panca'])
            d.rotation_euler = (R(-6), 0, 0); parti.append(d)
        else:
            parti.append(L.scatola(nome, (xa, y0, 0.42), (xb, y1, 0.45), M['legno_panca']))
    yy = y0 + 0.15
    while yy < y1:
        parti.append(L.scatola(nome, (x0 + 0.02, yy - 0.025, 0), (x0 + 0.06, yy + 0.025, 0.42), M['metallo_grezzo']))
        parti.append(L.scatola(nome, (x1 - 0.06, yy - 0.025, 0), (x1 - 0.02, yy + 0.025, 0.42), M['metallo_grezzo']))
        parti.append(L.scatola(nome, (x0 + 0.02, yy - 0.025, 0.38), (x1 - 0.02, yy + 0.025, 0.42), M['metallo_grezzo']))
        yy += 1.3
    return L.unisci(nome, parti)


def doccia(i, x, yparete, M):
    """Doccia sulla parete nord: tubo, braccio, soffione (separato), rubinetto (separato), punto d'emissione."""
    pref = f'doccia_{i:02d}'
    y = yparete - 0.05
    tubo = L.tubo_percorso(pref + '_tubo', [(x, y, 1.05), (x, y, 2.15), (x, y - 0.3, 2.15)], 0.016, M['cromo'], flange=False)
    sof = [L.cilindro(pref, (x, y - 0.33, 2.17), (x, y - 0.33, 2.11), 0.075, M['cromo'], seg=20),
           L.cilindro(pref, (x, y - 0.33, 2.112), (x, y - 0.33, 2.105), 0.068, M['nero'], seg=20)]
    soffione = L.unisci(pref + '_soffione', sof); L.origine(soffione, (x, y - 0.33, 2.15))
    rub = [L.cilindro(pref, (x, y, 1.1), (x, y - 0.07, 1.1), 0.03, M['cromo'], seg=12),
           L.scatola(pref, (x - 0.06, y - 0.08, 1.09), (x + 0.06, y - 0.06, 1.11), M['cromo'], uv=False)]
    rubinetto = L.unisci(pref + '_rubinetto', rub); L.origine(rubinetto, (x, y - 0.05, 1.1))
    L.vuoto('emit_' + pref, (x, y - 0.33, 2.1), (0, 0, 0), 'SINGLE_ARROW', 0.3)
    return tubo


def spogliatoi(M):
    L.usa_collezione('spogliatoi')
    X0, X1, Y0, Y1, H = 3.0, 11.0, 3.0, 11.0, 2.9
    mats = dict(pav=M['piastrelle_pavimento'], sof=M['soffitto_lamiera'], muro=M['lamiera_crema'], muro_basso=M['lamiera_petrolio'])
    statico = L.stanza('spogliatoi', X0, Y0, X1, Y1, H, mats, {
        'S': [(6.0, 7.6, 0, 2.2)],
        'N': [(3.6, 7.8, 0, 2.4), (8.6, 10.8, 0, 2.4)],
        'E': [(8.0, 8.9, 0, 2.05)],
    }, zoccolo=1.2)
    statico.append(cornice_porta('telaio_stanzino', 'E', 8.0, 8.9, 2.05, X1, M))
    statico.append(cornice_porta('telaio_spogliatoi_S', 'S', 6.0, 7.6, 2.2, Y0, M, entrambi=False))

    # ---- armadietti: fila ovest (18) ed est (11 + 3), ante ammaccate, qualcuna aperta
    random.seed(11)
    cw, aw, sw = fila_armadietti('armadietti_ovest', X0, 3.3, 18, +1, M,
                                 {2: ('aperto', 95), 5: ('aperto', 25), 8: ('mancante', 0), 11: ('aperto', 110), 15: ('aperto', 12)}, seme=0)
    ce, ae, se = fila_armadietti('armadietti_est', X1, 3.3, 11, -1, M,
                                 {1: ('aperto', 70), 4: ('speciale', 4), 7: ('aperto', 30), 9: ('aperto', 100)}, seme=5)
    ce2, ae2, _ = fila_armadietti('armadietti_est2', X1, 9.3, 4, -1, M, {2: ('aperto', 45)}, seme=21)
    L.col_scatola((X0, 3.3, 0), (X0 + 0.52, 3.3 + 18 * 0.4, 1.94))
    L.col_scatola((X1 - 0.52, 3.3, 0), (X1, 3.3 + 11 * 0.4, 1.94))
    L.col_scatola((X1 - 0.52, 9.3, 0), (X1, 9.3 + 4 * 0.4, 1.94))
    # l'armadietto che sbatte (anta separata, cardine come origine; dentro un salvagente colorato)
    anta_sb = se[4]; anta_sb.name = 'armadietto_sbatte_anta'
    anta_sb.rotation_euler = (0, 0, R(180 + 4))
    L.vuoto('marker_armadietto_sbatte', (X1 - 0.25, 3.3 + 4 * 0.4 + 0.2, 1.0), dim=0.2)
    sg = prop('salvagente_giocattolo', 'salvagente_giocattolo', (X1 - 0.26, 3.3 + 4 * 0.4 + 0.2, 0.15), 90, 0.36)
    sg.rotation_euler = (R(75), 0, R(90))
    L.vuoto('marker_polaroid_P2', (X0 + 0.25, 3.3 + 11 * 0.4 + 0.2, 1.6), dim=0.05)   # sul ripiano dell'armadietto aperto

    # ---- panche
    statico.append(panca('panca_ovest', 4.45, 4.0, 4.85, 9.8, M))
    statico.append(panca('panca_est', 9.15, 4.0, 9.55, 7.4, M, rotta=True))
    L.col_scatola((4.45, 4.0, 0), (4.85, 9.8, 0.45)); L.col_scatola((9.15, 4.0, 0), (9.55, 7.4, 0.45))
    # cartello con i pittogrammi vicino all'ingresso
    statico.append(L.piano('cartello_regole_spogliatoi', (8.6, 3.012, 1.65), 0.45, 0.6, M['cartello_regole'], rot=(R(90), 0, 0)))
    statico.append(L.tubo_percorso('tubi_spogliatoi', [(3.0, 10.75, 2.6), (11.0, 10.75, 2.6)], 0.07, M['ruggine']))
    statico.append(L.tubo_percorso('tubi_spogliatoi_2', [(6.2, 3.0, 2.72), (6.2, 11.0, 2.72)], 0.045, M['metallo_grezzo']))
    statico.append(grata_parete('grata_vent_spogliatoi', (7.0, 10.995, 2.5), 0.6, 0.3, (0, -1, 0), M))

    # ---- docce   x 3..8.2, y 11.2..14.6
    DX0, DX1, DY0, DY1 = 3.0, 8.2, 11.2, 14.6
    md = dict(pav=M['piastrelle_doccia'], sof=M['soffitto_lamiera'], muro=M['piastrelle_doccia'], muro_basso=M['piastrelle_verdi'])
    statico += L.stanza('docce', DX0, DY0, DX1, DY1, H, md, {'S': [(DX0 - 0.2, DX1 + 0.2, 0, H)], 'W': [(12.0, 12.6, 0, 0.5)]}, zoccolo=1.2)
    tubi_d = []
    for i, x in enumerate([3.7, 4.65, 5.6, 6.55, 7.5]):
        tubi_d.append(doccia(i + 1, x, DY1, M))
        statico.append(L.scatola('scarico_doccia', (x - 0.1, DY1 - 0.7, 0.0), (x + 0.1, DY1 - 0.5, 0.004), M['lamiera_grata']))
    for x in [4.175, 5.125, 6.075, 7.025]:
        L.col_scatola((x - 0.04, DY1 - 0.95, 0.0), (x + 0.04, DY1, 2.0))
        statico.append(L.scatola('divisorio_doccia', (x - 0.04, DY1 - 0.95, 0.15), (x + 0.04, DY1, 2.0), M['piastrelle_verdi']))
    statico.append(L.tubo_percorso('tubo_docce', [(3.0, DY1 - 0.05, 2.15), (8.2, DY1 - 0.05, 2.15)], 0.022, M['cromo'], flange=False))
    statico += tubi_d
    statico.append(L.scatola('canaletta_docce', (3.0, DY0 + 0.4, 0), (8.2, DY0 + 0.55, 0.004), M['lamiera_grata']))
    L.vuoto('emit_vapore_docce', (5.6, 13.6, 1.5), dim=0.6)
    # grata d'aerazione bassa (si apre: cardine in alto) e condotto dietro
    gr = [L.scatola('grata_aerazione', (DX0 - 0.02, 12.0, 0.04), (DX0, 12.6, 0.5), M['metallo_grezzo'])]
    for k in range(9):
        z = 0.08 + k * 0.045
        gr.append(L.scatola('grata_aerazione', (DX0 - 0.015, 12.04, z), (DX0 + 0.012, 12.56, z + 0.015), M['metallo_grezzo']))
    grata = L.unisci('grata_aerazione', gr)
    L.origine(grata, (DX0, 12.3, 0.5)); grata.rotation_euler = (0, R(-8), 0)   # un po' socchiusa
    L.vuoto('marker_grata_aerazione_cardine', (DX0, 12.3, 0.5), dim=0.2)
    statico += L.stanza('condotto_aerazione', 0.6, 12.0, 2.8, 12.6, 0.5, dict(pav=M['ruggine'], sof=M['ruggine'], muro=M['ruggine']), {'E': [(12.0, 12.6, 0, 0.5)]}, t=0.05)
    # impronte bagnate verso la grata (B1)
    imp = []
    for k in range(7):
        px = 5.2 - k * 0.32; py = 12.9 - k * 0.09 + (0.08 if k % 2 else -0.08)
        o = L.piano('impronta', (px, py, 0.003), 0.11, 0.25, M['impronte'], rot=(0, 0, R(80)))
        imp.append(o)
    L.unisci('impronte_bagnate_B1', imp)

    # ---- corridoio con la vasca lava-piedi   x 8.6..10.8, y 11.2..20.5, h 2.7
    CX0, CX1, CY0, CY1, CH = 8.6, 10.8, 11.2, 20.5, 2.7
    UX0, UX1, UH = 9.1, 10.3, 2.2    # uscita verso la sala principale: 1,2 x 2,2 m
    mc = dict(pav=M['piastrelle_pavimento'], sof=M['soffitto_lamiera'], muro=M['piastrelle_doccia'], muro_basso=M['piastrelle_verdi'])
    statico += L.stanza('corridoio_lavapiedi', CX0, CY0, CX1, CY1, CH, mc,
                        {'S': [(CX0 - 0.2, CX1 + 0.2, 0, CH)], 'E': [(15.2, 16.8, 0.95, 2.0)], 'N': [(UX0, UX1, 0, UH)]}, pavimento=False, zoccolo=1.2)
    VY0, VY1, VZ = 12.4, 14.4, -0.2
    L.raccogli(True)
    statico.append(L.scatola('pav_lavapiedi_a', (CX0 - 0.2, CY0, -0.2), (CX1 + 0.2, VY0, 0), M['piastrelle_pavimento']))
    statico.append(L.scatola('pav_lavapiedi_b', (CX0 - 0.2, VY1, -0.2), (CX1 + 0.2, CY1 + 0.2, 0), M['piastrelle_pavimento']))
    statico.append(L.scatola('vasca_lavapiedi_fondo', (CX0, VY0, VZ - 0.2), (CX1, VY1, VZ), M['piastrelle_verdi']))
    statico.append(L.scatola('vasca_lavapiedi_bordo', (CX0, VY0 - 0.06, -0.03), (CX1, VY0, 0.02), M['piastrelle_doccia']))
    statico.append(L.scatola('vasca_lavapiedi_bordo', (CX0, VY1, -0.03), (CX1, VY1 + 0.06, 0.02), M['piastrelle_doccia']))
    L.raccogli(False)
    acqua_lp = L.scatola('acqua_lavapiedi', (CX0, VY0, VZ), (CX1, VY1, -0.05), M['acqua'], uv=False)
    L.uv_scatola(acqua_lp, 1.0); acqua_lp.visible_shadow = False
    L.vuoto('marker_acqua_lavapiedi_livello', (9.7, 13.4, -0.05), dim=0.3)
    # docce lava-piedi sopra la vasca e corrimano
    statico.append(L.tubo_percorso('tubo_lavapiedi', [(CX0, 13.4, 2.3), (CX1, 13.4, 2.3)], 0.025, M['cromo'], flange=False))
    for k, x in enumerate((9.2, 10.2)):
        statico.append(L.cilindro('ugello_lavapiedi', (x, 13.4, 2.28), (x, 13.4, 2.2), 0.02, M['cromo']))
        L.vuoto(f'emit_lavapiedi_{k + 1}', (x, 13.4, 2.2), dim=0.2)
    for xx in (CX0 + 0.06, CX1 - 0.06):
        statico.append(L.tubo_percorso('corrimano_lavapiedi', [(xx, 11.8, 0.95), (xx, 15.0, 0.95)], 0.02, M['cromo'], flange=False))

    # tornello a tutta altezza (rotore separato, perno verticale) e grate fisse ai lati
    TY = 16.4; TX = 9.5; TR = 0.6
    rot = []
    rot.append(L.cilindro('tornello_rotore', (TX, TY, 0.0), (TX, TY, 2.25), 0.05, M['cromo']))
    for k in range(3):
        a = R(120 * k + 30)
        for z in [0.25 + 0.16 * j for j in range(12)]:
            rot.append(L.cilindro('tornello_rotore', (TX, TY, z), (TX + TR * math.cos(a), TY + TR * math.sin(a), z), 0.018, M['cromo'], seg=8))
    rotore = L.unisci('tornello_rotore', rot); L.origine(rotore, (TX, TY, 0))
    L.col_scatola((CX0, TY - 0.05, 0), (CX0 + 0.3, TY + 0.05, 2.7)); L.col_scatola((CX1 - 0.68, TY - 0.05, 0), (CX1, TY + 0.05, 2.7))
    L.col_scatola((CX0, TY - 0.05, 2.25), (CX1, TY + 0.05, 2.7))
    fisso = [L.scatola('tornello_fisso', (CX0, TY - 0.05, 2.25), (CX1, TY + 0.05, 2.35), M['metallo_grezzo']),
             L.scatola('tornello_fisso', (CX0, TY - 0.05, 0.0), (CX0 + 0.3, TY + 0.05, 2.25), M['metallo_grezzo']),
             L.scatola('tornello_fisso', (CX1 - 0.68, TY - 0.05, 0.0), (CX1, TY + 0.05, 0.08), M['metallo_grezzo'])]
    for x in [CX1 - 0.66 + 0.12 * j for j in range(6)]:
        fisso.append(L.cilindro('tornello_fisso', (x, TY, 0.08), (x, TY, 2.25), 0.015, M['cromo'], seg=8))
    statico.append(L.unisci('tornello_fisso', fisso))
    L.vuoto('marker_tornello_perno', (TX, TY, 0), dim=0.3)

    # gabbiotto con il vetro rotto e il pulsante del tornello (fuori portata)
    GX0, GX1, GY0, GY1 = 11.0, 13.2, 14.6, 17.4
    statico += L.stanza('gabbiotto', GX0, GY0, GX1, GY1, CH, dict(pav=M['piastrelle_pavimento'], sof=M['soffitto_lamiera'], muro=M['lamiera_crema'], muro_basso=M['lamiera_petrolio']),
                        {'W': [(GY0 - 0.2, GY1 + 0.2, 0, CH)]})
    # il vano del vetro rotto: blocca il giocatore ma non il getto (vedi INTEGRAZIONE.md)
    vb = L.scatola('vetro_rotto_blocco-colonly', (10.85, 15.2, 0.95), (10.95, 16.8, 2.0), None, uv=False)
    vb.hide_render = True; vb.display_type = 'WIRE'
    statico.append(L.scatola('davanzale_gabbiotto', (10.7, 15.15, 0.9), (11.25, 16.85, 0.95), M['metallo_grezzo']))
    # vetro con un buco frastagliato al centro (anello tra il telaio e il bordo del buco)
    import bmesh
    bm = bmesh.new(); xg = 10.9
    rnd = random.Random(4)
    cen = (16.05, 1.42); NB = 48
    def bordo_telaio(t):
        # punto sul perimetro del telaio (y 15.2..16.8, z 0.95..2.0) all'angolo t
        dy, dz = math.cos(t), math.sin(t)
        k = min(0.8 / abs(dy) if abs(dy) > 1e-6 else 9, 0.525 / abs(dz) if abs(dz) > 1e-6 else 9)
        return (16.0 + dy * k, 1.475 + dz * k)
    est, inn = [], []
    for i in range(NB):
        t = 2 * math.pi * i / NB
        est.append(bm.verts.new((xg, *bordo_telaio(t))))
        r = (0.33 if i % 2 else 0.22) * rnd.uniform(0.6, 1.5)
        inn.append(bm.verts.new((xg, cen[0] + math.cos(t) * r * 1.3, cen[1] + math.sin(t) * r)))
    for i in range(NB):
        j = (i + 1) % NB
        bm.faces.new((est[i], est[j], inn[j], inn[i]))
    vetro = L._ob_da_bm('vetro_rotto', bm, M['vetro_sporco']); L.uv_scatola(vetro, 1.0)
    sch = []
    for k in range(14):
        x = rnd.uniform(9.6, 10.7) if k < 8 else rnd.uniform(11.1, 12.2); y = rnd.uniform(15.0, 17.0)
        o = L.piano('schegge_vetro', (x, y, 0.003 if x < 10.8 else 0.003), rnd.uniform(0.04, 0.12), rnd.uniform(0.03, 0.08), M['vetro_sporco'], rot=(0, 0, rnd.uniform(0, 3)))
        sch.append(o)
    L.unisci('schegge_vetro', sch)
    statico.append(L.scatola('banco_gabbiotto', (12.4, 14.7, 0), (13.2, 17.3, 0.8), M['porta_lamiera']))
    L.col_scatola((12.4, 14.7, 0), (13.2, 17.3, 0.8))
    statico.append(L.scatola('quadro_pulsante', (13.17, 15.75, 1.05), (13.2, 16.25, 1.55), M['vernice_gialla']))
    pul = [L.cilindro('pulsante_tornello', (13.17, 16.0, 1.3), (13.08, 16.0, 1.3), 0.06, M['pulsante'], seg=20),
           L.cilindro('pulsante_tornello', (13.17, 16.0, 1.3), (13.13, 16.0, 1.3), 0.085, M['metallo_grezzo'], seg=20)]
    pulsante = L.unisci('pulsante_tornello', pul); L.origine(pulsante, (13.17, 16.0, 1.3))
    L.luce_punto('luce_pulsante_tornello', (12.95, 16.0, 1.35), (1.0, 0.15, 0.08), 6, 0.03)
    statico.append(L.scatola('spia_tornello', (13.17, 16.15, 1.45), (13.15, 16.2, 1.5), M['pulsante_verde']))
    prop('radio_gabbiotto', 'radio', (12.8, 15.2, 0.8), 100, 0.3)

    # saracinesca (si alza) nell'uscita verso la sala principale, con la turbina sulla parete ovest
    SY = CY1 + 0.1
    sar = []
    z = 0.0
    while z < UH - 0.01:
        sar.append(L.scatola('saracinesca', (UX0, SY - 0.03, z), (UX1, SY + 0.03, min(z + 0.075, UH)), M['porta_lamiera']))
        sar.append(L.scatola('saracinesca', (UX0, SY - 0.04, z + 0.03), (UX1, SY - 0.03, z + 0.045), M['nero'], uv=False))
        z += 0.08
    sar.append(L.scatola('saracinesca', (UX0, SY - 0.05, 0), (UX1, SY + 0.05, 0.08), M['vernice_gialla']))
    saracinesca = L.unisci('saracinesca', sar); L.ammacca(saracinesca, 0.008, 1.5, 2.0, 2)
    L.origine(saracinesca, ((UX0 + UX1) / 2, SY, 0))     # come PoweredDoor: in basso al centro del vano
    statico.append(L.scatola('cassonetto_saracinesca', (UX0 - 0.1, SY - 0.35, UH), (UX1 + 0.1, SY + 0.05, UH + 0.4), M['metallo_grezzo']))
    for x in (UX0 - 0.06, UX1):
        statico.append(L.scatola('guida_saracinesca', (x, SY - 0.06, 0), (x + 0.06, SY + 0.06, UH), M['metallo_grezzo']))
    statico.append(cornice_porta('telaio_uscita', 'N', UX0, UX1, UH, CY1, M, M['vernice_gialla'], entrambi=True))
    L.vuoto('marker_uscita_sala_principale', ((UX0 + UX1) / 2, CY1 + 0.2, 0), (0, 0, 0), 'SINGLE_ARROW', 0.5)
    # turbina: carcassa sulla parete, ruota a pale separata (asse lungo x), ingranaggio e catena verso il cassonetto
    TBy, TBz = 19.4, 2.05
    statico.append(L.cilindro('turbina_carcassa', (CX0, TBy, TBz), (CX0 + 0.08, TBy, TBz), 0.3, M['metallo_grezzo'], seg=28))
    statico.append(L.cilindro('turbina_mozzo', (CX0, TBy, TBz), (CX0 + 0.2, TBy, TBz), 0.05, M['ruggine']))
    pale = [L.cilindro('turbina', (CX0 + 0.12, TBy, TBz), (CX0 + 0.26, TBy, TBz), 0.07, M['vernice_gialla'], seg=16)]
    for k in range(8):
        a = R(45 * k)
        c = Vector((0, math.cos(a), math.sin(a)))
        p = L.scatola('turbina', (CX0 + 0.12, -0.02, 0.05), (CX0 + 0.26, 0.02, 0.24), M['vernice_rossa'] if k % 2 else M['vernice_gialla'], uv=False)
        p.matrix_world = Matrix.Translation((0, TBy, TBz)) @ Matrix.Rotation(a, 4, 'X')
        pale.append(p)
    turb = L.unisci('turbina_saracinesca', pale); L.uv_scatola(turb, 0.5)
    L.origine(turb, (CX0 + 0.19, TBy, TBz))
    statico.append(L.tubo_percorso('catena_turbina', [(CX0 + 0.05, TBy, TBz + 0.3), (CX0 + 0.05, TBy, 2.45), (CX0 + 0.05, SY - 0.2, 2.45), (UX0 - 0.1, SY - 0.2, 2.45)], 0.03, M['metallo_grezzo'], flange=False))

    # ---- luci
    for i, (p, n) in enumerate([((6.8, 3.02, 2.45), (0, 1, 0)), ((3.02, 7.0, 2.4), (1, 0, 0)), ((5.6, 14.58, 2.55), (0, -1, 0)),
                                ((10.78, 18.2, 2.3), (-1, 0, 0)), ((9.7, 11.22, 2.5), (0, 1, 0)), ((13.18, 16.0, 2.3), (-1, 0, 0))]):
        L.lampada_emergenza(f'luce_emergenza_spogliatoi_{i + 1:02d}', p, n, M, watt=40)
    for i, (x, y, stato, rz) in enumerate([(7.0, 5.0, 'sfarfalla', 90), (7.0, 8.8, 'spento', 90), (5.6, 12.6, 'spento', 0), (9.7, 17.5, 'spento', 90)]):
        L.neon_soffitto(f'neon_spogliatoi_{i + 1}', (x, y, 0), 1.2, M, H if y < 15 else CH, stato, watt=90, rot_z=R(rz))

    # ---- oggetti dimenticati (ciabatte, braccioli, asciugamani) e acqua
    random.seed(3)
    cia = prop('ciabatta', 'ciabatta', (6.1, 6.2, 0), 30, 0.27)
    for k, (x, y, rz) in enumerate([(6.35, 6.0, 10), (8.1, 8.9, 200), (5.2, 12.2, 130), (8.3, 9.2, 170), (9.9, 15.3, 60)]):
        copia(cia, f'ciabatta_{k + 2}', (x, y, 0), rz)
    br = prop('braccioli', 'braccioli', (4.65, 7.2, 0.45), 20, 0.3)
    copia(br, 'braccioli_2', (7.6, 9.9, 0), 110)
    prop('asciugamano', 'asciugamano', (9.35, 5.2, 0.45), 90, 0.9)
    prop('asciugamano_2', 'asciugamano', (6.4, 4.3, 0), 20, 0.8)
    prop('paperella_spogliatoi', 'paperella', (7.9, 13.3, 0), 200, 0.09)
    prop('secchio_mocio', 'secchio_mocio', (7.6, 11.6, 0), 210, 0.95, 'z')
    prop('pallone_spogliatoi', 'pallone', (10.2, 10.2, 0), 0, 0.4)
    prop('cestino_spogliatoi', 'cestino', (3.5, 10.6, 0), 0, 0.5, 'z')
    pz = [pozza('pozza_spogliatoi_1', (6.8, 9.2, 0), 1.2, 0.8, M, 11), pozza('pozza_spogliatoi_2', (5.5, 13.0, 0), 1.8, 1.0, M, 12),
          pozza('pozza_spogliatoi_3', (7.4, 5.4, 0), 0.6, 0.4, M, 13), pozza('pozza_spogliatoi_4', (9.7, 15.8, 0), 0.8, 0.6, M, 14)]
    L.unisci('acqua_pozze_spogliatoi', pz)
    L.unisci('spogliatoi_statico', statico)
    L.crea_collisione('spogliatoi', 'spogliatoi')


# =====================================================================================
# 3. STANZINO DEI BAGNINI   x 11.2..15.2, y 6.2..10.6, h 2.6
# =====================================================================================
def stanzino(M):
    L.usa_collezione('stanzino')
    X0, X1, Y0, Y1, H = 11.2, 15.2, 6.2, 10.6, 2.6
    mats = dict(pav=M['piastrelle_pavimento'], sof=M['soffitto_lamiera'], muro=M['lamiera_crema'], muro_basso=M['lamiera_petrolio'])
    statico = L.stanza('stanzino', X0, Y0, X1, Y1, H, mats, {'W': [(Y0 - 0.2, Y1 + 0.2, 0, H)]}, zoccolo=1.0)
    # porta (aperta verso l'interno, cardine sul lato nord del vano)
    pt = [L.scatola('porta_stanzino', (11.02, 8.02, 0.01), (11.07, 8.88, 2.03), M['porta_lamiera'])]
    pt.append(L.cilindro('porta_stanzino', (11.07, 8.1, 1.0), (11.14, 8.1, 1.0), 0.02, M['cromo']))
    pt.append(L.scatola('porta_stanzino', (11.0, 8.3, 1.35), (11.09, 8.6, 1.75), M['metallo_grezzo']))
    porta = L.unisci('porta_stanzino', pt); L.ammacca(porta, 0.004, 2.0, 12.0, 3)
    L.origine(porta, (11.05, 8.88, 0)); porta.rotation_euler = (0, 0, R(-75))
    # costole
    for y in (7.4, 9.4):
        statico.append(L.scatola('costola', (X1 - 0.07, y - 0.06, 0), (X1, y + 0.06, H), M['lamiera_crema']))
    statico.append(L.tubo_percorso('tubo_stanzino', [(X0, 10.35, 2.35), (13.4, 10.35, 2.35), (13.4, 10.35, 2.6)], 0.06, M['ruggine']))
    statico.append(L.tubo_percorso('tubo_stanzino_2', [(X0, 6.45, 2.4), (X1, 6.45, 2.4)], 0.04, M['vernice_rossa'], flange=False))

    # ---- parete nord: rastrelliera di ganci con i fischietti, radiatore, pronto soccorso
    statico.append(L.scatola('portaganci', (11.6, Y1 - 0.04, 1.62), (13.1, Y1, 1.74), M['legno_panca']))
    fis = None
    for k, x in enumerate([11.8, 12.1, 12.4, 12.7, 13.0]):
        statico.append(L.tubo_percorso('gancio', [(x, Y1 - 0.04, 1.68), (x, Y1 - 0.11, 1.68), (x, Y1 - 0.11, 1.72)], 0.008, M['metallo_grezzo'], flange=False))
        if k in (0, 1, 3, 4):
            statico.append(L.cilindro('cordino', (x, Y1 - 0.1, 1.67), (x, Y1 - 0.1, 1.35 - 0.04 * k), 0.003, M['vernice_rossa'] if k % 2 else M['gomma'], seg=5))
            if fis is None:
                fis = prop('fischietto_1', 'fischietto', (x, Y1 - 0.1, 1.3 - 0.04 * k - 0.05), 0, 0.07)
            else:
                copia(fis, f'fischietto_{k + 1}', (x, Y1 - 0.1, 1.3 - 0.04 * k - 0.05), random.uniform(-30, 30))
    rad = [L.scatola('radiatore', (11.7, Y1 - 0.12, 0.15), (13.1, Y1 - 0.1, 0.17), M['metallo_grezzo'])]
    x = 11.72
    while x < 13.1:
        rad.append(L.scatola('radiatore', (x, Y1 - 0.14, 0.12), (x + 0.04, Y1 - 0.05, 0.75), M['metallo_grezzo']))
        x += 0.07
    statico.append(L.unisci('radiatore', rad))
    prop('cassetta_pronto_soccorso', 'cassetta_pronto_soccorso', (14.1, Y1 - 0.15, 1.05), 180, 0.6, 'z')
    L.toro('salvagente_parete', Vector((13.6, Y1 - 0.08, 1.75)), 0.27, 0.075, M['salvagente'], rot=(R(90), 0, 0))

    # ---- parete est: rastrelliera dello zaino-pompa (posto libero al centro) e salvagenti
    RX = X1 - 0.04
    ras = []
    for y in (7.0, 8.4, 9.8):
        ras.append(L.scatola('rastrelliera', (RX - 0.05, y - 0.03, 0.0), (RX, y + 0.03, 2.0), M['vernice_gialla']))
    for z in (0.35, 1.25, 1.95):
        ras.append(L.cilindro('rastrelliera', (RX - 0.05, 6.95, z), (RX - 0.05, 9.85, z), 0.025, M['vernice_gialla'], seg=10))
    ras.append(L.scatola('rastrelliera_ripiano', (RX - 0.45, 6.95, 1.95), (RX, 9.85, 1.98), M['lamiera_grata']))
    for y in (7.4, 8.1, 8.75, 9.4):
        ras.append(L.tubo_percorso('rastrelliera_gancio', [(RX - 0.05, y, 1.25), (RX - 0.22, y, 1.25), (RX - 0.22, y, 1.32)], 0.012, M['metallo_grezzo'], flange=False))
    statico.append(L.unisci('rastrelliera_zaino', ras))
    L.col_scatola((RX - 0.45, 6.95, 0), (RX, 9.85, 2.0))
    # posto dello zaino: due ganci centrali (y 8.1 e 8.75) liberi; lo zaino va appeso qui, schiena verso il muro
    L.vuoto('marker_zaino_pompa', (RX - 0.22, 8.425, 1.25), (0, 0, R(90)), 'ARROWS', 0.4)
    for k, y in enumerate((7.4, 9.4)):
        s = L.toro(f'salvagente_rastrelliera_{k + 1}', Vector((RX - 0.16, y, 0.98)), 0.28, 0.08, M['salvagente'], rot=(R(90), R(8 * (k * 2 - 1)), R(90)))
    sal_ripiano = L.toro('salvagente_ripiano', Vector((RX - 0.25, 7.6, 2.06)), 0.27, 0.075, M['salvagente'], rot=(0, R(4), 0))
    prop('braccioli_stanzino', 'braccioli', (RX - 0.25, 9.3, 1.98), 70, 0.3)

    # ---- parete sud: bacheca di sughero con cartello, poster e foglietti; scrivania con radio; sedia
    BY = Y0 + 0.03
    statico.append(L.scatola('bacheca', (11.9, Y0, 1.15), (13.5, BY, 2.05), M['sughero']))
    cor = []
    for (a, b) in [((11.86, 1.11), (13.54, 1.15)), ((11.86, 2.05), (13.54, 2.09)), ((11.86, 1.15), (11.9, 2.05)), ((13.5, 1.15), (13.54, 2.05))]:
        cor.append(L.scatola('bacheca_cornice', (a[0], Y0, a[1]), (b[0], BY + 0.012, b[1]), M['legno_panca']))
    statico.append(L.unisci('bacheca_cornice', cor))
    statico.append(L.piano('bacheca_cartello_regole', (12.25, BY + 0.003, 1.62), 0.42, 0.56, M['cartello_regole'], rot=(R(90), 0, 0)))
    statico.append(L.piano('bacheca_poster_bagnino', (13.05, BY + 0.003, 1.6), 0.5, 0.67, M['poster_bagnino'], rot=(R(90), 0, R(2))))
    fog = []
    rnd = random.Random(8)
    for k in range(7):
        x = rnd.uniform(11.98, 13.45); z = rnd.uniform(1.2, 2.0)
        if 12.0 < x < 12.5 and 1.3 < z < 1.95:
            continue
        fog.append(L.piano('foglietti', (x, BY + 0.005 + k * 0.0004, z), rnd.choice([0.1, 0.09, 0.15]), rnd.choice([0.11, 0.14, 0.2]), M['carta'] if k % 3 else M['polaroid'], rot=(R(90), R(rnd.uniform(-8, 8)), 0)))
    if fog:
        statico.append(L.unisci('bacheca_foglietti', fog))
    L.vuoto('marker_polaroid_P3', (12.65, BY + 0.01, 1.3), (R(90), 0, 0), 'CUBE', 0.05)
    statico.append(L.scatola('scrivania', (11.8, Y0, 0.74), (13.2, Y0 + 0.6, 0.78), M['legno_panca']))
    L.col_scatola((11.8, Y0, 0), (13.2, Y0 + 0.6, 0.78))
    for (x, y) in [(11.85, Y0 + 0.05), (13.15, Y0 + 0.05), (11.85, Y0 + 0.55), (13.15, Y0 + 0.55)]:
        statico.append(L.scatola('scrivania', (x - 0.025, y - 0.025, 0), (x + 0.025, y + 0.025, 0.74), M['metallo_grezzo']))
    prop('radio', 'radio', (12.95, Y0 + 0.3, 0.78), 190, 0.32)
    prop('ricetrasmittente', 'radio_ricetrasmittente', (12.35, Y0 + 0.35, 0.78), 0, 0.2, rot=(R(90), 0, 0))
    prop('sedia', 'sedia', (12.4, Y0 + 1.05, 0), 160, 0.88, 'z')
    prop('estintore_stanzino', 'estintore', (14.6, Y0 + 0.12, 0.85), 0, 0.55, 'z')
    prop('ciabatta_stanzino', 'ciabatta', (14.2, 9.5, 0), 250, 0.27)
    statico.append(L.piano('poster_bagnino_parete', (14.4, Y0 + 0.012, 1.55), 0.75, 1.0, M['poster_bagnino'], rot=(R(90), 0, 0)))

    # ---- luci
    L.lampada_emergenza('luce_emergenza_stanzino_01', (11.22, 9.6, 2.3), (1, 0, 0), M, watt=30)
    L.lampada_emergenza('luce_emergenza_stanzino_02', (15.18, 7.6, 2.3), (-1, 0, 0), M, watt=22)
    L.neon_soffitto('neon_stanzino', (13.2, 8.4, 0), 1.2, M, H, 'sfarfalla', watt=60, rot_z=R(90))
    pozza('acqua_pozza_stanzino', (12.0, 8.6, 0), 0.6, 0.45, M, 21)
    L.unisci('stanzino_statico', statico)
    L.crea_collisione('stanzino', 'stanzino')


def costruisci():
    L.reset()
    M = materiali()
    corridoio(M)
    spogliatoi(M)
    stanzino(M)
    return M


if __name__ == '__main__':
    costruisci()
    out = os.path.join(AI, 'ambienti1.blend')
    bpy.ops.wm.save_as_mainfile(filepath=out)
    print('salvato', out)
    if '--no-export' not in sys.argv:
        os.makedirs(os.path.join(AI, 'gltf'), exist_ok=True)
        for c in ('corridoio', 'spogliatoi', 'stanzino'):
            L.esporta_glb(os.path.join(AI, 'gltf', f'{c}.gltf'), [c])
