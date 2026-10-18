extends Node
## Misura il blocco alla prima volta che si spruzza con lo zaino (riscontro sulla v0.3.5: "alla prima
## volta che si spruzza il gioco si blocca ancora per circa 1 secondo"), dopo la preparazione degli
## effetti (PreparaEffetti). Negli spogliatoi degli interni, con il renderer vero (Vulkan) e il tempo
## reale. Per ogni fotogramma dalla pressione del tasto: la durata e quante pipeline il motore ha
## compilato (monitor Performance: canvas, mesh, surface, draw, specialization) e quanto tempo è
## andato in process e physics. Poi la seconda volta, per confronto.
## Le compilazioni "draw" fermano il fotogramma (il motore aspetta la pipeline); le "specialization"
## si fanno in un thread a parte, intanto si disegna con l'ubershader.
## Uso (sotto flock /home/user/tools/render.lock):
##   xvfb-run -a -s "-screen 0 640x360x24" godot --path godot --rendering-driver vulkan --resolution 640x360 \
##     --script res://tests/run.gd -- res://tests/misura_spruzzo.gd [senza_preparazione]

const LEVEL := "res://scenes/interni/interni.tscn"
const POSIZIONE := Vector3(9.7, 0.0, -10.6)
const MIRA := Vector3(9.7, 1.2, -17.8)
const MONITOR := {
	"canvas": Performance.PIPELINE_COMPILATIONS_CANVAS,
	"mesh": Performance.PIPELINE_COMPILATIONS_MESH,
	"surface": Performance.PIPELINE_COMPILATIONS_SURFACE,
	"draw": Performance.PIPELINE_COMPILATIONS_DRAW,
	"spec": Performance.PIPELINE_COMPILATIONS_SPECIALIZATION,
}

var p: Player
var _ultimo := 0
var _righe: Array = []
var _registra := false
var _prima := {}


func _ready() -> void:
	_run.call_deferred()


func _process(_delta: float) -> void:
	var ora := Time.get_ticks_usec()
	if _registra and _ultimo > 0:
		var riga := {"ms": (ora - _ultimo) / 1000.0,
				"process": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
				"physics": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
				"carica": p.water_pack.get(&"_charge_t") > 0.0 and not p.water_pack.is_spraying,
				"getto": p.water_pack.is_spraying}
		for k in MONITOR:
			var v := Performance.get_monitor(MONITOR[k])
			riga[k] = int(v - _prima.get(k, v))
			_prima[k] = v
		_righe.append(riga)
	_ultimo = ora


## Tutte le compilazioni fino a ora (per azzerare i conteggi prima di misurare).
func _azzera() -> void:
	for k in MONITOR:
		_prima[k] = Performance.get_monitor(MONITOR[k])


func _run() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset("alto")
	if OS.get_cmdline_user_args().has("senza_preparazione"):
		Engine.set_meta(&"prepara_effetti_spento", true)
	get_tree().change_scene_to_file(LEVEL)
	await _frames(10)
	p = GameState.player
	for i in 400:
		if p.input_enabled:
			break
		await get_tree().process_frame
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	p.water_pack.call(&"set_equipped", true, false)
	p.teleport(POSIZIONE, 0.0, 0.0)
	p.look_at_point(MIRA)
	await _frames(90)
	for volta in ["PRIMA", "SECONDA"]:
		p.water_pack.set_tank_amount(20.0)
		_azzera()
		_righe.clear()
		_registra = true
		Input.action_press(&"spray")
		await _frames(45)
		Input.action_release(&"spray")
		await _frames(15)
		_registra = false
		_stampa(volta)
		await _frames(30)
	get_tree().quit()


func _stampa(volta: String) -> void:
	var durate: Array = _righe.map(func(r): return r.ms)
	durate.sort()
	var mediana: float = durate[durate.size() / 2]
	var totali := {}
	for k in MONITOR:
		totali[k] = 0
	print("SPRUZZO %s volta: mediana %.0f ms, massimo %.0f ms" % [volta, mediana, durate[-1]])
	for i in _righe.size():
		var r: Dictionary = _righe[i]
		var comp := ""
		for k in MONITOR:
			totali[k] += r[k]
			if r[k] > 0:
				comp += " %s=%d" % [k, r[k]]
		if r.ms > mediana * 1.4 or comp != "":
			print("  #%02d %6.0f ms (process %.0f, physics %.0f)%s%s%s" % [i, r.ms, r.process, r.physics,
					" [carica]" if r.carica else "", " [getto]" if r.getto else "", comp])
	print("  compilazioni in tutto: %s" % str(totali))


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
