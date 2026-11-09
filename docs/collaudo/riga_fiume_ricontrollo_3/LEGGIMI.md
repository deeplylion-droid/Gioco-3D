# Terzo ricontrollo della riga del fiume (#130): `lavoro/riga-fiume` 812f163f (9 novembre)

Squadra collaudo. Ho confrontato 812f163f con fed6fd28 e con main d01e5a95. Rispetto a e3104cd2, main non cambia niente nel fiume, quindi per main valgono gli scatti «prima» di `../riga_fiume_ricontrollo_2/`. Strumenti e scatti sono quelli di sempre: fiume da solo, luci del blackout, ambiente della sala, preset alto. Per le fessure ho caricato anche la risalita intera. Nel gioco non ho cambiato niente.

**Esito: superato su tutti i 7 punti.**

## 1. Le sei pinne: sparite
`fogli/pinne_tre_versioni.jpg` mette affiancati main, fed6fd28 e 812f163f, schiariti 2 volte, dagli occhi e dal basso.
- Su 812f163f gli angoli delle conche hanno pareti continue, senza spigoli di piastrelle che scendono nell'acqua.
- Su main, negli stessi punti, si vedeva la riga di cielo.

## 2. Triangoli e barriere con l'acqua dai due lati: 0
Ho controllato con i miei strumenti:
- **Pareti** (`dati/pareti.txt`): 2 638 triangoli. 0 non guardano l'acqua, 0 hanno l'acqua dai due lati o da nessuno, 0 hanno la normale contro la faccia.
- **Barriere** (`dati/barriere.txt`): 2 638 triangoli. Su fed6fd28 erano 18 con l'acqua dai due lati, ora 0.
  - Ne resta 1 col pavimento dai due lati, a (21,61; 5,91), che c'era già su main.
  - Non chiude nessun passaggio della griglia (punto 4). Il controllo di grafica (`lati_storti`) però la conta come buona, e i due conteggi non coincidono: va guardata.
- **Il controllo di grafica** (`sonda_lati_fiume.gd` e test_fiume_gioco): 0 pareti e 0 barriere storte.

## 3. Le giunte fra toppa e striscia, il magenta senz'acqua
- **Magenta senz'acqua sui 221 scatti** (`dati/magenta_senza_acqua.txt`): 23 scatti con magenta, gli stessi di fed6fd28 con gli stessi pixel. Nessuno è nuovo o più grande; su main erano 100.
- **Confronto scatto per scatto con fed6fd28:** cambiano solo i riflessi animati dell'acqua, più il pezzetto di pinna sparito a Giusto2 a 1 m (`fogli/ciambella_e_giunte.jpg`). Nessuna fessura o riga nuova sulle giunte spostate di 3 cm.
- **La mappa al bivio:**
  - a 5 cm (`dati/mappa_bivio.txt`): tutta acqua;
  - a 2 mm intorno a (−3,40; 25,15): tutti i punti sono acqua, tranne quello esatto, dove il calcolo «dentro il poligono» sbaglia.

  Non è un buco, quindi il «buchetto di 5 cm» del primo ricontrollo era lo stesso errore del test e non un difetto.

## 4. Collisioni: strada uguale
- **Le barriere** (`dati/confronto_barriere_*.txt`):
  - rispetto a fed6fd28: 0 passaggi chiusi e 0 aperti in più, e le coppie di punti di pavimento sono identiche;
  - rispetto a main: restano le 3 coppie sulle righe della griglia al bordo dell'acqua, già spiegate nel secondo ricontrollo.
- **I raggi** (`dati/confronto_raggi_fed6fd28.txt`): rispetto a fed6fd28 cambiano solo quelli che toccavano le barriere delle pinne.
- **test_fiume_gioco:** 35 controlli su 35, col giro in ciambella e col controllo nuovo dei lati. **test_fiume:** 35 su 35.

## 5. Le fessure: la spiegazione di grafica regge
`fogli/fessure_risalita_intera.jpg`. Ho rifatto gli stessi 23 scatti con tutta la risalita caricata (fiume, corridoi, infermeria), sia magenta senz'acqua sia normali (`dati/magenta_risalita_intera.txt`).
- Le fessure fra capanna e parete (Sbagliato1 e 2 a 25 m, Imbarco 1 m), sotto la valvola verde (Uscita 1 m) e la porta dell'approdo (Uscita 9 m) danno 0 pixel magenta.
- Negli scatti normali dietro c'è il corridoio illuminato dell'ingresso o della porta di servizio.
- Il magenta resta solo nelle due viste dall'alto a 14 m, una posizione che il giocatore non raggiunge.

## 6. Cielo e posizionamento
- **controllo_cielo:** 686 posti, 0 col cielo, compreso il fiume dalla ciambella; 0 fessure sottili. Gli unici 18 posti col cielo guardano dalla cupola di vetro della sala, come voluto.
- **controllo_posizionamento:** 0 da correggere.

## 7. Le pareti vicino alla ciambella
`fogli/ciambella_e_giunte.jpg`: sono identiche a fed6fd28, con le piastrelle illuminate dalla ciambella (scelta A).

## Strumenti
In `godot/tests/collaudo/`:
- quelli dei ricontrolli prima;
- `fiume_giro.gd` con `SOLO` (solo alcuni scatti) e `RISALITA=1` (tutta la risalita);
- `sonda_mm_fiume.gd`: la griglia di 2 mm.
