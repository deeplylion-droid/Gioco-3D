# Collaudo dei tentacoli morbidi di lei (23 ottobre, notte)

Base: `lavoro/godot` **86ad5f95** (lavoro/grafica-tentacoli 16a35834). Scene: tuffo, lei che sbuca, inseguimento
(gli otto posti del test), statua.

## Come è fatto

- `godot/tests/collaudo/sonda_lei.gd` registra lo scheletro di lei fotogramma per fotogramma, come fanno i test di grafica:
  - modi `tuffo`, `sbuca` e `inseguimento`;
  - le ossa si leggono nel segnale `modification_processed` dell'ultimo modificatore, cioè dopo tuffo e morbidezza. Fuori dal segnale le loro modifiche non si vedono;
  - la pelle a riposo di tutte le mesh si salva una volta sola.
- `godot/tests/collaudo/geometria.gd` scrive la geometria vera (le mesh, non le collisioni): sala principale al ritorno e sala della torre.
- `tools/collaudo/analisi_lei.py` rifà la pelle deformata.
- `tools/collaudo/spessore_lei.py`, per ogni tratto dei tentacoli:
  - prende il raggio della pelle attorno all'asse (75° percentile: 4-9 cm, 5,6 di mediana);
  - prende la distanza dell'asse dalla superficie più vicina, nei punti a un quarto, metà e tre quarti;
  - se l'asse è più vicino del raggio, il tubo entra di raggio meno distanza (si contano le entrate oltre 1 cm).
- `tools/collaudo/sezione_lei.py` disegna una sezione di un tentacolo (pelle e superfici).

I test di grafica (`test_morbidezza*.gd`) passano tutti: sbuca 16/16, inseguimento 56/56, statua 5/5. Però guardano l'asse con 1 cm di tolleranza contro le collisioni, e l'inseguimento solo i tratti che attraversano.

## T1: il tubo dei tentacoli entra nelle superfici

| Scena | Durante | Alla fine (posa ferma) | Dove |
|---|---|---|---|
| Inseguimento, grata | fino a 28 tratti su 132, fino a **9,8 cm** (2,3 s) | 5 tratti | struttura ins_A, tubo 3 |
| Inseguimento, sb1 | 7 tratti, fino a **8,3 cm** | 5 tratti | struttura ins_A |
| Inseguimento, scolo_2 | 16 tratti fino a 8 cm, solo a 0,4 s | 0 | struttura ins_A |
| Inseguimento, scolo_1 | 3 tratti fino a 5,8 cm | 1 | pompa 2 |
| Inseguimento, vasca_0, vasca_1, vasca_2, scolo_0 | al più 2 tratti, per un attimo | 0 | |
| Lei che sbuca | fino a 18 tratti, fino a **6,2 cm** | 9 tratti | pareti della fossa, vasca bimbi 1, strisce di bava |
| Tuffo, affacciata | 9 tratti fino a 6 cm | 9 (ferma) | punte 05 e 06 sul pavimento, strisce di bava a terra, fossa |
| Tuffo, il salto | 10 tratti fino a 7,1 cm in 9 fotogrammi su 27 | 2 | fossa, vasca bimbi 1 |
| Statua | la morbidezza è spenta: i tentacoli restano quelli della posa | | |

Correzione proposta (passata a grafica):
- nella collisione della morbidezza, tenere l'asse fuori di almeno il raggio del tratto, non di 0;
- nei test, contare l'asse più il raggio.

Sospesi: nelle pose misurate lei è in acqua o affacciata sul bordo, quindi punte lontane da ogni superficie sono normali. Non ho segnato tentacoli sospesi.

Nota: la prima versione di questi numeri (6-13 cm, 34 tratti nella posa finale di lei che sbuca) era sbagliata. Era misurata sulla posa prima dei modificatori, e i numeri sopra la sostituiscono.
