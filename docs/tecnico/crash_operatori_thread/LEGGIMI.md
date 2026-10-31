# Crash con GDScript su più thread (difetto di Godot 4.7.2)

## Cosa si è visto

Un `signal 11` rarissimo nella CI il 30 ottobre (run 41114234700, `test_morbidezza_tunnel`, alla presa, ai primi
fotogrammi in cui lei compare). La riga era `morbidezza_lei.gd:983`, `parti_usec["giri"] += ...`, nel thread
principale, mentre gli altri tentacoli si calcolavano sui thread del `WorkerThreadPool`. Il backtrace C++ aveva un solo
frame (`libc.so.6(+0x45330)`): è una chiamata a un puntatore nullo. In 37 giri in locale non si è mai ripetuto.

## Causa

È un difetto della VM di GDScript, in `modules/gdscript/gdscript_vm.cpp` di 4.7.2, righe 761-821, `OPCODE_OPERATOR`.

- È l'operatore che il compilatore usa quando almeno un operando non ha un tipo noto: un elemento di un `Array` o di
  un `Dictionary` senza tipo, per esempio `v - fo[9]` o `d["a"] += 1`, oppure due `Object`.
- La prima volta che quell'istruzione gira, sotto un mutex, scrive nel bytecode la firma dei tipi (`ip + 5`), il tipo
  del risultato (`ip + 6`) e infine il puntatore della funzione (`ip + 7`).
- Le volte dopo, chi trova la firma prende la via veloce senza il mutex e chiama quel puntatore.
- Se un secondo thread arriva sulla stessa istruzione proprio mentre il primo la sta scrivendo, vede già la firma ma
  non ancora il puntatore. Chiama allora il segnaposto 0 (`gdscript_byte_codegen.cpp`, righe 630-641) e va in crash.
- Succede solo alla prima esecuzione di ogni istruzione nel processo, e solo con due thread insieme sulla stessa riga.
  Per questo nel gioco capitava solo alla prima comparsa di lei.
- `OPCODE_OPERATOR_VALIDATED`, che si usa quando tutti e due gli operandi hanno un tipo noto, prende la funzione da una
  tabella fissa: non ha il problema.
- Nell'export release, che è quello che si gioca, passano da `OPCODE_OPERATOR` anche `int / int` e `int % int` (e
  gli stessi con `Vector2i`, `Vector3i`, `Vector4i`) pur se tipizzati. Nel debug invece vanno sempre per la via lenta.

## Regola per il codice che gira su più thread

Nelle funzioni che girano sui thread, e in tutto quello che chiamano:
- ogni operatore deve avere operandi di tipo noto;
- un elemento di un `Array` o di un `Dictionary` senza tipo si converte prima: `(fo[9] as Vector3)`, `int(d["a"])`,
  `float(t[2])`, oppure `var f: Vector3 = fo[9]`;
- niente `int / int` né `int % int`: per esempio `j + 1 if j + 1 < n else 0` invece di `(j + 1) % n`;
- niente confronti fra `Object`.

## Prova

`stress_operatore.gd`: ogni giro compila uno script nuovo (bytecode freddo) con 3000 righe e lo fa partire su 4
thread insieme.

```
godot --headless --script docs/tecnico/crash_operatori_thread/stress_operatore.gd -- senza_tipo 1000 3000
godot --headless --script docs/tecnico/crash_operatori_thread/stress_operatore.gd -- con_tipo 1000 3000
```

Risultati del 30 ottobre, Godot 4.7.2 ufficiale, 4 CPU:

| Modo | Righe | Risultato |
|---|---|---|
| `senza_tipo` | `d["a"] += 1` e `r = v - arr[0]` | `signal 11` al primo giro, 4 volte su 4, con la stessa firma del crash della CI |
| `con_tipo` | `a += 1` su un membro `int` e `r = v - w` con `var w: Vector3 = arr[0]` | 1000 giri, nessun crash |

Il modo `senza_tipo` va in crash apposta: non va messo nella CI.
