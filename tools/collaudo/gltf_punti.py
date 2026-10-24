# triangoli di un glTF vicino a dei punti, e raggi lungo gli assi (solo lettura, numpy)
import json, sys, struct, numpy as np, os
def carica(path, binpath=None):
    g = json.load(open(path))
    base = os.path.dirname(path)
    bufs = [open(binpath or os.path.join(base, b['uri']), 'rb').read() for b in g['buffers']]
    def acc(i):
        a = g['accessors'][i]; v = g['bufferViews'][a['bufferView']]
        n = {'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']]
        dt = {5126:np.float32,5125:np.uint32,5123:np.uint16,5121:np.uint8}[a['componentType']]
        off = v.get('byteOffset',0)+a.get('byteOffset',0)
        st = v.get('byteStride')
        it = np.dtype(dt).itemsize
        if st and st != n*it:
            raw = np.frombuffer(bufs[v['buffer']], np.uint8, count=st*a['count'], offset=off).reshape(a['count'], st)
            return raw[:, :n*it].copy().view(dt).reshape(a['count'], n)
        return np.frombuffer(bufs[v['buffer']], dt, count=a['count']*n, offset=off).reshape(a['count'], n)
    def mat(nd):
        if 'matrix' in nd: return np.array(nd['matrix']).reshape(4,4).T
        t = nd.get('translation',[0,0,0]); r = nd.get('rotation',[0,0,0,1]); s = nd.get('scale',[1,1,1])
        x,y,z,w = r
        R = np.array([[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],[2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],[2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]])
        M = np.eye(4); M[:3,:3] = R*np.array(s); M[:3,3] = t; return M
    tris = []
    def visita(i, P):
        nd = g['nodes'][i]; M = P @ mat(nd)
        if 'mesh' in nd:
            for pr in g['meshes'][nd['mesh']]['primitives']:
                v = acc(pr['attributes']['POSITION']).astype(np.float64)
                v = (np.c_[v, np.ones(len(v))] @ M.T)[:, :3]
                idx = acc(pr['indices']).reshape(-1) if 'indices' in pr else np.arange(len(v))
                tris.append((nd.get('name','?'), v[idx.reshape(-1,3)]))
        for c in nd.get('children', []): visita(c, M)
    for r in g['scenes'][g.get('scene',0)]['nodes']: visita(r, np.eye(4))
    return tris
def raggio(o, d, T):
    e1 = T[:,1]-T[:,0]; e2 = T[:,2]-T[:,0]; p = np.cross(d, e2); det = (e1*p).sum(1)
    ok = np.abs(det) > 1e-12; inv = np.where(ok, 1/np.where(ok,det,1), 0)
    s = o - T[:,0]; u = (s*p).sum(1)*inv; q = np.cross(s, e1); v = (q*d).sum(1)*inv; t = (e2*q).sum(1)*inv
    m = ok & (u>=0) & (v>=0) & (u+v<=1) & (t>0)
    return t[m].min() if m.any() else None
path = sys.argv[1]; binp = sys.argv[2] if len(sys.argv) > 3 else None
punti = [tuple(map(float, p.split(','))) for p in sys.argv[-1].split(';')]
tris = carica(path, binp)
for P in punti:
    o = np.array(P); print('punto', P)
    for nome, T in tris:
        c = T.mean(1); d = np.linalg.norm(c - o, axis=1)
        for ax, dv in [('+x',(1,0,0)),('-x',(-1,0,0)),('+z',(0,0,1)),('-z',(0,0,-1)),('+y',(0,1,0)),('-y',(0,-1,0))]:
            t = raggio(o, np.array(dv, float), T)
            if t is not None and t < 5: print('  ', nome, ax, round(t, 3))
