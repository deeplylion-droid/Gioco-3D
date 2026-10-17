extends Node
## Misura i blocchi al primo uso degli effetti (riscontro 3 della v0.3.4: "la prima volta che ho usato
## sia il risucchio d'acqua, sia lo sparo, sia che ho visto il geyser ... 1 secondo di freeze").
## Negli spogliatoi degli interni (scena leggera: la sala principale col renderer software non ci
## sta in memoria per tutta la misura), con il renderer vero (Vulkan) e il tempo reale (senza
## --fixed-fps): per ogni effetto il fotogramma più lungo nei primi 20-50 dopo l'avvio, la prima e la
## seconda volta, e il fotogramma normale (mediana) per confronto. Se la prima volta è molto più
## lunga della seconda, il primo uso compila shader o pipeline (che non dipendono dalla scena).
##   aspirazione: aspiri dalla vasca lava-piedi; getto: spari verso il tornello; geyser: un
##   GeyserFossa davanti a te; jumpscare: lo schermo rotto (lo shader di JumpscareGlitch).
## Uso (sotto flock /home/user/tools/render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##     --script res://tests/run.gd -- res://tests/misura_primo_uso.gd [senza_preparazione]

const LEVEL := "res://scenes/interni/interni.tscn"
const POSIZIONE := Vector3(9.7, 0.0, -10.6)
const POZZA := Vector3(9.7, -0.05, -12.9)
const MIRA := Vector3(9.7, 1.2, -17.8)

var p: Player
var _durate: Array[float] = []
var _ultimo := 0
var _registra := false
var risultati := {}


func _ready() -> void:
	_run.call_deferred()


func _process(_delta: float) -> void:
	var ora := Time.get_ticks_usec()
	if _registra and _ultimo > 0:
		_durate.append((ora - _ultimo) / 1000.0)
	_ultimo = ora


func _run() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset("alto")
	if OS.get_cmdline_user_args().has("senza_preparazione"):
		Engine.set_meta(&"prepara_effetti_spento", true)
	get_tree().change_scene_to_file(LEVEL)
	await _frames(10)
	print("livello caricato")
	get_tree().paused = false
	p = GameState.player
	for i in 400:
		if p.input_enabled:
			break
		await get_tree().process_frame
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	p.water_pack.call(&"set_equipped", true, false)
	p.water_pack.set_tank_amount(0.0)
	p.teleport(POSIZIONE, 0.0, 0.0)
	p.look_at_point(POZZA)
	await _frames(60)
	print("misuro")
	risultati["normale"] = await _misura(&"", 15)
	for volta in ["prima", "seconda"]:
		p.look_at_point(POZZA)
		risultati["aspirazione_" + volta] = await _misura(&"suck", 20)
		await _frames(15)
	p.look_at_point(MIRA)
	for volta in ["prima", "seconda"]:
		p.water_pack.set_tank_amount(20.0)
		risultati["getto_" + volta] = await _misura(&"spray", 30)
		await _frames(20)
	p.look_at_point(POZZA)
	for volta in ["prima", "seconda"]:
		var g := GeyserFossa.new()
		get_tree().current_scene.add_child(g)
		_durate.clear()
		_registra = true
		g.scoppia(p.global_position + p.global_basis * Vector3(0.0, 0.0, -4.0), [])
		await _frames(15)
		_registra = false
		risultati["geyser_" + volta] = _massimo()
		g.queue_free()
		await _frames(10)
	for volta in ["prima", "seconda"]:
		var strato := CanvasLayer.new()
		var r := ColorRect.new()
		r.set_anchors_preset(Control.PRESET_FULL_RECT)
		var m := ShaderMaterial.new()
		m.shader = JumpscareGlitch.SHADER
		m.set_shader_parameter(&"forza", 1.0)
		r.material = m
		strato.add_child(r)
		_durate.clear()
		_registra = true
		add_child(strato)
		await _frames(8)
		_registra = false
		risultati["jumpscare_" + volta] = _massimo()
		strato.queue_free()
		await _frames(5)
	print("MISURA (ms, fotogramma più lungo nei primi 20-25 dopo l'avvio):")
	for k in risultati:
		print("  %s: %.0f" % [k, risultati[k]])
	get_tree().quit()


## Tiene premuta [param azione] per [param n] fotogrammi e ritorna il più lungo (in ms); senza
## azione ritorna la mediana.
func _misura(azione: StringName, n: int) -> float:
	_durate.clear()
	_registra = true
	if azione != &"":
		Input.action_press(azione)
	await _frames(n)
	if azione != &"":
		Input.action_release(azione)
	_registra = false
	if azione == &"":
		var d := _durate.duplicate()
		d.sort()
		return d[d.size() / 2]
	return _massimo()


func _massimo() -> float:
	var m := 0.0
	for d in _durate:
		m = maxf(m, d)
	return m


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
