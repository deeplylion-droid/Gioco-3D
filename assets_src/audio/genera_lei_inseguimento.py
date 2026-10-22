"""La voce di lei nell'inseguimento (proposta B dell'utente, 22 ottobre: versi nuovi fatti apposta, nello
stesso stile dei suoi suoni di adesso). Lei non parla: niente parole né voce umana. La stessa gola
di genera_lei.py (la versione gutturale scelta il 16 ottobre: gola(), tratto(), ringhio(), respiro(),
rantolo(), gola_sottacqua()), solo sintesi.

Cinque suoni, quelli che si ripetono in tre varianti (semi diversi):
- lei_insegue_sale_1..3 (3,4 s): sale dall'acqua gorgogliando di gola, rompe la superficie e mentre
  incombe un ringhio basso che cresce col fiato umido (sale_dall_acqua 1,6 s + incombe);
- lei_insegue_presa_1..2 (1,6 s): un risucchio d'aria e poi il grido-ringhio che si apre quando
  scatta e afferra (presa, 1,2 s: l'afferrare a ~0,5 s), con sopra, piano, la voce stridula del suo
  urlo del jumpscare (proposte_jumpscare/genera_urlo.py); prima della morte "medusa";
- lei_insegue_respinta_1..3 (1,4 s): il lamento quando il getto la colpisce in faccia, la gola che
  sale e si spezza, poi il gorgoglio mentre torna sotto (respinta, 1,2 s);
- lei_insegue_sb1 (5,4 s, anche in ciclo): ti fissa dal pozzo: fiato lento e umido e un rantolo
  trattenuto (affacciata_sb1);
- lei_insegue_grata_1..3 (0,6 s): un verso di rabbia corto per ogni colpo contro la grata (colpo_grata,
  ciclo di 0,5 s: il palmo tocca a 0,25 s).

Uso: /home/user/tools/blender-venv/bin/python assets_src/audio/genera_lei_inseguimento.py [cartella | gioco]
Senza argomenti scrive le proposte in docs/proposte/voce_lei/; con "gioco" scrive i file del gioco in
godot/audio/lei/ (lei_insegue_*_01..) e li registra; poi catalogo.py e licenze.py.
"""
import os
import sys

import numpy as np

from comune import RADICE, ir_sala
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), 'proposte_jumpscare'))
from genera_urlo import formanti, voce  # noqa: E402  (la sua voce stridula del jumpscare)
from genera_lei import _norm, gola_sottacqua, respiro, rantolo, ringhio, rombo_sotto, sporca, tratto, gola
from lib_audio import (SR, bp, env_points, f32, fade, hp, lp, mix_into, n_of, normalize_lufs, reverb,
                       smooth_noise, white, write_ogg, limiter, pitch)

USCITA = os.path.join(RADICE, 'docs', 'proposte', 'voce_lei')


def grido(rng, dur, f0, bocca=1.3, sporco=4.0, rullo=26.0):
    """Il grido-ringhio: la stessa gola del ringhio con la bocca aperta e l'altezza che segue una
    curva [(t, Hz)]: sale quando si arrabbia, cade quando si spezza."""
    n = n_of(dur)
    f0c = env_points(f0, n) * (1 + 0.05 * smooth_noise(n, 5, rng))
    g = gola(rng, dur, f0c, jitter=0.14, shimmer=0.35, sotto=0.4, aspira=0.7)
    rullo_c = rullo * (1 + 0.2 * smooth_noise(n, 4, rng))
    g *= 0.55 + 0.45 * np.abs(np.sin(np.pi * np.cumsum(rullo_c) / SR)) ** 0.7
    v = tratto(rng, g, [(320 * bocca, 2.0, 1.0), (820 * bocca, 3.0, 0.7), (1900 * bocca, 4.0, 0.35),
                        (3000, 6.0, 0.12)], moto=0.12, velocita=1.2)
    v = lp(sporca(v, sporco), 5000, 2)
    ph = np.cumsum(f0c * 0.5) / SR
    v += np.tanh(np.sin(2 * np.pi * ph) * 2.0) * 0.3
    return f32(v)


def sale(rng):
    dur = 3.4
    n = n_of(dur)
    out = np.zeros(n)
    # sott'acqua: la gola che gorgoglia mentre sale
    gs = gola_sottacqua(rng, 1.3, cupo=rng.uniform(420, 560))
    mix_into(out, _norm(gs) * env_points([(0, 0), (0.6, 0.8), (1.1, 1.0), (1.3, 0)], len(gs)) * 0.6, 0)
    # fuori: un fiato umido che si apre e il ringhio che cresce mentre si sporge
    cicli = [(1.15, 0.7, 'insp', 0.8), (1.9, 1.4, 'esp', 0.7)]
    mix_into(out, _norm(respiro(rng, dur, cicli)) * 0.55, 0)
    rg = ringhio(rng, 2.0, f0=(rng.uniform(52, 60), rng.uniform(64, 74)), sporco=3.2, rullo=rng.uniform(20, 27))
    mix_into(out, _norm(rg) * env_points([(0, 0), (0.6, 0.55), (1.5, 1.0), (2.0, 0)], len(rg)) * 0.75,
             n_of(1.35))
    mix_into(out, _norm(rombo_sotto(rng, dur)) * env_points([(0, 0.3), (1.2, 0.8), (dur, 0.2)], n) * 0.4, 0)
    return f32(fade(hp(out, 28, 2), 0.02, 0.25))


def presa(rng):
    dur = 1.6
    n = n_of(dur)
    out = np.zeros(n)
    # si tira indietro: un risucchio d'aria tra i denti
    mix_into(out, _norm(respiro(rng, 0.45, [(0.0, 0.42, 'insp', 1.0)])) * 0.7, 0)
    # scatta e afferra (~0,5 s): il grido-ringhio si apre, sale e si strozza in un ringhio
    a = rng.uniform(70, 80)
    gr = grido(rng, 1.15, [(0, a), (0.15, a * 1.6), (0.45, a * 1.8), (0.8, a * 1.2), (1.15, a * 0.8)],
               bocca=rng.uniform(1.3, 1.5), sporco=4.5)
    mix_into(out, _norm(gr) * env_points([(0, 0), (0.05, 1.0), (0.5, 0.85), (1.15, 0)], len(gr)), n_of(0.38))
    # sopra, piano, la stessa voce stridula e rotta del suo urlo (lei_urlo, il jumpscare): quando afferra
    k = n_of(0.8)
    f0 = env_points([(0, 300), (0.25, 520), (0.8, 380)], k)
    st = formanti(voce(rng, k, f0, 1.2), 'a') * 0.7 + formanti(voce(rng, k, f0 * 1.01, 1.2), 'i') * 0.4
    st = np.tanh(_norm(st) * 5.0) * env_points([(0, 0), (0.04, 1.0), (0.45, 0.6), (0.8, 0)], k)
    mix_into(out, hp(lp(st, 7000, 2), 300, 2) * 0.22, n_of(0.48))
    mix_into(out, _norm(rombo_sotto(rng, dur)) * env_points([(0, 0), (0.4, 1), (dur, 0)], n) * 0.35, 0)
    return f32(fade(hp(out, 30, 2), 0.005, 0.15))


def respinta(rng):
    dur = 1.4
    n = n_of(dur)
    out = np.zeros(n)
    # il getto in faccia: la gola salta su in un lamento che si spezza
    a = rng.uniform(85, 100)
    gr = grido(rng, 0.95, [(0, a * 1.4), (0.1, a * 2.1), (0.35, a * 1.9), (0.7, a * 1.1), (0.95, a * 0.7)],
               bocca=rng.uniform(1.1, 1.3), sporco=3.0, rullo=rng.uniform(14, 20))
    mix_into(out, _norm(gr) * env_points([(0, 0), (0.03, 1.0), (0.4, 0.7), (0.95, 0)], len(gr)), 0)
    # torna sotto: l'ultimo fiato gorgoglia sott'acqua
    gs = gola_sottacqua(rng, 0.7, cupo=420.0)
    mix_into(out, _norm(gs) * env_points([(0, 0), (0.15, 1), (0.7, 0)], len(gs)) * 0.55, n_of(0.7))
    return f32(fade(hp(out, 30, 2), 0.004, 0.12))


def sb1(rng):
    """Ti fissa dal pozzo: 5,4 s, si può ripetere (inizio e fine piano)."""
    dur = 5.4
    n = n_of(dur)
    out = np.zeros(n)
    cicli = [(0.2, 1.6, 'esp', 0.8), (2.0, 0.9, 'insp', 0.6), (3.0, 2.0, 'esp', 0.9)]
    mix_into(out, _norm(respiro(rng, dur, cicli, umido=1.2, rauco=0.5)) * 0.8, 0)
    ra = rantolo(rng, dur, ritmo=0.9)
    mix_into(out, _norm(ra) * env_points([(0, 0), (1.0, 0.5), (3.5, 0.9), (dur, 0)], n) * 0.45, 0)
    mix_into(out, _norm(rombo_sotto(rng, dur)) * 0.25, 0)
    return f32(fade(hp(out, 28, 2), 0.3, 0.4))


def grata(rng):
    dur = 0.6
    n = n_of(dur)
    out = np.zeros(n)
    a = rng.uniform(75, 90)
    gr = grido(rng, 0.5, [(0, a), (0.08, a * 1.5), (0.5, a * 1.1)], bocca=rng.uniform(1.3, 1.5),
               sporco=5.0, rullo=rng.uniform(26, 32))
    mix_into(out, _norm(gr) * env_points([(0, 0), (0.03, 1.0), (0.25, 0.8), (0.5, 0)], len(gr)), 0)
    return f32(fade(hp(out, 30, 2), 0.004, 0.08))


# nome: (funzione, varianti, loudness, corto)
SUONI = {
    'lei_insegue_sale': (sale, 3, -16, False),
    'lei_insegue_presa': (presa, 2, -12, True),
    'lei_insegue_respinta': (respinta, 3, -13, True),
    'lei_insegue_sb1': (sb1, 1, -20, False),
    'lei_insegue_grata': (grata, 3, -13, True),
}


def genera():
    """Tutti i suoni, normalizzati, con un filo della sala grande: {nome_variante: array}."""
    ir = ir_sala()
    tutti = {}
    for i, (nome, (f, var, loud, corto)) in enumerate(SUONI.items()):
        for v in range(var):
            rng = np.random.default_rng(2210 + 37 * i + v)
            x = f(rng)
            x = reverb(x, ir, wet=0.16, dry=1.0, tail=False)
            if x.ndim == 2:
                x = x.mean(axis=1)   # mono: nel gioco è un suono posizionato, sulla sua testa
            x = normalize_lufs(x, loud, -1.0, short=corto)
            x = limiter(x, -1.0)
            tutti[nome if var == 1 else '%s_%d' % (nome, v + 1)] = f32(x)
    return tutti


def gioco():
    """Nel gioco (dopo l'ok dell'utente): godot/audio/lei/lei_insegue_*_01.. (varianti per il catalogo),
    registrati per catalogo.py e licenze.py."""
    from comune import salva
    note = {'lei_insegue_sale': 'sale dall\'acqua e incombe: gola sott\'acqua, fiato umido, ringhio che cresce',
            'lei_insegue_presa': 'ti afferra: risucchio, grido-ringhio, sotto la voce rotta del suo urlo',
            'lei_insegue_respinta': 'il getto in faccia: lamento che si spezza, gorgoglio mentre torna sotto',
            'lei_insegue_sb1': 'ti fissa dal pozzo SB1: fiato lento e umido, rantolo trattenuto',
            'lei_insegue_grata': 'un verso di rabbia per ogni colpo contro la grata'}
    for nome, x in genera().items():
        base = nome.rsplit('_', 1)
        if base[0] in note:
            file = '%s_%02d' % (base[0], int(base[1]))
            chiave = base[0]
        else:
            file = chiave = nome
        _, _, loud, corto = SUONI[chiave]
        salva('lei', file, x, loudness=loud, corto=corto, qualita=5,
              nota='inseguimento, voce (22 ottobre): ' + note[chiave])


def main():
    if len(sys.argv) > 1 and sys.argv[1] == 'gioco':
        gioco()
        return
    cartella = sys.argv[1] if len(sys.argv) > 1 else USCITA
    os.makedirs(cartella, exist_ok=True)
    for nome, x in genera().items():
        write_ogg(os.path.join(cartella, nome + '.ogg'), x, 5)
        print(nome, '%.2f s' % (len(x) / SR))


if __name__ == '__main__':
    main()
