"""Le voci candidate dello speaker dello spot della crociera Jubilee (GDD, "Lo spot della crociera Jubilee"; testo
approvato in docs/proposte/spot/bozza.md). Tre voci in inglese, stile pubblicità americana anni '90, con le 7 frasi; la 6
già un po' strana (il nastro che ondeggia, "Forever." che cala), la 7 che rallenta e si abbassa come un nastro che muore.

Modello: Kokoro-82M (hexgrad, licenza Apache 2.0, uso commerciale permesso: vedi docs/proposte/spot/voci/LICENZA.md),
nella versione ONNX di onnx-community/Kokoro-82M-v1.0-ONNX, con kokoro-onnx. Fuori dal repository (sono 330 MB):
    python3 -m venv /home/user/tools/tts-venv && /home/user/tools/tts-venv/bin/pip install kokoro-onnx soundfile
    model.onnx e voices/<voce>.bin da https://huggingface.co/onnx-community/Kokoro-82M-v1.0-ONNX in /home/user/tools/kokoro
L'utente ha scelto la voce A (uomo, caldo; 23 ottobre): si fa solo quella. Le altre due sono negli scartati
(assets_src/spot/voce/scartati/), e si rifanno con l'argomento --tutte.
Uso: /home/user/tools/tts-venv/bin/python assets_src/spot/voce/genera_voci.py [--tutte]
Scrive le frasi pulite in assets_src/spot/voce/<voce>/frase_N.wav e la traccia intera pulita (speaker_pulito.wav); il
filtro "da TV" è un passaggio a parte (filtro_tv.sh), che si può togliere."""
import os
import subprocess
import sys
import numpy as np
import soundfile as sf
from kokoro_onnx import Kokoro

QUI = os.path.dirname(os.path.abspath(__file__))
RADICE = os.path.normpath(os.path.join(QUI, '..', '..', '..'))
KOKORO = os.environ.get('KOKORO_DIR', '/home/user/tools/kokoro')
PROPOSTE = os.path.join(RADICE, 'docs', 'proposte', 'spot', 'voci')
SCARTATE = os.path.join(RADICE, 'docs', 'proposte', 'spot', 'scartati', 'voci')

# le tre candidate: le voci americane coi voti migliori del modello (VOICES.md di Kokoro)
VOCI = {
    'A_uomo_caldo': 'am_michael',
    'B_uomo_squillante': 'am_puck',
    'C_donna_sorridente': 'af_heart',
}
SCELTA = 'A_uomo_caldo'
# come si scrive per la voce, dove la pronuncia scivola (controllato con Whisper: con la B "Jilly" diventava "Julie")
GRAFIA = {'B_uomo_squillante': {'Jilly': 'Jill-ee'}}
# il testo approvato: (frase, velocità, pausa dopo in secondi)
FRASI = [
    ("Wonderwave Cruises presents...", 0.95, 0.5),
    ("The Jubilee! The happiest ship on the seven seas!", 1.05, 0.9),
    ("Splash into Splash Lagoon, the biggest indoor water park afloat!", 1.08, 0.9),
    ("Twist and turn on the Tower of Slides!", 1.08, 0.9),
    ("And meet the star of the show... Jilly Jubilee!", 1.0, 1.1),
    ("Jilly loves kids. Jilly will keep them safe. Forever.", 0.95, 1.2),
    ("Come aboard. Stay aboard.", 0.85, 0.0),
]


def varispeed(x, velocita):
    """Il nastro a velocità variabile: velocita(t) (t da 0 a 1 lungo la frase) moltiplica insieme tempo e altezza,
    come un registratore che rallenta."""
    pos = [0.0]
    n = len(x)
    while pos[-1] < n - 1:
        pos.append(pos[-1] + velocita(pos[-1] / n))
    pos = np.array(pos[:-1])
    return np.interp(pos, np.arange(n), x).astype(np.float32)


def strana(x, sr):
    # la 6: il nastro ondeggia appena (wow lento, ±1,2 %) e nell'ultimo terzo ("Forever.") cala fino al 90 %
    durata = len(x) / sr
    return varispeed(x, lambda t: (1.0 + 0.012 * np.sin(2 * np.pi * 0.7 * t * durata)) * (1.0 if t < 0.66 else 1.0 - 0.3 * (t - 0.66)))


def guasta(x, sr):
    # la 7: il nastro che muore, dal 97 % al 55 % della velocità, con un ondeggiare più largo; rallenta soprattutto alla
    # fine (prima con t^1,3 il secondo "aboard" col filtro da TV diventava "up and out", per Whisper)
    durata = len(x) / sr
    return varispeed(x, lambda t: (0.97 - 0.42 * t ** 2.2) * (1.0 + 0.02 * np.sin(2 * np.pi * 0.9 * t * durata)))


def main():
    k = Kokoro(os.path.join(KOKORO, 'model.onnx'), os.path.join(KOKORO, 'voices.npz'))
    os.makedirs(PROPOSTE, exist_ok=True)
    for nome, voce in VOCI.items():
        if nome != SCELTA and '--tutte' not in sys.argv:
            continue
        cartella = os.path.join(QUI, nome) if nome == SCELTA else os.path.join(QUI, 'scartati', nome)
        os.makedirs(cartella, exist_ok=True)
        traccia = []
        for i, (testo, velocita, pausa) in enumerate(FRASI, 1):
            for a, b in GRAFIA.get(nome, {}).items():
                testo = testo.replace(a, b)
            s, sr = k.create(testo, voice=voce, speed=velocita, lang='en-us')
            if i == 6:
                s = strana(s, sr)
            elif i == 7:
                s = guasta(s, sr)
            s = 0.89 * s / max(1e-6, float(np.abs(s).max()))
            sf.write(os.path.join(cartella, 'frase_%d.wav' % i), s, sr, subtype='PCM_16')
            traccia += [s, np.zeros(int(pausa * sr), np.float32)]
            print('%s frase %d: %.2f s' % (nome, i, len(s) / sr))
        pulito = os.path.join(cartella, 'speaker_pulito.wav')
        sf.write(pulito, np.concatenate(traccia), sr, subtype='PCM_16')
        # per la pagina dell'utente: col filtro da TV e pulita
        pagina = PROPOSTE if nome == SCELTA else SCARTATE
        os.makedirs(pagina, exist_ok=True)
        subprocess.run(['bash', os.path.join(QUI, 'filtro_tv.sh'), pulito, os.path.join(pagina, 'voce_%s.mp3' % nome)], check=True)
        subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', pulito, '-c:a', 'libmp3lame', '-q:a', '3',
                        os.path.join(pagina, 'voce_%s_pulita.mp3' % nome)], check=True)


if __name__ == '__main__':
    main()
