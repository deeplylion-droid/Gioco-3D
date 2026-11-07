# Collaudo 0.3.22, prima parte: menu, avvio e schermata di caricamento (7-8 novembre)

Squadra collaudo. Lo stato provato è `lavoro/candidata-0322` 34177697 (main 29f78c94 + caricamento-jilly bb377830, squalo-0322 c8c732ce, menu-0322 42307f6f), senza cambiare niente nel gioco. L'exe è l'export release Linux della candidata (`--export-release "Linux"`).

**Esito: due difetti da correggere (il primo grave, c'è già nella 0.3.21), un difetto piccolo già girato, alcune osservazioni.**

## Difetti
1. **Crash dell'exe alla prima entrata nella sala con un profilo nuovo (GRAVE).** `scripts/ui/menu/caricamento.gd:146-149`, `_entra()`: prima `get_tree().change_scene_to_packed(pacchetto)`, che toglie subito la schermata dall'albero, poi `QualitaAutomatica.avvia(get_tree(), …)` con `get_tree()` ormai null.
   - Editor, `--headless -- --partenza=torre`, profilo con `qualita_provata=false`: `ERROR: Parameter "data.tree" is null` in `_entra` (riga 149), poi `SCRIPT ERROR: Invalid access to property or key 'root'` in `avvia` (`qualita_automatica.gd:44`). La prova non parte e il `return` salta lo `schiarisci` (`log/editor_partenza_torre_errore.log`).
   - Exe release, stessi argomenti: segfault (uscita 139) all'arrivo nella sala, con torre, tunnel, fiume e in EN (`log/exe_partenza_torre_crash.log`, `log/exe_verbose_coda.log`).
   - Contro-prova: stesso exe e stesso profilo con `qualita_provata=true`: arriva, muore, riparte, resta 20 s ed esce con 0 (`log/exe_qualita_provata_true.log`). Senza `--partenza` (solo il titolo) nessun crash in 5 minuti.
   - Il codice è uguale nella 0.3.21 (c6187286) e in main 29f78c94. Nessun test lo prendeva: test_qualita_automatica chiama `avvia` da solo, la Prova su Vulkan passa `--preset=basso` (scelta a mano, niente prova), i test con `--script` la saltano.
2. **Fuoco perso chiudendo la calibrazione (joypad).** Chiusa «Calibra la luminosità…» con B o Esc il fuoco è «nessuno» e né la croce né le frecce lo riprendono (`log/calib_fuoco.log`, `tests/collaudo/calib_fuoco.gd`; `fogli/audio_joypad.jpg`, ultimo riquadro). Corretto da grafica su `lavoro/menu-0322` 0a05c8d0: da ricontrollare.
3. (piccolo) Il titolo dice «demo 0.3.21»: `project.godot:15`. Lo porta a 0.3.22 il coordinatore nel push finale.

## Test (0 BUG, 0 SCRIPT ERROR)
| test | esito |
|---|---|
| check_scripts | 0 errori |
| test_menu, menu_schede, avvio_sicuro, qualita_automatica, lingua | 85, 15, 21, 26, 30 ok |
| test_caricamento_jilly (`--fixed-fps 60`), primo_uso (Vulkan 320x180) | 17, 4 ok |
| test_fine_titolo, partenze_prova, continua | 13, 72, 127 ok |
| test_menu_pausa_zone inizio, torre, fiume, tunnel; inizio in EN | 26 ok ognuno |
| sonda_menu_audio su Vulkan (IT ed EN, 5 giri ciascuna) | 115 passi, nessun crash |

Gli ERROR rimasti nei log sono perdite all'uscita e l'audio ALSA del sandbox. Una prima corsa della sonda Audio era finita per timeout: sul renderer software ci mette 33 minuti (rifatta con un battito da un thread a parte: il motore non si ferma mai).

## 1. Primo avvio e avvio sicuro (gioco vero, tasti veri)
Il gioco senza `--script`, cartella utente vuota, su Xvfb con tasti e clic veri (XTEST), editor ed exe release, IT ed EN (`fogli/titolo_e_avvio_sicuro.jpg`):
- titolo senza calibrazione della luminosità; `settings.cfg` scritto con preset alto, `qualita_provata=false` (la prova automatica resta da fare all'ingresso nella sala), `calibrato=false` (`log/settings_primo_avvio.cfg`);
- 8 giri col mouse (Opzioni, Audio, cursore trascinato, altre schede, Ripristina i volumi, Esc, riapri) e 5 giri con le frecce nelle opzioni: nessun crash, nessun ERROR, sull'editor e sull'exe;
- chiusura di colpo (`kill -9`): il segno `sessione_aperta` resta e al riavvio c'è la domanda «Avvio sicuro?» (nota senza driver, siamo su Linux), col fuoco su «Avvio sicuro», senza aspettare nessuna calibrazione. Esc vale Avvio normale: titolo dopo 3 s, preset alto. Invio: preset basso salvato (`log/settings_dopo_avvio_sicuro.cfg`);
- Esci col pulsante cancella il segno.

**Osservazione:** con Invio la domanda resta ferma a schermo circa 45 s sul renderer software, mentre il titolo si ridisegna col preset basso; poi il titolo torna. Su una scheda vera sarà breve, ma la domanda non si chiude prima del cambio di qualità.

**Non provato:** la prova della qualità automatica vera dentro la sala sullo schermo: la sala intera su Vulkan software supera la memoria (vedi le note). Con la correzione del difetto 1 la ricontrollo sull'exe senza schermo.

## 2. Opzioni e Audio
- Scatti di tutte le schede in IT ed EN (`fogli/opzioni_schede_it.jpg`, `fogli/opzioni_schede_en.jpg`).
- Joypad (`fogli/audio_joypad.jpg`): dalla barra con la croce si arriva ad Audio, giù va sul volume generale, la croce a sinistra lo porta da 100 a 97.
- Dalla pausa, dopo una morte e appena ripartiti: test_menu_pausa_zone nelle 4 zone e in EN.
- Exe release: `--script` nell'exe viene ignorato, quindi niente sonde dentro l'exe; sull'exe ho fatto i giri coi tasti veri dal titolo (sopra). La pausa dentro la sala sull'exe non si può fare qui: la sala su Vulkan software va oltre la memoria.

**Osservazioni:** il fuoco sui cursori si vede solo dalla manopola bianca (resta così); il titolo «Opzioni grafiche» anche su Audio (corretto da grafica in «Opzioni»).

## 3. Luminosità
Il cursore va da 1,00 a 1,02 con la croce; «Calibra la luminosità…» si apre con A e si chiude con B (poi il difetto 2).

## 4. Schermata di caricamento
- **Tutte le entrate** (`car_entrate.gd`, senza schermo, una dopo l'altra nello stesso processo; `log/car_entrate.log`): Nuova partita (dopo lo spot), Continua due volte, F9 torre, fiume, tunnel, inizio passano dalla schermata; il video va, la barra arriva al 100% senza tornare indietro, all'arrivo il video è liberato (0 VideoJilly e 0 VideoStreamPlayer vivi). La ripartenza dopo la morte non passa dalla schermata: la sala si ricarica in due tempi, com'è fatto.
- **Memoria:** RSS 1,7 → 2,5 → 3,3 → 4,6 GB nei primi caricamenti, poi ferma a 4,7 GB per gli altri cinque; memoria statica di Godot fra 1,2 e 1,8 GB. Nodi orfani 305 subito dopo l'F9 della torre, poi 1-2.
- **Scatti in 3 momenti** (`car_scatti.gd`, `log/car_scatti.txt`; `fogli/caricamento_*.jpg`): a 1280x720, 1920x1080, 1280x800, 1024x768 ed EN il video avanza fra uno scatto e l'altro, non è mai deformato (rapporto 1,000: riempie e taglia ai lati, 71 px per lato a 16:10, 213 a 4:3), i testi stanno tutti dentro e non sono tagliati, il consiglio EN va su 2 righe.

**Osservazioni:** a 4:3 il bordo destro taglia un po' la testa di Jilly (occhio e mano interi). «tieni premuto» è un po' tenue dove dietro ci sono le luci.

## Note sugli strumenti
- `tests/misura_caricamento_jilly.gd`: aspetta la sala, e sul renderer software arriva a 12,3 GB e il sistema la uccide (OOM nel cgroup; la macchina non si è riavviata). Legge l'RSS con `get_as_text()` su `/proc/self/status`, che torna vuoto: stampa sempre 0 MB. Al suo posto `car_scatti.gd`, che fa gli scatti e chiude il processo prima della sala.
- Sul renderer software i tre scatti della misura cadevano nello stesso fotogramma (fotogrammi fino a 7 s durante il caricamento): per questo erano identici.
- Strumenti in `godot/tests/collaudo/`: `opzioni_scatti.gd`, `calib_fuoco.gd`, `sonda_audio_battito.gd`, `car_entrate.gd`, `car_scatti.gd`; `vero.sh`, `diag_as.sh` e `xin.py` (tasti veri con XTEST) qui accanto.
