extends Node
## Collaudo degli oblò con lei: gli stati che scatti_oblo_lei.gd non fa. Per ogni oblò della Risalita, dagli stessi posti
## (da lontano e da vicino, guardando il centro del vetro), coi materiali veri:
## - prima: prima del blackout (le luci della sala accese): l'oblò vuoto, lei non c'è;
## - al buio prima che compaia: blackout, lei non ancora venuta;
## - dopo: lei è venuta e si è staccata (sparita): l'oblò vuoto e buio.
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##        --script res://tests/run.gd -- res://tests/collaudo/stati_oblo.gd <cartella>

const PLAYER := "res://scenes/player/player.tscn"
const POSTI := {
	"ObloFiume": [Vector3(-5.5, -5.4, 54.4), Vector3(-5.45, -5.4, 58.3)],
	"ObloPersonale": [Vector3(-34.35, -5.4, 50.45), Vector3(-34.45, -5.4, 49.35)],
	"ObloServizio": [Vector3(-24.4, 0.0, 39.0), Vector3(-21.2, 0.0, 39.15)],
}

var cartella := "user://stati_oblo"


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 1:
		cartella = a[1]
	DirAccess.make_dir_recursive_absolute(cartella)
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	Engine.set_meta(&"risalita_subito", true)
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	env.environment.sdfgi_enabled = false
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color.BLACK
	env.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
	add_child(env)
	var ris := (load("res://scenes/risalita/risalita.tscn") as PackedScene).instantiate() as Node3D
	add_child(ris)
	var p := (load(PLAYER) as PackedScene).instantiate() as Player
	add_child(p)
	await _fotogrammi(20)
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	for stato in ["0_prima_luci", "1_buio_prima", "5_dopo"]:
		GameState.imposta_luci(GameState.Luci.BLACKOUT if stato != "0_prima_luci" else GameState.Luci.PRIMA_DEL_RISVEGLIO)
		await _fotogrammi(10)
		for nome in POSTI:
			var o := ris.find_child(nome, true, false) as ObloLei
			o.set_process(false)
			if stato == "5_dopo":
				o._mostra()
				await _fotogrammi(10)
				o._stacca()
				var t := 0.0
				while t < 6.0:
					await get_tree().process_frame
					t += get_process_delta_time()
				o.via()
			var c := o.global_position
			for i in 2:
				p.teleport(POSTI[nome][i])
				await _fotogrammi(4)
				p.look_at_point(c + Vector3.DOWN * 0.1)
				await _fotogrammi(30)
				await _scatto("%s_%s_%s" % [nome, stato, ["lontano", "vicino"][i]])
	print("STATI: finito")
	get_tree().quit()


func _fotogrammi(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _scatto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(cartella.path_join(nome + ".jpg"), 0.88)
