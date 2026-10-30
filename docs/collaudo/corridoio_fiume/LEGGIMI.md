# Corridoio del fiume, arredo A+C (scelta dell'utente del 30 ottobre)

Il corridoio in fondo alla scala che scende al fiume lento, dalla fine della scala alla porta del capannone. Prima era vuoto (riscontro sulla v0.3.16). Ora è il **corridoio di servizio** delle pompe (A), con **le macchie, la muffa e la pozza** dell'acqua che filtra dalla vasca dell'oblò (C). Gocce dal soffitto, scarabocchi e secchio rovesciato non ci sono: non erano nella A+C descritta all'utente. La luce è quella di prima.

Proposta e regole: `docs/proposte/corridoio_fiume/LEGGIMI.md`.

## Cosa c'è

Tutto sul muro ovest, di fronte all'oblò (a destra andando verso il capannone). Gli oggetti a terra sporgono al più 50 cm, così restano 1,5 m liberi per passare. L'arredo finisce 2 m prima della porta del capannone, per lasciare libere la porta e la strada del bambino.

| Oggetto | Dove (z) | Misure | Come sta |
|---|---|---|---|
| Due tubi delle pompe (ø 14 e 10 cm), con collari ogni 2 m | 48,2 → 63,5 | fra 2,14 e 2,51 m d'altezza | escono 3 cm dal muro della sala pompe, in fondo al pianerottolo; corrono a 8 mm dal muro ed entrano nel muro ovest prima della porta: sono l'acqua che fa girare il fiume |
| Valvola a volantino rossa sul tubo grosso | 54,0 | volantino a 2,14 m | sul tubo, sopra i bidoni |
| Quadro elettrico spento (modello degli ambienti tecnici) | 52,2-52,6 | fra 1,15 e 1,83 m, sporge 22 cm | avvitato al muro: segnato "voluto" con la regola del 23 ottobre (passaggio libero 1,78 m) |
| Due bidoni di plastica blu | 53,4-54,4 | alti 88 cm, ø 49 cm | a terra, contro il muro |
| Secchio di lamiera | 54,7-55,0 | alto 29 cm | a terra |
| Carrello degli attrezzi (modello della risalita) | 55,6-56,4 | alto 1 m, profondo 44 cm | a terra, contro il muro |
| Muffa e macchie con calcare | muro ovest 58,7-60,6 | fino a 1,75 m | decal |
| Griglia di scolo (modello del fiume) | 60,1-60,5 | 40 × 40 cm, 3 cm | a terra, dove finisce la pozza |
| Cartello a disegni: onda, ciambella, freccia verso la porta | 62,3 | 50 cm, a 1,5 m | avvitato al muro |
| Colature sotto l'oblò e muffa accanto | muro est 56,1-58,2 | | decal, a sud della P13 |
| Pozza | dalla colatura (57,45) alla griglia | lunga 3 m, larga 55 cm | il cemento del pavimento fradicio e lucido; la P13 resta a 15 cm dal bordo |

**Cambio rispetto al LEGGIMI della proposta.** Il modello Meshy dei fusti è un gruppo di tre, profondo 1,2 m, e non si separa. Al suo posto ci sono due bidoni fatti in Blender.

**Luce.** L'oblò è a z 58, a metà fra le due lampade rosse (z 51 e 62), nel punto più buio. Lì le macchie si vedono poco, soprattutto quando entra la luce rosa di lei. La muffa del muro di fronte è stata messa verso la lampada vicina alla porta, dove si legge.

## File

- Arredo: `tools/blender/corridoio_fiume.py` → `godot/assets/ambienti_tecnici/corridoio_fiume/corridoio_fiume.gltf`, con le collisioni.
- Macchie: `assets_src/corridoio_fiume/genera_macchie.py`.
- Cartello: `assets_src/corridoio_fiume/genera_cartello.py`. L'immagine è generata e usata solo come texture, come i cartelli del fiume.
- Nel gioco: `godot/scripts/risalita/risalita_gioco.gd`, `_arredo_corridoio_fiume`, per le decal e la pozza.
- Scatti: `godot/tests/collaudo/scatti_corridoio_fiume.gd <cartella> ravvicinati`. Usa l'ambiente della sala senza GI, nebbia volumetrica e SSIL, per stare sotto i 12,5 GB. Con `veloce` e `solo=…` serve per le prove rapide.

## Controlli

- Controllo di posizionamento (`sala_principale`): 0 nuovi, 0 da correggere.
- Giro dagli occhi del giocatore: `1_…`, `2_…`, `3_…`. Scatti ravvicinati di ogni oggetto: `r01`-`r15`. Fogli: `foglio_giro.jpg`, `foglio_ravvicinati_1.jpg`, `foglio_ravvicinati_2.jpg`.
- Texture VRAM Compressed con le mipmap (48c93eb3): rifatti `r02`, `r09`-`r13` e confrontati con quelli di prima in `confronto_vram.jpg`. Differenza media sotto 2 livelli su 255: quadro, macchie con la trasparenza, pozza, griglia e cartello sono uguali.
- Note del ricontrollo di grafica (30 ottobre): piastre dove i tubi entrano nei muri, rosoni tondi con quattro bulloni sul muro ovest e quadrate sul muro della sala pompe (lì i tubi corrono nell'angolo), e cemento bagnato che sfuma attorno alla pozza (decal solo sul pavimento, strato 19: la P13 resta com'è). Rifatti `2_`, `3_`, `r01`, `r11`, `r12`, `r14`; posizionamento 0 nuovi e 0 da correggere.
