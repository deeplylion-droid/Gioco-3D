extends Node
## Scatti della scaletta del bacino allungata sotto il pelo (ritocco del capitolo 1, scelta A dell'utente): dagli occhi
## del giocatore in piedi nell'acqua del bacino, e da vicino il tratto che scavalca il bordo e i due
## pioli nuovi contro il muro. La torre da sola, con l'ambiente della sala, al buio dopo la sala pompe, come nel gioco;
## la luce della scaletta (FaroScaletta) è quella che si accende dopo SB1.
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 960x540x24" godot --path godot --rendering-driver vulkan --resolution 960x540 \
##        --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/scatti_scaletta_bacino.gd <cartella>

const PLAYER := "res://scenes/player/player.tscn"

var cartella := ""
var p: Player
var cam: Camera3D


func _ready() -> void:
	_run.call_deferred()


func _fotogrammi(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _scatto(nome: String) -> void:
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(cartella.path_join(nome + ".jpg"), 0.9)
	print("SCATTO %s camera %s" % [nome, get_viewport().get_camera_3d().global_position])


func _run() -> void:
	Game.pause_on_focus_loss = false
	cartella = OS.get_cmdline_user_args()[1]
	DirAccess.make_dir_recursive_absolute(cartella)
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	env.environment.sdfgi_enabled = false
	env.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
	add_child(env)
	GameState.luci = GameState.Luci.BLACKOUT
	var torre := (load("res://scenes/sala/torre/sala_torre.tscn") as PackedScene).instantiate() as SalaTorre
	add_child(torre)
	await _fotogrammi(30)
	var ins := torre.inseguimento as SalaInseguimento
	ins.tempo_presa = 9999.0
	await _fotogrammi(200)
	if ins.lei:
		ins.lei.visible = false
	var s: Dictionary = ins.dati["scale"][0]
	var piede := SalaInseguimento.b([s["x"], s["y"], s["z0"]])
	var pelo := float(ins.dati["bacino"]["acqua"])
	# una luce come quella che si accende sulla scaletta dopo SB1 (il faro caldo)
	var faro := OmniLight3D.new()
	faro.light_color = Color(1.0, 0.85, 0.6)
	faro.light_energy = 2.0
	faro.omni_range = 6.0
	add_child(faro)
	faro.global_position = piede + Vector3(2.0, 2.5, 0.0)
	p = (load(PLAYER) as PackedScene).instantiate() as Player
	add_child(p)
	await _fotogrammi(5)
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	# dagli occhi, in piedi nell'acqua, 2 m e 1 m davanti alla scaletta
	for d in [2.0, 1.0]:
		p.teleport(Vector3(piede.x + d, piede.y + 0.3, piede.z))
		await _fotogrammi(40)
		p.look_at_point(Vector3(piede.x, pelo + 0.4, piede.z))
		await _scatto("scaletta_occhi_in_piedi_%dm" % int(d))
	# da vicino, con una camera libera: il tratto basso di lato, la curva sul bordo, i pioli sotto il pelo
	cam = Camera3D.new()
	cam.near = 0.02
	cam.fov = 50.0
	add_child(cam)
	cam.make_current()
	var vicini := {
		"vicino_lato_sud": [Vector3(0.8, 1.0, 0.9), Vector3(0.05, 0.6, 0.0)],
		"vicino_lato_nord": [Vector3(0.8, 1.0, -0.9), Vector3(0.05, 0.6, 0.0)],
		"vicino_curva_bordo": [Vector3(0.6, 1.5, 0.55), Vector3(0.0, 1.15, 0.25)],
		"vicino_pioli_pelo": [Vector3(0.7, 0.9, 0.1), Vector3(0.03, 0.55, 0.0)],
		"vicino_dall_alto": [Vector3(0.35, 1.9, 0.0), Vector3(0.03, 0.4, 0.0)],
	}
	for nome in vicini:
		var da: Vector3 = vicini[nome][0]
		var a: Vector3 = vicini[nome][1]
		cam.global_position = piede + da
		cam.look_at(piede + a, Vector3.UP)
		await _fotogrammi(10)
		await _scatto("scaletta_" + nome)
	get_tree().quit()
