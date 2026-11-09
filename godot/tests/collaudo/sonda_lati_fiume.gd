extends Node
## Collaudo riga del fiume (#130): conta le pareti e le barriere che non stanno sul bordo dell'acqua (FiumeGioco.lati_storti).
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/collaudo/sonda_lati_fiume.gd


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var f: Node3D = (load("res://scenes/risalita/fiume.tscn") as PackedScene).instantiate()
	add_child(f)
	while not bool(f.get(&"costruita")):
		await get_tree().process_frame
	var r: Dictionary = f.call(&"lati_storti")
	print("LATI: %d pareti storte, %d barriere storte, dove %s" % [r["pareti"], r["barriere"], str(r["dove"])])
	get_tree().quit()
