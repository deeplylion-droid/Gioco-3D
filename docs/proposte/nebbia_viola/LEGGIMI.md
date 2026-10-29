# Nebbia viola nell'infermeria (prova, 29 ottobre)

La nebbia viola di NotHuman, il gioco dell'utente (originali in `assets_src/nebbia_viola/`), tradotta in Godot 4.7 Forward+ per una prova. Non è nel gioco: sta in `godot/proposte/nebbia_viola/`, che non si esporta.

- `nebbia_viola.gdshader`: la nebbia. È un quad a schermo intero figlio della camera, prima del tone mapping, che legge lo schermo e la profondità (in Godot è rovesciata).
  - Per ogni punto cammina lungo il raggio per 20 passi, con l'inizio sfalsato.
  - La densità è nebbia ovunque più uno strato in basso, a ciuffi che vanno col vento.
  - Mette l'aria viola, l'alone delle lampade (fino a 4) e la polvere.
  - Il sole e la finestra dell'originale non ci sono.
- `colore_viola.gdshader`: dopo il tone mapping porta le ombre al blu viola e le luci al bianco freddo, con contrasto e vignetta.
- `nebbia_viola.gd` (`NebbiaViolaProva`): li mette sulla camera. `attiva` è l'interruttore, `forza` la luce della nebbia, `imposta_luci()` le lampade.
- `scatti_nebbia.gd`: gli scatti.

Scatti dagli occhi del giocatore nell'infermeria, stessa camera: com'è ora, e con la nebbia a forza 1,2 e 2,2. Sono in `foglio_infermeria.jpg` e nei singoli JPG. Le lampade usate per l'alone sono le 4 più forti della stanza, a forza 0,18: la luce del soffitto, il negatoscopio e le due rosse d'emergenza. L'originale è tarato su AgX con esposizione 2,6; qui l'esposizione è 1,15.

Costo (`misure.txt`): sul renderer software (llvmpipe, CPU) a 1280x720 la nebbia aggiunge 135-185 ms a un disegno di 700-815 ms, cioè circa il 20%. Su una scheda video vera dovrebbe stare intorno a 1-2 ms, ma non è misurato.
