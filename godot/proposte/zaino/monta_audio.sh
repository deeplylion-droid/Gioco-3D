#!/bin/bash
# PROPOSTA zaino: mette sotto un video di 8 s (scaletta fissa) i suoni di oggi dello zaino, a tempo.
# Serve perché nel sandbox, registrando con Movie Maker, i suoni dell'addon audio non partono.
# Eventi: aspira 0,5-2,5 s (serbatoio pieno a 2,5 s, poi la pompata), getto 3,5-7,0 s con l'impatto.
# Uso: godot/proposte/zaino/monta_audio.sh <video.mp4>   (sostituisce l'audio nel file)
set -euo pipefail
V=$(realpath "$1")
A=$(cd "$(dirname "$0")/../../audio/giocatore" && pwd)
TMP=$(mktemp -d /tmp/claude-0/audio_XXXX)
ffmpeg -y -loglevel error -i "$V" \
	-i "$A/zaino_aspira_inizio.ogg" -stream_loop -1 -i "$A/zaino_aspira_loop.ogg" -i "$A/zaino_aspira_fine.ogg" \
	-i "$A/zaino_pieno.ogg" -i "$A/zaino_pompata.ogg" \
	-i "$A/zaino_getto_inizio.ogg" -stream_loop -1 -i "$A/zaino_getto_loop.ogg" -stream_loop -1 -i "$A/zaino_impatto_loop.ogg" \
	-i "$A/zaino_getto_fine.ogg" -filter_complex "
	[1:a]adelay=500|500[a1];
	[2:a]atrim=0:2.0,afade=t=in:d=0.15,afade=t=out:st=1.85:d=0.15,adelay=500|500[a2];
	[3:a]adelay=2500|2500[a3];
	[4:a]volume=0.8,adelay=2500|2500[a4];
	[5:a]adelay=2950|2950[a5];
	[6:a]adelay=3500|3500[a6];
	[7:a]atrim=0:3.5,afade=t=in:d=0.1,afade=t=out:st=3.35:d=0.15,adelay=3500|3500[a7];
	[8:a]atrim=0:3.2,afade=t=in:d=0.2,afade=t=out:st=3.0:d=0.2,volume=0.8,adelay=3800|3800[a8];
	[9:a]adelay=7000|7000[a9];
	[a1][a2][a3][a4][a5][a6][a7][a8][a9]amix=inputs=9:normalize=0,atrim=0:8,apad=whole_dur=8[aud]" \
	-map 0:v -map "[aud]" -c:v copy -c:a aac -b:a 128k -movflags +faststart -t 8 "$TMP/out.mp4"
mv "$TMP/out.mp4" "$V"
rm -rf "$TMP"
ffmpeg -i "$V" -af volumedetect -f null - 2>&1 | grep max_volume
