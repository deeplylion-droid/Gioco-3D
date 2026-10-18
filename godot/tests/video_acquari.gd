extends Node
## Breve video dell'enigma degli acquari risolto (forme provvisorie), dagli occhi del giocatore:
## dopo la tappa 8 aspira due volte il giallo e una il blu, versa ogni volta nell'acquario vuoto, che
## cambia colore e diventa verde, poi il portone della torre si apre con le lampade accese.
## Come scatti_sala.gd toglie gli interni prima del primo frame (memoria).
## Uso, sotto il render.lock, con il Movie Maker di Godot:
##   xvfb-run -a -s "-screen 0 960x540x24" godot --path godot --rendering-driver vulkan --fixed-fps 25 \
##        --resolution 960x540 --write-movie <file.avi> --script res://tests/run.gd -- res://tests/video_acquari.gd

const LEVEL := "res://scenes/sala_principale.tscn"

var level: Node
var p: Player
var enigma: EnigmaAcquari
var _guarda := Vector3.ZERO


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset("medio")
	level = (load(LEVEL) as PackedScene).instantiate()
	for percorso in ["Interni"]:
		var n := level.get_node_or_null(NodePath(percorso))
		if n:
			n.get_parent().remove_child(n)
			n.free()
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	await _frames(10)
	p = GameState.player
	for i in 400:
		if p.input_enabled:
			break
		await get_tree().process_frame
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	for t in level.find_children("*", "Tempesta", true, false):
		(t as Tempesta).automatica = false
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	(level.get_node(^"Tecnici/Logica/SerrandaMagazzino")).call(&"apri")
	(level.get(&"lei_sbuca") as Node).call(&"load_state", {"finita": true})
	enigma = level.get_node(^"Gioco/EnigmaAcquari") as EnigmaAcquari
	if not p.has_item(&"zaino_pompa"):
		p.add_item(&"zaino_pompa", 1, "Zaino-pompa")
	p.water_pack.set_equipped(true, false)
	p.water_pack.set_tank_amount(0.0)
	# Al buio con la torcia accesa, come nel gioco.
	for t in p.find_children("*", "", true, false):
		if t.has_method(&"imposta_accesa"):
			t.call(&"imposta_accesa", true)
	var giallo := enigma.get_node(^"AcquarioGiallo") as WaterTank
	var blu := enigma.get_node(^"AcquarioBlu") as WaterTank
	var misto := enigma.get_node(^"AcquarioMisto") as WaterTank
	# Si parte guardando i tre acquari.
	p.teleport(Vector3(13.0, 0.0, -7.2), PI * 0.5, 0.0)
	_guarda = Vector3(17.0, 0.6, -7.2)
	p.look_at_point(_guarda)
	await _secondi(1.5)
	for t in [giallo, giallo, blu]:
		var c: Vector3 = (t as WaterTank).global_position
		await _vai(Vector3(c.x - 1.6, 0.0, c.z), c + Vector3(0.0, t.get_level() * 0.5, 0.0), 1.0)
		Input.action_press(&"suck")
		for i in 240:
			await get_tree().physics_frame
			if p.water_pack.tank_amount >= p.water_pack.tank_capacity - 0.01:
				break
		Input.action_release(&"suck")
		await _secondi(0.3)
		var m := misto.global_position
		var b := m + Vector3(0.3, 0.45, 0.0)
		var d := (Vector3(m.x - 2.0, 1.6, m.z)).distance_to(b)
		await _vai(Vector3(m.x - 2.0, 0.0, m.z), b + Vector3.UP * 0.0067 * d * d, 1.0)
		Input.action_press(&"spray")
		for i in 900:
			await get_tree().physics_frame
			if p.water_pack.tank_amount <= 0.001:
				break
		await _secondi(0.6)
		Input.action_release(&"spray")
		await _secondi(0.4)
	print("stato dell'enigma: ", enigma.stato)
	await _secondi(1.0)
	# Il portone che si apre, con le lampade accese.
	await _vai(Vector3(12.5, 0.0, -11.5), Vector3(19.8, 2.4, -15.0), 1.5)
	await _secondi(7.5)
	get_tree().quit()


## Va in [param piedi] guardando [param punto] in [param secondi], senza scatti.
func _vai(piedi: Vector3, punto: Vector3, secondi: float) -> void:
	var da := p.global_position
	var g0 := _guarda
	var n := maxi(int(secondi * 60.0), 1)
	for i in n:
		var k := smoothstep(0.0, 1.0, float(i + 1) / n)
		p.teleport(da.lerp(piedi, k), p.yaw, p.pitch)
		_guarda = g0.lerp(punto, k)
		p.look_at_point(_guarda)
		await get_tree().physics_frame


func _secondi(s: float) -> void:
	for i in int(s * 60.0):
		p.look_at_point(_guarda)
		await get_tree().physics_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
