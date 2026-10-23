# Collaudo del posizionamento: risalita (fiume lento e infermeria)

Base: `lavoro/enigmi-acquari` al commit **1c83bb8** (versione consegnata da enigmi). Squadra collaudo, 22 ottobre. Le correzioni di enigmi unite in `lavoro/godot` **e3e370d** superano i difetti 1-4 (lo dice il coordinatore; qui non ricontrollate).

Posizioni in metri nel mondo di `sala_principale.tscn`. Stato misurato: ritorno (blackout della tappa 7, porte e cassetti aperti, negatoscopio con la radiografia), più l'inizio per confronto. Scatti in `scatti/`, fogli in `fogli/`.

## Come è stato fatto

- **Distanze vere**: 600 oggetti della risalita. Nel gioco fiume e infermeria restano nascosti finché il giocatore non è vicino (`risalita_gioco.gd`, `_process`): il collaudo li mostra a mano (`mostra_nascosti` in `stati.gd`).
- **Giro dagli occhi**: 107 punti a piedi (imbarco, zona del personale, corridoio, scala, infermeria), più 54 punti sull'acqua lungo il fiume, all'altezza degli occhi di chi sta sulla ciambella: 644 scatti (`fogli/risalita_giro_*.jpg`).
- **Oggetti piccoli**: 150 sotto i 40 cm (`oggetti_piccoli.csv`); 161 vedute ravvicinate, da terra o dall'acqua, con la vista libera verificata (`fogli/risalita_vedute_*.jpg`).

## Difetti (visti su 1c83bb8)

| # | Nodo | Posizione | Problema | Scatto | Stato |
|---|---|---|---|---|---|
| 1 | `Risalita/Fiume/lampada_capannone`, `3`, `4`, `5`, `7`, `8` con i loro cavi (`Fiume/Tetto/@MeshInstance3D@176`, `179`, `181`, `182`, `186`, `187`) | x -18,4…-58,4, y -1,0 (lampada) / 1,1 (cima del cavo), z 76-114 | Il cavo finisce 5 cm sotto la capriata del tetto (`Tetto/@MeshInstance3D@175`): lampade appese al nulla. | `scatti/vris_lampada_capannone5_Mesh_0.jpg`, `vris_Tetto_@MeshInstance3D@176.jpg` | superato in e3e370d |
| 2 | `Risalita/Fiume/FiumeLento/Paratia1`, `2`, `3`: `Disco` | -20,0, -3,4, 113,4; -56,4, -3,4, 107,0; -48,5, -3,4, 74,8 | Il disco a strisce è a 1,2-1,3 cm dal palo. | `vris_Paratia1_Disco.jpg`, `vris_Paratia3_Disco.jpg` | superato in e3e370d |
| 3 | `Paratia1`, `2`, `3`: `lampada_emergenza` | y -2,7, accanto ai dischi | La lampada è a 1,7 cm dal collare del palo. | `vris_Paratia1_Disco.jpg` | superato in e3e370d |
| 4 | I 6 portali dei cartelli verdi: `Fiume/Cartello1Sx`, `1Dx`, `2Sx`, `2Dx`, `3Sx`, `3Dx` (pali `@MeshInstance3D@192`…`@254`, traverse, casse e facce) | z 65,3 / 70,7 / 89,3 / 92 / 113,3 / 116 | I pali da 3,8 m finiscono a y -5,4, 20 cm sopra il pelo dell'acqua (-5,6) e a 10 cm dalla sponda: i portali non poggiano su niente. | `vris_Fiume_@MeshInstance3D@192.jpg` | superato in e3e370d |

Il resto della risalita, nel giro e da vicino, è a posto: le ciambelle e la paperella galleggiano sull'acqua; la scrivania, la cassaforte con la keycard e la Polaroid, il negatoscopio, il pulsante del parco, lo schedario, la tenda, il lettino, la sedia a rotelle, la giraffa e gli adesivi poggiano o sono fissati. Le lampade rosse sono sulla roccia o sul muro, e le transenne a terra sono cadute, appoggiate al pavimento.

Negli scatti della risalita i cassetti dello schedario sono tutti tirati fuori: è lo stato forzato del collaudo, non quello del gioco (nel gioco se ne apre uno).

## Buco del controllo della CI

`controllo_posizionamento.gd` salta gli oggetti nascosti: fiume e infermeria sono nascosti all'avvio, quindi le loro 560 mesh non sono mai controllate. Il controllo deve mostrarli prima di misurare, per esempio spegnendo il `_process` della risalita e rendendo visibili `fiume` e `infermeria`, come `mostra_nascosti` in `godot/tests/collaudo/stati.gd`.
