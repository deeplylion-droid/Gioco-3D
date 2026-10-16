# Strada di risalita (tappa 7 B): apparizioni dei bambini

Punto 12 della prova della v0.3.1: "Magari ci aggiungiamo pure un'apparizione dei mostriciattoli bambini che avevamo fatto". Solo proposte: nel gioco non è cambiato niente.

Video brevi dal motore (Movie Maker, 24 fps), con la luce vera dopo il risveglio. I bambini sono le scene già fatte (`scenes/creature/bambino_agnello.tscn` e `bambino_cubo.tscn`) e fanno da soli quello che farebbero nel gioco; il giocatore segue un percorso fisso. Per ogni video c'è anche un foglio con 8 fotogrammi (`*_fotogrammi.jpg`).

1. **`1_scala.mp4`, in cima alla scala.** Dal pianerottolo in cima si vede l'agnellino fermo in cima alla scala del corridoio C2, rivolto verso di te. Quando lo guardi inclina la testa. Quando ti avvicini scappa lungo il corridoio e sparisce dietro l'angolo di C3, cioè proprio dove devi andare.
2. **`2_scaffali.mp4`, tra gli scaffali.** Entrando nel magazzino, il testa-a-cubo è in piedi tra gli scaffali e ti segue con lo sguardo. Se gli tieni addosso la torcia scappa nel varco tra due scaffali e sparisce.
3. **`3_serranda.mp4`, oltre la serranda.** Dal magazzino, sotto la serranda mezza alzata, nella sala buia ci sono due bambini fermi che guardano. Quando arrivi alla serranda il cubo scappa di lato e sparisce; l'agnellino resta lì a fissarti.

Si possono anche combinare (per esempio 1 e 3). Video fatti con `godot/tests/video_tappa7_bambini.gd` e montati con `tools/componi_video_tappa7.py`.
