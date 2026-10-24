# Giro finale dagli occhi del giocatore su v0.3.12 (24 ottobre, mattina)

Base: `lavoro/godot` **ce0e0c84** (v0.3.12). Squadra collaudo. Giro su tutta la strada dal risveglio alla torre e all'inseguimento, guardando soprattutto le zone cambiate stanotte, più i tentacoli di lei con la pelle vera.

**Verdetto:**
- **interni, torre e inseguimento sono a posto**: nessun oggetto sospeso, staccato o compenetrato negli scatti;
- **tentacoli a posto**, tranne scolo_2, che il coordinatore ha rinviato a dopo la Release;
- **il fiume e la risalita non li ho rigirati su ce0e0c84**: il lock dei render è rimasto bloccato (sotto).

La CI di ce0e0c84 (run 40065108360) è passata tutta, compreso il controllo di posizionamento e quello dei varchi.

## Come è stato fatto

- **Giro dagli occhi** con `tests/collaudo/giro.gd` e `COLLAUDO_SEMPLICE=1`: ogni superficie ha un materiale semplice del suo colore medio, visibile da tutte e due le parti. Le stesse liste di punti dei collaudi precedenti, quattro scatti per punto, più le vedute ravvicinate degli oggetti piccoli:

  | Zona | Scena e stato | Scatti |
  |---|---|---|
  | interni | `interni.tscn`, inizio | 278 |
  | torre | `sala_torre.tscn`, aperto | 305 |
  | torre e inseguimento | `sala_torre.tscn`, inizio | 479 |

  Ogni scatto è stato guardato nei fogli; i casi dubbi sono stati ingranditi uno per uno.
- **Tentacoli**: con `tests/collaudo/sonda_lei.gd` lo scheletro si legge dopo i modificatori (TuffoLei, MorbidezzaLei). La pelle deformata si rifà e si misura contro le mesh visibili (`tools/collaudo/spessore_lei.py`), come nel ricontrollo di af5ae492.

## Tentacoli di lei (pelle vera)

| Momento | Su ce0e0c84 | |
|---|---|---|
| Statua (morbidezza 0) | ferma; test della CI passato | a posto |
| Affacciata | 0 | a posto |
| Tuffo | 3 tratti della radice (_01) fino a 7,4 cm, solo alla fine, quando entra nell'imbocco della condotta | non si vede: è dentro l'imbocco |
| Lei che sbuca | al massimo 1 tratto, 2,5 cm, all'inizio; 0 alla fine | a posto |
| Inseguimento: vasca_0, vasca_1, scolo_0, scolo_1, grata, sb1 | 0 (scolo_1 ora corretto) | a posto |
| Inseguimento: vasca_2 | la punta 04_09 per 2 fotogrammi, 4,3 cm | non si vede |
| Inseguimento: scolo_2 | 15 tratti fino a 8,7 cm nel pavimento della sala, da 0,23 a 0,5 s, sotto 60 cm d'acqua; lei sale da 5 m sotto, perché scolo_2 manca in PROFONDITA | **rinviato a dopo la Release** (decisione del coordinatore) |

## Interni (278 scatti)

Corridoio, spogliatoi, stanzino, docce, lavapiedi, vedute ravvicinate di Polaroid, zaino, armadietti, ante, braccioli, rubinetti, soffioni, fischietti, luci d'emergenza, neon, radio, ricetrasmittente, salvagenti e sprinkler: tutti appoggiati o fissati. Foglio d'esempio: `fogli/interni_giro_00.jpg`.

**int017 e int019 non sono un difetto.** In questi due punti (nella sala -7,5 e -3,5, 1,6, 41; negli interni 2,2 e 6,2, 1,6, 0,1) la camera vede solo superfici grigie in tutte le direzioni (`fogli/int017_int019_dentro_il_muro.jpg`).
- Misurando i raggi sul glTF del corridoio, i due punti cadono dentro il muro sud del corridoio, spesso 20 cm (z da 0 a 0,2 negli interni).
- Il muro è uguale anche nella versione del 23 alle 11:54, prima di tutte le modifiche agli interni.
- Negli scatti vecchi, con i materiali veri, il muro non si vedeva dal di dentro, quindi si vedeva la stanza dietro. Il materiale semplice del giro si vede da tutte e due le parti.
- La Polaroid 2 spostata sullo sportello è a 7 m e non c'entra; lo squalo parte a 14 m. È solo un punto della lista dentro il muro, dove il giocatore non arriva.

## Torre (305 scatti) e inseguimento (479 scatti)

Visti e a posto:
- scale, passerelle, ringhiere aperte dove passano canali e tubi, imbocchi e vasche d'arrivo;
- lampade a palo, lampade a muro, lampade appese col cavo, fari con i perni nella staffa, lampade rosse d'emergenza;
- led degli imbocchi (MultiMesh), sui tubi;
- Polaroid 10 sul lettino;
- cartelli: il "non correre" storto è voluto ("penzolante");
- vasche dell'inseguimento con le paperelle che galleggiano, le scalette, il filtro, gli scivoli che finiscono nelle vasche.

La scia rosa sul bordo della vasca 1 (difetto 3 del collaudo del 22) ora è stretta come il bordo e appoggiata sopra (`appoggia = true`), e negli scatti non pende.

Fogli d'esempio: `fogli/torre_vedute_01.jpg`, `fogli/inseguimento_vasche.jpg`, `fogli/inseguimento_vedute_luci.jpg`.

## Fiume e risalita: non rigirati su ce0e0c84

**Il blocco:**
- Il giro della risalita (545 punti) l'ho fermato per stare nei tempi. Il suo Xvfb (pid 5987, display :103) è rimasto vivo da solo e tiene aperto il `render.lock`.
- Il permesso di chiuderlo mi è stato negato, e anche quello di usare un lock a parte come proposto dal coordinatore. Da quel momento su questa macchina non è partito nessun Godot.
- Ho fermato i miei giri in attesa sul lock vecchio, così non può partire niente insieme ad altro se il lock si libera.

**Cosa resta scoperto:**
- Il fiume è cambiato stanotte: roccia lungo le banchine e nei buchi delle conche, riva dell'imbarco, curva verso la piazza, testa del muro della piazza, colonna del bivio 3, oggetti a terra 1 mm sopra il pavimento; piolo e piastra della risalita che seguono il salvagente.
- L'ultimo giro dagli occhi del fiume è sul candidato v0.3.9 (ceaeacd0).
- Su ce0e0c84 passano i test del fiume, della risalita e il controllo di posizionamento della CI, ma il giro dagli occhi non c'è. Lista pronta: `tutto_fiume.txt`, 261 scatti, circa 25 minuti.

## Strumenti nuovi

- `tests/collaudo/sonda_punto.gd`: elenca i nodi visibili il cui riquadro contiene dei punti, e le distanze dalle collisioni lungo i 6 assi.
- `tools/collaudo/gltf_punti.py`: le stesse distanze, ma sui triangoli di un glTF, senza Godot.
