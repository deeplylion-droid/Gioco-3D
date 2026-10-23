# Versione semplificata di un materiale (proposta, fuori dal gioco): stesso colore e stessa idea, molto più calma.
# - albedo: via le macchie piccole e i dettagli fitti (passa-basso), contrasto molto più basso, un filo della grana
#   di prima per non farla di plastica;
# - normal: rilievo al [rilievo] (30-50%) e ammorbidito;
# - roughness: più uniforme.
# Uso: python semplifica.py <albedo> <normal|-> <rough|-> <cartella di uscita> [contrasto 0.45] [rilievo 0.4] [raggio 0.012] [grana 0.15]
import sys, os, numpy as np
from PIL import Image, ImageFilter

al, nr, rg, out = sys.argv[1:5]
contrasto = float(sys.argv[5]) if len(sys.argv) > 5 else 0.45
rilievo = float(sys.argv[6]) if len(sys.argv) > 6 else 0.4
raggio = float(sys.argv[7]) if len(sys.argv) > 7 else 0.012   # frazione del lato della texture
grana = float(sys.argv[8]) if len(sys.argv) > 8 else 0.15
os.makedirs(out, exist_ok=True)


def sfoca_ripetuta(im, r):
    # sfocatura che rispetta la ripetizione: si sfoca la texture affiancata 3x3 e si prende il centro
    w, h = im.size
    big = Image.new(im.mode, (w * 3, h * 3))
    for i in range(3):
        for j in range(3):
            big.paste(im, (i * w, j * h))
    big = big.filter(ImageFilter.GaussianBlur(r))
    return big.crop((w, h, 2 * w, 2 * h))


def nome(p, suff):
    b = os.path.splitext(os.path.basename(p))[0]
    return os.path.join(out, b + suff)


A = Image.open(al).convert('RGB')
w, h = A.size
r = max(1.0, raggio * w)
basso = np.asarray(sfoca_ripetuta(A, r), dtype=np.float32)
fine = np.asarray(A, dtype=np.float32) - basso
media = basso.reshape(-1, 3).mean(0)
# variazione larga ridotta, dettaglio fine quasi tolto
nuovo = media + (basso - media) * contrasto + fine * grana
Image.fromarray(np.clip(nuovo, 0, 255).astype(np.uint8)).save(nome(al, '_calmo.jpg'), quality=92)

if nr != '-' and os.path.exists(nr):
    N = Image.open(nr).convert('RGB')
    Nb = np.asarray(sfoca_ripetuta(N, max(1.0, r * 0.5)), dtype=np.float32) / 127.5 - 1
    xy = Nb[..., :2] * rilievo
    z = np.sqrt(np.clip(1 - (xy ** 2).sum(-1), 0, 1))
    n = np.dstack([xy, z])
    Image.fromarray(np.clip((n + 1) * 127.5, 0, 255).astype(np.uint8)).save(nome(nr, '_calmo.jpg'), quality=95)

if rg != '-' and os.path.exists(rg):
    G = Image.open(rg).convert('RGB')
    Gb = np.asarray(sfoca_ripetuta(G, r), dtype=np.float32)
    gm = Gb.reshape(-1, 3).mean(0)
    Image.fromarray(np.clip(gm + (Gb - gm) * 0.5, 0, 255).astype(np.uint8)).save(nome(rg, '_calmo.jpg'), quality=92)
print('fatto', al)
