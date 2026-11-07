extends Node
## Scatti delle salite diverse per vasca (0.3.21, scelta C dell'utente) con la logica vera del gioco (SalaInseguimento:
## _lei_sale e _lei_aggiorna, la testa che segue, i tentacoli morbidi), dagli occhi del giocatore nella vasca:
##  - vasca 3 (vasca_2): la mano che esce per prima e si aggrappa al bordo, lei che si tira su; più uno scatto
##    ravvicinato della mano sul bordo (dentro la vasca, a 1 m dalla mano);
##  - vasca 2 (vasca_1): la salita veloce con l'occhio già puntato su di te.
## Stampa anche, per la vasca 2, l'angolo fra lo sguardo dell'occhio e la direzione degli occhi del giocatore.
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##        --fixed-fps 30 --script res://tests/run.gd -- res://tests/collaudo/scatti_salite_lei.gd <cartella>

const SCENA := "res://scenes/sala/inseguimento/sala_inseguimento.tscn"

static func b(x: float, y: float, z: float) -> Vector3:
	return Vector3(x, z, -y)

## [vasca, occhi del giocatore, istanti della clip (s) da fotografare, ravvicinato]
var CASI := [
	["vasca_2", b(69.5, 4.6, -28.6) + Vector3.UP * 1.6, [0.66, 0.78, 0.92, 1.1, 1.3, 1.6], false],
	["vasca_2", b(70.6, 3.1, -28.6) + Vector3.UP * 1.6, [0.95], true],
	["vasca_1", b(65.0, 27.7, -25.6) + Vector3.UP * 1.6, [0.45, 0.7, 1.0, 1.6], false],
]

var cartella := "user://scatti_salite_lei"


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 1:
		cartella = a[1]
	DirAccess.make_dir_recursive_absolute(cartella)
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	env.environment.sdfgi_enabled = true
	env.environment.sdfgi_cascades = 3
	env.environment.volumetric_fog_density = 0.009
	env.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
	add_child(env)
	var sala := (load(SCENA) as PackedScene).instantiate() as SalaInseguimento
	add_child(sala)
	var p := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as Player
	add_child(p)
	p.process_mode = Node.PROCESS_MODE_DISABLED
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	GameState.player = p
	for i in 60:
		await get_tree().process_frame
	sala.set_physics_process(false)
	var lei := sala.lei
	var ap := lei.get_model_instance().find_child("AnimationPlayer", true, false) as AnimationPlayer
	var n := 0
	for caso in CASI:
		var dove: String = caso[0]
		var occhi: Vector3 = caso[1]
		p.global_position = occhi - Vector3.UP * (p.get_eye_position().y - p.global_position.y)
		# (da capo: lei via e nascosta)
		sala.lei_stato = SalaInseguimento.Lei.VIA
		lei.visible = false
		await get_tree().process_frame
		sala._lei_sale(dove, sala._posto_vasca(int(dove.right(1))))
		var istanti: Array = caso[2]
		var k := 0
		var guarda_mano := bool(caso[3])
		for f in 120:
			sala._lei_aggiorna(1.0 / 30.0, p)
			await get_tree().process_frame
			var tc := ap.current_animation_position if ap.current_animation.begins_with("inseguimento/sale") else 9.0
			# la camera del giocatore guarda lei (la testa), o la mano destra nello scatto ravvicinato
			var mira := lei.get_eye_position()
			if guarda_mano:
				var sk := lei.get_model_instance().find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
				mira = sk.global_transform * sk.get_bone_global_pose(sk.find_bone("mano.R")).origin
			p.look_at_point(mira)
			p.camera.global_transform = p.get_aim_transform()
			p.camera.make_current()
			if k < istanti.size() and tc >= float(istanti[k]) - 0.001:
				await RenderingServer.frame_post_draw
				var nome := "%02d_%s_%s%.2fs.jpg" % [n, "vasca3" if dove == "vasca_2" else "vasca2", "mano_vicino_" if guarda_mano else "", float(istanti[k])]
				get_viewport().get_texture().get_image().save_jpg(cartella.path_join(nome), 0.9)
				if dove == "vasca_1":
					_angolo_occhio(lei, p)
				print("scatto -> ", nome, " (stato ", SalaInseguimento.Lei.keys()[sala.lei_stato], ")")
				n += 1
				k += 1
			if k >= istanti.size():
				break
	get_tree().quit(0)


## Quanto lo sguardo dell'occhio (l'asse +Y dell'osso dell'occhio) si scosta dagli occhi del giocatore.
func _angolo_occhio(lei: Node3D, p: Player) -> void:
	var sk := (lei as MedusaAffacciata).get_model_instance().find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var o := sk.find_bone("occhio")
	if o < 0:
		return
	var g := sk.global_transform * sk.get_bone_global_pose(o)
	var sguardo := g.basis.y.normalized()
	var verso := (p.get_eye_position() - g.origin).normalized()
	print("   occhio: %.0f gradi fra lo sguardo e gli occhi del giocatore" % rad_to_deg(sguardo.angle_to(verso)))
