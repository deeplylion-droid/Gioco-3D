# Raffinamento del capitolo 1: proposte di grafica

Area: prestazioni, scatti, memoria, caricamenti e ripartenze, peso della build, stabilità e opzioni grafiche del menu.
Solo proposte scritte: nel gioco non cambia niente finché l'utente non dà il via. Non ci sono immagini già fatte per
questi temi, quindi le proposte sono senza immagini (niente scatti nuovi, come chiesto).

## grafica-1 Ripartire più in fretta dopo la morte

- Zona: tutte, soprattutto torre, condotte, tunnel e fiume (dove si muore di più).
- Cosa non va oggi, visto dal giocatore: dopo la morte si aspettano 5-10 secondi prima di riprendere a giocare. In un
  inseguimento, dove si muore e si riprova, l'attesa spezza la tensione più dello spavento.
- Proposta:
  - A) **Togliere il lavoro ripetuto, senza cambiare cosa succede** (consigliata). Oggi a ogni ripartenza la sala si
    ricarica da capo, e probabilmente rifà cose che servono solo la prima volta (per esempio il "riscaldamento" che
    disegna le zone fuori vista per non avere scatti dopo: da verificare con le misure). Si misura pezzo per pezzo
    dove vanno i secondi e si tolgono quelli ripetuti. Obiettivo: 2-4 secondi. Il giocatore vede la stessa morte e la stessa ripartenza, solo più corta.
  - B) Ripartire senza ricaricare la sala: si rimettono a posto solo il giocatore e gli oggetti. Sarebbe quasi
    istantaneo, ma è proprio il punto dove c'era il crash delle ripartenze della 0.3.17: rischio alto, sconsigliata.
  - C) Lasciare i tempi come sono e rendere l'attesa più breve a sentirla, con una dissolvenza più lunga e un suono.
    È una scelta di stile più che una correzione.
- Costo: medio (A). Rischio: basso con A, perché ogni ripartenza resta controllata dalla "Prova su Vulkan" in CI
  (morte e ripartenza in torre, inseguimento, tunnel e fiume).
- Immagini già fatte: nessuna.

## grafica-2 Il gioco in un solo file anche nelle prossime versioni

- Zona: la Release (il file che l'utente scarica).
- Cosa non va oggi, visto dal giocatore: l'exe unico, quello che si avvia con un doppio clic senza scompattare, pesa
  1922 MB. Il limite di GitHub è 2 GB e la CI lo pubblica solo sotto i 1950 MB. Con la prossima aggiunta di modelli o
  texture l'exe unico non uscirà più, e resterà solo lo zip da scompattare.
- Proposta:
  - A) **Alleggerire le texture degli oggetti piccoli e della torre, da 2048 a 1024** (consigliata). Sono gli oggetti
    che non si guardano mai da vicino: props degli interni, degli ambienti tecnici e dell'arredo della risalita, e le
    normal e ORM della torre, come già nella sala. Risparmio stimato circa 290 MB, quindi spazio per diverse versioni.
    Prima di metterlo nel gioco, scatti prima e dopo dal motore degli oggetti che si vedono più da vicino (estintori,
    leve, sedie), da approvare.
  - B) Rinunciare all'exe unico e pubblicare solo lo zip, come già per Linux: zero lavoro e nessuna perdita di
    qualità, ma ogni volta bisogna scompattare.
  - C) Pubblicare due file da mettere nella stessa cartella (l'exe e il pacchetto dei dati), senza zip: niente da
    scompattare, ma due file da scaricare.
- Costo: piccolo (A: poche righe in uno strumento, più gli scatti per l'approvazione). Rischio: basso, si vede solo
  avvicinandosi molto a un oggetto piccolo; la medusa (Jilly) e le superfici grandi della sala non si toccano.
- Immagini già fatte: nessuna. Il dettaglio dei pesi è in `docs/tecnico/peso_build.md` (lavoro/godot).

## grafica-3 Gli ultimi scatti al primo uso

- Zona: zaino (primo spruzzo) e i primi secondi di ogni effetto nuovo.
- Cosa non va oggi, visto dal giocatore: la prima volta che si vede un effetto, il gioco può fermarsi per un attimo
  mentre la scheda video prepara lo shader. Dal 18 ottobre nel GDD c'è ancora "resta da risolvere il primo spruzzo
  dello zaino". Aspirazione e geyser sono già risolti; prima di lavorarci si verifica se lo spruzzo blocca ancora.
- Proposta:
  - A) **Aggiungere al riscaldamento di oggi gli effetti che mancano** (consigliata): lo spruzzo dello zaino e gli
    altri effetti che si vedono per la prima volta a gioco iniziato. Si misurano con lo stesso test che già controlla
    "niente fotogrammi sopra 100 ms" all'ingresso della torre.
  - B) Usare la compilazione degli shader in anticipo di Godot, all'esportazione: il pacchetto contiene già gli shader
    pronti per DirectX 12 e Vulkan, e il primo avvio non compila quasi niente. È la soluzione più completa, ma il
    pacchetto cresce (da misurare) e va provata bene su tutti e due i driver: meglio dopo grafica-2.
  - C) Lasciare così.
- Costo: piccolo (A), medio (B). Rischio: basso (A); medio (B), per il peso e perché è una funzione nuova del motore.
- Immagini già fatte: nessuna.

## grafica-4 La qualità grafica giusta già al primo avvio

- Zona: opzioni grafiche del menu, primo avvio.
- Cosa non va oggi, visto dal giocatore: al primo avvio la qualità è sempre "alto", per tutti. Su un PC debole il gioco
  scatta finché il giocatore non trova da solo le opzioni; su un PC forte resta sotto quello che potrebbe dare. Le
  opzioni ci sono (basso, medio, alto, ultra), ma chi gioca un horror di solito non le apre.
- Proposta:
  - A) **Scelta automatica al primo avvio, con una prova di pochi secondi dietro la schermata di caricamento**
    (consigliata): il gioco misura quanto va fluido e sceglie il preset più alto che tiene i fotogrammi. Nelle opzioni
    si legge "scelto in automatico: medio" e si può cambiare come oggi. È la più precisa, perché misura il PC vero.
  - B) Scelta in base alla scheda video (nome e memoria video): più semplice, ma meno precisa con le schede integrate e
    i portatili.
  - C) Chiedere al giocatore al primo avvio, dopo la calibrazione della luminosità, con quattro pulsanti.
- Costo: medio (A), piccolo (B e C). Rischio: basso; la nebbia viola e le luci restano come sono, cambia solo il
  preset di partenza, e una scelta fatta a mano dal giocatore resta sua.
- Immagini già fatte: nessuna.

## grafica-5 Avvio sicuro dopo un crash

- Zona: avvio del gioco, stabilità.
- Cosa non va oggi, visto dal giocatore: se il gioco si chiude di colpo per colpa della scheda video o del driver,
  al riavvio si chiude allo stesso modo, e il giocatore non sa cosa fare. È già capitato in due modi: il crash delle
  ripartenze su Vulkan della 0.3.17, e il limite di DirectX 12 trovato sui PC senza scheda video (corretto nella
  0.3.18). Il Continua dall'ultimo checkpoint c'è già, ma serve a poco se il
  gioco non parte.
- Proposta:
  - A) **Se l'ultima partita si è chiusa di colpo, al riavvio il gioco propone "Avvio sicuro"** (consigliata): qualità
    "basso" e l'altro driver grafico (Vulkan invece di DirectX 12, o il contrario), con un solo pulsante. Se va,
    resta così; il Continua funziona come sempre.
  - B) Una voce fissa nelle opzioni, "Driver grafico: Vulkan / DirectX 12", senza proposta automatica: serve solo a
    chi sa cosa cercare.
  - C) Lasciare così.
- Costo: medio (A), piccolo (B). Rischio: basso; quando non ci sono crash il gioco è identico a oggi.
- Immagini già fatte: nessuna.
