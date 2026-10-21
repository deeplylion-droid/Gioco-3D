extends Node
## Prova (non è nella CI): la torre costruita a pezzi, quanto dura il fotogramma più lungo.

var _ultimo := 0
var _durate: Array[float] = []
var _reg := false

func _ready() -> void:
	_run.call_deferred()

func _process(_d: float) -> void:
	var ora := Time.get_ticks_usec()
	if _reg and _ultimo > 0:
		_durate.append((ora - _ultimo) / 1000.0)
	_ultimo = ora

func _run() -> void:
	var scena := load("res://scenes/sala/torre/sala_torre.tscn") as PackedScene
	for i in 10:
		await get_tree().process_frame
	var torre := scena.instantiate()
	torre.set(&"costruzione_a_pezzi", true)
	_reg = true
	var ta := Time.get_ticks_usec()
	add_child(torre)
	print("ADD_CHILD %.0f ms" % ((Time.get_ticks_usec() - ta) / 1000.0))
	await torre.call(&"costruisci_a_pezzi")
	_reg = false
	var d := _durate.duplicate()
	d.sort()
	print("PEZZI fotogrammi %d, il più lungo %.0f ms, mediana %.0f ms, checkpoint %d, scivoli %d" % [d.size(), d[-1], d[d.size() / 2], (torre.get(&"checkpoint") as Array).size(), (torre.call(&"corpi_scivolo") as Array).size()])
	get_tree().quit()
