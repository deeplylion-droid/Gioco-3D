"""Da un pixel di uno scatto ravvicinato (vista 'destra' ecc. del collaudo) al punto del modello: cosa colpisce il raggio
(guanto o lancia) e dove, in coordinate glTF. Uso: raggio_np.py guanto.glb lancia.gltf dx dy dz px py [px py ...]"""
import json, struct, sys, os
import numpy as np
def carica(path):
    if path.endswith('.glb'):
        d = open(path, 'rb').read(); n = struct.unpack_from('<I', d, 12)[0]
        js = json.loads(d[20:20 + n]); buf = d[20 + n + 8:]
    else:
        js = json.load(open(path)); buf = open(os.path.join(os.path.dirname(path), js['buffers'][0]['uri']), 'rb').read()
    def acc(i):
        a = js['accessors'][i]; bv = js['bufferViews'][a['bufferView']]
        comp = {5126: np.float32, 5125: np.uint32, 5123: np.uint16}[a['componentType']]
        k = {'SCALAR': 1, 'VEC3': 3, 'VEC2': 2, 'VEC4': 4}[a['type']]
        o = bv.get('byteOffset', 0) + a.get('byteOffset', 0)
        x = np.frombuffer(buf, comp, a['count'] * k, o)
        return x.reshape(-1, k) if k > 1 else x
    tri = []
    # trasformazioni dei nodi (solo traslazione/rotazione/scala dei nodi radice con mesh)
    for nd in js['nodes']:
        if 'mesh' not in nd: continue
        M = np.eye(4)
        if 'matrix' in nd: M = np.array(nd['matrix']).reshape(4, 4).T
        else:
            t = nd.get('translation', [0, 0, 0]); r = nd.get('rotation', [0, 0, 0, 1]); s = nd.get('scale', [1, 1, 1])
            x, y, z, w = r
            R = np.array([[1-2*(y*y+z*z), 2*(x*y-z*w), 2*(x*z+y*w)], [2*(x*y+z*w), 1-2*(x*x+z*z), 2*(y*z-x*w)], [2*(x*z-y*w), 2*(y*z+x*w), 1-2*(x*x+y*y)]])
            M[:3, :3] = R * np.array(s); M[:3, 3] = t
        for pr in js['meshes'][nd['mesh']]['primitives']:
            p = acc(pr['attributes']['POSITION']).astype(np.float64); t = acc(pr['indices']).reshape(-1, 3)
            p = p @ M[:3, :3].T + M[:3, 3]
            tri.append(p[t])
    return np.vstack(tri)
TG = carica(sys.argv[1]); TL = carica(sys.argv[2])
d = np.array([float(x) for x in sys.argv[3:6]]); d /= np.linalg.norm(d)
C = np.array([0.017, -0.245, 0.52]); pos = C + d * 0.28
f = -d; up = np.array([0, 1.0, 0]) if abs(d[1]) < 0.9 else np.array([0, 0, 1.0])
r = np.cross(f, up); r /= np.linalg.norm(r); u = np.cross(r, f)
tg = np.tan(np.radians(20))
def colpo(T, o, dd):
    A, B, Cc = T[:, 0], T[:, 1], T[:, 2]; e1 = B - A; e2 = Cc - A
    p = np.cross(dd, e2); det = (e1 * p).sum(1); ok = np.abs(det) > 1e-14
    inv = np.where(ok, 1 / np.where(ok, det, 1), 0); s = o - A
    a = (s * p).sum(1) * inv; q = np.cross(s, e1); b = (q * dd).sum(1) * inv; t = (e2 * q).sum(1) * inv
    h = ok & (a >= 0) & (b >= 0) & (a + b <= 1) & (t > 0)
    return t[h].min() if h.any() else np.inf
px = [float(x) for x in sys.argv[6:]]
for i in range(0, len(px), 2):
    x = (px[i] + 0.5) / 1280 * 2 - 1; y = 1 - (px[i + 1] + 0.5) / 720 * 2
    dd = f + r * x * tg * 1280 / 720 + u * y * tg; dd /= np.linalg.norm(dd)
    tgu = colpo(TG, pos, dd); tl = colpo(TL, pos, dd)
    chi = 'guanto' if tgu < tl else ('lancia' if tl < np.inf else 'niente')
    t = min(tgu, tl)
    print('pixel (%d, %d): %s in %s; guanto a %.1f mm, lancia a %.1f mm' % (px[i], px[i + 1], chi,
          np.round(pos + dd * t, 4) if t < np.inf else '-', tgu * 1000, tl * 1000))
