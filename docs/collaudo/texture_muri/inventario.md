# Inventario dei muri e delle macchie (23 ottobre)

Collaudo, per la richiesta dell'utente "texture dei muri troppo dettagliate" (coordinatore, 23 ottobre).
Niente è cambiato nel gioco: è solo l'elenco, con gli scatti presi dal motore.

## Come è fatto

- Strumenti: `godot/tests/collaudo/inventario_muri.gd` (tutti i materiali di una scena, con l'area delle facce verticali),
  `godot/tests/collaudo/vedute_muri.gd` (per ogni materiale due punti dove sta il giocatore, occhi a 1,6 m, muro di fronte
  a 2-3,5 m, niente in mezzo), `godot/tests/collaudo/inventario_macchie.gd` (decal e macchie: quante, quanto grandi, dove).
- Scene: interni, tecnici, risalita (con fiume e infermeria costruiti subito), sala della torre e dell'inseguimento,
  sala principale (solo i nodi della sala).
- Gli scatti sono nella luce del gioco (luci bianche al 40%, niente torcia, come lavoro/godot b1c162b3) e, per leggere
  la texture, anche in luce neutra (una luce bianca sulla camera, suffisso `_n`). Nella luce del gioco molti muri
  sono quasi neri: è il buio voluto, non un difetto.
- Le colonne "carico" misurano la texture da sola (0-1): contrasto, dettaglio fine, grana, rilievo del normal.
- "Muro" è l'area delle facce verticali, in m²: dice quanto si vede.

## Muri, zona per zona

### Interni (corridoio, spogliatoi, stanzino)

| # | Materiale | Texture | Scala | Normal | Muro | Dove | Carico (contrasto / dettaglio / grana / rilievo) | Scatti |
|---|---|---|---|---|---|---|---|---|
| int_m01 | parete.gdshader (vernice (0.55, 0.52, 0.44, 1.0), scrostatura 0.22) | scrostata ambienti_interni/texture/lamiera_crema_col.jpg | UV del modello | shader: 0,5 sulla vernice, 1,0 sullo scrostato | 422 m² | corridoio_statico, spogliatoi_statico, stanzino_statico | 0.13 / 0.044 / 0.044 / 0.057 | int_m01_1, int_m01_2 |
| int_m02 | parete.gdshader (vernice (0.13, 0.24, 0.23, 1.0), scrostatura 0.3) | scrostata ambienti_interni/texture/lamiera_petrolio_col.jpg | UV del modello | shader: 0,5 sulla vernice, 1,0 sullo scrostato | 267 m² | corridoio_statico, spogliatoi_statico, stanzino_statico | 0.03 / 0.009 / 0.010 / 0.057 | int_m02_1, int_m02_2 |
| int_m03 | piastrelle.gdshader (0.0 per lato, sporco <null>) | ambienti_interni/texture/piastrelle_doccia_col.jpg | UV del modello | fughe <null> | 117 m² | spogliatoi_statico | 0.08 / 0.019 / 0.023 / 0.081 | int_m03_1, int_m03_2 |
| int_m04 | piastrelle.gdshader (0.0 per lato, sporco <null>) | ambienti_interni/texture/piastrelle_verdi_col.jpg | UV del modello | fughe <null> | 102 m² | spogliatoi_statico | 0.05 / 0.018 / 0.033 / 0.079 | int_m04_1, int_m04_2 |
| int_m07 | metallo_grezzo | ambienti_interni/texture/metallo_grezzo_col.jpg + ambienti_interni/texture/metallo_grezzo_nrm.jpg | uv 1.0 | normal_scale 1.0 | 30 m² | corridoio_statico, grata_aerazione, spogliatoi_statico | 0.02 / 0.006 / 0.011 / 0.006 | int_m07_1, int_m07_2 |
| int_m11 | ruggine | ambienti_interni/texture/ruggine_col.jpg + ambienti_interni/texture/ruggine_nrm.jpg | uv 1.0 | normal_scale 1.0 | 10 m² | corridoio_statico, spogliatoi_statico, stanzino_statico | 0.02 / 0.009 / 0.011 / 0.026 | int_m11_1, int_m11_2 |

### Ambienti tecnici (camera onde, sala pompe, magazzino, raccordo)

| # | Materiale | Texture | Scala | Normal | Muro | Dove | Carico (contrasto / dettaglio / grana / rilievo) | Scatti |
|---|---|---|---|---|---|---|---|---|
| tec_m01 | parete.gdshader (vernice (1.0, 1.0, 1.0, 1.0), scrostatura 0.15) | base ambienti_tecnici/texture/MetalPlates013_Color.jpg; scrostata ambienti_interni/texture/ruggine_col.jpg | UV del modello | shader: 0,5 sulla vernice, 1,0 sullo scrostato | 1829 m² | CAMERA_struttura, NICCHIA_1, NICCHIA_2 | 0.04 / 0.019 / 0.017 / 0.063 | tec_m01_1, tec_m01_2 |
| tec_m02 | parete.gdshader (vernice (0.95, 0.95, 0.95, 1.0), scrostatura 0.0) | base ambienti_tecnici/texture/Concrete042C_Color.jpg; scrostata ambienti_interni/texture/ruggine_col.jpg | UV del modello | shader: 0,5 sulla vernice, 1,0 sullo scrostato | 1344 m² | CAMERA_struttura, NICCHIA_1, NICCHIA_2 | 0.05 / 0.029 / 0.016 / 0.07 | tec_m02_1, tec_m02_2 |
| tec_m03 | piastrelle.gdshader (0.0 per lato, sporco <null>) | ambienti_tecnici/texture/piastrelle_sporche_Color.jpg | UV del modello | fughe 0.0 | 504 m² | CAMERA_pozzo, SALA_struttura, SALA_vasca | 0.07 / 0.027 / 0.013 / 0.069 | tec_m03_1, tec_m03_2 |
| tec_m04 | ferro_arrugginito | ambienti_tecnici/texture/Metal021_Color.jpg + ambienti_tecnici/texture/Metal021_NormalGL.jpg | uv 1.0 | normal_scale 1.0 | 352 m² | ALBERO_pale, CAMERA_bocchette, CAMERA_costole | 0.05 / 0.020 / 0.021 / 0.011 | tec_m04_1, tec_m04_2 |
| tec_m05 | parete.gdshader (vernice (0.9, 0.9, 0.9, 1.0), scrostatura 0.0) | base ambienti_tecnici/texture/Concrete042C_Color.jpg; scrostata ambienti_interni/texture/ruggine_col.jpg | UV del modello | shader: 0,5 sulla vernice, 1,0 sullo scrostato | 54 m² | CAMERA_struttura, RACCORDO_struttura | 0.05 / 0.029 / 0.016 / 0.07 | tec_m05_1 |
| tec_m07 | vernice_giallo | ambienti_tecnici/texture/vernice_giallo_Color.jpg + ambienti_tecnici/texture/PaintedMetal006_NormalGL.jpg | uv 1.0 | normal_scale 1.0 | 41 m² | ALBERO_pale, PALA_1, PALA_2 | 0.14 / 0.046 / 0.043 / 0.057 | tec_m07_1, tec_m07_2 |
| tec_m08 | tubo_ruggine | ambienti_tecnici/texture/Metal041B_Color.jpg + ambienti_tecnici/texture/Metal041B_NormalGL.jpg | uv 1.0 | normal_scale 1.0 | 40 m² | ALBERO_pale, BIELLA_1, BIELLA_2 | 0.12 / 0.041 / 0.034 / 0.008 | tec_m08_1, tec_m08_2 |
| tec_m10 | strisce_pericolo | ambienti_tecnici/texture/PaintedMetal016_Color.jpg + ambienti_tecnici/texture/PaintedMetal016_NormalGL.jpg | uv 1.0 | normal_scale 1.0 | 23 m² | CAMERA_struttura, NICCHIA_1, NICCHIA_2 | 0.23 / 0.116 / 0.060 / 0.064 | tec_m10_1, tec_m10_2 |
| tec_m11 | vernice_rosso | ambienti_tecnici/texture/vernice_rosso_Color.jpg + ambienti_tecnici/texture/PaintedMetal006_NormalGL.jpg | uv 1.0 | normal_scale 1.0 | 21 m² | POMPA_2, SALA_arredo, SALA_meccanismi | 0.04 / 0.019 / 0.020 / 0.057 | tec_m11_1 |
| tec_m12 | ruggine | ambienti_tecnici/texture/Rust004_Color.jpg + ambienti_tecnici/texture/Rust004_NormalGL.jpg | uv 1.0 | normal_scale 1.0 | 10 m² | ALBERO_pale, CAMERA_bocchette, NICCHIA_1 | 0.02 / 0.011 / 0.011 / 0.063 | tec_m12_1, tec_m12_2 |

### Risalita (fiume, zona del personale, infermeria)

| # | Materiale | Texture | Scala | Normal | Muro | Dove | Carico (contrasto / dettaglio / grana / rilievo) | Scatti |
|---|---|---|---|---|---|---|---|---|
| ris_m01 | wet_surface (cemento) | fiume_lento/texture/cemento_col.jpg + fiume_lento/texture/cemento_nrm.jpg | uv_scale 0.35 triplanare | normal_strength <null> | 5261 m² | @MeshInstance3D@289, @MeshInstance3D@317, @MeshInstance3D@319 | 0.02 / 0.009 / 0.011 / 0.079 | ris_m01_1, ris_m01_2 |
| ris_m02 | wet_surface (roccia_ocra) | fiume_lento/texture/roccia_ocra_col.jpg + fiume_lento/texture/roccia_ocra_nrm.jpg | uv_scale 0.3 triplanare | normal_strength 1.6 | 2179 m² | Mesh_0, Mesh_0, Mesh_0 | 0.09 / 0.038 / 0.034 / 0.183 | nessun punto libero |
| ris_m03 | StandardMaterial3D | ambienti_tecnici/texture/MetalPlates013_Color.jpg + ambienti_tecnici/texture/MetalPlates013_NormalGL.jpg | uv 0.5 triplanare | normal_scale 1.0 | 581 m² | @MeshInstance3D@36, @MeshInstance3D@40, @MeshInstance3D@49 | 0.04 / 0.019 / 0.017 / 0.063 | ris_m03_1, ris_m03_2 |
| ris_m04 | wet_surface (mosaico_blu) | fiume_lento/texture/mosaico_blu_col.jpg + fiume_lento/texture/mosaico_blu_nrm.jpg | uv_scale 1.6 triplanare | normal_strength <null> | 356 m² | @MeshInstance3D@291, @MeshInstance3D@294 | 0.04 / 0.016 / 0.007 / 0.06 | ris_m04_1, ris_m04_2 |
| ris_m05 | StandardMaterial3D | ambienti_tecnici/texture/Concrete042C_Color.jpg + ambienti_tecnici/texture/Concrete042C_NormalGL.jpg | uv 0.4 triplanare | normal_scale 1.0 | 284 m² | @MeshInstance3D@32, @MeshInstance3D@34, @MeshInstance3D@38 | 0.05 / 0.029 / 0.016 / 0.07 | ris_m05_1, ris_m05_2 |
| ris_m06 | StandardMaterial3D | infermeria/texture/intonaco_col.jpg + infermeria/texture/intonaco_nrm.jpg | uv 0.4 triplanare | normal_scale 1.0 | 81 m² | @MeshInstance3D@677, @MeshInstance3D@680, @MeshInstance3D@683 | 0.04 / 0.020 / 0.017 / 0.087 | ris_m06_1, ris_m06_2 |
| ris_m07 | StandardMaterial3D | infermeria/texture/piastrelle_piccole_col.jpg + infermeria/texture/piastrelle_piccole_nrm.jpg | uv 1.2 triplanare | normal_scale 1.0 | 74 m² | @MeshInstance3D@679, @MeshInstance3D@682, @MeshInstance3D@697 | 0.07 / 0.031 / 0.043 / 0.085 | ris_m07_1, ris_m07_2 |

### Torre e sala dell'inseguimento

| # | Materiale | Texture | Scala | Normal | Muro | Dove | Carico (contrasto / dettaglio / grana / rilievo) | Scatti |
|---|---|---|---|---|---|---|---|---|
| tor_m01 | M_amb_metallo_grigio | ambiente/inseguimento/inseguimento_struttura_metallo_grigio_col.jpg + ambiente/inseguimento/inseguimento_struttura_metallo_verniciato_nrm.jpg | uv 1.0 | normal_scale 1.0 | 2310 m² | ins_A_struttura | 0.07 / 0.030 / 0.025 / 0.048 | tor_m01_1, tor_m01_2 |
| tor_m02 | M_amb_metallo | ambiente/inseguimento/inseguimento_struttura_metallo_col.jpg + ambiente/inseguimento/inseguimento_struttura_metallo_verniciato_nrm.jpg | uv 1.0 | normal_scale 1.0 | 710 m² | ins_A_collare, ins_A_struttura | 0.05 / 0.020 / 0.019 / 0.048 | tor_m02_1, tor_m02_2 |
| tor_m03 | M_amb_metallo_grigio | ambiente/torre/torre_struttura_metallo_grigio_col.jpg + ambiente/torre/torre_struttura_metallo_verniciato_nrm.jpg | uv 1.0 | normal_scale 1.0 | 552 m² | torre_A, torre_A_travi | 0.07 / 0.030 / 0.025 / 0.048 | tor_m03_1, tor_m03_2 |
| tor_m05 | M_amb_vasca | ambiente/inseguimento/inseguimento_struttura_vasca_col.jpg + ambiente/inseguimento/inseguimento_struttura_piastrelle_turchesi_nrm.jpg | uv 1.0 | normal_scale 1.6 | 330 m² | ins_A_struttura | 0.09 / 0.047 / 0.041 / 0.065 | tor_m05_1, tor_m05_2 |
| tor_m06 | M_amb_vasca_bimbi | ambiente/inseguimento/inseguimento_struttura_vasca_bimbi_col.jpg + ambiente/inseguimento/inseguimento_struttura_piastrelle_turchesi_nrm.jpg | uv 1.0 | normal_scale 1.6 | 315 m² | ins_A_struttura | 0.08 / 0.037 / 0.034 / 0.065 | tor_m06_1, tor_m06_2 |
| tor_m08 | M_amb_metallo | ambiente/torre/torre_struttura_metallo_col.jpg + ambiente/torre/torre_struttura_metallo_verniciato_nrm.jpg | uv 1.0 | normal_scale 1.0 | 227 m² | torre_A, torre_A_scalette, torre_A_sostegni | 0.05 / 0.020 / 0.019 / 0.048 | tor_m08_1, tor_m08_2 |
| tor_m09 | M_amb_vasca_bimbi | ambiente/torre/torre_struttura_vasca_bimbi_col.jpg + ambiente/torre/torre_struttura_piastrelle_turchesi_nrm.jpg | uv 1.0 | normal_scale 1.6 | 226 m² | torre_A | 0.08 / 0.037 / 0.034 / 0.065 | tor_m09_1, tor_m09_2 |
| tor_m13 | M_amb_vasca | ambiente/torre/torre_struttura_vasca_col.jpg + ambiente/torre/torre_struttura_piastrelle_turchesi_nrm.jpg | uv 1.0 | normal_scale 1.6 | 94 m² | torre_A | 0.09 / 0.047 / 0.041 / 0.065 | tor_m13_1, tor_m13_2 |
| tor_m18 | M_amb_cemento | ambiente/torre/torre_struttura_cemento_col.jpg + ambiente/torre/torre_struttura_cemento_nrm.jpg | uv 1.0 | normal_scale 1.0 | 28 m² | torre_A | 0.05 / 0.029 / 0.016 / 0.077 | tor_m18_1, tor_m18_2 |
| tor_m30 | M_amb_cemento | ambiente/inseguimento/inseguimento_struttura_cemento_col.jpg + ambiente/inseguimento/inseguimento_struttura_cemento_nrm.jpg | uv 1.0 | normal_scale 1.0 | 11 m² | ins_A_struttura | 0.05 / 0.029 / 0.016 / 0.077 | tor_m30_1, tor_m30_2 |

### Sala (pareti, cupola, piscina, area bimbi)

| # | Materiale | Texture | Scala | Normal | Muro | Dove | Carico (contrasto / dettaglio / grana / rilievo) | Scatti |
|---|---|---|---|---|---|---|---|---|
| sal_m01 | wet_surface (M_amb_intonaco_alto_bagnato) | ambiente/sala/sala_architettura_intonaco_alto_col.jpg + ambiente/sala/sala_architettura_intonaco_scrostato_nrm.jpg | uv_scale 1.0, uv1 (1.0, 1.0) | normal_strength 1.0 | 2722 m² | sala_pareti_alte, sala_soffitto | 0.02 / 0.011 / 0.010 / 0.057 | sal_m01_1, sal_m01_2 |
| sal_m02 | wet_surface (M_amb_intonaco_bagnato) | ambiente/sala/sala_architettura_intonaco_col.jpg + ambiente/sala/sala_architettura_intonaco_scrostato_nrm.jpg | uv_scale 1.0, uv1 (1.0, 1.0) | normal_strength 1.0 | 1072 m² | sala_pareti_basse | 0.02 / 0.013 / 0.013 / 0.057 | sal_m02_1, sal_m02_2 |
| sal_m03 | wet_surface (M_amb_ferro_cupola_bagnato) | ambiente/sala/sala_architettura_ferro_cupola_col.jpg + ambiente/sala/sala_architettura_metallo_verniciato_nrm.jpg | uv_scale 1.0, uv1 (1.0, 1.0) | normal_strength 1.0 | 456 m² | sala_soffitto_travi | 0.02 / 0.010 / 0.012 / 0.048 | sal_m03_1 |
| sal_m05 | wet_surface (M_amb_parete_bagnato) | ambiente/sala/sala_architettura_parete_col.jpg + ambiente/sala/sala_architettura_piastrelle_bianche_nrm.jpg | uv_scale 1.0, uv1 (1.0, 1.0) | normal_strength 1.60000002384186 | 217 m² | sala_pareti_basse | 0.12 / 0.068 / 0.050 / 0.096 | sal_m05_1, sal_m05_2 |
| sal_m06 | M_amb_decal_colatura | ambiente/sala/sala_architettura_colatura_col.png | uv 1.0 | - | 77 m² | sala_colature | 0.01 / 0.006 / 0.010 / None | sal_m06_1, sal_m06_2 |
| sal_m07 | wet_surface (M_amb_cemento_bagnato) | ambiente/sala/sala_architettura_cemento_col.jpg + ambiente/sala/sala_architettura_cemento_nrm.jpg | uv_scale 1.0, uv1 (1.0, 1.0) | normal_strength 1.0 | 76 m² | sala_torre_guscio | 0.05 / 0.029 / 0.016 / 0.077 | sal_m07_1, sal_m07_2 |
| sal_m08 | wet_surface (M_amb_vasca_bagnato) | ambiente/sala/sala_piscina_vasca_col.jpg + ambiente/sala/sala_piscina_piastrelle_turchesi_nrm.jpg | uv_scale 1.0, uv1 (1.0, 1.0) | normal_strength 1.60000002384186 | 68 m² | sala_piscina_onde | 0.09 / 0.047 / 0.041 / 0.065 | sal_m08_1, sal_m08_2 |
| sal_m09 | wet_surface (M_amb_metallo_bagnato) | ambiente/sala/sala_architettura_metallo_col.jpg + ambiente/sala/sala_architettura_metallo_verniciato_nrm.jpg | uv_scale 1.0, uv1 (1.0, 1.0) | normal_strength 1.0 | 54 m² | sala_altoparlanti, sala_pareti_alte, sala_pareti_basse | 0.05 / 0.020 / 0.019 / 0.048 | sal_m09_1, sal_m09_2 |
| sal_m10 | M_amb_metallo | ambiente/sala/sala_architettura_metallo_col.jpg + ambiente/sala/sala_architettura_metallo_verniciato_nrm.jpg | uv 1.0 | normal_scale 1.0 | 49 m² | sala_cartellone_mascotte_0, sala_cartellone_mascotte_1, sala_cartellone_n0 | 0.05 / 0.020 / 0.019 / 0.048 | sal_m10_1, sal_m10_2 |
| sal_m12 | wet_surface (M_amb_fascia_bagnato) | ambiente/sala/sala_architettura_fascia_col.jpg + ambiente/sala/sala_architettura_piastrelle_bianche_nrm.jpg | uv_scale 1.0, uv1 (1.0, 1.0) | normal_strength 1.60000002384186 | 40 m² | sala_pareti_basse | 0.07 / 0.037 / 0.036 / 0.096 | sal_m12_1, sal_m12_2 |
| sal_m13 | wet_surface (M_amb_vasca_bagnato) | ambiente/sala/sala_torre_scivoli_vasca_col.jpg + ambiente/sala/sala_torre_scivoli_piastrelle_turchesi_nrm.jpg | uv_scale 1.0, uv1 (1.0, 1.0) | normal_strength 1.60000002384186 | 36 m² | arrivo_bordi, sala_vasca_arrivo_fondo | 0.09 / 0.047 / 0.041 / 0.065 | sal_m13_1, sal_m13_2 |
| sal_m14 | wet_surface (M_amb_scacchi_bagnato) | ambiente/sala/sala_area_bimbi_scacchi_col.jpg + ambiente/sala/sala_area_bimbi_piastrelle_bianche_nrm.jpg | uv_scale 1.0, uv1 (1.0, 1.0) | normal_strength 1.60000002384186 | 32 m² | sala_fossa_bimbi, sala_vasca_bimbi_1, sala_vasca_bimbi_2 | 0.27 / 0.110 / 0.059 / 0.096 | sal_m14_1, sal_m14_2 |
| sal_m16 | wet_surface (M_amb_bordo_bagnato) | ambiente/sala/sala_piscina_bordo_col.jpg + ambiente/sala/sala_piscina_piastrelle_bianche_nrm.jpg | uv_scale 1.0, uv1 (1.0, 1.0) | normal_strength 1.60000002384186 | 26 m² | piscina_bordi | 0.11 / 0.062 / 0.044 / 0.096 | sal_m16_1, sal_m16_2 |
| sal_m17 | wet_surface (M_amb_cemento_bagnato) | ambiente/sala/sala_area_bimbi_cemento_col.jpg + ambiente/sala/sala_area_bimbi_cemento_nrm.jpg | uv_scale 1.0, uv1 (1.0, 1.0) | normal_strength 1.0 | 22 m² | sala_fossa_bimbi | 0.05 / 0.029 / 0.016 / 0.077 | sal_m17_1 |
| sal_m18 | wet_surface (M_amb_bordo_bagnato) | ambiente/sala/sala_torre_scivoli_bordo_col.jpg + ambiente/sala/sala_torre_scivoli_piastrelle_bianche_nrm.jpg | uv_scale 1.0, uv1 (1.0, 1.0) | normal_strength 1.60000002384186 | 14 m² | arrivo_bordi | 0.11 / 0.062 / 0.044 / 0.096 | sal_m18_1, sal_m18_2 |
| sal_m19 | wet_surface (M_sala_struttura_gioco_bagnato) | ambiente/sala/sala_area_bimbi_sala_struttura_gioco_0.jpg + ambiente/sala/sala_area_bimbi_sala_struttura_gioco_2.jpg | uv_scale 1.0, uv1 (1.0, 1.0) | normal_strength 1.0 | 14 m² | sala_struttura_gioco | 0.17 / 0.092 / 0.076 / 0.125 | sal_m19_1, sal_m19_2 |
| sal_m21 | M_amb_vasca_alta | ambiente/sala/sala_vasca_centrale_vasca_alta_col.jpg + ambiente/sala/sala_vasca_centrale_piastrelle_bianche_nrm.jpg | uv 1.0 | normal_scale 1.8 | 13 m² | sala_vasca_centrale | 0.28 / 0.116 / 0.065 / 0.096 | sal_m21_1, sal_m21_2 |

Nota: il "cemento" degli interni (`ambienti_interni/texture/cemento_col.jpg`, n. 5 del foglio) è solo nel corridoio,
in un ribassamento del pavimento di 3 × 1,4 m (x 16-19, z 0-1,4 nella scena degli interni, 20 cm sotto il pavimento):
1,8 m² di bordi e 8,4 m² di fondo. Il pavimento a chiazze del corridoio è un altro materiale.

### Macchie, colature e decal

| # | Zona | Texture | Tipo | Quante | Sui muri | Grandezza (la più grande) | Coprenza | Area totale | Scatti |
|---|---|---|---|---|---|---|---|---|---|
| mac_int_k01 | Interni | ambienti_interni/shader_tex/decal_crepa.png | decal | 5 | 5 | 0.9 × 0.9 m | 0.9 | 3.6 m² | mac_int_k01_1, mac_int_k01_2 |
| mac_int_k02 | Interni | ambienti_interni/shader_tex/decal_macchia.png | decal | 8 | 0 | 1.6 × 1.6 m | 0.7 | 17.8 m² | mac_int_k02_1, mac_int_k02_2 |
| mac_int_k03 | Interni | ambienti_interni/shader_tex/decal_ruggine.png | decal | 14 | 14 | 0.6 × 1.3 m | 0.8 | 9.0 m² | mac_int_k03_1, mac_int_k03_2 |
| mac_int_k04 | Interni | ambienti_interni/texture/ruggine_col.jpg | modello | 3 | 1 | 17.94 × 12.85 m | 1.0 | 428.5 m² | mac_int_k04_1, mac_int_k04_2 |
| mac_tec_k01 | Tecnici | ambienti_interni/shader_tex/decal_crepa.png | decal | 5 | 5 | 1.0 × 1.0 m | 0.9 | 5.0 m² | mac_tec_k01_1, mac_tec_k01_2 |
| mac_tec_k02 | Tecnici | ambienti_interni/shader_tex/decal_macchia.png | decal | 16 | 0 | 2.2 × 2.2 m | 0.7 | 48.1 m² | mac_tec_k02_1, mac_tec_k02_2 |
| mac_tec_k03 | Tecnici | ambienti_interni/shader_tex/decal_ruggine.png | decal | 14 | 14 | 0.8 × 1.8 m | 0.8 | 16.7 m² | mac_tec_k03_1, mac_tec_k03_2 |
| mac_tec_k04 | Tecnici | ambienti_tecnici/texture/Rust004_Color.jpg | modello | 15 | 11 | 33.65 × 25.15 m | 1.0 | 1304.6 m² | mac_tec_k04_1, mac_tec_k04_2 |
| mac_tor_k01 | Torre | ambienti_tecnici/texture/Rust004_Color.jpg | modello | 3 | 3 | 5.06 × 3.9 m | 1.0 | 59.2 m² | mac_tor_k01_1, mac_tor_k01_2 |
| mac_sal_k01 | Sala principale | ambiente/dettagli/gltf/texture/macchia_alghe_secche_col.png | modello | 6 | 0 | 1.72 × 1.64 m | 1.0 | 13.3 m² | mac_sal_k01_1, mac_sal_k01_2 |
| mac_sal_k02 | Sala principale | ambiente/dettagli/gltf/texture/macchia_alghe_verdi_col.png | modello | 44 | 34 | 1.57 × 1.56 m | 1.0 | 79.8 m² | mac_sal_k02_1, mac_sal_k02_2 |
| mac_sal_k03 | Sala principale | ambiente/dettagli/gltf/texture/macchia_calcare_col.png | modello | 100 | 57 | 1.41 × 1.41 m | 1.0 | 34.6 m² | mac_sal_k03_1, mac_sal_k03_2 |
| mac_sal_k04 | Sala principale | ambiente/dettagli/gltf/texture/macchia_muffa_col.png | modello | 20 | 20 | 1.0 × 0.8 m | 1.0 | 16.0 m² | mac_sal_k04_1, mac_sal_k04_2 |
| mac_sal_k05 | Sala principale | ambiente/dettagli/gltf/texture/macchia_ruggine_colata_col.png | modello | 36 | 36 | 1.2 × 0.35 m | 1.0 | 15.1 m² | mac_sal_k05_1, mac_sal_k05_2 |
| mac_sal_k06 | Sala principale | ambiente/sala/sala_architettura_colatura_col.png | modello | 1 | 1 | 41.63 × 39.98 m | 1.0 | 1664.2 m² | - |
| mac_sal_k07 | Sala principale | ambiente/sala/sala_vasca_centrale_linea_calcare_col.png | modello | 1 | 1 | 5.4 × 3.9 m | 1.0 | 21.0 m² | mac_sal_k07_1 |

Note sulle macchie:
- `mac_int_k04` e `mac_tec_k04`/`mac_tor_k01` non sono macchie ma i modelli con la ruggine come materiale (le aree
  sono quelle dei riquadri dei modelli, non della ruggine): la ruggine vera è nelle tabelle dei muri (`int_m11`
  10 m², `tec_m12` 10 m², le pompe della torre).
- `mac_sal_k06` è la mesh delle colature della sala (`sal_m06`, 77 m² di colature vere sui muri; l'area in tabella
  è il riquadro della mesh).
- Le macchie di ruggine più visibili sui muri dei tecnici non sono decal: sono la "scrostatura" dello shader
  `parete.gdshader` (la ruggine `ruggine_col` che esce da sotto la vernice, 0,15 su 1829 m² di MetalPlates013) e le
  colature procedurali dello stesso shader (`intensita_colature` 0,7, `sporco_basso` 0,75), su tutti i muri di
  interni e tecnici.
- La risalita non ha né decal né macchie.

## Fogli e dati

- `foglio_interni.jpg`, `foglio_tecnici.jpg`, `foglio_risalita.jpg`, `foglio_torre.jpg`: un muro per riquadro, nella
  luce del gioco; `foglio_tec_n.jpg`: i tecnici in luce neutra. La sala principale è nel foglio delle macchie della
  proposta (`docs/proposte/texture_muri/foglio_macchie_sala.jpg`).
- `riassunto.json`: tutti i materiali di tutte le zone, dal più esteso; `elenco_muri.json`: i 50 materiali dei muri con
  le loro vedute; `macchie_<zona>.json`: le macchie zona per zona, con le posizioni.
