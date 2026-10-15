# Ambienti tecnici del capitolo 1

Sala pompe, camera delle onde, interno degli scivoli e vasca d'arrivo. Tutto è generato da script ripetibili in `tools/blender/ambienti2_*.py`.

## Come si rigenera

```bash
python3 tools/blender/ambienti2_texture.py                     # scarica le texture CC0 (ambientCG)
/home/user/tools/blender-venv/bin/python tools/blender/ambienti2_texture_derivate.py
MESHY_API_KEY=... python3 tools/blender/ambienti2_meshy.py      # scrivania, monitor CRT, sedia (solo se mancano)
/home/user/tools/blender-venv/bin/python tools/blender/ambienti2_sala_pompe.py   [--render | --anteprima]
/home/user/tools/blender-venv/bin/python tools/blender/ambienti2_camera_onde.py  [--render | --anteprima]
/home/user/tools/blender-venv/bin/python tools/blender/ambienti2_scivoli.py      [--render | --anteprima] [--solo tubo|vasca]
```

`--anteprima` fa render piccoli e veloci (non vanno nel repository), `--render` quelli finiti in `docs/report/render_ambienti2/`.

## File per Godot (`glb/`)

| File | Cosa contiene |
|---|---|
| `sala_pompe.glb` | La sala intera, 18 x 12 m, alta 5,5 m |
| `camera_onde.glb` | Il tunnel sotto la piscina, 26 m, con pozzo e portello |
| `scivoli_kit.glb` | I moduli di tubo, uno per nodo `MOD_<nome>` |
| `vasca_arrivo.glb` | La vasca d'arrivo con la bocca dello scivolo e la grata |

## Convenzioni

- **Unità in metri.** Il giocatore è alto 1,75 m, occhi a 1,65 m. Blender ha Z in alto, Godot Y in alto: l'export glTF converte da solo (l'asse Y di Blender diventa -Z in Godot).
- **Materiali**: solo Principled BSDF con texture collegate direttamente, così in Godot si vede come nel render. Le texture hanno UV "a scatola" in coordinate del mondo (2 m per ripetizione, 1,2 m per le piastrelle piccole).
- **Nomi in maiuscolo = oggetti con un ruolo in gioco.** Hanno l'origine sul perno giusto e una proprietà personalizzata (extras glTF) che dice come si muovono:
  - `TURBINA_1..3`: le turbine d'avviamento delle pompe. Ruotano attorno all'asse Y di Blender, cioè -Z in Godot. Extras: `colore`, `ordine`.
  - `LEVA`: la leva grande. Perno alla base, ruota attorno a Y di Blender; abbassata = -70°.
  - `GRATA_leva`: lo sportello della gabbia della leva, cerniera sul lato sud.
  - `PORTA_ponte`: la porta stagna verso il ponte inferiore, cardine verticale.
  - `PALA_1..3`, `ALBERO_pale`, `BIELLA_1..3`: le pale delle onde (oscillano attorno a X) e l'albero a gomiti.
  - `PARATIA_1`, `PARATIA_2`: le paratie della camera delle onde. Origine sul bordo inferiore, scendono lungo Z fino a 0.
  - `PORTELLO`: il portello sul fondo della piscina, cerniera lungo Y.
  - `PARATIA_bivio_sx`, `PARATIA_bivio_dx`: le paratie a ribalta del bivio, cerniera in alto.
  - `GRATA_sicurezza`: la grata che cala sulla bocca dello scivolo. Origine sul bordo inferiore, scende lungo Z.
  - `PULSANTE_grata`: il pulsante a fungo della grata.
  - `SCHERMO_CRT`: un rettangolo con UV 0..1 davanti al vetro del monitor, dove va la ViewportTexture della telecamera.
  - `SCHEMA_pompe`: lo schema a colori sul muro.
- **Acqua**: tutti gli oggetti `ACQUA_*` hanno un materiale segnaposto. Lo shader vero lo fa l'agente dell'acqua. Le strisce `ACQUA_scorre_*` dentro i tubi hanno la U lungo il tubo (1 = 5 m) e l'extra `velocita_m_s`.
- **Segnaposto (Empty)**: `VAPORE_*` (vapore), `ARIA_*` (soffi d'aria dalle bocchette), `PUNTO_*` (punti utili: porte, scala, monitor), `USCITA*` (aggancio dei moduli di tubo).
- **Luci**: le puntiformi e gli spot sono nel GLB (KHR_lights_punctual), ma l'intensità va rivista in Godot (rosse d'emergenza `LUCE_rossa_*`: `light_energy` 2-3, `omni_range` 6). Le luci ad area (neon, schermo del CRT) il glTF non le porta: in Godot vanno messe sui tubi al neon (`neon_*`, emissivi) e sullo `SCHERMO_CRT`. Verificato l'import in Godot 4.7.2: nodi, perni e luci arrivano giusti.
- **Volumi di nebbia e vapore** servono solo ai render: in Godot c'è la nebbia volumetrica.

## Colori

I colori degli scivoli sono quelli della torre nella sala principale (kit di `lavoro/ambiente`, palette `sala_a`). La vasca d'arrivo usa le stesse texture della sala (`texture/da_ambiente/`, copiate dal kit) e le stesse misure: 7 x 10 m, acqua a -0,22, fondo a -1,10.

| Uso | Colore (sRGB) |
|---|---|
| Pompa e turbina gialla | 235, 180, 20 |
| Pompa e turbina rossa | 200, 30, 30 |
| Pompa e turbina blu | 30, 90, 200 |
| Scivolo rosso (tubo principale dell'inseguimento) | 178, 62, 45 |
| Scivolo verde (ramo sinistro del bivio) | 92, 142, 62 |
| Scivolo blu (ramo destro, grata cieca) | 45, 92, 155 |
| Scivolo giallo (tratto spaccato) | 205, 158, 55 |
| Scivolo arancio (di scorta) | 240, 108, 58 |
| Luce d'emergenza | rosso 1.0, 0.06, 0.03 |
| Neon | azzurro 0.25, 0.95, 1.0 |
| Luce di servizio nei tubi | ambra 1.0, 0.45, 0.12 |

Ordine delle pompe sullo schema: **blu, giallo, rosso**, poi la leva. Nella sala, da sinistra a destra, le pompe sono gialla, rossa e blu, così l'ordine non coincide con la posizione.

## Moduli degli scivoli

Diametro interno 1,6 m, parete 6 cm, giunture ogni 2 m con bulloni. L'ingresso di ogni modulo è nell'origine del suo nodo `MOD_<nome>`, con l'asse del tubo lungo +X a quota 0 (il fondo è a -0,8). L'Empty `USCITA` dice dove si aggancia il modulo successivo.

- `scivolo_dritto_4m`, `scivolo_discesa_4m` (dritto, da usare inclinato)
- `scivolo_curva_sx_90`, `scivolo_curva_dx_90`, `scivolo_curva_sx_45`, `scivolo_curva_dx_45` (raggio 4 m)
- `scivolo_discesa_inizio`, `scivolo_discesa_fine` (piega di 20° in verticale, raggio 5 m)
- `scivolo_spirale_dx` (mezzo giro, raggio 3,5 m)
- `scivolo_trasparente_4m` (plastica trasparente con anelli rossi: si vede fuori)
- `scivolo_spaccato_partenza`, `scivolo_spaccato_arrivo` (il tratto spaccato da cui si vola fuori: la distanza tra i due si decide in Godot)
- `scivolo_bivio` (camera di smistamento in acciaio con due uscite, `USCITA_sx` e `USCITA_dx`, e due paratie)
- `scivolo_grata_cieca` (la strada sbagliata: finisce contro una grata)

## Licenze

Vedi `LICENZE.md`.
