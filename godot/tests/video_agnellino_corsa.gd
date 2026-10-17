extends Node
## Video dell'agnellino della scala di C2 visto dal giocatore che corre (prova della v0.3.4): col blackout si sale
## di corsa la rampa F2, l'agnellino è in cima alla scala, scappa molto più veloce e sparisce solo quando non lo
## si vede più. Il giocatore vero, con la fisica, corre lungo la strada guardando avanti; la torcia è accesa.
## Uso (fotogrammi PNG, poi tools/componi_video_tappa7.py):
##   xvfb-run -a -s "-screen 0 960x540x24" godot --path godot --rendering-driver vulkan --resolution 960x540 \
##     --fixed-fps 24 --write-movie <cartella>/f.png --script res://tests/run.gd -- res://tests/video_agnellino_corsa.gd

const SCENA := "res://tests/scene/tappa7_gioco_agnellino.tscn"
## Nelle coordinate della scena dei tecnici, come test_agnellino.gd.
const PARTENZA := Vector3(49.5, 3.625, -7.8)
const CORSA := [Vector3(44.55, 7.25, -7.8), Vector3(44.55, 7.25, -4.0), Vector3(44.55, 9.05, 2.0), Vector3(44.55, 9.05, 15.0),
		Vector3(40.5, 9.05, 15.0)]

var p: Player


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset("medio")
	get_tree().change_scene_to_file(SCENA)
	for i in 300:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player):
			break
	get_tree().paused = false
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	for n in get_tree().current_scene.find_children("*", "Node3D", true, false):
		if n is LuceEmergenza and int(n.get(&"modalita")) in [1, 2]:
			n.set(&"modalita", 0)
	p = GameState.player
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	var tec: Node3D = get_tree().current_scene.get_node("Tecnici")
	p.teleport(tec.to_global(PARTENZA) + Vector3(0, 0.05, 0), PI * 0.5, 0.0)
	for i in 12:
		await get_tree().physics_frame
	GameState.luci_cambiate.emit(GameState.luci)
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	var tappa := 0
	for i in 600:
		var t: Vector3 = tec.to_global(CORSA[tappa])
		var d := t - p.global_position
		if Vector2(d.x, d.z).length() < 0.35:
			tappa += 1
			if tappa >= CORSA.size():
				break
			continue
		# si corre guardando avanti, la testa appena alzata (le scale salgono)
		p.set_look(atan2(-d.x, -d.z), deg_to_rad(4.0))
		await get_tree().physics_frame
	Input.action_release(&"move_forward")
	Input.action_release(&"sprint")
	# un attimo fermi a guardare il corridoio C3 vuoto
	for i in 40:
		await get_tree().physics_frame
	get_tree().quit()
