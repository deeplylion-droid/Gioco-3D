"""Il canto di lei prima del tunnel (build 0.4.0, «L'acqua è sua», scelta A del 15 novembre): da quando si
riaccendono le pompe lei canta la sigla del parco, lenta e storpiata, con la sua gola, ogni volta che è nell'acqua
vicina. Si sente in due distanze: lontana, dentro i tubi (filtrata, metallica, quasi senza acuti), e vicina, quando la
luce rosa si avvicina; quando il canto si spegne, lei sta per uscire. Il canto non si tronca mai (nota dell'utente
sull'avvicinamento, 15 novembre: «Si ferma di colpo»): l'ultima nota cala di tono e muore in circa un secondo, poi
almeno mezzo secondo di silenzio vero (nel gioco: la fase «spegne» di AcquaDiLei, 1 s, poi «silenzio», 0,5 s).
Nel tunnel l'utente ha scelto la B (15 novembre): anche lì la sigla storpiata, al posto del canto del 25 ottobre
(genera_canto_sirena.py, variante A, i cui file sono in scartati/canto_tunnel_25_ottobre/), ai livelli di quel canto e
con le sue correzioni (poco fiato, melodia in evidenza, nessun grattamento).

La voce è la stessa gola sintetica del canto del tunnel (voce() di genera_canto_sirena.py, con gola() e il tratto di
genera_lei.py): niente voce umana. La melodia è quella della sigla di Jilly (FRASE_A_1_6 e FINE_A di genera_musica.py),
abbassata nel registro della sua gola, rallentata a metà o poco meno (52-63 battiti al minuto invece di 120) e storpiata:
- nel minore, come la sigla rovinata della statua (minore() di genera_musica.py);
- le note calanti o crescenti di 20-60 cent, ognuna a modo suo, e qualche nota tenuta più a lungo o saltata;
- il nastro che ondeggia e un leggero sdoppiamento, come nel tunnel;
- ogni frase è un pezzo diverso della sigla (da 5 a 9 note di seguito), con tempo, note e vocali a caso: niente loop.

Riscontri dell'utente da rispettare: volumi bassi (gioca al 10%), suoni puliti, niente bollicine sotto, niente
grattamenti (nessun verso o ringhio mentre canta), niente musichette in loop.

Uso: /home/user/tools/blender-venv/bin/python assets_src/audio/genera_canto_sigla.py [cartella]
Scrive i tre esempi da far sentire all'utente (in mp3 per il telefono, e in ogg), in docs/proposte/canto_prima/:
- canto_prima_lontano_nei_tubi: due frasi lontane, dentro i tubi;
- canto_prima_vicino: due frasi vicine;
- canto_prima_avvicinamento: lontana, a metà, vicina, poi il canto si ferma a metà frase e resta il silenzio (lei sta
  per uscire). Bocciato dall'utente («Si ferma di colpo»), rifatto in:
- canto_prima_avvicinamento_spegne: lontana, a metà, vicina; poi l'ultima nota cala e muore in 1 s, e silenzio;
- canto_tunnel_sigla: la versione da tunnel, che si avvicina, col fiato del tunnel a x0,3 sotto.
Con "gioco" (dopo il sì dell'utente a lontano e vicino, 15 novembre): le frasi del gioco in godot/audio/lei/, a coppie della stessa lunghezza
(lei_canto_prima_lontano_NN e lei_canto_prima_vicino_NN, mono), registrate per catalogo.py e licenze.py; poi
catalogo.py e licenze.py. Nel gioco le sfuma addons/audio/audio.gd (CantoPrima).
Con "tunnel": copia il canto del 25 ottobre (godot/audio/lei/lei_tunnel_canto_NN) in scartati/canto_tunnel_25_ottobre/
e al suo posto scrive la sigla da tunnel, con gli stessi nomi (le suona la voce di lei, Statua).
"""
import os
import sys

import numpy as np

from comune import RADICE, ir_nave, ir_sala
from genera_canto_sirena import nastro, sdoppia, sottacqua, voce, write_mp3
from genera_lei import _norm
from genera_musica import FINE_A, FRASE_A_1_6, minore
from lib_audio import (SR, bp, comb, f32, fade, hp, limiter, lp, lufs, mix_into, n_of, normalize_lufs, reverb,
                       stereo, varispeed, write_ogg)

USCITA = os.path.join(RADICE, 'docs', 'proposte', 'canto_prima')
# i livelli, più bassi del canto del tunnel (-24 da vicino, -21,7 nel gioco): qui lei non insegue ancora
VICINO_LUFS = -27.0
LONTANO_LUFS = -34.0
# lo spegnimento: l'ultima nota cala di tanto (frazione di velocità: 0,89 = 2 semitoni sotto) e muore in tanto (s)
SPEGNI_TONO = 0.89
SPEGNI_S = 1.0
# il tunnel: il canto ai livelli del canto approvato il 25 ottobre (da vicino -24 LUFS, x1,3 nel gioco: -21,7)
TUNNEL_GIOCO_LUFS = -24.0 + 20.0 * np.log10(1.3)
# la melodia della sigla (E5 = 76 ...) portata nel registro della gola di lei: 19 semitoni sotto (Mi5 -> La3)
TRASPORTO = -19
MELODIA = FRASE_A_1_6 + FINE_A


def hz(m, cents=0.0):
    return 440.0 * 2 ** ((m - 69 + cents / 100.0) / 12.0)


def note_frase(rng):
    """Un pezzo della sigla, sempre diverso: da 5 a 9 note di seguito da un punto a caso, nel minore, rallentate (un
    battito 0,95-1,15 s, la sigla va a 0,5 s), ogni nota stonata a modo suo, qualcuna tenuta di più o saltata, l'ultima che cala come un
    sospiro. Restituisce [(inizio, durata, Hz, vocale)] e la durata della frase."""
    quante = int(rng.integers(5, 10))
    da = int(rng.integers(0, len(MELODIA) - quante))
    pezzo = MELODIA[da:da + quante]
    battito = float(rng.uniform(0.95, 1.15))
    note = []
    t = 0.0
    for k, (_b, m, d) in enumerate(pezzo):
        if k > 0 and k < len(pezzo) - 1 and rng.random() < 0.12:
            continue                                   # una nota saltata
        dur = d * battito * (rng.uniform(1.3, 1.9) if rng.random() < 0.18 else rng.uniform(0.9, 1.1))
        dur = max(dur, 0.38)
        cents = float(rng.normal(-15.0, 22.0))         # storpiata: più spesso calante
        if k == len(pezzo) - 1:
            cents -= float(rng.uniform(40.0, 90.0))    # l'ultima scende
            dur *= 1.3
        note.append((t, dur, hz(minore(m) + TRASPORTO, cents), str(rng.choice(['a', 'a', 'o', 'u', 'o']))))
        t += dur
    return note, t + 0.4


def frase(rng):
    """Una frase asciutta (mono): la gola di lei che canta il pezzo di sigla, col nastro che ondeggia, lo sdoppiamento
    e il filtro sott'acqua del tunnel (un po' più chiuso)."""
    note, dur = note_frase(rng)
    x = _norm(voce(rng, note, dur, scivola=0.22))
    x = nastro(rng, x, quanto=0.009, velocita=0.35)
    x = sdoppia(x, cent=18.0, quanto=0.4)
    return f32(fade(hp(sottacqua(x, chiuso=1400.0), 80, 2), 0.05, 0.4))


def nei_tubi(x, rng):
    """Lontana, dentro i tubi: quasi senza acuti, la risonanza metallica di un tubo (pettini a 3,1-7,3 ms), una coda
    lunga e scura come i corridoi della nave."""
    y = lp(lp(x, 650.0, 2), 900.0, 2)
    tubo = np.zeros_like(y)
    for ritardo, g in [(float(rng.uniform(0.0031, 0.0036)), 0.55), (float(rng.uniform(0.0052, 0.0060)), 0.4),
                       (float(rng.uniform(0.0068, 0.0073)), 0.3)]:
        tubo += comb(y, ritardo, 0.72, damp=0.6) * g
    y = 0.45 * y + 0.55 * bp(tubo, 180.0, 1500.0, 2)
    y = reverb(y, ir_nave(), wet=0.55, dry=0.6, tail=True)
    return f32(y)


def vicina(x):
    """Vicina: nell'acqua accanto, col riverbero della sala grande, poco."""
    return f32(reverb(x, ir_sala(), wet=0.22, dry=1.0, tail=True))


def a_distanza(rng, x, vicinanza):
    """La frase alla distanza data (0 lontana nei tubi, 1 vicina): le due versioni sfumate, al loro livello."""
    lon = nei_tubi(x, rng)
    vic = vicina(x)
    n = max(len(lon), len(vic))
    lon = np.pad(lon, ((0, n - len(lon)), (0, 0)) if lon.ndim == 2 else (0, n - len(lon)))
    vic = np.pad(vic, ((0, n - len(vic)), (0, 0)) if vic.ndim == 2 else (0, n - len(vic)))
    lon = stereo(lon) if lon.ndim == 1 else lon
    vic = stereo(vic) if vic.ndim == 1 else vic
    lon = lon * 10 ** ((LONTANO_LUFS - lufs(lon)) / 20)
    vic = vic * 10 ** ((VICINO_LUFS - lufs(vic)) / 20)
    return f32(lon * (1.0 - vicinanza) + vic * vicinanza)


def spegni(x, da, durata=SPEGNI_S, tono=SPEGNI_TONO):
    """Il canto che si spegne da solo da [param da] secondi: la voce cala di tono (fino a [param tono] della velocità) e
    muore in [param durata] secondi (fino a -60 dB, curva quadratica); dopo, niente. Come fa il gioco (CantoPrima, fase
    «spegne»): pitch_scale e volume insieme."""
    a = n_of(da)
    if a >= len(x):
        return x
    coda = x[a:a + n_of(durata * 1.2)]
    vel = np.linspace(1.0, tono, n_of(durata))
    y = varispeed(coda, np.concatenate([vel, np.full(max(0, len(coda) - len(vel)), tono)]))[:n_of(durata)]
    e = (1.0 - np.linspace(0.0, 1.0, len(y))) ** 2
    y = y * (e if y.ndim == 1 else e[:, None])
    return f32(np.concatenate([x[:a], y]))


def esempio(rng, vicinanze, dur, ferma=False, si_spegne=False):
    """Un esempio da dur secondi: una frase per ogni vicinanza, una dopo l'altra con 0,8-1,4 s di pausa (le code del
    riverbero si sovrappongono). Con ferma, l'ultima frase si interrompe a poco più di metà (dissolvenza di 60 ms:
    niente clic) e resta il silenzio fino alla fine: lei sta per uscire."""
    n = n_of(dur)
    out = np.zeros((n, 2))
    t = 0.5
    for k, vic in enumerate(vicinanze):
        if t > dur - (5.0 if ferma or si_spegne else 2.5):
            break
        x = frase(rng)
        secca = len(x)
        x = a_distanza(rng, x, vic)
        if ferma and k == len(vicinanze) - 1:
            # il canto si ferma: via anche la coda del riverbero, di colpo (come se lei chiudesse la bocca)
            a = n_of(t)
            lung = min(int(secca * float(rng.uniform(0.55, 0.65))), n - a - n_of(3.5))
            x = fade(x[:max(lung, n_of(1.0))].copy(), 0.0, 0.06)
        if si_spegne and k == len(vicinanze) - 1:
            # lei sta per uscire: a poco più di metà frase l'ultima nota cala e muore in 1 s (con la coda del riverbero
            # dentro: nel gioco il volume scende insieme), poi il silenzio vero
            a = n_of(t)
            da = min(secca * float(rng.uniform(0.5, 0.6)) / SR, (n - a) / SR - SPEGNI_S - 3.0)
            x = spegni(x, max(da, 1.0))
        a = n_of(t)
        mix_into(out, x[:max(0, n - a)], a)
        t += secca / SR + float(rng.uniform(0.8, 1.4))
    return f32(limiter(fade(out, 0.3, 0.0 if ferma or si_spegne else 1.5), -6.0))


FRASI_GIOCO = 10


def gioco():
    """Nel gioco, dopo il sì dell'utente: FRASI_GIOCO frasi, ognuna in due file mono della stessa lunghezza, lontana nei
    tubi (lei_canto_prima_lontano_NN, a LONTANO_LUFS) e vicina (lei_canto_prima_vicino_NN, a VICINO_LUFS), in
    godot/audio/lei/. Il gioco le fa partire insieme e le sfuma con la vicinanza di lei (addons/audio, CantoPrima)."""
    from comune import salva
    rng = np.random.default_rng(4000)
    for k in range(FRASI_GIOCO):
        x = frase(rng)
        lon = nei_tubi(x, rng)
        vic = vicina(x)
        lon = lon.mean(axis=1) if lon.ndim == 2 else lon
        vic = vic.mean(axis=1) if vic.ndim == 2 else vic
        n = max(len(lon), len(vic))
        coppia = []
        for y, livello in [(lon, LONTANO_LUFS), (vic, VICINO_LUFS)]:
            y = fade(np.pad(y, (0, n - len(y))), 0.0, 0.5)
            coppia.append(limiter(y * 10 ** ((livello - lufs(y)) / 20), -6.0))
        for nome, y in [('lontano', coppia[0]), ('vicino', coppia[1])]:
            picco = 20.0 * np.log10(float(np.abs(y).max()) + 1e-12) + 0.01
            salva('lei', 'lei_canto_prima_%s_%02d' % (nome, k + 1), y, loudness=None, picco=picco, qualita=5,
                  nota='prima del tunnel, la sigla lenta e storpiata con la gola di lei, %s (0.4.0, scelta A del 15 '
                       'novembre)' % ('lontana nei tubi' if nome == 'lontano' else 'vicina'))


def esempio_tunnel(rng, fiato, dur=20.0):
    """La versione da tunnel, com'è nel gioco: una frase ogni 3-7 s, sempre nuova, che si avvicina (lontana: 9 dB sotto e
    più chiusa, come nel canto del 25 ottobre), col riverbero del tunnel, al livello del canto del tunnel; sotto solo il
    fiato in ciclo a x0,3 (scelta dell'utente del 25 ottobre: niente versi mentre canta)."""
    import genera_canto_sirena as sirena
    ir = ir_sala()
    n = n_of(dur)
    canto = np.zeros((n, 2))
    t = 1.0
    k = 0
    vicinanze = [0.0, 0.5, 1.0, 1.0]
    while t < dur - 3.0:
        x = sirena.bagnata(frase(rng), ir, TUNNEL_GIOCO_LUFS)
        vic = vicinanze[min(k, 3)]
        x = lp(x, 900 + 1100 * vic, 2) * 10 ** ((-9.0 * (1 - vic)) / 20)
        mix_into(canto, x[:max(0, n - n_of(t))], n_of(t))
        t += len(x) / SR - 1.5 + float(rng.uniform(1.0, 3.0))
        k += 1
    sotto = stereo(np.tile(fiato, int(np.ceil(n / len(fiato))))[:n] * sirena.FIATO_X)
    return f32(limiter(fade(canto + sotto, 0.5, 1.5), -3.0))


def gioco_tunnel():
    """Nel tunnel (scelta B dell'utente, 15 novembre): il canto del 25 ottobre (lei_tunnel_canto_NN) copiato in
    scartati/canto_tunnel_25_ottobre/, e al suo posto FRASI_GIOCO frasi della sigla, mono, con un filo del riverbero del
    tunnel (il resto lo fa il gioco), a TUNNEL_GIOCO_LUFS, con gli stessi nomi: le suona la voce di lei (Statua)."""
    import glob
    import shutil
    from comune import AUDIO, salva
    scarti = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'scartati', 'canto_tunnel_25_ottobre')
    os.makedirs(scarti, exist_ok=True)
    for f in sorted(glob.glob(os.path.join(AUDIO, 'lei', 'lei_tunnel_canto_*.ogg'))):
        dest = os.path.join(scarti, os.path.basename(f))
        if not os.path.exists(dest):
            shutil.copy2(f, dest)
    ir = ir_sala()
    rng = np.random.default_rng(4500)
    for k in range(FRASI_GIOCO):
        x = frase(rng)
        y = reverb(x, ir, wet=0.14, dry=1.0, tail=True)
        if y.ndim == 2:
            y = y.mean(axis=1)
        y = fade(y[:len(x) + n_of(1.5)], 0.0, 1.0)
        y = limiter(normalize_lufs(y, TUNNEL_GIOCO_LUFS, -3.0), -3.0)
        picco = 20.0 * np.log10(float(np.abs(y).max()) + 1e-12) + 0.01
        salva('lei', 'lei_tunnel_canto_%02d' % (k + 1), y, loudness=None, picco=picco, qualita=5,
              nota='tunnel, la sigla lenta e storpiata con la gola di lei (scelta B del 15 novembre, al posto del canto '
                   'del 25 ottobre): una frase ogni 8-15 s mentre insegue')


def main():
    if len(sys.argv) > 1 and sys.argv[1] == 'gioco':
        gioco()
        return
    if len(sys.argv) > 1 and sys.argv[1] == 'tunnel':
        gioco_tunnel()
        return
    if len(sys.argv) > 1 and sys.argv[1] == 'spegne':
        # i due esempi dopo la risposta dell'utente del 15 novembre: l'avvicinamento che si spegne e la versione da tunnel
        import genera_lei_tunnel as lt
        cartella = sys.argv[2] if len(sys.argv) > 2 else USCITA
        os.makedirs(cartella, exist_ok=True)
        fiato = lt.genera()['lei_tunnel_fiato']
        esempi = [
            ('canto_prima_avvicinamento_spegne',
             esempio(np.random.default_rng(4404), [0.0, 0.5, 1.0], 20.0, si_spegne=True)),
            ('canto_tunnel_sigla', esempio_tunnel(np.random.default_rng(4505), fiato, 20.0)),
        ]
        for nome, x in esempi:
            write_mp3(os.path.join(cartella, nome + '.mp3'), x)
            write_ogg(os.path.join(cartella, nome + '.ogg'), x, 5)
            print(nome, '%.1f s' % (len(x) / SR), 'LUFS %.1f' % lufs(x),
                  'picco %.1f dB' % (20 * np.log10(np.abs(x).max() + 1e-12)))
        return
    cartella = sys.argv[1] if len(sys.argv) > 1 else USCITA
    os.makedirs(cartella, exist_ok=True)
    esempi = [
        ('canto_prima_lontano_nei_tubi', esempio(np.random.default_rng(4101), [0.0] * 6, 18.0)),
        ('canto_prima_vicino', esempio(np.random.default_rng(4202), [1.0] * 6, 18.0)),
        ('canto_prima_avvicinamento', esempio(np.random.default_rng(4303), [0.0, 0.5, 1.0], 20.0, ferma=True)),
    ]
    for nome, x in esempi:
        write_mp3(os.path.join(cartella, nome + '.mp3'), x)
        write_ogg(os.path.join(cartella, nome + '.ogg'), x, 5)
        print(nome, '%.1f s' % (len(x) / SR), 'LUFS %.1f' % lufs(x), 'picco %.1f dB' % (20 * np.log10(np.abs(x).max() + 1e-12)))


if __name__ == '__main__':
    main()
