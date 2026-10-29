extends Node
## Scatti della prova della nebbia viola nell'infermeria (NebbiaViolaProva), come tests/scatti_infermeria_gioco.gd:
## l'infermeria da sola con la sua luce d'ambiente, dagli occhi del giocatore (1,6 m). Per ogni punto di vista lo
## scatto com'è ora e con la nebbia (per ogni forza), dalla stessa camera, e quanto costa la nebbia: il tempo di disegno
## misurato dal motore con e senza (media di 30 fotogrammi).
## Uso: xvfb-run ... godot --path godot --rendering-driver vulkan --resolution 1280x720 --script res://tests/run.gd \
##        -- res://proposte/nebbia_viola/scatti_nebbia.gd <cartella> [stato] [forze separate da virgole]

const CAMERE := {
	"ingresso": [Vector3(1.6, 1.6, 2.7), Vector3(-0.5, 1.0, -2.5)],
	"negatoscopio": [Vector3(0.5, 1.6, -1.2), Vector3(0.5, 1.4, -3.2)],
	"cassaforte": [Vector3(2.0, 1.55, -0.6), Vector3(3.2, 1.3, -1.05)],
}


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var out := a[1]
	var stato: String = a[2] if a.size() > 2 else "chiusa"
	# le varianti: "nome:forza:lontano:oltre:cala" separate da virgole (lontano in metri; oltre e cala: dove e quanto si dirada)
	var varianti: Array = []
	for t in (a[3] if a.size() > 3 else "1.2:1.2:14:100:0").split(","):
		var v := t.split(":")
		varianti.append([v[0], float(v[1]), float(v[2]), float(v[3]), float(v[4])])
	DirAccess.make_dir_recursive_absolute(out)
	Grafica.applica_preset("alto")
	Grafica.imposta("antialiasing", 2)
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color.BLACK
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.1, 0.09, 0.1)
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.tonemap_exposure = 1.15
	e.ssao_enabled = true
	e.volumetric_fog_enabled = true
	e.volumetric_fog_density = 0.015
	we.environment = e
	get_tree().root.add_child(we)
	var f: Node3D = (load("res://scenes/risalita/infermeria.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(f)
	await get_tree().process_frame
	if stato != "chiusa":
		(f.get_node("Interruttore") as WaterButton).powered = true
	var cam := Camera3D.new()
	cam.fov = 62.0
	cam.near = 0.05
	get_tree().root.add_child(cam)
	cam.make_current()
	# le lampade dell'infermeria per l'alone (le più forti, fino a 4)
	var luci: Array = []
	for n in f.find_children("*", "Light3D", true, false):
		var l := n as Light3D
		if l is DirectionalLight3D or not l.is_visible_in_tree() or l.light_energy <= 0.0:
			continue
		luci.append(l)
	luci.sort_custom(func(x, y): return x.light_energy > y.light_energy)
	var nebbia := NebbiaViolaProva.new()
	add_child(nebbia)
	nebbia.su(cam)
	var scelte: Array = []
	for l in luci.slice(0, 4):
		scelte.append([(l as Light3D).global_position, (l as Light3D).light_color, 0.18])
		print("NEBBIA luce %s energia %.2f colore %s a %s" % [(l as Node).name, (l as Light3D).light_energy, (l as Light3D).light_color, (l as Light3D).global_position])
	nebbia.imposta_luci(scelte)
	var vp := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	for nome in CAMERE:
		var c: Array = CAMERE[nome]
		cam.global_position = c[0]
		cam.look_at(c[1], Vector3.UP)
		nebbia.attiva = false
		var senza := await _misura(vp)
		await _scatto(out.path_join("%s_ora.jpg" % nome))
		for v in varianti:
			nebbia.forza = v[1]
			nebbia.imposta(&"lontano", v[2])
			nebbia.imposta(&"oltre", v[3])
			nebbia.imposta(&"cala", v[4])
			nebbia.attiva = true
			var con := await _misura(vp)
			await _scatto(out.path_join("%s_nebbia_%s.jpg" % [nome, v[0]]))
			print("NEBBIA %s %s (forza %.2f, lontano %.1f, oltre %.1f, cala %.2f): disegno senza %.1f ms, con %.1f ms (costa %.1f ms; renderer software)" % [
					nome, v[0], v[1], v[2], v[3], v[4], senza, con, con - senza])
	get_tree().quit()


## Il tempo di disegno del motore (CPU + GPU), in media su 30 fotogrammi, dopo 20 per assestarsi.
func _misura(vp: RID) -> float:
	for i in 20:
		await get_tree().process_frame
	var s := 0.0
	for i in 30:
		await RenderingServer.frame_post_draw
		s += RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.viewport_get_measured_render_time_gpu(vp)
	return s / 30.0


func _scatto(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(file, 0.9)
	print("salvato ", file)
