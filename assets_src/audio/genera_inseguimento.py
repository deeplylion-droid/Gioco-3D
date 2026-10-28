"""I suoni dell'inseguimento nel tunnel sottomarino (scelte dell'utente della sera del 25 ottobre: il canto da solo forse
non basta a dare l'impressione di inseguimento). Proposte: l'utente le sente prima che entrino nel gioco.

- IL BATTITO DEL CUORE del giocatore (cuore_battito_NN): un "tum-tum" basso e ovattato, sentito da dentro. Nel gioco
  il battito non è un ciclo: la voce di lei (addons/audio/audio.gd, Statua) ne fa partire uno alla volta, col tempo che
  cresce quando lei si avvicina (72 battiti al minuto a 18 m, 128 a 8 m) e cala quando la respingi col getto; più forte
  quando è vicina, sempre sotto il canto.
- IL RITMO D'INSEGUIMENTO (inseguimento_colpo_NN): colpi bassi e cupi, come tamburi lontani nello scafo (una pelle grande
  e la lamiera che risuona, con il riverbero dello scafo). Partono quando lei comincia a inseguirti e si fanno più fitti
  quando è vicina; ogni colpo cade a una distanza un po' a caso dal precedente, a volte doppio: niente giro che si
  ripete, niente melodia.

Regole dell'utente: volumi bassi (gioca al 10%), suoni puliti (niente crepitii, bollicine o grattamenti), niente loop
riconoscibili. La distanza di lei resta quella del gioco (8-18 m).

Uso: /home/user/tools/blender-venv/bin/python assets_src/audio/genera_inseguimento.py [gioco]
Senza argomenti scrive in docs/proposte/inseguimento_suoni/ un esempio di 36 s come nel gioco (col canto A ritoccato, il
fiato a x0,3, il cuore e il ritmo: lei si avvicina, morde a vuoto, viene respinta e torna) e due varianti brevi, una
col solo cuore e una col solo ritmo, in mp3 e ogg. Con "gioco" (dopo l'ok dell'utente) scrive i file del gioco in
godot/audio/giocatore/ e godot/audio/ambiente/ e li registra; poi catalogo.py e licenze.py.
"""
import os
import subprocess
import sys
import tempfile

import numpy as np
from scipy.io import wavfile

from comune import RADICE, ir_nave, ir_sala
import genera_lei_tunnel as tunnel
from lib_audio import (SR, env_points, f32, fade, hp, lp, lufs, lufs_max, mix_into, n_of, read_audio, resonator_bank,
                       reverb, stereo, white, write_ogg, limiter)

USCITA = os.path.join(RADICE, 'docs', 'proposte', 'inseguimento_suoni')
# il livello da vicino (lei a 8 m), sul massimo di 100 ms: sotto il canto (-21,7 LUFS integrati, circa -17 di massimo)
CUORE_MAX = -26.0
RITMO_MAX = -28.0
# nel gioco (le stesse costanti di addons/audio/audio.gd, Statua)
CUORE_BPM = (72.0, 128.0)        # lei a 18 m / a 8 m
CUORE_DB = (-9.0, 0.0)
RITMO_OGNI = (1.5, 0.55)         # secondi fra un colpo e l'altro, a 18 m / a 8 m
RITMO_DB = (-9.0, 0.0)
LONTANA, VICINA = 18.0, 8.0
CANTO_X = 1.3
FIATO_X = 0.3


# --- il cuore -------------------------------------------------------------------------------

def _tonfo(rng, f0, durata, forza):
    """Un tonfo basso: un'onda che scende di altezza e si spegne in fretta, con un filo di corpo (rumore filtrato basso)."""
    n = n_of(durata)
    t = np.arange(n) / SR
    f = f0 * (1.0 + 0.6 * np.exp(-t / 0.012))
    fase = 2 * np.pi * np.cumsum(f) / SR
    e = (1 - np.exp(-t / 0.004)) * np.exp(-t / (durata * 0.28))
    corpo = lp(white(n, rng), 140, 2) * np.exp(-t / 0.03) * 0.25
    return f32((np.sin(fase) + corpo) * e * forza)


def battito(rng):
    """Un battito: il primo tonfo ("tum") e il secondo, più debole e un po' più acuto, 0,2 s dopo; ovattato come sentito da
    dentro (sotto i 300 Hz), senza attacchi secchi."""
    n = n_of(0.75)
    out = np.zeros(n)
    f0 = rng.uniform(54, 62)
    mix_into(out, _tonfo(rng, f0, 0.32, 1.0), 0)
    mix_into(out, _tonfo(rng, f0 * rng.uniform(1.12, 1.2), 0.28, rng.uniform(0.55, 0.7)), n_of(rng.uniform(0.19, 0.23)))
    # una saturazione morbida dà gli armonici fra 100 e 300 Hz: senza, sulle casse piccole (il telefono) non si sentirebbe
    p = float(np.abs(out).max()) + 1e-9
    out = np.tanh(out / p * 3.5) / np.tanh(3.5)
    out = lp(hp(out, 40, 2), 300, 2)
    return f32(fade(out, 0.002, 0.08))


# --- il ritmo -------------------------------------------------------------------------------

def colpo(rng, forte=False):
    """Un colpo di tamburo lontano nello scafo: una pelle grande (60-75 Hz che scendono, con due modi stonati sopra) e la
    lamiera che risuona bassa; lontano e cupo (niente sopra i 700 Hz), col riverbero dello scafo."""
    n = n_of(1.6)
    t = np.arange(n) / SR
    f0 = rng.uniform(58, 74)
    pelle = np.zeros(n)
    for mult, dec, g in [(1.0, 0.35, 1.0), (1.59, 0.18, 0.35), (2.14, 0.12, 0.18)]:
        f = f0 * mult * (1.0 + 0.35 * np.exp(-t / 0.03))
        pelle += np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / dec) * g
    pelle *= 1 - np.exp(-t / 0.003)
    # la mazza morbida: un soffio basso all'attacco
    pelle += lp(white(n, rng), 300, 2) * np.exp(-t / 0.015) * 0.3
    # la lamiera dello scafo che risuona, bassa e corta
    ecc = lp(white(n_of(0.02), rng), 400, 2)
    lam = resonator_bank(np.concatenate([ecc, np.zeros(n - len(ecc))]), [112, 171, 236, 318],
                         [0.5, 0.4, 0.3, 0.25], [0.5, 0.35, 0.25, 0.15])
    x = pelle + lam[:n] * 0.12
    x = lp(hp(x, 30, 2), 650 if forte else 520, 2) * (1.0 if forte else 0.8)
    y = reverb(x, ir_nave(), wet=0.45, dry=1.0, tail=False)
    if y.ndim == 2:
        y = y.mean(axis=1)
    return f32(fade(y, 0.0, 0.3))


# --- i file -------------------------------------------------------------------------------

def _a_livello(x, massimo):
    return f32(x * 10 ** ((massimo - lufs_max(x)) / 20))


def genera():
    """{nome: array}: 5 battiti e 6 colpi (2 più forti), al loro livello da vicino."""
    out = {}
    rng = np.random.default_rng(2510)
    for k in range(5):
        out['cuore_battito_%02d' % (k + 1)] = _a_livello(battito(rng), CUORE_MAX + rng.uniform(-0.8, 0.0))
    for k in range(6):
        out['inseguimento_colpo_%02d' % (k + 1)] = _a_livello(colpo(rng, forte=k < 2), RITMO_MAX + (0.0 if k < 2 else -2.0))
    return out


# --- l'esempio, come nel gioco --------------------------------------------------------------

def _vicinanza(d):
    return float(np.clip((LONTANA - d) / (LONTANA - VICINA), 0.0, 1.0))


def _lerp(a, b, v):
    return a + (b - a) * v


def scena(dur):
    """La storia dell'esempio: (t) -> (distanza di lei in m, stato), stato = 'riemerge', 'insegue', 'ritrae'."""
    def a(t):
        if t < 2.0:
            return LONTANA, 'riemerge'
        if t < 15.0:            # si avvicina
            return _lerp(LONTANA, 8.5, (t - 2.0) / 13.0), 'insegue'
        if t < 18.0:            # vicina, morde a vuoto
            return 8.0 + 0.4 * np.sin((t - 15.0) * 3.0), 'insegue'
        if t < 20.0:            # il getto: si ritrae di 6 m e resta ferma 2 s
            return 8.0 + min(1.0, (t - 18.0)) * 6.0, 'ritrae'
        return _lerp(14.0, 9.5, min(1.0, (t - 20.0) / (dur - 22.0))), 'insegue'   # torna
    return a


def esempio(suoni, canto, fiato, dur=36.0, con_cuore=True, con_ritmo=True, seme=7):
    """Come nel gioco: fiato in ciclo a x0,3 mentre insegue, il canto A (frasi del gioco) col suo tempo, il cuore e il ritmo
    fatti partire uno alla volta come in audio.gd, la distanza di lei che cambia (8-18 m) come in scena()."""
    rng = np.random.default_rng(seme)
    ir = ir_sala()
    n = n_of(dur)
    out = np.zeros((n, 2))
    # (le varianti brevi raccontano la stessa storia più in fretta)
    s36 = scena(36.0)
    storia = lambda tt: s36(tt * 36.0 / dur)
    dt = 1.0 / 60.0
    # (il fiato e il canto si sentono come da lei: 3D, unità 3 m; qui la distanza dà il volume, vicino a 8 m = 0 dB)
    fiato_l = np.zeros(n)
    canto_tr = np.zeros((n, 2))
    t = 0.0
    bpm = CUORE_BPM[0]
    cuore_t = 0.6
    ritmo_t = 0.4
    canto_t = rng.uniform(1.5, 4.0)
    canto_fine = -1.0
    cuori = [k for k in suoni if k.startswith('cuore')]
    colpi = [k for k in suoni if k.startswith('inseguimento')]
    ultimo_c, ultimo_r = '', ''
    while t < dur - 1.5:
        d, st = storia(t)
        v = _vicinanza(d)
        g_lei = (VICINA / max(d, 1.0))
        corsa = st == 'insegue'
        if corsa or st == 'ritrae':
            i = n_of(t)
            fiato_l[i:i + n_of(dt) + 1] = g_lei * (1.0 if corsa else 0.3)
        # il cuore: tempo che segue la distanza, piano (8 battiti al minuto al secondo)
        if st != 'riemerge' and con_cuore:
            voluto = _lerp(*CUORE_BPM, v) * (0.88 if st == 'ritrae' else 1.0)
            bpm += np.clip(voluto - bpm, -8 * dt, 8 * dt)
            cuore_t -= dt
            if cuore_t <= 0.0:
                k = rng.choice([c for c in cuori if c != ultimo_c])
                ultimo_c = k
                g = 10 ** ((_lerp(*CUORE_DB, v) + rng.uniform(-0.8, 0.0)) / 20)
                mix_into(out, stereo(suoni[k]) * g, n_of(t))
                cuore_t = 60.0 / bpm
        # il ritmo: più fitto quando è vicina, sparso mentre si ritrae
        if st != 'riemerge' and con_ritmo:
            ritmo_t -= dt
            if ritmo_t <= 0.0:
                k = rng.choice([c for c in colpi if c != ultimo_r])
                ultimo_r = k
                g = 10 ** ((_lerp(*RITMO_DB, v) - (3.0 if st == 'ritrae' else 0.0)) / 20)
                mix_into(out, stereo(suoni[k]) * g, n_of(t))
                if rng.random() < 0.2 and st == 'insegue':
                    k2 = rng.choice([c for c in colpi if c != k])
                    mix_into(out, stereo(suoni[k2]) * g * 0.55, n_of(t + rng.uniform(0.16, 0.22)))
                ritmo_t = _lerp(*RITMO_OGNI, v) * rng.uniform(0.8, 1.25) * (1.6 if st == 'ritrae' else 1.0)
        # il canto: solo mentre insegue, una frase alla volta
        if corsa:
            if t >= canto_fine:
                canto_t -= dt
                if canto_t <= 0.0:
                    fr = canto[rng.integers(len(canto))]
                    # (le frasi hanno già il loro filo di riverbero: qui un po' di tunnel, alla loudness del file)
                    y = reverb(fr, ir, wet=0.3, dry=1.0, tail=False)
                    y = lp(y * 10 ** ((lufs(fr) - lufs(y)) / 20) * g_lei, 900 + 1100 * v, 2)
                    mix_into(canto_tr, y, n_of(t))
                    canto_fine = t + len(fr) / SR
                    canto_t = rng.uniform(3.0, 7.0)
        else:
            if t < canto_fine:
                # la frase si spegne in 0,5 s, come Audio.dissolvi
                i0, i1 = n_of(t), min(n, n_of(t + 0.5))
                canto_tr[i0:i1] *= np.linspace(1, 0, i1 - i0)[:, None]
                canto_tr[i1:] = 0.0
            canto_fine = -1.0
            canto_t = rng.uniform(1.5, 4.0)
        t += dt
    f = np.tile(fiato, int(np.ceil(n / len(fiato))))[:n] * FIATO_X
    w = n_of(0.3)
    fiato_l = np.convolve(fiato_l, np.ones(w) / w, 'same')
    out += stereo(f * fiato_l) + canto_tr
    return f32(limiter(fade(out, 0.3, 1.5), -3.0))


def write_mp3(path, x):
    x = f32(x)
    with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as tf:
        tmp = tf.name
    try:
        wavfile.write(tmp, SR, np.clip(x, -1, 1).astype(np.float32))
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', tmp, '-c:a', 'libmp3lame', '-q:a', '2',
                        '-map_metadata', '-1', path], check=True)
    finally:
        os.unlink(tmp)


def _frasi_canto():
    """Le frasi del canto A del gioco (lavoro/canto-sirena-gioco), a x1,3 come nel gioco, oppure rigenerate se mancano."""
    cartella = os.path.join(RADICE, 'godot', 'audio', 'lei')
    frasi = []
    for k in range(1, 11):
        p = os.path.join(cartella, 'lei_tunnel_canto_%02d.ogg' % k)
        if not os.path.exists(p):
            dati = subprocess.run(['git', '-C', RADICE, 'show', 'origin/lavoro/canto-sirena-gioco:godot/audio/lei/lei_tunnel_canto_%02d.ogg' % k],
                                  capture_output=True).stdout
            if not dati:
                continue
            p = os.path.join(tempfile.gettempdir(), 'canto_%02d.ogg' % k)
            open(p, 'wb').write(dati)
        frasi.append(read_audio(p, 1))
    return frasi


def gioco():
    from comune import salva
    for nome, x in genera().items():
        picco = 20.0 * np.log10(float(np.abs(x).max()) + 1e-12) + 0.01
        cartella = 'giocatore' if nome.startswith('cuore') else 'ambiente'
        nota = ('tunnel, inseguimento (25 ottobre sera): il battito del cuore, uno alla volta col tempo che segue lei'
                if cartella == 'giocatore' else
                'tunnel, inseguimento (25 ottobre sera): colpo di tamburo lontano nello scafo, più fitti quando lei è vicina')
        salva(cartella, nome, x, loudness=None, picco=picco, qualita=5, nota=nota)


def main():
    if len(sys.argv) > 1 and sys.argv[1] == 'gioco':
        gioco()
        return
    os.makedirs(USCITA, exist_ok=True)
    suoni = genera()
    canto = _frasi_canto()
    fiato = tunnel.genera()['lei_tunnel_fiato']
    for nome, kw, dur in [('inseguimento_esempio_36s', {}, 36.0),
                          ('solo_cuore_esempio_22s', {'con_ritmo': False}, 22.0),
                          ('solo_ritmo_esempio_22s', {'con_cuore': False}, 22.0)]:
        x = esempio(suoni, canto, fiato, dur=dur, **kw)
        write_mp3(os.path.join(USCITA, nome + '.mp3'), x)
        write_ogg(os.path.join(USCITA, nome + '.ogg'), x, 5)
        print(nome, '%.1f s' % (len(x) / SR), 'LUFS %.1f' % lufs(x), 'picco %.1f dB' % (20 * np.log10(np.abs(x).max())),
              'canto: %d frasi' % len(canto))


if __name__ == '__main__':
    main()
