import json, sys, collections
S = sys.argv[1]
righe = collections.OrderedDict()
for scena in ('sala_principale', 'torre'):
    for e in json.load(open(f'{S}/tex/inv_{scena}.json')):
        m = e['materiale']
        if m['classe'] == 'ShaderMaterial':
            texs = sorted(v for k, v in m.get('parametri', {}).items() if isinstance(v, str) and v.startswith('res://'))
            firma = ('shader', m.get('shader', ''), tuple(texs))
        else:
            firma = ('std', m.get('albedo', ''), m.get('normal', ''))
        if firma == ('std', '', '') :
            firma = ('colore', m.get('colore'), m.get('nome'))
        r = righe.setdefault(firma, {'materiali': [], 'av': 0.0, 'ao': 0.0, 'zone': collections.Counter(), 'punti': [], 'nodi': []})
        r['materiali'].append(m)
        r['av'] += e['area_verticale']; r['ao'] += e['area_orizzontale']
        for n in e['nodi']:
            z = ('Torre/' if scena == 'torre' else '') + '/'.join(n.split('/')[:2])
            r['zone'][z] += 1
        if e['punto']:
            r['punti'].append((e['max'], e['punto'], e['normale'], e['nodi'][0] if e['nodi'] else '', scena))
        r['nodi'] += e['nodi'][:3]
out = []
for firma, r in righe.items():
    m0 = r['materiali'][0]
    out.append({'firma': list(firma), 'area_verticale': round(r['av'], 1), 'area_orizzontale': round(r['ao'], 1),
                'zone': dict(r['zone'].most_common(8)), 'esempio': m0, 'quanti': len(r['materiali']),
                'punto': max(r['punti'])[1:] if r['punti'] else None})
out.sort(key=lambda x: -x['area_verticale'])
json.dump(out, open(f'{S}/tex/riassunto.json', 'w'), indent=1)
for o in out[:60]:
    m = o['esempio']
    tex = m.get('albedo') or ','.join(o['firma'][2]) if o['firma'][0] == 'shader' else m.get('albedo')
    print(f"{o['area_verticale']:8.1f} m² vert {o['area_orizzontale']:7.1f} oriz | {o['firma'][0]:6s} {str(o['firma'][1])[-45:]:45s} | {str(tex)[-60:]:60s} | ns {m.get('normal_scale','')} uv {m.get('uv1_scale','')} tri {m.get('triplanare','')} | {list(o['zone'])[:3]}")
