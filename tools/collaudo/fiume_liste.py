# liste per giro.gd dal JSON della sonda della strada del fiume, nelle coordinate della risalita
import json, math, sys
d = json.load(open(sys.argv[1]))
C = (-35.0, -5.4, 92.0)        # CENTRO_FIUME, ruotato di -90 gradi
def W(p): return (C[0] - p[2], C[1] + p[1], C[2] + p[0])
def yaw(dx, dz):                # direzione locale -> yaw nel mondo (gradi; 0 guarda -z)
    wx, wz = -dz, dx
    return math.degrees(math.atan2(-wx, -wz))
def riga(n, p, y, pitch=-8):
    w = W(p); return "%s %.2f %.2f %.2f %.1f %d" % (n, w[0], w[1], w[2], y, pitch)
strada = []
# a piedi
def tratto_a_piedi(nome, a, b, passo=2.0):
    a = d['marker'][a]; b = d['marker'][b]
    L = math.dist(a, b); n = max(1, int(L / passo))
    dx, dz = b[0]-a[0], b[2]-a[2]
    for i in range(n + 1):
        t = i / n; p = [a[0]+dx*t, d['occhi_in_piedi'], a[2]+dz*t]
        y0 = yaw(dx, dz)
        for k, off in (('a', 0), ('d', -90), ('i', 180), ('s', 90)):
            strada.append(riga("%s%02d_%s" % (nome, i, k), p, y0 + off, -12))
tratto_a_piedi("piedi_fila", "Ingresso", "FineFila")
tratto_a_piedi("piedi_imbarco", "FineFila", "Imbarco")
tratto_a_piedi("piedi_porta", "Approdo", "PortaPersonale", 1.0)
# sulla ciambella: la camera 1,65 m sopra il punto del tratto
h = d['seduti']['camera'][1] - d['seduti']['punto'][1]
ordine = ["Imbarco", "Giusto1", "Giusto2", "Uscita", "Sbagliato1", "Sbagliato2", "Sbagliato3"]
tr = {t['nome']: t for t in d['tratti']}
for nome in ordine:
    for i, (s, p, dr) in enumerate(tr[nome]['punti']):
        q = [p[0], p[1] + h, p[2]]; y0 = yaw(dr[0], dr[2])
        for k, off in (('a', 0), ('d', -90), ('i', 180), ('s', 90)):
            strada.append(riga("cb_%s_%02d_%s" % (nome, i, k), q, y0 + off, -10))
open(sys.argv[2], 'w').write("\n".join(strada) + "\n")
# ravvicinati degli oggetti piccoli (non le pile, non la camera del giocatore, non il tetto)
mire = []
for o in d['piccoli']:
    if o.get('grande') or o['nodo'].startswith('Player') or '/Tetto' in o['nodo']:
        continue
    c = W(o['centro']); s = max(o['box'][1]); dist = max(0.6, s * 2.2)
    nome = o['nodo'].replace('Fiume/', '').replace('/', '_').replace('@', '')
    mire.append("mira %s %.3f %.3f %.3f %.2f" % (nome, c[0], c[1], c[2], dist))
open(sys.argv[3], 'w').write("\n".join(mire) + "\n")
print(len(strada), "scatti di strada,", len(mire), "mire")
