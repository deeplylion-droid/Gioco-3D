"""Libreria di sintesi e trattamento audio per Jilly Jubilee (numpy + scipy + ffmpeg).

Tutto lavora a 44100 Hz, in float32. I segnali mono sono array 1D, quelli stereo (n, 2).
Strumenti: rumori, filtri (anche variabili nel tempo), risonatori e sintesi modale,
inviluppi, riverbero a convoluzione con risposta all'impulso sintetica, saturazione,
varispeed (rallentamento "a nastro" con wow e flutter), loop senza scatti, loudness
(ITU-R BS.1770, K-weighting) e scrittura in OGG Vorbis con ffmpeg.
"""
from __future__ import annotations

import os
import subprocess
import tempfile

import numpy as np
from scipy import signal
from scipy.io import wavfile

SR = 44100


# --- base -----------------------------------------------------------------------------------

def n_of(dur: float) -> int:
    return int(round(dur * SR))


def t_axis(n: int) -> np.ndarray:
    return (np.arange(n, dtype=np.float64) / SR)


def silence(dur: float, stereo: bool = False) -> np.ndarray:
    n = n_of(dur)
    return np.zeros((n, 2) if stereo else n, dtype=np.float32)


def db(x: float) -> float:
    return float(10.0 ** (x / 20.0))


def to_db(x: float) -> float:
    return float(20.0 * np.log10(max(x, 1e-12)))


def f32(x) -> np.ndarray:
    return np.asarray(x, dtype=np.float32)


def mono(x: np.ndarray) -> np.ndarray:
    return x.mean(axis=1) if x.ndim == 2 else x


def stereo(x: np.ndarray) -> np.ndarray:
    return x if x.ndim == 2 else np.stack([x, x], axis=1)


def pad_to(x: np.ndarray, n: int) -> np.ndarray:
    if len(x) >= n:
        return x[:n]
    shape = (n - len(x),) + x.shape[1:]
    return np.concatenate([x, np.zeros(shape, dtype=x.dtype)])


def mix_into(dst: np.ndarray, src: np.ndarray, start: int, gain: float = 1.0) -> None:
    """Somma src in dst a partire dal campione start (taglia ai bordi)."""
    if start >= len(dst):
        return
    s0 = 0
    if start < 0:
        s0 = -start
        start = 0
    n = min(len(src) - s0, len(dst) - start)
    if n <= 0:
        return
    seg = src[s0:s0 + n] * gain
    if dst.ndim == 2 and seg.ndim == 1:
        seg = seg[:, None]
    dst[start:start + n] += seg


# --- rumori ---------------------------------------------------------------------------------

def white(n: int, rng: np.random.Generator) -> np.ndarray:
    return rng.standard_normal(n).astype(np.float32)


def colored(n: int, rng: np.random.Generator, slope_db_oct: float = -3.0, fmin: float | None = None) -> np.ndarray:
    """Rumore con pendenza spettrale data (-3 dB/ott = rosa, -6 = marrone).
    Con fmin lo spettro è piatto sotto fmin: l'energia resta nella banda udibile."""
    X = np.fft.rfft(rng.standard_normal(n))
    f = np.fft.rfftfreq(n, 1.0 / SR)
    f[0] = f[1]
    if fmin:
        f = np.maximum(f, fmin)
        X[0] = 0.0
    X *= (f / 1000.0) ** (slope_db_oct / 6.0206)
    y = np.fft.irfft(X, n)
    y -= y.mean()
    return f32(y / (np.std(y) + 1e-12))


def pink(n, rng):
    return colored(n, rng, -3.0)


def brown(n, rng):
    return colored(n, rng, -6.0)


def smooth_noise(n: int, rate_hz: float, rng: np.random.Generator, octaves: int = 1) -> np.ndarray:
    """Curva casuale lenta (circa -1..1) per modulazioni: rumore interpolato a coseno."""
    out = np.zeros(n, dtype=np.float64)
    amp = 1.0
    total = 0.0
    for o in range(octaves):
        r = rate_hz * (2 ** o)
        k = max(int(n / SR * r) + 3, 4)
        pts = rng.uniform(-1, 1, k)
        x = np.arange(n) / SR * r
        i = np.floor(x).astype(int)
        fr = x - i
        fr = (1 - np.cos(fr * np.pi)) * 0.5
        out += amp * (pts[i] * (1 - fr) + pts[np.minimum(i + 1, k - 1)] * fr)
        total += amp
        amp *= 0.5
    return f32(out / total)


# --- filtri ---------------------------------------------------------------------------------

def _sos(kind, f, order=2):
    return signal.butter(order, f, kind, fs=SR, output='sos')


def lp(x, fc, order=2):
    fc = min(fc, SR * 0.49)
    return f32(signal.sosfilt(_sos('low', fc, order), x, axis=0))


def hp(x, fc, order=2):
    return f32(signal.sosfilt(_sos('high', fc, order), x, axis=0))


def bp(x, lo, hi, order=2):
    hi = min(hi, SR * 0.49)
    return f32(signal.sosfilt(_sos('band', [lo, hi], order), x, axis=0))


def biquad_coefs(kind: str, f0: float, q: float = 0.707, gain_db: float = 0.0):
    """Coefficienti RBJ (cookbook). kind: peak, lowshelf, highshelf, bandpass, notch, lowpass, highpass."""
    A = 10 ** (gain_db / 40.0)
    w0 = 2 * np.pi * min(f0, SR * 0.49) / SR
    cw, sw = np.cos(w0), np.sin(w0)
    alpha = sw / (2 * q)
    if kind == 'peak':
        b = [1 + alpha * A, -2 * cw, 1 - alpha * A]
        a = [1 + alpha / A, -2 * cw, 1 - alpha / A]
    elif kind == 'lowshelf':
        sa = 2 * np.sqrt(A) * alpha
        b = [A * ((A + 1) - (A - 1) * cw + sa), 2 * A * ((A - 1) - (A + 1) * cw), A * ((A + 1) - (A - 1) * cw - sa)]
        a = [(A + 1) + (A - 1) * cw + sa, -2 * ((A - 1) + (A + 1) * cw), (A + 1) + (A - 1) * cw - sa]
    elif kind == 'highshelf':
        sa = 2 * np.sqrt(A) * alpha
        b = [A * ((A + 1) + (A - 1) * cw + sa), -2 * A * ((A - 1) + (A + 1) * cw), A * ((A + 1) + (A - 1) * cw - sa)]
        a = [(A + 1) - (A - 1) * cw + sa, 2 * ((A - 1) - (A + 1) * cw), (A + 1) - (A - 1) * cw - sa]
    elif kind == 'bandpass':   # guadagno 0 dB al centro
        b = [alpha, 0.0, -alpha]
        a = [1 + alpha, -2 * cw, 1 - alpha]
    elif kind == 'notch':
        b = [1, -2 * cw, 1]
        a = [1 + alpha, -2 * cw, 1 - alpha]
    elif kind == 'lowpass':
        b = [(1 - cw) / 2, 1 - cw, (1 - cw) / 2]
        a = [1 + alpha, -2 * cw, 1 - alpha]
    elif kind == 'highpass':
        b = [(1 + cw) / 2, -(1 + cw), (1 + cw) / 2]
        a = [1 + alpha, -2 * cw, 1 - alpha]
    else:
        raise ValueError(kind)
    b = np.array(b) / a[0]
    a = np.array(a) / a[0]
    return b, a


def biquad(x, kind, f0, q=0.707, gain_db=0.0):
    b, a = biquad_coefs(kind, f0, q, gain_db)
    return f32(signal.lfilter(b, a, x, axis=0))


def eq(x, bands):
    """bands: lista di (kind, f0, q, gain_db)."""
    for k, f0, q, g in bands:
        x = biquad(x, k, f0, q, g)
    return x


def tv_biquad(x: np.ndarray, kind: str, f0_curve, q_curve, gain_curve=None, block: int = 128) -> np.ndarray:
    """Biquad con parametri che cambiano nel tempo (curve campione per campione o costanti).
    Elabora a blocchi portando avanti lo stato del filtro (forma diretta II trasposta)."""
    x = np.asarray(x, dtype=np.float64)
    n = len(x)
    f0c = np.broadcast_to(np.asarray(f0_curve, dtype=np.float64), (n,))
    qc = np.broadcast_to(np.asarray(q_curve, dtype=np.float64), (n,))
    gc = np.broadcast_to(np.asarray(0.0 if gain_curve is None else gain_curve, dtype=np.float64), (n,))
    y = np.zeros_like(x)
    z = np.zeros((2,) + x.shape[1:])
    for s in range(0, n, block):
        e = min(s + block, n)
        m = (s + e) // 2
        b, a = biquad_coefs(kind, f0c[m], qc[m], gc[m])
        y[s:e], z = signal.lfilter(b, a, x[s:e], axis=0, zi=z)
    return f32(y)


def resonator_bank(exc: np.ndarray, freqs, decays, gains) -> np.ndarray:
    """Sintesi modale: l'eccitazione passa in un banco di risonatori a due poli.
    decays = tempo (s) per scendere di 60 dB."""
    exc = np.asarray(exc, dtype=np.float64)
    out = np.zeros_like(exc)
    for f, d, g in zip(freqs, decays, gains):
        if f >= SR * 0.47:
            continue
        r = 10 ** (-3.0 / (max(d, 1e-4) * SR))
        w = 2 * np.pi * f / SR
        a = [1.0, -2 * r * np.cos(w), r * r]
        b = [(1 - r * r) * 0.5, 0.0, -(1 - r * r) * 0.5]
        out += g * signal.lfilter(b, a, exc, axis=0)
    return f32(out)


def comb(x, delay_s, feedback, damp=0.0):
    """Filtro a pettine con retroazione (risonanza di un tubo)."""
    d = max(1, int(round(delay_s * SR)))
    a = np.zeros(d + 1)
    a[0] = 1.0
    a[d] = -feedback
    y = signal.lfilter([1.0], a, x, axis=0)
    if damp > 0:
        y = lp(y, 20000 * (1 - damp) + 500)
    return f32(y)


# --- inviluppi -----------------------------------------------------------------------------

def env_points(points, n: int, curve: str = 'lin') -> np.ndarray:
    """points: [(tempo_s, valore), ...]. Interpolazione lineare (o 'exp' in dB)."""
    t = t_axis(n)
    ts = np.array([p[0] for p in points], dtype=np.float64)
    vs = np.array([p[1] for p in points], dtype=np.float64)
    if curve == 'exp':
        vdb = 20 * np.log10(np.maximum(vs, 1e-5))
        return f32(10 ** (np.interp(t, ts, vdb) / 20.0) * (np.interp(t, ts, vs) > 1e-5))
    return f32(np.interp(t, ts, vs))


def env_ad(n: int, attack: float, decay60: float) -> np.ndarray:
    """Attacco lineare e decadimento esponenziale (decay60 = secondi per -60 dB)."""
    t = t_axis(n)
    a = np.clip(t / max(attack, 1e-5), 0, 1)
    d = 10 ** (-3.0 * np.maximum(t - attack, 0) / max(decay60, 1e-4))
    return f32(a * d)


def fade(x: np.ndarray, fin: float = 0.0, fout: float = 0.0) -> np.ndarray:
    x = x.copy()
    n = len(x)
    if fin > 0:
        k = min(n, n_of(fin))
        g = np.sin(np.linspace(0, np.pi / 2, k)) ** 2
        x[:k] *= g if x.ndim == 1 else g[:, None]
    if fout > 0:
        k = min(n, n_of(fout))
        g = np.cos(np.linspace(0, np.pi / 2, k)) ** 2
        x[n - k:] *= g if x.ndim == 1 else g[:, None]
    return x


def trim_silence(x: np.ndarray, thresh_db: float = -60.0, tail: float = 0.02) -> np.ndarray:
    a = np.abs(mono(x))
    th = db(thresh_db) * (a.max() + 1e-12)
    idx = np.nonzero(a > th)[0]
    if len(idx) == 0:
        return x
    end = min(len(x), idx[-1] + n_of(tail))
    return fade(x[:end], 0.0, min(tail, 0.01))


# --- dinamica e distorsione ----------------------------------------------------------------

def soft_clip(x, drive: float = 1.0):
    return f32(np.tanh(x * drive) / np.tanh(drive))


def bitcrush(x, bits: int = 8, downsample: int = 1):
    q = 2 ** (bits - 1)
    y = np.round(x * q) / q
    if downsample > 1:
        y = np.repeat(y[::downsample], downsample, axis=0)[:len(x)]
    return f32(y)


def limiter(x: np.ndarray, ceiling_db: float = -1.0, release: float = 0.06, lookahead: float = 0.005) -> np.ndarray:
    """Limitatore di picco: guadagno = minimo su una finestra (lookahead), poi lisciato.
    La finestra del minimo è più larga di quella della media, così i picchi restano sotto."""
    from scipy.ndimage import minimum_filter1d, uniform_filter1d
    c = db(ceiling_db)
    a = np.abs(x).max(axis=1) if x.ndim == 2 else np.abs(x)
    need = np.minimum(1.0, c / np.maximum(a, 1e-9))
    la = max(2, n_of(lookahead))
    rel = max(la + 2, n_of(release))
    # minimo sulla finestra [i - rel, i + la]: anticipa i picchi e li tiene per il rilascio
    g = minimum_filter1d(need, size=rel + la + 1, origin=(rel - la) // 2, mode='nearest')
    g = uniform_filter1d(g, size=la, mode='nearest')
    # risalita graduale: mai sopra la curva tenuta
    g = np.minimum(g, uniform_filter1d(g, size=rel, mode='nearest'))
    y = x * (g[:, None] if x.ndim == 2 else g)
    return f32(np.clip(y, -c, c))


def normalize_peak(x, peak_db: float = -1.0):
    p = np.abs(x).max()
    return f32(x * (db(peak_db) / p)) if p > 0 else x


# --- loudness (ITU-R BS.1770-4) -------------------------------------------------------------

def _k_weight(x):
    # filtro 1: mensola alta; filtro 2: passa-alto RLB (coefficienti ricalcolati per 44,1 kHz)
    G, Q, fc = 3.99984385397, 0.7071752369554193, 1681.974450955533
    A = 10 ** (G / 40)
    w0 = 2 * np.pi * fc / SR
    alpha = np.sin(w0) / (2 * Q)
    cw = np.cos(w0)
    b = [A * ((A + 1) + (A - 1) * cw + 2 * np.sqrt(A) * alpha), -2 * A * ((A - 1) + (A + 1) * cw),
         A * ((A + 1) + (A - 1) * cw - 2 * np.sqrt(A) * alpha)]
    a = [(A + 1) - (A - 1) * cw + 2 * np.sqrt(A) * alpha, 2 * ((A - 1) - (A + 1) * cw),
         (A + 1) - (A - 1) * cw - 2 * np.sqrt(A) * alpha]
    y = signal.lfilter(np.array(b) / a[0], np.array(a) / a[0], x, axis=0)
    Q2, fc2 = 0.5003270373253953, 38.13547087613982
    w0 = 2 * np.pi * fc2 / SR
    alpha = np.sin(w0) / (2 * Q2)
    cw = np.cos(w0)
    b = [(1 + cw) / 2, -(1 + cw), (1 + cw) / 2]
    a = [1 + alpha, -2 * cw, 1 - alpha]
    return signal.lfilter(np.array(b) / a[0], np.array(a) / a[0], y, axis=0)


def _ms_blocks(x, win: float, hop: float):
    y = _k_weight(np.asarray(x, dtype=np.float64))
    if y.ndim == 1:
        y = y[:, None]
    p = (y ** 2).sum(axis=1)
    w = n_of(win)
    h = max(1, n_of(hop))
    if len(p) < w:
        return np.array([p.mean() * len(p) / w])
    cs = np.concatenate([[0.0], np.cumsum(p)])
    starts = np.arange(0, len(p) - w + 1, h)
    return (cs[starts + w] - cs[starts]) / w


def lufs(x) -> float:
    """Loudness integrata (con gating), in LUFS."""
    ms = _ms_blocks(x, 0.4, 0.1)
    ms = ms[ms > 0]
    if len(ms) == 0:
        return -100.0
    l = -0.691 + 10 * np.log10(ms)
    g = ms[l > -70]
    if len(g) == 0:
        return -100.0
    rel = -0.691 + 10 * np.log10(g.mean()) - 10
    g2 = g[(-0.691 + 10 * np.log10(g)) > rel]
    return float(-0.691 + 10 * np.log10(g2.mean())) if len(g2) else -100.0


def lufs_max(x, win: float = 0.1) -> float:
    """Loudness massima su finestre corte (per i suoni brevi)."""
    ms = _ms_blocks(x, win, win / 4)
    return float(-0.691 + 10 * np.log10(max(ms.max(), 1e-12)))


def normalize_lufs(x, target: float, peak_ceiling: float = -1.0, short: bool = False):
    cur = lufs_max(x) if short else lufs(x)
    y = x * db(target - cur)
    p = np.abs(y).max()
    if p > db(peak_ceiling):
        y = limiter(y, peak_ceiling)
    return f32(y)


# --- riverbero ------------------------------------------------------------------------------

def make_ir(rt60: float = 3.0, dur: float | None = None, seed: int = 1, predelay: float = 0.02,
            hf_damp: float = 0.5, lf_rt_mul: float = 1.15, early: int = 14, early_span: float = 0.08,
            width: float = 1.0, brightness: float = 9000.0) -> np.ndarray:
    """Risposta all'impulso stereo sintetica: riflessioni iniziali + coda di rumore a bande
    con tempi di decadimento diversi (le alte si spengono prima)."""
    rng = np.random.default_rng(seed)
    dur = dur or rt60 * 1.1
    n = n_of(dur)
    t = t_axis(n)
    bands = [(20, 250, rt60 * lf_rt_mul), (250, 1000, rt60), (1000, 3000, rt60 * (1 - 0.3 * hf_damp)),
             (3000, 7000, rt60 * (1 - 0.6 * hf_damp)), (7000, 20000, rt60 * (1 - 0.85 * hf_damp))]
    ir = np.zeros((n, 2))
    for ch in range(2):
        nz = rng.standard_normal(n)
        acc = np.zeros(n)
        for lo, hi, rt in bands:
            b = signal.sosfilt(signal.butter(2, [lo, min(hi, SR * 0.45)], 'band', fs=SR, output='sos'), nz)
            acc += b * 10 ** (-3 * t / rt)
        ir[:, ch] = acc
    # decorrelazione/larghezza
    m = ir.mean(axis=1, keepdims=True)
    ir = m + (ir - m) * width
    # attacco morbido della coda
    ir *= np.clip(t / 0.03, 0, 1)[:, None]
    ir = signal.sosfilt(signal.butter(1, brightness, 'low', fs=SR, output='sos'), ir, axis=0)
    # riflessioni iniziali
    for k in range(early):
        d = predelay + rng.uniform(0.002, early_span)
        i = n_of(d)
        if i < n:
            g = rng.uniform(0.25, 0.7) * (1 - d / (early_span + predelay + 0.05))
            ir[i, 0] += g * rng.choice([-1, 1]) * rng.uniform(0.6, 1.0)
            ir[i + rng.integers(0, 40), 1] += g * rng.choice([-1, 1]) * rng.uniform(0.6, 1.0)
    pd = n_of(predelay)
    ir = np.concatenate([np.zeros((pd, 2)), ir])[:n + pd]
    ir /= np.sqrt((ir ** 2).sum(axis=0).mean()) + 1e-12
    return f32(ir)


def reverb(x: np.ndarray, ir: np.ndarray, wet: float = 0.3, dry: float = 1.0, tail: bool = True) -> np.ndarray:
    """Convoluzione; restituisce stereo (con la coda se tail=True)."""
    xs = stereo(x).astype(np.float64)
    n = len(xs) + (len(ir) - 1 if tail else 0)
    out = np.zeros((n, 2))
    for ch in range(2):
        w = signal.fftconvolve(xs[:, ch], ir[:, ch].astype(np.float64))[:n]
        out[:, ch] = w * wet
    out[:len(xs)] += xs * dry
    return f32(out)


def reverb_loop(x: np.ndarray, ir: np.ndarray, wet: float = 0.3, dry: float = 1.0) -> np.ndarray:
    """Riverbero per un segnale già ciclico: la coda si somma all'inizio (resta un loop)."""
    xs = stereo(x).astype(np.float64)
    n = len(xs)
    out = xs * dry
    for ch in range(2):
        w = signal.fftconvolve(xs[:, ch], ir[:, ch].astype(np.float64))
        # piega la coda sul ciclo
        folded = np.zeros(n)
        for s in range(0, len(w), n):
            seg = w[s:s + n]
            folded[:len(seg)] += seg
        out[:, ch] += folded * wet
    return f32(out)


# --- tempo e altezza ------------------------------------------------------------------------

def varispeed(x: np.ndarray, speed) -> np.ndarray:
    """Legge x a velocità variabile (1 = normale, 0.8 = più lento e più grave, come un nastro).
    speed: costante o curva per campione d'uscita (si calcola fino a fine sorgente)."""
    x = np.asarray(x, dtype=np.float64)
    if np.isscalar(speed):
        n_out = int(len(x) / speed)
        pos = np.arange(n_out) * speed
    else:
        sp = np.asarray(speed, dtype=np.float64)
        pos = np.concatenate([[0.0], np.cumsum(sp)])[:-1]
        pos = pos[pos < len(x) - 2]
    i = np.floor(pos).astype(np.int64)
    fr = pos - i
    i = np.clip(i, 1, len(x) - 3)
    # interpolazione cubica (Catmull-Rom)
    def take(k):
        return x[i + k]
    p0, p1, p2, p3 = take(-1), take(0), take(1), take(2)
    if x.ndim == 2:
        fr = fr[:, None]
    y = p1 + 0.5 * fr * (p2 - p0 + fr * (2 * p0 - 5 * p1 + 4 * p2 - p3 + fr * (3 * (p1 - p2) + p3 - p0)))
    return f32(y)


def resample_ratio(x, ratio):
    """Cambia la durata di 'ratio' (2 = doppia, più grave) con resample di alta qualità."""
    from fractions import Fraction
    fr = Fraction(ratio).limit_denominator(200)
    return f32(signal.resample_poly(x, fr.numerator, fr.denominator, axis=0))


def pitch(x, semitones):
    """Trasposizione per ricampionamento (cambia anche la durata)."""
    return resample_ratio(x, 2 ** (-semitones / 12.0))


# --- spazio ---------------------------------------------------------------------------------

def pan(x: np.ndarray, p: float) -> np.ndarray:
    """p da -1 (sinistra) a 1 (destra), legge a potenza costante."""
    a = (p + 1) * np.pi / 4
    return f32(np.stack([x * np.cos(a), x * np.sin(a)], axis=1))


def widen(x: np.ndarray, delay_ms: float = 11.0, amount: float = 0.6) -> np.ndarray:
    """Allarga un mono in stereo con un piccolo ritardo decorrelato (Haas leggero)."""
    d = n_of(delay_ms / 1000.0)
    r = np.concatenate([np.zeros(d), x])[:len(x)]
    return f32(np.stack([x, x * (1 - amount) + r * amount], axis=1))


# --- loop -----------------------------------------------------------------------------------

def make_loop(x: np.ndarray, length: float, xfade: float = 1.0) -> np.ndarray:
    """Da un segnale lungo almeno length + xfade fa un loop di length secondi senza scatti:
    la parte dopo la fine si dissolve nell'inizio (a potenza costante, per rumori)."""
    L = n_of(length)
    F = n_of(xfade)
    assert len(x) >= L + F, (len(x), L + F)
    y = x[:L].copy()
    k = np.linspace(0, 1, F)
    gin = np.sin(k * np.pi / 2)
    gout = np.cos(k * np.pi / 2)
    if x.ndim == 2:
        gin = gin[:, None]
        gout = gout[:, None]
    y[:F] = x[:F] * gin + x[L:L + F] * gout
    return f32(y)


def loop_click_check(x: np.ndarray) -> float:
    """Salto tra l'ultimo e il primo campione rispetto alla variazione tipica (per i controlli)."""
    m = mono(x)
    jump = abs(float(m[0] - m[-1]))
    typ = float(np.percentile(np.abs(np.diff(m)), 99)) + 1e-9
    return jump / typ


# --- file -----------------------------------------------------------------------------------

def read_audio(path: str, channels: int = 1) -> np.ndarray:
    """Legge qualsiasi file audio con ffmpeg, a 44,1 kHz, float32."""
    cmd = ['ffmpeg', '-v', 'error', '-i', path, '-f', 'f32le', '-ac', str(channels), '-ar', str(SR), '-']
    raw = subprocess.run(cmd, check=True, capture_output=True).stdout
    a = np.frombuffer(raw, dtype=np.float32).copy()
    return a.reshape(-1, channels) if channels == 2 else a


def write_wav(path: str, x: np.ndarray) -> None:
    os.makedirs(os.path.dirname(path) or '.', exist_ok=True)
    wavfile.write(path, SR, np.clip(f32(x), -1, 1))


def write_ogg(path: str, x: np.ndarray, quality: float = 4.0) -> None:
    """Scrive in OGG Vorbis (ffmpeg + libvorbis). quality: -1..10 (4 ~ 128 kbit/s in stereo)."""
    os.makedirs(os.path.dirname(path) or '.', exist_ok=True)
    x = f32(x)
    if np.abs(x).max() > 1.0:
        x = x / np.abs(x).max()
    with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as tf:
        tmp = tf.name
    try:
        # WAV in virgola mobile: nessuna perdita prima della compressione
        wavfile.write(tmp, SR, np.clip(x, -1, 1).astype(np.float32))
        # bitexact: file identici a ogni rigenerazione (niente numero di serie casuale nell'Ogg)
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', tmp, '-c:a', 'libvorbis', '-q:a', str(quality),
                        '-map_metadata', '-1', '-fflags', '+bitexact', '-flags:a', '+bitexact', path], check=True)
    finally:
        os.unlink(tmp)
