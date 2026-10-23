import json,sys,struct,numpy as np,subprocess
rev=sys.argv[1]; base='godot/assets/ambienti_interni/spogliatoi'
def show(p): return subprocess.run(['git','-C','/home/user/wt/collaudo','show',f'{rev}:{p}'],capture_output=True,check=True).stdout
g=json.loads(show(base+'.gltf')); b=show(base+'.bin')
def acc(i):
    a=g['accessors'][i]; bv=g['bufferViews'][a['bufferView']]
    n={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']]; dt={5126:np.float32,5125:np.uint32,5123:np.uint16,5121:np.uint8}[a['componentType']]
    off=bv.get('byteOffset',0)+a.get('byteOffset',0); st=bv.get('byteStride',0)
    if st and st!=n*np.dtype(dt).itemsize:
        raw=np.frombuffer(b,dtype=np.uint8,count=st*a['count'],offset=off).reshape(a['count'],st)[:,:n*np.dtype(dt).itemsize]
        return np.frombuffer(raw.tobytes(),dtype=dt).reshape(-1,n)
    return np.frombuffer(b,dtype=dt,count=a['count']*n,offset=off).reshape(-1,n)
nomi={}
for nd in g['nodes']:
    if 'mesh' in nd and 'anta' in nd.get('name',''): nomi.setdefault(nd['mesh'],[]).append(nd['name'])
for mi,ns in nomi.items():
    m=g['meshes'][mi]; area=0; tri=0; box=None
    for p in m['primitives']:
        v=acc(p['attributes']['POSITION']).astype(np.float64); ix=acc(p['indices']).reshape(-1,3) if 'indices' in p else np.arange(len(v)).reshape(-1,3)
        t=v[ix]; area+=0.5*np.linalg.norm(np.cross(t[:,1]-t[:,0],t[:,2]-t[:,0]),axis=1).sum(); tri+=len(ix)
        lo,hi=v.min(0),v.max(0)
    print(f'{rev} mesh {m.get("name")} usata da {len(ns)} ({ns[0]}...) tri {tri} area {area:.3f} box {np.round(hi-lo,3)}')
