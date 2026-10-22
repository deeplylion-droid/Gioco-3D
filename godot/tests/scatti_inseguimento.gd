extends Node
## Scatti di controllo dell'inseguimento nel gioco (SalaInseguimento, scenes/sala/inseguimento/): la sala da
## sola con l'ambiente della sala grande, le stesse inquadrature degli scatti della proposta A
## (proposte/inseguimento/scatti_inseguimento.gd) e qualcuna in più. Lei nelle sue pose dove serve.
##
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##        --script res://tests/run.gd -- res://tests/scatti_inseguimento.gd <cartella> [scatti separati da virgole]

const SCENA := "res://scenes/sala/inseguimento/sala_inseguimento.tscn"

static func b(x: float, y: float, z: float) -> Vector3:
	return Vector3(x, z, -y)

## nome: [camera, punto guardato, campo visivo, cosa fa lei ("" niente, "vasca_0", "grata", "sb1"), paratie aperte, grata giù]
var SCATTI := {
	"1_primo_bivio": [b(50.9, 17.4, -20.55), b(56.5, 12.6, -22.6), 78.0, "", [], false],
	"2_lei_ti_raggiunge": [b(54.3, 12.9, -20.7), b(48.6, 17.6, -22.4), 52.0, "vasca_0", [], false],
	"3_secondo_bivio": [b(65.5, 29.6, -23.8), b(65.5, 25.0, -24.2), 76.0, "", [], false],
	"3b_terzo_bivio": [b(69.6, 7.0, -26.9), b(66.5, 4.6, -28.0), 76.0, "", [], false],
	"3c_paratia_aperta": [b(51.6, 16.4, -21.0), b(56.0, 16.4, -21.9), 70.0, "", [0], false],
	"4_grata": [b(44.6, 4.6, -32.3), b(51.0, 6.5, -32.4), 76.0, "grata", [], true],
	"4b_grata_vicino": [b(48.0, 5.6, -32.4), b(51.2, 8.5, -31.4), 70.0, "grata", [], true],
	"5_sb1": [b(43.4, 4.4, -32.4), b(44.7, 9.0, -32.6), 66.0, "sb1", [], true],
	"6_sala_dall_alto": [b(44.0, 30.0, -17.0), b(62.0, 12.0, -27.0), 80.0, "", [], false],
	"7_nel_tubo": [b(57.6, 17.7, -22.4), b(60.5, 21.0, -23.1), 80.0, "", [], false],
	"8_lampada_vasca": [b(65.4, 27.2, -24.2), b(63.3, 29.7, -23.3), 70.0, "", [], false],
	"8b_lei_vasca_2": [b(64.6, 26.4, -24.1), b(70.6, 28.0, -19.5), 70.0, "vasca_1", [], false],
}

var cartella := "user://scatti_inseguimento"
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
	var sala := (load(SCENA) as PackedScene).instantiate() as SalaInseguimento
	add_child(sala)
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	for i in 40:
		await get_tree().process_frame
	# lei nella vasca 3 (dal giocatore dentro la vasca) e nelle vasche di scolo 0 e 1
	for q in [["9_vasca_3", "vasche", 2, "vasca_2"], ["9b_scolo_0", "scolo", 0, "scolo_0"], ["9c_scolo_1", "scolo", 1, "scolo_1"]]:
		var v: Dictionary = sala.dati[q[1]][q[2]]
		var r: Array = v["rett"]
		var occhi := b((r[0] + r[2]) / 2.0, (r[1] + r[3]) / 2.0, float(v["fondo"]) + 1.6)
		var lei_pos := sala._posto_vasca(q[2]) if q[1] == "vasche" else sala._posto_scolo(q[2])
		if q[1] == "scolo":
			# le vasche di scolo sono chiuse e buie: da fuori, 5 m dietro di lei, con la vasca davanti
			var via := Vector3(lei_pos.x - occhi.x, 0.0, lei_pos.z - occhi.z).normalized()
			SCATTI[q[0]] = [lei_pos + via * 5.0 + Vector3.UP * 4.5, (occhi + lei_pos) / 2.0 + Vector3.UP * 1.5, 70.0, q[3], [], false]
		else:
			SCATTI[q[0]] = [occhi, lei_pos + Vector3.UP * 4.0, 70.0, q[3], [], false]
	for nome in SCATTI:
		if not solo.is_empty() and not solo.has(nome):
			continue
		var s: Array = SCATTI[nome]
		cam.fov = s[2]
		cam.look_at_from_position(s[0], s[1])
		for k in sala.paratie.size():
			var d: Dictionary = sala.paratie[k]
			var su := (s[4] as Array).has(k)
			(d["pannello_nodo"] as Node3D).global_position = (d["chiuso"] as Vector3) + Vector3.UP * (float(d["corsa"]) if su else 0.0)
		if sala.grata:
			var g: Dictionary = sala.dati["grata"]
			var alto := SalaInseguimento.b(g["perno"])
			sala.grata.global_position = alto + (Vector3.DOWN * float(g["corsa"]) if s[5] else Vector3.ZERO)
		_lei(sala, String(s[3]), s[0])
		for i in 30:
			await get_tree().process_frame
		var f := cartella.path_join(nome + ".jpg")
		get_viewport().get_texture().get_image().save_jpg(f, 0.9)
		print("scatto -> ", f)
	get_tree().quit()


## Lei nella posa che serve (le animazioni dell'inseguimento, ferme a un istante), girata verso la camera; alla
## grata girata verso la grata, a SB1 sullo spigolo del pozzo dalla parte della camera (come in gioco).
func _lei(sala: SalaInseguimento, cosa: String, camera: Vector3) -> void:
	var lei := sala.lei
	if cosa == "":
		lei.visible = false
		return
	var L: Array = sala.dati["lei"]
	var pos: Vector3
	var guarda := camera
	var anim := &"inseguimento/incombe"
	var t := 0.6
	match cosa:
		"vasca_0":
			pos = SalaInseguimento.b(L[0]["pos"])
		"vasca_1":
			pos = sala._posto_vasca(1)
		"vasca_2":
			pos = sala._posto_vasca(2)
		"scolo_0", "scolo_1":
			pos = sala._posto_scolo(int(cosa.right(1)))
			var r: Array = sala.dati["scolo"][int(cosa.right(1))]["rett"]
			guarda = b((r[0] + r[2]) / 2.0, (r[1] + r[3]) / 2.0, 0.0)   # verso chi è nella vasca
		"grata":
			pos = SalaInseguimento.b(L[2]["pos"])
			guarda = sala.mira_grata(pos)
			anim = &"inseguimento/colpo_grata_sbieco"
			t = 0.27
		"sb1":
			pos = sala._posto_sb1()
			guarda = Vector3.INF
			anim = &"inseguimento/affacciata_sb1"
			t = 3.0
	lei.global_position = pos
	lei.visible = true
	if guarda != Vector3.INF:
		guarda.y = pos.y
		lei.look_at(guarda, Vector3.UP, true)
	var ap := lei.get_model_instance().find_child("AnimationPlayer", true, false) as AnimationPlayer
	ap.play(anim)
	ap.seek(t, true)
	ap.pause()
