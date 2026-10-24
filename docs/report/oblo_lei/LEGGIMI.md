# Oblò con Jilly dietro il vetro (Risalita)

Tre oblò grossi nei corridoi della Risalita. Dietro ognuno c'è una vasca allagata, e Jilly è attaccata al vetro con la sua luce rosa. Compaiono solo dopo la sala pompe, al buio. Lei arriva quando il giocatore non guarda l'oblò e resta finché la vede. Si stacca piano quando il giocatore si avvicina troppo o guarda altrove, e in ogni corridoio succede una volta sola.

| Oblò | Dove | Posa |
|---|---|---|
| ObloFiume | in fondo alla scala verso il fiume, sul muro est | schiacciata sul vetro |
| ObloPersonale | nel corridoio del personale, sul muro ovest | sbircia dal bordo |
| ObloServizio | nella scala di servizio, tratto in piano, sul muro nord | a testa in giù |

Il pezzo è `godot/scripts/game/ObloLei` (`oblo_lei.gd`), con lei di mascotte (`lei_oblo.gd`). È in `godot/scripts/risalita/risalita_gioco.gd`, nella funzione `_oblo()`.

## Scatti dagli occhi del giocatore

`scatti/`, uno per ogni momento:

- `_1_da_lontano`: quando la scopri;
- `_2_da_vicino`: mentre ti guarda;
- `_3_si_stacca` e `_3b_si_stacca`: al 35% e al 60% del distacco;
- `_4_ravvicinato`: l'oblò visto da vicino.

`foglio.jpg` li mette tutti insieme.

Sono presi con il Player vero e la Risalita da sola (`risalita.tscn`), con l'ambiente della sala, al buio e senza torcia. Fuori dalle porte della Risalita c'è un fondo nero, perché lì la sala non è caricata. Per questo in `ObloServizio_1_da_lontano` la porta di C3, in fondo al corridoio, si vede come un rettangolo nero. La macchia rosa sul soffitto, nello stesso scatto, è la luce di lei che esce dall'oblò.

Come rifarli (sotto il `render.lock`):

```
xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
     --script res://tests/run.gd -- res://tests/scatti_oblo_lei.gd <cartella>
```

## Controlli

- `godot/tests/test_oblo_lei.gd`, in CI, verifica che:
  - prima del blackout non succeda niente;
  - lei compaia solo fuori vista e resti mentre la guardi;
  - l'occhio segua il giocatore;
  - se ne vada se il giocatore guarda via o si avvicina, e lo faccia una volta sola;
  - lo stato si salvi;
  - tutte le ossa di lei restino dentro la vasca e dietro il vetro.
- Il controllo di posizionamento, zona `risalita`, ha uno stato `risalita_oblo` con lei ferma dietro i tre vetri: 0 casi da correggere.
- Memoria: le texture sono quelle che il gioco ha già, e il modello e i materiali di lei sono condivisi con la sala. Lei esiste solo mentre si vede. Appena compare, fuori vista, una camera nascosta guarda il vetro per 4 fotogrammi, così la prima volta che il giocatore la vede il gioco non scatta.
