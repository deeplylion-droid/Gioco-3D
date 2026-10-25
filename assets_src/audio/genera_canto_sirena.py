"""Il canto di sirena di lei durante l'inseguimento nel tunnel sottomarino (richiesta dell'utente del 25 ottobre: "un
canto da sirena distorto ed inquietante, che possa dare l'idea di inseguimento pauroso"). Proposte, non ancora nel
gioco: l'utente le sente prima.

La voce è la stessa gola sintetica della voce di lei già approvata (gola() e il tratto di genera_lei.py), qui
tenuta più ferma per cantare: niente voce umana. Lei canta mentre insegue: frasi di 4-8 s, una ogni 8-15 s,
sempre diverse (note, durate e vocali a caso da una scala minore), più vicine e forti quando lei si avvicina.

Le tre varianti:
- A: un vocalizzo lento in minore (aah, ooh), il nastro che ondeggia, un leggero sdoppiamento, il filtro
  sott'acqua e il riverbero del tunnel;
- B: come A ma "rotto": si inceppa (un pezzetto ripetuto), cala di tono come un disco che rallenta, più
  distorto (una saturazione morbida, controllata: niente crepitii);
- C: un coro di tre voci di lei a intervalli stonati (seconda minore e tritono), con dei sussurri fra una frase
  e l'altra (rumore filtrato dalle stesse risonanze del tratto, a sillabe).

Riscontri dell'utente da rispettare: volumi bassi (gioca al 10%), suoni puliti, niente bollicine o crepitii, niente
musichette in loop: ogni frase è nuova.

Uso: /home/user/tools/blender-venv/bin/python assets_src/audio/genera_canto_sirena.py [cartella | gioco A|B|C]
Scrive in docs/proposte/canto_sirena/, per ogni variante, tre frasi di prova e un esempio di 30 s come sarebbe nel
gioco (con il fiato e i versi del tunnel già approvati sotto, ai loro volumi), in mp3 (per il telefono) e in ogg.
Con "gioco A" (o B, C), solo dopo la scelta dell'utente, scrive le frasi del gioco in godot/audio/lei/
(lei_tunnel_canto_NN); poi catalogo.py e licenze.py. Nel gioco le suona la voce di lei (addons/audio/audio.gd, Statua).
"""
import os
import subprocess
import sys
import tempfile

import numpy as np
from scipy.io import wavfile

from comune import RADICE, ir_sala
from genera_lei import _norm, gola, sporca
import genera_lei_tunnel as tunnel
from lib_audio import (SR, env_points, f32, fade, hp, lp, lufs, mix_into, n_of, normalize_lufs, reverb,
                       smooth_noise, stereo, tv_biquad, varispeed, white, write_ogg, limiter)

USCITA = os.path.join(RADICE, 'docs', 'proposte', 'canto_sirena')
# il canto da vicino: sotto i versi (-19 corti, circa -22 integrati), sopra il fiato (-27)
CANTO_LUFS = -24
# Scelta dell'utente del 25 ottobre sera: A, con "il respiro abbassato del 70%, la melodia alzata del 30% e senza quel
# suono fastidioso di grattamento che compare ritmicamente" (erano i versi, il ringhio raschiato ogni 4-6 s: i picchi
# acuti dell'esempio cadevano proprio sui versi). Nel gioco: il fiato a x0,3 (-10,5 dB), il canto a x1,3 (+2,3 dB), e
# mentre canta niente versi.
FIATO_X = 0.3
CANTO_X = 1.3
CANTO_GIOCO_LUFS = CANTO_LUFS + 20.0 * np.log10(CANTO_X)
# la scala: la minore con la seconda abbassata (frigio), da sol2 a fa3 (Hz)
SCALA = [196.0, 220.0, 233.1, 261.6, 293.7, 329.6, 349.2]
# le vocali di una gola grande (un po' più basse di quelle umane): (F1, F2, F3)
VOCALI = {'a': (640, 1050, 2400), 'o': (400, 760, 2300), 'u': (320, 620, 2200)}


def melodia(rng, dur):
    """Le note di una frase: [(inizio, durata, Hz, vocale)], un passo per volta lungo la scala, che alla fine
    scende (un sospiro). Mai uguale: durate, note e vocali a caso."""
    note = []
    i = int(rng.integers(1, 5))
    t = 0.0
    while t < dur - 0.6:
        d = float(rng.uniform(0.9, 2.2))
        d = min(d, dur - t)
        note.append((t, d, SCALA[i], str(rng.choice(['a', 'a', 'o', 'u']))))
        t += d
        # su o giù di un passo (raramente due), verso il basso alla fine
        passo = int(rng.choice([-2, -1, -1, 1, 1, 2]))
        if t > dur * 0.6:
            passo = -abs(passo)
        i = int(np.clip(i + passo, 0, len(SCALA) - 1))
    return note


def curve(rng, note, n, scivola=0.3):
    """L'altezza (Hz) e le tre formanti per campione: scivolate fra le note (portamento), vibrato che cresce in ogni
    nota, la vocale che si trasforma piano nella successiva."""
    f0 = np.zeros(n)
    fm = np.zeros((3, n))
    for k, (t0, d, hz, voc) in enumerate(note):
        a, b = n_of(t0), min(n, n_of(t0 + d))
        f0[a:b] = hz
        fm[:, a:b] = np.array(VOCALI[voc])[:, None]
    # portamento e passaggio di vocale: media mobile lunga quanto la scivolata
    w = max(1, n_of(scivola))
    ker = np.ones(w) / w
    f0 = np.convolve(np.pad(f0, (w, w), mode='edge'), ker, mode='same')[w:w + n]
    fm = np.stack([np.convolve(np.pad(r, (w, w), mode='edge'), ker, mode='same')[w:w + n] for r in fm])
    # vibrato: 4,5-5,5 Hz, profondo fino all'1,8% verso la fine di ogni nota, e una deriva lenta
    vib = np.zeros(n)
    for t0, d, _, _ in note:
        a, b = n_of(t0), min(n, n_of(t0 + d))
        vib[a:b] = np.linspace(0.2, 1.0, b - a) ** 1.5
    fv = rng.uniform(4.5, 5.5)
    f0 = f0 * (1 + 0.018 * vib * np.sin(2 * np.pi * fv * np.arange(n) / SR + rng.uniform(0, 6.3)))
    f0 = f0 * (1 + 0.006 * smooth_noise(n, 0.7, rng))
    return f0, fm


def voce(rng, note, dur, scivola=0.3):
    """La gola di lei che canta: le stesse impulsioni della sua voce, più ferme (poco jitter), con un filo della
    subarmonica ruvida e dell'aria, nelle risonanze della vocale."""
    n = n_of(dur)
    f0, fm = curve(rng, note, n, scivola)
    g = gola(rng, dur, f0, jitter=0.012, shimmer=0.07, sotto=0.1, aspira=0.1)[:n]
    v = np.zeros(n)
    for (q, gain), riga in zip([(5.0, 1.0), (6.0, 0.7), (9.0, 0.25)], fm):
        v += tv_biquad(g, 'bandpass', riga * (1 + 0.03 * smooth_noise(n, 0.5, rng)), q) * gain
    # attacco lento e coda, a ogni frase
    e = env_points([(0, 0), (0.45, 0.8), (dur * 0.5, 1.0), (dur - 0.9, 0.85), (dur, 0)], n)
    return f32(hp(v, 90, 2) * e)


def nastro(rng, x, quanto=0.006, velocita=0.45):
    """Il nastro che ondeggia: la velocità di lettura che va su e giù piano (wow) con un tremolio più fitto (flutter)."""
    n = len(x)
    s = 1 + quanto * np.sin(2 * np.pi * velocita * np.arange(n) / SR + rng.uniform(0, 6.3)) \
        + quanto * 0.35 * smooth_noise(n, 1.5, rng) + 0.0015 * np.sin(2 * np.pi * 6.5 * np.arange(n) / SR)
    return f32(varispeed(x, s)[:n])


def sdoppia(x, cent=14.0, ritardo=0.028, quanto=0.45):
    """Un leggero sdoppiamento: una copia appena più acuta e in ritardo."""
    y = varispeed(x, 2 ** (cent / 1200))
    out = np.array(x, dtype=np.float64)
    mix_into(out, y * quanto, n_of(ritardo))
    return f32(out)


def sottacqua(x, chiuso=1600.0):
    """Il filtro sott'acqua: via gli acuti, un po' di corpo sui medi bassi."""
    return f32(lp(lp(x, chiuso, 2), chiuso * 1.6, 2))


def inceppa(rng, x, volte=2):
    """Si inceppa: un pezzetto di 90-160 ms ripetuto 2-4 volte (con dissolvenze di 5 ms: niente clic)."""
    out = np.array(x, dtype=np.float64)
    for _ in range(volte):
        lung = n_of(rng.uniform(0.09, 0.16))
        da = int(rng.integers(n_of(0.6), max(n_of(0.7), len(out) - n_of(2.5))))
        pezzo = fade(out[da:da + lung].copy(), 0.005, 0.005)
        rip = int(rng.integers(2, 5))
        nuovo = np.concatenate([out[:da + lung]] + [pezzo] * rip + [out[da + lung:]])
        out = nuovo
    return f32(out)


def rallenta(x, quanto=0.45, durata=1.6):
    """Cala di tono come un disco che rallenta, nell'ultimo pezzo della frase (da 1 a 1 - quanto)."""
    n = len(x)
    k = n_of(durata)
    testa = x[:n - k]
    coda = varispeed(x[n - k:], np.linspace(1.0, 1.0 - quanto, int(k / (1 - quanto * 0.5))))
    return f32(fade(np.concatenate([testa, coda]), 0.0, 0.3))


def sussurro(rng, dur):
    """Un sussurro senza parole: aria filtrata dalle risonanze del tratto, a sillabe (3-5 al secondo)."""
    n = n_of(dur)
    aria = hp(white(n, rng), 900, 2)
    f1 = 600 * (1 + 0.35 * smooth_noise(n, 4.0, rng))
    f2 = 1500 * (1 + 0.3 * smooth_noise(n, 3.5, rng))
    v = tv_biquad(aria, 'bandpass', f1, 3.0) * 0.6 + tv_biquad(aria, 'bandpass', f2, 4.0)
    sill = np.clip(smooth_noise(n, rng.uniform(3.0, 5.0), rng), 0, None) ** 1.2
    e = env_points([(0, 0), (0.15, 1), (dur - 0.3, 0.8), (dur, 0)], n)
    return f32(lp(v * sill * e, 4500, 2))


def frase(rng, variante, dur):
    """Una frase del canto, già con l'effetto della variante (asciutta: il riverbero lo mette chi la usa)."""
    note = melodia(rng, dur)
    if variante == 'C':
        # il coro: tre voci di lei, la seconda una seconda minore sopra, la terza un tritono sotto, un po' sfasate
        out = _norm(voce(rng, note, dur))
        for semi, g, rit in [(1, 0.55, 0.07), (-6, 0.45, 0.13)]:
            altre = [(t0, d, hz * 2 ** (semi / 12), v) for t0, d, hz, v in note]
            mix_into(out, _norm(voce(rng, altre, dur, scivola=0.4)) * g, n_of(rit))
        x = nastro(rng, out, 0.005)
    else:
        x = nastro(rng, _norm(voce(rng, note, dur)), 0.006 if variante == 'A' else 0.011)
    x = sdoppia(x, quanto=0.4 if variante != 'B' else 0.5)
    if variante == 'B':
        x = inceppa(rng, x, volte=int(rng.integers(1, 3)))
        x = rallenta(x, quanto=rng.uniform(0.35, 0.5))
        # più distorto, ma con una saturazione morbida (tanh) e poi filtrato: niente crepitii
        x = lp(sporca(x, 2.4), 3000, 2)
    return f32(fade(hp(sottacqua(x), 80, 2), 0.05, 0.4))


def esempio(rng, variante, base, dur=30.0):
    """Com'è nel gioco: il fiato e i versi del tunnel sotto; una frase di 4-8 s ogni 8-15 s, sempre nuova, che si
    avvicina (lontana: più bassa e più chiusa; vicina: più forte e più aperta); il riverbero del tunnel."""
    ir = ir_sala()
    n = n_of(dur)
    canto = np.zeros((n, 2))
    t = 1.0
    k = 0
    vicinanze = [0.0, 0.5, 1.0, 1.0]
    while t < dur - 3.0:
        d = float(rng.uniform(4.0, 8.0))
        d = min(d, dur - t - 0.5)
        x = bagnata(frase(rng, variante, d), ir)
        # ogni frase (col suo riverbero) portata a CANTO_LUFS da vicino, poi la distanza: fino a 9 dB sotto e più chiusa
        vic = vicinanze[min(k, 3)]
        x = lp(x, 900 + 1100 * vic, 2) * 10 ** ((-9.0 * (1 - vic)) / 20)
        mix_into(canto, x, n_of(t))
        if variante == 'C' and t + d + 1.5 < dur:
            s = bagnata(sussurro(rng, rng.uniform(1.2, 2.0)), ir, CANTO_LUFS - 10.0)
            mix_into(canto, s * (0.5 + 0.5 * vic), n_of(t + d + rng.uniform(0.3, 0.9)))
        t += d + float(rng.uniform(3.0, 7.0))
        k += 1
    sotto = stereo(base[:n])
    return f32(limiter(fade(canto + sotto, 0.5, 1.5), -3.0))


def esempio_ritoccato(rng, variante, fiato, dur=30.0):
    """L'esempio dopo la scelta dell'utente: sotto solo il fiato in ciclo a FIATO_X (niente versi), il canto a
    CANTO_GIOCO_LUFS da vicino, come in esempio()."""
    ir = ir_sala()
    n = n_of(dur)
    canto = np.zeros((n, 2))
    t = 1.0
    k = 0
    vicinanze = [0.0, 0.5, 1.0, 1.0]
    while t < dur - 3.0:
        d = min(float(rng.uniform(4.0, 8.0)), dur - t - 0.5)
        x = bagnata(frase(rng, variante, d), ir, CANTO_GIOCO_LUFS)
        vic = vicinanze[min(k, 3)]
        x = lp(x, 900 + 1100 * vic, 2) * 10 ** ((-9.0 * (1 - vic)) / 20)
        mix_into(canto, x, n_of(t))
        t += d + float(rng.uniform(3.0, 7.0))
        k += 1
    sotto = stereo(np.tile(fiato, int(np.ceil(n / len(fiato))))[:n] * FIATO_X)
    return f32(limiter(fade(canto + sotto, 0.5, 1.5), -3.0))


def bagnata(x, ir, livello=CANTO_LUFS):
    """La frase col riverbero del tunnel (e la sua coda), portata a [param livello] LUFS."""
    y = reverb(x, ir, wet=0.3, dry=1.0, tail=True)
    return f32(y * 10 ** ((livello - lufs(y)) / 20))


def write_mp3(path, x):
    """In mp3 per il telefono (libmp3lame, VBR alta qualità)."""
    x = f32(x)
    with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as tf:
        tmp = tf.name
    try:
        wavfile.write(tmp, SR, np.clip(x, -1, 1).astype(np.float32))
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', tmp, '-c:a', 'libmp3lame', '-q:a', '2',
                        '-map_metadata', '-1', path], check=True)
    finally:
        os.unlink(tmp)


FRASI_GIOCO = 10


def gioco(variante):
    """Nel gioco, dopo la scelta dell'utente: FRASI_GIOCO frasi della variante, mono (la voce viene da lei, in 3D),
    con un filo del riverbero del tunnel come i versi (il resto lo fa il gioco), a CANTO_GIOCO_LUFS (+2,3 dB, scelta
    dell'utente). In godot/audio/lei/
    come lei_tunnel_canto_NN, registrate per catalogo.py e licenze.py."""
    from comune import salva
    ir = ir_sala()
    rng = np.random.default_rng({'A': 1100, 'B': 1200, 'C': 1300}[variante])
    for k in range(FRASI_GIOCO):
        x = frase(rng, variante, float(rng.uniform(4.0, 8.0)))
        y = reverb(x, ir, wet=0.14, dry=1.0, tail=True)
        if y.ndim == 2:
            y = y.mean(axis=1)
        y = fade(y[:len(x) + n_of(1.5)], 0.0, 1.0)
        y = limiter(normalize_lufs(y, CANTO_GIOCO_LUFS, -3.0), -3.0)
        picco = 20.0 * np.log10(float(np.abs(y).max()) + 1e-12) + 0.01
        salva('lei', 'lei_tunnel_canto_%02d' % (k + 1), y, loudness=None, picco=picco, qualita=5,
              nota='tunnel, canto di sirena (variante %s, 25 ottobre): una frase ogni 8-15 s mentre insegue' % variante)


def main():
    if len(sys.argv) > 2 and sys.argv[1] == 'gioco':
        gioco(sys.argv[2].upper())
        return
    if len(sys.argv) > 1 and sys.argv[1] == 'ritoccato':
        os.makedirs(USCITA, exist_ok=True)
        fiato = tunnel.genera()['lei_tunnel_fiato']
        x = esempio_ritoccato(np.random.default_rng(101), 'A', fiato)
        for est in ('mp3', 'ogg'):
            nome = os.path.join(USCITA, 'canto_A_ritoccato_esempio_30s.' + est)
            write_mp3(nome, x) if est == 'mp3' else write_ogg(nome, x, 5)
        print('canto_A_ritoccato_esempio_30s', 'LUFS %.1f' % lufs(x), 'picco %.1f dB' % (20 * np.log10(np.abs(x).max())))
        return
    cartella = sys.argv[1] if len(sys.argv) > 1 else USCITA
    os.makedirs(cartella, exist_ok=True)
    # sotto: il fiato e i versi del tunnel come nel loro esempio approvato (fiato -27 LUFS, versi intorno a -22)
    base = tunnel.esempio(tunnel.genera())
    ir = ir_sala()
    for semi, variante in [(100, 'A'), (200, 'B'), (300, 'C')]:
        # tre frasi di prova da sole (vicine, col riverbero), una dopo l'altra
        rng = np.random.default_rng(semi)
        prove = []
        for _ in range(3):
            prove.append(bagnata(frase(rng, variante, float(rng.uniform(5.0, 7.0))), ir))
            prove.append(np.zeros((n_of(0.5), 2)))
        prova = f32(np.concatenate(prove))
        es = esempio(np.random.default_rng(semi + 1), variante, base)
        for nome, x in [('canto_%s_frasi' % variante, prova), ('canto_%s_esempio_30s' % variante, es)]:
            write_mp3(os.path.join(cartella, nome + '.mp3'), x)
            write_ogg(os.path.join(cartella, nome + '.ogg'), x, 5)
            print(nome, '%.1f s' % (len(x) / SR), 'LUFS %.1f' % lufs(x), 'picco %.1f dB' % (20 * np.log10(np.abs(x).max())))


if __name__ == '__main__':
    main()
