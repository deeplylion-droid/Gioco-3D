# La nebbia viola (da NotHuman)

La nebbia della stanza del medico, staccata dal gioco per usarla in un'altra scena Three.js. È una nebbia volumetrica vera, calcolata con la profondità della scena: non è un filtro colore.
- È più fitta in basso, a ciuffi che vanno col vento.
- Ha l'aria viola, i raggi del sole (anche solo dai vetri di una finestra), l'alone delle lampade e la polvere nella luce.
- Alla fine c'è un filtro colore, che porta le ombre al blu viola e le luci al bianco freddo.

## I file

- `nebbia_viola.js`: due passaggi per l'`EffectComposer` di Three.js:
  - `NebbiaViola`, la nebbia;
  - `ColoreViola`, il colore finale.

  Ci sono anche i valori del gioco, `NEBBIA_VIOLA` e `COLORE_VIOLA`.
- `esempio.html`: una stanza con una finestra, il sole e una lampadina.
  - Si apre da un server qualsiasi, per esempio `python3 -m http.server`, poi `esempio.html`.
  - Si trascina per guardarsi attorno, e N toglie e rimette la nebbia.

## Come si usa

Serve Three.js r150 o più nuovo, con WebGL 2. Il modulo importa da `three` e da `three/addons/…`; con le versioni vecchie il percorso è `three/examples/jsm/…`.

```js
import { NebbiaViola, ColoreViola } from "./nebbia_viola.js";

renderer.toneMapping = THREE.AgXToneMapping;
renderer.toneMappingExposure = 2.6;                      // i colori della nebbia sono tarati su questa esposizione
const rt = new THREE.WebGLRenderTarget(w, h, { type: THREE.HalfFloatType, samples: 4 });
rt.depthTexture = new THREE.DepthTexture(w, h);          // la nebbia ha bisogno della profondità
const composer = new EffectComposer(renderer, rt);
composer.addPass(new RenderPass(scene, camera));
const nebbia = new NebbiaViola(camera, {
  luci: [{ posizione: [0, 2.4, 0], forza: 0.18 }],       // le lampade (fino a 4)
  sole: { direzione: [0.47, -0.38, 0.8], forza: 1 },     // dove va la luce del sole (facoltativo)
  finestra: { origine: [-1.3, 1.0, -3.0], u: [1, 0, 0], v: [0, 1, 0], vetri: [[0, 0, 0.57, 0.62]] }, // facoltativa
});
composer.addPass(nebbia);
composer.addPass(new OutputPass());                      // tone mapping e sRGB
composer.addPass(new ColoreViola());
// a ogni fotogramma composer.render() al posto di renderer.render(); al ridimensionamento composer.setSize(w, h)
```

`nebbia.imposta({ ... })` cambia i valori mentre si gioca. Le misure sono in metri, col pavimento a `y = 0` (se no, `quota`).

## La finestra e i raggi del sole

- `sole.direzione` dice dove va la luce, dal cielo verso il basso.
- La `finestra` è un rettangolo sul muro:
  - `origine` è l'angolo in basso a sinistra;
  - `u` e `v` sono le direzioni del lato orizzontale e di quello verticale;
  - `vetri` sono i rettangoli trasparenti, in metri dall'angolo (`[u0, v0, u1, v1]`, fino a 8).
- Con la finestra il sole entra solo dai vetri, e nella nebbia si vedono i raggi. Il calcolo non guarda la geometria: la finestra deve corrispondere a un'apertura vera nel muro.
- Senza finestra il sole illumina tutta la nebbia. In un esterno conviene una `forza` bassa, per esempio 0,1.

## Regolarla

- **Luminosità:** con un'esposizione diversa da 2,6 si cambia `forza`, la luce di tutta la nebbia (con esposizione 1, circa 2,5).
- **Quanto è fitta:** `densita` è la nebbia ovunque, `strato` quella in più vicino al pavimento. `altezza` più alta tiene lo strato più basso.
- **I ciuffi:** `ciuffi` va da 0 (uniforme) a 1 (tutta a banchi). `scala` più bassa li fa più grandi. `vento` è in metri al secondo.
- **I colori:** `aria` è la nebbia al buio, `raggi` il sole, `caldo` l'alone delle lampade. Il colore finale si regola con `ColoreViola({ ombre, luci, tinta, contrasto, vignetta })`.
- **Scene grandi:** `lontano` (fin dove si calcola, 14 m), `scala` e `densita` più basse.
- **Quanto costa:** 20 passi per punto dello schermo. Sui telefoni `passi: 10`, o la scena disegnata più piccola.
- **Limiti:**
  - non funziona con `logarithmicDepthBuffer` né con `reverseDepthBuffer`;
  - la nebbia va subito dopo il `RenderPass`, prima del tone mapping;
  - `ColoreViola` va dopo l'`OutputPass`.

## In un altro motore

Il codice è per Three.js, ma la tecnica è un passaggio a schermo intero che si traduce in qualunque motore:
1. Dalla profondità si ricostruisce il punto visto.
2. Si cammina lungo il raggio con N passi, partendo ogni volta da un punto un po' diverso (rumore intrecciato).
3. A ogni passo la densità è la nebbia ovunque, più uno strato che cala con l'altezza, per un rumore 3D che scorre col vento.
4. Si accumulano la trasparenza e la luce:
   - l'aria;
   - il sole, con la fase di Henyey-Greenstein (g = 0,6) e la maschera dei vetri;
   - le lampade, che calano con il quadrato della distanza.
5. Alla fine il colore.

Lo shader GLSL è in `nebbia_viola.js`.
