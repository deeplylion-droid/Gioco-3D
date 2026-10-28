extends Node
## Misura: la sala principale messa e tolta tre volte, ogni volta senza uno dei suoi figli diretti: il figlio senza il
## quale la memoria non cresce più è quello che la trattiene (test_memoria_morti del 28 ottobre).
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/misura_ricariche_sala.gd

const SALA := "res://scenes/sala_principale.tscn"
const GIRI := 3


func _ready() -> void:
	_run.call_deferred()


func _mb() -> float:
	return Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0


func _giri(pacchetto: PackedScene, senza: String) -> float:
	var misure: Array[float] = []
	for g in GIRI:
		var n := pacchetto.instantiate()
		if senza != "":
			var c := n.get_node_or_null(senza)
			if c:
				n.remove_child(c)
				c.free()
		add_child(n)
		for i in 20:
			await get_tree().process_frame
		n.queue_free()
		for i in 15:
			await get_tree().process_frame
		misure.append(_mb())
	return (misure[-1] - misure[0]) / (GIRI - 1)


func _run() -> void:
	Game.pause_on_focus_loss = false
	var pacchetto := load(SALA) as PackedScene
	var prova := pacchetto.instantiate()
	var figli: Array[String] = []
	for c in prova.get_children():
		figli.append(String(c.name))
	prova.free()
	print("RICARICA intera: %+.2f MB per giro" % await _giri(pacchetto, ""))
	for f in figli:
		print("RICARICA senza %s: %+.2f MB per giro" % [f, await _giri(pacchetto, f)])
	Game.esci(0)
