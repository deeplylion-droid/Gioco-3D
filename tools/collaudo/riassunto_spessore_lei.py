import json, collections, sys
for n in sys.argv[2:]:
    try: F = json.load(open(f'{sys.argv[1]}/sp_{n}.json'))
    except Exception as e: print(n, 'manca'); continue
    print('==', n)
    per = collections.defaultdict(list)
    for f in F: per[f['tag']].append(f)
    for tag, L in per.items():
        mx = max(L, key=lambda f: f['entrano'])
        dove = collections.Counter()
        for f in L:
            for k, v in f['dove'].items(): dove[k] = max(dove[k], v)
        print(f" {tag}: {len(L)} fot.; con tratti dentro {sum(1 for f in L if f['entrano'])}; max {mx['entrano']} tratti a {mx['t']} s; prof. max {max(f['max_cm'] for f in L)} cm; fine {L[-1]['entrano']}; {dict(dove)}")
        if mx['entrano']: print('    ', [e[:3] for e in mx['lista'][:4]])
