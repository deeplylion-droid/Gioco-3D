extends Node
## Collaudo degli oblò con lei: come si muove quando si stacca. Dagli occhi del giocatore, da vicino (come
## scatti_oblo_torre.gd e scatti_oblo_lei.gd), uno scatto ogni OGNI fotogrammi dal distacco (8 di serie) fino al fotogramma FINO (160).
## Uso (sotto il render.lock):
##   OBLO_RAGGIO=0.6 xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --fixed-fps 60 \
##        --resolution 1280x720 --script res://tests/run.gd -- res://tests/collaudo/distacco_oblo.gd <cartella> [torre|NomeOblo]
## Con un nome di oblò della Risalita (ObloFiume, ObloPersonale, ObloServizio) lo fa lì. OGNI, DA (il primo fotogramma
## da scattare dopo il distacco) e FINO (l'ultimo) si cambiano con le variabili d'ambiente omonime.

const PLAYER := "res://scenes/player/player.tscn"
const POSTO_TORRE := Vector3(38.0, -19.98, -13.4)
## Il posto da vicino di ogni oblò della Risalita (come scatti_oblo_lei.gd).
const POSTI_RISALITA := {
	"ObloFiume": Vector3(-5.45, -5.4, 58.3),
	"ObloPersonale": Vector3(-34.45, -5.4, 49.35),
	"ObloServizio": Vector3(-21.2, 0.0, 39.15),
}

var cartella := "user://distacco_oblo"


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 1:
		cartella = a[1]
	DirAccess.make_dir_recursive_absolute(cartella)
	_run.call_deferred(a[2] if a.size() > 2 else "torre")


func _env(nome: String, di_serie: int) -> int:
	return int(OS.get_environment(nome)) if OS.get_environment(nome) != "" else di_serie


func _run(dove: String) -> void:
	var ogni := _env("OGNI", 8)
	var da := _env("DA", ogni)
	var fino := _env("FINO", 160)
	Game.pause_on_focus_loss = false
	Engine.set_meta(&"precarica_torre_spento", true)
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	env.environment.sdfgi_enabled = false
	env.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
	add_child(env)
	GameState.luci = GameState.Luci.BLACKOUT
	var o: ObloLei
	var posto := POSTO_TORRE
	if dove == "torre":
		var torre := (load("res://scenes/sala/torre/sala_torre.tscn") as PackedScene).instantiate() as SalaTorre
		if OS.get_environment("OBLO_RAGGIO") != "":
			torre.oblo_raggio_vetro = float(OS.get_environment("OBLO_RAGGIO"))
		add_child(torre)
		o = torre.oblo
	else:
		Engine.set_meta(&"risalita_subito", true)
		env.environment.background_mode = Environment.BG_COLOR
		env.environment.background_color = Color.BLACK
		var ris := (load("res://scenes/risalita/risalita.tscn") as PackedScene).instantiate() as Node3D
		add_child(ris)
		o = ris.find_child(dove, true, false) as ObloLei
		posto = POSTI_RISALITA[dove]
	var p := (load(PLAYER) as PackedScene).instantiate() as Player
	add_child(p)
	await _fotogrammi(20)
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	o.set_process(false)
	p.teleport(posto)
	await _fotogrammi(4)
	p.look_at_point(o.global_position + Vector3.DOWN * 0.15)
	o._mostra()
	await _fotogrammi(60)
	_scatto("%s_distacco_000_ferma" % dove)
	o._stacca()
	var f := 0
	while f < fino:
		await get_tree().process_frame
		f += 1
		if f >= da and (f - da) % ogni == 0:
			_scatto("%s_distacco_%03d" % [dove, f])
	print("DISTACCO: finito")
	get_tree().quit()


func _fotogrammi(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _scatto(nome: String) -> void:
	get_viewport().get_texture().get_image().save_jpg(cartella.path_join(nome + ".jpg"), 0.88)
	print("scatto -> ", nome)
