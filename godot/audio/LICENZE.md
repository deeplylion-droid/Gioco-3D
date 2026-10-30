# Suoni di Jilly Jubilee: fonti e licenze

Tutti i suoni di questa cartella sono **generati dagli script** in `assets_src/audio/` (`python genera_tutto.py` con il venv di Blender: numpy, scipy e ffmpeg). Sono di due tipi:

- **Sintesi procedurale** scritta per questo gioco (rumori filtrati, sintesi modale, bolle, riverbero a convoluzione con risposte all'impulso sintetiche, ecc.). Nessun campione esterno.
- **Campioni CC0 di Kenney** (www.kenney.nl) rielaborati: filtrati, trasposti, rallentati, sovrapposti a parti sintetiche. Licenza **Creative Commons Zero 1.0** (pubblico dominio): uso libero anche commerciale, il credito non è obbligatorio ma lo diamo volentieri.

La **sigla della mascotte** (`musica/sigla_pulita.ogg`, `musica/sigla_rovinata.ogg`) è una melodia originale con arrangiamento originale (carillon, organetto, percussioni giocattolo), scritta nota per nota in `assets_src/audio/genera_musica.py`. Anche gli stinger sono originali.

Niente da freesound, niente modelli generativi.

## Pacchetti Kenney usati (CC0)

| Pacchetto | Pagina | File usati |
|---|---|---|
| Impact Sounds | https://kenney.nl/assets/impact-sounds | footstep_concrete_000-004, impactMetal_light_000-004, impactMetal_heavy_000-004, impactPlate_light_000-004, impactSoft_medium_000-004 |
| RPG Audio | https://kenney.nl/assets/rpg-audio | creak1-3, doorClose_1-4, cloth1-2, clothBelt, metalLatch |
| Interface Sounds | https://kenney.nl/assets/interface-sounds | click_001, tick_002, toggle_002, switch_002, open_002, close_002 |
| Sci-Fi Sounds | https://kenney.nl/assets/sci-fi-sounds | lowFrequency_explosion_000-001, slime_000-001 |

I file originali usati sono copiati in `assets_src/audio/sorgenti/kenney/` con le licenze (46 file).

## Elenco dei file

| File | Durata | Origine | Note |
|---|---|---|---|
| `ambiente/goccia_acqua_01.ogg` | 0.5 s | sintesi (originale) |  |
| `ambiente/goccia_acqua_02.ogg` | 0.5 s | sintesi (originale) |  |
| `ambiente/goccia_acqua_03.ogg` | 0.5 s | sintesi (originale) |  |
| `ambiente/goccia_acqua_04.ogg` | 0.5 s | sintesi (originale) |  |
| `ambiente/goccia_acqua_05.ogg` | 0.5 s | sintesi (originale) |  |
| `ambiente/goccia_acqua_06.ogg` | 0.5 s | sintesi (originale) |  |
| `ambiente/goccia_pavimento_01.ogg` | 0.3 s | sintesi (originale) |  |
| `ambiente/goccia_pavimento_02.ogg` | 0.3 s | sintesi (originale) |  |
| `ambiente/goccia_pavimento_03.ogg` | 0.3 s | sintesi (originale) |  |
| `ambiente/goccia_pavimento_04.ogg` | 0.3 s | sintesi (originale) |  |
| `ambiente/inseguimento_colpo_01.ogg` | 1.6 s | sintesi (originale) | tunnel, inseguimento (25 ottobre sera): colpo di tamburo lontano nello scafo, più fitti quando lei è vicina |
| `ambiente/inseguimento_colpo_02.ogg` | 1.6 s | sintesi (originale) | tunnel, inseguimento (25 ottobre sera): colpo di tamburo lontano nello scafo, più fitti quando lei è vicina |
| `ambiente/inseguimento_colpo_03.ogg` | 1.6 s | sintesi (originale) | tunnel, inseguimento (25 ottobre sera): colpo di tamburo lontano nello scafo, più fitti quando lei è vicina |
| `ambiente/inseguimento_colpo_04.ogg` | 1.6 s | sintesi (originale) | tunnel, inseguimento (25 ottobre sera): colpo di tamburo lontano nello scafo, più fitti quando lei è vicina |
| `ambiente/inseguimento_colpo_05.ogg` | 1.6 s | sintesi (originale) | tunnel, inseguimento (25 ottobre sera): colpo di tamburo lontano nello scafo, più fitti quando lei è vicina |
| `ambiente/inseguimento_colpo_06.ogg` | 1.6 s | sintesi (originale) | tunnel, inseguimento (25 ottobre sera): colpo di tamburo lontano nello scafo, più fitti quando lei è vicina |
| `ambiente/nave_colpo_lontano_01.ogg` | 5.5 s | Kenney Impact Sounds + RPG Audio (CC0), rielaborati |  |
| `ambiente/nave_colpo_lontano_02.ogg` | 5.5 s | Kenney Impact Sounds + RPG Audio (CC0), rielaborati |  |
| `ambiente/nave_colpo_lontano_03.ogg` | 5.5 s | Kenney Impact Sounds + RPG Audio (CC0), rielaborati |  |
| `ambiente/nave_gemito_01.ogg` | 8.7 s | sintesi + Kenney RPG Audio (CC0) | creak rallentato e lamiera sintetica |
| `ambiente/nave_gemito_02.ogg` | 8.4 s | sintesi + Kenney RPG Audio (CC0) | creak rallentato e lamiera sintetica |
| `ambiente/nave_gemito_03.ogg` | 7.8 s | sintesi + Kenney RPG Audio (CC0) | creak rallentato e lamiera sintetica |
| `ambiente/nave_gemito_04.ogg` | 6.8 s | sintesi + Kenney RPG Audio (CC0) | creak rallentato e lamiera sintetica |
| `ambiente/nave_loop.ogg` | 40.0 s | sintesi (originale) | ronzio elettrico a 50 Hz, macchine lontane, onde contro lo scafo |
| `ambiente/nave_scricchiolio_01.ogg` | 3.8 s | Kenney RPG Audio (CC0), rielaborato |  |
| `ambiente/nave_scricchiolio_02.ogg` | 4.0 s | Kenney RPG Audio (CC0), rielaborato |  |
| `ambiente/nave_scricchiolio_03.ogg` | 3.0 s | Kenney RPG Audio (CC0), rielaborato |  |
| `ambiente/nave_tic_01.ogg` | 2.6 s | sintesi (originale) |  |
| `ambiente/nave_tic_02.ogg` | 2.6 s | sintesi (originale) |  |
| `ambiente/nave_tic_03.ogg` | 2.6 s | sintesi (originale) |  |
| `ambiente/pioggia_cupola_loop.ogg` | 40.0 s | sintesi (originale) | pioggia battente sulla cupola di vetro sentita dalla sala (senza le bollicine dei rivoli dal 16 ottobre) |
| `ambiente/sirena_lontana_01.ogg` | 10.8 s | sintesi (originale) |  |
| `ambiente/sirena_lontana_02.ogg` | 9.8 s | sintesi (originale) |  |
| `ambiente/sottacqua_loop.ogg` | 16.0 s | sintesi (originale) | fondo ovattato sott'acqua |
| `ambiente/tuono_lontano_01.ogg` | 9.3 s | sintesi + Kenney Sci-Fi Sounds (CC0) | lowFrequency_explosion come sub |
| `ambiente/tuono_lontano_02.ogg` | 10.6 s | sintesi + Kenney Sci-Fi Sounds (CC0) | lowFrequency_explosion come sub |
| `ambiente/tuono_lontano_03.ogg` | 11.8 s | sintesi + Kenney Sci-Fi Sounds (CC0) | lowFrequency_explosion come sub |
| `ambiente/tuono_vicino_01.ogg` | 8.8 s | sintesi + Kenney Sci-Fi Sounds (CC0) | lowFrequency_explosion come sub |
| `ambiente/tuono_vicino_02.ogg` | 8.5 s | sintesi + Kenney Sci-Fi Sounds (CC0) | lowFrequency_explosion come sub |
| `ambiente/tuono_vicino_03.ogg` | 7.5 s | sintesi + Kenney Sci-Fi Sounds (CC0) | lowFrequency_explosion come sub |
| `ambiente/vento_loop.ogg` | 45.0 s | sintesi (originale) | vento e ululati fuori dalla cupola |
| `effetti/cancello_fine.ogg` | 0.8 s | Kenney Impact Sounds + RPG Audio (CC0), rielaborati |  |
| `effetti/cancello_ruota.ogg` | 5.0 s | Kenney RPG Audio (CC0), rielaborato |  |
| `effetti/emergenza_ronzio_loop.ogg` | 4.0 s | sintesi (originale) |  |
| `effetti/emergenza_rotante_loop.ogg` | 3.6 s | sintesi (originale) |  |
| `effetti/faro_acceso.ogg` | 3.0 s | sintesi (originale) |  |
| `effetti/faro_ronzio_loop.ogg` | 3.0 s | sintesi (originale) |  |
| `effetti/gonfiabile_colpito.ogg` | 0.3 s | sintesi (originale) |  |
| `effetti/gonfiabile_libero.ogg` | 2.2 s | sintesi (originale) |  |
| `effetti/medusa_presenza_loop.ogg` | 8.0 s | sintesi + Kenney Sci-Fi Sounds (CC0) | slime rallentato |
| `effetti/medusa_risveglio.ogg` | 4.5 s | sintesi + Kenney Sci-Fi Sounds (CC0) | slime rallentato |
| `effetti/neon_clic_01.ogg` | 0.1 s | sintesi (originale) |  |
| `effetti/neon_clic_02.ogg` | 0.1 s | sintesi (originale) |  |
| `effetti/neon_clic_03.ogg` | 0.1 s | sintesi (originale) |  |
| `effetti/neon_ronzio_loop.ogg` | 3.0 s | sintesi (originale) |  |
| `effetti/neon_scintilla_01.ogg` | 0.4 s | sintesi (originale) |  |
| `effetti/neon_scintilla_02.ogg` | 0.5 s | sintesi (originale) |  |
| `effetti/neon_scintilla_03.ogg` | 0.5 s | sintesi (originale) |  |
| `effetti/porta_aperta.ogg` | 0.8 s | Kenney Impact Sounds + RPG Audio (CC0), rielaborati |  |
| `effetti/porta_chiusa.ogg` | 0.9 s | Kenney Impact Sounds + RPG Audio (CC0), rielaborati |  |
| `effetti/porta_motore_loop.ogg` | 2.0 s | sintesi (originale) |  |
| `effetti/portello_apre.ogg` | 3.2 s | Kenney RPG Audio + Impact Sounds (CC0), rielaborati |  |
| `effetti/pulsante_premuto.ogg` | 1.0 s | sintesi (originale) |  |
| `effetti/pulsante_rilasciato.ogg` | 0.2 s | sintesi (originale) |  |
| `effetti/quadro_scintille.ogg` | 2.2 s | sintesi (originale) |  |
| `effetti/riempie_loop.ogg` | 3.0 s | sintesi (originale) |  |
| `effetti/ruota_pale_loop.ogg` | 2.4 s | sintesi (originale) |  |
| `effetti/saracinesca_fine.ogg` | 1.0 s | Kenney Impact Sounds + RPG Audio (CC0), rielaborati |  |
| `effetti/saracinesca_loop.ogg` | 2.0 s | sintesi (originale) |  |
| `effetti/scarico_loop.ogg` | 4.0 s | sintesi (originale) |  |
| `effetti/scivolo_loop.ogg` | 3.0 s | sintesi (originale) |  |
| `effetti/secchio_ribalta.ogg` | 4.5 s | sintesi + Kenney RPG Audio (CC0) |  |
| `effetti/secchio_ritorno.ogg` | 3.0 s | Kenney RPG Audio (CC0), rielaborato |  |
| `effetti/turbina_bloccata.ogg` | 0.6 s | sintesi (originale) |  |
| `effetti/turbina_loop.ogg` | 2.0 s | sintesi (originale) |  |
| `effetti/vasca_svuotata.ogg` | 2.8 s | sintesi (originale) |  |
| `giocatore/atterraggio_acqua_01.ogg` | 0.7 s | Kenney Impact Sounds (CC0), rielaborati + sintesi |  |
| `giocatore/atterraggio_acqua_02.ogg` | 0.6 s | Kenney Impact Sounds (CC0), rielaborati + sintesi |  |
| `giocatore/atterraggio_bagnato_01.ogg` | 0.5 s | sintesi (originale) | scarpe di gomma: tonfo morbido e smorzato, senza tic (scelta A dell'utente, 30 ottobre; assets_src/passi/genera_passi.py) |
| `giocatore/atterraggio_bagnato_02.ogg` | 0.5 s | sintesi (originale) | scarpe di gomma: tonfo morbido e smorzato, senza tic (scelta A dell'utente, 30 ottobre; assets_src/passi/genera_passi.py) |
| `giocatore/atterraggio_metallo_01.ogg` | 0.6 s | sintesi (originale) | scarpe di gomma: tonfo morbido e smorzato, senza tic (scelta A dell'utente, 30 ottobre; assets_src/passi/genera_passi.py) |
| `giocatore/atterraggio_metallo_02.ogg` | 0.6 s | sintesi (originale) | scarpe di gomma: tonfo morbido e smorzato, senza tic (scelta A dell'utente, 30 ottobre; assets_src/passi/genera_passi.py) |
| `giocatore/atterraggio_piastrelle_01.ogg` | 0.5 s | sintesi (originale) | scarpe di gomma: tonfo morbido e smorzato, senza tic (scelta A dell'utente, 30 ottobre; assets_src/passi/genera_passi.py) |
| `giocatore/atterraggio_piastrelle_02.ogg` | 0.5 s | sintesi (originale) | scarpe di gomma: tonfo morbido e smorzato, senza tic (scelta A dell'utente, 30 ottobre; assets_src/passi/genera_passi.py) |
| `giocatore/cuore_battito_01.ogg` | 0.8 s | sintesi (originale) | tunnel, inseguimento (25 ottobre sera): il battito del cuore, uno alla volta col tempo che segue lei |
| `giocatore/cuore_battito_02.ogg` | 0.8 s | sintesi (originale) | tunnel, inseguimento (25 ottobre sera): il battito del cuore, uno alla volta col tempo che segue lei |
| `giocatore/cuore_battito_03.ogg` | 0.8 s | sintesi (originale) | tunnel, inseguimento (25 ottobre sera): il battito del cuore, uno alla volta col tempo che segue lei |
| `giocatore/cuore_battito_04.ogg` | 0.8 s | sintesi (originale) | tunnel, inseguimento (25 ottobre sera): il battito del cuore, uno alla volta col tempo che segue lei |
| `giocatore/cuore_battito_05.ogg` | 0.8 s | sintesi (originale) | tunnel, inseguimento (25 ottobre sera): il battito del cuore, uno alla volta col tempo che segue lei |
| `giocatore/passo_acqua_01.ogg` | 0.8 s | sintesi (originale) |  |
| `giocatore/passo_acqua_02.ogg` | 0.8 s | sintesi (originale) |  |
| `giocatore/passo_acqua_03.ogg` | 0.8 s | sintesi (originale) |  |
| `giocatore/passo_acqua_04.ogg` | 0.8 s | sintesi (originale) |  |
| `giocatore/passo_acqua_05.ogg` | 0.8 s | sintesi (originale) |  |
| `giocatore/passo_acqua_06.ogg` | 0.8 s | sintesi (originale) |  |
| `giocatore/passo_bagnato_01.ogg` | 0.3 s | sintesi (originale) | scarpe di gomma: tonfo morbido e smorzato, senza tic (scelta A dell'utente, 30 ottobre; assets_src/passi/genera_passi.py) |
| `giocatore/passo_bagnato_02.ogg` | 0.3 s | sintesi (originale) | scarpe di gomma: tonfo morbido e smorzato, senza tic (scelta A dell'utente, 30 ottobre; assets_src/passi/genera_passi.py) |
| `giocatore/passo_bagnato_03.ogg` | 0.3 s | sintesi (originale) | scarpe di gomma: tonfo morbido e smorzato, senza tic (scelta A dell'utente, 30 ottobre; assets_src/passi/genera_passi.py) |
| `giocatore/passo_bagnato_04.ogg` | 0.3 s | sintesi (originale) | scarpe di gomma: tonfo morbido e smorzato, senza tic (scelta A dell'utente, 30 ottobre; assets_src/passi/genera_passi.py) |
| `giocatore/passo_bagnato_05.ogg` | 0.3 s | sintesi (originale) | scarpe di gomma: tonfo morbido e smorzato, senza tic (scelta A dell'utente, 30 ottobre; assets_src/passi/genera_passi.py) |
| `giocatore/passo_bagnato_06.ogg` | 0.3 s | sintesi (originale) | scarpe di gomma: tonfo morbido e smorzato, senza tic (scelta A dell'utente, 30 ottobre; assets_src/passi/genera_passi.py) |
| `giocatore/passo_metallo_01.ogg` | 0.4 s | sintesi (originale) | scarpe di gomma: tonfo morbido e smorzato, senza tic (scelta A dell'utente, 30 ottobre; assets_src/passi/genera_passi.py) |
| `giocatore/passo_metallo_02.ogg` | 0.4 s | sintesi (originale) | scarpe di gomma: tonfo morbido e smorzato, senza tic (scelta A dell'utente, 30 ottobre; assets_src/passi/genera_passi.py) |
| `giocatore/passo_metallo_03.ogg` | 0.4 s | sintesi (originale) | scarpe di gomma: tonfo morbido e smorzato, senza tic (scelta A dell'utente, 30 ottobre; assets_src/passi/genera_passi.py) |
| `giocatore/passo_metallo_04.ogg` | 0.4 s | sintesi (originale) | scarpe di gomma: tonfo morbido e smorzato, senza tic (scelta A dell'utente, 30 ottobre; assets_src/passi/genera_passi.py) |
| `giocatore/passo_metallo_05.ogg` | 0.4 s | sintesi (originale) | scarpe di gomma: tonfo morbido e smorzato, senza tic (scelta A dell'utente, 30 ottobre; assets_src/passi/genera_passi.py) |
| `giocatore/passo_metallo_06.ogg` | 0.4 s | sintesi (originale) | scarpe di gomma: tonfo morbido e smorzato, senza tic (scelta A dell'utente, 30 ottobre; assets_src/passi/genera_passi.py) |
| `giocatore/passo_piastrelle_01.ogg` | 0.3 s | sintesi (originale) | scarpe di gomma: tonfo morbido e smorzato, senza tic (scelta A dell'utente, 30 ottobre; assets_src/passi/genera_passi.py) |
| `giocatore/passo_piastrelle_02.ogg` | 0.3 s | sintesi (originale) | scarpe di gomma: tonfo morbido e smorzato, senza tic (scelta A dell'utente, 30 ottobre; assets_src/passi/genera_passi.py) |
| `giocatore/passo_piastrelle_03.ogg` | 0.3 s | sintesi (originale) | scarpe di gomma: tonfo morbido e smorzato, senza tic (scelta A dell'utente, 30 ottobre; assets_src/passi/genera_passi.py) |
| `giocatore/passo_piastrelle_04.ogg` | 0.3 s | sintesi (originale) | scarpe di gomma: tonfo morbido e smorzato, senza tic (scelta A dell'utente, 30 ottobre; assets_src/passi/genera_passi.py) |
| `giocatore/passo_piastrelle_05.ogg` | 0.3 s | sintesi (originale) | scarpe di gomma: tonfo morbido e smorzato, senza tic (scelta A dell'utente, 30 ottobre; assets_src/passi/genera_passi.py) |
| `giocatore/passo_piastrelle_06.ogg` | 0.3 s | sintesi (originale) | scarpe di gomma: tonfo morbido e smorzato, senza tic (scelta A dell'utente, 30 ottobre; assets_src/passi/genera_passi.py) |
| `giocatore/passo_scala_01.ogg` | 0.3 s | sintesi (originale) | scarpe di gomma: tonfo morbido e smorzato, senza tic (scelta A dell'utente, 30 ottobre; assets_src/passi/genera_passi.py) |
| `giocatore/passo_scala_02.ogg` | 0.3 s | sintesi (originale) | scarpe di gomma: tonfo morbido e smorzato, senza tic (scelta A dell'utente, 30 ottobre; assets_src/passi/genera_passi.py) |
| `giocatore/passo_scala_03.ogg` | 0.3 s | sintesi (originale) | scarpe di gomma: tonfo morbido e smorzato, senza tic (scelta A dell'utente, 30 ottobre; assets_src/passi/genera_passi.py) |
| `giocatore/passo_scala_04.ogg` | 0.3 s | sintesi (originale) | scarpe di gomma: tonfo morbido e smorzato, senza tic (scelta A dell'utente, 30 ottobre; assets_src/passi/genera_passi.py) |
| `giocatore/riemersione.ogg` | 1.4 s | sintesi (originale) |  |
| `giocatore/salto_01.ogg` | 0.3 s | Kenney RPG Audio (CC0) | cloth |
| `giocatore/salto_02.ogg` | 0.3 s | Kenney RPG Audio (CC0) | cloth |
| `giocatore/torcia_accesa.ogg` | 0.2 s | sintesi (originale) |  |
| `giocatore/torcia_spenta.ogg` | 0.2 s | sintesi (originale) |  |
| `giocatore/tuffo.ogg` | 1.6 s | sintesi (originale) |  |
| `giocatore/zaino_aspira_fine.ogg` | 0.7 s | sintesi (originale) |  |
| `giocatore/zaino_aspira_inizio.ogg` | 0.6 s | sintesi (originale) |  |
| `giocatore/zaino_aspira_loop.ogg` | 3.0 s | sintesi (originale) |  |
| `giocatore/zaino_getto_fine.ogg` | 0.7 s | sintesi (originale) |  |
| `giocatore/zaino_getto_inizio.ogg` | 0.5 s | sintesi (originale) |  |
| `giocatore/zaino_getto_loop.ogg` | 2.0 s | sintesi (originale) |  |
| `giocatore/zaino_impatto_acqua_loop.ogg` | 2.0 s | sintesi (originale) |  |
| `giocatore/zaino_impatto_loop.ogg` | 2.0 s | sintesi (originale) |  |
| `giocatore/zaino_pieno.ogg` | 1.1 s | sintesi (originale) |  |
| `giocatore/zaino_pompata.ogg` | 0.7 s | sintesi (originale) |  |
| `giocatore/zaino_preso.ogg` | 1.7 s | Kenney RPG Audio (CC0) + sintesi | cloth, clothBelt, metalLatch e pompate sintetiche |
| `giocatore/zaino_ricarica_loop.ogg` | 2.5 s | sintesi (originale) |  |
| `giocatore/zaino_sciabordio_01.ogg` | 0.8 s | sintesi (originale) |  |
| `giocatore/zaino_sciabordio_02.ogg` | 0.8 s | sintesi (originale) |  |
| `giocatore/zaino_sciabordio_03.ogg` | 0.8 s | sintesi (originale) |  |
| `giocatore/zaino_vuoto.ogg` | 0.9 s | sintesi (originale) |  |
| `interfaccia/ui_apri.ogg` | 0.4 s | Kenney Interface Sounds (CC0) | open_002 |
| `interfaccia/ui_chiudi.ogg` | 0.4 s | Kenney Interface Sounds (CC0) | close_002 |
| `interfaccia/ui_clic.ogg` | 0.1 s | Kenney Interface Sounds (CC0) | click_001 |
| `interfaccia/ui_cursore.ogg` | 0.0 s | Kenney Interface Sounds (CC0) | tick_002 |
| `interfaccia/ui_pausa.ogg` | 0.4 s | Kenney Interface Sounds (CC0) | switch_002 |
| `interfaccia/ui_scatto.ogg` | 0.1 s | Kenney Interface Sounds (CC0) | toggle_002 |
| `lei/fossa_ribolle_loop.ogg` | 5.0 s | sintesi (originale) | gorgoglio profondo e bolle grosse: la fossa che riempie le vasche basse |
| `lei/lei_insegue_grata_01.ogg` | 0.6 s | sintesi (originale) | inseguimento, voce (22 ottobre): un verso di rabbia per ogni colpo contro la grata |
| `lei/lei_insegue_grata_02.ogg` | 0.6 s | sintesi (originale) | inseguimento, voce (22 ottobre): un verso di rabbia per ogni colpo contro la grata |
| `lei/lei_insegue_grata_03.ogg` | 0.6 s | sintesi (originale) | inseguimento, voce (22 ottobre): un verso di rabbia per ogni colpo contro la grata |
| `lei/lei_insegue_presa_01.ogg` | 1.6 s | sintesi (originale) | inseguimento, voce (22 ottobre): ti afferra: risucchio, grido-ringhio, sotto la voce rotta del suo urlo |
| `lei/lei_insegue_presa_02.ogg` | 1.6 s | sintesi (originale) | inseguimento, voce (22 ottobre): ti afferra: risucchio, grido-ringhio, sotto la voce rotta del suo urlo |
| `lei/lei_insegue_respinta_01.ogg` | 1.4 s | sintesi (originale) | inseguimento, voce (22 ottobre): il getto in faccia: lamento che si spezza, gorgoglio mentre torna sotto |
| `lei/lei_insegue_respinta_02.ogg` | 1.4 s | sintesi (originale) | inseguimento, voce (22 ottobre): il getto in faccia: lamento che si spezza, gorgoglio mentre torna sotto |
| `lei/lei_insegue_respinta_03.ogg` | 1.4 s | sintesi (originale) | inseguimento, voce (22 ottobre): il getto in faccia: lamento che si spezza, gorgoglio mentre torna sotto |
| `lei/lei_insegue_sale_01.ogg` | 3.4 s | sintesi (originale) | inseguimento, voce (22 ottobre): sale dall'acqua e incombe: gola sott'acqua, fiato umido, ringhio che cresce |
| `lei/lei_insegue_sale_02.ogg` | 3.4 s | sintesi (originale) | inseguimento, voce (22 ottobre): sale dall'acqua e incombe: gola sott'acqua, fiato umido, ringhio che cresce |
| `lei/lei_insegue_sale_03.ogg` | 3.4 s | sintesi (originale) | inseguimento, voce (22 ottobre): sale dall'acqua e incombe: gola sott'acqua, fiato umido, ringhio che cresce |
| `lei/lei_insegue_sb1.ogg` | 5.4 s | sintesi (originale) | inseguimento, voce (22 ottobre): ti fissa dal pozzo SB1: fiato lento e umido, rantolo trattenuto |
| `lei/lei_sbuca.ogg` | 7.6 s | sintesi + Kenney Impact Sounds e Sci-Fi Sounds (CC0) | versione gutturale (16 ottobre): gola sott'acqua, respiro umido, rantolo; impactSoft_medium, slime_000 |
| `lei/lei_scivola_sotto.ogg` | 4.5 s | sintesi (originale) | versione gutturale (16 ottobre): brontolio di gola, l'ultimo fiato che gorgoglia sott'acqua |
| `lei/lei_tunnel_canto_01.ogg` | 6.3 s | sintesi (originale) | tunnel, canto di sirena (variante A, 25 ottobre): una frase ogni 8-15 s mentre insegue |
| `lei/lei_tunnel_canto_02.ogg` | 7.8 s | sintesi (originale) | tunnel, canto di sirena (variante A, 25 ottobre): una frase ogni 8-15 s mentre insegue |
| `lei/lei_tunnel_canto_03.ogg` | 7.8 s | sintesi (originale) | tunnel, canto di sirena (variante A, 25 ottobre): una frase ogni 8-15 s mentre insegue |
| `lei/lei_tunnel_canto_04.ogg` | 9.2 s | sintesi (originale) | tunnel, canto di sirena (variante A, 25 ottobre): una frase ogni 8-15 s mentre insegue |
| `lei/lei_tunnel_canto_05.ogg` | 6.6 s | sintesi (originale) | tunnel, canto di sirena (variante A, 25 ottobre): una frase ogni 8-15 s mentre insegue |
| `lei/lei_tunnel_canto_06.ogg` | 6.0 s | sintesi (originale) | tunnel, canto di sirena (variante A, 25 ottobre): una frase ogni 8-15 s mentre insegue |
| `lei/lei_tunnel_canto_07.ogg` | 6.4 s | sintesi (originale) | tunnel, canto di sirena (variante A, 25 ottobre): una frase ogni 8-15 s mentre insegue |
| `lei/lei_tunnel_canto_08.ogg` | 5.9 s | sintesi (originale) | tunnel, canto di sirena (variante A, 25 ottobre): una frase ogni 8-15 s mentre insegue |
| `lei/lei_tunnel_canto_09.ogg` | 7.1 s | sintesi (originale) | tunnel, canto di sirena (variante A, 25 ottobre): una frase ogni 8-15 s mentre insegue |
| `lei/lei_tunnel_canto_10.ogg` | 6.8 s | sintesi (originale) | tunnel, canto di sirena (variante A, 25 ottobre): una frase ogni 8-15 s mentre insegue |
| `lei/lei_tunnel_fiato_loop.ogg` | 8.0 s | sintesi (originale) | tunnel, voce (24 ottobre): fiato roco e basso a bocca aperta, in ciclo |
| `lei/lei_tunnel_verso_01.ogg` | 1.3 s | sintesi (originale) | tunnel, voce (24 ottobre): verso a bocca spalancata, uno ogni 4-6 s |
| `lei/lei_tunnel_verso_02.ogg` | 1.4 s | sintesi (originale) | tunnel, voce (24 ottobre): verso a bocca spalancata, uno ogni 4-6 s |
| `lei/lei_tunnel_verso_03.ogg` | 1.2 s | sintesi (originale) | tunnel, voce (24 ottobre): verso a bocca spalancata, uno ogni 4-6 s |
| `lei/lei_tunnel_verso_04.ogg` | 1.4 s | sintesi (originale) | tunnel, voce (24 ottobre): verso a bocca spalancata, uno ogni 4-6 s |
| `lei/morso.ogg` | 1.8 s | sintesi + Kenney Sci-Fi Sounds (CC0) | versione gutturale (16 ottobre): ringhio, la fauce si chiude a 1,0 s; slime_000, slime_001 |
| `musica/polaroid_chiudi.ogg` | 0.3 s | sintesi (originale) |  |
| `musica/polaroid_raccolta.ogg` | 2.6 s | sintesi (originale) |  |
| `musica/sigla_pulita.ogg` | 37.6 s | sintesi (originale) | melodia e arrangiamento originali; carillon, organetto, percussioni giocattolo |
| `musica/sigla_rovinata.ogg` | 31.0 s | sintesi (originale) | 96 BPM, primo battito a 0.05 s |
| `musica/stinger_bambini.ogg` | 6.0 s | sintesi (originale) |  |
| `musica/stinger_morte.ogg` | 7.5 s | sintesi (originale) |  |
| `piscina/medusina_aspirata_01.ogg` | 0.8 s | sintesi (originale) | vetro (A, scelto il 16 ottobre): tintinnii che scendono nel tubo |
| `piscina/medusina_aspirata_02.ogg` | 0.8 s | sintesi (originale) | vetro (A, scelto il 16 ottobre): tintinnii che scendono nel tubo |
| `piscina/medusina_aspirata_03.ogg` | 0.8 s | sintesi (originale) | vetro (A, scelto il 16 ottobre): tintinnii che scendono nel tubo |
| `piscina/medusina_aspirata_04.ogg` | 0.8 s | sintesi (originale) | vetro (A, scelto il 16 ottobre): tintinnii che scendono nel tubo |
| `piscina/medusina_aspirata_05.ogg` | 0.8 s | sintesi (originale) | vetro (A, scelto il 16 ottobre): tintinnii che scendono nel tubo |
| `piscina/medusina_aspirata_06.ogg` | 0.8 s | sintesi (originale) | vetro (A, scelto il 16 ottobre): tintinnii che scendono nel tubo |
| `piscina/medusine_sparate_01.ogg` | 1.8 s | sintesi (originale) | A: cascata di tintinnii che si allontana |
| `piscina/medusine_sparate_02.ogg` | 1.8 s | sintesi (originale) | A: cascata di tintinnii che si allontana |
| `piscina/piscina_svuota_loop.ogg` | 6.0 s | sintesi (originale) | gorgo (A, scelto il 16 ottobre): suona dove aspiri finché il livello scende |
| `piscina/piscina_vuota.ogg` | 6.5 s | sintesi (originale) | A: ultimo risucchio, sorso grave a 2,2 s, gocce nella piscina vuota |
| `piscina/pulsante_botola_attiva.ogg` | 1.4 s | sintesi (originale) | richiamo (B, scelto il 16 ottobre): scatto del contattore e jingle che cala |
| `piscina/pulsante_botola_bibu.ogg` | 0.4 s | sintesi (originale) | un bi-bu a ogni lampo del lampeggiante (ogni 1,6 s) |
| `piscina/pulsante_botola_lampeggiante_loop.ogg` | 3.2 s | sintesi (originale) | il lampeggiante giallo che gira |
| `squalo/jilly_richiamo.ogg` | 10.8 s | sintesi (originale) | il verso lontano e profondo di Jilly che lo chiama, dietro la porta tagliafuoco |
| `squalo/squalo_denti_01.ogg` | 1.4 s | sintesi (originale) | i denti che scattano a ogni morso nell'aria |
| `squalo/squalo_denti_02.ogg` | 1.4 s | sintesi (originale) | i denti che scattano a ogni morso nell'aria |
| `squalo/squalo_denti_03.ogg` | 1.4 s | sintesi (originale) | i denti che scattano a ogni morso nell'aria |
| `squalo/squalo_minaccia.ogg` | 6.0 s | sintesi (originale) | fiato a 30 cm, gola che brontola sotto e tre ringhi corti con il risucchio della saliva (2,3 s, 3,2 s, 4,1 s dall'inizio del file); versione B del 23 ottobre |
| `squalo/squalo_passo_01.ogg` | 0.8 s | sintesi + Kenney Impact Sounds (CC0) | passo pesante e bagnato con gli artigli, con il colpo grave sotto |
| `squalo/squalo_passo_02.ogg` | 0.8 s | sintesi + Kenney Impact Sounds (CC0) | passo pesante e bagnato con gli artigli, con il colpo grave sotto |
| `squalo/squalo_passo_03.ogg` | 0.8 s | sintesi + Kenney Impact Sounds (CC0) | passo pesante e bagnato con gli artigli, con il colpo grave sotto |
| `squalo/squalo_passo_04.ogg` | 0.8 s | sintesi + Kenney Impact Sounds (CC0) | passo pesante e bagnato con gli artigli, con il colpo grave sotto |
| `squalo/squalo_ringhio.ogg` | 2.3 s | sintesi (originale) | il ringhio corto e aggressivo verso la porta; versione B del 23 ottobre |
| `squalo/squalo_sbuffo.ogg` | 1.9 s | sintesi (originale) | sbuffo di gola quando si volta a guardarti |
| `tecnici/cancello_stagno_apre_01.ogg` | 3.7 s | sintesi (originale) | cancello stagno che si apre da solo: si muove da 0,55 s e sbatte a 2,55 s |
| `tecnici/cancello_stagno_apre_02.ogg` | 3.7 s | sintesi (originale) | cancello stagno che si apre da solo: si muove da 0,55 s e sbatte a 2,55 s |
| `tecnici/corrente_salta.ogg` | 5.5 s | sintesi (originale) |  |
| `tecnici/crt_neve_loop.ogg` | 3.0 s | sintesi (originale) | la neve di un televisore senza segnale: si sente anche col ruggito delle pompe |
| `tecnici/maniglione_bloccato.ogg` | 0.9 s | Kenney RPG Audio + Impact Sounds (CC0) + sintesi | metalLatch, impactMetal_heavy |
| `tecnici/paratia_scende_loop.ogg` | 3.0 s | sintesi (originale) |  |
| `tecnici/plastica_piega_lontano.ogg` | 12.0 s | sintesi (originale) | si deve sentire sotto il ruggito delle pompe (che lascia liberi i medi) |
| `tecnici/pompa_avvio.ogg` | 3.4 s | sintesi (originale) |  |
| `tecnici/pompe_ruggito_loop.ogg` | 4.0 s | sintesi (originale) | una pompa a pieno regime, ruggito basso; tre pompe = tre loop |
| `tecnici/porta_ponte_apre.ogg` | 3.4 s | Kenney RPG Audio (CC0) + sintesi | metalLatch, creak, doorClose |
| `tecnici/tonfo_acqua_lontano.ogg` | 6.0 s | sintesi (originale) |  |
| `tecnici/zampette_condotto.ogg` | 8.0 s | sintesi (originale) | l'agnellino che corre via dentro il condotto della grata di C2 (v0.3.6) |
| `torre/atterraggio_scivolo_01.ogg` | 0.9 s | sintesi (originale) |  |
| `torre/atterraggio_scivolo_02.ogg` | 0.9 s | sintesi (originale) |  |
| `torre/portone_torre_apre.ogg` | 8.5 s | sintesi (originale) | motore (A, scelto il 16 ottobre): il portone si muove da 0,7 s e sbatte a 6,4 s |
| `torre/scivolo_loop.ogg` | 3.0 s | sintesi (originale) | scivolare sull'acquascivolo bagnato; volume e tono seguono la velocità |

Totale: 222 file, 7.5 MB (OGG Vorbis, 44,1 kHz; mono i suoni posizionati, stereo i fondi, la musica e i tuoni).
