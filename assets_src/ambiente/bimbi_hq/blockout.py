"""Render 'blockout' (colori piatti, luce semplice) della struttura di gioco fatta a mano, senza Blender:
legge sala_area_bimbi.glb, divide la struttura nei moduli e li disegna con un rasterizzatore numpy.
Servono solo come riferimento interno per l'image-to-image (Meshy), in rif/blockout_*.jpg.
Uso: SALA_AREA_BIMBI_GLB=<sala_area_bimbi.glb di oggi> python3 blockout.py <uscita>"""
import json, struct, sys, os
import numpy as np
from PIL import Image

GLB = os.environ.get('SALA_AREA_BIMBI_GLB', '/home/user/wt/ambiente/godot/assets/ambiente/sala/sala_area_bimbi.glb')
CX, CY = -14.6, 19.6
TIPI = {5126: np.float32, 5125: np.uint32, 5123: np.uint16, 5121: np.uint8}
NC = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}
COLORI = {'M_amb_gioco_blu': '#2c6aa6', 'M_amb_gioco_rosso': '#b03a2a', 'M_amb_gioco_giallo': '#e0ae2e',
          'M_amb_gioco_verde': '#3f9a8c', 'M_amb_gioco_arancio': '#d8702a', 'M_amb_torre': '#8a3a26',
          'M_amb_inox': '#b9bdc2', 'M_prop_secchio_gigante': '#b8402e'}


def hexrgb(h):
    return np.array([int(h[i:i + 2], 16) for i in (1, 3, 5)], float) / 255.0


def quat(q):
    x, y, z, w = q
    return np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                     [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                     [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


def leggi():
    d = open(GLB, 'rb').read()
    n = struct.unpack_from('<I', d, 12)[0]
    g = json.loads(d[20:20 + n])
    off = 20 + n
    b = d[off + 8:off + 8 + struct.unpack_from('<I', d, off)[0]]

    def acc(i):
        a = g['accessors'][i]; v = g['bufferViews'][a['bufferView']]
        o = v.get('byteOffset', 0) + a.get('byteOffset', 0); k = NC[a['type']]
        arr = np.frombuffer(b, dtype=TIPI[a['componentType']], count=a['count'] * k, offset=o)
        return arr.reshape(-1, k) if k > 1 else arr
    tris = []   # (nome nodo, materiale, triangoli Nx3x3 in coordinate Blender)
    for nd in g['nodes']:
        if nd['name'] not in ('sala_struttura_gioco', 'sala_secchio_gigante'):
            continue
        R = quat(nd['rotation']) if 'rotation' in nd else np.eye(3)
        T = np.array(nd.get('translation', [0, 0, 0]))
        for pr in g['meshes'][nd['mesh']]['primitives']:
            p = acc(pr['attributes']['POSITION']).astype(float) @ R.T + T
            idx = acc(pr['indices']).astype(np.int64).reshape(-1, 3)
            P = p[idx]
            P = np.stack([P[..., 0], -P[..., 2], P[..., 1]], -1)   # glTF -> Blender
            tris.append((nd['name'], g['materials'][pr['material']]['name'], P))
    return tris


def modulo(x, y, z):
    """Il modulo di un triangolo della struttura dal suo centro (coordinate locali, vedi struttura_gioco)."""
    if x > 1.5 and y < 0.2 and z < 3.0:
        return 'arancio'                                   # scivolo
    if z > 5.0 and -1.45 < x < 2.35 and -0.15 < y < 3.3:
        return 'secchio'                                   # telaio alto, asse, tubo in cima
    if z > 3.75 and (abs(x + 1.3) < 0.1 or abs(x - 1.7) < 0.1) and (abs(y - 0.05) < 0.1 or abs(y - 3.15) < 0.1):
        return 'secchio'                                   # pali del telaio
    if -0.65 < x < 1.05 and -0.7 < y < 0.95 and 2.9 < z < 3.95:
        return 'secchio'                                   # ponte tra la torre 1 e la torre 2
    if -1.45 < x < -0.95 and -1.75 < y < -0.65 and z < 1.5:
        return 'verde'                                     # passerella 1
    if -1.45 < x < -0.95 and 1.15 < y < 2.05 and 2.4 < z < 2.7:
        return 'rossa'                                     # passerella 2
    if x < -1.2:
        return 'verde' if y < 0.2 else 'rossa'             # torre 0 con la scala, torre 3
    return 'arancio' if y < 0.2 else 'secchio'             # torre 1, torre 2 con il tubo


def moduli(tris):
    out = {k: [] for k in ('verde', 'arancio', 'rossa', 'secchio', 'tutta', 'secchio_solo')}
    for nome, mat, P in tris:
        C = P.mean(1) - [CX, CY, 0]
        for i in range(len(P)):
            tri = (mat, P[i])
            if nome == 'sala_secchio_gigante':
                out['secchio_solo'].append(tri)
                continue
            out['tutta'].append(tri)
            out[modulo(*C[i])].append(tri)
    return out


def rendi(tris, cam, mira, fov=40.0, W=1024, H=1024, sfondo=(0.86, 0.86, 0.87), rim=None):
    cam = np.array(cam, float); mira = np.array(mira, float)
    f = mira - cam; f /= np.linalg.norm(f)
    r = np.cross(f, [0, 0, 1]); r /= np.linalg.norm(r)
    u = np.cross(r, f)
    foc = (H / 2) / np.tan(np.radians(fov) / 2)
    img = np.ones((H, W, 3)) * sfondo
    zb = np.full((H, W), np.inf)
    luce = np.array([-0.45, -0.6, 0.75]); luce /= np.linalg.norm(luce)
    for mat, P in tris:
        base = hexrgb(COLORI.get(mat, '#888888'))
        if mat == 'M_prop_secchio_gigante' and rim is not None and P[:, 2].mean() > rim:
            base = hexrgb('#e0b52e')
        n = np.cross(P[1] - P[0], P[2] - P[0]); nn = np.linalg.norm(n)
        if nn < 1e-12:
            continue
        n /= nn
        V = P - cam
        zc = V @ f
        if (zc < 0.05).any():
            continue
        xs = W / 2 + foc * (V @ r) / zc
        ys = H / 2 - foc * (V @ u) / zc
        x0, x1 = int(max(np.floor(xs.min()), 0)), int(min(np.ceil(xs.max()), W - 1))
        y0, y1 = int(max(np.floor(ys.min()), 0)), int(min(np.ceil(ys.max()), H - 1))
        if x0 > x1 or y0 > y1:
            continue
        gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        d = (ys[1] - ys[2]) * (xs[0] - xs[2]) + (xs[2] - xs[1]) * (ys[0] - ys[2])
        if abs(d) < 1e-9:
            continue
        a = ((ys[1] - ys[2]) * (gx - xs[2]) + (xs[2] - xs[1]) * (gy - ys[2])) / d
        bb = ((ys[2] - ys[0]) * (gx - xs[2]) + (xs[0] - xs[2]) * (gy - ys[2])) / d
        c = 1 - a - bb
        m = (a >= -1e-4) & (bb >= -1e-4) & (c >= -1e-4)
        if not m.any():
            continue
        z = 1.0 / (a / zc[0] + bb / zc[1] + c / zc[2])
        sub = zb[y0:y1 + 1, x0:x1 + 1]
        m &= z < sub
        if not m.any():
            continue
        if n @ (cam - P.mean(0)) < 0:
            n = -n
        s = 0.42 + 0.58 * max(n @ luce, 0.0) + 0.12 * max(n[2], 0)
        col = np.clip(base * s, 0, 1)
        sub[m] = z[m]
        img[y0:y1 + 1, x0:x1 + 1][m] = col
    return Image.fromarray((np.clip(img, 0, 1) ** (1 / 1.0) * 255).astype(np.uint8))


if __name__ == '__main__':
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    M = moduli(leggi())
    for k, v in M.items():
        print(k, len(v))
    # viste 3/4 da sud-est (come chi arriva), coordinate del mondo
    def cxy(x, y, z):
        return (CX + x, CY + y, z)
    viste = {
        'tutta': (cxy(10.5, -13.0, 5.5), cxy(0.2, 0.0, 3.4), 40),
        'verde': (cxy(3.6, -10.5, 3.8), cxy(-2.6, -2.6, 1.9), 36),
        'arancio': (cxy(8.0, -8.5, 4.2), cxy(1.8, -1.3, 2.0), 40),
        'rossa': (cxy(4.4, -5.6, 4.6), cxy(-2.5, 1.6, 2.5), 38),
        'secchio': (cxy(8.0, -7.5, 6.5), cxy(0.3, 1.4, 4.4), 42),
        'secchio_solo': (cxy(0.2, -5.0, 8.3), cxy(0.2, 1.6, 7.0), 30),
    }
    for k, (cam, mira, fov) in viste.items():
        im = rendi(M[k], cam, mira, fov, rim=7.55 if k == 'secchio_solo' else None)
        im.save(os.path.join(out, f'blockout_{k}.png'))
        print('salvato', k)
