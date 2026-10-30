"""I passi del giocatore, due proposte (riscontro dell'utente sulla 0.3.16: "il rumore dei passi va rifatto, è troppo
ticchettoso al momento"). Opzioni nella pagina del coordinatore:
  A  scarpe di gomma: suoni nuovi di sintesi, tonfo morbido e smorzato senza tic; sul bagnato un piccolo sciac della
     suola; sulle grate e sul metallo un suono sordo e basso;
  B  gli stessi passi di adesso ammorbiditi: tolta la parte acuta del colpo (passa-basso e attacco di qualche
     millisecondo invece che istantaneo) e volume un po' più basso.
Per tutte e due cambiano piastrelle, metallo, bagnato e scale (e gli atterraggi allo stesso modo); la camminata
nell'acqua alta resta com'è. Stessi nomi e stesso numero di file del gioco (godot/audio/giocatore/), in
assets_src/passi/<A|B>/: per metterli nel gioco basta copiarli sopra quelli di adesso.

Cosa rende "ticchettosi" i passi di adesso (misure di misura.py, medie per gruppo):
  - attacco istantaneo (0,4-0,8 ms dal 10 al 90% del picco) e colpo corto: 68 ms sulle piastrelle, poi niente;
  - picco a -1 dBFS (normalizzati) e nel gioco 10 dB sopra i picchi dell'ambiente (nave_loop: -14 dBFS di picco);
  - sul bagnato il 23% dell'energia dei primi 30 ms sopra i 4 kHz (lo schiocco), sulle scale il centroide a 2,3 kHz;
  - il ritmo: 4,5 passi al secondo camminando (3,4 m/s, un passo ogni 0,75 m) e 5,5 correndo.

A è sintesi (rumore filtrato, risonanze smorzate): nessuna fonte esterna, licenza come il resto, CC0. B parte dai file
di adesso (Kenney Impact Sounds, CC0, rielaborati il 16 ottobre).
Scelta dell'utente del 30 ottobre: A, senza sentirli prima; i file di A sono anche in godot/audio/giocatore/.
Uso: /home/user/tools/blender-venv/bin/python assets_src/passi/genera_passi.py [A|B]
"""
import os
import subprocess
import sys

import numpy as np
from scipy import signal

QUI = os.path.dirname(os.path.abspath(__file__))
GIOCO = os.path.normpath(os.path.join(QUI, '..', '..', 'godot', 'audio', 'giocatore'))
SR = 48000
GRUPPI = {'passo_piastrelle': 6, 'passo_metallo': 6, 'passo_bagnato': 6, 'passo_scala': 4,
          'atterraggio_piastrelle': 2, 'atterraggio_metallo': 2, 'atterraggio_bagnato': 2}


def leggi(f):
    raw = subprocess.run(['ffmpeg', '-loglevel', 'error', '-i', f, '-f', 'f32le', '-ac', '1', '-ar', str(SR), '-'],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.float32).astype(np.float64)


def scrivi(f, x):
    os.makedirs(os.path.dirname(f), exist_ok=True)
    x = np.clip(x, -1.0, 1.0).astype(np.float32)
    subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-f', 'f32le', '-ar', str(SR), '-ac', '1', '-i', '-',
                    '-c:a', 'libvorbis', '-q:a', '6', f], input=x.tobytes(), check=True)


def a_db(x, db):
    """Picco a [db] dBFS."""
    return x / max(np.abs(x).max(), 1e-9) * 10 ** (db / 20.0)


def passa_basso(x, f, ordine=4):
    return signal.sosfilt(signal.butter(ordine, f, 'low', fs=SR, output='sos'), x)


def passa_alto(x, f, ordine=2):
    return signal.sosfilt(signal.butter(ordine, f, 'high', fs=SR, output='sos'), x)


def banda(x, f0, f1, ordine=2):
    return signal.sosfilt(signal.butter(ordine, [f0, f1], 'band', fs=SR, output='sos'), x)


def inviluppo(n, attacco, decadimento):
    """Attacco morbido (seno al quadrato, in s) e decadimento esponenziale (costante in s)."""
    t = np.arange(n) / SR
    a = np.clip(t / attacco, 0.0, 1.0)
    a = np.sin(a * np.pi / 2) ** 2
    return a * np.exp(-np.maximum(t - attacco, 0.0) / decadimento)


def risonanza(n, f, smorza, rng):
    """Una risonanza smorzata (un modo del corpo che suona), con un po' di variazione."""
    t = np.arange(n) / SR
    return np.sin(2 * np.pi * f * t + rng.uniform(0, np.pi)) * np.exp(-t / smorza)


def ritardo(x, s):
    k = int(s * SR)
    return np.concatenate([np.zeros(k), x])[:len(x)]


# --- A: scarpe di gomma ------------------------------------------------------------------------------------

def tonfo(rng, durata=0.30, peso=1.0):
    """Il tallone della suola di gomma: tonfo basso e morbido (rumore filtrato sotto i 700 Hz più il corpo a 70-120 Hz),
    attacco di 6-9 ms, niente tic; poi la punta che rotola giù, più piano, 70-110 ms dopo."""
    n = int(durata * SR)
    rumore = rng.standard_normal(n)
    tallone = passa_basso(rumore, rng.uniform(500, 700)) * inviluppo(n, rng.uniform(0.006, 0.009), rng.uniform(0.028, 0.040))
    corpo = risonanza(n, rng.uniform(70, 120), rng.uniform(0.035, 0.05), rng) * inviluppo(n, 0.008, 0.045) * 0.9
    punta = passa_basso(rng.standard_normal(n), rng.uniform(800, 1100)) * inviluppo(n, 0.01, 0.025) * rng.uniform(0.25, 0.4)
    punta = ritardo(punta, rng.uniform(0.07, 0.11))
    # un fruscio leggerissimo della suola sul pavimento (lo sporco), lungo
    fruscio = banda(rng.standard_normal(n), 1200, 3000) * inviluppo(n, 0.02, 0.05) * 0.04
    return (tallone + corpo * peso + punta + ritardo(fruscio, 0.06))


def sciac(rng, durata=0.32):
    """Bagnato: il tonfo più leggero e lo sciac della suola che si stacca dall'acqua sottile (rumore 1,2-3,5 kHz,
    attacco morbido, con un risucchio corto), mai lo schiocco acuto."""
    n = int(durata * SR)
    base = tonfo(rng, durata, peso=0.7) * 0.8
    acqua = banda(rng.standard_normal(n), rng.uniform(1100, 1400), rng.uniform(3000, 3600)) * inviluppo(n, 0.012, 0.045)
    # il risucchio: lo stesso rumore modulato veloce e più scuro, quando la suola si stacca
    t = np.arange(n) / SR
    risucchio = banda(rng.standard_normal(n), 500, 1600) * inviluppo(n, 0.015, 0.03) * (0.6 + 0.4 * np.sin(2 * np.pi * 38 * t))
    return base + ritardo(acqua, rng.uniform(0.01, 0.02)) * 0.35 + ritardo(risucchio, rng.uniform(0.09, 0.13)) * 0.22


def sordo_metallo(rng, durata=0.40, scala=False):
    """Grate e metallo: gomma su lamiera, un tonfo sordo e basso con la lamiera che risponde appena (due modi a
    150-300 Hz e uno debole a 600-900, smorzati in fretta), niente squillo."""
    n = int(durata * SR)
    base = tonfo(rng, durata, peso=1.1) * 0.8
    lam = (risonanza(n, rng.uniform(150, 210), 0.07, rng) + 0.7 * risonanza(n, rng.uniform(240, 300), 0.05, rng)
           + 0.18 * risonanza(n, rng.uniform(600, 900), 0.025, rng)) * inviluppo(n, 0.006, 0.09)
    if scala:
        # il piolo: più corto e più alto, la scala che vibra un poco
        lam = (risonanza(n, rng.uniform(320, 420), 0.04, rng) + 0.35 * risonanza(n, rng.uniform(900, 1200), 0.018, rng)) \
            * inviluppo(n, 0.005, 0.05)
        return base * 0.6 + lam * 0.35
    return base + lam * 0.28


def versione_A():
    uscita = os.path.join(QUI, 'A')
    rng = np.random.default_rng(317)
    for nome, quanti in GRUPPI.items():
        for k in range(1, quanti + 1):
            atterra = nome.startswith('atterraggio')
            if 'metallo' in nome:
                x = sordo_metallo(rng, 0.55 if atterra else 0.40)
            elif 'bagnato' in nome:
                x = sciac(rng, 0.5 if atterra else 0.32)
            elif 'scala' in nome:
                x = sordo_metallo(rng, 0.3, scala=True)
            else:
                x = tonfo(rng, 0.45 if atterra else 0.30)
            if atterra:
                # l'atterraggio: due piedi quasi insieme, più pesante e più lungo
                x = x + ritardo(tonfo(rng, len(x) / SR, peso=1.3), rng.uniform(0.025, 0.045)) * 0.8
                x = passa_basso(x, 900)
            x = passa_alto(x, 45)
            # (i passi a -9 dBFS di picco, 8 sotto quelli di adesso; gli atterraggi a -5)
            x = a_db(x, -5.0 if atterra else -9.0)
            scrivi(os.path.join(uscita, f'{nome}_{k:02d}.ogg'), x)
    print('A in', uscita)


# --- B: gli stessi, ammorbiditi -----------------------------------------------------------------------------

def versione_B():
    uscita = os.path.join(QUI, 'B')
    for nome, quanti in GRUPPI.items():
        for k in range(1, quanti + 1):
            x = leggi(os.path.join(GIOCO, f'{nome}_{k:02d}.ogg'))
            # la parte acuta del colpo via: passa-basso (2,2 kHz; sul bagnato 3 kHz e una mensola sopra i 4)
            taglio = 3000 if 'bagnato' in nome else (1800 if 'scala' in nome else 2200)
            x = passa_basso(x, taglio, 2)
            # l'attacco di 5 ms invece che istantaneo (il tic è il primo millisecondo)
            on = int(np.argmax(np.abs(x) > 0.05 * np.abs(x).max()))
            n_att = int(0.005 * SR)
            rampa = np.ones(len(x))
            rampa[:on] = 0.0
            rampa[on:on + n_att] = np.sin(np.linspace(0, np.pi / 2, n_att)) ** 2
            x = x * rampa
            # volume più basso: picco a -7 dBFS invece di -1 (gli atterraggi a -4)
            x = a_db(x, -4.0 if nome.startswith('atterraggio') else -7.0)
            scrivi(os.path.join(uscita, f'{nome}_{k:02d}.ogg'), x)
    print('B in', uscita)


if __name__ == '__main__':
    quali = sys.argv[1:] or ['A', 'B']
    if 'A' in quali:
        versione_A()
    if 'B' in quali:
        versione_B()
