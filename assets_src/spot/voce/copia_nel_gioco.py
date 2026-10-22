"""Le frasi dello speaker nel gioco, per il lettore dello spot (ambienti-2, scenes/spot/lettore_spot.tscn): per ogni voce
candidata godot/assets/spot/voce/<voce>/frase_1..7.wav, già col filtro da TV (filtro_tv.sh), più durate.json con la
durata di ogni frase. La voce la sceglie l'utente: il lettore la prende come parametro.
Uso (dopo genera_voci.py): python3 assets_src/spot/voce/copia_nel_gioco.py"""
import json
import os
import subprocess
import wave

QUI = os.path.dirname(os.path.abspath(__file__))
GIOCO = os.path.normpath(os.path.join(QUI, '..', '..', '..', 'godot', 'assets', 'spot', 'voce'))
VOCI = ('A_uomo_caldo', 'B_uomo_squillante', 'C_donna_sorridente')

durate = {}
for v in VOCI:
    os.makedirs(os.path.join(GIOCO, v), exist_ok=True)
    durate[v] = []
    for i in range(1, 8):
        uscita = os.path.join(GIOCO, v, 'frase_%d.wav' % i)
        subprocess.run(['bash', os.path.join(QUI, 'filtro_tv.sh'), os.path.join(QUI, v, 'frase_%d.wav' % i), uscita], check=True)
        with wave.open(uscita) as w:
            durate[v].append(round(w.getnframes() / w.getframerate(), 3))
with open(os.path.join(GIOCO, 'durate.json'), 'w') as f:
    json.dump(durate, f, indent='\t')
print(json.dumps(durate))
