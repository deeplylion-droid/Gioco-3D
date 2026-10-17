extends Node
## Misura i blocchi al primo uso degli effetti (riscontro 3 della v0.3.4: "la prima volta che ho usato
## sia il risucchio d'acqua, sia lo sparo, sia che ho visto il geyser ... 1 secondo di freeze").
## Nella sala principale al buio, con il renderer vero (Vulkan), tempo reale (senza --fixed-fps):
## per ogni effetto il fotogramma più lungo nei primi 20 dopo l'avvio, la prima e la seconda volta,
## e il fotogramma normale (mediana) per confronto. Se la seconda volta è molto più corta, il primo
## uso compila shader o pipeline.
##   aspirazione: aspiri dall'acqua della fossa; getto: spari verso il muro; geyser: spruzzi lei;
##   jumpscare: lei ti prende (solo la prima volta: poi si riparte dal checkpoint).
## Uso (sotto flock /home/user/tools/render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##     --script res://tests/run.gd -- res://tests/misura_primo_uso.gd [senza_preparazione]

const LEVEL := "res://scenes/sala_principale.tscn"

var p: Player
var lei: LeiSbuca
var level: Node
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
	level = (load(LEVEL) as PackedScene).instantiate()
	for percorso in ["Interni", "Tecnici"]:
		var n := level.get_node_or_null(NodePath(percorso))
		if n:
			n.get_parent().remove_child(n)
			n.free()
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	await _frames(10)
	get_tree().paused = false
	p = GameState.player
	for i in 400:
		if p.input_enabled:
			break
		await get_tree().process_frame
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	lei = level.get_node(^"Gioco/LeiSbuca") as LeiSbuca
	for v in lei.vasche:
		var t := v as WaterTank
		t.fill = clampf((lei.livello_pieno - t.get_floor_global_y()) / t.inner_size.y, 0.0, t.max_fill)
	lei.distanza_presa = 0.0
	if not p.has_item(&"zaino_pompa"):
		p.add_item(&"zaino_pompa", 1, "Zaino-pompa")
	p.water_pack.set_equipped(true, false)
	p.water_pack.set_tank_amount(0.0)
	await _frames(240)
	var testa: Vector3 = lei.punto_sbuca.global_transform * Vector3(0.0, 1.63, 1.8)
	var avanti := lei.punto_sbuca.global_basis.z
	var lato := lei.punto_sbuca.global_basis.x
	# Accanto alla fossa, di lato, guardando l'acqua (lontano da lei: non si spruzza ancora).
	var acqua: Vector3 = lei.punto_sbuca.global_transform * Vector3(-1.2, 0.4, 0.6)
	var piedi := acqua + lato * -2.2 + avanti * 0.5
	piedi.y = 0.0
	p.teleport(piedi, 0.0, 0.0)
	p.look_at_point(acqua)
	await _frames(60)
	risultati["normale"] = await _misura(&"", 40)
	for volta in ["prima", "seconda"]:
		p.look_at_point(acqua)
		risultati["aspirazione_" + volta] = await _misura(&"suck", 30)
		await _frames(40)
	# Il getto verso il muro lontano, lontano da lei.
	p.look_at_point(piedi - avanti * 6.0 + Vector3.UP * 1.0)
	for volta in ["prima", "seconda"]:
		p.water_pack.set_tank_amount(20.0)
		risultati["getto_" + volta] = await _misura(&"spray", 50)
		await _frames(60)
	# Il geyser: la spruzzi.
	for volta in ["prima", "seconda"]:
		lei.load_state({"finita": false})
		await _frames(30)
		var da := testa + avanti * 5.0
		da.y = 0.0
		p.teleport(da, 0.0, 0.0)
		p.look_at_point(testa + Vector3.UP * 0.15)
		await _frames(20)
		p.water_pack.set_tank_amount(20.0)
		_durate.clear()
		_registra = true
		Input.action_press(&"spray")
		for i in 240:
			await get_tree().process_frame
			p.look_at_point(testa + Vector3.UP * 0.15)
			if lei.fase != LeiSbuca.Fase.GUARDA:
				break
		Input.action_release(&"spray")
		_durate.clear()
		for i in 25:
			await get_tree().process_frame
		_registra = false
		risultati["geyser_" + volta] = _massimo()
		for i in 400:
			if lei.fase == LeiSbuca.Fase.FINITA:
				break
			await get_tree().process_frame
	# Il jumpscare (prima volta).
	lei.load_state({"finita": false})
	await _frames(30)
	_durate.clear()
	_registra = true
	lei.call(&"_prendi")
	await _frames(25)
	_registra = false
	risultati["jumpscare_prima"] = _massimo()
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
