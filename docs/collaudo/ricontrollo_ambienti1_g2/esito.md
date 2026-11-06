# Ricontrollo di grafica-2: ritocchi di ambienti-1 (lavoro/angolo-via b341d58c)

Il branch è 6816726a di ambienti-1 più la fuga del bambino di mascotte. Ho guardato:
- la Risalita della scena di prova (`tests/scene/risalita_prova.tscn`), con le luci del blackout e le pozze risolte (stato 2: turchese, viola e arancione tolti);
- il renderer vero (Vulkan su llvmpipe, 960x540);
- i raggi sulle collisioni del gioco.

Gli scatti ravvicinati hanno una luce tecnica sulla camera, che nel gioco non c'è.

Script: `ric_a1_g2.gd` (scala, angolo, corridoio) e `video_bambino_g2.gd`. Il secondo è `video_bambino_cubo.gd` con in più i casi `insegui` e `insegui_soglia`.

## Esito

| cosa | esito |
|---|---|
| Nastro giallo e nero (24 strisce) | appoggiato: distacco dal pavimento 0 mm, misurato in 5 punti per striscia |
| Fascia catarifrangente (2 pezzi, muro ovest del tratto e muro sud del corridoio) | attaccata: 0 mm dal muro in 7 punti per pezzo, da capo a capo; all'angolo i due pezzi si incontrano |
| Lampade rosse in cima (2) | fondo a 2,030 m dal pavimento; la piastra è contro il muro (il box della mesh entra 2 cm nel muro, come prima del ritocco) |
| 2 m liberi in cima alla scala | niente sotto i 2 m sul tratto verso sud e sul corridoio fino alla porta di C3 |
| Salita e discesa con le pozze risolte | dalla ripartenza alla porta di C3 e ritorno senza fermarsi; fra 0,1 e 2 m sopra i piedi solo i gradini delle rampe |
| Pile del fiume dal file | identiche: le due liste (dal file e costruite) hanno 7.122 righe, uguali byte per byte |
| test_bambini_sfuggita | 55/55 |
| Bambino, inseguimento fino alla soglia | lo vedi correre dietro la pila; visto l'ultima volta al fotogramma 208 (solo un pezzetto sul bordo della pila), sparisce al 222, quando non si vede più |
| Bambino, inseguimento entrando 1 m | visto fino al fotogramma 225 (un piede sul bordo dello stipite), sparisce al 226. Non si vede sparire, ma il margine è di un fotogramma (foglio `insegui_dentro_ultimi_fotogrammi.jpg`) |
| Pila dell'angolo: appoggiata | 41 unità, la più bassa a 0 mm dal pavimento; collisione 1,2 x 5,4 x 1,0 m con la base a 0 |

## Da decidere o da correggere (ambienti-1)

1. **La pila dell'angolo non è contro il muro nord: c'è uno spazio di 34-37 cm.**
   - Misura: raggi sulle collisioni dalla faccia nord della pila a 30 cm, 1 m e 1,8 m d'altezza, in tre punti.
   - Negli scatti `pila_muro_nord_radente` e `pila_muro_nord_radente_basso` (`foglio_angolo_b.jpg`) si vede il pavimento fra la pila e il muro.
   - È la stessa distanza del muro di pile 0 lungo il muro nord, che parte a Z0 + 0,32. Ma il compito diceva "contro il muro nord".
   - Da 40 cm dentro la soglia, guardando lungo il muro, dentro quella fessura si vede fino in fondo alla nicchia: 12 punti su 48, tutti a 10 cm dal muro, dove il bambino non entra.
2. **La nicchia è aperta verso sud: da dentro il capannone se ne vede la parte sud.**

   | da dove (occhi a 1,6 m) | punti della nicchia visibili |
   |---|---|
   | soglia | 0 su 48 |
   | 1 m dentro, anche accucciati | 0 su 48 |
   | 2 m dentro | 0 su 48 |
   | 2 m dentro, 80 cm a ovest | 3 su 48 |
   | 4 m dentro | 12 su 48 |

   - I punti visibili sono quelli a sud, accanto alla pila.
   - Il bambino sparisce prima che il giocatore possa arrivare lì: compare solo col giocatore nel corridoio. Lo scrivo perché il criterio era "dalla strada la nicchia non si deve vedere".
3. Niente da correggere ma da sapere: nella scena di prova, oltre la porta di C3, c'è il cielo, perché C3 sta nella sala e lì non è caricata. La porta e il corridoio fino a lei sono a posto.

## Fogli
- `foglio_scala_vicino.jpg`: le due lampade (da sotto e di lato), il nastro (capo e radente: il primo, il quarto e l'ultimo), la fascia (capi e mezzo).
- `foglio_scala_giro.jpg`: su per la scala fino alla porta di C3 e di nuovo giù, dagli occhi.
- `foglio_angolo_b.jpg`:
  - dalla soglia (avanti e girati a sinistra), da dentro e da 2 e 4 m;
  - la pila dall'alto, radente al muro nord e alla base;
  - la nicchia.
- `foglio_insegui_soglia.jpg`, `foglio_insegui_dentro.jpg`, `insegui_dentro_ultimi_fotogrammi.jpg`: l'inseguimento dagli occhi, a 30 fotogrammi al secondo.
- `foglio_corridoio_pile.jpg`: una passata del corridoio delle pile dall'ingresso fino al salvagente, tutto come prima.
