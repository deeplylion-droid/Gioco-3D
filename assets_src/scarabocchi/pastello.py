"""Il tratto dei pastelli a cera, grosso (richiesta dell'utente del 28 ottobre: "nei muri più vuoti, di aggiungermi degli
scarabocchi a pastelli a cera, tratto grosso"). Stesso spirito del pannello dell'infermeria rifatto a pastello
(assets_src/ambienti_interni/poster/rovina.py, Pennarello.applica_pastello di grafica-2), ma su un livello trasparente
che va sul muro come decal:
- cera opaca: copre il muro (non lo moltiplica), il colore è quello del pastello;
- la grana: il pastello salta sui rilievi del muro, a granelli, più dove si preme poco (i bordi e la fine del tratto);
- bordi irregolari, il tratto che trema, segni ripassati più volte (ogni tratto si disegna 2-3 volte un po' spostato);
- sbiadito e rovinato dall'umidità dove il posto è bagnato (macchie larghe dove la cera è venuta via).
Solo disegni: niente lettere né numeri, niente frecce né cerchi colorati in fila (sembrerebbero indizi degli enigmi).
Le immagini fatte qui sono solo texture del gioco (non concept da mostrare).
"""
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

# i colori dei pastelli a cera di una scatola da 12, un po' spenti dal tempo
COLORI = {
    'rosso': (196, 38, 34), 'arancio': (226, 112, 30), 'giallo': (238, 196, 40), 'verde': (52, 140, 62),
    'verde_chiaro': (130, 190, 70), 'azzurro': (70, 150, 210), 'blu': (40, 70, 160), 'viola': (118, 58, 150),
    'rosa': (232, 120, 170), 'marrone': (120, 74, 40), 'nero': (28, 26, 30), 'bianco': (236, 232, 222),
}


def rumore(shape, seme, scala):
    """Rumore morbido (blob): rumore bianco ingrandito, tra 0 e 1."""
    rng = np.random.default_rng(seme)
    h, w = shape
    piccolo = rng.random((max(2, h // scala), max(2, w // scala))).astype(np.float32)
    im = Image.fromarray((piccolo * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
    return np.asarray(im, np.float32) / 255.0


class Pastello:
    """Un foglio trasparente di [w]x[h] pixel su cui si disegna coi pastelli; [mm] millimetri per pixel."""

    def __init__(self, w, h, seme, mm=2.4):
        self.w, self.h, self.mm = w, h, mm
        self.k = 2                       # si disegna a 2x e si riduce (bordi meno a scalini)
        self.rng = np.random.default_rng(seme)
        self.seme = seme
        # ogni colore su un livello suo (pressione 0-1), poi si mettono uno sopra l'altro nell'ordine dei tratti
        self.livelli = []                # [(colore, Image L)]

    def _livello(self, colore):
        if self.livelli and self.livelli[-1][0] == colore:
            return self.livelli[-1][1]
        im = Image.new('L', (self.w * self.k, self.h * self.k), 0)
        self.livelli.append((colore, im))
        return im

    def tratto(self, pts, colore, larg_mm=17.0, volte=2, trem=1.0, pressione=235):
        """Un segno di pastello lungo [pts] (in pixel), largo [larg_mm], ripassato [volte] volte un po' spostato."""
        im = self._livello(colore)
        d = ImageDraw.Draw(im)
        k = self.k
        lw = max(2, int(larg_mm / self.mm * k))
        for v in range(volte):
            sp = self.rng.normal(0, lw * 0.18, 2)
            pp = [(x * k + sp[0] + self.rng.normal(0, trem * k), y * k + sp[1] + self.rng.normal(0, trem * k)) for x, y in pts]
            p = int(pressione * (0.75 + 0.25 * self.rng.random()))
            for i in range(len(pp) - 1):
                # lo spessore cambia un po' lungo il tratto (la mano preme e alleggerisce)
                l = max(2, int(lw * (0.8 + 0.35 * self.rng.random())))
                d.line([pp[i], pp[i + 1]], fill=p, width=l)
                r = l / 2
                d.ellipse([pp[i][0] - r, pp[i][1] - r, pp[i][0] + r, pp[i][1] + r], fill=p)

    def linea(self, p0, p1, colore, larg_mm=14.0, curva=0.0, n=12, **kw):
        pts = []
        nx, ny = -(p1[1] - p0[1]), p1[0] - p0[0]
        for t in np.linspace(0, 1, n):
            b = math.sin(t * math.pi) * curva
            pts.append((p0[0] + (p1[0] - p0[0]) * t + nx * b, p0[1] + (p1[1] - p0[1]) * t + ny * b))
        self.tratto(pts, colore, larg_mm, **kw)

    def ovale(self, cx, cy, rx, ry, colore, larg_mm=14.0, giri=1.15, **kw):
        """Un tondo fatto a mano: non si chiude bene, va un po' oltre."""
        n = int(40 * giri)
        a0 = self.rng.uniform(0, 2 * math.pi)
        pts = [(cx + rx * (1 + self.rng.normal(0, 0.03)) * math.cos(a0 + 2 * math.pi * giri * i / n),
                cy + ry * (1 + self.rng.normal(0, 0.03)) * math.sin(a0 + 2 * math.pi * giri * i / n)) for i in range(n + 1)]
        self.tratto(pts, colore, larg_mm, **kw)

    def riempi(self, poligono, colore, larg_mm=12.0, passo_mm=10.0, ang=None, **kw):
        """Il riempimento dei bambini: un va e vieni fitto e storto dentro la forma (che a volte esce dal bordo)."""
        ang = self.rng.uniform(-0.6, 0.6) + 0.8 if ang is None else ang
        xs = [p[0] for p in poligono]
        ys = [p[1] for p in poligono]
        cx, cy = sum(xs) / len(xs), sum(ys) / len(ys)
        r = max(max(xs) - min(xs), max(ys) - min(ys))
        maschera = Image.new('L', (self.w, self.h), 0)
        ImageDraw.Draw(maschera).polygon(poligono, fill=255)
        m = np.asarray(maschera) > 0
        passo = passo_mm / self.mm
        u = (math.cos(ang), math.sin(ang))
        v = (-u[1], u[0])
        pts = []
        t = -r
        verso = 1
        while t < r:
            # il segmento della riga t dentro la forma
            dentro = []
            for s in np.linspace(-r, r, 60):
                x, y = cx + u[0] * s + v[0] * t, cy + u[1] * s + v[1] * t
                if 0 <= int(x) < self.w and 0 <= int(y) < self.h and m[int(y), int(x)]:
                    dentro.append((x, y))
            if dentro:
                a, b = dentro[0], dentro[-1]
                fuori = self.rng.uniform(-0.04, 0.08) * r
                a = (a[0] - u[0] * fuori, a[1] - u[1] * fuori)
                b = (b[0] + u[0] * fuori, b[1] + u[1] * fuori)
                pts += [a, b] if verso > 0 else [b, a]
                verso = -verso
            t += passo * self.rng.uniform(0.7, 1.3)
        if len(pts) > 1:
            self.tratto(pts, colore, larg_mm, volte=1, trem=1.5, **kw)

    def finisci(self, bagnato=0.0, sbiadito=0.0):
        """L'immagine RGBA: i colori uno sopra l'altro, la grana del muro, i bordi sfrangiati, l'umidità."""
        h, w = self.h, self.w
        rgb = np.zeros((h, w, 3), np.float32)
        alfa = np.zeros((h, w), np.float32)
        # la grana del muro (granelli fini e la trama un po' più grande)
        granelli = np.random.default_rng(self.seme + 1).random((h, w)).astype(np.float32)
        trama = rumore((h, w), self.seme + 2, 6)
        grana = granelli * 0.55 + trama * 0.45
        for colore, im in self.livelli:
            p = np.asarray(im.resize((w, h), Image.LANCZOS), np.float32) / 255.0
            # bordi irregolari: la pressione cala ai bordi del segno (sfocato) e la grana mangia di più lì
            morbido = np.asarray(im.resize((w, h), Image.LANCZOS).filter(ImageFilter.GaussianBlur(1.2)), np.float32) / 255.0
            pres = np.minimum(p, morbido * 1.15)
            soglia = 1.0 - pres
            q = np.clip((grana - soglia * 0.85) * 3.2, 0.0, 1.0) * (pres > 0.02)
            c = np.array(COLORI[colore] if isinstance(colore, str) else colore, np.float32) / 255.0
            # la cera più spessa è appena più scura e satura; sopra un altro colore lo copre (cera opaca)
            rgb = rgb * (1 - q[..., None]) + c * (0.92 + 0.08 * pres[..., None]) * q[..., None]
            alfa = alfa + q * (1 - alfa)
        if sbiadito > 0:
            alfa *= 1.0 - sbiadito
        if bagnato > 0:
            # macchie larghe dove l'umidità ha staccato la cera, e colature leggere verso il basso
            macchie = rumore((h, w), self.seme + 3, 90)
            colate = rumore((h, w // 6), self.seme + 4, 40)
            colate = np.asarray(Image.fromarray((colate * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC), np.float32) / 255.0
            giu = np.linspace(0.6, 1.0, h, dtype=np.float32)[:, None]
            via = np.clip((macchie * 0.7 + colate * 0.3 * giu - (1.0 - bagnato * 0.55)) * 4.0, 0.0, 0.85)
            alfa *= 1.0 - via
            rgb = rgb * (1.0 - 0.15 * bagnato) + 0.15 * bagnato * np.array([0.55, 0.5, 0.42], np.float32)
        out = np.dstack([np.clip(rgb, 0, 1), np.clip(alfa, 0, 1)])
        return Image.fromarray((out * 255).astype(np.uint8), 'RGBA')
