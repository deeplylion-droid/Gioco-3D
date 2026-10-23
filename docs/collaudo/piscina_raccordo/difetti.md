# Collaudo del posizionamento: piscina a onde e raccordo

Base: `lavoro/godot` al commit **59aef5a**, con le consegne di stasera: per il raccordo le correzioni di enigmi 97fb7120, d02b8987 ed e321f1cb. Squadra collaudo, 22 ottobre. Tutto quello che c'è qui sotto è visto su 59aef5a.

Posizioni in metri nel mondo di `sala_principale.tscn`. Stati misurati: ritorno (blackout della tappa 7, porte aperte, pozza nella piscina) e inizio. Gli scatti sono in `scatti/` e i fogli in `fogli/`.

## Come è stato fatto

- **Distanze vere**: 374 oggetti del raccordo (con il magazzino, la serranda e le scale) e 75 nella piscina a onde (oggetti, dettagli della sala nel fondo, Polaroid05), negli stati ritorno e inizio. Il collaudo legge ora anche il meta `trasformazioni` dei MultiMesh, quindi le lamelle della serranda del magazzino sono contate.
- **Giro dagli occhi**: raccordo 24 punti (96 scatti), piscina 22 punti sul fondo (88 scatti) (`fogli/raccordo_giro_*.jpg`, `fogli/piscina_giro_*.jpg`).
- **Oggetti piccoli**: 173 (`oggetti_piccoli.csv`). Vedute ravvicinate: 110 nel raccordo e 35 nella piscina (`fogli/*_vedute_*.jpg`).
- **Spazio per la testa**: anche i festoni e i tubi lunghi, a qualsiasi lunghezza.

## Difetti (visti su 59aef5a)

| # | Nodo | Posizione | Problema | Scatto |
|---|---|---|---|---|
| 1 | Minore: `Tecnici/Ambienti/Raccordo/ArredoRisalita/c2_corrimano_staffa1` e `_staffa2` | 2,27, -0,25, 45,0 e 1,33, 0,35, 45,0 | Le due staffe di mezzo sono a 1,2 cm dal corrimano: non lo reggono (le staffe 0 e 3 toccano). | `scatti/vrac_ArredoRisalita_c2_corrimano_staffa1.jpg`, `_staffa2.jpg` |

## Visti e a posto

- **Raccordo**: le lampade (rc1-3, t7_c2a/b/c, t7_c3a/b, t7_mag_a/b, t7_serranda), la plafoniera e i cartelli d'uscita adesso toccano il muro (a 604e519 erano a 2 cm); `uscita_r1` è a posto. I festoni sono attaccati ai loro ganci e non scendono sotto i 2 m sopra dove si cammina. Le lamelle e la barra della serranda, i mucchi di gonfiabili, gli scaffali e le scatole poggiano su qualcosa.
- **Lampade a muro `G_*` vicino ai punti dove si cammina** (`G_c2e_m_2`, `G_c3n_m_0`, `G_f1e_m_2`, `G_f1o_m_1`): sono estintori e salvagenti appesi al muro con piastra e piolo, a 1,3-1,5 m d'altezza. Sporgono 20-25 cm dal muro, come in un corridoio vero, e non passano davanti alla faccia.
- **Piscina a onde**: ciambelle, palloni, paperelle, tubi galleggianti, il delfino sgonfio e i dettagli del fondo (fogli, ciabatte, secchielli, alghe, piastrelle) poggiano sul fondo o galleggiano sulla pozza. La **Polaroid05** tocca il fondo (0,4 cm; prima era a 1 cm): `scatti/vpis_Polaroid05.jpg`.

## Note

- Nel giro del raccordo i punti `rac007`-`rac009` (scala da -5,4 a -1,8 verso il fiume) e `rac018` (verso l'infermeria) danno sul buio: per la memoria il giro toglie la risalita, quindi lì non c'è niente da vedere. Non sono difetti.
- I MultiMesh delle meduse della piscina (`Piscina/SvuotaPiscina/Medusine`) si muovono e non hanno il meta `trasformazioni`: non sono misurati.
