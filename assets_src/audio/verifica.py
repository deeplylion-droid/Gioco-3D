"""Controlli sui suoni generati: durata, picco, loudness, scatto al punto di loop e
spettrogramma in PNG (frequenze in scala logaritmica) per vedere com'è fatto un suono.
Uso: python verifica.py file.ogg [altri...] [--png cartella]
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import signal

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib_audio import SR, loop_click_check, lufs, lufs_max, mono, read_audio, to_db  # noqa: E402


def spettrogramma(x: np.ndarray, path: str, titolo: str = '', h: int = 256, w: int = 900) -> None:
    m = mono(x).astype(np.float64)
    nper = 2048
    f, t, S = signal.spectrogram(m, SR, nperseg=nper, noverlap=nper - max(1, len(m) // w), mode='magnitude')
    S = 20 * np.log10(S + 1e-9)
    # asse delle frequenze logaritmico da 30 Hz a 20 kHz
    fl = np.geomspace(30, 20000, h)
    rows = np.array([np.interp(fl, f, S[:, j]) for j in range(S.shape[1])]).T
    # pesatura: compensa la pendenza naturale (-3 dB/ottava) per leggere meglio le acute
    rows = rows + 3.0 * np.log2(fl / 1000.0)[:, None]
    top = np.percentile(rows, 99.5)
    v = np.clip((rows - (top - 60)) / 60, 0, 1)[::-1]
    # palette tipo "inferno": nero, viola, arancio, giallo
    stops = np.array([[0, 0, 4], [87, 16, 110], [188, 55, 84], [249, 142, 9], [252, 255, 164]], dtype=float)
    pos = v * (len(stops) - 1)
    i0 = np.clip(np.floor(pos).astype(int), 0, len(stops) - 2)
    fr = (pos - i0)[..., None]
    rgbarr = (stops[i0] * (1 - fr) + stops[i0 + 1] * fr).astype(np.uint8)
    rgb = Image.fromarray(rgbarr, 'RGB').resize((w, h))
    canvas = Image.new('RGB', (w + 160, h + 60), (20, 20, 24))
    canvas.paste(rgb, (0, 0))
    d = ImageDraw.Draw(canvas)
    # spettro medio a destra (dB, compensato)
    avg = rows.mean(axis=1)[::-1]
    lo_, hi_ = avg.max() - 50, avg.max()
    pts = [(w + 5 + int(150 * np.clip((a - lo_) / (hi_ - lo_), 0, 1)), y) for y, a in
           zip(np.linspace(0, h - 1, h).astype(int), avg)]
    d.line(pts, fill=(255, 255, 255))
    # forma d'onda sotto
    env = np.abs(m)
    k = max(1, len(env) // w)
    env = env[:k * w].reshape(w, k).max(axis=1) if len(env) >= w else np.interp(np.linspace(0, len(env) - 1, w), np.arange(len(env)), env)
    for i, v in enumerate(env):
        y = int(min(1.0, v) * 28)
        d.line([(i, h + 30 - y), (i, h + 30 + y)], fill=(120, 200, 220))
    for fr in [100, 1000, 10000]:
        y = int(h - (np.log(fr / 30) / np.log(20000 / 30)) * h)
        d.line([(0, y), (12, y)], fill=(255, 255, 255))
        d.text((14, y - 6), f'{fr} Hz', fill=(255, 255, 255))
    d.text((4, h + 46), f'{titolo}  {len(m) / SR:.2f} s', fill=(230, 230, 230))
    canvas.save(path)


def main() -> None:
    args = sys.argv[1:]
    png_dir = None
    if '--png' in args:
        i = args.index('--png')
        png_dir = args[i + 1]
        args = args[:i] + args[i + 2:]
        os.makedirs(png_dir, exist_ok=True)
    for p in args:
        x = read_audio(p, 2)
        n = os.path.basename(p)
        loop = loop_click_check(x) if 'loop' in n else 0.0
        mx = np.abs(x).max()
        print(f'{n:38s} {len(x) / SR:6.2f}s picco {to_db(mx):6.1f} dB  LUFS {lufs(x):6.1f}  maxM {lufs_max(x):6.1f}'
              + (f'  scatto loop {loop:5.1f}' if loop else ''))
        if png_dir:
            spettrogramma(x, os.path.join(png_dir, n.replace('.ogg', '.png').replace('.wav', '.png')), n)


if __name__ == '__main__':
    main()
