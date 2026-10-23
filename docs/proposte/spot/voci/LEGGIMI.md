# Voce dello speaker

**L'utente ha scelto la voce A** (uomo, caldo; 23 ottobre). È in inglese, nello stile di una pubblicità americana anni '90, e dice le 7 frasi approvate (`docs/proposte/spot/bozza.md`).

| File | Voce |
|---|---|
| `voce_A_uomo_caldo.mp3` | uomo, caldo (Kokoro `am_michael`), col filtro da TV |
| `voce_A_uomo_caldo_pulita.mp3` | la stessa, senza filtro |

Le frasi nel gioco sono in `godot/assets/spot/voce/A_uomo_caldo/frase_1..7.wav`, già col filtro da TV. Le loro durate sono in `durate.json`: 1,99, 3,06, 4,21, 2,21, 3,12, 3,65 e 2,54 s.

- Il filtro "da TV" fa l'altoparlante piccolo, un poco di compressione e una stanza piccola (`assets_src/spot/voce/filtro_tv.sh`).
- La frase 6 è già un po' strana: il nastro ondeggia appena, e "Forever." cala.
- La frase 7 rallenta e si abbassa come un nastro che muore, dal 97 % al 55 % della velocità; rallenta soprattutto alla fine.
- Due ritocchi rispetto alle prove, per farla capire (23 ottobre):
  - il filtro taglia sopra 6,5 kHz invece che sopra 5: a 5 kHz Whisper sentiva "Julie" al posto di "Jilly" nella frase 6;
  - nella 7 il rallentamento parte più tardi: prima il secondo "aboard" diventava "up and out".
- Controllo con Whisper: le 7 frasi del gioco si capiscono tutte, parola per parola.
- La licenza è in `LICENZA.md`: Apache 2.0, l'uso commerciale è permesso.

Le altre due voci candidate (B, uomo squillante; C, donna sorridente) sono negli scartati, non cancellate:
- `docs/proposte/spot/scartati/voci/`: gli mp3;
- `assets_src/spot/voce/scartati/`: le frasi pulite, e in `gioco/` quelle col filtro di prima.

Si rifanno con `genera_voci.py --tutte`.
