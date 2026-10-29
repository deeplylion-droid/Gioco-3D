# Ricontrollo della sparizione dei bambini, 013db6fb (29 ottobre)

Squadra collaudo. `lavoro/bambini-sfuggita` **013db6fb**: i bambini spariscono solo quando nessun osso del corpo è in
vista. **Esito: va.** 0 righe "ERROR: BUG,". Test del branch: test_bambini_sfuggita 41/41, test_bambini_passi 16/16,
test_agnellino 12/12, test_bambini 49/49. Le zone si costruiscono a pezzi col riscaldamento come nel gioco
(`risalita_prova.tscn`, partita del tunnel, scena di prova della tappa 7).

## Corridoio del fiume, 5 posizioni del giocatore

Mentre il bambino col cubo scappa, il giocatore:
- `cammina` verso la porta (come prima, quella dei 13,6 m);
- resta `fermo` in fondo alla scala;
- `corre` verso la porta;
- va avanti spostandosi a `destra` o a `sinistra`.

| Modo | Ossa in vista nel fotogramma prima | Giocatore più vicino | Fermo in vista ad aspettare |
|---|---|---|---|
| cammina | 1 su 24 (punta del piede destro) | 12,8 m | no |
| fermo | 1 su 24 | 16,5 m | no |
| corre | 1 su 24 | 10,1 m | 0,01 s |
| destra | 1 su 24 | 13,9 m | no |
| sinistra | 1 su 24 | 15,8 m | no |

- Ora sparisce 30 cm più in là di prima (x -6,26 invece di -5,95), coperto dal muro `Corridoi`.
- Negli ultimi fotogrammi della fuga le ossa in vista calano da 6 a 1, una per fotogramma mentre corre dietro lo stipite. Poi sparisce subito.
- L'osso che resta è nel fotogramma prima: il gioco controlla dagli occhi e dopo l'ultimo passo (4 cm).
- Col renderer vero (`cammina`), nell'ultimo scatto dagli occhi in fuga il cubo è già tutto dietro lo stipite
  (`fogli/013db6fb_corridoio_cubo_alla_porta.jpg`, 016). Non si vede più sparire a metà.
- Non si ferma in vista: col giocatore di corsa resta fermo al massimo 0,01 s.

## Tunnel e scala

- **Galleria del tunnel:** sparisce con 0 ossa su 24 in vista, coperto dal muro della galleria. Il giocatore resta a 11,1 m e non ci sono prese.
  Il secondo morso a 222,7 m è dopo la zona del bambino.
- **Agnellino della scala C2:** sparisce fuori dall'inquadratura, nella cavità. Il giocatore gli arriva al massimo a 1,26 m.
  test_agnellino col renderer vero 10/10.

## Piedi

Uguali a f9b7c8cd, quindi le correzioni ci sono ancora:
- corridoio: svolta 0,13 m/s di media;
- tunnel e C2: come prima;
- C2: in fuga i piedi non vanno sotto -0,5 cm;
- cubo fermo a 2,1-2,4 cm (le ossa delle punte; la suola tocca terra);
- agnellino fermo a 0,5-0,7 cm.
