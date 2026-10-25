extends Node
## Collaudo degli oblò con lei: come si muove quando si stacca. Dagli occhi del giocatore, da vicino (come
## scatti_oblo_torre.gd e scatti_oblo_lei.gd), uno scatto ogni [constant OGNI] fotogrammi dal distacco finché non è sparita.
## Uso (sotto il render.lock):
##   OBLO_RAGGIO=0.6 xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan \
##        --resolution 1280x720 --script res://tests/run.gd -- res://tests/collaudo/distacco_oblo.gd <cartella> torre

const PLAYER := "res://scenes/player/player.tscn"
const OGNI := 8
const SCATTI := 10
const POSTO_TORRE := Vector3(38.0, -19.98, -13.4)

var cartella := "user://distacco_oblo"


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 1:
		cartella = a[1]
	DirAccess.make_dir_recursive_absolute(cartella)
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	Engine.set_meta(&"precarica_torre_spento", true)
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	env.environment.sdfgi_enabled = false
	env.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
	add_child(env)
	GameState.luci = GameState.Luci.BLACKOUT
	var torre := (load("res://scenes/sala/torre/sala_torre.tscn") as PackedScene).instantiate() as SalaTorre
	if OS.get_environment("OBLO_RAGGIO") != "":
		torre.oblo_raggio_vetro = float(OS.get_environment("OBLO_RAGGIO"))
	add_child(torre)
	var p := (load(PLAYER) as PackedScene).instantiate() as Player
	add_child(p)
	await _fotogrammi(20)
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	var o := torre.oblo
	o.set_process(false)
	p.teleport(POSTO_TORRE)
	await _fotogrammi(4)
	p.look_at_point(o.global_position + Vector3.DOWN * 0.15)
	o._mostra()
	await _fotogrammi(60)
	_scatto("distacco_00_ferma")
	o._stacca()
	for i in SCATTI:
		await _fotogrammi(OGNI)
		_scatto("distacco_%02d" % ((i + 1) * OGNI))
	print("DISTACCO: finito")
	get_tree().quit()


func _fotogrammi(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _scatto(nome: String) -> void:
	get_viewport().get_texture().get_image().save_jpg(cartella.path_join(nome + ".jpg"), 0.88)
	print("scatto -> ", nome)
