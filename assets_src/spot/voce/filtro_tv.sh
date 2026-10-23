#!/bin/bash
# Il filtro leggero "da TV" sopra la voce dello speaker (si può togliere: le frasi pulite restano in frase_N.wav):
# l'altoparlante piccolo di un televisore a tubo (taglia sotto 220 Hz e sopra 6,5 kHz), un poco di compressione e di
# saturazione, e una stanza piccola. Uso: filtro_tv.sh <ingresso> <uscita .mp3 o .wav>
# (a 5 kHz, con la voce A, Whisper sentiva "Julie" al posto di "Jilly" nella frase 6: 23 ottobre)
set -e
ffmpeg -y -loglevel error -i "$1" -af "highpass=f=220,highpass=f=220,lowpass=f=6500,lowpass=f=6500,acompressor=threshold=-20dB:ratio=3:attack=5:release=90,asoftclip=type=tanh:param=1.2,aecho=0.85:0.5:17|29:0.22|0.14,volume=1.4,alimiter=limit=0.93" \
    $([[ "$2" == *.mp3 ]] && echo "-c:a libmp3lame -q:a 3") "$2"
