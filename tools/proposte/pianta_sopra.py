"""Disegni sopra le piante (viste dall'alto prese in Godot da godot/tests/proposte_sala.gd) e fascia
con titolo: percorsi, punto d'arrivo, scia della tappa 8, cancello. Solo indicazioni grafiche sopra uno
screenshot vero del motore.

Uso: python3 tools/proposte/pianta_sopra.py <pianta.jpg> <log di godot con la riga PIANTA> <tipo> <uscita.jpg> [titolo] [sottotitolo]
  tipo: bimbi | torre_nord | torre_est
"""
import math, re, sys
from PIL import Image, ImageDraw, ImageFont

FONT_B = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
FONT_R = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
ROSSO, BLU, GIALLO, ROSA, BIANCO, NERO = (230, 40, 40), (40, 140, 255), (255, 210, 40), (255, 90, 190), (250, 250, 250), (15, 15, 15)


def font(px, bold=True):
    return ImageFont.truetype(FONT_B if bold else FONT_R, px)


class Pianta:
    def __init__(self, img, estensione):
        self.img = img.convert('RGB')
        self.W, self.H = self.img.size
        self.x0, self.x1, self.z0, self.z1 = estensione
        self.d = ImageDraw.Draw(self.img)

    def solo_dentro(self, rettangoli, colore=(22, 24, 28)):
        """Copre quello che sta fuori dalla sala (il cielo della tempesta visto dall'alto)."""
        maschera = Image.new('L', self.img.size, 255)
        dm = ImageDraw.Draw(maschera)
        for (x0, z0, x1, z1) in rettangoli:
            a, b = self.P(x0, z0), self.P(x1, z1)
            dm.rectangle([min(a[0], b[0]), min(a[1], b[1]), max(a[0], b[0]), max(a[1], b[1])], fill=0)
        self.img.paste(Image.new('RGB', self.img.size, colore), (0, 0), maschera)
        self.d = ImageDraw.Draw(self.img)

    def P(self, x, z):
        return ((x - self.x0) / (self.x1 - self.x0) * self.W, (z - self.z0) / (self.z1 - self.z0) * self.H)

    def linea(self, pts, col, w=8, tratteggio=0, contorno=True):
        q = [self.P(*p) for p in pts]
        if tratteggio:
            seg = []
            for a, b in zip(q, q[1:]):
                L = math.dist(a, b)
                n = max(1, int(L / tratteggio))
                for k in range(0, n, 2):
                    t0, t1 = k / n, min(1.0, (k + 1) / n)
                    seg.append(((a[0] + (b[0] - a[0]) * t0, a[1] + (b[1] - a[1]) * t0), (a[0] + (b[0] - a[0]) * t1, a[1] + (b[1] - a[1]) * t1)))
            for s in seg:
                if contorno:
                    self.d.line(s, fill=NERO, width=w + 6)
            for s in seg:
                self.d.line(s, fill=col, width=w)
        else:
            if contorno:
                self.d.line(q, fill=NERO, width=w + 6, joint='curve')
            self.d.line(q, fill=col, width=w, joint='curve')
        return q

    def freccia(self, pts, col, w=8, tratteggio=0):
        q = self.linea(pts, col, w, tratteggio)
        (ax, ay), (bx, by) = q[-2], q[-1]
        a = math.atan2(by - ay, bx - ax)
        L = 7 * w
        tri = [(bx + math.cos(a) * L * 0.4, by + math.sin(a) * L * 0.4),
               (bx + math.cos(a + 2.5) * L, by + math.sin(a + 2.5) * L),
               (bx + math.cos(a - 2.5) * L, by + math.sin(a - 2.5) * L)]
        self.d.polygon(tri, fill=col, outline=NERO, width=3)

    def punto(self, x, z, col, r=16):
        cx, cy = self.P(x, z)
        self.d.ellipse([cx - r - 4, cy - r - 4, cx + r + 4, cy + r + 4], fill=NERO)
        self.d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=col)

    def cono(self, x, z, tx, tz, apertura, lungo, col):
        cx, cy = self.P(x, z)
        a = math.atan2(self.P(tx, tz)[1] - cy, self.P(tx, tz)[0] - cx)
        h = math.radians(apertura / 2)
        L = lungo / (self.x1 - self.x0) * self.W
        pts = [(cx, cy), (cx + math.cos(a - h) * L, cy + math.sin(a - h) * L), (cx + math.cos(a + h) * L, cy + math.sin(a + h) * L)]
        sopra = Image.new('RGBA', self.img.size, (0, 0, 0, 0))
        ImageDraw.Draw(sopra).polygon(pts, fill=col + (45,), outline=col + (200,), width=3)
        self.img = Image.alpha_composite(self.img.convert('RGBA'), sopra).convert('RGB')
        self.d = ImageDraw.Draw(self.img)

    def etichetta(self, x, z, testo, col=BIANCO, px=34, dx=0, dy=0):
        cx, cy = self.P(x, z)
        f = font(px)
        b = self.d.textbbox((0, 0), testo, font=f)
        w, h = b[2] - b[0], b[3] - b[1]
        X, Y = cx + dx - w / 2, cy + dy - h / 2
        self.d.rounded_rectangle([X - 12, Y - 10, X + w + 12, Y + h + 14], radius=10, fill=(15, 15, 15))
        self.d.text((X, Y - b[1] + 2), testo, font=f, fill=col)


def a_capo(testo, f, larghezza):
    """Spezza il testo in righe che stanno nella larghezza (pixel) col font f."""
    d = ImageDraw.Draw(Image.new('RGB', (8, 8)))
    righe = []
    for par in testo.split('\n'):
        riga = ''
        for parola in par.split():
            prova = (riga + ' ' + parola).strip()
            if d.textlength(prova, font=f) <= larghezza or not riga:
                riga = prova
            else:
                righe.append(riga)
                riga = parola
        if riga:
            righe.append(riga)
    return righe


def con_fascia(img, titolo, sottotitolo, legenda=None):
    W, H = img.size
    t = max(34, int(W * 0.042)); st = max(24, int(W * 0.026)); lg = max(22, int(W * 0.024))
    righe = a_capo(sottotitolo, font(st, False), W * 0.94) if sottotitolo else []
    alto = int(t * 1.6 + len(righe) * st * 1.35 + 24)
    basso = int(lg * 2.2) if legenda else 0
    out = Image.new('RGB', (W, H + alto + basso), (16, 18, 22))
    out.paste(img, (0, alto))
    d = ImageDraw.Draw(out)
    x = int(W * 0.03)
    d.text((x, 14), titolo, font=font(t), fill=GIALLO)
    for i, r in enumerate(righe):
        d.text((x, int(14 + t * 1.45 + i * st * 1.35)), r, font=font(st, False), fill=(235, 235, 235))
    if legenda:
        cx = x
        y = H + alto + int(lg * 0.55)
        for col, testo in legenda:
            d.rectangle([cx, y + 4, cx + lg * 1.6, y + lg - 2], fill=col, outline=NERO)
            d.text((cx + lg * 2.0, y), testo, font=font(lg, False), fill=(235, 235, 235))
            cx += int(lg * 2.6 + d.textlength(testo, font=font(lg, False)) + lg * 1.4)
    return out


def estensione_da_log(log):
    for riga in open(log, errors='ignore'):
        m = re.search(r'PIANTA x (\S+) (\S+) z (\S+) (\S+)', riga)
        if m:
            return tuple(float(v) for v in m.groups())
    raise SystemExit('riga PIANTA non trovata in ' + log)


SCIA = [(-18.3, 2.9), (-18.3, -5.7), (-17.1, -7.1), (-16.3, -7.7)]


SALA = (-20.25, -24.25, 20.25, 20.25)


def bimbi(p):
    p.solo_dentro([SALA])
    p.linea(SCIA, ROSSO, 9, tratteggio=26)
    p.etichetta(-17.6, -4.2, 'scia tappa 8', ROSSO, 28)
    p.cono(-8.3, -4.0, -16.0, -13.2, 94, 3.6, (60, 150, 255))
    p.freccia([(-8.0, 0.0), (-8.0, -3.4)], BLU, 9)
    p.freccia([(-8.6, -5.2), (-8.9, -11.0), (-7.0, -13.8), (-5.8, -15.2)], BLU, 8, tratteggio=22)
    p.punto(-8.3, -4.0, BLU, 15)
    p.etichetta(-11.6, -3.0, 'arrivo (tappa 4)', BLU, 28)
    p.etichetta(-6.9, -17.4, 'spiaggia', (180, 220, 255), 28)
    return [(ROSSO, 'scia della tappa 8 (resta libera)'), (BLU, 'arrivo e strada verso la spiaggia')]


def torre(p, v):
    p.solo_dentro([SALA, (-11.0, -44.0, 11.0, -24.0) if v == 'nord' else (20.0, -26.0, 40.0, -4.0)])
    if v == 'nord':
        p.freccia([(-15.6, -8.6), (-12.0, -12.5), (-6.5, -17.5), (-1.5, -21.8)], ROSSO, 10)
        p.etichetta(-14.0, -6.4, 'tappa 8', ROSSO, 32)
        p.punto(0.0, -24.0, GIALLO, 18)
        p.etichetta(6.6, -24.2, 'cancello', GIALLO, 34)
        p.etichetta(0.0, -40.5, 'sala della torre', BIANCO, 36)
        p.linea([(0.0, -31.5), (0.0, -24.0), (-3.0, -19.0), (-9.5, -14.5), (-15.0, -10.0), (-16.5, -5.0), (-13.5, -1.0)], ROSA, 8, tratteggio=24)
    else:
        p.freccia([(-15.6, -8.6), (-10.0, -15.5), (0.0, -16.5), (10.0, -16.0), (18.4, -15.2)], ROSSO, 10)
        p.etichetta(-14.0, -6.4, 'tappa 8', ROSSO, 32)
        p.punto(20.0, -15.0, GIALLO, 18)
        p.etichetta(20.0, -20.2, 'portone', GIALLO, 34)
        p.etichetta(30.0, -24.0, 'sala della torre', BIANCO, 36)
        p.linea([(28.0, -15.0), (20.0, -9.0), (12.0, -21.5), (0.0, -21.5), (-12.0, -21.0), (-16.5, -10.0), (-13.5, -1.0)], ROSA, 8, tratteggio=24)
    return [(ROSSO, 'dopo la tappa 8, verso il cancello'), (GIALLO, 'cancello'), (ROSA, 'tubo dell\'inseguimento, solo indicativo')]


def main():
    img, log, tipo, uscita = sys.argv[1:5]
    titolo = sys.argv[5] if len(sys.argv) > 5 else ''
    sotto = sys.argv[6] if len(sys.argv) > 6 else ''
    p = Pianta(Image.open(img), estensione_da_log(log))
    legenda = bimbi(p) if tipo == 'bimbi' else torre(p, tipo.split('_')[1])
    con_fascia(p.img, titolo, sotto, legenda).save(uscita, quality=90)
    print('->', uscita)


if __name__ == '__main__':
    main()
