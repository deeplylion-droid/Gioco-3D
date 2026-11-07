extends Node
## Scatti della mano sulla lancia (il guanto, richiesta dell'utente sulla 0.3.21) nel livello di prova: dagli occhi del
## giocatore in ogni stato (fermo, camminando, correndo, sparando, aspirando, accovacciato, sulla scala, in acqua) e
## da vicino, con una seconda camera attaccata alla camera del giocatore che guarda la mano da più lati (solo il
## livello della lancia, con una luce), per vedere distacchi e compenetrazioni.
## Uso: xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 960x540 \
##   --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/scatti_guanto.gd <cartella> [stati|vicino]

const LEVEL := "res://scenes/test/test_level.tscn"

var cart := ""
var p: Player


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _scatto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(cart.path_join(nome + ".jpg"), 0.9)
	print("SCATTO ", nome)


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	cart = a[1] if a.size() > 1 else "/tmp/scatti_guanto"
	var cosa: String = a[2] if a.size() > 2 else "stati,vicino"
	DirAccess.make_dir_recursive_absolute(cart)
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset("alto")
	get_tree().change_scene_to_file(LEVEL)
	await _frames(20)
	p = GameState.player
	for i in 300:
		if p and p.input_enabled:
			break
		await get_tree().process_frame
		p = GameState.player
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	p.add_item(&"zaino_pompa", 1, "Zaino-pompa")
	p.water_pack.set_equipped(true, false)
	p.water_pack.set_tank_amount(18.0)
	await _frames(30)
	if cosa.contains("vicino"):
		await _vicino()
	if cosa.contains("stati"):
		await _stati()
	print("FINE")
	get_tree().quit()


func _stati() -> void:
	p.teleport(Vector3(0.0, 0.0, 2.0), 0.0, 0.0)
	await _frames(30)
	await _scatto("stato_fermo")
	Input.action_press("move_forward")
	await _frames(25)
	await _scatto("stato_camminando")
	Input.action_press("sprint")
	await _frames(25)
	await _scatto("stato_correndo")
	Input.action_release("sprint")
	Input.action_release("move_forward")
	p.teleport(Vector3(0.0, 0.0, 2.0), 0.0, 0.0)
	await _frames(20)
	Input.action_press("spray")
	await _frames(40)
	await _scatto("stato_sparando")
	Input.action_release("spray")
	await _frames(20)
	p.water_pack.set_tank_amount(2.0)
	Input.action_press("suck")
	await _frames(40)
	await _scatto("stato_aspirando")
	Input.action_release("suck")
	await _frames(20)
	Input.action_press("crouch")
	await _frames(40)
	await _scatto("stato_accovacciato")
	Input.action_release("crouch")
	await _frames(30)
	# la scala a pioli del livello di prova (x 4,5, z -4): davanti, poi su
	p.teleport(Vector3(4.5, 0.0, -3.3), 0.0, 0.0)
	await _frames(10)
	Input.action_press("move_forward")
	await _frames(70)
	await _scatto("stato_scala")
	Input.action_release("move_forward")
	await _frames(10)
	# in acqua: la vasca piccola (x 3,5, z -0,5)
	p.teleport(Vector3(3.5, 0.3, -0.5), 0.0, 0.0)
	await _frames(60)
	await _scatto("stato_acqua")


## Da vicino: una camera figlia della camera del giocatore, girata attorno alla mano destra.
func _vicino() -> void:
	p.teleport(Vector3(0.0, 0.0, 2.0), 0.0, 0.0)
	await _frames(30)
	var rig := p.water_pack.lance_rig as Node3D
	# la mano destra, sull'impugnatura
	# la mano destra, sull'impugnatura (coordinate della lancia C1: il centro dell'impugnatura)
	var centro: Vector3 = rig.global_transform * Vector3(0.01, -0.24, 0.51)
	var c := Camera3D.new()
	c.fov = 40.0
	c.near = 0.005
	c.cull_mask = 0xFFFFF
	get_tree().current_scene.add_child(c)
	var luce := OmniLight3D.new()
	luce.omni_range = 2.0
	luce.light_energy = 1.2
	luce.light_cull_mask = 0xFFFFF
	c.add_child(luce)
	var cam := p.camera
	var vis_dir := [["destra", Vector3(0.35, 0.05, 0.0)], ["sinistra", Vector3(-0.35, 0.05, 0.0)],
			["sopra", Vector3(0.05, 0.35, 0.05)], ["sotto", Vector3(0.05, -0.35, 0.05)],
			["davanti", Vector3(0.0, 0.05, -0.35)], ["dietro", Vector3(0.0, 0.1, 0.35)]]
	for v in vis_dir:
		var off: Vector3 = cam.global_basis * (v[1] as Vector3)
		c.global_position = centro + off
		c.look_at(centro, cam.global_basis.y if absf((v[1] as Vector3).normalized().y) < 0.9 else cam.global_basis.z)
		c.make_current()
		await _frames(6)
		await _scatto("vicino_" + String(v[0]))
	cam.make_current()
	c.queue_free()
