"""Per ogni modulo fedele: quale rotazione (0/90/180/270 gradi attorno a z) del modello Meshy, adattato ai limiti
del modulo fatto a mano, gli somiglia di più (IoU dei voxel di superficie, 10 cm). Senza Blender.
Uso: SALA_AREA_BIMBI_GLB=<sala_area_bimbi.glb di oggi> python3 orienta.py <cartella con modulo_*.glb> [moduli...]
Risultato (16 ottobre): verde 0, arancio 90, rossa 90, secchio 0 gradi, con scale per asse entro il 5%."""
import sys, json
import numpy as np
import blockout as B
from glb_info import leggi



def limiti_moduli(tris):
    """Limiti locali dei moduli di oggi (quelli scritti in tools/blender/bimbi_hq.py, MODULI_FEDELI)."""
    out = {}
    for k in ('verde', 'arancio', 'rossa', 'secchio'):
        P = np.concatenate([t[1] for t in tris[k]]) - [B.CX, B.CY, 0]
        out[k] = dict(lo=P.min(0).round(3).tolist(), hi=P.max(0).round(3).tolist())
    return out


def campiona(T, n=250000, seme=0):
    """Punti a caso sulla superficie (pesati per area). T: triangoli Nx3x3."""
    A = np.linalg.norm(np.cross(T[:, 1] - T[:, 0], T[:, 2] - T[:, 0]), axis=1) / 2
    rng = np.random.default_rng(seme)
    i = rng.choice(len(T), size=n, p=A / A.sum())
    u, v = rng.random(n), rng.random(n)
    m = u + v > 1
    u[m], v[m] = 1 - u[m], 1 - v[m]
    t = T[i]
    return t[:, 0] + u[:, None] * (t[:, 1] - t[:, 0]) + v[:, None] * (t[:, 2] - t[:, 0])


def voxel(P, lo, passo=0.2):
    return set(map(tuple, np.floor((P - lo) / passo).astype(int)))


def adatta(V, rot, lo_t, hi_t):
    a = np.radians(rot)
    R = np.array([[np.cos(a), -np.sin(a), 0], [np.sin(a), np.cos(a), 0], [0, 0, 1]])
    W = V @ R.T
    lo, hi = W.min(0), W.max(0)
    return (W - lo) * ((hi_t - lo_t) / (hi - lo)) + lo_t


if __name__ == '__main__':
    cartella = sys.argv[1]
    moduli = sys.argv[2:] or ['verde', 'arancio', 'rossa', 'secchio']
    tris = B.moduli(B.leggi())
    LIM = limiti_moduli(tris)
    print(json.dumps(LIM))
    ris = {}
    for k in moduli:
        Tp = np.stack([t[1] for t in tris[k]]) - [B.CX, B.CY, 0]
        lo_t, hi_t = np.array(LIM[k]['lo']), np.array(LIM[k]['hi'])
        Pp = campiona(Tp)
        Vp = voxel(Pp, lo_t)
        V, F, _ = leggi(f'{cartella}/modulo_{k}.glb')
        Tm = V[F]
        migliore = None
        for rot in (0, 90, 180, 270):
            Tr = adatta(Tm.reshape(-1, 3), rot, lo_t, hi_t).reshape(-1, 3, 3)
            Pm = campiona(Tr, seme=1)
            Vm = voxel(Pm, lo_t)
            iou = len(Vp & Vm) / len(Vp | Vm)
            a = np.radians(rot)
            W = Tm.reshape(-1, 3) @ np.array([[np.cos(a), -np.sin(a), 0], [np.sin(a), np.cos(a), 0], [0, 0, 1]]).T
            scala = (hi_t - lo_t) / (W.max(0) - W.min(0))
            print(f'{k} rot {rot:3d}: IoU {iou:.3f}  scala x/y/z {np.round(scala, 3)}  (rapporti {np.round(scala / scala.mean(), 3)})')
            if migliore is None or iou > migliore[1]:
                migliore = (rot, iou)
        ris[k] = migliore
        print('->', k, migliore)
