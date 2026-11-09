extends Node
## Sonda: le posizioni delle lampade d'emergenza della torre dopo la costruzione a pezzi (Posa.fissa_al_muro e i 9 raggi
## sul retro di SalaTorre._emergenza), con l'md5 della lista. Per confrontare due versioni del codice: stesse posizioni,
## stesso md5. Anche quante mesh ha guardato ogni raggio (TORRE_TEMPI).
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/sonda_posizioni_emergenza.gd

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	var torre := (load("res://scenes/sala/torre/sala_torre.tscn") as PackedScene).instantiate()
	torre.set(&"costruzione_a_pezzi", true)
	add_child(torre)
	await torre.call(&"costruisci_a_pezzi", 50.0)
	var luci := torre.get_node_or_null(^"Luci")
	var righe: PackedStringArray = []
	for c in luci.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh is BoxMesh:
			var p := (c as Node3D).global_position
			righe.append("%s %.6f %.6f %.6f" % [c.name, p.x, p.y, p.z])
	var testo := "\n".join(righe)
	print(testo)
	print("EMERGENZA: %d lampade, md5 %s" % [righe.size(), testo.md5_text()])
	get_tree().quit()
