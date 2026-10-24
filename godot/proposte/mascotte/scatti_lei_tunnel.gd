extends Node
## Scatti di controllo (interni) dal motore delle animazioni di lei per il tunnel del viaggio sottomarino
## (tools/blender/medusa_inseguimento.py: insegue_aperta, insegue_morde, ritrae, tuffo_sb1, riemerge, schianto), con
## le blend shape della fauce e le vene nell'occhio (attacca senza animazione). Per riferimento il pelo dell'acqua a
## quota 0 (l'origine di lei) e la volta a 6 m, in trasparenza.
## Uso (sotto render.lock):
##   xvfb-run -a -s "-screen 0 960x540x24" godot --path godot --rendering-driver vulkan --resolution 960x540 \
##     --fixed-fps 30 --script res://tests/run.gd -- res://proposte/mascotte/scatti_lei_tunnel.gd <cartella> [anim,anim]

## nome: [durata, quanti scatti]
const ANIM := {
	"insegue_aperta": [2.6, 4], "insegue_morde": [2.6, 6], "ritrae": [2.0, 5], "tuffo_sb1": [1.3, 4],
	"riemerge": [1.8, 5], "schianto": [2.4, 5], "presa": [1.2, 3],
}
const VOLTA := 6.0

var out_dir := ""


func _ready() -> void:
	out_dir = OS.get_cmdline_user_args()[1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _piano(radice: Node3D, y: float, colore: Color) -> void:
	var m := MeshInstance3D.new()
	var p := PlaneMesh.new()
	p.size = Vector2(8, 10)
	m.mesh = p
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colore
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	m.position = Vector3(0, y, 0)
	radice.add_child(m)


func _run() -> void:
	Game.pause_on_focus_loss = false
	var solo: PackedStringArray = OS.get_cmdline_user_args()[2].split(",") if OS.get_cmdline_user_args().size() > 2 else PackedStringArray()
	var radice := Node3D.new()
	add_child(radice)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.04, 0.06)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.65, 0.8)
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	var we := WorldEnvironment.new()
	we.environment = env
	radice.add_child(we)
	var sole := DirectionalLight3D.new()
	sole.rotation_degrees = Vector3(-35, 30, 0)
	sole.light_energy = 1.2
	radice.add_child(sole)
	_piano(radice, 0.0, Color(0.1, 0.3, 0.4, 0.45))
	_piano(radice, VOLTA, Color(0.8, 0.8, 0.3, 0.25))
	var lei := MedusaAffacciata.new()
	lei.model = load("res://assets/models/medusa/medusa.glb")
	lei.bell_material = load("res://assets/models/medusa/medusa_campana.tres")
	lei.material_map = {
		"M_capelli": load("res://assets/models/medusa/medusa_capelli_bagnata.tres"),
		"M_ciocche": load("res://assets/models/medusa/medusa_ciocche_bagnata.tres"),
		"M_mani": load("res://assets/models/medusa/medusa_mani_bagnata.tres"),
		"M_occhio_bulbo": load("res://assets/models/medusa/medusa_occhio.tres"),
		"M_orbita": load("res://assets/models/medusa/medusa_orbita_bagnata.tres"),
		"M_pelle": load("res://assets/models/medusa/medusa_pelle_bagnata.tres"),
		"M_tentacoli": load("res://assets/models/medusa/medusa_tentacoli_bagnata.tres"),
	}
	lei.animazioni_inseguimento = true
	lei.animazione = &"inseguimento/insegue_aperta"
	lei.gocce = false
	radice.add_child(lei)
	for i in 5:
		await get_tree().process_frame
	lei.attacca(0.05, &"")
	var ap := lei.get_model_instance().find_child("AnimationPlayer", true, false) as AnimationPlayer
	var cam := Camera3D.new()
	cam.fov = 50.0
	radice.add_child(cam)
	cam.current = true
	# viste: tre quarti davanti all'altezza del viso, di lato intera
	var viste := {"viso": [Vector3(0.5, 4.5, 2.4), Vector3(0, 4.45, 0.4)], "lato": [Vector3(8.5, 3.0, 0.5), Vector3(0, 2.9, 0.0)], "vittima": [Vector3(0.1, 3.85, 2.7), Vector3(0, 4.1, 0.6)]}
	for nome: String in ANIM:
		if not solo.is_empty() and not nome in solo:
			continue
		var dur: float = ANIM[nome][0]
		var n: int = ANIM[nome][1]
		ap.play(StringName("inseguimento/" + nome), 0.0)
		for i in n:
			var t := dur * i / maxf(n - 1, 1) if nome != "insegue_aperta" and nome != "insegue_morde" else dur * i / n
			if nome == "insegue_morde":
				t = [0.0, 0.3, 0.42, 0.55, 0.75, 1.6][i]
			ap.seek(t, true)
			if OS.has_environment("BLEND"):
				for mi in lei.get_model_instance().find_children("*", "MeshInstance3D", true, false):
					var m := mi as MeshInstance3D
					if m.mesh and m.mesh.get_blend_shape_count() > 0:
						var vals := []
						for b in m.mesh.get_blend_shape_count():
							vals.append("%s=%.2f" % [m.mesh.get_blend_shape_name(b), m.get_blend_shape_value(b)])
						print("BLEND ", nome, " t=", t, " ", m.name, " vis=", m.is_visible_in_tree(), " ", vals)
			for v: String in viste:
				cam.global_position = viste[v][0]
				cam.look_at(viste[v][1], Vector3.UP)
				for k in 3:
					await get_tree().process_frame
				await RenderingServer.frame_post_draw
				var img := get_viewport().get_texture().get_image()
				img.save_jpg(out_dir.path_join("%s_%02d_%s_%.2f.jpg" % [nome, i, v, t]), 0.85)
		print("SCATTI ", nome)
	get_tree().quit(0)
