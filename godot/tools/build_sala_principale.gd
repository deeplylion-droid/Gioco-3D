extends SceneTree
## Genera la demo giocabile della sala principale: res://scenes/sala_principale.tscn
## (più i materiali in assets/materials/sala/ e l'ambiente assets/env/sala_environment.tres).
## Uso: godot --headless --path godot --script res://tools/build_sala_principale.gd
## Dopo averla generata si può modificare a mano nell'editor; rilanciando questo script
## le modifiche fatte a mano si perdono.
##
## Pianta (docs/livello/mappa_capitolo1.png, misure in metri, -Z = nord):
##  - sala 48 x 35 m, alta 10 m, cupola di 26 m sopra la piscina;
##  - piscina a onde vuota al centro (13 x 23 m): spiaggia a nord, parte profonda a sud con la pozza;
##  - statua sul bordo sud, davanti all'ingresso dagli spogliatoi (muro sud);
##  - area bimbi a ovest (nord-ovest) con il secchio gigante, vasca d'arrivo a sud-ovest;
##  - torre degli scivoli a est (nord-est).
## Ogni parte grafica sta in un AssetSlot: i GLB veri sostituiscono il figlio "Graybox".

const OUT := "res://scenes/sala_principale.tscn"
const MAT_DIR := "res://assets/materials/sala/"
const UNION := CSGShape3D.OPERATION_UNION
const SUB := CSGShape3D.OPERATION_SUBTRACTION

const POOL_CENTER := Vector3(1.0, 0.0, -2.5)
const POOL_WIDTH := 13.0
const POOL_PROFILE := [Vector2(-11.5, 0.0), Vector2(-3.5, 1.2), Vector2(4.0, 2.4), Vector2(11.5, 2.4)]
const DEEP_Y := -2.4

var level: Node3D
var M := {}
var S := {}
var _n := 0


func _initialize() -> void:
	S.player = load("res://scenes/player/player.tscn")
	S.turbine = load("res://scenes/props/turbine.tscn")
	S.door = load("res://scenes/props/powered_door.tscn")
	S.button = load("res://scenes/props/water_button.tscn")
	S.tank = load("res://scenes/props/water_tank.tscn")
	S.ladder = load("res://scenes/props/ladder.tscn")
	S.polaroid = load("res://scenes/props/polaroid.tscn")
	_materials()
	level = Node3D.new()
	level.name = "SalaPrincipale"
	level.set_script(load("res://scripts/game/sala_principale.gd"))
	_environment()
	_hall()
	_pool()
	_statue()
	_kids_area()
	_arrival_pool()
	_slide_tower()
	_lights()
	_gameplay()
	var packed := PackedScene.new()
	var err := packed.pack(level)
	if err == OK:
		err = ResourceSaver.save(packed, OUT)
	print("build_sala_principale: ", error_string(err))
	level.free()
	quit(0 if err == OK else 1)


# --- Materiali e ambiente ---------------------------------------------------------------

func _grid_mat(file: String, base: Color, line: Color, rough: float, grid := 1.0, sub := 0.35, spec := 0.5) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/graybox.gdshader")
	m.set_shader_parameter(&"base_color", base)
	m.set_shader_parameter(&"line_color", line)
	m.set_shader_parameter(&"grid_size", grid)
	m.set_shader_parameter(&"sub_lines", sub)
	m.set_shader_parameter(&"roughness_value", rough)
	m.set_shader_parameter(&"specular_value", spec)
	return _save(m, file)


func _std_mat(file: String, color: Color, rough: float, emission := Color.BLACK, energy := 0.0, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color, alpha)
	m.roughness = rough
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = energy
	return _save(m, file)


func _save(m: Material, file: String) -> Material:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MAT_DIR))
	var path := MAT_DIR + file + ".tres"
	ResourceSaver.save(m, path)
	m.take_over_path(path)
	return m


func _materials() -> void:
	M.floor = _grid_mat("pavimento", Color(0.19, 0.21, 0.22), Color(0.12, 0.13, 0.14), 0.2, 1.0, 0.6, 0.65)
	M.wall = _grid_mat("muro", Color(0.31, 0.34, 0.35), Color(0.24, 0.26, 0.27), 0.8, 1.0, 0.25)
	M.ceiling = _grid_mat("soffitto", Color(0.16, 0.17, 0.18), Color(0.12, 0.13, 0.14), 0.9)
	M.metal = _grid_mat("metallo", Color(0.13, 0.13, 0.14), Color(0.1, 0.1, 0.11), 0.45, 1.0, 0.0, 0.6)
	M.rust = _grid_mat("ruggine", Color(0.32, 0.17, 0.1), Color(0.24, 0.12, 0.07), 0.8, 1.0, 0.0)
	M.pool = _grid_mat("piastrelle_piscina", Color(0.24, 0.42, 0.44), Color(0.15, 0.27, 0.29), 0.3, 1.0, 0.85, 0.6)
	M.pool_wall = _grid_mat("piastrelle_parete", Color(0.27, 0.45, 0.48), Color(0.17, 0.3, 0.32), 0.35, 1.0, 0.85, 0.6)
	M.coping = _grid_mat("bordo_piscina", Color(0.55, 0.56, 0.52), Color(0.4, 0.4, 0.38), 0.45, 0.5, 0.0)
	M.red = _grid_mat("gioco_rosso", Color(0.75, 0.12, 0.1), Color(0.55, 0.08, 0.06), 0.45, 1.0, 0.0)
	M.yellow = _grid_mat("gioco_giallo", Color(0.9, 0.7, 0.1), Color(0.65, 0.5, 0.05), 0.45, 1.0, 0.0)
	M.blue = _grid_mat("gioco_blu", Color(0.12, 0.35, 0.8), Color(0.08, 0.24, 0.55), 0.45, 1.0, 0.0)
	M.green = _grid_mat("gioco_verde", Color(0.2, 0.62, 0.3), Color(0.12, 0.42, 0.2), 0.45, 1.0, 0.0)
	M.orange = _grid_mat("gioco_arancio", Color(0.92, 0.42, 0.1), Color(0.65, 0.28, 0.06), 0.45, 1.0, 0.0)
	M.purple = _grid_mat("gioco_viola", Color(0.48, 0.25, 0.7), Color(0.33, 0.16, 0.5), 0.45, 1.0, 0.0)
	M.soft = _grid_mat("tappeto_morbido", Color(0.2, 0.4, 0.55), Color(0.14, 0.3, 0.42), 0.8, 1.0, 0.0)
	M.locker = _grid_mat("armadietti", Color(0.45, 0.6, 0.62), Color(0.3, 0.42, 0.44), 0.5, 0.5, 0.0)
	M.glass = _std_mat("vetro_cupola", Color(0.06, 0.09, 0.14), 0.05, Color(0.25, 0.35, 0.55), 0.15, 0.3)
	(M.glass as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	(M.glass as StandardMaterial3D).metallic = 0.3
	ResourceSaver.save(M.glass, M.glass.resource_path)
	M.neon = _std_mat("neon", Color(0.8, 0.95, 1.0), 0.3, Color(0.75, 0.92, 1.0), 3.0)
	M.emergency = _std_mat("luce_emergenza", Color(0.5, 0.05, 0.03), 0.4, Color(1.0, 0.08, 0.04), 4.0)
	M.lamp = _std_mat("lampada_calda", Color(0.6, 0.5, 0.35), 0.4, Color(1.0, 0.78, 0.5), 4.0)
	M.porthole = _std_mat("oblo_vetro", Color(0.03, 0.05, 0.08), 0.05, Color(0.12, 0.18, 0.3), 0.6)
	M.hole = _std_mat("buio", Color(0.0, 0.0, 0.0), 1.0)
	(M.hole as StandardMaterial3D).shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ResourceSaver.save(M.hole, M.hole.resource_path)
	var murky := (load("res://assets/materials/water_placeholder.tres") as ShaderMaterial).duplicate() as ShaderMaterial
	murky.set_shader_parameter(&"shallow_color", Color(0.16, 0.22, 0.16))
	murky.set_shader_parameter(&"deep_color", Color(0.03, 0.06, 0.05))
	murky.set_shader_parameter(&"alpha", 0.86)
	M.murky = _save(murky, "acqua_torbida")


func _environment() -> void:
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.012, 0.016, 0.028)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.4, 0.5, 0.66)
	e.ambient_light_energy = 0.32
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.tonemap_exposure = 1.25
	e.ssao_enabled = true
	e.ssao_intensity = 1.6
	e.ssr_enabled = true
	e.ssr_max_steps = 48
	e.glow_enabled = true
	e.glow_intensity = 0.75
	e.glow_bloom = 0.06
	e.glow_hdr_threshold = 0.9
	e.volumetric_fog_enabled = true
	e.volumetric_fog_density = 0.022
	e.volumetric_fog_albedo = Color(0.65, 0.7, 0.78)
	e.volumetric_fog_anisotropy = 0.35
	e.volumetric_fog_length = 48.0
	e.volumetric_fog_ambient_inject = 0.15
	ResourceSaver.save(e, "res://assets/env/sala_environment.tres")
	e.take_over_path("res://assets/env/sala_environment.tres")
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = e
	own(we)
	M.env = e


# --- Sala: muri, pavimento, soffitto, cupola, ballatoi, oblò, ingresso ---------------------

func _hall() -> void:
	var slot := slot_node(level, "Sala")
	var gb := group(slot, "Graybox")
	var csg := csg_root(gb, "Struttura")
	box(csg, "Esterno", Vector3(49.2, 11.0, 36.2), Vector3(0, 5.1, 0), UNION, M.wall)
	box(csg, "Interno", Vector3(48, 10.05, 35), Vector3(0, 4.975, 0), SUB, M.wall)
	box(csg, "Pavimento", Vector3(48.4, 0.05, 35.4), Vector3(0, -0.025, 0), UNION, M.floor)
	box(csg, "Soffitto", Vector3(48.4, 0.05, 35.4), Vector3(0, 9.975, 0), UNION, M.ceiling)
	# Spogliatoi: l'uscita da cui si entra nella sala.
	box(csg, "SpogliatoiEsterno", Vector3(5.2, 3.9, 6.0), Vector3(0, 1.55, 20.9), UNION, M.wall)
	box(csg, "SpogliatoiInterno", Vector3(4, 3.05, 5.4), Vector3(0, 1.475, 21.0), SUB, M.wall)
	box(csg, "SpogliatoiPavimento", Vector3(4.2, 0.05, 5.6), Vector3(0, -0.025, 21.0), UNION, M.floor)
	# Ballatoi lungo i muri nord, ovest ed est (non raggiungibili), con le colonne.
	box(csg, "BallatoioNord", Vector3(48, 0.3, 2.0), Vector3(0, 5.15, -16.5), UNION, M.metal)
	box(csg, "BallatoioOvest", Vector3(2.0, 0.3, 33), Vector3(-23, 5.15, 1.0), UNION, M.metal)
	box(csg, "BallatoioEst", Vector3(2.0, 0.3, 33), Vector3(23, 5.15, 1.0), UNION, M.metal)
	for x in [-16.0, -8.0, 8.0, 16.0]:
		cyl(csg, "ColonnaN", 0.28, 5.0, Vector3(x, 2.5, -15.6), UNION, M.metal)
	for z in [-8.0, 0.0, 8.0, 15.0]:
		cyl(csg, "ColonnaO", 0.28, 5.0, Vector3(-22.1, 2.5, z), UNION, M.metal)
		cyl(csg, "ColonnaE", 0.28, 5.0, Vector3(22.1, 2.5, z), UNION, M.metal)
	# Buchi: cupola, piscina, vasca d'arrivo, porta degli spogliatoi.
	cyl(csg, "BucoCupola", 13.0, 1.4, Vector3(POOL_CENTER.x, 10.3, POOL_CENTER.z), SUB, M.ceiling)
	box(csg, "BucoPiscina", Vector3(POOL_WIDTH + 0.04, 3.1, 23.04), Vector3(POOL_CENTER.x, -1.45, POOL_CENTER.z), SUB, M.pool_wall)
	box(csg, "BucoVascaArrivo", Vector3(11.0, 1.5, 8.0), Vector3(-15, -0.6, 7.0), SUB, M.wall)
	box(csg, "PortaSpogliatoi", Vector3(2.4, 2.8, 1.8), Vector3(0, 1.401, 17.6), SUB, M.wall)
	# Ringhiere dei ballatoi (solo grafica).
	var rail := group(gb, "Ringhiere")
	mesh_box(rail, Vector3(48, 0.06, 0.06), Vector3(0, 6.3, -15.5), M.metal)
	mesh_box(rail, Vector3(0.06, 0.06, 33), Vector3(-22.0, 6.3, 1.0), M.metal)
	mesh_box(rail, Vector3(0.06, 0.06, 33), Vector3(22.0, 6.3, 1.0), M.metal)
	# Cartelloni colorati sui ballatoi (stile B): solo forme, niente scritte.
	var signs := group(gb, "Cartelloni")
	for s in [[Vector3(-10, 5.9, -15.45), M.blue, M.yellow], [Vector3(10, 5.9, -15.45), M.purple, M.orange], [Vector3(-1, 5.9, -15.45), M.green, M.red]]:
		mesh_box(signs, Vector3(6.0, 1.3, 0.08), s[0], s[1])
		var wave := mesh_box(signs, Vector3(4.6, 0.35, 0.1), s[0] + Vector3(0, -0.15, 0.02), s[2])
		wave.rotation = Vector3(0, 0, 0.08)
	# Oblò sui muri (fuori c'è la tempesta).
	var ports := group(gb, "Oblo")
	for z in [-12.0, -6.0, 6.0, 12.0]:
		porthole(ports, Vector3(-23.95, 2.4, z), PI * 0.5)
		porthole(ports, Vector3(23.95, 2.4, z), -PI * 0.5)
		porthole(ports, Vector3(-23.95, 7.6, z), PI * 0.5)
		porthole(ports, Vector3(23.95, 7.6, z), -PI * 0.5)
	for x in [-14.0, -7.0, 7.0, 14.0]:
		porthole(ports, Vector3(x, 2.4, 17.45), PI)
	# Armadietti negli spogliatoi.
	var lockers := csg_root(gb, "Armadietti")
	for z in [19.0, 19.6, 20.2, 20.8, 21.4, 22.0, 22.6]:
		box(lockers, "ArmadiettoO", Vector3(0.5, 1.9, 0.56), Vector3(-1.72, 0.95, z), UNION, M.locker)
		box(lockers, "ArmadiettoE", Vector3(0.5, 1.9, 0.56), Vector3(1.72, 0.95, z), UNION, M.locker)
	# Cupola di vetro con la struttura.
	var dome: Node3D = load("res://scripts/environment/dome.gd").new()
	dome.name = "Cupola"
	dome.set(&"radius", 13.0)
	dome.set(&"height", 7.0)
	dome.set(&"glass_material", M.glass)
	dome.set(&"frame_material", M.metal)
	dome.position = Vector3(POOL_CENTER.x, 10.0, POOL_CENTER.z)
	own(dome, gb)


# --- Piscina a onde vuota con la pozza e l'enigma dello scarico ---------------------------

func _pool() -> void:
	var pool := group(level, "Piscina")
	var slot := slot_node(pool, "Vasca")
	var gb := group(slot, "Graybox")
	var basin: StaticBody3D = load("res://scripts/environment/pool_basin.gd").new()
	basin.name = "FondoPiscina"
	basin.position = POOL_CENTER
	basin.set(&"width", POOL_WIDTH)
	basin.set(&"profile", PackedVector2Array(POOL_PROFILE))
	basin.set(&"floor_material", M.pool)
	basin.set(&"wall_material", M.pool_wall)
	own(basin, gb)
	# Bordo della piscina (a nord la spiaggia entra in acqua senza gradino).
	var coping := csg_root(gb, "Bordo")
	var x0 := POOL_CENTER.x - POOL_WIDTH * 0.5
	var x1 := POOL_CENTER.x + POOL_WIDTH * 0.5
	box(coping, "BordoOvest", Vector3(0.5, 0.06, 23.5), Vector3(x0 - 0.25, 0.03, -2.25), UNION, M.coping)
	box(coping, "BordoEst", Vector3(0.5, 0.06, 23.5), Vector3(x1 + 0.25, 0.03, -2.25), UNION, M.coping)
	box(coping, "BordoSud", Vector3(POOL_WIDTH + 1.0, 0.06, 0.5), Vector3(POOL_CENTER.x, 0.03, 9.25), UNION, M.coping)
	mesh_box(gb, Vector3(POOL_WIDTH + 1.0, 0.02, 0.35), Vector3(POOL_CENTER.x, 0.065, 9.25), M.metal, "Griglia")
	# Giocattoli rimasti sul fondo (ricompaiono quando la pozza si svuota).
	var toys := group(gb, "Giocattoli")
	for t in [[Vector3(0.0, DEEP_Y + 0.22, 6.0), 0.22, M.red], [Vector3(3.2, DEEP_Y + 0.18, 4.4), 0.18, M.yellow],
			[Vector3(5.5, DEEP_Y + 0.25, 7.2), 0.25, M.blue], [Vector3(-3.6, DEEP_Y + 0.2, 7.8), 0.2, M.green]]:
		var ball := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = t[1]
		sm.height = t[1] * 2.0
		ball.mesh = sm
		ball.material_override = t[2]
		ball.position = t[0]
		own(ball, toys)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.22
	tm.outer_radius = 0.42
	ring.mesh = tm
	ring.material_override = M.orange
	ring.position = Vector3(2.0, DEEP_Y + 0.1, 6.8)
	own(ring, toys)
	# La pozza: si aspira, e lo scarico la svuota quando gira la turbina.
	var puddle: WaterTank = S.tank.instantiate()
	puddle.name = "Pozza"
	puddle.build_walls = false
	puddle.inner_size = Vector3(POOL_WIDTH, 0.6, 9.6)
	puddle.capacity_liters = 150.0
	puddle.max_fill = 0.7
	puddle.fill = 0.7
	puddle.drain_time = 24.0
	puddle.water_material = M.murky
	puddle.position = Vector3(POOL_CENTER.x, DEEP_Y, 4.2)
	own(puddle, pool)
	mesh_box(pool, Vector3(0.9, 0.02, 0.9), Vector3(POOL_CENTER.x, DEEP_Y + 0.01, 7.6), M.metal, "Scarico")
	var vortex: MeshInstance3D = load("res://scripts/environment/drain_vortex.gd").new()
	vortex.name = "Gorgo"
	vortex.set(&"tank", puddle)
	vortex.position = Vector3(POOL_CENTER.x, DEEP_Y + 0.4, 7.6)
	own(vortex, pool)
	# Turbina dello scarico, in alto sul muro della parte profonda, bloccata da un gonfiabile.
	var turbine: Turbine = S.turbine.instantiate()
	turbine.name = "TurbinaScarico"
	turbine.radius = 0.6
	turbine.position = Vector3(4.5, -0.9, 9.0)
	turbine.rotation = Vector3(0, PI, 0)
	own(turbine, pool)
	var drains: Array[PowerSource] = [turbine]
	puddle.drain_sources = drains
	_inflatable(pool, turbine)
	# Portello della camera delle onde sul fondo e il suo pulsante (sott'acqua finché c'è la pozza).
	mesh_box(pool, Vector3(1.5, 0.004, 1.5), Vector3(-2.5, DEEP_Y + 0.003, 5.0), M.hole, "Buio")
	var hatch_button: WaterButton = S.button.instantiate()
	hatch_button.name = "PulsantePortello"
	hatch_button.mode = WaterButton.Mode.LATCH
	hatch_button.radius = 0.18
	hatch_button.position = Vector3(x0, DEEP_Y + 0.28, 5.0)
	hatch_button.rotation = Vector3(0, PI * 0.5, 0)
	own(hatch_button, pool)
	var hatch: PoweredDoor = S.door.instantiate()
	hatch.name = "Portello"
	hatch.size = Vector3(1.6, 1.6, 0.06)
	hatch.open_offset = Vector3(1.7, 0, 0)
	hatch.position = Vector3(-2.5, DEEP_Y + 0.02, 4.2)
	hatch.rotation = Vector3(PI * 0.5, 0, 0)
	var hatch_sources: Array[PowerSource] = [hatch_button]
	hatch.sources = hatch_sources
	own(hatch, pool)
	# Scaletta per uscire dalla parte profonda.
	var ladder: Node3D = S.ladder.instantiate()
	ladder.name = "Scaletta"
	ladder.set(&"height", 2.4)
	ladder.position = Vector3(x1, DEEP_Y, 3.0)
	ladder.rotation = Vector3(0, -PI * 0.5, 0)
	own(ladder, pool)
	polaroid(pool, "Polaroid05", Vector3(-0.8, DEEP_Y, 6.6))
	level.set(&"hatch", hatch)


func _inflatable(parent: Node, turbine: Turbine) -> void:
	var body: RigidBody3D = load("res://scripts/mechanisms/stuck_inflatable.gd").new()
	body.name = "GonfiabileIncastrato"
	body.mass = 0.6
	body.collision_layer = Layers.PROPS
	body.collision_mask = Layers.WORLD | Layers.PLAYER | Layers.PROPS
	body.position = turbine.position + Vector3(0.1, 0.05, -0.42)
	body.rotation = Vector3(PI * 0.5, 0, 0.3)
	body.set(&"jams", turbine)
	own(body, parent)
	var cs := CollisionShape3D.new()
	cs.name = "CollisionShape3D"
	var shape := CylinderShape3D.new()
	shape.radius = 0.45
	shape.height = 0.2
	cs.shape = shape
	own(cs, body)
	var mi := MeshInstance3D.new()
	mi.name = "Ciambella"
	var tm := TorusMesh.new()
	tm.inner_radius = 0.24
	tm.outer_radius = 0.46
	mi.mesh = tm
	mi.material_override = M.red
	own(mi, body)
	var hit := WaterHitbox.new()
	hit.name = "Bersaglio"
	own(hit, body)
	var hs := CollisionShape3D.new()
	hs.name = "CollisionShape3D"
	var hshape := CylinderShape3D.new()
	hshape.radius = 0.5
	hshape.height = 0.4
	hs.shape = hshape
	own(hs, hit)


# --- Statua sul piedistallo, lampione e pulsante della sigla -------------------------------

func _statue() -> void:
	var statue := group(level, "Statua")
	statue.position = Vector3(0, 0, 11.6)
	var ped := csg_root(statue, "Piedistallo")
	cyl(ped, "Base", 1.25, 1.0, Vector3(0, 0.5, 0), UNION, M.wall)
	cyl(ped, "Fascia", 1.27, 0.25, Vector3(0, 0.55, 0), UNION, M.blue)
	cyl(ped, "Cappello", 1.32, 0.08, Vector3(0, 1.0, 0), UNION, M.coping)
	var slot := slot_node(statue, "Medusa")
	slot.position = Vector3(0, 1.04, 0)
	var placeholder: Node3D = load("res://scripts/environment/medusa_placeholder.gd").new()
	placeholder.name = "Graybox"
	own(placeholder, slot)
	level.set(&"statue", placeholder)
	var jingle: WaterButton = S.button.instantiate()
	jingle.name = "PulsanteSigla"
	jingle.mode = WaterButton.Mode.MOMENTARY
	jingle.radius = 0.16
	jingle.position = Vector3(0, 0.58, 1.27)
	own(jingle, statue)
	level.set(&"jingle_button", jingle)
	# Lampione: si accende quando entri nella sala (FlickerLight parte spenta).
	var post := csg_root(statue, "Lampione")
	cyl(post, "Palo", 0.07, 5.2, Vector3(2.2, 2.6, 1.0), UNION, M.rust)
	var arm := box(post, "Braccio", Vector3(0.08, 0.08, 1.75), Vector3(1.55, 5.12, 0.6), UNION, M.rust)
	arm.rotation = Vector3(0, atan2(1.3, 0.8), 0)
	var head := MeshInstance3D.new()
	head.name = "Lampada"
	var cm := CylinderMesh.new()
	cm.top_radius = 0.12
	cm.bottom_radius = 0.32
	cm.height = 0.32
	head.mesh = cm
	head.material_override = M.lamp
	head.position = Vector3(0.9, 4.98, 0.2)
	own(head, statue)
	var spot := SpotLight3D.new()
	spot.name = "LuceStatua"
	spot.position = Vector3(0.9, 4.8, 0.2)
	spot.rotation = Vector3(-PI * 0.5, 0, 0)
	spot.light_color = Color(1.0, 0.78, 0.52)
	spot.light_energy = 12.0
	spot.spot_range = 9.0
	spot.spot_angle = 36.0
	spot.shadow_enabled = true
	spot.light_volumetric_fog_energy = 1.6
	own(spot, statue)
	var flicker: Node = load("res://scripts/environment/flicker_light.gd").new()
	flicker.name = "Sfarfallio"
	flicker.set(&"light", spot)
	flicker.set(&"mesh", head)
	flicker.set(&"base_energy", 12.0)
	flicker.set(&"base_emission", 4.0)
	flicker.set(&"flicker_rate", 0.05)
	flicker.set(&"min_level", 0.3)
	flicker.set(&"start_off", true)
	own(flicker, statue)
	level.set(&"statue_lamp", flicker)


# --- Area bimbi (ovest) con il secchio gigante ---------------------------------------------

func _kids_area() -> void:
	var slot := slot_node(level, "AreaBimbi")
	var gb := group(slot, "Graybox")
	var csg := csg_root(gb, "Struttura")
	box(csg, "TappetoMorbido", Vector3(13, 0.02, 13), Vector3(-14.5, 0.01, -7.5), UNION, M.soft)
	for p in [Vector2(-19, -13), Vector2(-14, -13), Vector2(-19, -8), Vector2(-14, -8)]:
		cyl(csg, "Palo", 0.16, 5.6, Vector3(p.x, 2.8, p.y), UNION, M.red)
	box(csg, "Piano1", Vector3(5.2, 0.2, 5.2), Vector3(-16.5, 1.5, -10.5), UNION, M.yellow)
	box(csg, "Piano2", Vector3(5.2, 0.2, 2.6), Vector3(-16.5, 3.5, -11.8), UNION, M.green)
	box(csg, "Tettoia", Vector3(5.8, 0.15, 5.8), Vector3(-16.5, 5.65, -10.5), UNION, M.red)
	# Scala crollata: mancano gli ultimi gradini.
	for i in 4:
		box(csg, "Gradino", Vector3(1.2, 0.3, 0.45), Vector3(-12.2, 0.15 + i * 0.3, -6.6 - i * 0.45), UNION, M.blue)
	# Scivolo dal primo piano.
	var slide := box(csg, "Scivolo", Vector3(1.0, 0.1, 4.2), Vector3(-17.0, 0.85, -6.1), UNION, M.orange)
	slide.rotation = Vector3(0.37, 0, 0)
	# Funghi-fontana e cannoncini ad acqua.
	for f in [Vector3(-11.0, 0, -3.6), Vector3(-12.8, 0, -1.8), Vector3(-9.6, 0, -6.4)]:
		cyl(csg, "GamboFungo", 0.16, 1.7, f + Vector3(0, 0.85, 0), UNION, M.yellow)
		var cap := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.95
		sm.height = 0.95
		sm.is_hemisphere = true
		cap.mesh = sm
		cap.scale = Vector3(1, 0.45, 1)
		cap.material_override = M.red
		cap.position = f + Vector3(0, 1.65, 0)
		own(cap, gb)
	for c in [Vector3(-9.2, 0, -10.0), Vector3(-13.5, 0, -2.0)]:
		cyl(csg, "PaloCannone", 0.12, 1.1, c + Vector3(0, 0.55, 0), UNION, M.blue)
		var barrel := cyl(csg, "Cannone", 0.12, 0.8, c + Vector3(0, 1.2, 0.25), UNION, M.yellow)
		barrel.rotation = Vector3(PI * 0.4, 0, 0)
	# Il secchio gigante in cima, sui suoi sostegni.
	var bucket_frame := csg_root(gb, "SostegnoSecchio")
	cyl(bucket_frame, "Montante1", 0.14, 7.8, Vector3(-20.3, 3.9, -12.5), UNION, M.rust)
	cyl(bucket_frame, "Montante2", 0.14, 7.8, Vector3(-16.7, 3.9, -12.5), UNION, M.rust)
	var pivot := cyl(bucket_frame, "Perno", 0.09, 3.8, Vector3(-18.5, 7.6, -12.5), UNION, M.rust)
	pivot.rotation = Vector3(0, 0, PI * 0.5)
	var bucket := CSGCombiner3D.new()
	bucket.name = "SecchioGigante"
	bucket.position = Vector3(-18.5, 7.2, -12.5)
	bucket.rotation = Vector3(0.12, 0, 0.06)
	own(bucket, gb)
	var outer := CSGCylinder3D.new()
	outer.name = "Esterno"
	outer.radius = 1.4
	outer.height = 1.9
	outer.sides = 32
	outer.cone = false
	outer.material = M.orange
	own(outer, bucket)
	var inner := CSGCylinder3D.new()
	inner.name = "Interno"
	inner.radius = 1.28
	inner.height = 1.9
	inner.sides = 32
	inner.position = Vector3(0, 0.12, 0)
	inner.operation = SUB
	inner.material = M.orange
	own(inner, bucket)
	# Vasche basse: una piena (si aspira), una vuota.
	var full: WaterTank = S.tank.instantiate()
	full.name = "VascaBassaPiena"
	full.inner_size = Vector3(3.5, 0.45, 3.0)
	full.wall_thickness = 0.2
	full.capacity_liters = 30.0
	full.max_fill = 0.85
	full.fill = 0.8
	full.position = Vector3(-10.8, 0, -12.0)
	own(full, gb)
	var empty: WaterTank = S.tank.instantiate()
	empty.name = "VascaBassaVuota"
	empty.inner_size = Vector3(3.0, 0.45, 2.6)
	empty.wall_thickness = 0.2
	empty.capacity_liters = 25.0
	empty.max_fill = 0.85
	empty.position = Vector3(-19.5, 0, -3.6)
	own(empty, gb)
	polaroid(gb, "Polaroid04", Vector3(-15.0, 1.6, -9.0))


# --- Vasca d'arrivo degli scivoli (sud-ovest) --------------------------------------------

func _arrival_pool() -> void:
	var tank: WaterTank = S.tank.instantiate()
	tank.name = "VascaArrivo"
	tank.inner_size = Vector3(10.4, 1.4, 7.4)
	tank.wall_thickness = 0.3
	tank.capacity_liters = 200.0
	tank.max_fill = 0.85
	tank.fill = 0.75
	tank.position = Vector3(-15, -1.0, 7.0)
	own(tank, level)


# --- Torre degli scivoli (est) e tubi -------------------------------------------------------

func _slide_tower() -> void:
	var slot := slot_node(level, "TorreScivoli")
	var gb := group(slot, "Graybox")
	var csg := csg_root(gb, "Impalcatura")
	for x in [11.0, 16.5, 22.0]:
		for z in [-13.5, -8.5, -3.5]:
			cyl(csg, "Montante", 0.2, 14.0, Vector3(x, 7.0, z), UNION, M.rust)
	box(csg, "Piano1", Vector3(11.4, 0.25, 10.4), Vector3(16.5, 4.0, -8.5), UNION, M.metal)
	box(csg, "Piano2", Vector3(11.4, 0.25, 5.4), Vector3(16.5, 8.0, -11.0), UNION, M.metal)
	box(csg, "Piano3", Vector3(5.9, 0.25, 5.4), Vector3(19.25, 12.0, -11.0), UNION, M.metal)
	box(csg, "BucoScala", Vector3(2.0, 0.6, 3.0), Vector3(12.2, 4.0, -4.6), SUB, M.metal)
	# Scala fino al primo piano.
	for i in 13:
		box(csg, "Gradino", Vector3(1.8, 0.3, 0.42), Vector3(12.2, 0.15 + i * 0.3, -0.2 - i * 0.36), UNION, M.metal)
	# Partenze degli scivoli in cima.
	box(csg, "Partenza1", Vector3(1.8, 1.6, 1.8), Vector3(17.5, 13.0, -13.0), UNION, M.green)
	box(csg, "Partenza2", Vector3(1.8, 1.6, 1.8), Vector3(20.5, 13.0, -13.0), UNION, M.blue)
	# Tubi: dalla torre lungo il muro nord e poi giù lungo il muro ovest fino alla vasca d'arrivo.
	var tubes := group(gb, "Tubi")
	var path := [Vector3(17.5, 12.2, -14.0), Vector3(6.0, 11.0, -16.4), Vector3(-8.0, 9.6, -16.4),
		Vector3(-20.6, 8.2, -15.2), Vector3(-21.0, 5.6, -6.0), Vector3(-21.0, 3.4, 1.0), Vector3(-19.2, 1.3, 4.2)]
	var colors := [M.green, M.green, M.blue, M.blue, M.red, M.yellow]
	for i in path.size() - 1:
		tube(tubes, path[i], path[i + 1], 0.75, colors[i])
	var path2 := [Vector3(20.5, 12.2, -14.0), Vector3(23.0, 10.0, -9.0), Vector3(20.0, 8.6, -1.8), Vector3(14.5, 6.6, -1.2),
		Vector3(11.0, 4.6, -4.5), Vector3(13.0, 2.4, 1.0), Vector3(16.0, 0.9, 1.6)]
	var colors2 := [M.purple, M.purple, M.orange, M.orange, M.red, M.red]
	for i in path2.size() - 1:
		tube(tubes, path2[i], path2[i + 1], 0.7, colors2[i])


# --- Luci, nebbia bassa, lampi ----------------------------------------------------------------

func _lights() -> void:
	var lights := group(level, "Luci")
	var storm := DirectionalLight3D.new()
	storm.name = "LuceTempesta"
	storm.rotation = Vector3(deg_to_rad(-64.0), deg_to_rad(25.0), 0)
	storm.light_color = Color(0.55, 0.65, 0.95)
	storm.light_energy = 0.35
	storm.shadow_enabled = true
	storm.light_volumetric_fog_energy = 2.5
	own(storm, lights)
	var lightning: Node = load("res://scripts/environment/lightning.gd").new()
	lightning.name = "Lampi"
	lightning.set(&"light", storm)
	lightning.set(&"glass_material", M.glass)
	lightning.set(&"base_energy", 0.35)
	lightning.set(&"environment", M.env)
	own(lightning, lights)
	# Luci rosse d'emergenza.
	var red := [Vector3(-23.6, 6.8, -9.0), Vector3(-23.6, 6.8, 9.0), Vector3(23.6, 6.8, -9.0), Vector3(23.6, 6.8, 9.0),
		Vector3(-9.0, 6.8, -17.2), Vector3(9.0, 6.8, -17.2), Vector3(-6.0, 4.0, 17.2), Vector3(6.0, 4.0, 17.2)]
	for i in red.size():
		var p: Vector3 = red[i]
		var o := omni(lights, "Emergenza%d" % (i + 1), p + _inward(p) * 0.6, Color(1.0, 0.09, 0.05), 1.7, 8.5, i < 3)
		o.light_volumetric_fog_energy = 1.5
		mesh_box(lights, Vector3(0.36, 0.2, 0.36), p, M.emergency, "LampadaEmergenza%d" % (i + 1))
	# Neon sotto i ballatoi: alcuni sfarfallano.
	var neons := [[Vector3(-21.9, 4.75, -6.0), 0.0, 0.12], [Vector3(-21.9, 4.75, 9.0), 0.0, 0.0],
		[Vector3(21.9, 4.75, -1.0), 0.0, 0.3], [Vector3(-2.0, 4.75, -15.4), PI * 0.5, 0.0], [Vector3(0.0, 2.95, 21.0), PI * 0.5, 0.5]]
	for i in neons.size():
		var n: Array = neons[i]
		var tube_mesh := mesh_box(lights, Vector3(0.12, 0.07, 2.2), n[0], M.neon, "Neon%d" % (i + 1))
		tube_mesh.rotation = Vector3(0, n[1], 0)
		var o := omni(lights, "LuceNeon%d" % (i + 1), n[0] + Vector3(0, -0.25, 0) + _inward(n[0]) * 0.3, Color(0.75, 0.92, 1.0), 1.3, 9.0, false)
		var fl: Node = load("res://scripts/environment/flicker_light.gd").new()
		fl.name = "Sfarfallio%d" % (i + 1)
		fl.set(&"light", o)
		fl.set(&"mesh", tube_mesh)
		fl.set(&"base_energy", 1.3)
		fl.set(&"base_emission", 3.0)
		fl.set(&"flicker_rate", n[2])
		own(fl, lights)
	omni(lights, "LuceAreaBimbi", Vector3(-15.0, 6.8, -7.5), Color(0.95, 0.45, 0.85), 1.4, 12.0, true)
	omni(lights, "LuceSecchio", Vector3(-18.5, 9.2, -10.5), Color(1.0, 0.75, 0.4), 0.9, 6.0, false)
	omni(lights, "LuceTorre", Vector3(16.5, 9.5, -7.0), Color(0.4, 0.85, 1.0), 1.2, 13.0, false)
	omni(lights, "LuceVascaArrivo", Vector3(-15.0, 3.0, 7.0), Color(0.35, 0.7, 0.9), 0.9, 9.0, false)
	omni(lights, "LucePozza", Vector3(1.5, -0.6, 5.0), Color(0.45, 0.75, 0.75), 0.7, 9.0, false)
	# Nebbia bassa sul pavimento.
	var fog := FogVolume.new()
	fog.name = "NebbiaBassa"
	fog.size = Vector3(48, 2.2, 35)
	fog.position = Vector3(0, 0.4, 0)
	var fm := FogMaterial.new()
	fm.density = 0.07
	fm.albedo = Color(0.7, 0.75, 0.8)
	fm.height_falloff = 1.2
	fog.material = fm
	own(fog, lights)
	var fog_pool := FogVolume.new()
	fog_pool.name = "NebbiaPiscina"
	fog_pool.size = Vector3(13, 2.0, 23)
	fog_pool.position = Vector3(POOL_CENTER.x, -1.6, POOL_CENTER.z)
	fog_pool.material = fm
	own(fog_pool, lights)


func _inward(p: Vector3) -> Vector3:
	if absf(p.x) > 23.0:
		return Vector3(-signf(p.x), 0, 0)
	return Vector3(0, 0, -signf(p.z))


# --- Giocatore, checkpoint, trigger -----------------------------------------------------------

func _gameplay() -> void:
	var gp := group(level, "Gioco")
	var player: Node3D = S.player.instantiate()
	player.name = "Player"
	player.position = Vector3(0, 0, 22.4)
	own(player, level)
	checkpoint(gp, "CheckpointIngresso", 0, Vector3(0, 1.5, 21.5), Vector3(3.5, 3, 3), Vector3(0, -1.5, 0.9), 0.0)
	checkpoint(gp, "CheckpointStatua", 1, Vector3(0, 1.5, 15.0), Vector3(6, 3, 2), Vector3(0, -1.5, 0), 0.0)
	checkpoint(gp, "CheckpointSpiaggia", 2, Vector3(POOL_CENTER.x, 1.5, -12.5), Vector3(13, 3, 2), Vector3(0, -1.5, 0), PI)
	checkpoint(gp, "CheckpointFondo", 3, Vector3(POOL_CENTER.x, DEEP_Y + 1.5, 2.0), Vector3(13, 3, 2), Vector3(0, -1.5, 0), PI)
	var trig := Area3D.new()
	trig.name = "AccendiLampione"
	trig.collision_layer = 0
	trig.collision_mask = Layers.PLAYER
	trig.monitorable = false
	trig.position = Vector3(0, 1.5, 16.2)
	own(trig, gp)
	shape_box(trig, Vector3(4, 3, 1.2))
	level.set(&"lamp_trigger", trig)


# --- Aiuti ---------------------------------------------------------------------------------

func own(n: Node, parent: Node = null) -> Node:
	(parent if parent else level).add_child(n)
	n.owner = level
	return n


func group(parent: Node, node_name: String) -> Node3D:
	var g := Node3D.new()
	g.name = node_name
	own(g, parent)
	return g


func slot_node(parent: Node, node_name: String) -> Node3D:
	var s: Node3D = load("res://scripts/game/asset_slot.gd").new()
	s.name = node_name
	own(s, parent)
	return s


func csg_root(parent: Node, node_name: String) -> CSGCombiner3D:
	var c := CSGCombiner3D.new()
	c.name = node_name
	c.use_collision = true
	c.collision_layer = Layers.WORLD
	c.collision_mask = 0
	own(c, parent)
	return c


func box(parent: Node, node_name: String, size: Vector3, pos: Vector3, op: int, mat: Material) -> CSGBox3D:
	var b := CSGBox3D.new()
	_n += 1
	b.name = "%s%d" % [node_name, _n]
	b.size = size
	b.position = pos
	b.operation = op
	b.material = mat
	own(b, parent)
	return b


func cyl(parent: Node, node_name: String, radius: float, height: float, pos: Vector3, op: int, mat: Material) -> CSGCylinder3D:
	var c := CSGCylinder3D.new()
	_n += 1
	c.name = "%s%d" % [node_name, _n]
	c.radius = radius
	c.height = height
	c.sides = 24 if radius < 2.0 else 64
	c.position = pos
	c.operation = op
	c.material = mat
	own(c, parent)
	return c


func mesh_box(parent: Node, size: Vector3, pos: Vector3, mat: Material, node_name := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	_n += 1
	mi.name = (node_name if node_name != "" else "Pannello") + ("" if node_name != "" else str(_n))
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	own(mi, parent)
	return mi


func tube(parent: Node, a: Vector3, b: Vector3, radius: float, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	_n += 1
	mi.name = "Tubo%d" % _n
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = a.distance_to(b) + radius * 0.6
	m.radial_segments = 20
	mi.mesh = m
	mi.material_override = mat
	var d := (b - a).normalized()
	var x := d.cross(Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT).normalized()
	mi.basis = Basis(x, d, x.cross(d))
	mi.position = (a + b) * 0.5
	own(mi, parent)


func porthole(parent: Node, pos: Vector3, yaw: float) -> void:
	var ring := MeshInstance3D.new()
	_n += 1
	ring.name = "Oblo%d" % _n
	var tm := TorusMesh.new()
	tm.inner_radius = 0.38
	tm.outer_radius = 0.52
	ring.mesh = tm
	ring.material_override = M.rust
	ring.position = pos
	ring.rotation = Vector3(PI * 0.5, yaw, 0)
	own(ring, parent)
	var glass := MeshInstance3D.new()
	glass.name = "Vetro"
	var cm := CylinderMesh.new()
	cm.top_radius = 0.4
	cm.bottom_radius = 0.4
	cm.height = 0.04
	glass.mesh = cm
	glass.material_override = M.porthole
	own(glass, ring)


func shape_box(parent: Node, size: Vector3, pos := Vector3.ZERO) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	cs.name = "CollisionShape3D"
	var s := BoxShape3D.new()
	s.size = size
	cs.shape = s
	cs.position = pos
	own(cs, parent)
	return cs


func polaroid(parent: Node, node_name: String, pos: Vector3) -> Node3D:
	var p: Node3D = S.polaroid.instantiate()
	p.name = node_name
	p.position = pos
	p.set(&"entry_id", StringName(node_name.to_lower()))
	own(p, parent)
	return p


func checkpoint(parent: Node, node_name: String, order: int, pos: Vector3, size: Vector3, spawn_offset: Vector3, spawn_yaw: float) -> Area3D:
	var cp: Area3D = load("res://scripts/game/checkpoint.gd").new()
	cp.name = node_name
	cp.set(&"order", order)
	cp.position = pos
	own(cp, parent)
	shape_box(cp, size)
	var spawn := Marker3D.new()
	spawn.name = "Ripartenza"
	spawn.position = spawn_offset
	spawn.rotation = Vector3(0, spawn_yaw, 0)
	own(spawn, cp)
	cp.set(&"spawn_point", spawn)
	return cp


func omni(parent: Node, node_name: String, pos: Vector3, color: Color, energy: float, light_range: float, shadow := true) -> OmniLight3D:
	var o := OmniLight3D.new()
	o.name = node_name
	o.position = pos
	o.light_color = color
	o.light_energy = energy
	o.omni_range = light_range
	o.shadow_enabled = shadow
	own(o, parent)
	return o
