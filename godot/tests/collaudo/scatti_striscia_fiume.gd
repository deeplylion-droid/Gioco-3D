extends Node
## Collaudo finale 0.3.21 (mascotte, seconda parte): il fiume lento dagli occhi del giocatore seduto sulla ciambella,
## lungo tutti i tratti (TrattoFiume: l'anello, i tre bivi, i rami sbagliati con lo scivolo e l'uscita all'approdo),
## ogni [constant PASSO] m: avanti, a sinistra e a destra (di [constant GIRO] gradi). Gli occhi sono dove li mette
## FiumeLento: la ciambella più 5 cm, più l'altezza degli occhi in piedi (Player.stand_eye_height, 1,6 m). Luci del
## blackout (dopo la sala pompe, i cartelli verdi accesi sui rami giusti), ambiente ed esposizione della sala.
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##     --script res://tests/run.gd -- res://tests/collaudo/collaudo_0321_fiume.gd <cartella>
## I file: <tratto>_<s>_<avanti|sinistra|destra>.jpg.

const PASSO := 12.0
## solo i punti dove mascotte ha visto la riga chiara (per il confronto 0.3.20 / 0.3.21)
const CASI := {"Giusto1": [37.0], "Giusto2": [1.0], "Sbagliato1": [25.0], "Sbagliato2": [25.0], "Sbagliato3": [25.0]}
const GIRO := 70.0
const OCCHI := 0.05 + 1.6
var cartella := "/tmp/fiume"


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 1:
		cartella = a[1]
	DirAccess.make_dir_recursive_absolute(cartella)
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.luci = GameState.Luci.BLACKOUT
	Grafica.applica_preset("alto")
	var we := WorldEnvironment.new()
	we.environment = load("res://addons/grafica/sala/ambiente_sala.tres") as Environment
	we.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
	add_child(we)
	var f: Node3D = (load("res://scenes/risalita/fiume.tscn") as PackedScene).instantiate()
	add_child(f)
	var cam := Camera3D.new()
	cam.fov = 62.0
	cam.near = 0.05
	cam.far = 200.0
	add_child(cam)
	cam.make_current()
	for i in 240:
		await get_tree().process_frame
	var tratti := f.find_children("*", "TrattoFiume", true, false)
	print("TRATTI: %d" % tratti.size())
	var n := 0
	for t: TrattoFiume in tratti:
		var lung := t.lunghezza()
		print("tratto %s: %.0f m%s%s" % [t.name, lung, " (ramo sbagliato)" if t.ramo_sbagliato else "", " (uscita)" if t.uscita else ""])
		for s: float in CASI.get(String(t.name), []):
			var p := t.punto(s) + Vector3.UP * OCCHI
			var d := t.direzione(s)
			d.y = 0.0
			d = d.normalized()
			for v in [["avanti", 0.0], ["sinistra", GIRO], ["destra", -GIRO]]:
				var dir := d.rotated(Vector3.UP, deg_to_rad(v[1]))
				cam.global_position = p
				cam.look_at(p + dir * 10.0 + Vector3.DOWN * 0.9, Vector3.UP)
				for i in 8:
					await get_tree().process_frame
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_jpg(cartella.path_join("%s_%03d_%s.jpg" % [t.name, int(s), v[0]]), 0.85)
				n += 1
	print("SCATTI %d" % n)
	print("FIUME FINITO")
	get_tree().quit()
