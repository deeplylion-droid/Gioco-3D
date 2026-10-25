"""La voce di lei nel tunnel del viaggio sottomarino (scelta 10A dell'utente, 24 ottobre): sotto i versi già
approvati dell'inseguimento, un fiato roco e basso, continuo, con un verso ogni 4-6 secondi. Lei corre a bocca
spalancata: il fiato è quello di una gola aperta, non umido. La stessa gola di genera_lei.py (la versione
gutturale scelta il 16 ottobre), solo sintesi, niente voce umana.

Riscontri dell'utente da rispettare: volumi bassi (gioca al 10%), suoni puliti, niente bollicine di sottofondo
né rumori strani. Per questo qui non ci sono il crepitio del muco di respiro() (impulsi fitti che si sentono
come bollicine), il brontolio sotto i 60 Hz né la distorsione forte.

Suoni:
- lei_tunnel_fiato (8 s, in ciclo senza stacchi): ansima a bocca aperta, espira roca con un filo di ringhio,
  inspira stretta e cupa, circa un ciclo ogni 1,3 s, come chi insegue;
- lei_tunnel_verso_1..4 (1,1-1,5 s): il verso a bocca spalancata, un ringhio che si apre e cade; il gioco ne
  mette uno ogni 4-6 secondi, a caso.

Uso: /home/user/tools/blender-venv/bin/python assets_src/audio/genera_lei_tunnel.py [cartella | gioco]
Senza argomenti scrive in docs/proposte/voce_lei_tunnel/ i suoni e un esempio di 30 s com'è nel gioco (fiato
con i versi sopra); con "gioco" scrive i file del gioco in godot/audio/lei/ e li registra (solo dopo l'ok
dell'utente); poi catalogo.py e licenze.py.
"""
import os
import sys

import numpy as np

from comune import RADICE, ir_sala
from genera_lei import _norm, gola, tratto
from genera_lei_inseguimento import grido
from lib_audio import (SR, env_points, f32, fade, hp, lp, mix_into, n_of, normalize_lufs, reverb, smooth_noise,
                       white, write_ogg, limiter)

USCITA = os.path.join(RADICE, 'docs', 'proposte', 'voce_lei_tunnel')
CICLO = 8.0          # durata del fiato in ciclo
FIATO_LUFS = -27     # basso: sta sotto tutto
VERSO_LUFS = -19


def espira(rng, d, forza):
    """Espira a bocca aperta: aria che raschia nella gola con un filo di ringhio basso, senza muco."""
    k = n_of(d)
    e = env_points([(0, 0), (d * 0.12, 1), (d * 0.6, 0.8), (d, 0)], k)
    f0 = 52 * (1 + 0.08 * smooth_noise(k, 2, rng))
    voce = gola(rng, d, f0, jitter=0.18, shimmer=0.4, sotto=0.5, aspira=0.3)
    rullo = 0.6 + 0.4 * np.abs(np.sin(np.pi * np.cumsum(np.full(k, 22.0)) / SR)) ** 0.7
    src = lp(white(k, rng), 2400, 2) * 0.6 + _norm(voce) * rullo * 0.5
    v = tratto(rng, src, [(380, 2.0, 0.9), (900, 2.6, 1.0), (1900, 3.8, 0.4), (2900, 6.0, 0.12)])
    return f32(lp(v, 3200, 2) * e * forza)


def inspira(rng, d, forza):
    """Inspira stretta e cupa: un risucchio corto di gola, senza lo scatto finale."""
    k = n_of(d)
    e = env_points([(0, 0), (d * 0.55, 1), (d * 0.85, 0.7), (d, 0)], k) ** 1.4
    v = tratto(rng, lp(white(k, rng), 2800, 2), [(420, 2.6, 0.8), (1000, 3.4, 0.6), (2300, 5.0, 0.2)])
    return f32(lp(v, 3200, 2) * e * forza)


def fiato(rng):
    """Il fiato in ciclo: CICLO secondi di respiri corti e rochi; la coda del ciclo si sovrappone all'inizio
    (dissolvenza incrociata), così il giro non si sente."""
    coda = 1.0
    n = n_of(CICLO + coda)
    out = np.zeros(n)
    t = 0.05
    while t < CICLO + coda - 0.3:
        de = rng.uniform(0.62, 0.8)
        di = rng.uniform(0.34, 0.46)
        mix_into(out, espira(rng, de, rng.uniform(0.8, 1.0)), n_of(t))
        mix_into(out, inspira(rng, di, rng.uniform(0.45, 0.6)), n_of(t + de * 0.92))
        t += de * 0.92 + di + rng.uniform(0.02, 0.12)
    out = hp(out, 60, 2)
    m = n_of(CICLO)
    c = n_of(coda)
    x = out[:m].copy()
    w = np.linspace(0, 1, c)
    x[:c] = x[:c] * w + out[m:m + c] * (1 - w)
    return f32(x)


def verso(rng):
    """Il verso a bocca spalancata: un ringhio che si apre e cade, con il fiato in coda."""
    dur = rng.uniform(1.1, 1.5)
    n = n_of(dur)
    out = np.zeros(n)
    a = rng.uniform(62, 76)
    d = dur - 0.25
    gr = grido(rng, d, [(0, a), (d * 0.25, a * 1.35), (d * 0.7, a * 1.15), (d, a * 0.8)],
               bocca=rng.uniform(1.25, 1.45), sporco=2.5, rullo=rng.uniform(22, 28))
    mix_into(out, _norm(gr) * env_points([(0, 0), (0.08, 0.9), (d * 0.35, 1.0), (d * 0.8, 0.6), (d, 0)], len(gr)), 0)
    mix_into(out, _norm(espira(rng, 0.45, 1.0)) * 0.35, n_of(d - 0.15))
    # (via la subarmonica sotto i 70 Hz del grido: niente brontolio, come per lo squalo)
    return f32(fade(hp(out, 75, 4), 0.01, 0.12))


def genera():
    """{nome: array}, normalizzati, con un filo della sala (il tunnel è grande e chiuso)."""
    ir = ir_sala()
    tutti = {}
    rng = np.random.default_rng(2410)
    x = fiato(rng)
    # il riverbero del fiato si calcola sul ciclo ripetuto due volte e se ne prende il secondo giro, così anche la
    # coda del riverbero gira senza stacchi
    doppio = reverb(np.concatenate([x, x]), ir, wet=0.12, dry=1.0, tail=False)
    if doppio.ndim == 2:
        doppio = doppio.mean(axis=1)
    x = doppio[len(x):2 * len(x)]
    tutti['lei_tunnel_fiato'] = f32(limiter(normalize_lufs(x, FIATO_LUFS, -6.0), -6.0))
    for v in range(4):
        rng = np.random.default_rng(2420 + 13 * v)
        y = reverb(verso(rng), ir, wet=0.14, dry=1.0, tail=False)
        if y.ndim == 2:
            y = y.mean(axis=1)
        tutti['lei_tunnel_verso_%d' % (v + 1)] = f32(limiter(normalize_lufs(y, VERSO_LUFS, -3.0, short=True), -3.0))
    return tutti


def esempio(tutti, dur=30.0):
    """Com'è nel gioco: il fiato in ciclo e un verso ogni 4-6 s, a caso."""
    rng = np.random.default_rng(7)
    n = n_of(dur)
    f = tutti['lei_tunnel_fiato']
    out = np.tile(f, int(np.ceil(n / len(f))))[:n].astype(np.float64)
    t = 2.0
    while t < dur - 2.0:
        y = tutti['lei_tunnel_verso_%d' % rng.integers(1, 5)]
        mix_into(out, y, n_of(t))
        t += rng.uniform(4.0, 6.0)
    return f32(fade(out, 0.5, 1.0))


def gioco():
    """Nel gioco (l'utente ha approvato il fiato, 24 ottobre: "ok per il fiato"): godot/audio/lei/, registrati per
    catalogo.py e licenze.py. Gli stessi campioni che ha sentito (fiato a -27 LUFS, versi intorno a -22): salva() non
    li rinormalizza (picco = il loro, guadagno 1)."""
    from comune import salva
    for nome, x in genera().items():
        picco = 20.0 * np.log10(float(np.abs(x).max()) + 1e-12) + 0.01
        if nome == 'lei_tunnel_fiato':
            # (nel gioco col suffisso _loop: l'addon audio lo mette in ciclo)
            salva('lei', 'lei_tunnel_fiato_loop', x, loudness=None, picco=picco, qualita=5,
                  nota='tunnel, voce (24 ottobre): fiato roco e basso a bocca aperta, in ciclo')
        else:
            base, k = nome.rsplit('_', 1)
            salva('lei', '%s_%02d' % (base, int(k)), x, loudness=None, picco=picco, qualita=5,
                  nota='tunnel, voce (24 ottobre): verso a bocca spalancata, uno ogni 4-6 s')


def main():
    if len(sys.argv) > 1 and sys.argv[1] == 'gioco':
        gioco()
        return
    cartella = sys.argv[1] if len(sys.argv) > 1 else USCITA
    os.makedirs(cartella, exist_ok=True)
    tutti = genera()
    for nome, x in tutti.items():
        write_ogg(os.path.join(cartella, nome + '.ogg'), x, 5)
        print(nome, '%.2f s' % (len(x) / SR))
    write_ogg(os.path.join(cartella, 'esempio_30s.ogg'), esempio(tutti), 5)
    print('esempio_30s')


if __name__ == '__main__':
    main()
