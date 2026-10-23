import json,sys,numpy as np
S=sys.argv[1]
for c in ('vecchio','nuovo'):
    d=json.load(open(f'{S}/ci/{c}/geo_aperto.json')); t=np.fromfile(f'{S}/ci/{c}/geo_aperto.bin',dtype=np.float32).reshape(-1,3,3)
    corpi=[m for m in d['mesh'] if 'armadiett' in m['nodo'] and not m['nodo'].endswith('_anta')]
    print(c)
    for m in d['mesh']:
        if not m['nodo'].endswith('_anta'): continue
        tt=t[m['da']:m['da']+m['n']]; p=tt.reshape(-1,3)
        dentro=np.zeros(len(p),bool); chi=set()
        for k in corpi:
            b=np.array(k['box']); lo=b[:3]+0.005; hi=b[:3]+b[3:]-0.005
            s=np.all((p>lo)&(p<hi),axis=1)
            if s.any(): chi.add(k['nodo'].split('/')[-1]+'%.0f%%'%(100*s.mean()))
            dentro|=s
        print(f"  {m['nodo'].split('/')[-1]:32s} vertici dentro un corpo: {100*dentro.mean():5.1f}%  {sorted(chi)}")
