#!/usr/bin/env python3
"""Genera le texture procedurali dell'acqua. Sono tutte ripetibili (tileable) e create da zero
da questo script, quindi senza vincoli di licenza (CC0).

Uso (dalla radice del repository):
    /home/user/tools/blender-venv/bin/python labs/acqua/tools/genera_texture_acqua.py

Output in labs/acqua/water/textures/:
    water_normal_a.png   normal map delle onde lunghe (512x512, convenzione OpenGL)
    water_normal_b.png   normal map delle increspature fini (512x512)
    caustics_3d.png      caustiche fisiche animate: 64 fotogrammi 256x256 in una griglia 8x8,
                         importata come Texture3D (la terza dimensione e' il tempo, ciclo perfetto).
                         Valore = sqrt(intensita' / 5): media dell'intensita' = 1.
    foam.png             schiuma a bolle (512x512, scala di grigi)
    noise_rgba.png       rumori di servizio (512x512): R fbm largo, G fbm fine,
                         B bordi di celle (Worley), A valore casuale per cella
"""
import os
import time

import numpy as np
from PIL import Image

OUT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "water", "textures"))
os.makedirs(OUT, exist_ok=True)


def freq_grid(n):
    f = np.fft.fftfreq(n) * n  # cicli per tile, interi -> ripetibile
    kx, ky = np.meshgrid(f, f, indexing="xy")
    return kx, ky, np.sqrt(kx * kx + ky * ky)


def band(k, kmin, kmax, soft=0.25):
    lo = np.clip((k - kmin * (1 - soft)) / max(kmin * soft * 2, 1e-6), 0, 1)
    hi = np.clip((kmax * (1 + soft) - k) / max(kmax * soft * 2, 1e-6), 0, 1)
    return lo * hi


def spectral_field(n, kmin, kmax, power, rng):
    """Campo di altezza ripetibile e le sue derivate esatte (spettrali)."""
    kx, ky, k = freq_grid(n)
    amp = band(k, kmin, kmax) * np.power(np.maximum(k, 1e-6), -power)
    amp[0, 0] = 0
    spec = amp * (rng.normal(size=(n, n)) + 1j * rng.normal(size=(n, n)))
    h = np.real(np.fft.ifft2(spec))
    # derivate rispetto alle coordinate di tile (0..1)
    dx = np.real(np.fft.ifft2(spec * 2j * np.pi * kx))
    dy = np.real(np.fft.ifft2(spec * 2j * np.pi * ky))
    s = h.std()
    return h / s, dx / s, dy / s


def save_normal(path, dx, dy, slope_rms):
    """dx, dy = derivate dell'altezza lungo colonne e righe (righe verso il basso)."""
    g = np.sqrt(np.mean(dx * dx + dy * dy))
    sx = dx / g * slope_rms
    sy = -dy / g * slope_rms  # convenzione OpenGL: +Y verso l'alto dell'immagine
    nz = 1.0 / np.sqrt(1 + sx * sx + sy * sy)
    nx, ny = -sx * nz, -sy * nz
    rgb = np.stack([nx, ny, nz], -1) * 0.5 + 0.5
    Image.fromarray(np.clip(rgb * 255 + 0.5, 0, 255).astype(np.uint8), "RGB").save(path, optimize=True)


def normal_maps(rng):
    n = 512
    _, dx, dy = spectral_field(n, 1.5, 20, 2.2, rng)
    save_normal(os.path.join(OUT, "water_normal_a.png"), dx, dy, 0.55)
    _, dx, dy = spectral_field(n, 10, 120, 1.6, rng)
    save_normal(os.path.join(OUT, "water_normal_b.png"), dx, dy, 0.55)


def caustics(rng, size=256, frames=64, grid=8, photons=2048, depth=0.65, slope_rms=0.1, ior=1.333):
    """Caustiche fisiche: luce verticale rifratta da una superficie ondulata periodica
    (onde con vettori d'onda interi e frequenze intere -> ripetibile nello spazio e nel tempo),
    raccolta sul fondo a profondita' `depth` (in unita' di tile)."""
    t0 = time.time()
    n = photons
    # componenti d'onda casuali
    comps = []
    while len(comps) < 48:
        kx, ky = rng.integers(-14, 15, size=2)
        kk = np.hypot(kx, ky)
        if kk < 3.5 or kk > 14:
            continue
        if any((c[0] == kx and c[1] == ky) or (c[0] == -kx and c[1] == -ky) for c in comps):
            continue
        a = kk ** -1.9 * rng.uniform(0.6, 1.0)
        w = max(1, int(round(0.95 * np.sqrt(kk))))  # cicli per loop, circa la dispersione delle onde di gravita'
        if rng.random() < 0.5:
            w = -w
        comps.append((int(kx), int(ky), a, w, rng.uniform(0, 2 * np.pi)))
    # normalizza la pendenza rms
    srms = np.sqrt(sum(0.5 * (2 * np.pi * np.hypot(c[0], c[1]) * c[2]) ** 2 for c in comps))
    comps = [(c[0], c[1], c[2] * slope_rms / srms, c[3], c[4]) for c in comps]

    xs = (np.arange(n) + 0.5) / n
    X, Y = np.meshgrid(xs, xs, indexing="xy")
    eta = 1.0 / ior
    atlas = np.zeros((grid * size, grid * size), np.float32)
    for f in range(frames):
        t = f / frames
        spec = np.zeros((n, n), np.complex128)
        for kx, ky, a, w, ph in comps:
            c = 0.5 * a * np.exp(1j * (ph - 2 * np.pi * w * t))
            spec[ky % n, kx % n] += c * n * n
            spec[(-ky) % n, (-kx) % n] += np.conj(c) * n * n
        fx = np.fft.fftfreq(n) * n
        KX, KY = np.meshgrid(fx, fx, indexing="xy")
        h = np.real(np.fft.ifft2(spec))
        gx = np.real(np.fft.ifft2(spec * 2j * np.pi * KX))
        gy = np.real(np.fft.ifft2(spec * 2j * np.pi * KY))
        # normale della superficie (z in alto) e rifrazione di un raggio verticale verso il basso
        inv = 1.0 / np.sqrt(1 + gx * gx + gy * gy)
        nx, ny, nz = -gx * inv, -gy * inv, inv
        ix, iy, iz = 0.0, 0.0, -1.0
        cosi = -(nx * ix + ny * iy + nz * iz)
        k = 1 - eta * eta * (1 - cosi * cosi)
        tcoef = eta * cosi - np.sqrt(np.maximum(k, 0))
        tx = eta * ix + tcoef * nx
        ty = eta * iy + tcoef * ny
        tz = eta * iz + tcoef * nz
        dist = (depth + h) / np.maximum(-tz, 1e-3)
        px = (X + tx * dist) % 1.0
        py = (Y + ty * dist) % 1.0
        # splat bilineare con avvolgimento
        fxp = px * size - 0.5
        fyp = py * size - 0.5
        x0 = np.floor(fxp).astype(np.int64)
        y0 = np.floor(fyp).astype(np.int64)
        wx = fxp - x0
        wy = fyp - y0
        img = np.zeros(size * size, np.float64)
        for ox, oy, wgt in ((0, 0, (1 - wx) * (1 - wy)), (1, 0, wx * (1 - wy)), (0, 1, (1 - wx) * wy), (1, 1, wx * wy)):
            idx = ((y0 + oy) % size) * size + ((x0 + ox) % size)
            img += np.bincount(idx.ravel(), weights=wgt.ravel(), minlength=size * size)
        img = img.reshape(size, size)
        img /= img.mean()
        # leggera sfocatura periodica (riduce il rumore dei fotoni)
        F = np.fft.fft2(img)
        fk = np.fft.fftfreq(size)
        FX, FY = np.meshgrid(fk, fk, indexing="xy")
        sigma = 0.55
        F *= np.exp(-2 * (np.pi ** 2) * (sigma ** 2) * (FX ** 2 + FY ** 2))
        img = np.maximum(np.real(np.fft.ifft2(F)), 0)
        gxi, gyi = f % grid, f // grid
        atlas[gyi * size:(gyi + 1) * size, gxi * size:(gxi + 1) * size] = img
        if f % 8 == 0:
            print(f"  caustiche: fotogramma {f}/{frames}  max {img.max():.2f}  ({time.time() - t0:.0f}s)", flush=True)
    enc = np.sqrt(np.clip(atlas / 5.0, 0, 1))
    Image.fromarray(np.clip(enc * 255 + 0.5, 0, 255).astype(np.uint8), "L").save(os.path.join(OUT, "caustics_3d.png"), optimize=True)


def worley(n, cells, rng):
    """Distanze F1, F2 da punti casuali in una griglia periodica di celle; id della cella piu' vicina."""
    pts = rng.random((cells, cells, 2))
    ys, xs = np.mgrid[0:n, 0:n]
    u = (xs + 0.5) / n * cells
    v = (ys + 0.5) / n * cells
    cu, cv = np.floor(u).astype(int), np.floor(v).astype(int)
    f1 = np.full((n, n), 9.0)
    f2 = np.full((n, n), 9.0)
    cid = np.zeros((n, n))
    rnd = rng.random((cells, cells))
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            gx, gy = cu + dx, cv + dy
            p = pts[gy % cells, gx % cells]
            d = np.hypot(gx + p[..., 0] - u, gy + p[..., 1] - v)
            closer = d < f1
            f2 = np.where(closer, f1, np.minimum(f2, d))
            cid = np.where(closer, rnd[gy % cells, gx % cells], cid)
            f1 = np.where(closer, d, f1)
    return f1, f2, cid


def fbm(n, rng, kmin, kmax, power):
    h, _, _ = spectral_field(n, kmin, kmax, power, rng)
    h = (h - h.min()) / (h.max() - h.min())
    return h


def foam(rng):
    n = 512
    acc = np.zeros((n, n))
    for cells, w in ((10, 0.55), (22, 0.35), (46, 0.25)):
        f1, f2, _ = worley(n, cells, rng)
        edge = np.clip(1 - (f2 - f1) * 6.0, 0, 1) ** 2  # pareti delle bolle
        acc += edge * w
    acc /= acc.max()
    lo = fbm(n, rng, 2, 10, 1.5)
    acc = acc * (0.55 + 0.45 * lo)
    acc = np.clip(acc * 1.25, 0, 1)
    Image.fromarray((acc * 255 + 0.5).astype(np.uint8), "L").save(os.path.join(OUT, "foam.png"), optimize=True)


def noise_rgba(rng):
    n = 512
    r = fbm(n, rng, 1, 8, 1.8)
    g = fbm(n, rng, 6, 64, 1.4)
    f1, f2, cid = worley(n, 16, rng)
    b = np.clip((f2 - f1) * 2.0, 0, 1)
    a = cid
    img = np.stack([r, g, b, a], -1)
    Image.fromarray((img * 255 + 0.5).astype(np.uint8), "RGBA").save(os.path.join(OUT, "noise_rgba.png"), optimize=True)


if __name__ == "__main__":
    rng = np.random.default_rng(1997)
    print("normal map...")
    normal_maps(rng)
    print("schiuma e rumori...")
    foam(rng)
    noise_rgba(rng)
    print("caustiche...")
    caustics(rng)
    print("fatto:", OUT)
