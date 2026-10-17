"""Legge un GLB senza Blender (numpy): vertici e triangoli nel sistema di Blender (Z in alto, glTF Y-up ->
Blender: x, -z, y), limiti, conteggi. Uso: python3 glb_info.py file.glb [--npz uscita.npz]"""
import json, struct, sys
import numpy as np

TIPI = {5126: np.float32, 5125: np.uint32, 5123: np.uint16, 5121: np.uint8}
NCOMP = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}


def leggi(path):
    d = open(path, 'rb').read()
    n = struct.unpack_from('<I', d, 12)[0]
    g = json.loads(d[20:20 + n])
    off = 20 + n
    bn = struct.unpack_from('<I', d, off)[0]
    b = d[off + 8:off + 8 + bn]

    def acc(i):
        a = g['accessors'][i]
        v = g['bufferViews'][a['bufferView']]
        o = v.get('byteOffset', 0) + a.get('byteOffset', 0)
        k = NCOMP[a['type']]
        arr = np.frombuffer(b, dtype=TIPI[a['componentType']], count=a['count'] * k, offset=o)
        return arr.reshape(-1, k) if k > 1 else arr

    def matrice(nd):
        if 'matrix' in nd:
            return np.array(nd['matrix'], dtype=float).reshape(4, 4).T
        M = np.eye(4)
        if 'scale' in nd:
            M = np.diag(list(nd['scale']) + [1.0]) @ M
        if 'rotation' in nd:
            x, y, z, w = nd['rotation']
            R = np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                          [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                          [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])
            M4 = np.eye(4); M4[:3, :3] = R
            M = M4 @ M
        if 'translation' in nd:
            T = np.eye(4); T[:3, 3] = nd['translation']
            M = T @ M
        return M

    V, F = [], []
    def visita(i, P):
        nd = g['nodes'][i]
        M = P @ matrice(nd)
        if 'mesh' in nd:
            for pr in g['meshes'][nd['mesh']]['primitives']:
                p = acc(pr['attributes']['POSITION']).astype(float)
                p = (M @ np.c_[p, np.ones(len(p))].T).T[:, :3]
                idx = acc(pr['indices']).astype(np.int64).reshape(-1, 3) if 'indices' in pr else np.arange(len(p)).reshape(-1, 3)
                F.append(idx + sum(len(v) for v in V))
                V.append(p)
        for c in nd.get('children', []):
            visita(c, M)
    for i in g['scenes'][g.get('scene', 0)]['nodes']:
        visita(i, np.eye(4))
    V = np.concatenate(V); F = np.concatenate(F)
    V = np.c_[V[:, 0], -V[:, 2], V[:, 1]]     # glTF Y-up -> Blender Z-up
    return V, F, g


if __name__ == '__main__':
    V, F, g = leggi(sys.argv[1])
    lo, hi = V.min(0), V.max(0)
    print('vertici', len(V), 'triangoli', len(F))
    print('min', np.round(lo, 3), 'max', np.round(hi, 3), 'dim', np.round(hi - lo, 3))
    print('immagini', [(im.get('mimeType'), g['bufferViews'][im['bufferView']]['byteLength']) for im in g.get('images', [])])
    if '--npz' in sys.argv:
        np.savez(sys.argv[sys.argv.index('--npz') + 1], V=V, F=F)
