extends Node3D
## Scena di prova dell'acqua: sala con piscina a onde vuota (pozza torbida e scarico), vasca bimbi
## che si riempie, vasca profonda d'arrivo dello scivolo.
##
## Tasti: 0 aspetto predefinito (scura + pozza torbida), 1/2/3 stessa acqua ovunque (opzioni),
## R riempi / F svuota la vasca d'arrivo, V svuota la pozza (gorgo), B riempie la vasca bimbi,
## L lampo, T qualita' (bassa/media/alta), Spazio lancia una palla, E (tenuto) aspira,
## J (tenuto) spara il getto (usa l'acqua aspirata), C cambia inquadratura,
## P screenshot in user://, H aiuto. Tasto destro + WASD/QE per muoversi.
##
## Da riga di comando (dopo "--"):
##   --shot=<nome> / --shots=a,b,c   inquadrature (vedi SHOTS)
##   --style=<0|1|2|3>               aspetto (0 = predefinito)
##   --quality=<0|1|2>               qualita'
##   --out=<file>                    salva screenshot ed esce (con piu' inquadrature: file_<nome>.jpg)
##   --frames=<n>                    fotogrammi di attesa prima dello screenshot (default 45)
##   --sequence=<nome>               esegue res://demo/scripts/sequence_<nome>.gd (per Movie Maker)
##   --kids=<livello>  --puddle=<livello>  --land=<livello>   livelli iniziali dell'acqua

const STYLES := [
	"res://addons/acqua/presets/stile_1_limpida.tres",
	"res://addons/acqua/presets/stile_2_torbida.tres",
	"res://addons/acqua/presets/stile_3_scura.tres",
]
const DEFAULT_DEEP := "res://addons/acqua/presets/stile_3_scura.tres"
const DEFAULT_PUDDLE := "res://addons/acqua/presets/stile_2_torbida.tres"

# inquadrature: posizione, punto guardato
const SHOTS := {
	"finale": [Vector3(10.2, 0.55, 3.7), Vector3(12.3, 0.1, -6.4)],
	"pozza": [Vector3(-4.8, 2.3, 8.2), Vector3(0.4, -1.6, -3.4)],
	"bimbi": [Vector3(-7.3, 0.95, 2.4), Vector3(-10.4, 0.2, -0.1)],
	"sott_acqua": [Vector3(10.6, -1.3, 2.2), Vector3(12.6, -0.9, -5.2)],
	"sott_acqua_su": [Vector3(11.5, -1.9, 0.5), Vector3(12.3, 0.4, -2.2)],
	"bimbi_sotto": [Vector3(-12.6, -0.25, 2.6), Vector3(-9.8, -0.05, 0.3)],
	"sala": [Vector3(-16.8, 5.2, 10.8), Vector3(2.0, -0.8, -2.0)],
	"gorgo": [Vector3(1.8, 1.5, -0.2), Vector3(0.0, -1.7, -3.6)],
	"pavimento": [Vector3(4.6, 1.5, 10.5), Vector3(8.0, 0.0, 4.4)],
	"vasca_alta": [Vector3(9.4, 2.6, 4.6), Vector3(12.4, -1.4, -2.6)],
}

@onready var land: WaterBody = $LandingPool
@onready var puddle: WaterBody = $WavePuddle
@onready var kids: WaterBody = $KidsPool
@onready var cam: Camera3D = $Camera
@onready var hall: Node3D = $MainHall

var args := {}
var suction: WaterSuction
var jet: WaterJet
var style_index := -1
var shot_names: Array = SHOTS.keys()
var shot_index := 0
var flicker_enabled := true
var _help: Label
var _t := 0.0
var _flash := 0.0
var _next_flash := 9.0


func _ready() -> void:
	args = _parse_args()
	_build_help()
	# lancia dello zaino-pompa davanti alla camera: E aspira, J spara
	var lance := Node3D.new()
	lance.name = "Lancia"
	lance.position = Vector3(0.22, -0.22, -0.55)
	cam.add_child(lance)
	suction = WaterSuction.new()
	lance.add_child(suction)
	jet = WaterJet.new()
	jet.suction = suction
	lance.add_child(jet)
	if args.has("quality"):
		WaterManager.quality = int(args["quality"])
	set_style(int(args.get("style", "0")))
	if args.has("kids"):
		kids.level = float(args["kids"])
	if args.has("puddle"):
		puddle.level = float(args["puddle"])
	if args.has("land"):
		land.level = float(args["land"])
	if args.has("noflicker"):
		flicker_enabled = false
	# interruttori di prova
	if args.has("nomoon") and hall.moon:
		hall.moon.visible = false
	if args.has("noglow"):
		$MedusaGlow.queue_free()
	if args.has("noprops"):
		$Props.queue_free()
	if args.has("nopost"):
		var env: Environment = $WorldEnvironment.environment
		env.glow_enabled = false
		env.ssr_enabled = false
	if args.has("novolfog"):
		$WorldEnvironment.environment.volumetric_fog_enabled = false
	if args.has("noprobe"):
		$ReflectionProbe.queue_free()
	if args.has("noripples"):
		for b in [land, puddle, kids]:
			b.simulate_ripples = false
			b._on_quality_changed(WaterManager.quality)
	apply_shot(args.get("shot", "sala"))
	if args.has("sequence"):
		var seq_path := "res://demo/scripts/sequence_%s.gd" % args["sequence"]
		if ResourceLoader.exists(seq_path):
			var seq: Node = load(seq_path).new()
			seq.name = "Sequence"
			add_child(seq)
	if args.has("out"):
		var shots: Array = args["shots"].split(",") if args.has("shots") else [args.get("shot", "sala")]
		_capture_and_quit(args["out"], int(args.get("frames", "45")), shots)
	elif args.has("measure"):
		_measure_and_quit()


func _parse_args() -> Dictionary:
	var d := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			d[kv[0]] = kv[1] if kv.size() > 1 else "1"
	return d


## 0 = aspetto predefinito (vasche scure e profonde, pozza torbida); 1..3 = stessa acqua ovunque.
func set_style(i: int) -> void:
	style_index = clampi(i, 0, STYLES.size())
	if style_index == 0:
		land.style = load(DEFAULT_DEEP)
		kids.style = load(DEFAULT_DEEP)
		puddle.style = load(DEFAULT_PUDDLE)
	else:
		var st: WaterStyle = load(STYLES[style_index - 1])
		land.style = st
		kids.style = st
		puddle.style = st
	_update_help()


func apply_shot(name: String) -> void:
	if not SHOTS.has(name):
		push_warning("inquadratura sconosciuta: " + name)
		return
	shot_index = shot_names.find(name)
	var s: Array = SHOTS[name]
	if cam.has_method("look_from"):
		cam.look_from(s[0], s[1])
	else:
		cam.global_position = s[0]
		cam.look_at(s[1])


## Salva uno screenshot per ogni inquadratura. Con piu' inquadrature il nome del file riceve il
## suffisso "_<inquadratura>".
func _capture_and_quit(path: String, frames: int, shots: Array) -> void:
	for i in shots.size():
		var shot: String = shots[i]
		apply_shot(shot)
		for f in (frames if i == 0 else maxi(frames / 2, 14)):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var p := path
		if shots.size() > 1:
			p = path.get_basename() + "_" + shot + "." + path.get_extension()
		if p.ends_with(".jpg"):
			img.save_jpg(p, 0.92)
		else:
			img.save_png(p)
		print("screenshot: ", p)
	get_tree().quit()


## Misura i costi ai tre livelli di qualita' (draw call, primitive, tempi) e stampa una tabella.
func _measure_and_quit() -> void:
	var vp := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var lines := ["qualita' | draw call | primitive | oggetti | ms CPU | ms GPU"]
	for q in [0, 1, 2]:
		WaterManager.quality = q
		for f in 20:
			await get_tree().process_frame
		var dc := 0.0
		var prim := 0.0
		var obj := 0.0
		var cpu := 0.0
		var gpu := 0.0
		var n := 8
		for f in n:
			await RenderingServer.frame_post_draw
			dc += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
			prim += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
			obj += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
			cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		lines.append("%d | %d | %d | %d | %.1f | %.1f" % [q, dc / n, prim / n, obj / n, cpu / n, gpu / n])
	for l in lines:
		print("MISURA ", l)
	get_tree().quit()


func _process(delta: float) -> void:
	_t += delta
	# un neon che sfarfalla ogni tanto
	if flicker_enabled and hall.neon_lights.size() > 1:
		var n: Node3D = hall.neon_lights[1]
		var phase := fmod(_t, 7.0)
		var on := 1.0
		if phase > 5.6 and phase < 6.4:
			on = 0.12 if sin(_t * 47.0) * sin(_t * 13.0) > 0.1 else 1.0
		n.get_meta("light").light_energy = 2.2 * on
		n.get_meta("tube").transparency = 0.0 if on > 0.5 else 0.75
	# lampi del temporale attraverso la cupola
	if flicker_enabled and _t > _next_flash:
		_next_flash = _t + randf_range(8.0, 16.0)
		flash()
	_flash = maxf(0.0, _flash - delta * 2.2)
	var f := _flash * (0.6 + 0.4 * sin(_t * 41.0))
	if hall.sky_material:
		hall.sky_material.set_shader_parameter("flash", f)
	if hall.moon:
		hall.moon.light_energy = 0.4 + f * 14.0


func flash() -> void:
	_flash = 1.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo:
		if event.keycode == KEY_E:
			suction.active = event.pressed
		elif event.keycode == KEY_J:
			jet.active = event.pressed
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_0, KEY_1, KEY_2, KEY_3:
			set_style(event.keycode - KEY_0)
		KEY_R:
			land.fill()
		KEY_F:
			land.drain()
		KEY_V:
			puddle.drain(0.012)
		KEY_B:
			kids.fill(0.035)
		KEY_L:
			flash()
		KEY_T:
			WaterManager.quality = (WaterManager.quality + 1) % 3
			_update_help()
		KEY_SPACE:
			throw_ball()
		KEY_C:
			shot_index = (shot_index + 1) % shot_names.size()
			apply_shot(shot_names[shot_index])
		KEY_P:
			var img := get_viewport().get_texture().get_image()
			var p := "user://screenshot_%d.png" % Time.get_ticks_msec()
			img.save_png(p)
			print("salvato ", ProjectSettings.globalize_path(p))
		KEY_H:
			_help.visible = not _help.visible


## Lancia una palla davanti alla camera: quando tocca l'acqua fa uno schizzo e galleggia.
func throw_ball(from := Vector3.INF, velocity := Vector3.INF) -> RigidBody3D:
	var b := RigidBody3D.new()
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.14
	sm.height = 0.28
	mi.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.75, 0.2)
	mat.roughness = 0.4
	mi.material_override = mat
	b.add_child(mi)
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.14
	cs.shape = sh
	b.add_child(cs)
	b.mass = 0.5
	add_child(b)
	b.global_position = cam.global_position - cam.global_basis.z * 0.6 if from == Vector3.INF else from
	b.linear_velocity = (-cam.global_basis.z * 7.0 + Vector3.UP * 2.0) if velocity == Vector3.INF else velocity
	var fl := WaterFloater.new()
	fl.radius = 0.14
	b.add_child(fl)
	return b


func _build_help() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)
	_help = Label.new()
	_help.position = Vector2(12, 10)
	_help.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	_help.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_help.add_theme_constant_override("shadow_offset_x", 1)
	_help.add_theme_constant_override("shadow_offset_y", 1)
	cl.add_child(_help)
	_help.visible = not args.has("out") and not args.has("sequence") and not args.has("nohelp")


func _update_help() -> void:
	if _help == null:
		return
	var sname := "predefinito (scura + pozza torbida)" if style_index == 0 else "opzione %d" % style_index
	_help.text = "Aspetto: %s (0/1/2/3)   Qualita' %s (T)\nR riempi / F svuota vasca d'arrivo   V svuota pozza (gorgo)   B riempi vasca bimbi   L lampo\nSpazio palla   E aspira   J getto   C inquadratura   P screenshot   H aiuto   Tasto destro + WASD/QE per muoversi" % [
		sname, ["bassa", "media", "alta"][WaterManager.quality]]
