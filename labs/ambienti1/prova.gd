extends Node3D
## Carica i glTF degli ambienti interni da assets_src (a runtime, senza copiarli), sostituisce le luci
## dei neon con delle OmniLight, aggiunge nebbia volumetrica e salva uno screenshot per inquadratura.
## Uso: godot --path labs/ambienti1 -- [inquadratura] [cartella_uscita]

const GLTF := "../../assets_src/ambienti_interni/gltf/"
const OCCHI := 1.62
# posizione e punto guardato in coordinate Blender (x, y, z): convertite sotto
const INQ := {
	"corridoio_risveglio": [Vector3(21.2, 1.35, OCCHI), Vector3(9.0, 1.05, 1.25), 75.0],
	"spogliatoi": [Vector3(6.8, 3.25, OCCHI), Vector3(6.3, 12.0, 1.15), 75.0],
	"lavapiedi_tornello": [Vector3(9.7, 11.4, OCCHI), Vector3(9.8, 18.0, 1.2), 75.0],
	"stanzino": [Vector3(11.35, 8.55, OCCHI), Vector3(15.2, 8.2, 1.15), 75.0],
}

func b2g(v: Vector3) -> Vector3:
	return Vector3(v.x, v.z, -v.y)

func _ready() -> void:
	var base := ProjectSettings.globalize_path("res://").path_join(GLTF).simplify_path()
	for nome in ["corridoio", "spogliatoi", "stanzino"]:
		var doc := GLTFDocument.new()
		var stato := GLTFState.new()
		var err := doc.append_from_file(base.path_join(nome + ".gltf"), stato)
		if err != OK:
			push_error("non carico %s: %d" % [nome, err])
			continue
		var scena := doc.generate_scene(stato)
		add_child(scena)
		_sistema(scena)
	_ambiente()
	var args := OS.get_cmdline_user_args()
	var quali: Array = [args[0]] if args.size() > 0 and args[0] != "tutte" else INQ.keys()
	var uscita: String = args[1] if args.size() > 1 else "user://"
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	for q in quali:
		var d: Array = INQ[q]
		cam.fov = d[2]
		cam.position = b2g(d[0])
		cam.look_at(b2g(d[1]))
		for i in 40:
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_jpg(uscita.path_join("godot_" + q + ".jpg"), 0.92)
		print("screenshot ", q)
	get_tree().quit()

func _sistema(n: Node) -> void:
	for c in n.get_children():
		_sistema(c)
	if n is MeshInstance3D and n.name.begins_with("acqua"):
		# acqua: superficie scura e lucida (in attesa dello shader dell'acqua)
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.05, 0.06, 0.06, 0.45)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.02
		m.metallic = 0.3
		m.metallic_specular = 0.6
		n.material_override = m
	if n is Light3D:
		n.shadow_enabled = true
		if n is OmniLight3D:
			n.omni_range = 7.0
			n.light_energy = 0.55
			n.omni_attenuation = 1.4
	if n.name.ends_with("_luce") and n.name.begins_with("neon") and not n is Light3D:
		var l := OmniLight3D.new()
		l.light_color = Color(0.78, 1.0, 0.9)
		l.light_energy = 1.4
		l.omni_range = 6.0
		l.shadow_enabled = true
		n.add_child(l)

func _ambiente() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.6, 0.7)
	env.ambient_light_energy = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.1
	env.ssao_enabled = true
	env.ssr_enabled = true
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.035
	env.volumetric_fog_albedo = Color(0.85, 0.82, 0.8)
	env.volumetric_fog_length = 30.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
