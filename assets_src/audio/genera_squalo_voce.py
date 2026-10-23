"""La voce nuova del mostro-squalo all'inizio (riscontro dell'utente del 23 ottobre su squalo_minaccia e
squalo_ringhio: "si sono questi, fanno cagare"). I difetti dei primi: il brontolio a 46-58 Hz sporcato apposta
(distorsione), quasi tutto sotto gli 80 Hz: dagli altoparlanti piccoli restava solo il ronzio della distorsione.

Qui una bestia grossa e bagnata a 30 cm dalla faccia, solo sintesi (nessun campione: si può vendere):
- la gola vibra a 85-160 Hz (non 50), con le false corde che raddoppiano il periodo (la ruvidità dei ruggiti
  veri), il tremolio irregolare del rullo, i formanti larghi di un tratto lungo che si muovono sempre;
- niente distorsione: solo una saturazione leggera; sotto i 70 Hz si taglia;
- la saliva: bollicine fitte e schiocchi umidi che seguono la voce, e il risucchio prima dei ringhi;
- tutto deve restare chiaro e pauroso anche tagliato sotto i 150 Hz (telefono, portatile).

Due caratteri, da far scegliere all'utente:
- A, "orso": ringhio profondo e rotondo che rulla, il fiato di adesso (genera_lei.respiro, gli stessi cicli);
- B, "coccodrillo": ringhio più alto, sibilante e rasposo, con più saliva; un fiato nuovo più umido e animale
  (le guance e le labbra che sbattono, il muco).
I cicli del fiato sono quelli di squalo_minaccia (seme 2110): la mascella del modello respira a tempo con loro
(mostro_anim.fiato_mascella).

Uso: /home/user/tools/blender-venv/bin/python assets_src/audio/genera_squalo_voce.py [proposte | gioco A|B A|B]
proposte (di serie): docs/proposte/squalo_suoni/ con prima/A/B di minaccia e ringhio in mp3 (-16 LUFS), le stesse
tagliate sotto i 150 Hz ("_telefono") e il mix della scena (i tempi del gioco). gioco <minaccia> <ringhio>: scrive
godot/audio/squalo/squalo_minaccia.ogg e squalo_ringhio.ogg con le versioni scelte.
"""
import os
import subprocess
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from comune import RADICE, ir_piccola  # noqa: E402
from genera_ambiente import bollicina, treno_impulsi  # noqa: E402
from genera_effetti import impulso  # noqa: E402
from genera_lei import gola, tratto, respiro  # noqa: E402
from lib_audio import (SR, mono, bp, env_points, f32, fade, hp, lp, mix_into, n_of, resonator_bank, reverb,  # noqa: E402
                       smooth_noise, white, normalize_lufs, limiter, lufs, read_audio, write_wav)

MINACCIA_INIZIO = 0.8
RICHIAMO = 5.4
SCATTI = (2.4 + 0.7, 2.4 + 1.6, 2.4 + 2.5)
USCITA = os.path.join(RADICE, 'docs', 'proposte', 'squalo_suoni')

CARATTERI = {
    # f0 (Hz), rullo (colpi al secondo), formanti [(Hz, Q, guadagno)], soffio, sotto (raddoppio del periodo)
    'A': dict(f0=95.0, rullo=21.0, formanti=[(330, 2.0, 1.0), (800, 2.6, 0.7), (1650, 3.5, 0.35), (2600, 5.0, 0.15)],
              aspira=0.55, sotto=0.5, saliva=0.6),
    'B': dict(f0=125.0, rullo=33.0, formanti=[(460, 2.2, 0.9), (1150, 2.8, 0.8), (2300, 3.5, 0.45), (3400, 5.0, 0.2)],
              aspira=1.1, sotto=0.35, saliva=1.3),
}


def _norm(x):
    p = float(np.max(np.abs(x)))
    return x / p if p > 0 else x


def saliva(rng, n, inviluppo, densita=1.0):
    """Bollicine fitte e schiocchi umidi (la saliva che si muove in bocca), più fitti dove la voce è forte."""
    out = np.zeros(n)
    k = int(rng.poisson(90 * densita * n / SR))
    for _ in range(k):
        i = int(rng.integers(0, n))
        if rng.random() > inviluppo[i]:
            continue
        b = bollicina(rng, rng.uniform(1300, 4800), rng.uniform(0.0015, 0.006), rise=rng.uniform(0.3, 1.2))
        mix_into(out, b * rng.uniform(0.05, 0.25) * inviluppo[i], i)
    cr = treno_impulsi(n, 120 * densita, rng, alpha=2.2) * inviluppo
    out += resonator_bank(cr, [900, 1700, 3100], [0.006, 0.004, 0.003], [1, 0.6, 0.35]) * 0.12
    return f32(out)


def voce(rng, dur, curva_f0, car, bocca=1.0):
    """La gola della bestia: impulsi irregolari con il raddoppio del periodo, il rullo, i formanti che si
    muovono. curva_f0: [(t, moltiplicatore della f0 del carattere)]."""
    n = n_of(dur)
    f0 = env_points([(t, car['f0'] * m) for t, m in curva_f0], n) * (1 + 0.05 * smooth_noise(n, 4, rng))
    g = gola(rng, dur, f0, jitter=0.14, shimmer=0.35, sotto=car['sotto'], aspira=car['aspira'])
    # il rullo: la gola che sbatte, irregolare (non un tremolo elettronico)
    r = car['rullo'] * (1 + 0.25 * smooth_noise(n, 3, rng))
    rullo = np.abs(np.sin(np.pi * np.cumsum(r) / SR)) ** 0.8
    g *= 0.45 + 0.55 * rullo * (0.8 + 0.2 * smooth_noise(n, 9, rng))
    fm = [(f * bocca, q, a) for f, q, a in car['formanti']]
    v = tratto(rng, g, fm, moto=0.12, velocita=1.4)
    # il petto: una risonanza larga a 120-160 Hz, che si sente anche dai telefoni nelle armoniche
    v += tratto(rng, g, [(140, 1.5, 0.5)], moto=0.05, velocita=0.5)
    v = np.tanh(_norm(v) * 1.3) / np.tanh(1.3)          # saturazione leggera, niente distorsione
    return f32(hp(lp(v, 6000, 2), 70, 2))


def risucchio(rng, dur=0.22):
    """Il risucchio di saliva tra i denti prima di un ringhio."""
    n = n_of(dur)
    e = env_points([(0, 0), (dur * 0.6, 1), (dur, 0)], n) ** 1.5
    v = bp(white(n, rng), 1200, 5200, 2) * e
    v = tratto(rng, v, [(1800, 3.0, 1.0), (3200, 4.0, 0.6)], moto=0.2, velocita=6)
    return f32(v * 0.6 + saliva(rng, n, e, 2.5))


def ringhio_corto(rng, car, dur=0.6, forza=1.0):
    """Un ringhio corto da morso: parte di colpo, sale e si chiude."""
    v = voce(rng, dur, [(0, 1.15), (0.08, 1.45), (dur * 0.6, 1.2), (dur, 0.9)], car, bocca=1.15)
    e = env_points([(0, 0), (0.025, 1.0), (dur * 0.45, 0.75), (dur, 0)], len(v))
    v = v * e
    return f32((v + saliva(rng, len(v), e, car['saliva']) * 1.2) * forza)


def fiato_B(rng, dur, cicli):
    """Il fiato nuovo: più umido e animale. Espira: aria pesante nel tratto, le guance e le labbra che sbattono
    (un frullo irregolare a 25-40 Hz), il muco; inspira: un risucchio bagnato che gorgoglia."""
    out = np.zeros(n_of(dur))
    for t0, d, tipo, forza in cicli:
        k = n_of(d)
        if tipo == 'esp':
            e = env_points([(0, 0), (d * 0.15, 1), (d * 0.6, 0.8), (d, 0)], k)
            aria = lp(white(k, rng), 2600, 2)
            frullo = 0.55 + 0.45 * np.abs(np.sin(np.pi * np.cumsum(32 * (1 + 0.3 * smooth_noise(k, 5, rng))) / SR))
            v = tratto(rng, aria * frullo, [(220, 1.8, 0.9), (520, 2.2, 1.0), (1250, 3.0, 0.5), (2500, 4.0, 0.2)],
                       moto=0.15, velocita=1.0)
            v = _norm(v) * e
            v += saliva(rng, k, e, 1.6) * 0.9
        else:
            e = env_points([(0, 0), (d * 0.55, 1), (d * 0.9, 0.7), (d, 0)], k) ** 1.4
            aria = bp(white(k, rng), 600, 3500, 2)
            v = tratto(rng, aria, [(700, 2.5, 0.8), (1500, 3.5, 0.7), (2800, 5.0, 0.3)], moto=0.2, velocita=1.5)
            v = _norm(v) * e * 0.7
            g = np.zeros(k)
            for _ in range(int(d * 14)):
                mix_into(g, bollicina(rng, rng.uniform(500, 1400), rng.uniform(0.005, 0.012), rise=0.6) *
                         rng.uniform(0.2, 0.5), int(rng.integers(0, max(k - n_of(0.08), 1))))
            v += g * e + saliva(rng, k, e, 1.2) * 0.6
        mix_into(out, v * forza, n_of(t0))
    return f32(out)


def cicli_fiato():
    """Gli stessi cicli di squalo_minaccia (seme 2110, le stesse estrazioni): la mascella respira con loro."""
    rng = np.random.default_rng(2110)
    dur = RICHIAMO - MINACCIA_INIZIO + 0.4
    cicli = []
    t = 0.05
    while t < dur - 0.6:
        lungo = 1.2 if t < 1.4 else 0.85
        cicli.append((t, lungo * 0.45, 'insp', 0.55))
        cicli.append((t + lungo * 0.45, lungo * 0.55, 'esp', 1.0))
        t += lungo + rng.uniform(0.02, 0.12)
    return cicli, dur


def minaccia(variante):
    """Il fiato a 30 cm dalla faccia, la gola che brontola sotto (pulita, a 90-130 Hz) e i tre ringhi corti con
    il risucchio, agli scatti della testa (2,3 s, 3,2 s, 4,1 s dall'inizio del file)."""
    car = CARATTERI[variante]
    cicli, dur = cicli_fiato()
    rng = np.random.default_rng(3110 + ord(variante))
    n = n_of(dur)
    out = np.zeros(n)
    if variante == 'A':
        fiato = respiro(rng, dur, cicli, umido=2.2, rauco=0.6) * 1.5
    else:
        fiato = fiato_B(rng, dur, cicli)
    mix_into(out, _norm(fiato) * 0.8, 0)
    # sotto, la gola che brontola: la stessa voce, piano, che segue il fiato (più forte nelle espirazioni)
    sotto = voce(rng, dur, [(0, 0.95), (dur, 1.0)], car, bocca=0.9)
    e = np.full(n, 0.25)
    for t0, d, tipo, _ in cicli:
        if tipo == 'esp':
            i0, k = n_of(t0), n_of(d)
            e[i0:i0 + k] += env_points([(0, 0), (d * 0.3, 0.6), (d, 0)], len(e[i0:i0 + k]))
    mix_into(out, sotto * e * 0.32, 0)
    from genera_squalo import schiocco
    for tc in SCATTI:
        t = tc - MINACCIA_INIZIO
        mix_into(out, risucchio(rng) * 0.5, n_of(t - 0.28))
        mix_into(out, ringhio_corto(rng, car) * 0.95, n_of(t - 0.06))
        mix_into(out, schiocco(rng) * 0.8, n_of(t + 0.12))
    out = reverb(out, ir_piccola(), wet=0.12)
    return f32(mono(fade(out, 0.05, 0.3)))


def ringhio(variante):
    """Il ringhio della girata, verso la porta: corto e aggressivo (1,1 s), un risucchio e poi il ruggito che sale
    e si chiude di colpo."""
    car = CARATTERI[variante]
    rng = np.random.default_rng(3130 + ord(variante))
    dur = 1.25
    out = np.zeros(n_of(dur))
    mix_into(out, risucchio(rng, 0.18) * 0.6, 0)
    d = 1.0
    v = voce(rng, d, [(0, 1.1), (0.12, 1.6), (0.5, 1.75), (0.8, 1.4), (d, 1.0)], car, bocca=1.3)
    e = env_points([(0, 0), (0.03, 1.0), (0.55, 0.9), (0.85, 0.6), (d, 0)], len(v))
    v = v * e + saliva(rng, len(v), e, car['saliva'] * 1.3) * 1.1
    mix_into(out, v, n_of(0.15))
    out = reverb(out, ir_piccola(), wet=0.15)
    return f32(mono(fade(out, 0.005, 0.12)))


def _mp3(x, nome, cartella=USCITA):
    os.makedirs(cartella, exist_ok=True)
    w = os.path.join(cartella, nome + '.wav')
    write_wav(w, x)
    subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-i', w, '-b:a', '192k', os.path.join(cartella, nome + '.mp3')],
                   check=True)
    os.remove(w)


def _pronto(x, loud=-16.0):
    return f32(limiter(normalize_lufs(f32(x), loud, -1.0), -1.0))


def proposte():
    vecchi = {'minaccia': read_audio(os.path.join(RADICE, 'godot', 'audio', 'squalo', 'squalo_minaccia.ogg')),
              'ringhio': read_audio(os.path.join(RADICE, 'godot', 'audio', 'squalo', 'squalo_ringhio.ogg'))}
    nuovi = {}
    for nome, f in (('minaccia', minaccia), ('ringhio', ringhio)):
        versioni = {'prima': vecchi[nome], 'A': f('A'), 'B': f('B')}
        for v, x in versioni.items():
            x = _pronto(x)
            nuovi[(nome, v)] = x
            tel = hp(x, 150, 4)
            print('%-9s %-6s %4.1f s  LUFS %.1f  tagliato sotto 150 Hz: %.1f (perde %.1f dB)' % (
                nome, v, len(x) / SR, lufs(x), lufs(tel), lufs(x) - lufs(tel)))
            _mp3(x, f'{nome}_{v}')
            _mp3(f32(tel), f'{nome}_{v}_telefono')
    return nuovi


def mix_scena(nuovi, v_min, v_ring, nome):
    """La scena intera con i tempi del gioco (main: animazione di prima), ai livelli del gioco (file + PIU_FORTE),
    senza la distanza: indicativo."""
    import json
    tempi = json.loads(subprocess.run(['git', '-C', RADICE, 'show',
                                       'origin/main:godot/assets/models/mascotte/mostro_squalo_A_rig.json'],
                                      capture_output=True, text=True, check=True).stdout)
    A = os.path.join(RADICE, 'godot', 'audio')
    dur = tempi['porta'] + 3.0
    out = np.zeros(n_of(dur))
    def metti(x, t, loud, piu):
        x = normalize_lufs(f32(x), loud, -1.0, short=len(x) < SR * 2)
        mix_into(out, x * 10 ** (piu / 20), n_of(t))
    piu_nuovo = 3.0 if v_min != 'prima' else 6.0
    metti(nuovi[('minaccia', v_min)], 0.8, -15, piu_nuovo)
    for k, tc in enumerate(SCATTI):
        metti(read_audio(os.path.join(A, 'squalo', f'squalo_denti_{k + 1:02d}.ogg')), tc + 0.08, -11, 5)
    metti(read_audio(os.path.join(A, 'squalo', 'jilly_richiamo.ogg')), tempi['richiamo'], -20, 3)
    metti(nuovi[('ringhio', v_ring)], tempi['giro'] - 0.1, -14, 3.0 if v_ring != 'prima' else 6.0)
    metti(read_audio(os.path.join(A, 'squalo', 'squalo_sbuffo.ogg')), tempi['sbuffo'] - 0.07, -16, 6)
    for i, tp in enumerate(tempi['passi']):
        metti(read_audio(os.path.join(A, 'squalo', f'squalo_passo_{i % 4 + 1:02d}.ogg')), tp, -12, 5 - 1.5 * i)
    _mp3(_pronto(out, -16.0), nome)


def main():
    if len(sys.argv) > 1 and sys.argv[1] == 'gioco':
        from comune import salva
        salva('squalo', 'squalo_minaccia', minaccia(sys.argv[2]), loudness=-15, qualita=5,
              nota="fiato a 30 cm, gola che brontola sotto e tre ringhi corti con il risucchio della saliva "
                   "(2,3 s, 3,2 s, 4,1 s dall'inizio del file); versione %s del 23 ottobre" % sys.argv[2])
        salva('squalo', 'squalo_ringhio', ringhio(sys.argv[3]), loudness=-14, corto=True, qualita=5,
              nota='il ringhio corto e aggressivo verso la porta; versione %s del 23 ottobre' % sys.argv[3])
        return
    nuovi = proposte()
    mix_scena(nuovi, 'prima', 'prima', 'scena_prima')
    mix_scena(nuovi, 'A', 'A', 'scena_A')
    mix_scena(nuovi, 'B', 'B', 'scena_B')


if __name__ == '__main__':
    main()
