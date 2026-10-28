# Dai risultati di sonda_polaroid.gd (righe "POLAROID: pNN Pn in (x, y, z), fondo f ...") le liste dei punti per giro.gd:
# per ogni Polaroid nuova quattro viste radenti (35 cm, 4 cm sopra il fondo), una dall'alto e una dagli occhi, più "mira".
# Uso: python3 punti_polaroid.py <log> <cartella uscita>
import re, sys, math, os
log, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
scena = {"p12": "torre", "p13": "risalita", "p15": "risalita", "p16": "risalita", "p14": "sala"}
liste = {}
for r in open(log):
    m = re.search(r"POLAROID: (p1[2-6]) P\d+ in \(([-\d.]+), ([-\d.]+), ([-\d.]+)\), fondo ([-\d.]+)", r)
    if not m:
        continue
    pid = m.group(1); x, y, z, f = map(float, m.group(2, 3, 4, 5))
    righe = liste.setdefault(scena[pid], [])
    if any(l.startswith(pid + "_") for l in righe):
        continue
    def vista(nome, cx, cy, cz, fov=50):
        dx, dy, dz = x - cx, f + 0.004 - cy, z - cz
        yaw = math.degrees(math.atan2(-dx, -dz)); pitch = math.degrees(math.atan2(dy, math.hypot(dx, dz)))
        righe.append("%s_%s %.3f %.3f %.3f %.1f %.1f %d" % (pid, nome, cx, cy, cz, yaw, pitch, fov))
    for k, nome in enumerate(["radente_n", "radente_e", "radente_s", "radente_o"]):
        a = math.radians(90 * k)
        vista(nome, x + 0.35 * math.sin(a), f + 0.04, z + 0.35 * math.cos(a), 40)
    vista("alto", x + 0.15, f + 0.5, z + 0.15, 45)
    for k, nome in enumerate(["occhi_1", "occhi_2"]):
        a = math.radians(45 + 180 * k)
        vista(nome, x + 1.1 * math.sin(a), f + 1.6, z + 1.1 * math.cos(a), 60)
    righe.append("mira %s_mira %.3f %.3f %.3f 0.4" % (pid, x, f + 0.01, z))
for s, righe in liste.items():
    open(os.path.join(out, "punti_%s.txt" % s), "w").write("\n".join(righe) + "\n")
    print(s, len(righe), "righe")
