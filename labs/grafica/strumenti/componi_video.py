"""Unisce i fotogrammi PNG di Godot (--write-movie) in un MP4 e in una GIF leggera.
Uso: python componi_video.py <cartella_png> <uscita_senza_estensione>"""
import sys, glob
import imageio.v2 as imageio
from PIL import Image

cartella, uscita = sys.argv[1], sys.argv[2]
fotogrammi = sorted(glob.glob(f"{cartella}/*.png"))
with imageio.get_writer(uscita + ".mp4", fps=24, codec="libx264", bitrate="2500k", pixelformat="yuv420p",
                        macro_block_size=2) as w:
    for f in fotogrammi:
        w.append_data(imageio.imread(f)[:, :, :3])
# GIF: metà risoluzione, 12 fps
piccoli = [Image.open(f).convert("RGB").resize((427, 240), Image.LANCZOS) for f in fotogrammi[::2]]
piccoli[0].save(uscita + ".gif", save_all=True, append_images=piccoli[1:], duration=83, loop=0, optimize=True)
print("scritto", uscita + ".mp4", len(fotogrammi), "fotogrammi")
