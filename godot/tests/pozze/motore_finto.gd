extends Node
## Un motore di lei finto per i test della stanza delle pozze (LeiPozze), finché non c'è quello di mascotte: non si vede
## e non si sente niente, tiene solo l'elenco di quello che LeiPozze gli chiede.

## [nome della fase, pozza, dati, fotogramma di fisica] per ogni fase.
var fasi: Array = []
## Le posizioni della luce, nell'ordine.
var luci: Array[Vector3] = []


func fase(nome: StringName, pozza: WaterTank, dati: Dictionary) -> void:
	fasi.append([nome, pozza, dati, Engine.get_physics_frames()])


func luce(posizione: Vector3) -> void:
	luci.append(posizione)


## Quante volte c'è stata la fase [param nome].
func quante(nome: StringName) -> int:
	return fasi.filter(func(f): return f[0] == nome).size()


## L'ultima fase [param nome] (o []).
func ultima(nome: StringName) -> Array:
	for i in range(fasi.size() - 1, -1, -1):
		if fasi[i][0] == nome:
			return fasi[i]
	return []
