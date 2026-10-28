extends Node
## Misura i blocchi (fotogrammi lunghi) lungo la strada del capitolo: fa girare un altro test (di serie
## test_strada.gd, che cammina dalla partenza alla torre caricando le stanze come nel gioco) e intanto misura il tempo
## vero di ogni fotogramma del ciclo principale. Stampa "BLOCCO" per ogni fotogramma sopra [constant SOGLIA_MS], in
## mezzo alle righe del test (così si vede in che tratto è), con le compilazioni di pipeline di quel fotogramma, e alla
## fine i 15 fotogrammi più lunghi.
## Con --headless misura il lavoro sulla CPU (istanze, costruzioni, script), senza disegno né shader. Col renderer
## vero misura anche shader e pipeline: per la cache vuota si sposta via prima user://shader_cache (non si cancella).
## Alla fine stampa anche "BLOCCHI_SOPRA_LIMITE: n", i fotogrammi sopra [constant LIMITE_MS] dopo i primi
## [constant AVVIO] (l'ingresso nella sala, nel gioco dietro lo schermo nero): la CI vuole 0.
## Uso (a tempo vero, senza --fixed-fps: i thread lavorano in tempo vero, il gioco deve fare lo stesso):
##   godot --headless --path godot --script res://tests/run.gd -- res://tests/misura_blocchi.gd [test]

const SOGLIA_MS := 50.0
const LIMITE_MS := 100.0
const AVVIO := 10
const MONITOR := {
	"surface": Performance.PIPELINE_COMPILATIONS_SURFACE,
	"draw": Performance.PIPELINE_COMPILATIONS_DRAW,
	"spec": Performance.PIPELINE_COMPILATIONS_SPECIALIZATION,
}

var _t := 0
var _f := 0
var _lunghi: Array = []
var _prima := {}
var _nodi := 0


func _ready() -> void:
	process_priority = -1000
	var a := OS.get_cmdline_user_args()
	var percorso := a[1] if a.size() > 1 else "res://tests/test_strada.gd"
	var test: Node = (load(percorso) as GDScript).new()
	test.name = "Misurato"
	add_child(test)
	get_tree().root.tree_exiting.connect(_fine)
	for k in MONITOR:
		_prima[k] = Performance.get_monitor(MONITOR[k])
	_t = Time.get_ticks_usec()


func _process(_delta: float) -> void:
	var ora := Time.get_ticks_usec()
	var ms := (ora - _t) / 1000.0
	_t = ora
	_f += 1
	var c := {}
	for k in MONITOR:
		var v := Performance.get_monitor(MONITOR[k])
		c[k] = int(v - _prima[k])
		_prima[k] = v
	if ms > SOGLIA_MS and _f > 2:
		var scena: String = String(get_tree().current_scene.name) if get_tree().current_scene else "-"
		var nodi := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		print("BLOCCO %.0f ms al fotogramma %d (%s; pipeline surface %d draw %d spec %d; process %.0f ms, fisica %.0f ms, nodi %+d)" % [
				ms, _f, scena, c["surface"], c["draw"], c["spec"], Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
				Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, nodi - _nodi])
		_lunghi.append([ms, _f])
	_nodi = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_fine()


func _fine() -> void:
	if _lunghi.is_empty() and _f == 0:
		return
	var sopra := _lunghi.filter(func(e): return e[0] > LIMITE_MS and e[1] > AVVIO).size()
	_lunghi.sort_custom(func(x, y): return x[0] > y[0])
	print("BLOCCHI: %d fotogrammi, %d sopra %.0f ms; i più lunghi: %s" % [_f, _lunghi.size(), SOGLIA_MS,
			", ".join(_lunghi.slice(0, 15).map(func(e): return "%.0f ms (f %d)" % [e[0], e[1]]))])
	print("BLOCCHI_SOPRA_LIMITE: %d (sopra %.0f ms dopo i primi %d fotogrammi)" % [sopra, LIMITE_MS, AVVIO])
	_f = 0
	_lunghi.clear()
