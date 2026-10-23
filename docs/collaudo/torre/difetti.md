# Collaudo del posizionamento: torre degli scivoli e inseguimento

Base: `lavoro/ambienti-2-inseguimento` al commit **604e519**. Squadra collaudo, 22 ottobre. Tutti i difetti qui sotto sono visti su 604e519.

Posizioni in metri nel mondo di `scenes/sala/torre/sala_torre.tscn`, che contiene anche la sala dell'inseguimento. Stato misurato: inizio. I nomi `@Node3D@…` e `@MeshInstance3D@…` sono quelli che Godot dà ai nodi creati da `sala_torre.gd` e `sala_inseguimento.gd`: cambiano da un commit all'altro, per questo c'è sempre anche la posizione. Gli scatti sono in `scatti/` e i fogli in `fogli/`.

## Come è stato fatto

- **Distanze vere**: 303 oggetti, misurati fra le superfici delle mesh (`tools/collaudo/distanze.py`).
- **Giro dagli occhi**: 55 punti lungo le scale, le passerelle, gli imbocchi degli scivoli, le vasche d'arrivo e le vasche dell'inseguimento (dove si cammina nell'acqua), 4 scatti per punto: 220 scatti (`fogli/torre_giro_*.jpg`).
- **Oggetti piccoli**: 164 sotto i 40 cm (`oggetti_piccoli.csv`); 85 vedute ravvicinate dai punti dove si cammina, con la vista libera verificata (`fogli/torre_vedute_*.jpg`).
- **Spazio per la testa**: le mesh a meno di 30 cm in pianta da un punto dove si cammina e fra 0,5 e 1,95 m sopra quel punto.

## Difetti (visti su 604e519)

| # | Nodo | Posizione | Problema | Scatto |
|---|---|---|---|---|
| 1 | `Polaroid10` (da raccogliere) e `TorreStruttura/torre_polaroid_10`, sul `TorreProp/prop_lettino_plastica_1` | 23,59, -11,63, -22,41 | La Polaroid è 2,1 cm sopra il lettino, e il lettino è 1 cm sopra il grigliato: la Polaroid da raccogliere è sospesa. | `scatti/vtor_Modello_Polaroid.jpg`, `vtor_TorreProp_prop_lettino_plastica_1.jpg` |
| 2 | Due fari sulla passerella, sulla strada: `Luci/@Node3D@145` (con il braccio `Luci/@MeshInstance3D@154`) e `Luci/@Node3D@156` (braccio `@165`) | 26,6, 1,4, -19,1 (passerella a -0,01) e 26,6, -10,6, -19,0 (passerella a -12,01) | Il corpo del faro sta fra 1,27 e 1,52 m sopra la passerella, proprio sopra i punti dove si cammina (checkpoint 20 e 24): passa davanti alla faccia, e non ha collisione, quindi ci si entra con la testa. | `tor012_o.jpg`, `tor012_s.jpg`, `tor030_e.jpg`, `vtor_@Node3D@145_@MeshInstance3D@150.jpg` |
| 3 | La scia rosa sul bordo della vasca 1 dell'inseguimento: `SalaInseguimento/Luci/@Node3D@439/Nastro` (la `BavaRosa` di `sala_inseguimento.gd`, riga 873) | da 53,5 a 49,7, y -21,48, z -15,9…-18,2 | Il nastro è tutto alla stessa quota (`appoggia = false`) e non segue il bordo: su 90 vertici, 49 non hanno niente sotto per almeno mezzo metro (pende nel vuoto oltre il bordo della vasca), 6 sono 10 cm-1 m sopra qualcosa e 35 sono 2-10 cm sopra il bordo; nessuno lo tocca. | `tor041_e.jpg`, `tor041_o.jpg`, `vtor_@Node3D@439_Nastro.jpg` |
| 4 | `Luci/@MeshInstance3D@128`…`@132`: la lampada con il braccio | 31,0, 1,0, -25,65 | Lampada e braccio sono a 5 cm da tutto: appesi al nulla. | `vtor_Luci_@MeshInstance3D@130.jpg`, `@132.jpg` |
| 5 | Lampade d'emergenza rosse `Luci/@MeshInstance3D@72` e `@80` | 20,3, 6,0, -20,5 e 20,3, -12,0, -10,0 | A 2 cm dal muro: il `Posa.fissa_al_muro` aggiunto in `_emergenza` non le ha portate a contatto (le altre sì). | `vtor_Luci_@MeshInstance3D@72.jpg`, `@80.jpg` |
| 6 | Faro `Luci/@Node3D@233` con il suo braccio `Luci/@MeshInstance3D@242` | 26,9, -10,5, -10,7 | Il faro è a 1,5 cm dalla struttura che dovrebbe reggerlo. | (posizione misurata) |
| 7 | Inseguimento: le 6 lampade sopra le vasche, `SalaInseguimento/Luci/@MeshInstance3D@408`/`409`, `412`/`413`, `416`/`417`, `420`/`421`, `424`/`425`, `428`/`429` | 51,5, -16,5, -7,5; 61,5, -17,5, -17,5; 70,5, -18,5, -24,0; 45,0, -19,0, -22,5; 43,8, -17,0, -28,5; 61,0, -23,5, -9,9 | Il paralume pende 1,2 cm sotto il suo gancio (`@407`, `@411`, …): non è attaccato. | `vtor_Luci_@MeshInstance3D@408.jpg`, `@417.jpg` |
| 8 | `SalaInseguimento/Luci/@Node3D@457/det_tubo_valvola_T` | 55,6, -23,2, -31,8 | A 2 cm dal muro: il tubo con la valvola non è fissato a niente. | (posizione misurata) |
| 9 | Minore: `TorreProp/prop_cartello_pavimento_bagnato_1` e `SalaInseguimento/InseguimentoProp/prop_cartello_pavimento_bagnato_1` | 23,6, 0,3, -22,4 e 41,3, -29,7, -5,8 | A 1 cm dal grigliato: appena sospesi. | `vtor_TorreProp_prop_cartello_pavimento_bagnato_1.jpg` |
| 10 | Da valutare: il tubo lungo inclinato nella vasca dell'inseguimento (fa parte di una mesh grande, quindi non è misurato a parte) | vicino a 43,5, -33,4, -3,5 | Il tubo esce dall'acqua, sale fino al bordo e finisce accanto ai piedi della scaletta gialla. Dagli scatti non sembra sospeso, ma conviene guardare che non si incroci con la scaletta e che si capisca perché è lì. | `tor052_o.jpg`, `tor052_e.jpg` |

## Visti e a posto

- Le lampade a palo sui corrimano, le lampade a muro e i grappoli della catena di lei toccano ciò che li regge (a 604e519 i pali arrivano alla pedana e i cavi oltre l'ultimo grappolo).
- I perni dei fari reggono il corpo nella staffa.
- Le ciambelle e le paperelle delle vasche d'arrivo e dell'inseguimento galleggiano sull'acqua.
- Il fondo del pozzo di lei è incastrato fra le pareti.
- Negli scatti del giro dalle passerelle non ci sono altri oggetti sospesi o compenetrati.
- Le inquadrature "dentro" gli scivoli (`tor014`-`tor029`) vengono dai punti sugli imbocchi: lì il giocatore entra nello scivolo, quindi non sono difetti.

## Buchi del controllo della CI

- I MultiMesh della torre (`Luci/@MultiMeshInstance3D@300`, i led degli imbocchi) senza schermo non hanno trasformazioni. Il meta `trasformazioni` aggiunto in `_segnali_strada` serve al controllo; questo collaudo non lo legge ancora.
- Lo spazio per la testa sopra le passerelle (difetto 2) il controllo non lo vede, perché i fari non hanno collisione.
