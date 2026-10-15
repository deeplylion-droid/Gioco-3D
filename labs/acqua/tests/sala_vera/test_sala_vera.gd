extends Node3D
## Prova dell'acqua nella sala vera (GLB di main copiati in sala_main/, cartella non versionata).
## Prima: bash labs/acqua/tools/prepara_sala_vera.sh (copia da main i GLB della sala in sala_main/).
## Uso: godot --path labs/acqua res://tests/sala_vera/test_sala_vera.tscn -- --out=file.jpg --shots=pozza,bimbi,arrivo

const GLBS := ["sala_architettura", "sala_cupola", "sala_piscina", "sala_area_bimbi", "sala_torre_scivoli", "sala_interattivi", "sala_luci"]

# inquadrature (Godot): posizione, punto guardato, fov verticale
const SHOTS := {
	"pozza": [Vector3(5.6, 1.9, 6.9), Vector3(-0.6, -1.4, 0.8), 58.7],
	"pozza_vicina": [Vector3(3.2, -0.4, 5.6), Vector3(0.0, -2.1, 1.6), 55.0],
	# come lo scatto "piscina" dell'integratore (giocatore in (5.6, 0, 6.6), occhi a 1.65 m)
	"piscina_gioco": [Vector3(5.6, 1.65, 6.6), Vector3(-2.0, -1.0, -6.0), 70.0],
	"bimbi": [Vector3(-12.2, 0.95, -5.4), Vector3(-12.9, 0.25, -11.5), 53.7],
	"arrivo": [Vector3(-8.2, 1.4, 8.6), Vector3(-13.0, -0.6, 1.2), 55.0],
	"panoramica": [Vector3(16.5, 6.4, 10.0), Vector3(-3.0, 2.0, -8.0), 64.6],
	# scie delle luci rosse della parete ovest sulla vasca d'arrivo (come S12)
	"arrivo_scie": [Vector3(-8.4, 0.55, 4.6), Vector3(-19.0, 0.2, 3.0), 55.0],
	# sott'acqua nella vasca d'arrivo, verso la luce subacquea
	"sotto": [Vector3(-11.4, -0.6, 4.3), Vector3(-12.5, -0.68, 6.85), 64.0],
	# la luce rosa della medusa nella vasca bimbi
	"medusa": [Vector3(-10.0, 0.75, -7.6), Vector3(-12.0, 0.15, -9.0), 55.0],
	# prova dei materiali sciolti (acqua del kit scivoli, piano che scorre, pozzanghera)
	"materiali": [Vector3(12.0, 1.5, 12.0), Vector3(12.0, 0.0, 9.2), 60.0],
}

var cam: Camera3D
var bodies := {}


func _ready() -> void:
	var sala := Node3D.new()
	sala.name = "SalaPrincipale"
	sala.set_script(load("res://sala_main/sala_luci_ambiente.gd"))
	for g in GLBS:
		var ps: PackedScene = load("res://sala_main/%s.glb" % g)
		if ps:
			sala.add_child(ps.instantiate())
	add_child(sala)

	# acqua vera al posto dei segnaposto (quote da assets_src/ambiente/INTEGRAZIONE.md)
	bodies["pozza"] = _body("Pozza", Vector3(0, 0, 2), Vector2(8, 8), -2.07, -2.24, -1.9, "res://addons/acqua/presets/stile_2_torbida.tres", true)
	bodies["arrivo"] = _body("VascaArrivo", Vector3(-12.5, 0, 2), Vector2(7, 10), -0.22, -1.1, -0.05, "res://addons/acqua/presets/stile_3_scura.tres", false)
	bodies["bimbi1"] = _body("VascaBimbi1", Vector3(-12.6, 0, -9.6), Vector2(4.4, 3.2), 0.30, 0.02, 0.43, "res://addons/acqua/presets/stile_3_scura.tres", false)
	bodies["bimbi2"] = _body("VascaBimbi2", Vector3(-15.3, 0, -12.4), Vector2(2.8, 2.8), 0.22, 0.02, 0.43, "res://addons/acqua/presets/stile_3_scura.tres", false)

	# superfici bagnabili: pavimento con pozzanghere, vasche con caustiche
	var c1 := WetSurfaceConverter.new()
	c1.name_filter = PackedStringArray(["M_amb_pavimento", "M_amb_zoccolo"])
	c1.puddle_amount = 0.35
	c1.base_wetness = 0.3
	c1.convert_on_ready = false
	add_child(c1)
	c1.convert_root(sala)
	var c2 := WetSurfaceConverter.new()
	c2.name_filter = PackedStringArray(["M_amb_vasca", "M_amb_bordo", "M_amb_scacchi", "M_amb_parete"])
	c2.base_wetness = 0.2
	c2.convert_on_ready = false
	add_child(c2)
	c2.convert_root(sala)
	var c3 := WetSurfaceConverter.new()
	c3.name_filter = PackedStringArray(["M_amb_pozzanghera"])
	c3.puddle_amount = 1.0
	c3.base_wetness = 1.0
	c3.convert_on_ready = false
	add_child(c3)
	c3.convert_root(sala)
	print("superfici convertite: ", c1.converted + c2.converted + c3.converted)

	# bocchette che riempiono la vasca bimbi 1 (getto quando il livello sale)
	for z in [-10.5, -8.7]:
		var inl: Node3D = load("res://addons/acqua/scenes/bocchetta.tscn").instantiate()
		inl.position = Vector3(-14.65, 0.4, z)
		inl.rotation = Vector3(0.0, -PI * 0.5, 0.0)
		add_child(inl)
	# luci subacquee della vasca d'arrivo: luci "immerse"
	for l in sala.find_children("luce_subacquea*", "Light3D", true, false):
		WaterManager.register_underwater_light(l, 2.0, 4.0)
	# la luce rosa della medusa sotto l'acqua della vasca bimbi (solo la luce)
	var glow: Node3D = load("res://addons/acqua/scenes/luce_medusa.tscn").instantiate()
	glow.position = Vector3(-12.0, 0.12, -9.0)
	add_child(glow)

	# gocce dal soffitto sulle pozzanghere e sulle vasche
	for p in [Vector3(4.0, 10.5, 9.0), Vector3(-6.0, 10.5, 8.5), Vector3(0.6, 10.5, 2.4), Vector3(-1.2, 10.5, 1.0),
			Vector3(-12.0, 10.5, -9.2), Vector3(-12.6, 10.5, 3.0), Vector3(9.0, 10.5, 6.0)]:
		var d: Node3D = load("res://addons/acqua/scenes/gocciolatoio.tscn").instantiate()
		d.position = p
		add_child(d)

	cam = Camera3D.new()
	cam.near = 0.03
	cam.far = 160.0
	add_child(cam)
	cam.current = true
	cam.add_child(load("res://addons/acqua/scenes/effetto_sottacqua.tscn").instantiate())

	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if args.has("quality"):
		WaterManager.quality = int(args["quality"])
	if args.has("drain"):
		bodies["pozza"].drain(0.01)
	var shots: Array = args.get("shots", "pozza").split(",")
	if shots.has("materiali"):
		_material_samples()
	_shot(shots[0])
	if args.has("style"):
		var st: WaterStyle = load(["", "res://addons/acqua/presets/stile_1_limpida.tres", "res://addons/acqua/presets/stile_2_torbida.tres", "res://addons/acqua/presets/stile_3_scura.tres"][int(args["style"])])
		for k in bodies:
			bodies[k].style = st
	if args.has("sequence"):
		_sequence = true
		bodies["bimbi1"].level = bodies["bimbi1"].bottom + 0.03
	if args.has("out") and args.has("styles"):
		_capture_styles(args["out"], int(args.get("frames", "30")), shots, args["styles"].split(","))
	elif args.has("out"):
		_capture(args["out"], int(args.get("frames", "30")), shots)
	elif args.has("measure"):
		_measure_and_quit()


## Tre piani sul pavimento con i materiali dell'addon che non stanno nella sala.
func _material_samples() -> void:
	var mats := ["res://addons/acqua/materials/acqua_scivolo_kit.tres", "res://addons/acqua/materials/acqua_che_scorre_piano.tres", "res://addons/acqua/materials/pozzanghera.tres"]
	for i in mats.size():
		var mi := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(1.0, 2.2)
		mi.mesh = pm
		mi.material_override = load(mats[i])
		mi.position = Vector3(10.8 + i * 1.2, 0.012, 9.2)
		add_child(mi)


## Costo dell'acqua: stessa inquadratura senza acqua e con le tre qualita'.
func _measure_and_quit() -> void:
	var vp := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var lines := ["caso | draw call | primitive | ms CPU | ms GPU"]
	for q in [-1, 0, 1, 2]:
		for k in bodies:
			bodies[k].visible = q >= 0
		WaterManager.quality = maxi(q, 0)
		for f in 24:
			await get_tree().process_frame
		var dc := 0.0
		var prim := 0.0
		var cpu := 0.0
		var gpu := 0.0
		var n := 10
		for f in n:
			await RenderingServer.frame_post_draw
			dc += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
			prim += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
			cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		var label := "senza acqua" if q < 0 else "qualita' %d" % q
		lines.append("%s | %d | %d | %.1f | %.1f" % [label, dc / n, prim / n, cpu / n, gpu / n])
	for l in lines:
		print("MISURA ", l)
	get_tree().quit()


# --- sequenza animata (Movie Maker) ---------------------------------------------------------

const SEQ := [
	# inizio (s), da (pos, guarda), a (pos, guarda), fov
	# vasca d'arrivo scura con le scie delle luci rosse (S12)
	[0.0, Vector3(-8.3, 0.75, 5.4), Vector3(-19.0, 0.3, 3.6), Vector3(-9.0, 0.45, 4.0), Vector3(-19.0, 0.15, 2.6), 55.0],
	# pozza torbida sul fondo della piscina: si apre lo scarico e parte il gorgo (S06)
	[5.0, Vector3(4.6, 1.2, 6.6), Vector3(0.0, -2.1, 2.0), Vector3(2.6, 0.2, 5.2), Vector3(0.0, -2.15, 2.0), 55.0],
	# vasca bimbi che si riempie, luce rosa della medusa sotto l'acqua (S09)
	[11.0, Vector3(-9.9, 0.95, -7.1), Vector3(-12.2, 0.12, -9.2), Vector3(-10.5, 0.75, -7.7), Vector3(-12.1, 0.12, -9.1), 55.0],
	# sott'acqua nella vasca d'arrivo, verso la luce subacquea
	[16.0, Vector3(-11.3, -0.6, 3.2), Vector3(-12.5, -0.62, 6.85), Vector3(-11.6, -0.64, 4.4), Vector3(-12.4, -0.42, 6.85), 64.0],
]
const SEQ_LEN := 20.0
var _sequence := false
var _st := 0.0
var _splashed := false


func _process(delta: float) -> void:
	if not _sequence:
		return
	_st += delta
	var cut: Array = SEQ[0]
	var next_t := SEQ_LEN
	for i in SEQ.size():
		if _st >= SEQ[i][0]:
			cut = SEQ[i]
			next_t = SEQ[i + 1][0] if i + 1 < SEQ.size() else SEQ_LEN
	var k := clampf((_st - float(cut[0])) / (next_t - float(cut[0])), 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)
	cam.global_position = (cut[1] as Vector3).lerp(cut[3], k)
	cam.look_at((cut[2] as Vector3).lerp(cut[4], k), Vector3.UP)
	cam.fov = cut[5]
	if _st > 5.5 and not bodies["pozza"].is_draining() and not bodies["pozza"].is_empty():
		bodies["pozza"].drain(0.012)
	if _st > 11.0 and not bodies["bimbi1"].is_filling() and bodies["bimbi1"].level < 0.38:
		bodies["bimbi1"].set_target_level(0.4, 0.06)
	# qualcosa cade nella vasca d'arrivo: schizzo e onde che passano sotto le scie
	if _st > 1.2 and not _splashed:
		_splashed = true
		bodies["arrivo"].splash(Vector3(-11.4, -0.22, 2.4), 1.0)


func _body(nm: String, center: Vector3, size: Vector2, level: float, bottom: float, max_level: float, style: String, vortex: bool) -> WaterBody:
	var b := WaterBody.new()
	b.name = nm
	b.position = center
	b.size = size
	b.bottom = bottom
	b.max_level = max_level
	b.level = level
	b.style = load(style)
	b.vortex_on_drain = vortex
	b.planar_reflection_on_high = nm == "Pozza"   # come nel gioco (build_sala_principale.gd)
	b.env_box_min = Vector3(-20, -2.5, -24)
	b.env_box_max = Vector3(20, 11.5, 12)
	add_child(b)
	return b


func _shot(name: String) -> void:
	var s: Array = SHOTS[name]
	cam.global_position = s[0]
	cam.look_at(s[1], Vector3.UP)
	cam.fov = s[2]


## Le stesse inquadrature con i tre aspetti dell'acqua (per le proposte): file <nome>_<scatto>_stile<N>.jpg
func _capture_styles(path: String, frames: int, shots: Array, styles: Array) -> void:
	const PRESETS := ["", "res://addons/acqua/presets/stile_1_limpida.tres", "res://addons/acqua/presets/stile_2_torbida.tres", "res://addons/acqua/presets/stile_3_scura.tres"]
	for st in styles:
		var res: WaterStyle = load(PRESETS[int(st)])
		for k in bodies:
			if k != "pozza":
				bodies[k].style = res
		for i in shots.size():
			_shot(shots[i])
			for f in maxi(frames / 2, 12):
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			var p: String = path.get_basename() + "_" + shots[i] + "_stile" + st + "." + path.get_extension()
			img.save_jpg(p, 0.92)
			print("screenshot: ", p)
	get_tree().quit()


func _capture(path: String, frames: int, shots: Array) -> void:
	for i in shots.size():
		_shot(shots[i])
		for f in (frames if i == 0 else maxi(frames / 2, 12)):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var p := path
		if shots.size() > 1:
			p = path.get_basename() + "_" + shots[i] + "." + path.get_extension()
		img.save_jpg(p, 0.92)
		print("screenshot: ", p)
	get_tree().quit()
