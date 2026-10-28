# Enigma "I giocattoli al loro posto": i modelli (ambienti-1, 28 ottobre)

Per la squadra enigmi (logica su `lavoro/enigma-giocattoli`), secondo l'accordo passato dal coordinatore. Tutto è in
`godot/assets/models/enigma_giocattoli/`; le sorgenti e gli script sono in `assets_src/enigma_giocattoli/`.

## I tre giocattoli (GLB, niente collisioni)

Gomma piena un po' vecchia, scolorita e sporca. I giocattoli sono pesanti e mezzi pieni d'acqua.

Per tutti e tre:
- scala in metri;
- origine al centro della base, col punto che tocca terra a y = 0;
- muso verso -Z;
- una sola mesh, con texture da 1024 (colore, metallo/ruvidezza, normali).

| file | misure (X × altezza × Z) | triangoli |
|---|---|---|
| `paperella.glb` | 0,32 × 0,39 × 0,45 | 4714 |
| `pallone.glb` | diametro 0,50 | 3140 |
| `balena.glb` | 0,50 × 0,38 × 0,75 | 4703 |

- **Paperella:** è la paperella di gomma classica, piccola e liscia, come quella che galleggia nella Polaroid P04.
  - Non è la `paperella_gigante` gonfiabile d'arredo: forma diversa, gomma piena, niente valvola.
  - Ha gli stessi colori: giallo pallido e becco arancione.
- **Pallone:** pieno, rosso, con la buccia ruvida e una riga di stampo; non è a spicchi come i palloni da spiaggia.
- **Balena:** per stare vicina ai 35 cm d'altezza dell'accordo l'ho abbassata a 0,38 m. Ancora più bassa si schiaccia
  troppo: se serve proprio 0,35, si può scalare in Y a 0,92 nella scena.

Per rifarli:
1. `genera_giocattoli.py` (Meshy);
2. `prepara_giocattoli.py` (Blender: misura, origine, verso, decimazione sotto i 4800 triangoli, texture a 1024, sporco).

## Il materiale dei cerchi

- Lo shader è `cerchio_mosaico.gdshader`, con un materiale per colore: `cerchio_giallo.tres`, `cerchio_rosso.tres`,
  `cerchio_blu.tres`.
- Va sul vostro disco di 1 m, con le UV 0..1 sul quadrato del disco. Fuori dal cerchio non si disegna niente (discard).
- Dentro: tessere da 2,5 cm del colore del cerchio fino a 0,88 m di diametro. Intorno, un bordo di due file di tessere
  fosforescenti largo 6 cm.

Parametri dello shader (con `set_shader_parameter`):

| uniform | di serie | cosa fa |
|---|---|---|
| `bordo_acceso` | 0 | 0 = bordo spento (tessere crema); 1 = acceso, verde-giallino fosforescente |
| `energia_bordo` | 1,5 | l'emissione a `bordo_acceso` = 1 |
| `colore_luce` | (0,72; 1; 0,38) | il colore del fosforo |
| `colore` | giallo, rosso o blu | il colore delle tessere |
| `sporco` | 0,55 | chiazze e fughe annerite |
| `bagnato` | 0 | 1 = più scuro e lucido |

**Attenzione al fondo.** Il fondo della parte profonda non è piano a -2,05: è una conca. Nei vostri tre punti l'ho
misurato con un raggio sul modello `sala_piscina.glb`.

| cerchio | quota al centro | quota ai bordi del disco (x+, x-, z+, z-) |
|---|---|---|
| giallo (-3,9; 3,3) | -2,009 | -2,028; -2,001; -2,005; -2,013 |
| rosso (3,9; 3,3) | -2,008 | -2,001; -2,027; -2,004; -2,012 |
| blu (-3,9; -0,1) | -2,001 | -2,011; -2,000; -2,005; -2,000 |

- A -2,05 il disco finisce sotto il fondo e non si vede.
- Nei miei scatti il disco sta a 3 mm sopra il punto trovato col raggio ed è inclinato come la normale del fondo.
- Su 1 m il fondo curva di 1-2 cm, quindi un disco piatto ne tocca un pezzo appena: meglio 1 cm più su, o un disco che
  segua il fondo.
- Lo stesso vale per i giocattoli: vanno appoggiati sul fondo vero.

## Il disegno a pastello

- `disegno_piscina.png`: 1200 × 900, con trasparenza, per il decal da 1,2 × 0,9 m sul muro ovest della parte
  profonda (x -6,97; centro z -0,2, y -0,8; guarda a est).
- La carta è tolta: si vede il pastello dritto sulle piastrelle.
- Orientamento come nell'accordo: in alto l'ovest (x -7), in basso l'est (x 7), a sinistra il muro sud della parte
  fonda (z 5), a destra la spiaggia a nord (z -13).
- Cosa c'è disegnato:
  - la parte profonda in blu, con la botola grigia al centro in (0; 2);
  - il cerchio giallo con la paperella in (-3,9; 3,3), il rosso col pallone in (3,9; 3,3) e il blu con la balena
    in (-3,9; -0,1), ognuno col bordo verdino;
  - poi l'acqua chiara e la sabbia.
- Niente scritte.
- I cerchi sono disegnati più grandi del vero (circa 1,9 m in scala), come li farebbe un bambino.
- Le posizioni vengono da uno schema esatto (`disegno/schema_disegno.py`), ridisegnato a pastello da Meshy
  (`genera_disegno_muro.py`, variante `muro_v2`) e scontornato (`scontorna.py`).

Nei miei scatti il decal è così (lo fa enigmi nella scena):

```
Decal.size = Vector3(1.2, 0.1, 0.9)
global_transform = Transform3D(Basis(Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, -1, 0)), Vector3(-6.97, -0.8, -0.2))
```

## Immagini per la pagina del mattino

- Render dei modelli veri (Blender, Cycles): `render_paperella.jpg`, `render_pallone.jpg`, `render_balena.jpg`.
- Scatti dal motore (`godot/tests/scatti_giocattoli.gd`): `disegno_vicino.jpg`, `disegno_muro.jpg`,
  `disegno_e_cerchi.jpg`, `giocattoli_vicino.jpg`, `pallone_vicino.jpg`.
  - Sono fatti col solo modello della piscina a onde, vuota, al buio, con una torcia sulla camera.
  - Il bordo è spento sul giallo, a metà sul rosso e acceso sul blu.
  - Nella piscina vera ci sono anche i gonfiabili d'arredo, che in questi scatti non si vedono.
