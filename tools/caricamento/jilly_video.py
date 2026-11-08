#!/usr/bin/env python3
"""Il video di Jilly per la schermata di caricamento, dai fotogrammi del Movie Maker di Godot
(godot/scenes/ui/caricamento/registra_jilly.gd).

Prende il ciclo (CICLO secondi a FPS fotogrammi) a partire dal fotogramma dove comincia (lo stampa lo script di
registrazione: "JILLY: inizio del ciclo al fotogramma N") e fonde i fotogrammi della coda, registrati dopo il ciclo,
con i primi del ciclo: così il video gira senza giunte anche dove la scena non torna da sola (l'acqua, le luci che
sfarfallano). Poi lo codifica in Theora (ffmpeg, libtheora), il formato che Godot legge da solo.

Uso: jilly_video.py <cartella dei fotogrammi> <primo fotogramma del ciclo> <uscita.ogv> [qualita 0-10, 6]
      [scatti: una cartella dove salvare alcuni fotogrammi in JPG]
"""
import os
import subprocess
import sys
import tempfile

from PIL import Image

FPS = 24
CICLO = 8.0
CODA = 0.5

cartella, inizio, uscita = sys.argv[1], int(sys.argv[2]), sys.argv[3]
qualita = sys.argv[4] if len(sys.argv) > 4 else "6"
scatti = sys.argv[5] if len(sys.argv) > 5 else ""
nomi = sorted(f for f in os.listdir(cartella) if f.endswith(".png"))
n_ciclo = round(CICLO * FPS)
n_coda = round(CODA * FPS)
if inizio + n_ciclo + n_coda > len(nomi):
    sys.exit(f"mancano fotogrammi: {len(nomi)} in tutto, ne servono {inizio + n_ciclo + n_coda}")
with tempfile.TemporaryDirectory() as tmp:
    for i in range(n_ciclo):
        im = Image.open(os.path.join(cartella, nomi[inizio + i])).convert("RGB")
        if i < n_coda:
            # i primi fotogrammi: dalla coda (il seguito della fine del ciclo) all'inizio vero
            w = (i + 0.5) / n_coda
            coda = Image.open(os.path.join(cartella, nomi[inizio + n_ciclo + i])).convert("RGB")
            im = Image.blend(coda, im, w)
        im.save(os.path.join(tmp, f"{i:04d}.png"))
        if scatti and i % (FPS // 2) == 0:
            os.makedirs(scatti, exist_ok=True)
            im.save(os.path.join(scatti, f"jilly_{i / FPS:04.1f}s.jpg"), quality=90)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(FPS), "-i", os.path.join(tmp, "%04d.png"),
                    "-c:v", "libtheora", "-q:v", qualita, "-pix_fmt", "yuv420p", "-g", str(FPS * 2), uscita], check=True)
print(f"{uscita}: {n_ciclo} fotogrammi, {os.path.getsize(uscita) / 1e6:.2f} MB")
