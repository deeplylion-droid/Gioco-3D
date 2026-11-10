extends Node
## Spia di grafica-2 (0.3.24): a ogni fotogramma guarda il contatore delle pipeline 2D compilate ("canvas"); quando sale
## stampa il fotogramma, gli elementi 2D (CanvasItem) diventati visibili da quello prima e, per quelli con un materiale
## shader, lo shader. Si aggiunge alla radice (giro_squalo con GIRO_SPIA=1).

var _prima := {}
var _prima2 := {}
var _c := 0
var _f := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 1000
	_c = int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS))
	print("SPIA: canvas all'inizio %d" % _c)


func _visibili() -> Dictionary:
	var d := {}
	for n in get_tree().root.find_children("*", "CanvasItem", true, false):
		var ci := n as CanvasItem
		if ci.is_visible_in_tree():
			d[ci.get_instance_id()] = ci
	return d


func _process(_delta: float) -> void:
	_f += 1
	var ora := _visibili()
	var c := int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS))
	if c != _c:
		var nuovi: Array[String] = []
		# (la spia gira per ultima: quello che si è disegnato alla fine del fotogramma prima era già visibile allora)
		for id in _prima:
			if not _prima2.has(id) and is_instance_valid(_prima[id]):
				var ci: CanvasItem = _prima[id]
				var sh := ""
				if ci.material is ShaderMaterial and (ci.material as ShaderMaterial).shader:
					sh = " shader " + (ci.material as ShaderMaterial).shader.resource_path
				elif ci.material:
					sh = " materiale " + ci.material.get_class()
				nuovi.append("%s (%s%s)" % [ci.get_path(), ci.get_class(), sh])
		print("SPIA: fotogramma %d, canvas +%d (totale %d); visibili da poco: %s" % [_f, c - _c, c, nuovi])
		_c = c
	_prima2 = _prima
	_prima = ora
