"""Mette la voce nuova di lei (genera_lei_inseguimento.py) sul video di controllo di mascotte
(docs/report/mascotte/lei_inseguimento/lei_inseguimento_senza_audio.mp4), nei momenti delle animazioni.
I tempi vengono da godot/proposte/mascotte/video_lei_inseguimento.gd (30 fps):
  vasca: sale 0,0-1,6, incombe 1,6-4,0, respinta 4,0-5,2, (vuoto), sale 5,8, incombe 7,4, presa 8,6-10,1,
         (vuoto), sale 10,5, incombe 12,1, scende 13,1-14,1;
  grata: sale veloce 14,5, colpo_grata 15,5-17,0 (il palmo tocca a 0,25 s di ogni ciclo di 0,5 s:
         15,75, 16,25, 16,75), scende 17,0;
  sb1:   affacciata_sb1 18,4-23,8.
Solo la voce (il video è senza gli altri suoni). Uso:
  /home/user/tools/blender-venv/bin/python assets_src/audio/video_voce_lei.py
Esce docs/proposte/voce_lei/lei_inseguimento_con_voce.mp4.
"""
import os
import subprocess
import tempfile

import numpy as np

import genera_lei_inseguimento as G
from lib_audio import SR, env_points, f32, limiter, mix_into, n_of, write_wav

VIDEO = os.path.join(G.RADICE, 'docs', 'report', 'mascotte', 'lei_inseguimento', 'lei_inseguimento_senza_audio.mp4')
USCITA = os.path.join(G.USCITA, 'lei_inseguimento_con_voce.mp4')
DUR = 23.8

# (secondo, suono, quanto ne tiene: None = tutto)
SCALETTA = [
    (0.0, 'lei_insegue_sale_1', 4.0),
    (4.0, 'lei_insegue_respinta_1', None),
    (5.8, 'lei_insegue_sale_2', 2.8),
    (8.6, 'lei_insegue_presa_1', None),
    (10.5, 'lei_insegue_sale_3', 2.6),
    (14.5, 'lei_insegue_sale_2', 1.0),
    (15.75 - 0.06, 'lei_insegue_grata_1', None),
    (16.25 - 0.06, 'lei_insegue_grata_2', None),
    (16.75 - 0.06, 'lei_insegue_grata_3', None),
    (18.4, 'lei_insegue_sb1', None),
]


def main():
    suoni = G.genera()
    out = np.zeros(n_of(DUR))
    for t, nome, tieni in SCALETTA:
        x = suoni[nome]
        if x.ndim == 2:
            x = x.mean(axis=1)
        if tieni is not None and len(x) > n_of(tieni):
            x = x[:n_of(tieni)] * env_points([(0, 1), (tieni - 0.3, 1), (tieni, 0)], n_of(tieni))
        mix_into(out, x, n_of(t))
    out = limiter(f32(out), -1.0)
    with tempfile.TemporaryDirectory() as d:
        wav = os.path.join(d, 'voce.wav')
        write_wav(wav, out)
        subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', VIDEO, '-i', wav, '-map', '0:v', '-map', '1:a',
                        '-c:v', 'copy', '-c:a', 'aac', '-b:a', '160k', '-shortest', USCITA], check=True)
    print(USCITA)


if __name__ == '__main__':
    main()
