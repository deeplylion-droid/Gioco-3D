"""Anteprima per il coordinatore (circa 55 s): qualche secondo di sigla pulita (titolo), poi la
sala di notte con pioggia sulla cupola, vento e nave, passi sulle piastrelle bagnate e
nell'acqua, un neon che sfarfalla, un tuono vicino, lo zaino che aspira e spruzza, il pulsante
del piedistallo e la sigla rovinata che parte dalla statua e scivola nel minore.
Usa i file già generati in godot/audio/. Uscita: godot/audio/anteprima/anteprima_audio.ogg
(la cartella ha un .gdignore: Godot non la importa e non finisce nel gioco esportato).
"""
import os

import numpy as np

from comune import AUDIO, ir_sala
from lib_audio import (SR, db, fade, limiter, lp, lufs, mix_into, n_of, pan, read_audio, reverb,
                       stereo, write_ogg)

DUR = 56.0


def f(rel):
    return os.path.join(AUDIO, rel)


def leggi(rel, canali=2):
    return read_audio(f(rel), canali)


def main():
    rng = np.random.default_rng(7)
    n = n_of(DUR)
    amb = np.zeros((n, 2), dtype=np.float32)    # fondi (già riverberati)
    eff = np.zeros((n, 2), dtype=np.float32)    # effetti: passano per il riverbero della sala
    mus = np.zeros((n, 2), dtype=np.float32)

    # 0-7 s: la sigla pulita, come nella schermata del titolo
    sp = leggi('musica/sigla_pulita.ogg')[:n_of(7.5)]
    mix_into(mus, fade(sp, 0.0, 2.0) * db(-3), 0)

    # fondi dalla sala (entrano mentre la sigla sfuma)
    t0 = 6.0
    for rel, g in [('ambiente/pioggia_cupola_loop.ogg', 0.0), ('ambiente/vento_loop.ogg', -2.0),
                   ('ambiente/nave_loop.ogg', 0.0)]:
        x = leggi(rel)
        x = np.concatenate([x, x])[:n - n_of(t0)]
        mix_into(amb, fade(x, 2.5, 3.0) * db(g), n_of(t0))

    def passo(nome, t, g=0.0, p=0.0):
        x = leggi(f'giocatore/{nome}.ogg', 1)
        mix_into(eff, pan(x * db(g), p), n_of(t))

    # passi sulle piastrelle bagnate, poi nella pozza, poi di nuovo sul bagnato
    t = 8.0
    for k in range(12):
        passo(f'passo_bagnato_{k % 6 + 1:02d}', t, -5 + rng.uniform(-1, 1), (-0.08 if k % 2 else 0.08))
        t += 0.47 + rng.uniform(-0.03, 0.03)
    for k in range(4):
        passo(f'passo_acqua_{k % 6 + 1:02d}', t, -4, (-0.08 if k % 2 else 0.08))
        t += 0.55
    for k in range(5):
        passo(f'passo_bagnato_{(k + 2) % 6 + 1:02d}', t, -6, (-0.08 if k % 2 else 0.08))
        t += 0.47
    # uno scricchiolio a sinistra, lontano
    mix_into(amb, pan(leggi('ambiente/nave_scricchiolio_02.ogg', 1) * db(-9), -0.7), n_of(10.0))
    # tuono vicino
    mix_into(amb, leggi('ambiente/tuono_vicino_01.ogg') * db(-1), n_of(13.5))
    # passando sotto un neon che sfarfalla
    bz = leggi('effetti/neon_ronzio_loop.ogg', 1)
    bz = np.concatenate([bz, bz, bz])[:n_of(6.0)]
    envl = np.interp(np.arange(len(bz)) / SR, [0, 2.5, 3.5, 6.0], [0, 1, 1, 0])
    gate = np.ones(len(bz))
    for a, b in [(2.6, 2.75), (2.9, 2.95), (3.3, 3.6), (3.7, 3.75)]:
        gate[n_of(a):n_of(b)] = 0.05
    mix_into(eff, pan(bz * envl * gate * db(-12), 0.3), n_of(17.0))
    for tc in [19.6, 19.9, 20.3, 20.75]:
        mix_into(eff, pan(leggi('effetti/neon_clic_0%d.ogg' % (1 + int(tc * 10) % 3), 1) * db(-12), 0.35), n_of(tc))
    # lo zaino: aspira dalla vasca, serbatoio pieno, poi spruzza sul pulsante del piedistallo
    ta = 24.0
    mix_into(eff, stereo(leggi('giocatore/zaino_aspira_inizio.ogg', 1) * db(-3)), n_of(ta))
    asp = leggi('giocatore/zaino_aspira_loop.ogg', 1)
    asp = np.concatenate([asp, asp])[:n_of(3.0)]
    mix_into(eff, stereo(fade(asp, 0.1, 0.1) * db(-3)), n_of(ta + 0.45))
    mix_into(eff, stereo(leggi('giocatore/zaino_aspira_fine.ogg', 1) * db(-3)), n_of(ta + 3.4))
    mix_into(eff, stereo(leggi('giocatore/zaino_pieno.ogg', 1) * db(-2)), n_of(ta + 3.0))
    tg = 29.0
    mix_into(eff, stereo(leggi('giocatore/zaino_getto_inizio.ogg', 1) * db(-2)), n_of(tg))
    get = leggi('giocatore/zaino_getto_loop.ogg', 1)
    get = np.concatenate([get, get])[:n_of(2.6)]
    mix_into(eff, stereo(fade(get, 0.08, 0.1) * db(-3)), n_of(tg + 0.12))
    imp = leggi('giocatore/zaino_impatto_loop.ogg', 1)[:n_of(2.3)]
    mix_into(eff, pan(lp(fade(imp, 0.1, 0.2), 6000) * db(-10), 0.1), n_of(tg + 0.35))
    mix_into(eff, pan(leggi('effetti/pulsante_premuto.ogg', 1) * db(-6), 0.1), n_of(tg + 1.4))
    mix_into(eff, stereo(leggi('giocatore/zaino_getto_fine.ogg', 1) * db(-4)), n_of(tg + 2.7))
    # la sigla rovinata dall'altoparlante del piedistallo, a qualche metro
    ts = tg + 1.9
    sr_ = leggi('musica/sigla_rovinata.ogg')
    durata_sigla = DUR - ts - 1.0
    sr_ = fade(sr_[:n_of(durata_sigla)], 0.0, 3.0)
    mix_into(mus, lp(sr_, 7000) * db(-2), n_of(ts))
    # gocce, un gemito lontano e la sirena dell'allarme in fondo alla nave
    for tc, g in [(36.2, -14), (39.0, -16), (43.1, -14), (47.5, -15), (51.0, -14)]:
        x = leggi('ambiente/goccia_acqua_0%d.ogg' % rng.integers(1, 7), 1)
        mix_into(eff, pan(x * db(g), rng.uniform(-0.6, 0.6)), n_of(tc))
    mix_into(amb, pan(leggi('ambiente/nave_gemito_02.ogg', 1) * db(-8), 0.6), n_of(40.5))
    mix_into(amb, leggi('ambiente/tuono_lontano_02.ogg') * db(-4), n_of(45.0))
    # riverbero della sala sugli effetti (come il bus Effetti del gioco)
    eff = reverb(eff, ir_sala(), wet=0.26, dry=1.0, tail=False)
    out = amb + eff + mus
    out = fade(out, 0.0, 3.0)
    g = db(-16.0 - lufs(out))
    out = limiter(out * g, -1.0)
    path = os.path.join(AUDIO, 'anteprima', 'anteprima_audio.ogg')
    write_ogg(path, out, 5)
    with open(os.path.join(AUDIO, 'anteprima', '.gdignore'), 'w') as fh:
        fh.write('')
    print(f'anteprima: {path}  {len(out) / SR:.1f}s  LUFS {lufs(out):.1f}  picco {np.abs(out).max():.2f}')



if __name__ == '__main__':
    main()
