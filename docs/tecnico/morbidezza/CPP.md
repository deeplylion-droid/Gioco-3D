# Morbidezza in C++ (dopo la v0.3.12)

Nota per decidere se e quando portare il calcolo dei tentacoli morbidi (`MorbidezzaLei`) in C++.

## Perché

Con la pelle vera (24 ottobre) i tentacoli toccano molto di più il mondo, e in GDScript il costo è salito di circa il 50-70%. Sulla CPU del sandbox:

| Scena | Media | 95% |
|---|---|---|
| Lei affacciata | 3,0-4,4 ms | 4,5-6,8 ms |
| Tuffo, lei che sbuca | 3,8-6,3 ms | 7,4-16,9 ms |
| Inseguimento, grata | 5-7 ms | fino a 14 ms |

Su un PC vero sono frazioni di ms, ma la grata e i fotogrammi in cui lei compare restano i più cari. Quasi tutto il tempo è nel giro dei contatti (`_fuori`, `_tratti_fuori`, i giri delle lunghezze): migliaia di chiamate per fotogramma, dove in GDScript pesa la chiamata stessa più del conto. In C++ ci si aspetta 10-20 volte di meno.

## Cosa servirebbe

- **Una GDExtension** (godot-cpp per Godot 4.7) con una classe che fa i passi di una catena: punti, velocità, bersagli, sezioni, forme (piani e scatole) e griglia. `MorbidezzaLei` resta in GDScript per tutto il resto (accensione, posa, ossa, campana, acqua) e le passa i dati in array impacchettati.
- **Build:** la libreria compilata per Windows (l'exe del gioco) e Linux (la CI e il sandbox). In CI un passo in più con scons e il compilatore, prima dell'esportazione. Su Windows: compilazione incrociata da Linux con MinGW, o un job Windows.
- **Ripiego:** se la libreria manca, la stessa logica in GDScript (quella di adesso), così il gioco non si rompe.
- **Test:** gli stessi di adesso (`test_morbidezza*.gd`), che girano con tutte e due le versioni; la pelle vera deve dare gli stessi numeri.

## Quanto costa

Circa un giorno di lavoro di grafica: mezza giornata per la classe e il ripiego, mezza per la build in CI e su Windows, e la prova che i test diano gli stessi numeri. Il rischio maggiore è la build Windows in CI.
