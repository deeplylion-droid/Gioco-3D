extends Node
## Video di controllo delle animazioni di lei per l'inseguimento (tools/blender/medusa_inseguimento.py) nella
## sala vera (SalaInseguimento da sola, con l'ambiente della sala grande, come tests/scatti_inseguimento.gd),
## con le inquadrature degli scatti di ambienti-2:
##   vasca: lei sale nella vasca 1, incombe (la testa ti segue), il getto la respinge; risale, incombe, ti
##          prende; risale e torna sotto da sola;
##   grata: sale di colpo dietro la grata calata e ci sbatte contro tre volte, poi torna sotto;
##   sb1:   sbuca dal pozzo, si aggrappa al bordo, gira la testa e ti fissa.
## Per la squadra (proposte/ è esclusa dall'export). Stampa "CLIP nome frame N" all'inizio di ogni pezzo.
## Uso (sotto il render.lock, con almeno 13,5 GB liberi):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##     --fixed-fps 30 [--write-movie <cartella>/f.png] --script res://tests/run.gd -- \
##     res://proposte/mascotte/video_lei_inseguimento.gd <cartella> [scatti "clip:t,clip:t"]

const SCENA := "res://scenes/sala/inseguimento/sala_inseguimento.tscn"


static func b(x: float, y: float, z: float) -> Vector3:
	return Vector3(x, z, -y)


## clip: [camera, punto guardato, campo visivo, [[animazione, secondi, testa], ...]]
var CLIP := {
	"vasca": [b(54.3, 12.9, -20.7), b(48.6, 17.6, -22.4), 52.0, [
		["sale_dall_acqua", 1.6, 0.0], ["incombe", 2.4, 1.0], ["respinta", 1.2, 0.0], ["", 0.6, 0.0],
		["sale_dall_acqua", 1.6, 0.0], ["incombe", 1.2, 1.0], ["presa", 1.5, 0.0], ["", 0.4, 0.0],
		["sale_dall_acqua", 1.6, 0.0], ["incombe", 1.0, 1.0], ["scende", 1.0, 0.0], ["", 0.4, 0.0]]],
	"grata": [b(44.6, 4.6, -32.3), b(51.0, 6.5, -32.4), 76.0, [
		["sale_dall_acqua_veloce", 1.0, 0.0], ["colpo_grata", 1.5, 0.0], ["scende", 1.0, 0.0], ["", 0.4, 0.0]]],
	"sb1": [b(43.4, 4.4, -32.4), b(44.7, 9.0, -32.6), 66.0, [["affacciata_sb1", 5.4, 0.0]]],
}

var cartella := "user://video_lei_inseguimento"
var scatti := {}
var sala: SalaInseguimento
var lei: MedusaAffacciata
var ap: AnimationPlayer
var cam: Camera3D


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 1:
		cartella = a[1]
	if a.size() > 2:
		for x in a[2].split(",", false):
			var c := x.split(":")
			if not scatti.has(c[0]):
				scatti[c[0]] = []
			scatti[c[0]].append(float(c[1]))
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
	sala = (load(SCENA) as PackedScene).instantiate() as SalaInseguimento
	add_child(sala)
	cam = Camera3D.new()
	add_child(cam)
	cam.current = true
	for i in 40:
		await get_tree().process_frame
	lei = sala.lei
	sala.set_process(false)
	sala.set_physics_process(false)
	ap = lei.get_model_instance().find_child("AnimationPlayer", true, false) as AnimationPlayer
	if not ap.has_animation_library(&"inseguimento"):
		ap.add_animation_library(&"inseguimento", load(MedusaAffacciata.ANIMAZIONI_INSEGUIMENTO))
	var frame := 0
	for nome in CLIP:
		var c: Array = CLIP[nome]
		cam.fov = c[2]
		cam.look_at_from_position(c[0], c[1])
		_metti_lei(nome)
		if sala.grata:
			var g: Dictionary = sala.dati["grata"]
			sala.grata.global_position = SalaInseguimento.b(g["perno"]) + \
				(Vector3.DOWN * float(g["corsa"]) if nome == "grata" else Vector3.ZERO)
		print("CLIP ", nome, " frame ", frame)
		var t_clip := 0.0
		var foto: Array = scatti.get(nome, [])
		for pezzo: Array in c[3]:
			var an := String(pezzo[0])
			lei.visible = an != ""
			if an != "":
				ap.play(StringName("inseguimento/" + an), 0.0)
			lei.segui_con_la_testa(float(pezzo[2]), 0.3)
			var n := int(round(float(pezzo[1]) * 30.0))
			for i in n:
				(lei.get(&"_bersaglio") as Node3D).global_position = cam.global_position
				await get_tree().process_frame
				frame += 1
				t_clip += 1.0 / 30.0
				if not foto.is_empty() and t_clip >= float(foto[0]):
					await RenderingServer.frame_post_draw
					var f := cartella.path_join("%s_%05.2f.jpg" % [nome, float(foto[0])])
					get_viewport().get_texture().get_image().save_jpg(f, 0.9)
					print("scatto -> ", f)
					foto.pop_front()
	print("FINE frame ", frame)
	get_tree().quit()


## Lei al suo posto: nella vasca 1 girata verso la camera, alla grata girata verso la grata, a SB1 con lo
## spigolo del pozzo a 1 m davanti (BORDO_SB1 di medusa_inseguimento.py), dal lato della camera.
func _metti_lei(nome: String) -> void:
	var L: Array = sala.dati["lei"]
	var pos: Vector3
	var guarda: Vector3
	match nome:
		"vasca":
			pos = SalaInseguimento.b(L[0]["pos"])
			guarda = CLIP["vasca"][0]
		"grata":
			pos = SalaInseguimento.b(L[2]["pos"])
			var g: Dictionary = sala.dati["grata"]
			guarda = SalaInseguimento.b(g["perno"])
		"sb1":
			var pz: Dictionary = sala.dati["pozzo"]
			var r: Array = pz["rett"]
			# lo spigolo sud del pozzo (verso la camera), lei 1 m dietro, 0,8 m sotto il bordo
			pos = b((r[0] + r[2]) / 2.0, r[1] + 1.0, float(pz["bordo"]) - 0.8)
			guarda = b((r[0] + r[2]) / 2.0, r[1] - 5.0, float(pz["bordo"]))
	lei.global_position = pos
	guarda.y = pos.y
	lei.look_at(guarda, Vector3.UP, true)
	lei.visible = true
