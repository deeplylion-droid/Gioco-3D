"""Occhio venato (versione malvagia): texture e parametro 'venatura' del materiale dell'occhio.

La texture tex/occhio_bulbo_venato.png nasce da quella calma (tex/occhio_bulbo_basecolor.png, stessa
proiezione: iride al centro, sclera intorno):
  - capillari rossi che partono dal bordo della sclera e vanno verso l'iride, ramificati, piu' fitti ai bordi
    e sempre piu' sottili verso l'iride, con un alone rosato intorno (occhio iniettato di sangue);
  - sclera un po' ingiallita, di piu' verso il bordo;
  - iride rosa piu' accesa (piu' satura e un po' piu' luminosa).
Il materiale M_occhio_bulbo mescola le due texture con il valore 'venatura' (0 = calma, 1 = malvagia): in Blender
e' un nodo Value con quel nome, in Godot il parametro dello shader medusa_occhio.gdshader. Nella calma resta a 0.
Uso dal passo 7 (materiale_venatura) oppure da solo per rifare la texture.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from medusa_comune import *  # noqa: E402,F401

TEX_CALMO = os.path.join(TEX, 'occhio_bulbo_basecolor.png')
TEX_VENATO = os.path.join(TEX, 'occhio_bulbo_venato.png')
R_IRIDE = 0.358         # raggio esterno dell'anello dell'iride (frazione del lato della texture)


def _smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def crea_texture(seme=7):
    import cv2
    from PIL import Image
    base = np.asarray(Image.open(TEX_CALMO).convert('RGB')).astype(np.float32) / 255.0
    H = base.shape[0]
    c = H / 2.0
    yy, xx = np.mgrid[0:H, 0:H]
    r = np.hypot(xx - c, yy - c) / H
    rng = np.random.default_rng(seme)
    vene = np.zeros((H, H), np.float32)

    def ramo(r0, th0, w0, lung, livello):
        rr, th, w, dth = r0, th0, w0, 0.0
        passo = 0.0035
        prec = None
        for _ in range(int(lung / passo)):
            p = (c + rr * H * math.cos(th), c + rr * H * math.sin(th))
            if prec is not None:
                cv2.line(vene, (int(prec[0] * 4), int(prec[1] * 4)), (int(p[0] * 4), int(p[1] * 4)),
                         float(min(1.0, 0.45 + w / 6.0)), max(1, int(round(w))), cv2.LINE_AA, 2)
            prec = p
            dth = 0.82 * dth + rng.normal(0.0, 0.035)
            th += dth * passo / max(rr, 0.05) * 6.0
            rr -= passo * rng.uniform(0.55, 1.0)
            w *= 0.988
            if rr < R_IRIDE + 0.004 or w < 0.6:
                break
            if livello < 3 and rng.random() < 0.07:
                ramo(rr, th + rng.choice([-1, 1]) * rng.uniform(0.08, 0.35), w * rng.uniform(0.5, 0.75),
                     lung * rng.uniform(0.35, 0.65), livello + 1)

    # vasi grandi dal bordo verso l'iride (circa la meta' ci arriva)
    for _ in range(64):
        ramo(0.56 + rng.uniform(0, 0.05), rng.uniform(0, 2 * math.pi), rng.uniform(3.5, 7.0),
             rng.uniform(0.16, 0.34), 0)
    # capillari fini, fitti vicino al bordo
    for _ in range(260):
        ramo(0.5 + rng.uniform(0, 0.08), rng.uniform(0, 2 * math.pi), rng.uniform(1.0, 2.4),
             rng.uniform(0.03, 0.1), 2)
    vene = cv2.GaussianBlur(vene, (0, 0), 0.9)
    alone = cv2.GaussianBlur(vene, (0, 0), 7.0)
    sclera = _smooth(R_IRIDE - 0.004, R_IRIDE + 0.03, r)            # 0 sull'iride, 1 sulla sclera
    out = base.copy()
    # sclera ingiallita, di piu' verso il bordo
    giallo = np.array([0.86, 0.77, 0.52], np.float32)
    g = (0.28 + 0.3 * _smooth(0.4, 0.55, r)) * sclera
    out = out * (1 - g[..., None]) + giallo * g[..., None]
    # alone rosato e vene rosse (piu' scure quelle grandi)
    rosa = np.array([0.85, 0.42, 0.45], np.float32)
    a = np.clip(alone * 1.9, 0, 0.5) * sclera * (0.6 + 0.4 * _smooth(0.38, 0.5, r))
    out = out * (1 - a[..., None]) + rosa * a[..., None]
    rosso = np.array([0.55, 0.035, 0.06], np.float32)
    v = np.clip(vene, 0, 1) * sclera
    out = out * (1 - v[..., None]) + rosso * v[..., None]
    # iride piu' accesa
    hsv = cv2.cvtColor(np.clip(out, 0, 1).astype(np.float32), cv2.COLOR_RGB2HSV)
    iride = 1 - sclera
    hsv[..., 1] = np.clip(hsv[..., 1] * (1 + 0.45 * iride), 0, 1)
    hsv[..., 2] = np.clip(hsv[..., 2] * (1 + 0.12 * iride), 0, 1)
    out = cv2.cvtColor(hsv, cv2.COLOR_HSV2RGB)
    Image.fromarray((np.clip(out, 0, 1) * 255 + 0.5).astype(np.uint8)).save(TEX_VENATO)
    log('occhio venato:', os.path.relpath(TEX_VENATO, REPO))
    return TEX_VENATO


def materiale_venatura():
    """M_occhio_bulbo: colore = mix(texture calma, texture venata, venatura); anche la luce propria."""
    if not os.path.exists(TEX_VENATO):
        crea_texture()
    m = bpy.data.materials['M_occhio_bulbo']
    nt = m.node_tree
    b = nt.nodes['BSDF']
    base = nt.nodes['base']
    ven = nt.nodes.get('base_venata') or nodo(nt, 'ShaderNodeTexImage', (base.location.x, base.location.y - 320))
    ven.name = 'base_venata'
    ven.image = immagine(TEX_VENATO)
    ven.extension = base.extension
    val = nt.nodes.get('venatura') or nodo(nt, 'ShaderNodeValue', (base.location.x, base.location.y + 220))
    val.name = 'venatura'
    val.label = 'venatura (0 calma, 1 malvagia)'
    val.outputs[0].default_value = 0.0
    mix = nt.nodes.get('mix_venatura') or nodo(nt, 'ShaderNodeMix', (base.location.x + 300, base.location.y))
    mix.name = 'mix_venatura'
    mix.data_type = 'RGBA'
    mix.blend_type = 'MIX'
    nt.links.new(val.outputs[0], mix.inputs['Factor'])
    nt.links.new(base.outputs['Color'], mix.inputs['A'])
    nt.links.new(ven.outputs['Color'], mix.inputs['B'])
    nt.links.new(mix.outputs['Result'], b.inputs['Base Color'])
    nt.links.new(mix.outputs['Result'], b.inputs['Emission Color'])


if __name__ == '__main__':
    crea_texture()
