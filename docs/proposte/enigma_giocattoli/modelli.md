# Enigma "I giocattoli al loro posto": i modelli (ambienti-1, 28 ottobre)

Per la squadra enigmi (logica su `lavoro/enigma-giocattoli`). Tutto in `godot/assets/enigma_giocattoli/`; le
sorgenti e gli script sono in `assets_src/enigma_giocattoli/`.

## I tre giocattoli

Gomma piena, pesante, mezza piena d'acqua, un po' scolorita e sporca. Ognuno è una scena `RigidBody3D` con il modello
(`Modello`) e una collisione semplice (`Collisione`). **Origine in basso al centro** (appoggiato sul fondo con y = 0),
**davanti verso +Z** (becco e muso). Misure in metri, X × altezza × Z.

| scena | modello | misure | collisione | massa |
|---|---|---|---|---|
| `paperella.tscn` | `paperella.glb` (8341 triangoli) | 0,44 × 0,50 × 0,62 | involucro convesso del modello | 24 kg |
| `palla_rossa.tscn` | `palla_rossa.glb` (3140 triangoli) | diametro 0,55 | sfera r 0,275 con centro a y 0,275 | 45 kg |
| `balena_blu.tscn` | `balena_blu.glb` (8346 triangoli) | 0,44 × 0,38 × 0,66 | involucro convesso del modello | 22 kg |

- La paperella è `paperella_gigante` degli oggetti in alta qualità (`assets_src/ambiente/oggetti_hq/`): la stessa
  già nella sala e nelle Polaroid, solo portata a 62 cm e sporcata.
- Palla e balena sono nuove (Meshy, `genera_giocattoli.py`).
- Sui corpi: `linear_damp` 0,6, `angular_damp` 1,5, attrito 0,7, rimbalzo 0,05. Sono valori di partenza: il galleggiamento
  sull'acqua e la spinta del getto li tarate voi.
- Le texture sono di 2048 px. I preset alto e basso le prendono come tutti gli altri modelli (import di Godot), quindi
  non c'è niente da fare a parte.
- Per rifarli: `prepara_giocattoli.py` (Blender: misura, origine, sporco), poi `genera_risorse.gd` (scene,
  materiali, disegno).

## Il cerchio a mosaico

- `cerchio_mosaico.tscn`: un piano di 1,1 × 1,1 m, 2 mm sopra l'origine, da mettere sul fondo. Di serie ha il
  materiale giallo: per gli altri colori si cambia il materiale (`material_override` o `mesh.material`).
- Materiali: `cerchio_giallo.tres`, `cerchio_rosso.tres`, `cerchio_blu.tres`, tutti sullo shader
  `cerchio_mosaico.gdshader`.
- Disegno: un disco di tessere da 2,5 cm del colore del giocattolo (diametro 0,90 m), poi un anello di due file di
  tessere fosforescenti fino a 1,04 m. Fuori dal cerchio non si disegna niente (discard), quindi sotto si vede il fondo.

Parametri dello shader (con `set_shader_parameter`; un materiale per cerchio, così si accendono uno alla volta):

| parametro | di serie | cosa fa |
|---|---|---|
| `luce_bordo` | 0 | 0 = bordo spento (tessere color crema); 1 = appena acceso (verdino, non una lampada) |
| `energia_bordo` | 1,2 | quanta emissione a `luce_bordo` = 1 |
| `colore_luce` | verdino (0,55; 1; 0,62) | il colore del fosforo |
| `colore` | giallo, rosso o blu | il colore delle tessere |
| `sporco` | 0,55 | chiazze e fughe annerite |
| `bagnato` | 0 | 1 = più scuro e lucido (per il fondo appena svuotato) |

## Il disegno dei bambini

- `disegno_giocattoli.tscn`: un `MeshInstance3D` con la mesh `disegno_giocattoli.res`.
- È un foglio di 30 × 40 cm (come quello degli acquari) con quattro pezzi di nastro di carta agli angoli. Il foglio sta
  1 mm davanti al muro e il nastro 2 mm.
- Origine al centro del foglio, sulla faccia del muro. Il foglio guarda verso +Z.
- La texture è `disegno_giocattoli.jpg` (variante v2 in `assets_src/enigma_giocattoli/disegno/`; la v1, coi cerchi
  solo contornati, resta lì).
- Cosa mostra: la piscina vista dall'alto con la parte fonda in alto, la scaletta in alto a destra, il cerchio rosso
  con la palla in alto al centro, il giallo con la paperella in basso a sinistra e il blu con la balena in basso a
  destra. Niente scritte.
- **Questa disposizione l'ho proposta io al coordinatore**: se i cerchi nel gioco vanno messi diversamente, il disegno
  si rifà (circa 6 crediti).

Posto provato negli scatti, sul muro della parte fonda (z = 5, guarda verso la spiaggia):

- Il centro del foglio è a (-2,5; -0,42; 4,997), con rotation.y = 180°.
- In altezza sta sopra le bocchette delle onde (arrivano a y -0,77), fra due griglie, e lontano dal pulsante del
  portello (x 2,25).
- A piscina piena, se l'acqua arriva a circa -1,5, il disegno resta fuori dall'acqua.

## Immagini

- Render dei modelli veri (Blender, Cycles): `render_paperella.jpg`, `render_palla_rossa.jpg`, `render_balena_blu.jpg`.
- Scatti dal motore: `disegno_da_vicino.jpg`, `disegno_dal_fondo.jpg` e `cerchi_e_giocattoli.jpg`.
  - Gli scatti sono fatti col solo modello della piscina a onde, vuota, al buio, con una torcia sulla camera
    (`godot/tests/scatti_giocattoli.gd`).
  - Nello scatto dei cerchi il bordo è spento sul giallo, a metà sul rosso e acceso sul blu.
  - La disposizione dei cerchi in quello scatto serve solo alla foto.
