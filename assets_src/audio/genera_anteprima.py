"""Anteprime per il coordinatore, fatte con i file già generati in godot/audio/.

- anteprima_audio.ogg (circa 55 s): qualche secondo di sigla pulita (titolo), poi la sala di
  notte con pioggia sulla cupola, vento e nave, passi sulle piastrelle bagnate e nell'acqua, un
  neon che sfarfalla, un tuono vicino, lo zaino che aspira e spruzza, il pulsante del piedistallo
  e la sigla rovinata che parte dalla statua e scivola nel minore.
- anteprima_tecnici.ogg (circa 40 s): la sala pompe delle tappe 5-6 sentita da chi gioca, con i
  tempi di scripts/tecnici/risveglio_sala_pompe.gd e le distanze vere della scena.
- anteprima_lei.ogg (circa 27 s): la tappa 8 nell'area bimbi, la fossa che ribolle, lei che sbuca,
  guarda e scivola sotto; poi l'altro finale, il morso (con i suoni del gioco: dal 16 ottobre la
  versione gutturale).
- proposta_lei_gutturale.ogg e proposta_lei_estrema.ogg (circa 20 s): le due proposte per lei più
  gutturale (respiro umido, gola che gorgoglia sott'acqua, rantolo, ringhio prima del morso), in
  due intensità (genera_lei.proposte). Il 16 ottobre l'utente ha scelto la gutturale, che ora è
  nel gioco; le due anteprime restano com'erano.
- confronto_pioggia_bollicine.ogg (circa 31 s): la sala con solo i fondi, 15 s con la pioggia di
  prima (con le bollicine dei rivoli) e 15 s con quella di adesso (16 ottobre).
- confronto_passi_goccioline.ogg (circa 21 s): si cammina sul bagnato nella sala, 10 s con i passi
  di oggi (con le goccioline che schizzano) e 10 s con gli stessi passi senza goccioline.
- cancello_stagno.ogg (circa 10 s): nella camera delle onde, dopo la scala del pozzo, i due
  cancelli stagni che si aprono da soli uno dopo l'altro (il secondo 2 s dopo, più lontano), col
  fondo della stanza tecnica sotto (16 ottobre).
Le anteprime delle altre proposte (proposta_<nome>_a/b.ogg) le fa genera_proposte.py.

Uscita: godot/audio/anteprima/ (la cartella ha un .gdignore: Godot non la importa e non finisce
nel gioco esportato). Uso: genera_anteprima.py [sala|tecnici|lei|proposte|pioggia|passi|cancello]
(senza argomenti, tutte).
"""
import os
import sys

import numpy as np

from comune import AUDIO, ir_sala
from lib_audio import (SR, biquad, db, fade, hp, limiter, lp, lufs, mix_into, n_of, pan, read_audio,
                       reverb, stereo, varispeed, write_ogg)

DUR = 56.0


def f(rel):
    return os.path.join(AUDIO, rel)


def leggi(rel, canali=2):
    return read_audio(f(rel), canali)


def anteprima_sala():
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


# --- sala pompe (tappe 5-6) -------------------------------------------------------------------

def tile(x, dur, offset=0.0):
    """Un loop letto per dur secondi a partire da offset (AudioLoop parte da un punto a caso)."""
    k = n_of(dur)
    a = n_of(offset) % len(x)
    reps = (a + k) // len(x) + 2
    return np.concatenate([x] * reps, axis=0)[a:a + k]


def curva_loop(eventi, dur, fps=60):
    """Volume e tono di un AudioLoop nel tempo, fotogramma per fotogramma come nel gioco
    (audio_loop.gd). eventi: [(t, volume, tono)]. Restituisce due curve per campione."""
    nf = int(dur * fps) + 2
    att, ton, vol, tono, suona = 0.0, 1.0, 0.0, 1.0, False
    va, ta = np.zeros(nf), np.zeros(nf)
    ev = sorted(eventi)
    j = 0
    d = 1.0 / fps
    for f in range(nf):
        while j < len(ev) and ev[j][0] <= f * d:
            _, vol, tono = ev[j]
            j += 1
        if att <= 0.0005 and not suona:
            ton = tono
        else:
            ton += (tono - ton) * (1.0 - np.exp(-4.0 * d))
        passo = d * 6.0 * max(abs(vol - att), 0.05)
        att = min(att + passo, vol) if vol > att else max(att - passo, vol)
        suona = att > 0.0005
        va[f], ta[f] = att, ton
    ts = np.arange(n_of(dur)) / SR
    tf = np.arange(nf) * d
    return np.interp(ts, tf, va), np.interp(ts, tf, ta)


def distanza_db(d, unit):
    """Attenuazione di AudioStreamPlayer3D (inverse distance, max_db 0)."""
    return min(0.0, 20 * np.log10(unit / max(d, 0.01)))


def anteprima_tecnici():
    """Chi gioca sta alla leva della sala pompe. Distanze dalla scena (sala_principale.tscn):
    pompe a 4, 9 e 13 m, maniglione a 6 m, monitor a 8 m, paratie a 24 e 27 m, vasca della
    medusa a 37 m. Tempi del risveglio come in risveglio_sala_pompe.gd."""
    rng = np.random.default_rng(56)
    DURT = 41.0
    n = n_of(DURT)
    eff = np.zeros((n, 2), dtype=np.float32)    # bus Effetti (riverbero della sala)
    mus = np.zeros((n, 2), dtype=np.float32)
    amb = np.zeros((n, 2), dtype=np.float32)

    def mono(rel):
        return leggi(rel, 1)

    def metti(x, t, g_db=0.0, p=0.0, dest=None):
        dest = eff if dest is None else dest
        mix_into(dest, pan(x * db(g_db), p) if x.ndim == 1 else x * db(g_db), n_of(t))

    # fondo: la nave, bassa (la sala pompe è sotto, lontano dalla cupola)
    nave = tile(leggi('ambiente/nave_loop.ogg'), DURT, 3.0)
    mix_into(amb, fade(nave, 1.5, 3.0) * db(-11), 0)
    for tc in [2.8, 9.4, 13.1]:
        metti(mono('ambiente/goccia_acqua_0%d.ogg' % rng.integers(1, 7)), tc, -17, rng.uniform(-0.5, 0.5))

    # 1) la porta del ponte inferiore: il maniglione non si apre (due spinte)
    metti(mono('tecnici/maniglione_bloccato.ogg'), 0.6, -1.0, 0.45)
    metti(varispeed(mono('tecnici/maniglione_bloccato.ogg'), 2 ** (0.4 / 12)), 1.75, -1.5, 0.45)

    # 2) le tre pompe nell'ordine dello schema, poi la leva: ruggiscono
    T_LEVA = 14.6
    T_VIA = 31.6             # chi gioca esce dalla porta: le pompe restano indietro
    pompe = [(3.6, 13.2, -0.55, 0.3), (7.2, 8.7, -0.35, 1.7), (10.8, 4.3, -0.15, 2.9)]
    roar = mono('tecnici/pompe_ruggito_loop.ogg')
    motori = np.zeros((n, 2), dtype=np.float32)
    for t0, dist, p, off in pompe:
        g = distanza_db(dist, 6.0)
        metti(mono('tecnici/pompa_avvio.ogg'), t0, g, p)
        vol, ton = curva_loop([(t0, 0.45, 0.65), (T_LEVA, 1.0, 0.95)], DURT)
        src = tile(roar, DURT + 1.0, off)
        x = varispeed(src, ton)[:n]
        x = np.pad(x, (0, n - len(x))) * vol[:n]
        mix_into(motori, pan(x * db(g), p), 0)

    # 3) la leva: il flash con la sigla a tutto volume per un secondo, poi salta la corrente
    metti(varispeed(mono('effetti/cancello_fine.ogg'), 0.8), T_LEVA, 0.0, 0.1)
    metti(varispeed(mono('ambiente/nave_gemito_01.ogg'), 0.6), T_LEVA + 0.1, -1.0, -0.35)
    metti(stereo(varispeed(mono('effetti/faro_acceso.ogg'), 0.8)), T_LEVA, 4.0)
    sig = leggi('musica/sigla_pulita.ogg')[:n_of(1.0)]
    mix_into(mus, fade(sig, 0.0, 0.03) * db(4.0), n_of(T_LEVA))
    T_BLACK = T_LEVA + 1.0
    metti(leggi('tecnici/corrente_salta.ogg'), T_BLACK, 0.0)

    # 4) lontano, dalla vasca della medusa (dietro, a sinistra): la plastica, poi il tonfo
    T_PLAST = T_BLACK + 1.4
    lontano = np.array([1.0, 0.8])          # un po' a sinistra
    metti(leggi('tecnici/plastica_piega_lontano.ogg') * lontano, T_PLAST, distanza_db(37, 40.0))
    T_TONFO = T_PLAST + 2.6
    metti(leggi('tecnici/tonfo_acqua_lontano.ogg') * lontano, T_TONFO, distanza_db(37, 40.0))

    # 5) le paratie della camera delle onde si abbassano (4,5 s) e sbattono in fondo
    T_PAR = T_TONFO + 1.2
    par = mono('tecnici/paratia_scende_loop.ogg')
    for dist, p, off in [(24.0, -0.5, 0.4), (27.4, -0.65, 1.9)]:
        g = distanza_db(dist, 12.0)
        vol, _ = curva_loop([(T_PAR, 1.0, 1.0), (T_PAR + 4.5, 0.0, 1.0)], DURT)
        x = tile(par, DURT, off) * vol
        x = biquad(x, 'highshelf', 6000, 0.7, -20 * (1 - db(g)))
        mix_into(eff, pan(x * db(g), p), 0)
        colpo = biquad(varispeed(mono('effetti/porta_chiusa.ogg'), 0.7), 'highshelf', 6000, 0.7, -17)
        metti(colpo, T_PAR + 4.5 + rng.uniform(0.0, 0.05), 6.0 + distanza_db(dist, 4.0), p)

    # 6) finito il risveglio ci si avvicina al monitor: solo neve
    neve = tile(mono('tecnici/crt_neve_loop.ogg'), 5.0, 1.1)
    k = len(neve)
    avv = np.interp(np.arange(k) / SR, [0, 1.8, 3.2, 5.0], [distanza_db(8, 2), 0.0, 0.0, distanza_db(6, 2)])
    metti(neve * 10.0 ** (avv / 20.0), 26.4, 0.0, 0.15)

    # 7) il maniglione si sblocca e la porta pesante si apre; si esce
    T_PORTA = 31.4
    metti(mono('tecnici/porta_ponte_apre.ogg'), T_PORTA, -0.5, 0.35)
    # chi esce si lascia dietro le pompe: si allontanano e restano dietro la porta
    via = np.clip((np.arange(n) / SR - T_VIA - 1.2) / 5.0, 0, 1)[:, None]
    eff += motori * (1 - 0.85 * via) + lp(motori, 500) * 0.35 * via
    # riverbero della sala sugli effetti (come il bus Effetti del gioco)
    eff = reverb(eff, ir_sala(), wet=0.26, dry=1.0, tail=False)
    out = hp(amb + eff + mus, 20, 2)
    out = fade(out, 0.3, 2.5)
    g = db(-16.0 - lufs(out))
    out = limiter(out * g, -1.0)
    path = os.path.join(AUDIO, 'anteprima', 'anteprima_tecnici.ogg')
    write_ogg(path, out, 5)
    print(f'anteprima: {path}  {len(out) / SR:.1f}s  LUFS {lufs(out):.1f}  picco {np.abs(out).max():.2f}')


# --- area bimbi: lei (tappa 8) ----------------------------------------------------------------

def anteprima_lei():
    """Al buio nell'area bimbi, sotto la pioggia sulla cupola: si segue la scia, la fossa ribolle
    sempre più vicina, lei sbuca dal bordo a 6,5 m, guarda, scivola sotto e torna il silenzio.
    Poi, dopo una pausa, l'altro finale: se le vai incontro ti prende (morso, stinger al lampo
    rosso, il mondo che si abbassa). Livelli e distanze come nel gioco (audio.gd, lei_sbuca.gd)."""
    rng = np.random.default_rng(88)
    DURT = 27.0
    n = n_of(DURT)
    eff = np.zeros((n, 2), dtype=np.float32)    # bus Effetti (riverbero della sala)
    amb = np.zeros((n, 2), dtype=np.float32)    # bus Ambiente (i fondi)
    mus = np.zeros((n, 2), dtype=np.float32)    # bus Musica (lo stinger)
    ui = np.zeros((n, 2), dtype=np.float32)     # bus Interfaccia (il morso: niente riverbero)

    def mono(rel):
        return leggi(rel, 1)

    def metti(dest, x, t, g_db=0.0, p=0.0):
        mix_into(dest, pan(x * db(g_db), p) if x.ndim == 1 else x * db(g_db), n_of(t))

    # i fondi della sala con la tempesta: pioggia sulla cupola, vento, nave
    for rel, g, off in [('ambiente/pioggia_cupola_loop.ogg', 0.0, 5.0), ('ambiente/vento_loop.ogg', -2.0, 9.0),
                        ('ambiente/nave_loop.ogg', 0.0, 2.0)]:
        mix_into(amb, fade(tile(leggi(rel), DURT, off), 1.5, 0.0) * db(g), 0)
    mix_into(amb, leggi('ambiente/tuono_lontano_01.ogg') * db(-4), n_of(9.0))

    # si cammina sulla scia bagnata verso la fossa (da 16 a 7 m)
    t = 0.8
    for k in range(10):
        metti(eff, mono('giocatore/passo_bagnato_%02d.ogg' % (k % 6 + 1)), t, -2 + rng.uniform(-1, 1),
              -0.06 if k % 2 else 0.06)
        t += 0.5 + rng.uniform(-0.03, 0.03)
    T_SBUCA = 6.4
    T_SCIVOLA = T_SBUCA + 1.8 + 6.0          # durata_sbuca + attesa (lei_sbuca.gd)
    # la fossa: ribolle mentre l'acqua risale; si avvicina, poi tace quando lei va sotto
    vol, _ = curva_loop([(0.6, 1.0, 1.0), (T_SCIVOLA, 0.0, 1.0)], DURT)
    k = np.arange(n) / SR
    dist = np.interp(k, [0.6, 5.8], [16.0, 7.0])
    g = 20 * np.log10(np.minimum(1.0, 5.0 / dist))
    fossa = tile(mono('lei/fossa_ribolle_loop.ogg'), DURT, 1.3)
    # in audio.gd la fossa sfuma più piano (rapidita_volume 1,5): qui la coda dopo T_SCIVOLA
    coda = np.clip(1.0 - (k - T_SCIVOLA) / 2.5, 0.0, 1.0)
    vol = np.where(k < T_SCIVOLA, vol, coda * vol[n_of(T_SCIVOLA) - 1])
    mix_into(eff, pan(fossa * vol * 10 ** (g / 20), 0.15), 0)
    # lei sbuca dal bordo (a 6,5 m, un po' a destra), guarda, poi scivola sotto
    metti(eff, mono('lei/lei_sbuca.ogg'), T_SBUCA, distanza_db(6.5, 6.0), 0.2)
    metti(eff, mono('lei/lei_scivola_sotto.ogg'), T_SCIVOLA, distanza_db(6.5, 6.0), 0.2)

    # l'altro finale: le vai incontro e ti prende
    T_MORSO = 22.4
    for k2 in range(3):
        metti(eff, mono('giocatore/passo_bagnato_%02d.ogg' % (k2 + 2)), T_MORSO - 1.1 + k2 * 0.36, -2, 0.0)
    metti(ui, leggi('lei/morso.ogg'), T_MORSO)
    metti(mus, leggi('musica/stinger_morte.ogg'), T_MORSO + 1.0)
    # durante la morte il mondo si abbassa (Ambiente -12 dB, Effetti -14 dB, in 0,25 s circa)
    giu = np.clip((k - T_MORSO) / 0.4, 0.0, 1.0)[:, None]
    amb *= 10 ** (-12 * giu / 20)
    eff *= 10 ** (-14 * giu / 20)

    eff = reverb(eff, ir_sala(), wet=0.26, dry=1.0, tail=False)
    out = hp(amb + eff + mus + ui, 20, 2)
    out = fade(out, 0.3, 2.5)
    g = db(-16.0 - lufs(out))
    out = limiter(out * g, -1.0)
    path = os.path.join(AUDIO, 'anteprima', 'anteprima_lei.ogg')
    write_ogg(path, out, 5)
    print(f'anteprima: {path}  {len(out) / SR:.1f}s  LUFS {lufs(out):.1f}  picco {np.abs(out).max():.2f}')


def anteprima_proposta_lei(estrema=False):
    """Proposta per l'utente (non nel gioco): lei più gutturale. I tre suoni nuovi in fila, nella
    scena come nel gioco: lei che sbuca (a 6,5 m, con la fossa che ribolle), guarda e scivola
    sotto; poi, dopo un attimo di pioggia, il morso con lo stinger alla chiusura della fauce."""
    import genera_lei
    voce = genera_lei.proposte(estrema)
    sbuca, scivola, morso = voce['lei_sbuca'], voce['lei_scivola_sotto'], voce['morso']
    T_SBUCA = 1.0
    T_SCIVOLA = T_SBUCA + 1.8 + 6.0          # durata_sbuca + attesa (lei_sbuca.gd)
    T_MORSO = T_SCIVOLA + len(scivola) / SR + 1.6
    DURT = T_MORSO + 4.2
    n = n_of(DURT)
    eff = np.zeros((n, 2), dtype=np.float32)
    amb = np.zeros((n, 2), dtype=np.float32)
    mus = np.zeros((n, 2), dtype=np.float32)
    ui = np.zeros((n, 2), dtype=np.float32)
    for rel, g, off in [('ambiente/pioggia_cupola_loop.ogg', 0.0, 5.0), ('ambiente/vento_loop.ogg', -2.0, 9.0),
                        ('ambiente/nave_loop.ogg', 0.0, 2.0)]:
        mix_into(amb, fade(tile(leggi(rel), DURT, off), 1.0, 0.0) * db(g), 0)
    # la fossa ribolle finché lei non va sotto (come AudioLei in audio.gd)
    k = np.arange(n) / SR
    fossa = tile(leggi('lei/fossa_ribolle_loop.ogg', 1), DURT, 0.7)
    vol = np.clip(k / 1.0, 0, 1) * np.clip(1.0 - (k - T_SCIVOLA) / 2.5, 0, 1)
    mix_into(eff, pan(fossa * vol * db(distanza_db(6.5, 5.0)), 0.15), 0)
    mix_into(eff, pan(sbuca * db(distanza_db(6.5, 6.0)), 0.2), n_of(T_SBUCA))
    mix_into(eff, pan(scivola * db(distanza_db(6.5, 6.0)), 0.2), n_of(T_SCIVOLA))
    for k2 in range(3):
        mix_into(eff, pan(leggi('giocatore/passo_bagnato_%02d.ogg' % (k2 + 2), 1) * db(-2), 0.0),
                 n_of(T_MORSO - 1.1 + k2 * 0.36))
    mix_into(ui, morso, n_of(T_MORSO))
    mix_into(mus, leggi('musica/stinger_morte.ogg'), n_of(T_MORSO + 1.0))
    giu = np.clip((k - T_MORSO) / 0.4, 0.0, 1.0)[:, None]
    amb *= 10 ** (-12 * giu / 20)
    eff *= 10 ** (-14 * giu / 20)
    eff = reverb(eff, ir_sala(), wet=0.26, dry=1.0, tail=False)
    out = hp(amb + eff + mus + ui, 20, 2)
    out = fade(out, 0.3, 2.5)
    g = db(-16.0 - lufs(out))
    out = limiter(out * g, -1.0)
    nome = 'proposta_lei_estrema.ogg' if estrema else 'proposta_lei_gutturale.ogg'
    path = os.path.join(AUDIO, 'anteprima', nome)
    write_ogg(path, out, 5)
    print(f'anteprima: {path}  {len(out) / SR:.1f}s  LUFS {lufs(out):.1f}  picco {np.abs(out).max():.2f}  '
          f'(sbuca {T_SBUCA:.1f}s, scivola {T_SCIVOLA:.1f}s, morso {T_MORSO:.1f}s)')


# --- confronto: la pioggia sulla cupola con e senza le bollicine (16 ottobre) ------------------

def anteprima_confronto_pioggia():
    """La sala con solo i fondi del gioco (pioggia sulla cupola, vento, nave, ai volumi di
    FONDI in audio.gd): 15 s con la pioggia di prima, che aveva le bollicine dei rivoli, un attimo
    di silenzio, poi 15 s con quella di adesso. Stesso guadagno per le due metà."""
    from genera_ambiente import pioggia_cupola
    from lib_audio import f32, normalize_lufs

    def pioggia(rivoli):
        # come la genera genera_ambiente.main(): primo suono col seme 2026, poi salva()
        x = f32(pioggia_cupola(np.random.default_rng(2026), rivoli=rivoli))
        x = normalize_lufs(x, -24.0, -1.0)
        return limiter(x, -1.0) if float(np.abs(x).max()) > db(-1.0) + 1e-4 else x

    PEZZO, PAUSA, DA = 15.0, 0.8, 4.0
    vento = tile(leggi('ambiente/vento_loop.ogg'), PEZZO, DA) * db(-2.0)
    nave = tile(leggi('ambiente/nave_loop.ogg'), PEZZO, DA)
    meta = []
    for rivoli in (True, False):
        x = tile(pioggia(rivoli), PEZZO, DA) + vento + nave
        meta.append(fade(x, 0.6, 0.4))
    out = np.concatenate([meta[0], np.zeros((n_of(PAUSA), 2), dtype=np.float32), meta[1]])
    out = limiter(out * db(-16.0 - lufs(out)), -1.0)
    path = os.path.join(AUDIO, 'anteprima', 'confronto_pioggia_bollicine.ogg')
    write_ogg(path, out, 5)
    print(f'anteprima: {path}  {len(out) / SR:.1f}s  LUFS prima {lufs(out[:n_of(PEZZO)]):.1f}  '
          f'dopo {lufs(out[-n_of(PEZZO):]):.1f}')


# --- confronto: i passi bagnati con e senza le goccioline (16 ottobre) --------------------------

def anteprima_confronto_passi():
    """Si cammina sul bagnato nella sala, con i fondi del gioco (pioggia sulla cupola senza
    bollicine, vento, nave): 10 s con i passi bagnati di oggi (lo sciac della suola e 4-9 goccioline
    acute che schizzano), un attimo di silenzio, poi 10 s con gli stessi passi senza goccioline.
    Stessi passi (stessi semi di genera_giocatore), stessi tempi, stessi fondi, stesso guadagno."""
    import genera_giocatore as gg
    from lib_audio import f32, normalize_lufs

    def passi(goccioline):
        rng = np.random.default_rng(1990)           # come genera_giocatore.main()
        for i in range(6):
            gg.passo_piastrelle(rng, i)
        return [normalize_lufs(f32(gg.passo_bagnato(rng, i, goccioline=goccioline)), -20.0, -1.0, short=True)
                for i in range(6)]

    PEZZO, PAUSA, DA = 10.0, 0.8, 6.0
    n = n_of(PEZZO)
    fondi = np.zeros((n, 2), dtype=np.float32)
    for rel, g in [('ambiente/pioggia_cupola_loop.ogg', 0.0), ('ambiente/vento_loop.ogg', -2.0),
                   ('ambiente/nave_loop.ogg', 0.0)]:
        fondi += tile(leggi(rel), PEZZO, DA) * db(g)
    meta = []
    for goccioline in (True, False):
        varianti = passi(goccioline)
        rng = np.random.default_rng(16)             # stessi tempi, toni e volumi nelle due metà
        eff = np.zeros((n, 2), dtype=np.float32)
        t, k = 0.4, 0
        while t < PEZZO - 0.4:
            x = varianti[k % 6]
            # come nel gioco: -2 dB di taratura, l'intensità del passo e ±0,8 semitoni di tono
            x = varispeed(x, 2 ** (rng.uniform(-0.8, 0.8) / 12))
            mix_into(eff, pan(x * db(-5.0 + rng.uniform(-1, 1)), -0.08 if k % 2 else 0.08), n_of(t))
            t += 0.5 + rng.uniform(-0.03, 0.03)
            k += 1
        eff = reverb(eff, ir_sala(), wet=0.26, dry=1.0, tail=False)
        meta.append(fade(fondi + eff, 0.6, 0.4))
    out = np.concatenate([meta[0], np.zeros((n_of(PAUSA), 2), dtype=np.float32), meta[1]])
    out = limiter(out * db(-16.0 - lufs(out)), -1.0)
    path = os.path.join(AUDIO, 'anteprima', 'confronto_passi_goccioline.ogg')
    write_ogg(path, out, 5)
    print(f'anteprima: {path}  {len(out) / SR:.1f}s  LUFS prima {lufs(out[:n]):.1f}  dopo {lufs(out[-n:]):.1f}')


# --- i cancelli stagni della camera delle onde (16 ottobre) ---------------------------------------

def come_3d(x, d, unit, vol_db=0.0, max_d=0.0):
    """Un suono mono come lo fa sentire AudioStreamPlayer3D dell'addon a d metri: distanza inversa
    più il volume della taratura, con il tetto max_db = 0; la dissolvenza lineare fino a
    max_distance; il filtro d'attenuazione del pool (mensola alta a 6 kHz, fino a -20 dB)."""
    att = min(0.0, 20 * np.log10(unit / max(d, 0.01)) + vol_db)
    mult = 10 ** (att / 20) * (max(0.0, 1.0 - d / max_d) if max_d > 0 else 1.0)
    mensola = (1.0 - min(1.0, mult)) * -20.0
    y = biquad(x, 'highshelf', 6000, 0.7, mensola) if mensola < -0.05 else x
    return y * mult


def anteprima_cancello():
    """Si cammina nella camera delle onde, dopo la scala del pozzo, verso i due cancelli stagni:
    il primo, a 3,5 m un po' a sinistra, si apre da solo; il secondo, 3,5 m più in là, parte 2 s
    dopo (l'altra variante). Sotto, il fondo della stanza tecnica come in anteprima_tecnici: la
    nave bassa (la camera è sotto la sala, lontano dalla cupola) e qualche goccia dal pozzo.
    Livelli e distanze come nel gioco: taratura di cancello_stagno_apre in audio.gd (+2 dB,
    unit_size 5 m, max_distance 60 m), bus Effetti col riverbero della sala."""
    rng = np.random.default_rng(1610)
    T1, T2 = 2.5, 4.5
    DURT = 10.5
    n = n_of(DURT)
    eff = np.zeros((n, 2), dtype=np.float32)    # bus Effetti (riverbero della sala)
    amb = np.zeros((n, 2), dtype=np.float32)    # bus Ambiente (i fondi)

    def metti(x, t, g_db=0.0, p=0.0):
        mix_into(eff, pan(x * db(g_db), p), n_of(t))

    nave = tile(leggi('ambiente/nave_loop.ogg'), DURT, 7.0)
    mix_into(amb, fade(nave, 1.0, 0.0) * db(-10), 0)
    for tc, g, p in [(0.9, -16, 0.4), (5.9, -18, -0.5), (9.1, -16, 0.3)]:
        metti(leggi('ambiente/goccia_acqua_0%d.ogg' % rng.integers(1, 7), 1), tc, g, p)
    # i passi sul bagnato fino a 3,5 m dal primo cancello, poi ci si ferma a guardare
    t = 0.4
    for k in range(5):
        metti(leggi('giocatore/passo_bagnato_%02d.ogg' % (k % 6 + 1), 1), t, -5 + rng.uniform(-1, 1),
              -0.08 if k % 2 else 0.08)
        t += 0.48 + rng.uniform(-0.02, 0.02)
    for tc, var, d, p in [(T1, 1, 3.5, -0.12), (T2, 2, 7.0, 0.05)]:
        x = leggi('tecnici/cancello_stagno_apre_%02d.ogg' % var, 1)
        metti(come_3d(x, d, 5.0, 2.0, 60.0), tc, 0.0, p)
    eff = reverb(eff, ir_sala(), wet=0.26, dry=1.0, tail=False)
    out = hp(amb + eff, 20, 2)
    out = fade(out, 0.3, 1.5)
    g = db(-16.0 - lufs(out))
    out = limiter(out * g, -1.0)
    path = os.path.join(AUDIO, 'anteprima', 'cancello_stagno.ogg')
    write_ogg(path, out, 5)
    print(f'anteprima: {path}  {len(out) / SR:.1f}s  LUFS {lufs(out):.1f}  picco {np.abs(out).max():.2f}')


def main(quali=('sala', 'tecnici', 'lei', 'proposte', 'pioggia', 'passi', 'cancello')):
    if 'sala' in quali:
        anteprima_sala()
    if 'tecnici' in quali:
        anteprima_tecnici()
    if 'lei' in quali:
        anteprima_lei()
    if 'proposte' in quali:
        anteprima_proposta_lei(False)
        anteprima_proposta_lei(True)
    if 'pioggia' in quali:
        anteprima_confronto_pioggia()
    if 'passi' in quali:
        anteprima_confronto_passi()
    if 'cancello' in quali:
        anteprima_cancello()


if __name__ == '__main__':
    main(sys.argv[1:] or ('sala', 'tecnici', 'lei', 'proposte', 'pioggia', 'passi', 'cancello'))
