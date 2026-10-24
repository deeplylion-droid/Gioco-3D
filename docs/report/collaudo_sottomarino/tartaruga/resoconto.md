# Collaudo dell'ambiente: tunnel sottomarino, tratto della tartaruga (315-390 m)

Base: lavoro/sottomarino ee20554a. Ho trovato e documentato, senza correggere niente.

Scatti presi dal motore con i materiali veri:
- dalle due banchine (5 m dall'asse, all'altezza degli occhi) e dall'acqua (nel canale, 2 m dall'asse), ogni 6 m;
- tre direzioni per ogni punto: avanti verso l'approdo, verso il muro vicino, verso il muro di fronte;
- uno scatto ravvicinato di ogni oggetto piccolo;
- gli stessi scatti senza la luce della camera, cioè senza torcia.

## Difetti

1. **Reti con le stelle quasi invisibili senza torcia** (foglio `difetto_reti_al_buio.jpg`):
   - quella a 388 m, sul muro di x -20,7, non si vede da nessuna banchina;
   - quella a 333 m si vede appena dalla banchina di fronte;
   - quella a 325 m si vede solo dalla sua banchina.
   La luce delle lampade al muro non le raggiunge. Con la torcia invece si vedono bene: le stelle sono attaccate alla rete e la rete ha i chiodi.

## Da valutare

- **Le macerie a 348 m**: dalla banchina destra appaiono come una lastra di mosaico piatta e alta che chiude il passaggio (`da_valutare_macerie_348.jpg`). Da vicino sono lastre impilate, ma da lontano sembrano un muro liscio.
- **Il buco nella volta a circa 345 m**: dentro è una superficie scura e piatta, con i ferri d'armatura sottili. Dal basso si legge come un buco nel buio, e va bene così.
- Nel sandbox la luce è senza GI. Verso 381-390 m, dove comincia l'abisso, è molto buio, ma è la luce voluta dell'abisso.

## Passati

- **Distanze vere** (soglia 1 cm, 139 oggetti nel tratto): tutti attaccati, lo stacco più grande è 6 mm (un gommone).
  - La tartaruga è appesa con tre catene, attaccate alle piastre sulla volta e al guscio.
  - I due faretti hanno la staffa sul muro.
  - Le stelle sono sulla rete.
- **Controllo di posizionamento** (stati sottomarino_t0, t1, t2): nessun caso in questo tratto. I 6 casi nuovi sono tutti fra i pesci (240-315 m, ancora in correzione): due mensole dentro le lampade e quattro pesci staccati dalla mensola. Sono in `controllo_posizionamento.md`.
- **Gommoni**: le corde arrivano agli anelli del muro.
- Lampade al muro e oblò attaccati; niente sulle banchine oltre all'ostacolo.

## Fogli

| File | Cosa contiene |
|---|---|
| `tartaruga_avanti.jpg`, `tartaruga_muro.jpg`, `tartaruga_fronte.jpg` | gli scatti del giro |
| `tartaruga_mire.jpg`, `tartaruga_vedute.jpg` | gli oggetti da vicino |
| `tartaruga_buio_avanti.jpg`, `tartaruga_buio_muri.jpg` | gli stessi scatti senza torcia |
