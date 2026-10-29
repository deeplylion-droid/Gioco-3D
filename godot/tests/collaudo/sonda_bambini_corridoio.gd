extends Node
## Collaudo dell'agnellino del corridoio del fiume (bambini visti di sfuggita): nella scena di prova della risalita,
## col giocatore vero (si muove coi tasti e guarda col mirino), come chi gioca:
## 1. in fondo alla scala, girato verso la scala: lei compare all'oblò (il vetro è fuori vista);
## 2. guarda l'oblò per 2 s (lei è stata vista), poi di nuovo la scala per 4 s (lei si stacca e va via);
## 3. girato verso il fondo del corridoio: l'agnellino è comparso, lo guarda finché scappa, poi 4 m avanti.
## Il MonitorBambini registra piedi, contatti, Polaroid, lei, sparizione e pipeline; stampa lo stato dell'oblò.
## Uso: xvfb-run ... godot --path godot --rendering-driver vulkan --resolution 960x540 --fixed-fps 60 \
##        --script res://tests/run.gd -- res://tests/collaudo/sonda_bambini_corridoio.gd <cartella>

const MON := preload("res://tests/collaudo/monitor_bambini.gd")
var p: Player
var mon: Node


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _guarda_per(q: Vector3, secondi: float) -> void:
	for i in int(secondi * 60.0):
		p.look_at_point(q)
		await get_tree().physics_frame


func _run() -> void:
	var cart := OS.get_cmdline_user_args()[1]
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	get_tree().change_scene_to_file("res://tests/scene/risalita_prova.tscn")
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 120000:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player):
			break
	await _frames(10)
	p = GameState.player
	mon = MON.new(cart)
	add_child(mon)
	var ris := get_tree().current_scene.get_node(^"Risalita")
	var b := ris.find_child("BambinoCorridoioFiume", true, false) as BambinoSfuggita
	var oblo := ris.find_child("ObloFiume", true, false) as ObloLei
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	var m := ris.get_node(^"Marker")
	var cima := (m.get_node(^"CimaScalaFiume") as Node3D).global_position
	var fondo := (m.get_node(^"FondoScalaFiume") as Node3D).global_position
	var porta := (m.get_node(^"PortaFiume") as Node3D).global_position
	p.teleport(cima + Vector3.UP * 0.05, 0.0, 0.0)
	p.look_at_point(fondo + Vector3.UP * 1.0)
	for i in 1800:
		await get_tree().process_frame
		if not bool(ris.call(&"lavori_in_corso")) and i > 300:
			break
	mon.evento("pronto: bambino %s, oblò %s" % [BambinoSfuggita.Stato.keys()[b.stato], oblo.get(&"stato")])
	# giù per la scala coi tasti, guardando in fondo
	Input.action_press(&"move_forward")
	for i in 600:
		p.look_at_point(fondo + Vector3.UP * 1.0)
		await get_tree().physics_frame
		if Vector2(p.global_position.x - fondo.x, p.global_position.z - fondo.z).length() < 0.5:
			break
	Input.action_release(&"move_forward")
	mon.evento("in fondo alla scala in %s; oblò %s, bambino %s" % [p.global_position.snapped(Vector3.ONE * 0.01), oblo.get(&"stato"), BambinoSfuggita.Stato.keys()[b.stato]])
	# 1. girato verso la scala: lei compare all'oblò
	await _guarda_per(cima + Vector3.UP * 1.0, 2.0)
	mon.evento("guardando la scala: oblò %s" % oblo.get(&"stato"))
	# 2. l'oblò per 2,5 s, poi la scala per 5 s
	await _guarda_per(oblo.centro_vetro(), 2.5)
	mon.evento("dopo aver guardato l'oblò: oblò %s" % oblo.get(&"stato"))
	await _guarda_per(cima + Vector3.UP * 1.0, 5.0)
	mon.evento("dopo aver guardato via: oblò %s, bambino %s" % [oblo.get(&"stato"), BambinoSfuggita.Stato.keys()[b.stato]])
	# 3. il fondo del corridoio
	var lontano := Vector3(fondo.x + 0.4, fondo.y + 1.0, porta.z + 1.0)
	var t := 0.0
	while t < 8.0 and b.stato != BambinoSfuggita.Stato.SCAPPA and b.stato != BambinoSfuggita.Stato.FINITO:
		p.look_at_point(b.bambino.punto_testa() if b.stato == BambinoSfuggita.Stato.GUARDA else lontano)
		await get_tree().physics_frame
		t += 1.0 / 60.0
	mon.evento("dopo %.1f s verso il fondo: bambino %s" % [t, BambinoSfuggita.Stato.keys()[b.stato]])
	Input.action_press(&"move_forward")
	t = 0.0
	while t < 6.0 and b.stato != BambinoSfuggita.Stato.FINITO:
		p.look_at_point(porta + Vector3(-1.0, 1.0, 0.0))
		await get_tree().physics_frame
		t += 1.0 / 60.0
	Input.action_release(&"move_forward")
	await _frames(60)
	mon.evento("fine: bambino %s, giocatore in %s" % [BambinoSfuggita.Stato.keys()[b.stato], p.global_position.snapped(Vector3.ONE * 0.01)])
	get_tree().quit()
