# Posizionamento delle cose di mascotte nella sala (22 ottobre)

Regola dell'utente: "basta con queste robe volanti o staccate dal resto" (anche 1-2 cm sono un difetto).
Misura al centimetro: `godot/proposte/mascotte/sonda_mascotte_posizioni.gd` (per ogni mesh: se tocca qualcosa entro
1,2 cm, l'appoggio delle statue, la distanza del retro dalla parete, i vertici dentro altre cose). Scatti dal motore
(`godot/proposte/mascotte/scatti_mascotte_posizioni.gd`), in questa cartella.

| Cosa | Prima | Ora | Scatto |
| --- | --- | --- | --- |
| Lampade dell'insegna | lampadina e paralume a mezz'aria (1-3 cm dal braccio) | il braccio entra nel portalampada di ferro, il paralume ci si appoggia, la lampadina e' avvitata sotto | `insegna_lampada_sx.jpg`, `insegna_lampade.jpg` |
| Manifesto | 3-4 cm staccato dal muro (il muro visibile li' e' dove c'e' la collisione) | a filo del muro (Posa.fissa_al_muro): il retro a 1-11 mm per le onde della carta, la colla a 1,5 mm | `manifesto.jpg`, `manifesto_bordo.jpg` |
| Targa | a filo della collisione, ma la collisione della vasca sporge 3 cm oltre le piastrelle: 3 cm staccata (controllo severo, sera) | sulle piastrelle vere (Posa con l'affondo di 3 cm) | `targa.jpg` |
| Insegna (pannello, staffe, piastre) | a filo (3-13 mm) | a filo, con Posa | `insegna_lampade.jpg` |
| Statue (squalo, polpo A, polpo B) | appoggiate: la base tocca il pavimento | uguale | `statua_*_base.jpg` |
| Cornice dell'insegna | i listelli su e giu' si sovrappongono a quelli di lato (la sonda, che guarda i vertici, li dava staccati: sono scatole con 8 vertici) | uguale | - |
| Jilly alla vasca centrale e alla fossa | il corpo, le mani e i tentacoli toccano il bordo e l'acqua; occhio, palpebre, capelli fanno parte della testa | uguale | - |

Il "pezzo della medusa della vasca a 1 cm" del controllo severo (`Vasca/Medusa/@Node3D@.../@MeshInstance3D@...`, e lo
stesso alla fossa) e' una goccia d'acqua che cade dalle dita (WaterDripEmitter, addons/acqua): si vede solo mentre
cade, e nello stato "tutto visibile" resta ferma a mezz'aria. Non e' un oggetto da fissare.

Controllo severo della sera (gruppi che si reggono solo fra loro): il manifesto era gia' a posto con la correzione
del pomeriggio (il rapporto di grafica era fatto prima che fosse unita); la targa era vera: corretta come sopra.
Controllo ufficiale sul ramo, dopo aver unito lavoro/godot 9628ee5: 0 casi di mascotte.
