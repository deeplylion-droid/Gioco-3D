"""Kit modulare dell'acquapark (capitolo 1): genera i pezzi in Blender, applica i materiali
PBR (texture CC0 in assets_src/ambiente/textures) ed esporta un GLB per pezzo.

Uso (dalla radice del repository):
  PY=/home/user/tools/blender-venv/bin/python
  $PY tools/blender/ambiente_kit.py --palette p1_bianco_turchese              # tutti i pezzi
  $PY tools/blender/ambiente_kit.py --palette p2_blu_giallo --pezzi parete_2x3_oblo,oblo_60
  opzioni: --texture incorporate|nessuna  --uscita <cartella>  --elenco

Regole (vedi assets_src/ambiente/KIT.md): metri, Z in alto in Blender (Y in alto nel GLB),
pivot dei moduli nell'angolo in basso a sinistra sul fronte, oggetti di scena con pivot alla base,
UV in scala reale (1 unità UV = lato della texture del materiale), collisioni come oggetti
'<pezzo>-colonly' (trimesh) o '<pezzo>-convcolonly' (convessi) che Godot converte da solo.
"""
import math, os, sys
import bpy, bmesh
from mathutils import Vector, Matrix

QUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, QUI)
from ambiente_palette import PALETTE, COMUNI, hex_rgb  # noqa: E402
from ambiente_texture import CATALOGO  # noqa: E402

RADICE = os.path.abspath(os.path.join(QUI, '..', '..'))
TEX = os.path.join(RADICE, 'assets_src', 'ambiente', 'textures')

# ----------------------------------------------------------------------------- misure (metri)
MODULO = 2.0            # lato dei moduli principali
PASSO = 0.5             # griglia di posa
ALTEZZA_PIANO = 3.0     # altezza di un modulo di parete (un ponte)
SPESSORE_PARETE = 0.2
# fasce della parete piastrellata (z in metri): ogni limite è multiplo di 12,5 cm e di 5 cm
FASCE_PARETE = [(0.0, 0.25, 'zoccolo'), (0.25, 0.75, 'parete'), (0.75, 1.0, 'fascia'),
                (1.0, 2.0, 'parete'), (2.0, 3.0, 'intonaco')]
OBLO_Z = 1.5            # centro dell'oblò nella parete
OBLO_R_LUCE = 0.30      # luce netta Ø 60 cm
OBLO_R_FORO = 0.33      # foro nella parete (manicotto)
OBLO_R_FLANGIA = 0.42   # flangia Ø 84 cm
VASCA_PROF = 1.2        # profondità della vasca standard
BORDO_GRIGLIA = 0.25    # larghezza del canale con griglia
BORDO_COPERTINA = 0.25  # larghezza della copertina (bordo in ceramica)
RINGHIERA_H = 1.05      # corrimano (SOLAS chiede almeno 1,0 m)
SCIVOLO_R = 0.5         # tubo dello scivolo: Ø interno 1,0 m
SCIVOLO_SPESSORE = 0.012


# materiali RGBA: sorgente CC0 per rugosità/metallo e lato reale della texture (metri)
ALFA_SORGENTI = {'grata': 'metallo_verniciato'}
ALFA_LATI = {'grata': 0.5, 'rosa_venti': 1.0, 'colatura': 1.0, 'impronte': 1.0}


def lato(nome_materiale_cc0):
    return CATALOGO[nome_materiale_cc0]['lato']


# ----------------------------------------------------------------------------- materiali

def _sock(socks, ident):
    for x in socks:
        if x.identifier == ident:
            return x
    raise KeyError(ident)


def nodo_mix(nt, tipo, blend='MIX', loc=(0, 0)):
    """Nodo Mix con le prese giuste: tipo 'RGBA' o 'FLOAT'. Ritorna (nodo, A, B, risultato)."""
    n = nt.nodes.new('ShaderNodeMix'); n.data_type = tipo; n.location = loc
    if tipo == 'RGBA':
        n.blend_type = blend
        return n, _sock(n.inputs, 'A_Color'), _sock(n.inputs, 'B_Color'), _sock(n.outputs, 'Result_Color')
    return n, _sock(n.inputs, 'A_Float'), _sock(n.inputs, 'B_Float'), _sock(n.outputs, 'Result_Float')


class Materiali:
    """Crea (una volta sola) i materiali M_amb_* per una palette.
    per_render=True aggiunge effetti solo per le anteprime (pozzanghere in spazio mondo)."""

    def __init__(self, palette, per_render=False):
        self.palette = palette
        self.pal = PALETTE[palette]
        self.per_render = per_render
        self.cache = {}
        self.lati = {}

    # file delle mappe per un materiale logico della palette
    def _mappe(self, nome):
        ricette = dict(COMUNI)
        ricette.update(self.pal['materiali'])
        r = ricette[nome]
        src = r['sorgente']
        cc0 = os.path.join(TEX, 'cc0', src)
        der = os.path.join(TEX, 'derivate', self.palette)
        col = os.path.join(cc0, f'{src}_col.jpg') if r['ricetta'] == 'originale' else os.path.join(der, f'{nome}_col.jpg')
        orm = os.path.join(der, f'{nome}_orm.jpg')
        if not os.path.exists(orm):
            orm = os.path.join(cc0, f'{src}_orm.jpg')
        return col, os.path.join(cc0, f'{src}_nrm.jpg'), orm, lato(src)

    def _img(self, path, colore):
        im = bpy.data.images.load(path, check_existing=True)
        im.colorspace_settings.name = 'sRGB' if colore else 'Non-Color'
        return im

    def get(self, nome):
        if nome in self.cache:
            return self.cache[nome]
        speciali = {'vetro': self._vetro, 'neon': self._neon, 'neon_spento': self._neon_spento,
                    'luce_rossa': self._luce_rossa, 'nero': self._nero, 'gomma': self._gomma,
                    'cartellone': self._cartellone, 'vetro_cupola': self._vetro_cupola,
                    'lampadina': lambda: self._emissivo('lampadina', (1.0, 0.72, 0.42), 35.0)}
        if nome in speciali:
            m = speciali[nome]()
        elif nome.startswith('cartellone_'):
            m = self._cartellone(nome.split('_', 1)[1])
        elif nome.startswith('alfa_'):
            m = self._alfa(nome)
        else:
            m = self._pbr(nome)
        self.cache[nome] = m
        return m

    def lato(self, nome):
        self.get(nome)
        return self.lati.get(nome, 1.0)

    def _base(self, nome):
        m = bpy.data.materials.new('M_amb_' + nome)
        m.use_nodes = True
        nt = m.node_tree
        bsdf = nt.nodes['Principled BSDF']
        return m, nt, bsdf

    def _gltf_occlusione(self, nt, sock):
        """Nodo 'glTF Material Output' con l'occlusione: l'esportatore glTF lo riconosce."""
        g = bpy.data.node_groups.get('glTF Material Output')
        if g is None:
            g = bpy.data.node_groups.new('glTF Material Output', 'ShaderNodeTree')
            g.interface.new_socket('Occlusion', in_out='INPUT', socket_type='NodeSocketFloat')
            g.interface.new_socket('Thickness', in_out='INPUT', socket_type='NodeSocketFloat')
        n = nt.nodes.new('ShaderNodeGroup'); n.node_tree = g; n.location = (300, -500)
        nt.links.new(sock, n.inputs['Occlusion'])

    def _pbr(self, nome):
        col, nrm, orm, lt = self._mappe(nome)
        self.lati[nome] = lt
        m, nt, bsdf = self._base(nome)
        L = nt.links
        uv = nt.nodes.new('ShaderNodeUVMap'); uv.uv_map = 'UVMap'; uv.location = (-1100, 0)
        tc = nt.nodes.new('ShaderNodeTexImage'); tc.image = self._img(col, True); tc.location = (-800, 300)
        to = nt.nodes.new('ShaderNodeTexImage'); to.image = self._img(orm, False); to.location = (-800, 0)
        tn = nt.nodes.new('ShaderNodeTexImage'); tn.image = self._img(nrm, False); tn.location = (-800, -300)
        for t in (tc, to, tn):
            L.new(uv.outputs['UV'], t.inputs['Vector'])
        sep = nt.nodes.new('ShaderNodeSeparateColor'); sep.location = (-500, 0)
        L.new(to.outputs['Color'], sep.inputs['Color'])
        nm = nt.nodes.new('ShaderNodeNormalMap'); nm.location = (-500, -300)
        L.new(tn.outputs['Color'], nm.inputs['Color'])
        L.new(nm.outputs['Normal'], bsdf.inputs['Normal'])
        L.new(sep.outputs['Blue'], bsdf.inputs['Metallic'])
        self._gltf_occlusione(nt, sep.outputs['Red'])
        # colore x colore dei vertici (sporco): in glTF è COLOR_0, che moltiplica il colore base
        va = nt.nodes.new('ShaderNodeVertexColor'); va.layer_name = 'Col'; va.location = (-800, 550)
        mix, A, B, R = nodo_mix(nt, 'RGBA', 'MULTIPLY', (-400, 400))
        mix.inputs['Factor'].default_value = 1.0
        L.new(tc.outputs['Color'], A)
        L.new(va.outputs['Color'], B)
        base = R
        rough = sep.outputs['Green']
        if self.per_render and nome in ('pavimento', 'bordo'):
            base, rough = self._pozzanghere(nt, base, rough)
        L.new(base, bsdf.inputs['Base Color'])
        L.new(rough, bsdf.inputs['Roughness'])
        return m

    def _pozzanghere(self, nt, base, rough):
        """Solo anteprima: pozzanghere con una maschera in spazio mondo (in Godot: decal o shader)."""
        L = nt.links
        tc = nt.nodes.new('ShaderNodeTexCoord'); tc.location = (-1300, -700)
        no = nt.nodes.new('ShaderNodeTexNoise'); no.location = (-1100, -700)
        no.inputs['Scale'].default_value = 0.55; no.inputs['Detail'].default_value = 4.0
        no.inputs['Roughness'].default_value = 0.55
        L.new(tc.outputs['Object'], no.inputs['Vector'])
        cr = nt.nodes.new('ShaderNodeValToRGB'); cr.location = (-900, -700)
        cr.color_ramp.elements[0].position = 0.50; cr.color_ramp.elements[1].position = 0.56
        L.new(no.outputs['Fac'], cr.inputs['Fac'])
        mr, rA, rB, rR = nodo_mix(nt, 'FLOAT', loc=(-300, -500))
        L.new(cr.outputs['Color'], mr.inputs['Factor'])
        L.new(rough, rA); rB.default_value = 0.02
        mc, cA, cB, cR = nodo_mix(nt, 'RGBA', 'MULTIPLY', (-200, 300))
        L.new(cr.outputs['Color'], mc.inputs['Factor'])
        L.new(base, cA); cB.default_value = (0.72, 0.74, 0.77, 1)
        return cR, rR

    def _vetro(self):
        m, nt, bsdf = self._base('vetro')
        if not self.per_render:   # nel gioco: vetro semplice, senza mappe (il vetro vero lo fa Godot)
            bsdf.inputs['Base Color'].default_value = (0.06, 0.08, 0.09, 1)
            bsdf.inputs['Roughness'].default_value = 0.15
            bsdf.inputs['Alpha'].default_value = 0.3
            if hasattr(m, 'surface_render_method'):
                m.surface_render_method = 'BLENDED'
            self.lati['vetro'] = 1.0
            return m
        src = 'macchie_acqua'
        tex = nt.nodes.new('ShaderNodeTexImage')
        tex.image = self._img(os.path.join(TEX, 'cc0', src, f'{src}_col.jpg'), False)
        cr = nt.nodes.new('ShaderNodeMapRange')
        cr.inputs['To Min'].default_value = 0.05; cr.inputs['To Max'].default_value = 0.45
        nt.links.new(tex.outputs['Color'], cr.inputs['Value'])
        nt.links.new(cr.outputs['Result'], bsdf.inputs['Roughness'])
        bsdf.inputs['Base Color'].default_value = (0.06, 0.08, 0.09, 1)
        bsdf.inputs['Alpha'].default_value = 0.3
        if hasattr(m, 'surface_render_method'):
            m.surface_render_method = 'BLENDED'

        self.lati['vetro'] = 1.0
        return m

    def _vetro_cupola(self):
        """Vetro della cupola: sottile, sporco a chiazze (macchie CC0), lascia passare la luna."""
        m, nt, bsdf = self._base('vetro_cupola')
        if not self.per_render:
            bsdf.inputs['Base Color'].default_value = (0.08, 0.1, 0.11, 1)
            bsdf.inputs['Roughness'].default_value = 0.08
            bsdf.inputs['Alpha'].default_value = 0.2
            if hasattr(m, 'surface_render_method'):
                m.surface_render_method = 'BLENDED'
            self.lati['vetro_cupola'] = 1.0
            return m
        src = 'macchie_acqua'
        tex = nt.nodes.new('ShaderNodeTexImage')
        tex.image = self._img(os.path.join(TEX, 'cc0', src, f'{src}_col.jpg'), False)
        mr = nt.nodes.new('ShaderNodeMapRange')
        mr.inputs['To Min'].default_value = 0.08; mr.inputs['To Max'].default_value = 0.35
        nt.links.new(tex.outputs['Color'], mr.inputs['Value'])
        nt.links.new(mr.outputs['Result'], bsdf.inputs['Alpha'])
        bsdf.inputs['Base Color'].default_value = (0.08, 0.1, 0.11, 1)
        bsdf.inputs['Roughness'].default_value = 0.08
        if hasattr(m, 'surface_render_method'):
            m.surface_render_method = 'BLENDED'
        self.lati['vetro_cupola'] = 1.0
        return m

    def _emissivo(self, nome, colore, forza):
        m, nt, bsdf = self._base(nome)
        bsdf.inputs['Base Color'].default_value = (*colore, 1)
        bsdf.inputs['Emission Color'].default_value = (*colore, 1)
        bsdf.inputs['Emission Strength'].default_value = forza
        bsdf.inputs['Roughness'].default_value = 0.3
        self.lati[nome] = 1.0
        return m

    def _neon(self):
        return self._emissivo('neon', (0.82, 1.0, 0.93), 28.0)

    def _neon_spento(self):
        return self._emissivo('neon_spento', (0.75, 0.8, 0.78), 0.0)

    def _luce_rossa(self):
        return self._emissivo('luce_rossa', (1.0, 0.03, 0.015), 4.0)

    def _nero(self):
        m, nt, bsdf = self._base('nero')
        bsdf.inputs['Base Color'].default_value = (0.012, 0.012, 0.011, 1)
        bsdf.inputs['Roughness'].default_value = 0.5
        self.lati['nero'] = 1.0
        return m

    def _gomma(self):
        m, nt, bsdf = self._base('gomma')
        bsdf.inputs['Base Color'].default_value = (0.03, 0.03, 0.03, 1)
        bsdf.inputs['Roughness'].default_value = 0.8
        self.lati['gomma'] = 1.0
        return m

    def _alfa(self, nome):
        """Materiale con colore RGBA (alfa ritagliata): grigliati, decal. File: derivate/<palette>/<nome>.png
        oppure textures/decal/<nome>.png. ORM e normal dalla sorgente CC0 indicata in ALFA_SORGENTI."""
        m, nt, bsdf = self._base(nome)
        p = os.path.join(TEX, 'derivate', self.palette, nome[5:] + '_col.png')
        if not os.path.exists(p):
            p = os.path.join(TEX, 'decal', nome[5:] + '_col.png')
        uv = nt.nodes.new('ShaderNodeUVMap'); uv.uv_map = 'UVMap'
        t = nt.nodes.new('ShaderNodeTexImage'); t.image = self._img(p, True)
        nt.links.new(uv.outputs['UV'], t.inputs['Vector'])
        nt.links.new(t.outputs['Color'], bsdf.inputs['Base Color'])
        nt.links.new(t.outputs['Alpha'], bsdf.inputs['Alpha'])
        src = ALFA_SORGENTI.get(nome[5:])
        if src:
            cc0 = os.path.join(TEX, 'cc0', src)
            to = nt.nodes.new('ShaderNodeTexImage'); to.image = self._img(os.path.join(cc0, f'{src}_orm.jpg'), False)
            nt.links.new(uv.outputs['UV'], to.inputs['Vector'])
            sep = nt.nodes.new('ShaderNodeSeparateColor')
            nt.links.new(to.outputs['Color'], sep.inputs['Color'])
            nt.links.new(sep.outputs['Green'], bsdf.inputs['Roughness'])
            nt.links.new(sep.outputs['Blue'], bsdf.inputs['Metallic'])
        else:
            bsdf.inputs['Roughness'].default_value = 0.6
        if hasattr(m, 'surface_render_method'):
            m.surface_render_method = 'DITHERED'
        self.lati[nome] = ALFA_LATI.get(nome[5:], 1.0)
        return m

    def _cartellone(self, chiave=''):
        m, nt, bsdf = self._base('cartellone' + ('_' + chiave if chiave else ''))
        p = os.path.join(TEX, 'derivate', self.palette, f'cartellone{"_" + chiave if chiave else ""}_col.jpg')
        tex = nt.nodes.new('ShaderNodeTexImage'); tex.image = self._img(p, True)
        uv = nt.nodes.new('ShaderNodeUVMap'); uv.uv_map = 'UVMap'
        nt.links.new(uv.outputs['UV'], tex.inputs['Vector'])
        nt.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
        bsdf.inputs['Roughness'].default_value = 0.55
        self.lati['cartellone'] = 1.0
        return m


# ----------------------------------------------------------------------------- costruttore di mesh

class Costruttore:
    """Raccoglie facce con materiale e UV, poi crea l'oggetto Blender.
    UV 'scatola': proiezione sul piano più vicino alla normale, in metri / lato della texture."""

    def __init__(self, mats):
        self.mats = mats
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new('UVMap')
        self.col = self.bm.loops.layers.color.new('Col')
        self.nomi_mat = []
        self.uv_manuali = {}
        self.lisce = set()

    def _slot(self, nome):
        if nome not in self.nomi_mat:
            self.nomi_mat.append(nome)
        return self.nomi_mat.index(nome)

    def faccia(self, punti, mat, uv=None, liscia=False):
        vs = [self.bm.verts.new(Vector(p)) for p in punti]
        f = self.bm.faces.new(vs)
        f.material_index = self._slot(mat)
        if uv is not None:
            self.uv_manuali[f] = uv
        if liscia:
            self.lisce.add(f)
        return f

    def scatola(self, lo, hi, mat, senza=()):
        x0, y0, z0 = lo; x1, y1, z1 = hi
        F = {
            '-z': [(x0, y0, z0), (x0, y1, z0), (x1, y1, z0), (x1, y0, z0)],
            '+z': [(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)],
            '-y': [(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)],
            '+y': [(x1, y1, z0), (x0, y1, z0), (x0, y1, z1), (x1, y1, z1)],
            '-x': [(x0, y1, z0), (x0, y0, z0), (x0, y0, z1), (x0, y1, z1)],
            '+x': [(x1, y0, z0), (x1, y1, z0), (x1, y1, z1), (x1, y0, z1)],
        }
        for k, pts in F.items():
            if k not in senza:
                self.faccia(pts, mat)

    def tubo(self, punti, r, mat, seg=16, chiuso=False, tappi=False, lato_uv=None):
        """Tubo lungo una polilinea (frame per trasporto parallelo). UV: u intorno, v lungo."""
        P = []
        for p in punti:
            p = Vector(p)
            if not P or (p - P[-1]).length > 1e-5:
                P.append(p)
        n = len(P)
        T = []
        for i in range(n):
            a = P[min(i + 1, n - 1)] - P[max(i - 1, 0)]
            T.append(a.normalized())
        ref = Vector((0, 0, 1)) if abs(T[0].z) < 0.9 else Vector((1, 0, 0))
        N = [(ref - T[0] * ref.dot(T[0])).normalized()]
        for i in range(1, n):
            v = N[-1] - T[i] * N[-1].dot(T[i])
            N.append(v.normalized())
        anelli = []
        for i in range(n):
            B = T[i].cross(N[i])
            anelli.append([P[i] + (N[i] * math.cos(2 * math.pi * k / seg) + B * math.sin(2 * math.pi * k / seg)) * r
                           for k in range(seg)])
        lt = lato_uv or self.mats.lato(mat)
        circ = 2 * math.pi * r
        s = [0.0]
        for i in range(1, n):
            s.append(s[-1] + (P[i] - P[i - 1]).length)
        for i in range(n - 1):
            for k in range(seg):
                k2 = (k + 1) % seg
                pts = [anelli[i][k], anelli[i][k2], anelli[i + 1][k2], anelli[i + 1][k]]
                u0, u1 = circ * k / seg / lt, circ * (k + 1) / seg / lt
                v0, v1 = s[i] / lt, s[i + 1] / lt
                self.faccia(pts, mat, uv=[(u0, v0), (u1, v0), (u1, v1), (u0, v1)], liscia=True)
        if tappi:
            for i, sgn in ((0, -1), (n - 1, 1)):
                ring = anelli[i] if sgn > 0 else list(reversed(anelli[i]))
                self.faccia(ring, mat)

    def anello(self, centro, asse, r_in, r_out, spessore, mat, seg=32):
        """Rondella / flangia: corona circolare con spessore lungo 'asse'."""
        c = Vector(centro); a = Vector(asse).normalized()
        ref = Vector((0, 0, 1)) if abs(a.z) < 0.9 else Vector((1, 0, 0))
        u = (ref - a * ref.dot(a)).normalized(); v = a.cross(u)
        def p(r, k, h):
            t = 2 * math.pi * k / seg
            return c + (u * math.cos(t) + v * math.sin(t)) * r + a * h
        pieno = r_in < 1e-6
        if pieno:  # disco: due poligoni pieni invece delle corone
            self.faccia([p(r_out, k, spessore) for k in range(seg)], mat)
            self.faccia([p(r_out, k, 0) for k in reversed(range(seg))], mat)
        for k in range(seg):
            k2 = k + 1
            if not pieno:
                self.faccia([p(r_in, k, spessore), p(r_out, k, spessore), p(r_out, k2, spessore), p(r_in, k2, spessore)], mat)
                self.faccia([p(r_in, k2, 0), p(r_out, k2, 0), p(r_out, k, 0), p(r_in, k, 0)], mat)
                self.faccia([p(r_in, k2, 0), p(r_in, k, 0), p(r_in, k, spessore), p(r_in, k2, spessore)], mat, liscia=True)
            self.faccia([p(r_out, k, 0), p(r_out, k2, 0), p(r_out, k2, spessore), p(r_out, k, spessore)], mat, liscia=True)

    def toro(self, centro, asse, R, r, mat, seg=64, seg_r=10, sezione=None):
        """Anello chiuso esatto (toro). sezione=(larghezza, altezza) per una sezione rettangolare."""
        c = Vector(centro); a = Vector(asse).normalized()
        ref = Vector((0, 0, 1)) if abs(a.z) < 0.9 else Vector((1, 0, 0))
        u = (ref - a * ref.dot(a)).normalized(); v = a.cross(u)
        if sezione:
            w, h = sezione
            prof = [(-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)]
            liscia = False
        else:
            prof = [(r * math.cos(2 * math.pi * k / seg_r), r * math.sin(2 * math.pi * k / seg_r)) for k in range(seg_r)]
            liscia = True
        lt = self.mats.lato(mat)
        def p(i, j):
            t = 2 * math.pi * i / seg
            d = u * math.cos(t) + v * math.sin(t)
            rr, hh = prof[j % len(prof)]
            return c + d * (R + rr) + a * hh
        n = len(prof)
        for i in range(seg):
            for j in range(n):
                q = [p(i, j), p(i + 1, j), p(i + 1, j + 1), p(i, j + 1)]
                uv = [(2 * math.pi * R * i / seg / lt, j / n), (2 * math.pi * R * (i + 1) / seg / lt, j / n),
                      (2 * math.pi * R * (i + 1) / seg / lt, (j + 1) / n), (2 * math.pi * R * i / seg / lt, (j + 1) / n)]
                self.faccia(q, mat, uv=uv, liscia=liscia)

    def cilindro(self, a, b, r, mat, seg=12, tappi=True):
        self.tubo([a, b], r, mat, seg=seg, tappi=tappi)

    def disco(self, centro, asse, r, mat, seg=32, uv_disco=False):
        c = Vector(centro); a = Vector(asse).normalized()
        ref = Vector((0, 0, 1)) if abs(a.z) < 0.9 else Vector((1, 0, 0))
        u = (ref - a * ref.dot(a)).normalized(); v = a.cross(u)
        pts = [c + (u * math.cos(2 * math.pi * k / seg) + v * math.sin(2 * math.pi * k / seg)) * r for k in range(seg)]
        uv = [(0.5 + 0.5 * math.cos(2 * math.pi * k / seg), 0.5 + 0.5 * math.sin(2 * math.pi * k / seg)) for k in range(seg)] if uv_disco else None
        return self.faccia(pts, mat, uv=uv)

    def crea(self, nome, sporco=None, liscio_tutto=False):
        """Crea l'oggetto. sporco(pos)->0..1 imposta il colore dei vertici (1 = pulito)."""
        bm = self.bm
        bm.normal_update()  # le facce nuove hanno normale nulla finché non si aggiorna
        for f in bm.faces:
            lt = self.mats.lato(self.nomi_mat[f.material_index])
            if f in self.uv_manuali:
                for loop, (u, v) in zip(f.loops, self.uv_manuali[f]):
                    loop[self.uv].uv = (u, v)
            else:
                nrm = f.normal
                ax = max(range(3), key=lambda i: abs(nrm[i]))
                for loop in f.loops:
                    co = loop.vert.co
                    if ax == 2:
                        u, v = co.x, co.y * (1 if nrm.z > 0 else -1)
                    elif ax == 1:
                        u, v = co.x * (-1 if nrm.y > 0 else 1), co.z
                    else:
                        u, v = co.y * (1 if nrm.x > 0 else -1), co.z
                    loop[self.uv].uv = (u / lt, v / lt)
            for loop in f.loops:
                s = 1.0 if sporco is None else sporco(loop.vert.co)
                loop[self.col] = (s, s, s, 1.0)
            f.smooth = liscio_tutto or f in self.lisce
        self.uv_manuali.clear(); self.lisce.clear()
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
        me = bpy.data.meshes.new(nome)
        bm.to_mesh(me)
        bm.free()
        for n in self.nomi_mat:
            me.materials.append(self.mats.get(n))
        ob = bpy.data.objects.new(nome, me)
        bpy.context.scene.collection.objects.link(ob)
        return ob


def collisione_scatola(nome, lo, hi, padre=None, convessa=True):
    """Oggetto di collisione: Godot lo trasforma in forma fisica e non lo disegna."""
    me = bpy.data.meshes.new(nome)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector([lo[i] + (v.co[i] + 0.5) * (hi[i] - lo[i]) for i in range(3)])
    bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(nome + ('-convcolonly' if convessa else '-colonly'), me)
    bpy.context.scene.collection.objects.link(ob)
    if padre is not None:
        ob.parent = padre
    ob.display_type = 'WIRE'
    return ob


def collisione_punti(nome, punti, padre=None):
    """Collisione convessa dall'inviluppo di punti qualsiasi (rampe di scale, tratti di tubo)."""
    bm = bmesh.new()
    for p in punti:
        bm.verts.new(Vector(p))
    bmesh.ops.convex_hull(bm, input=bm.verts)
    me = bpy.data.meshes.new(nome)
    bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(nome + '-convcolonly', me)
    bpy.context.scene.collection.objects.link(ob)
    if padre is not None:
        ob.parent = padre
    ob.display_type = 'WIRE'
    ob.hide_render = True
    return ob


def sporco_basso(altezza=0.6, minimo=0.62):
    """Più scuro vicino al pavimento (umidità che risale), con un po' di variazione."""
    def f(co):
        t = max(0.0, min(1.0, co.z / altezza))
        rumore = 0.04 * math.sin(co.x * 3.1 + co.y * 1.7) * math.sin(co.x * 0.7 + 1.3)
        return max(0.0, min(1.0, minimo + (1 - minimo) * t * t + rumore))
    return f


# ----------------------------------------------------------------------------- pezzi architettonici

def pavimento(mats, larghezza=MODULO, profondita=MODULO, nome=None):
    nome = nome or f'amb_pavimento_{larghezza:g}x{profondita:g}'.replace('.', '')
    c = Costruttore(mats)
    c.scatola((0, 0, -0.1), (larghezza, profondita, 0), 'pavimento', senza=('-z',))
    ob = c.crea(nome)
    collisione_scatola(nome, (0, 0, -0.1), (larghezza, profondita, 0), padre=ob)
    return ob


def _parete_fronte(c, x0, x1, z0, z1, mat, y=0.0, foro=None, verso=-1):
    """Fascia piana di parete sul piano y. verso=-1: normale -y (fronte), +1: normale +y (retro).
    foro = (cx, cz, r, mezzo_lato) per l'oblò."""
    def F(pts):
        c.faccia(pts if verso < 0 else pts[::-1], mat)
    if foro is None:
        F([(x0, y, z0), (x1, y, z0), (x1, y, z1), (x0, y, z1)])
        return
    cx, cz, r, h = foro
    # parti piene ai lati e sopra/sotto il quadrato che contiene il foro
    for (a0, a1, b0, b1) in ((x0, cx - h, z0, z1), (cx + h, x1, z0, z1), (cx - h, cx + h, z0, cz - h), (cx - h, cx + h, cz + h, z1)):
        if a1 - a0 > 1e-6 and b1 - b0 > 1e-6:
            F([(a0, y, b0), (a1, y, b0), (a1, y, b1), (a0, y, b1)])
    seg = 32
    for k in range(seg):
        t0 = math.pi / 4 + 2 * math.pi * k / seg
        t1 = math.pi / 4 + 2 * math.pi * (k + 1) / seg
        def bordo(t):
            d = Vector((math.cos(t), math.sin(t)))
            d = d / max(abs(d.x), abs(d.y)) * h
            return (cx + d.x, y, cz + d.y)
        def cerchio(t):
            return (cx + math.cos(t) * r, y, cz + math.sin(t) * r)
        F([cerchio(t0), bordo(t0), bordo(t1), cerchio(t1)])


def parete(mats, larghezza=MODULO, oblo=False, nome=None, alta=False, altezza=ALTEZZA_PIANO,
           oblo_z=OBLO_Z, mat_alta='intonaco'):
    """Modulo di parete largo 'larghezza' e alto 'altezza' (3 m di serie): fronte su y=0 (verso -y,
    dentro la sala), spessore 0,2 m verso +y. alta=True: solo intonaco (piani superiori).
    Le fasce piastrellate restano fino a 2 m; sopra c'è l'intonaco fino in cima."""
    nome = nome or ('amb_parete_alta' if alta else 'amb_parete') + f'_{larghezza:g}x{altezza:g}' + ('_oblo' if oblo else '')
    nome = nome.replace('.', '')
    c = Costruttore(mats)
    h, s, L = altezza, SPESSORE_PARETE, larghezza
    OBLO_Z_ = oblo_z
    if alta:
        fasce = [(0.0, h, mat_alta)]
    else:
        fasce = [f for f in FASCE_PARETE if f[1] <= 2.0 + 1e-6] + [(2.0, h, 'intonaco')]
    foro = (L / 2, OBLO_Z_, OBLO_R_FORO, 0.5) if oblo else None
    for z0, z1, mat in fasce:
        dentro = foro is not None and z0 <= OBLO_Z_ - 0.5 + 1e-6 and z1 >= OBLO_Z_ + 0.5 - 1e-6
        if foro is not None and not dentro and z0 < OBLO_Z_ + 0.5 - 1e-6 and z1 > OBLO_Z_ - 0.5 + 1e-6:
            raise ValueError("il quadrato del foro dell'oblò deve stare dentro una sola fascia")
        _parete_fronte(c, 0, L, z0, z1, mat, foro=foro if dentro else None)
    retro = mat_alta if alta else 'intonaco'
    # retro (verso +y, lato esterno: scafo o stanza accanto)
    _parete_fronte(c, 0, L, 0, h, retro, y=s, foro=foro, verso=+1)
    # testa e fianchi
    c.faccia([(0, 0, h), (L, 0, h), (L, s, h), (0, s, h)], retro)
    c.faccia([(0, s, 0), (0, 0, 0), (0, 0, h), (0, s, h)], retro)
    c.faccia([(L, 0, 0), (L, s, 0), (L, s, h), (L, 0, h)], retro)
    if oblo:  # manicotto del foro attraverso lo spessore (normali verso l'asse)
        seg = 32
        for k in range(seg):
            t0 = 2 * math.pi * k / seg; t1 = 2 * math.pi * (k + 1) / seg
            a0 = (L / 2 + math.cos(t0) * OBLO_R_FORO, 0, OBLO_Z_ + math.sin(t0) * OBLO_R_FORO)
            a1 = (L / 2 + math.cos(t1) * OBLO_R_FORO, 0, OBLO_Z_ + math.sin(t1) * OBLO_R_FORO)
            c.faccia([a0, a1, (a1[0], s, a1[2]), (a0[0], s, a0[2])], 'metallo', liscia=True)
    ob = c.crea(nome, sporco=None if alta else sporco_basso())
    collisione_scatola(nome, (0, 0, 0), (L, s, h), padre=ob)
    return ob


def parete_porta(mats, larghezza=MODULO, altezza=ALTEZZA_PIANO, luce=1.8, h_porta=2.4, nome=None,
                 ante_aperte=True):
    """Modulo di parete con porta a due ante (luce 1,8 x 2,4 m, telaio in metallo).
    Stesse fasce della parete normale; le ante si aprono verso -y (dentro la sala)."""
    nome = nome or f'amb_parete_porta_{larghezza:g}x{altezza:g}'.replace('.', '')
    c = Costruttore(mats)
    L, h, s = larghezza, altezza, SPESSORE_PARETE
    a0, a1 = (L - luce) / 2, (L + luce) / 2
    fasce = [f for f in FASCE_PARETE if f[1] <= 2.0 + 1e-6] + [(2.0, h, 'intonaco')]
    for z0, z1, mat in fasce:
        if z1 <= h_porta + 1e-6:
            _parete_fronte(c, 0, a0, z0, z1, mat); _parete_fronte(c, a1, L, z0, z1, mat)
        elif z0 >= h_porta - 1e-6:
            _parete_fronte(c, 0, L, z0, z1, mat)
        else:
            _parete_fronte(c, 0, a0, z0, z1, mat); _parete_fronte(c, a1, L, z0, z1, mat)
            _parete_fronte(c, a0, a1, h_porta, z1, mat)
    for (x0, x1, z0, z1) in ((0, a0, 0, h), (a1, L, 0, h), (a0, a1, h_porta, h)):
        _parete_fronte(c, x0, x1, z0, z1, 'intonaco', y=s, verso=+1)
    c.faccia([(0, 0, h), (L, 0, h), (L, s, h), (0, s, h)], 'intonaco')
    # imbotte (spessore del vano) e telaio
    c.faccia([(a0, 0, 0), (a0, s, 0), (a0, s, h_porta), (a0, 0, h_porta)], 'metallo')
    c.faccia([(a1, s, 0), (a1, 0, 0), (a1, 0, h_porta), (a1, s, h_porta)], 'metallo')
    c.faccia([(a0, 0, h_porta), (a0, s, h_porta), (a1, s, h_porta), (a1, 0, h_porta)][::-1], 'metallo')
    for (x0, x1, z0, z1) in ((a0 - 0.08, a0, 0, h_porta + 0.08), (a1, a1 + 0.08, 0, h_porta + 0.08),
                             (a0, a1, h_porta, h_porta + 0.08)):
        c.scatola((x0, -0.03, z0), (x1, 0.0, z1), 'metallo', senza=('-z',))
    # ante (metallo verniciato con oblò rettangolare) aperte a 70 gradi verso la sala
    w = luce / 2
    for lato in (-1, 1):
        cerniera = Vector((a0 if lato < 0 else a1, -0.02, 0))
        ang = math.radians(70) * (1 if lato < 0 else -1) if ante_aperte else 0.0
        R = Matrix.Rotation(ang, 4, 'Z')
        def P(x, y, z):
            v = R @ Vector((x * -lato, y, z))
            return tuple(cerniera + v)
        for (x0, x1, z0, z1) in ((0, w, 0, h_porta - 0.02),):
            # anta come scatola sottile
            pts = [(x0, -0.05, z0), (x1, -0.05, z0), (x1, 0.0, z0), (x0, 0.0, z0),
                   (x0, -0.05, z1), (x1, -0.05, z1), (x1, 0.0, z1), (x0, 0.0, z1)]
            q = [P(*p) for p in pts]
            facce = [(0, 1, 5, 4), (2, 3, 7, 6), (1, 2, 6, 5), (3, 0, 4, 7), (4, 5, 6, 7), (3, 2, 1, 0)]
            for f in facce:
                vv = [q[i] for i in f]
                c.faccia(vv if lato < 0 else vv[::-1], 'metallo')
    ob = c.crea(nome, sporco=sporco_basso())
    collisione_scatola(nome + '_sx', (0, 0, 0), (a0, s, h), padre=ob)
    collisione_scatola(nome + '_dx', (a1, 0, 0), (L, s, h), padre=ob)
    collisione_scatola(nome + '_sopra', (a0, 0, h_porta), (a1, s, h), padre=ob)
    return ob


def bordo_vasca(mats, lunghezza=MODULO, profondita=VASCA_PROF, nome=None, pitch=0.03, con_parete=True):
    """Bordo vasca a sfioro: canale con griglia (lato ponte, y da -0,5 a -0,25), copertina in
    ceramica con toro arrotondato (y da -0,25 a 0) e parete della vasca (y=0) fino al fondo.
    La vasca sta dalla parte di +y. Lunghezza lungo x."""
    nome = nome or f'amb_bordo_vasca_{lunghezza:g}'.replace('.', '')
    c = Costruttore(mats)
    L = lunghezza
    g0, g1 = -(BORDO_GRIGLIA + BORDO_COPERTINA), -BORDO_COPERTINA
    fondo_canale = -0.18
    # canale (interno scuro e sporco)
    c.faccia([(0, g0, fondo_canale), (L, g0, fondo_canale), (L, g1, fondo_canale), (0, g1, fondo_canale)], 'nero')
    c.faccia([(0, g0, fondo_canale), (L, g0, fondo_canale), (L, g0, 0), (0, g0, 0)][::-1], 'bordo')
    c.faccia([(0, g1, fondo_canale), (L, g1, fondo_canale), (L, g1, 0), (0, g1, 0)], 'bordo')
    # griglia: listelli trasversali su due correnti
    for yb in (g0 + 0.02, g1 - 0.02):
        c.scatola((0, yb - 0.006, -0.035), (L, yb + 0.006, -0.02), 'plastica', senza=('-z',))
    n = int(round(L / pitch))
    for i in range(n):
        x = (i + 0.5) * pitch
        c.scatola((x - 0.006, g0 + 0.005, -0.02), (x + 0.006, g1 - 0.005, -0.002), 'plastica', senza=('-z',))
    # copertina: profilo (d = distanza dalla parete della vasca, z)
    prof = [(BORDO_COPERTINA, 0.0), (0.05, 0.012), (0.03, 0.009), (0.012, 0.0), (0.003, -0.015), (0.0, -0.04)]
    for (d0, z0), (d1, z1) in zip(prof, prof[1:]):
        y0, y1 = -d0, -d1
        c.faccia([(0, y0, z0), (L, y0, z0), (L, y1, z1), (0, y1, z1)], 'bordo', liscia=d0 < 0.06)
    # parete della vasca (con_parete=False quando la parete la fa chi costruisce la vasca)
    if con_parete:
        c.faccia([(0, 0, -0.04), (L, 0, -0.04), (L, 0, -profondita), (0, 0, -profondita)], 'vasca')  # guarda +y
    ob = c.crea(nome, sporco=lambda co: 0.75 if co.z < -0.9 else (0.85 if co.z < -0.5 else 1.0))
    collisione_scatola(nome + '_copertina', (0, -BORDO_COPERTINA, -profondita if con_parete else -0.2), (L, 0, 0.012), padre=ob)
    collisione_scatola(nome + '_griglia', (0, g0, -0.2), (L, g1, 0), padre=ob)
    return ob


def bordo_vasca_angolo(mats, profondita=VASCA_PROF, nome='amb_bordo_vasca_angolo_esterno', pitch=0.03):
    """Angolo del bordo attorno a uno spigolo sporgente della vasca: quadrato 0,5 x 0,5 m.
    Coordinate: x da 0 a 0,5 e y da 0 a 0,5; lo spigolo della vasca è nel punto (0, 0) e la vasca
    sta verso -x e -y. Si accosta a due bordi dritti (uno lungo y con la vasca a -x, uno lungo x
    con la vasca a -y)."""
    c = Costruttore(mats)
    W = BORDO_COPERTINA + BORDO_GRIGLIA
    prof = [(0.0, -0.04), (0.003, -0.015), (0.012, 0.0), (0.03, 0.009), (0.05, 0.012), (BORDO_COPERTINA, 0.0)]
    def p(d):
        for (d0, z0), (d1, z1) in zip(prof, prof[1:]):
            if d <= d1 + 1e-9:
                t = (d - d0) / (d1 - d0)
                return z0 + (z1 - z0) * t
        return 0.0
    ds = [d for d, _ in prof]
    # copertina d'angolo: z = max(p(dx), p(dy)) su una griglia di campioni del profilo
    for i in range(len(ds) - 1):
        for j in range(len(ds) - 1):
            q = [(ds[i], ds[j]), (ds[i + 1], ds[j]), (ds[i + 1], ds[j + 1]), (ds[i], ds[j + 1])]
            c.faccia([(x, y, max(p(x), p(y))) for x, y in q], 'bordo', liscia=True)
    # canale e griglia a L
    fc = -0.18
    g0, g1 = BORDO_COPERTINA, W
    c.faccia([(g0, 0, fc), (g1, 0, fc), (g1, g1, fc), (0, g1, fc), (0, g0, fc), (g0, g0, fc)], 'nero')
    c.faccia([(g0, 0, fc), (g0, g0, fc), (g0, g0, 0), (g0, 0, 0)], 'bordo')         # guarda +x
    c.faccia([(0, g0, fc), (g0, g0, fc), (g0, g0, 0), (0, g0, 0)][::-1], 'bordo')   # guarda +y
    c.faccia([(g1, g1, fc), (g1, 0, fc), (g1, 0, 0), (g1, g1, 0)][::-1], 'bordo')   # lato ponte, guarda -x
    c.faccia([(0, g1, fc), (g1, g1, fc), (g1, g1, 0), (0, g1, 0)], 'bordo')         # lato ponte, guarda -y
    n = int(round(BORDO_GRIGLIA / pitch))
    for i in range(n):  # braccio lungo y (listelli lungo x)
        y = (i + 0.5) * pitch
        c.scatola((g0 + 0.005, y - 0.006, -0.02), (g1 - 0.005, y + 0.006, -0.002), 'plastica', senza=('-z',))
    m = int(round(W / pitch))
    for i in range(m):  # braccio lungo x (listelli lungo y), compreso il quadrato d'angolo
        x = (i + 0.5) * pitch
        c.scatola((x - 0.006, g0 + 0.005, -0.02), (x + 0.006, g1 - 0.005, -0.002), 'plastica', senza=('-z',))
    ob = c.crea(nome)
    collisione_scatola(nome, (0, 0, -0.2), (W, W, 0.012), padre=ob)
    return ob


def fondo_vasca(mats, larghezza=MODULO, profondita=MODULO, quota=-VASCA_PROF, nome=None):
    nome = nome or f'amb_fondo_vasca_{larghezza:g}x{profondita:g}'.replace('.', '')
    c = Costruttore(mats)
    c.faccia([(0, 0, quota), (larghezza, 0, quota), (larghezza, profondita, quota), (0, profondita, quota)], 'vasca')
    ob = c.crea(nome, sporco=lambda co: 0.8)
    collisione_scatola(nome, (0, 0, quota - 0.1), (larghezza, profondita, quota), padre=ob)
    return ob


def parete_vasca(mats, lunghezza=MODULO, profondita=VASCA_PROF, nome=None):
    """Parete interna della vasca senza bordo (per i lati non visibili o sotto altri pezzi)."""
    nome = nome or f'amb_parete_vasca_{lunghezza:g}'.replace('.', '')
    c = Costruttore(mats)
    c.faccia([(0, 0, 0), (lunghezza, 0, 0), (lunghezza, 0, -profondita), (0, 0, -profondita)], 'vasca')  # guarda +y
    return c.crea(nome)


# ----------------------------------------------------------------------------- pezzi in metallo

def scaletta_vasca(mats, profondita=VASCA_PROF, gradini=3, nome='amb_scaletta_vasca'):
    """Scaletta in acciaio inox: due corrimano Ø 43 mm a 50 cm, ancorati nel ponte dietro la
    griglia, curvi sopra il bordo e lungo la parete della vasca; gradini ogni 30 cm.
    Pivot: sul bordo della vasca (y=0, z=0), la vasca è verso +y."""
    c = Costruttore(mats)
    r = 0.0215
    seg = 14
    for x in (-0.25, 0.25):
        pts = []
        y_anc, y_in = -0.62, 0.11
        alto = 0.92
        pts.append((x, y_anc, -0.02))
        pts.append((x, y_anc, alto - 0.22))
        rc = 0.22
        for k in range(0, 9):  # curva sopra il bordo (semicerchio)
            t = math.pi * k / 8
            cy = (y_anc + y_in) / 2
            rr = (y_in - y_anc) / 2
            pts.append((x, cy - math.cos(t) * rr, alto - 0.22 + math.sin(t) * 0.22 + (0.0 if k in (0, 8) else 0)))
        pts.append((x, y_in, alto - 0.22))
        pts.append((x, y_in, -profondita + 0.15))
        # piede che torna verso la parete
        pts.append((x, 0.02, -profondita + 0.12))
        c.tubo(pts, r, 'inox', seg=seg, tappi=True)
        # rosone di ancoraggio nel ponte
        c.anello((x, y_anc, 0.0), (0, 0, 1), r, 0.045, 0.006, 'inox', seg=16)
        # staffa a parete
        c.cilindro((x, 0.0, -0.45), (x, y_in, -0.45), 0.012, 'inox', seg=8)
    for i in range(gradini):
        z = -0.30 * (i + 1)
        c.scatola((-0.25, y_in - 0.035, z - 0.02), (0.25, y_in + 0.085, z), 'inox', senza=())
        c.scatola((-0.24, y_in - 0.03, z), (0.24, y_in + 0.08, z + 0.004), 'gomma', senza=('-z',))
    ob = c.crea(nome)
    collisione_scatola(nome, (-0.27, -0.65, -profondita), (0.27, 0.2, 0.95), padre=ob)
    return ob


def ringhiera(mats, lunghezza=MODULO, nome=None, sbarre=True, paletto_fine=False):
    """Ringhiera navale: paletto Ø 50 mm a x=0 (il prossimo modulo porta il suo), corrimano
    Ø 50 mm a 1,05 m, correnti in basso, sbarre verticali Ø 16 mm ogni 11 cm (sicura per i bambini)."""
    nome = nome or f'amb_ringhiera_{lunghezza:g}'.replace('.', '') + ('_fine' if paletto_fine else '')
    c = Costruttore(mats)
    L = lunghezza
    H = RINGHIERA_H
    paletti = [0.0] + ([L] if paletto_fine else [])
    for x in paletti:
        c.cilindro((x, 0, 0), (x, 0, H), 0.025, 'metallo', seg=12)
        c.anello((x, 0, 0), (0, 0, 1), 0.0, 0.06, 0.008, 'metallo', seg=12)
    c.cilindro((0, 0, H), (L, 0, H), 0.025, 'metallo', seg=12, tappi=False)
    c.cilindro((0, 0, 0.1), (L, 0, 0.1), 0.014, 'metallo', seg=8, tappi=False)
    c.cilindro((0, 0, H - 0.12), (L, 0, H - 0.12), 0.012, 'metallo', seg=8, tappi=False)
    if sbarre:
        n = int(round(L / 0.11))
        for i in range(1, n):
            x = i * L / n
            c.cilindro((x, 0, 0.1), (x, 0, H - 0.12), 0.008, 'metallo', seg=6, tappi=False)
    ob = c.crea(nome)
    collisione_scatola(nome, (0, -0.04, 0), (L, 0.04, H + 0.03), padre=ob)
    return ob


def oblo(mats, nome='amb_oblo_60'):
    """Oblò Ø 60 cm di luce: flangia Ø 84 cm con 12 bulloni sul lato interno, manicotto che
    attraversa la parete (20 cm), vetro arretrato. Pivot al centro, sul filo della parete (y=0);
    l'interno della stanza è verso -y."""
    c = Costruttore(mats)
    s = SPESSORE_PARETE
    c.anello((0, 0, 0), (0, -1, 0), OBLO_R_LUCE - 0.005, OBLO_R_FLANGIA, 0.035, 'cornice_oblo', seg=40)
    # manicotto
    seg = 40
    for k in range(seg):
        t0 = 2 * math.pi * k / seg; t1 = 2 * math.pi * (k + 1) / seg
        a0 = (math.cos(t0) * (OBLO_R_LUCE - 0.005), -0.035, math.sin(t0) * (OBLO_R_LUCE - 0.005))
        a1 = (math.cos(t1) * (OBLO_R_LUCE - 0.005), -0.035, math.sin(t1) * (OBLO_R_LUCE - 0.005))
        b0 = (a0[0], s + 0.02, a0[2]); b1 = (a1[0], s + 0.02, a1[2])
        c.faccia([a0, a1, b1, b0], 'cornice_oblo', liscia=True)
    # anello che tiene il vetro + vetro
    c.anello((0, 0.06, 0), (0, -1, 0), OBLO_R_LUCE - 0.045, OBLO_R_LUCE - 0.004, 0.02, 'cornice_oblo', seg=40)
    c.disco((0, 0.07, 0), (0, -1, 0), OBLO_R_LUCE - 0.01, 'vetro', seg=40)
    # flangia esterna
    c.anello((0, s, 0), (0, 1, 0), OBLO_R_LUCE - 0.005, OBLO_R_FLANGIA - 0.04, 0.025, 'cornice_oblo', seg=40)
    for k in range(12):
        t = 2 * math.pi * (k + 0.5) / 12
        x, z = math.cos(t) * 0.375, math.sin(t) * 0.375
        c.cilindro((x, -0.035, z), (x, -0.055, z), 0.014, 'cornice_oblo', seg=6)
    return c.crea(nome)


def galleria_bordo(mats, lunghezza=MODULO, sbalzo=1.5, nome=None, z=3.0, spessore=0.3):
    """Soletta della galleria: intradosso a quota z (3,0 m di serie), spessore 0,3 m; fronte a y=0,
    si appoggia alla parete a y=sbalzo. Sopra: pavimento; sotto: intradosso in metallo verniciato."""
    nome = nome or f'amb_galleria_bordo_{lunghezza:g}'.replace('.', '')
    c = Costruttore(mats)
    L, z1 = lunghezza, z + spessore
    c.faccia([(0, 0, z1), (L, 0, z1), (L, sbalzo, z1), (0, sbalzo, z1)], 'pavimento')
    c.faccia([(0, 0, z), (0, sbalzo, z), (L, sbalzo, z), (L, 0, z)], 'metallo')
    c.faccia([(0, 0, z), (L, 0, z), (L, 0, z1), (0, 0, z1)], 'metallo')
    # piccola veletta sotto il fronte (nasconde i cavi delle lampade)
    c.scatola((0, 0.0, z - 0.12), (L, 0.04, z), 'metallo', senza=('+z',))
    ob = c.crea(nome)
    collisione_scatola(nome, (0, 0, z), (L, sbalzo, z1), padre=ob)
    return ob


# ----------------------------------------------------------------------------- luci e cartelli

def lampada_neon(mats, lunghezza=1.2, accesa=(True, True), nome='amb_lampada_neon_120'):
    """Plafoniera industriale con due tubi T8 da 120 cm (Ø 26 mm). Pivot al centro del lato
    di attacco (soffitto, z=0); la lampada pende verso -z."""
    c = Costruttore(mats)
    L = lunghezza + 0.1
    c.scatola((-L / 2, -0.09, -0.07), (L / 2, 0.09, 0.0), 'metallo')
    for i, y in enumerate((-0.045, 0.045)):
        m = 'neon' if accesa[i] else 'neon_spento'
        c.cilindro((-lunghezza / 2, y, -0.085), (lunghezza / 2, y, -0.085), 0.013, m, seg=10)
        for x in (-lunghezza / 2 - 0.02, lunghezza / 2 + 0.02):
            c.scatola((x - 0.015, y - 0.02, -0.1), (x + 0.015, y + 0.02, -0.07), 'plastica')
    return c.crea(nome)


def luce_emergenza(mats, nome='amb_luce_emergenza'):
    """Plafoniera navale stagna con gabbia e vetro rosso (Ø 18 cm). Pivot al centro della base,
    sul muro (y=0); sporge verso -y."""
    c = Costruttore(mats)
    c.anello((0, 0, 0), (0, -1, 0), 0.0, 0.1, 0.03, 'metallo', seg=20)
    # cupola di vetro rosso
    pts = []
    for k in range(7):
        t = (math.pi / 2) * k / 6
        pts.append((0, -0.03 - math.sin(t) * 0.075, 0))
    for k in range(6):
        t0 = (math.pi / 2) * k / 6; t1 = (math.pi / 2) * (k + 1) / 6
        r0, r1 = math.cos(t0) * 0.075, math.cos(t1) * 0.075
        y0, y1 = -0.03 - math.sin(t0) * 0.075, -0.03 - math.sin(t1) * 0.075
        seg = 20
        for j in range(seg):
            a0 = 2 * math.pi * j / seg; a1 = 2 * math.pi * (j + 1) / seg
            q = [(math.cos(a0) * r0, y0, math.sin(a0) * r0), (math.cos(a1) * r0, y0, math.sin(a1) * r0),
                 (math.cos(a1) * r1, y1, math.sin(a1) * r1), (math.cos(a0) * r1, y1, math.sin(a0) * r1)]
            if r1 < 1e-5:
                q = q[:3]
            c.faccia(q, 'luce_rossa', liscia=True)
    # gabbia: 4 archi
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        arco = [(math.cos(a) * math.cos(t) * 0.085, -0.03 - math.sin(t) * 0.085, math.sin(a) * math.cos(t) * 0.085)
                for t in [i * (math.pi / 2) / 6 for i in range(7)]]
        c.tubo(arco, 0.005, 'metallo', seg=6)
    return c.crea(nome)


def cartellone(mats, larghezza=2.4, altezza=1.35, nome='amb_cartellone_240x135'):
    """Pannello dipinto con cornice metallica. Pivot al centro del bordo basso, sul retro (y=0);
    la grafica guarda -y."""
    c = Costruttore(mats)
    w, h, s = larghezza, altezza, 0.03
    c.faccia([(-w / 2, -s, 0), (w / 2, -s, 0), (w / 2, -s, h), (-w / 2, -s, h)], 'cartellone',
             uv=[(0, 0), (1, 0), (1, 1), (0, 1)])
    c.scatola((-w / 2, -s, 0), (w / 2, 0, h), 'metallo', senza=('-y',))
    f = 0.035
    for (x0, x1, z0, z1) in ((-w / 2 - f, w / 2 + f, -f, 0), (-w / 2 - f, w / 2 + f, h, h + f),
                             (-w / 2 - f, -w / 2, 0, h), (w / 2, w / 2 + f, 0, h)):
        c.scatola((x0, -s - 0.012, z0), (x1, 0.005, z1), 'metallo')
    return c.crea(nome)


def tubo_scivolo(mats, punti, nome='amb_scivolo_tratto', passo_flange=2.0, materiali=None, seg=24):
    """Tubo chiuso dello scivolo (vetroresina) lungo una curva: segmenti con flange imbullonate
    ogni 'passo_flange' metri. materiali = sequenza ciclica dei colori dei segmenti."""
    c = Costruttore(mats)
    P = [Vector(p) for p in punti]
    # ricampiona a passi di circa 0,15 m (Catmull-Rom)
    def cr(p0, p1, p2, p3, t):
        return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3)
    Q = []
    E = [P[0] + (P[0] - P[1])] + P + [P[-1] + (P[-1] - P[-2])]
    for i in range(1, len(E) - 2):
        n = max(2, int((E[i + 1] - E[i]).length / 0.3))
        for k in range(n):
            Q.append(cr(E[i - 1], E[i], E[i + 1], E[i + 2], k / n))
    Q.append(P[-1])
    s = [0.0]
    for i in range(1, len(Q)):
        s.append(s[-1] + (Q[i] - Q[i - 1]).length)
    mats_seq = materiali or ['scivolo']
    # divide in segmenti
    segm = []
    cur = [0]
    lim = passo_flange
    for i in range(1, len(Q)):
        cur.append(i)
        if s[i] >= lim or i == len(Q) - 1:
            segm.append(cur)
            cur = [i]
            lim += passo_flange
    for j, idx in enumerate(segm):
        m = mats_seq[j % len(mats_seq)]
        pts = [Q[i] for i in idx]
        c.tubo(pts, SCIVOLO_R + SCIVOLO_SPESSORE, m, seg=seg)       # esterno
        c.tubo(list(reversed(pts)), SCIVOLO_R, m, seg=seg)           # interno (normali verso dentro)
        # flangia all'inizio del segmento
        i0 = idx[0]
        t = (Q[min(i0 + 1, len(Q) - 1)] - Q[max(i0 - 1, 0)]).normalized()
        c.anello(Q[i0] - t * 0.012, t, SCIVOLO_R, SCIVOLO_R + 0.075, 0.024, m, seg=seg)
        for k in range(8):  # bulloni
            ref = Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((1, 0, 0))
            u = (ref - t * ref.dot(t)).normalized(); v = t.cross(u)
            a = 2 * math.pi * k / 8
            pb = Q[i0] + (u * math.cos(a) + v * math.sin(a)) * (SCIVOLO_R + 0.05)
            c.cilindro(pb - t * 0.03, pb + t * 0.03, 0.009, 'inox', seg=5)
    # bordo dell'ultimo segmento (uscita)
    t = (Q[-1] - Q[-2]).normalized()
    c.anello(Q[-1] - t * 0.012, t, SCIVOLO_R, SCIVOLO_R + 0.03, 0.024, mats_seq[(len(segm) - 1) % len(mats_seq)], seg=seg)
    return c.crea(nome)


def colonna(mats, base, altezza, raggio=0.09, nome='amb_colonna'):
    c = Costruttore(mats)
    b = Vector(base)
    c.cilindro(b, b + Vector((0, 0, altezza)), raggio, 'metallo', seg=16)
    c.anello(b, (0, 0, 1), 0.0, raggio + 0.08, 0.02, 'metallo', seg=16)
    return c.crea(nome)


# ----------------------------------------------------------------------------- elenco ed export

def pezzi_kit(mats):
    """Tutti i pezzi del kit di prova, ognuno all'origine (per l'export)."""
    sel = mats.pal.get('scivolo_sequenza')
    curva = [(0, 0, 0), (0, 2, -0.35), (0.6, 3.8, -0.75), (1.9, 5.0, -1.1)]
    return {
        'amb_pavimento_2x2': lambda: pavimento(mats),
        'amb_pavimento_05x2': lambda: pavimento(mats, 0.5, 2.0),
        'amb_parete_2x3': lambda: parete(mats),
        'amb_parete_2x3_oblo': lambda: parete(mats, oblo=True),
        'amb_parete_05x3': lambda: parete(mats, 0.5),
        'amb_parete_alta_2x3': lambda: parete(mats, alta=True),
        'amb_parete_alta_2x3_oblo': lambda: parete(mats, alta=True, oblo=True),
        'amb_bordo_vasca_2': lambda: bordo_vasca(mats),
        'amb_bordo_vasca_angolo_esterno': lambda: bordo_vasca_angolo(mats),
        'amb_fondo_vasca_2x2': lambda: fondo_vasca(mats),
        'amb_parete_vasca_2': lambda: parete_vasca(mats),
        'amb_scaletta_vasca': lambda: scaletta_vasca(mats),
        'amb_ringhiera_2': lambda: ringhiera(mats),
        'amb_oblo_60': lambda: oblo(mats),
        'amb_galleria_bordo_2': lambda: galleria_bordo(mats),
        'amb_lampada_neon_120': lambda: lampada_neon(mats),
        'amb_luce_emergenza': lambda: luce_emergenza(mats),
        'amb_cartellone_240x135': lambda: cartellone(mats),
        'amb_scivolo_tratto_prova': lambda: tubo_scivolo(mats, curva, materiali=sel),
    }


def svuota():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def esporta(oggetti, percorso, texture='incorporate'):
    for o in bpy.context.scene.objects:
        o.select_set(False)
    for o in oggetti:
        o.select_set(True)
        for ch in o.children_recursive:
            ch.select_set(True)
    os.makedirs(os.path.dirname(percorso), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=percorso, export_format='GLB', use_selection=True, export_apply=True,
        export_yup=True, export_texcoords=True, export_normals=True, export_materials='EXPORT',
        export_image_format='AUTO' if texture == 'incorporate' else 'NONE', export_jpeg_quality=88,
        export_vertex_color='MATERIAL', export_extras=False, export_cameras=False, export_lights=False)


def main():
    import argparse
    argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:]
    ap = argparse.ArgumentParser()
    ap.add_argument('--palette', default='p1_bianco_turchese', choices=list(PALETTE))
    ap.add_argument('--pezzi', default='')
    ap.add_argument('--texture', default='incorporate', choices=['incorporate', 'nessuna'])
    ap.add_argument('--uscita', default=os.path.join(RADICE, 'assets_src', 'ambiente', 'kit_glb'))
    ap.add_argument('--elenco', action='store_true')
    a = ap.parse_args(argv)
    svuota()
    mats = Materiali(a.palette)
    tutti = pezzi_kit(mats)
    if a.elenco:
        print('\n'.join(tutti))
        return
    scelti = [p for p in a.pezzi.split(',') if p] or list(tutti)
    for nome in scelti:
        svuota()
        mats = Materiali(a.palette)
        ob = pezzi_kit(mats)[nome]()
        ob.name = nome
        out = os.path.join(a.uscita, a.palette, nome + '.glb')
        esporta([ob], out, a.texture)
        tri = sum(len(p.vertices) - 2 for p in ob.data.polygons)
        print(f'{nome}: {tri} triangoli -> {os.path.relpath(out, RADICE)}')


if __name__ == '__main__':
    main()
