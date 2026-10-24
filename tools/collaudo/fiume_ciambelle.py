import json, math, sys
d = json.load(open(sys.argv[1]))
C = (-35.0, -5.4, 92.0)
def W(p): return (C[0] - p[2], C[1] + p[1], C[2] + p[0])
h = d['seduti']['camera'][1] - d['seduti']['punto'][1]
righe = []
punti = [(t['nome'], i, p) for t in d['tratti'] if not t['sbagliato'] for i, (s, p, dr) in enumerate(t['punti'])]
for c in d['ciambelle']:
    n = c['nodo'].split('/')[-1]
    if n not in ('CiambellaRiva', 'CiambellaRiva2', 'CiambellaRiva3', 'ciambella6'): continue
    w = W(c['centro'])
    for dist in (0.6, 1.0, 1.8):
        righe.append("mira %s_%s %.3f %.3f %.3f %.2f" % (n, str(dist).replace('.', ''), w[0], w[1], w[2], dist))
    # dalla ciambella in corsa: i tre punti dei tratti giusti più vicini, guardando la ciambella
    vicini = sorted(punti, key=lambda q: math.dist([q[2][0], q[2][2]], [c['centro'][0], c['centro'][2]]))[:3]
    for nome, i, p in vicini:
        cam = W([p[0], p[1] + h, p[2]])
        dx, dy, dz = w[0] - cam[0], w[1] - cam[1], w[2] - cam[2]
        yaw = math.degrees(math.atan2(-dx, -dz)); pitch = math.degrees(math.atan2(dy, math.hypot(dx, dz)))
        righe.append("%s_dacorsa_%s%02d %.2f %.2f %.2f %.1f %.1f" % (n, nome, i, cam[0], cam[1], cam[2], yaw, pitch))
open(sys.argv[2], 'w').write("\n".join(righe) + "\n")
print(len(righe), "righe")
