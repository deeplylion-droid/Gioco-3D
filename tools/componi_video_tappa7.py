"""Monta i fotogrammi PNG di Godot (--write-movie) in un MP4 (H.264, 24 fps) con ffmpeg, saltando i primi
fotogrammi del caricamento della scena (quelli prima della luce del blackout: si riconoscono perché non sono rossi).
Fa anche un foglio con 8 fotogrammi in fila, per guardarlo senza video.
Uso: /home/user/tools/blender-venv/bin/python tools/componi_video_tappa7.py <cartella_png> <uscita_senza_estensione> [fotogrammi]
(fotogrammi: quanti tenerne dopo il caricamento, per tagliare la coda)"""
import glob, os, subprocess, sys
from PIL import Image, ImageStat

cartella, uscita = sys.argv[1], sys.argv[2]
fs = sorted(glob.glob(os.path.join(cartella, 'f*.png')))
quanti = int(sys.argv[3]) if len(sys.argv) > 3 else None
inizio = 0
for i, f in enumerate(fs):
    r, g, b = ImageStat.Stat(Image.open(f).convert('RGB').resize((64, 36))).mean
    if r > 1.6 * b and r > 20:
        inizio = i + 2   # due fotogrammi di margine: la luce si sta ancora assestando
        break
if quanti:
    fs = fs[:inizio + quanti]
os.makedirs(os.path.dirname(uscita), exist_ok=True)
subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-framerate', '24', '-start_number', str(inizio),
                '-i', os.path.join(cartella, 'f%08d.png'), '-frames:v', str(len(fs) - inizio), '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '22',
                '-movflags', '+faststart', uscita + '.mp4'], check=True)
scelti = [fs[inizio + k * (len(fs) - 1 - inizio) // 7] for k in range(8)]
ims = [Image.open(f).convert('RGB').resize((480, 270)) for f in scelti]
foglio = Image.new('RGB', (1920, 540))
for k, im in enumerate(ims):
    foglio.paste(im, ((k % 4) * 480, (k // 4) * 270))
foglio.save(uscita + '_fotogrammi.jpg', quality=88)
print(uscita + '.mp4', len(fs) - inizio, 'fotogrammi da', inizio, f'({(len(fs) - inizio) / 24:.1f} s)')
