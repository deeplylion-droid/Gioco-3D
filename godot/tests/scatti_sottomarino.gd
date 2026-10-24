extends Node
## Scatti interni del tunnel del viaggio sottomarino (SalaSottomarino), dagli occhi del giocatore lungo la strada:
## per il collaudo e per i controlli della squadra (non per l'utente, che lo giudica giocando).
##
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##        --script res://tests/run.gd -- res://tests/scatti_sottomarino.gd <cartella> [scatti separati da virgole]
## Ogni scatto: [s lungo la strada, lato (-1 banchina sinistra, 1 destra, 0 asse), quota degli occhi sopra il piano,
## s guardato, lato guardato, quota guardata sopra il piano, campo visivo].

var SCATTI := {
	"01_dalla_porta": [2.0, -1.0, 1.6, -3.0, 0.0, 0.0, 75.0],
	"02_partenza": [4.0, -1.0, 1.6, 20.0, -0.3, 1.0, 75.0],
	"03_rettilineo": [30.0, -1.0, 1.6, 50.0, -0.2, 1.4, 75.0],
	"04_indietro": [40.0, 1.0, 1.6, 20.0, 0.0, 2.5, 75.0],
	"05_canale_dal_basso": [60.0, 0.0, 0.9, 75.0, 0.0, 1.0, 75.0],
	"06_curva_u": [125.0, 1.0, 1.6, 145.0, 0.0, 1.5, 75.0],
	"07_gradini": [21.0, 1.0, 1.6, 23.0, 0.6, -0.6, 75.0],
	"08_volta": [200.0, 0.0, 1.6, 206.0, 0.0, 7.0, 80.0],
	"09_fine": [540.0, -1.0, 1.6, 552.0, 0.0, 1.5, 75.0],
	"10_crollo_e_gommoni": [60.0, -1.0, 1.6, 72.0, -0.3, 0.0, 75.0],
	"11_gommoni_vicino": [65.0, -1.0, 1.6, 67.5, -0.3, -0.4, 70.0],
	"12_carico": [128.0, 1.0, 1.6, 139.5, 1.0, 0.8, 70.0],
	"13_galleria_bocca": [199.0, -1.0, 1.6, 203.8, -1.0, 0.6, 70.0],
	"14_galleria_dentro": [206.0, -1.0, 0.9, 214.0, -1.0, 0.5, 80.0],
	"15_cancello": [262.0, -1.0, 1.6, 268.0, -1.0, 1.0, 70.0],
	"16_macerie": [340.0, 1.0, 1.6, 349.5, 1.0, 0.9, 70.0],
	"17_vetrina": [476.0, -1.0, 1.6, 484.5, -1.0, 0.8, 70.0],
}

var cartella := "user://scatti_sottomarino"
var solo := PackedStringArray()


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 1:
		cartella = a[1]
	if a.size() > 2:
		solo = a[2].split(",", false)
	DirAccess.make_dir_recursive_absolute(cartella)
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	env.environment.sdfgi_enabled = true
	env.environment.sdfgi_cascades = 3
	env.environment.volumetric_fog_density = 0.009
	env.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
	add_child(env)
	var sala := SalaSottomarino.new()
	sala.name = "SalaSottomarino"
	add_child(sala)
	sala.costruisci()
	if OS.get_environment("SCATTI_DEBUG") != "":
		# debug: materiale chiaro senza ombre, con o senza le facce dal retro (SCATTI_DEBUG=retro le mostra rosse)
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.8, 0.8, 0.8)
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var mr := StandardMaterial3D.new()
		mr.albedo_color = Color(0.9, 0.1, 0.1)
		mr.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mr.cull_mode = BaseMaterial3D.CULL_FRONT
		m.next_pass = mr if OS.get_environment("SCATTI_DEBUG") == "retro" else null
		for mi in sala.find_children("*", "MeshInstance3D", true, false):
			if (mi as MeshInstance3D).material_override:
				(mi as MeshInstance3D).material_override = m
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	for i in 30:
		await get_tree().process_frame
	for nome in SCATTI:
		if not solo.is_empty() and not solo.has(nome):
			continue
		var s: Array = SCATTI[nome]
		cam.fov = s[6]
		cam.look_at_from_position(_occhio(sala, s[0], s[1], s[2]), _occhio(sala, s[3], s[4], s[5]))
		for i in 40:
			await get_tree().process_frame
		var f := cartella.path_join(nome + ".jpg")
		get_viewport().get_texture().get_image().save_jpg(f, 0.88)
		print("scatto -> ", f)
	get_tree().quit()


## Un punto a [param s] lungo la strada, di lato (in banchine: -1 la sinistra, 1 la destra, frazioni del canale
## fra -1 e 1 se [param lato] è minore di 1 in valore), a [param su] sopra il piano delle banchine.
func _occhio(sala: SalaSottomarino, s: float, lato: float, su: float) -> Vector3:
	var di_lato := lato * sala.canale if absf(lato) < 0.99 else signf(lato) * (sala.canale + sala.banchina * 0.5)
	return sala.punto(s) + sala.destra(s) * di_lato + Vector3.UP * (sala.piano - sala.acqua + su)
