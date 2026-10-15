# Kit modulare dell'acquapark (capitolo 1)

Specifiche e regole per i pezzi dell'ambiente: la nave da crociera anni '90 abbandonata, di notte.
Tutto si rigenera dagli script in `tools/blender/ambiente_*.py` (vedi in fondo). Per montare la
sala principale in Godot leggi `INTEGRAZIONE.md`.

## Stato

- **Sala principale (vertical slice): fatta**, palette `sala_a` = Opzione 1 adattata al concept A
  (scelta del coordinatore come la più vicina al concept A e allo storyboard). Le Opzioni 2 e 3
  restano alternative: basta `--palette` negli script e si rigenerano le texture.
- Proposte in attesa dell'utente: `docs/proposte/ambiente/` (angolo di prova in 3 palette, oggetti).

## Unità, assi, griglia

- **Metri**, scala reale. In Blender Z in alto; il GLB esce con Y in alto (glTF), come Godot.
  Conversione: `(x, y, z)_Blender -> (x, z, -y)_Godot`.
- **Griglia di posa 0,5 m**; moduli principali **2 m**; pezzi di riempimento da 0,5 m e 1 m.
- Altezza di un ponte (modulo di parete del kit): **3 m**. Nella sala (40 x 44 m, x da -20 a 20,
  y da -20 a 24 in Blender): 4 m sotto la galleria, soffitto a 11,5 m, cupola fino a 18 m.

## Misure reali usate

| Elemento | Misura |
|---|---|
| Piastrelle pareti e vasche | 12,5 x 12,5 cm (texture 1,5 m = 12 piastrelle) |
| Mosaico (Opzione 2, piedistallo) | 5 x 5 cm (texture 1,2 m = 24 tessere) |
| Pavimento antiscivolo | 25 x 25 cm (texture 1,5 m = 6 piastrelle) |
| Fasce della parete | zoccolo 0-0,25; piastrelle 0,25-0,75; fascia 0,75-1,0; piastrelle 1,0-2,0; intonaco sopra |
| Vasca standard / piscina a onde / vasca d'arrivo / vasche bimbi | 1,2 m / 2,0 m (spiaggia a 0) / 1,1 m / bordo 0,45 m |
| Bordo a sfioro | canale con griglia 25 cm (listelli ogni 3 cm) + copertina in ceramica 25 cm con toro |
| Scaletta della vasca | tubo inox Ø 43 mm, corrimano a 50 cm, alto 0,92 m sul ponte, gradini ogni 30 cm |
| Ringhiera | corrimano Ø 50 mm a 1,05 m (SOLAS chiede almeno 1,0 m), sbarre Ø 16 mm ogni 11 cm |
| Porta degli spogliatoi (kit) | doppia anta, luce 1,8 x 2,4 m, telaio metallico |
| Vano della sala verso gli spogliatoi | luce 1,2 x 2,2 m, porta stagna aperta (anta 1,4 x 2,3 m, 6 leve, volantino) |
| Porta stagna (da fare) | luce 0,8 x 1,9 m, soglia 0,3 m, angoli arrotondati, 8 tiranti |
| Oblò | luce Ø 60 cm, flangia Ø 84 cm con 12 bulloni, manicotto nello spessore (20 cm), centro a 1,5 m |
| Galleria | profonda 3 m, soletta 0,3 m, a 4,0 m (sala) / 3,0 m (kit) |
| Scivoli | tubo chiuso Ø interno 1,0 m, vetroresina 12 mm, flange imbullonate ogni 2 m |
| Plafoniera al neon | 2 tubi T8 da 120 cm (Ø 26 mm) |
| Luce d'emergenza | plafoniera stagna Ø 18 cm con gabbia e vetro rosso |
| Cartelloni | 2,4 x 1,35 m (kit) e 3,2 x 1,8 m (sala), solo disegni, nessuna scritta |
| Torre degli scivoli | 6 x 6 m, piani a 3,0 / 6,0 / 8,6 m, pozzo centrale 2,2 m, gradini da 18 cm |

## Monumento della statua (per il gruppo "medusa")

La statua della medusa è il simbolo del gioco: il suo piedistallo è un **monumento** al centro del
piazzale sud, sull'asse della porta degli spogliatoi. Il piedistallo è **vuoto** (nodo `amb_piedistallo`
in `sala_monumento.glb`); la medusa la mette il gruppo "medusa".

- Centro: Blender **(0, -10, 0)** = Godot **(0, 0, 10)**. La porta (vano 1,2 x 2,2 m) è a 10 m, sullo
  stesso asse: entrando la statua si vede subito, intera e centrata, con la cupola sopra.
- **Piano superiore a 1,15 m**, Ø 2,8 m. La medusa va appoggiata in Godot a **(0, 1,15, 10)**,
  rivolta verso la porta (+Z Godot). Prevista alta circa 4,5 m: la cima arriva a 5,65 m.
- Gradoni: Ø 4,0 m (alto 0,28) e Ø 3,24 m (fino a 0,56), piastrellati; tamburo Ø 2,6 m con il fregio
  a mosaico marino; cornice in ceramica con il toro d'ottone; conchiglie d'ottone sul secondo gradino.
- Davanti (verso la porta) la scatola gialla con il fungo rosso dei bambini (nodo a parte), a 0,8 m.
- Luci: 4 faretti nel primo gradino (dal basso), 2 fari sulla ringhiera della galleria sud, il lampione
  accanto (base in Blender (2,8, -13,2)) con la lampada sopra il davanti della statua.
- Cordone di velluto su colonnine d'ottone a raggio 3 m, con un varco di 3 m sul davanti.
- Alla base le offerte dei bambini: disegni a pastello (senza scritte), conchiglie, stelle marine,
  secchiello, salvagente, orsetto, paperelle, pallone, ciambella.

## Convenzioni dei nomi

- Pezzi del kit: `amb_<pezzo>_<misure>[_variante]`, per esempio `amb_parete_2x3_oblo`, `amb_bordo_vasca_2`.
- Pezzi della sala: `sala_<parte>` (`sala_pavimento`, `sala_torre`, `sala_secchio_gigante`...).
- Materiali: `M_amb_<materiale>` (kit e sala), `M_prop_<oggetto>` (oggetti Meshy). Lo stesso nome
  in tutte le palette: cambia solo la texture.
- Oggetti di scena in sala: `ogg_<oggetto>_<n>` (istanze dello stesso modello).
- Collisioni: `<nome>-convcolonly` (convesse: scatole, rampe, tratti di tubo) e `<nome>-colonly`
  (trimesh: pavimento, piscina). Nomi sempre unici: un `.001` finale romperebbe il suffisso in Godot.

## Pivot

- Moduli di parete, pavimento, galleria: angolo in basso a sinistra sul fronte (x=0, y=0, z=0);
  il fronte guarda -y, lo spessore va verso +y.
- Bordo vasca: sul filo della parete della vasca, la vasca sta verso +y; angolo esterno: sullo spigolo.
- Oblò, luci d'emergenza, cartelloni: al centro (o al centro in basso), sul filo del muro.
- Oggetti di scena: alla base, al centro. Secchio gigante e ruota a pale: sul loro asse di rotazione.

## UV e densità delle texture

- UV0 in **scala reale**: 1 unità UV = il lato reale della texture del materiale (1,5 m piastrelle,
  1,2 m mosaico, 2 m intonaco, 1 m metalli e plastiche). Niente atlas: le texture si ripetono.
- Le texture a piastrelle sono **allineate**: una fuga cade sul bordo della texture. Ogni pezzo lungo
  un multiplo di 12,5 cm si accosta al vicino senza giunte visibili.
- Densità: 1365 px/m piastrelle, 1024 px/m intonaco, 2048 px/m metalli (texture 2K). Obiettivo:
  almeno 1024 px/m vicino al giocatore, 512 px/m per soffitti e superfici lontane.
- UV2 (lightmap): la genera Godot all'import se si usa LightmapGI.
- Colore dei vertici (COLOR_0): sporco e umidità che risale dal pavimento. In Godot serve
  `vertex_color_use_as_albedo` (lo accende lo script `godot/ambiente_post_import.gd`).

## Materiali e texture

- Texture CC0 da ambientCG e Poly Haven, 2K, in `textures/cc0/<nome>/` con nomi uniformi:
  `_col` (colore sRGB), `_nrm` (normal OpenGL), `_orm` (R occlusione, G rugosità, B metallo), `_alt` (altezza).
  Fonti e licenze: `textures/LICENZE.md`.
- Le palette ricolorano le CC0 (ogni piastrella prende il suo colore, sporco e fughe conservati):
  `textures/derivate/<palette>/`. Ricette in `tools/blender/ambiente_palette.py`.
- Bagnato: ogni piastrella del pavimento (25 cm) prende uno di tre materiali con la stessa texture di
  colore e rugosità diverse (`pavimento_asciutto`, `pavimento`, `pavimento_bagnato`), scelti da un
  campo in spazio mondo (più bagnato vicino alle vasche, sotto le lastre rotte della cupola e lungo il
  bordo della galleria). Le pozzanghere sono mesh a parte con la texture del pavimento (le fughe
  combaciano), lisce come specchi (`M_amb_pozzanghera`): con SSR riflettono.
- Sporco: colori dei vertici calcolati in spazio mondo (`tools/blender/ambiente_dettagli.py`): umidità
  che risale con la linea della marea, colature dall'alto, angoli più sporchi, linea dell'ultimo livello
  dell'acqua nella piscina. Le fughe delle piastrelle hanno la normal map più forte (`normale` 1,6).
- Grigliati e rosa dei venti: PNG con alfa (alpha scissor in Godot).
- Oggetti Meshy: GLB grezzi in `oggetti/<nome>/<nome>_meshy.glb` (texture ricompresse in JPG, la
  geometria è quella di Meshy); in sala hanno texture 1K se piccoli, 2K se grandi.

## LOD e poligoni

- I LOD li genera Godot all'import (`meshes/generate_lods`, attivo di serie): i pezzi sono già leggeri.
- Sala: i numeri aggiornati di ogni GLB sono in `INTEGRAZIONE.md` (architettura circa 210 mila
  triangoli con pavimento e pareti più fitti per lo sporco nei colori dei vertici).
- Se servono più prestazioni: `visibility_range_end` sugli oggetti piccoli (palloni, paperelle) a 25-30 m.

## Collisioni

- Muri, colonne, galleria, ringhiere, piedistallo, lampione, oggetti: scatole convesse.
- Pavimento e piscina a onde: trimesh (seguono buchi, pendenza e conca).
- Torre: piani intorno al pozzo, parapetti, colonne, rampe inclinate (convesse).
- Struttura di gioco: pedane, parapetti, scala, passerelle e ponte (si sale davvero).
- Scivoli: tratti convessi di circa 2 m intorno al tubo (fuori). L'interno per l'inseguimento va
  fatto a parte (percorso su binario o collisioni dedicate).

## Export GLB per Godot

- `ambiente_kit.py`: un GLB per pezzo del kit. `--texture incorporate` (di serie, autonomo) oppure
  `--texture nessuna` (solo nomi dei materiali, file piccolissimi, da usare con materiali condivisi).
- `ambiente_sala.py --glb <cartella>`: la sala in 8 GLB + `sala_dati.json` (vedi `INTEGRAZIONE.md`).
- Opzioni usate: Y in alto, modificatori applicati, normali e UV, colori dei vertici, immagini nel
  formato originale (JPG; PNG solo con alfa), qualità JPG 88. Verificato l'import in Godot 4.7.2.

## Come si rigenera tutto

```
PY=/home/user/tools/blender-venv/bin/python
$PY tools/blender/ambiente_texture.py scarica              # texture CC0 (2K) + allineamento fughe
$PY tools/blender/ambiente_texture.py deriva sala_a        # texture della palette (anche p1_..., p2_..., p3_...)
$PY assets_src/ambiente/oggetti/meshy_oggetti.py immagini   # Meshy: immagini di riferimento (crediti!)
$PY assets_src/ambiente/oggetti/meshy_oggetti.py modelli    # Meshy: modelli 3D (crediti!)
$PY tools/blender/ambiente_oggetti.py ricomprimi --copia <cartella fuori dal repo>
$PY tools/blender/ambiente_sala.py --glb assets_src/ambiente/glb/sala          # GLB della sala
$PY tools/blender/ambiente_integrazione.py                                      # INTEGRAZIONE.md dai GLB
flock /home/user/tools/render.lock nice -n 10 $PY tools/blender/ambiente_sala.py --render S04_statua --uscita <cartella>   # render Cycles (max 1600x900)
$PY tools/blender/ambiente_kit.py --palette sala_a --uscita <cartella>          # pezzi del kit
nice -n 10 $PY tools/blender/ambiente_anteprima.py --palette p1_bianco_turchese --uscita <cartella>  # angolo di prova
$PY tools/blender/ambiente_proposte.py angolo <cartella render>                 # JPG con le etichette
```

Gli script Meshy salvano gli ID dei task in `meshy_task.json`: rilanciandoli non si ripagano i task già fatti.

## Da fare

Porte stagne, scale per la galleria, spogliatoi e corridoi, camera delle onde e sala pompe, tubo rotto,
angoli interni del bordo vasca, varianti rotte delle piastrelle (le CC0 "C" e "D" sono già pronte da usare).
