extends Node
## Prova (non è nella CI): quanto ferma il gioco mettere nella scena la torre già caricata.

var _ultimo := 0
var _durate: Array[float] = []

func _ready() -> void:
	_run.call_deferred()

func _process(_d: float) -> void:
	var ora := Time.get_ticks_usec()
	if _ultimo > 0:
		_durate.append((ora - _ultimo) / 1000.0)
	_ultimo = ora

func _run() -> void:
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(10, 2, -15)
	cam.make_current()
	var scena := load("res://scenes/sala/torre/sala_torre.tscn") as PackedScene
	for i in 30:
		await get_tree().process_frame
	_durate.clear()
	var t0 := Time.get_ticks_usec()
	var torre := scena.instantiate()
	var t1 := Time.get_ticks_usec()
	add_child(torre)
	var t2 := Time.get_ticks_usec()
	for i in 10:
		await get_tree().process_frame
	print("ISTANZA instantiate %.0f ms, add_child (_ready) %.0f ms, fotogrammi dopo: %s" % [(t1 - t0) / 1000.0, (t2 - t1) / 1000.0, str(_durate.map(func(d): return roundi(d)))])
	get_tree().quit()
