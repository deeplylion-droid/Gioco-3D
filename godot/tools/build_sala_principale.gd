extends SceneTree
## Costruisce res://scenes/sala_principale.tscn, la demo giocabile della sala principale:
## l'architettura vera dell'acquapark (i GLB di assets/ambiente/sala, tutti in 0,0,0), la medusa
## sul piedistallo, le luci della sala e l'atmosfera (addon grafica), le meccaniche della demo
## (zaino sulla rastrelliera dei bagnini, pozza, turbina dello scarico, portello, vasche, ruota
## a pale e secchio gigante) e le 10 Polaroid.
## Le coordinate vengono da assets/ambiente/sala/sala_dati.json (vedi INTEGRAZIONE.md).
## Uso: godot --headless --path godot --script res://tools/build_sala_principale.gd

const OUT := "res://scenes/sala_principale.tscn"
const SALA := "res://assets/ambiente/sala/"
const MAT_DIR := "res://assets/materials/sala/"

## Quota del piano del piedistallo e centro (dalla guida dell'ambiente).
const PEDESTAL := Vector3(0.0, 0.9, 6.9)
const SPAWN := Vector3(0.0, 0.0, 11.2)
## Pozza torbida sul fondo della piscina a onde: fondo a conca intorno allo scarico.
const DRAIN := Vector3(0.0, -2.24, 2.0)
const PUDDLE_LEVEL := -2.07
## La medusa scalata a circa 4,5 m di altezza (dalle punte dei tentacoli alla testa).
const MEDUSA_SCALE := 1.54

var level: Node3D
var M := {}
var S := {}
var _n := 0


func _initialize() -> void:
	S.player = load("res://scenes/player/player.tscn")
	S.turbine = load("res://scenes/props/turbine.tscn")
	S.button = load("res://scenes/props/water_button.tscn")
	S.tank = load("res://scenes/props/water_tank.tscn")
	S.ladder = load("res://scenes/props/ladder.tscn")
	S.polaroid = load("res://scenes/props/polaroid.tscn")
	S.pack_model = load("res://assets/models/zaino/zaino_opzione2/zaino_opzione2.gltf")
	_materials()
	level = Node3D.new()
	level.name = "SalaPrincipale"
	level.set_script(load("res://scripts/game/sala_principale.gd"))
	_environment()
	_hall()
	_statue()
	_pack_station()
	_pool()
	_pools()
	_kids_toys()
	_polaroids()
	_atmosphere()
	_gameplay()
	_kid_sighting()
	var packed := PackedScene.new()
	var err := packed.pack(level)
	if err == OK:
		err = ResourceSaver.save(packed, OUT)
	print("build_sala_principale: ", error_string(err))
	level.free()
	quit(0 if err == OK else 1)


# --- Materiali e ambiente ---------------------------------------------------------------

func _std(file: String, color: Color, rough: float, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return _save(m, file)


func _save(m: Material, file: String) -> Material:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MAT_DIR))
	var path := MAT_DIR + file + ".tres"
	ResourceSaver.save(m, path)
	m.take_over_path(path)
	return m


func _materials() -> void:
	M.metal = _std("metallo_verniciato", Color(0.16, 0.19, 0.2), 0.55, 0.6)
	M.red = _std("gonfiabile_rosso", Color(0.78, 0.07, 0.06), 0.22)
	(M.red as StandardMaterial3D).clearcoat_enabled = true
	ResourceSaver.save(M.red, M.red.resource_path)
	M.hatch = _std("portello", Color(0.42, 0.45, 0.43), 0.5, 0.8)
	var hole := StandardMaterial3D.new()
	hole.albedo_color = Color.BLACK
	hole.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	M.hole = _save(hole, "buio")
	var water: ShaderMaterial = load("res://assets/materials/water_placeholder.tres")
	# La pozza torbida è opaca e lucida: prende i riflessi (SSR) delle luci della sala.
	var murky := ShaderMaterial.new()
	murky.shader = load("res://shaders/water_murky.gdshader")
	murky.set_shader_parameter(&"shallow_color", Color(0.17, 0.22, 0.15))
	murky.set_shader_parameter(&"deep_color", Color(0.03, 0.045, 0.03))
	M.murky = _save(murky, "acqua_torbida")
	var clean := water.duplicate() as ShaderMaterial
	clean.set_shader_parameter(&"shallow_color", Color(0.18, 0.45, 0.5))
	clean.set_shader_parameter(&"deep_color", Color(0.02, 0.12, 0.16))
	M.clean = _save(clean, "acqua_vasche")
	# Vetro della cupola con i rivoli di pioggia che si accende coi lampi (addon grafica).
	var glass := ShaderMaterial.new()
	glass.shader = load("res://addons/grafica/vetro_cupola.gdshader")
	glass.set_shader_parameter(&"opacita", 0.16)
	M.dome_glass = _save(glass, "vetro_cupola")


func _environment() -> void:
	# L'ambiente notturno dell'addon grafica (cielo in tempesta visto dalla cupola, AgX,
	# nebbia volumetrica, SSR/SSAO/SSIL, glow), regolato per la sala vera.
	var e: Environment = load("res://addons/grafica/ambiente_horror.gd").crea(true)
	e.ambient_light_color = Color(0.3, 0.38, 0.5)
	e.ambient_light_energy = 0.22
	e.tonemap_exposure = 1.35
	e.volumetric_fog_density = 0.016
	e.volumetric_fog_albedo = Color(0.62, 0.68, 0.76)
	e.volumetric_fog_gi_inject = 0.4
	e.volumetric_fog_ambient_inject = 0.06
	e.sdfgi_use_occlusion = true
	e.sdfgi_read_sky_light = false
	e.sdfgi_cascades = 4
	e.sdfgi_min_cell_size = 0.2
	e.sdfgi_energy = 1.1
	e.ssr_max_steps = 64
	e.ssr_fade_in = 0.15
	e.ssr_fade_out = 2.0
	e.glow_intensity = 0.55
	e.glow_bloom = 0.025
	e.glow_hdr_threshold = 1.15
	ResourceSaver.save(e, "res://assets/env/sala_environment.tres")
	e.take_over_path("res://assets/env/sala_environment.tres")
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = e
	own(we)
	M.env = e
	# Lampi della tempesta (addon grafica): luce che si muove, cielo e vetro della cupola.
	var storm: Node3D = load("res://addons/grafica/tempesta.gd").new()
	storm.name = "Tempesta"
	storm.set(&"intervallo_min", 9.0)
	storm.set(&"intervallo_max", 20.0)
	storm.set(&"energia_lampo", 7.0)
	var mats: Array[ShaderMaterial] = [M.dome_glass]
	storm.set(&"materiali", mats)
	own(storm)


# --- Sala: i GLB dell'ambiente, le luci e la toppa delle collisioni ------------------------

func _hall() -> void:
	var sala := Node3D.new()
	sala.name = "Sala"
	# Lo script dell'ambiente regola le luci di sala_luci.glb e fa sfarfallare i neon.
	sala.set_script(load("res://assets/ambiente/sala_luci_ambiente.gd"))
	sala.set(&"crea_ambiente", false)
	own(sala)
	for part in [["Architettura", "sala_architettura"], ["Cupola", "sala_cupola"], ["Piscina", "sala_piscina"],
			["AreaBimbi", "sala_area_bimbi"], ["TorreScivoli", "sala_torre_scivoli"], ["Oggetti", "sala_oggetti"],
			["Interattivi", "sala_interattivi"], ["Luci", "sala_luci"]]:
		var inst: Node3D = (load(SALA + part[1] + ".glb") as PackedScene).instantiate()
		inst.name = part[0]
		own(inst, sala)
	level.set(&"dome_glass", M.dome_glass)
	# Superfici bagnabili (addon acqua): pavimenti con pozzanghere e cerchi delle gocce, pareti
	# e vasche con la banda bagnata e le caustiche vicino all'acqua.
	var roots: Array[NodePath] = [NodePath("../Architettura"), NodePath("../Piscina"), NodePath("../AreaBimbi"), NodePath("../TorreScivoli")]
	var floors: Node = (load("res://addons/acqua/scenes/convertitore_bagnato.tscn") as PackedScene).instantiate()
	floors.name = "PavimentiBagnati"
	floors.set(&"roots", roots)
	floors.set(&"name_filter", PackedStringArray(["pavimento"]))
	floors.set(&"puddle_amount", 0.45)
	floors.set(&"base_wetness", 0.35)
	own(floors, sala)
	var walls: Node = (load("res://addons/acqua/scenes/convertitore_bagnato.tscn") as PackedScene).instantiate()
	walls.name = "SuperficiBagnate"
	walls.set(&"roots", roots)
	walls.set(&"exclude_filter", PackedStringArray(["pavimento", "pozzanghere", "vetro", "glass", "griglia", "grata", "neon", "luce", "insegna", "lampad", "cartellone", "colature"]))
	walls.set(&"base_wetness", 0.2)
	own(walls, sala)


# --- La medusa sul piedistallo, la lampada e il pulsante della sigla ---------------------------

func _statue() -> void:
	var statue := group(level, "Statua")
	statue.position = Vector3(PEDESTAL.x, 0.0, PEDESTAL.z)
	# La medusa vera (GLB in posa statua): l'origine è alla vita, le punte dei tentacoli
	# (misurate sul modello) 1,95 m più in basso, appoggiate sul piano del piedistallo.
	# Guarda verso +Z (l'ingresso).
	var medusa: Node3D = load("res://scripts/environment/medusa_statue.gd").new()
	medusa.name = "Medusa"
	medusa.set(&"bell_material", load("res://assets/models/medusa/medusa_campana.tres"))
	medusa.set(&"model", load("res://assets/models/medusa/medusa.glb"))
	# Statua imponente (indicazione dell'utente): circa 4,5 m dalle punte dei tentacoli alla
	# testa. Il modello è alto 2,92 m: per ora si scala (arriverà il modello da eroe).
	medusa.set(&"feet_depth", 1.97 * MEDUSA_SCALE)
	medusa.scale = Vector3.ONE * MEDUSA_SCALE
	medusa.position = Vector3(0, PEDESTAL.y + 1.97 * MEDUSA_SCALE - 0.02, 0)
	own(medusa, statue)
	level.set(&"statue", medusa)
	# Luce rosa della campana (addon acqua): si vede anche riflessa nell'acqua.
	var glow: Node3D = (load("res://addons/acqua/scenes/luce_medusa.tscn") as PackedScene).instantiate()
	glow.name = "LuceCampana"
	glow.position = Vector3(0, -0.2, 0)
	glow.set(&"light_energy", 0.35)
	glow.set(&"omni_range", 3.5)
	own(glow, medusa)
	_monument_lights(statue)
	# Il pulsante per i bambini sul davanti del piedistallo (è già nel modello: qui c'è solo
	# il bersaglio per il getto).
	var jingle: WaterButton = S.button.instantiate()
	jingle.name = "PulsanteSigla"
	jingle.mode = WaterButton.Mode.MOMENTARY
	jingle.radius = 0.14
	jingle.show_model = false
	jingle.position = Vector3(0, 0.47, 1.14)
	own(jingle, statue)
	level.set(&"jingle_button", jingle)
	level.set(&"jingle_button_mesh", NodePath("Sala/Interattivi/sala_pulsante_piedistallo"))
	# La lampada sul palo è nel modello e la sua luce in sala_luci.glb ("luce_lampione"):
	# qui si orienta verso il viso e parte spenta, poi si accende quando ti avvicini.
	var flicker: Node = load("res://scripts/environment/flicker_light.gd").new()
	flicker.name = "Sfarfallio"
	flicker.set(&"base_energy", 5.0)
	flicker.set(&"base_emission", 6.0)
	flicker.set(&"flicker_rate", 0.05)
	flicker.set(&"min_level", 0.35)
	flicker.set(&"start_off", true)
	own(flicker, statue)
	level.set(&"statue_lamp", flicker)
	level.set(&"statue_lamp_light", NodePath("Sala/Luci/luce_lampione"))
	level.set(&"statue_lamp_aim", Vector3(PEDESTAL.x, 4.4, PEDESTAL.z))


## Luci da monumento: un faro dall'alto e tre fari a terra intorno al piedistallo, con i fasci
## che si vedono nella nebbia. Coordinate locali al gruppo della statua (centro del piedistallo).
func _monument_lights(statue: Node3D) -> void:
	var top := PEDESTAL.y + 1.97 * MEDUSA_SCALE * 1.48
	var chest := Vector3(0, PEDESTAL.y + 1.97 * MEDUSA_SCALE + 0.35, 0)
	var key := SpotLight3D.new()
	key.name = "FaroDallAlto"
	key.position = Vector3(0.0, 9.8, 2.8)
	own(key, statue)
	key.look_at_from_position(key.position, chest, Vector3.UP)
	key.light_color = Color(1.0, 0.93, 0.84)
	key.light_energy = 4.5
	key.spot_range = 16.0
	key.spot_angle = 15.0
	key.spot_angle_attenuation = 1.6
	key.shadow_enabled = true
	key.light_size = 0.05
	key.light_volumetric_fog_energy = 1.4
	key.set_meta(&"grafica_priorita_ombra", 0)
	var housing := StandardMaterial3D.new()
	housing.albedo_color = Color(0.08, 0.08, 0.09)
	housing.roughness = 0.5
	housing.metallic = 0.7
	var lens := StandardMaterial3D.new()
	lens.albedo_color = Color(0.9, 0.95, 1.0)
	lens.emission_enabled = true
	lens.emission = Color(0.9, 0.95, 1.0)
	lens.emission_energy_multiplier = 6.0
	# [posizione a terra, colore, energia]
	for u in [[Vector3(-1.45, 0.0, 1.35), Color(0.72, 0.88, 1.0), 1.5], [Vector3(1.45, 0.0, 1.35), Color(0.72, 0.88, 1.0), 1.5],
			[Vector3(0.0, 0.0, -1.7), Color(1.0, 0.45, 0.78), 1.0]]:
		var base := MeshInstance3D.new()
		base.name = "FaroATerra"
		var cm := CylinderMesh.new()
		cm.top_radius = 0.13
		cm.bottom_radius = 0.16
		cm.height = 0.16
		base.mesh = cm
		base.material_override = housing
		base.position = u[0] + Vector3(0, 0.08, 0)
		own(base, statue)
		var glass := MeshInstance3D.new()
		glass.name = "Vetro"
		var gm := CylinderMesh.new()
		gm.top_radius = 0.11
		gm.bottom_radius = 0.11
		gm.height = 0.01
		glass.mesh = gm
		var lm := lens.duplicate() as StandardMaterial3D
		lm.emission = u[1]
		glass.material_override = lm
		glass.position = Vector3(0, 0.085, 0)
		own(glass, base)
		var up := SpotLight3D.new()
		up.name = "FaroDalBasso"
		up.position = u[0] + Vector3(0, 0.2, 0)
		own(up, statue)
		up.look_at_from_position(up.position, Vector3(0, top * 0.62, 0), Vector3.FORWARD)
		up.light_color = u[1]
		up.light_energy = u[2]
		up.spot_range = 9.0
		up.spot_angle = 24.0
		up.spot_angle_attenuation = 1.2
		up.shadow_enabled = true
		up.light_volumetric_fog_energy = 0.7
		up.set_meta(&"grafica_priorita_ombra", 1)


# --- La postazione dei bagnini all'ingresso: rastrelliera con lo zaino-pompa ---------------------

func _pack_station() -> void:
	# Gli spogliatoi e lo stanzino dei bagnini non sono ancora modellati: per la demo lo zaino
	# sta su una rastrelliera dei bagnini contro il muro dell'ingresso, sotto la luce rossa.
	var st := group(level, "PostazioneBagnini")
	st.position = Vector3(4.3, 0.0, 11.55)
	st.rotation = Vector3(0, PI, 0)
	var rack := csg_root(st, "Rastrelliera")
	for x in [-0.9, 0.9]:
		box(rack, "Montante", Vector3(0.05, 1.9, 0.05), Vector3(x, 0.95, 0.2), UNION, M.metal)
	for y in [0.82, 1.45, 1.85]:
		box(rack, "Traversa", Vector3(1.85, 0.04, 0.04), Vector3(0, y, 0.2), UNION, M.metal)
	box(rack, "Ripiano", Vector3(1.85, 0.04, 0.5), Vector3(0, 0.8, 0.0), UNION, M.metal)
	var holder := group(st, "Zaino")
	holder.position = Vector3(-0.25, 0.82, 0.0)
	var model: Node3D = S.pack_model.instantiate()
	model.name = "Modello"
	own(model, holder)
	var pick: Area3D = load("res://scripts/interaction/pack_pickup.gd").new()
	pick.name = "Prendi"
	pick.set(&"remove_node", holder)
	own(pick, holder)
	shape_box(pick, Vector3(0.8, 0.8, 0.6), Vector3(0, 0.35, 0))
	var spot := SpotLight3D.new()
	spot.name = "LuceZaino"
	spot.position = Vector3(0.0, 2.7, -1.1)
	own(spot, st)
	spot.look_at_from_position(spot.position, Vector3(-0.25, 0.9, 0.0), Vector3.UP)
	spot.light_color = Color(1.0, 0.9, 0.75)
	spot.light_energy = 2.5
	spot.spot_range = 4.5
	spot.spot_angle = 26.0
	spot.shadow_enabled = true
	spot.set_meta(&"grafica_priorita_ombra", 1)


# --- Piscina a onde vuota: la pozza, la turbina dello scarico e il portello ----------------------

func _pool() -> void:
	var pool := group(level, "Piscina")
	# La pozza torbida: il fondo è a conca intorno allo scarico, quindi il piano dell'acqua
	# si vede come un cerchio; svuotandola scende sotto il fondo e sparisce.
	var puddle: WaterTank = S.tank.instantiate()
	puddle.name = "Pozza"
	puddle.build_walls = false
	puddle.inner_size = Vector3(7.6, 0.3, 7.6)
	puddle.capacity_liters = 150.0
	puddle.max_fill = (PUDDLE_LEVEL - (DRAIN.y - 0.02)) / 0.3
	puddle.fill = puddle.max_fill
	puddle.drain_time = 24.0
	puddle.water_material = M.murky
	puddle.position = Vector3(DRAIN.x, DRAIN.y - 0.02, DRAIN.z)
	own(puddle, pool)
	# L'acqua vera (addon acqua): superficie torbida con riflessi, gorgo sullo scarico.
	_water_link(pool, "AcquaPozza", puddle, "res://addons/acqua/presets/stile_2_torbida.tres", true)
	var vortex: MeshInstance3D = load("res://scripts/environment/drain_vortex.gd").new()
	vortex.name = "Gorgo"
	vortex.set(&"tank", puddle)
	vortex.position = Vector3(DRAIN.x, DRAIN.y + 0.3, DRAIN.z + 1.25)
	own(vortex, pool)
	# Turbina dello scarico in alto sulla parete sud (nel modello: qui si fa girare la sua
	# girante), bloccata da un gonfiabile.
	var turbine: Turbine = S.turbine.instantiate()
	turbine.name = "TurbinaScarico"
	turbine.radius = 0.47
	turbine.show_model = false
	turbine.position = Vector3(4.6, -0.62, 4.84)
	turbine.rotation = Vector3(0, PI, 0)
	turbine.external_rotor = NodePath("../../Sala/Interattivi/sala_turbina_scarico")
	own(turbine, pool)
	var drains: Array[PowerSource] = [turbine]
	puddle.drain_sources = drains
	_inflatable(pool, turbine)
	# Portello della camera delle onde sul fondo, sotto la pozza (cerniera sul lato nord), e il
	# suo pulsante sulla parete sud. Sotto il portello: il buio del tunnel.
	var hole := MeshInstance3D.new()
	hole.name = "Buio"
	var hm := BoxMesh.new()
	hm.size = Vector3(1.2, 0.004, 1.2)
	hole.mesh = hm
	hole.material_override = M.hole
	hole.position = Vector3(0.0, -2.256, 2.0)
	own(hole, pool)
	var hatch_button: WaterButton = S.button.instantiate()
	hatch_button.name = "PulsantePortello"
	hatch_button.mode = WaterButton.Mode.LATCH
	hatch_button.radius = 0.14
	hatch_button.show_model = false
	hatch_button.position = Vector3(1.9, -1.15, 4.95)
	hatch_button.rotation = Vector3(0, PI, 0)
	own(hatch_button, pool)
	var hatch: Node3D = load("res://scripts/mechanisms/hinged_hatch.gd").new()
	hatch.name = "Portello"
	hatch.set(&"target_path", NodePath("../../Sala/Interattivi/sala_portello_scarico"))
	hatch.set(&"axis", Vector3.RIGHT)
	hatch.set(&"open_angle", -105.0)
	var hatch_sources: Array[PowerSource] = [hatch_button]
	hatch.set(&"sources", hatch_sources)
	own(hatch, pool)
	level.set(&"hatch", hatch)
	level.set(&"hatch_button_mesh", NodePath("Sala/Interattivi/sala_pulsante_portello"))
	# Le scalette sono nel modello: qui solo le aree per arrampicarsi.
	for l in [["ScalettaEst", Vector3(6.95, -1.95, 3.2), -PI * 0.5], ["ScalettaOvest", Vector3(-6.95, -1.95, 2.2), PI * 0.5]]:
		var ladder: Node3D = S.ladder.instantiate()
		ladder.name = l[0]
		ladder.set(&"height", 1.95)
		ladder.set(&"show_model", false)
		ladder.position = l[1]
		ladder.rotation = Vector3(0, l[2], 0)
		own(ladder, pool)


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
	tm.rings = 48
	tm.ring_segments = 24
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


# --- Le altre vasche: si può aspirare anche da lì -----------------------------------------------

func _pools() -> void:
	var pools := group(level, "Vasche")
	# [nome, centro xz, fondo, livello, bordo, litri, materiale]
	for v in [["VascaArrivo", Vector2(-12.5, 2.0), Vector2(7.0, 10.0), -1.1, -0.22, -0.05, 400.0],
			["VascaBimbi1", Vector2(-12.6, -9.6), Vector2(4.4, 3.2), 0.02, 0.30, 0.45, 120.0],
			["VascaBimbi2", Vector2(-15.3, -12.4), Vector2(2.8, 2.8), 0.02, 0.22, 0.45, 60.0]]:
		var tank: WaterTank = S.tank.instantiate()
		tank.name = v[0]
		tank.build_walls = false
		var h: float = v[5] - v[3]
		tank.inner_size = Vector3(v[2].x, h, v[2].y)
		tank.capacity_liters = v[6]
		tank.max_fill = 1.0
		tank.fill = (v[4] - v[3]) / h
		tank.water_material = M.clean
		tank.position = Vector3(v[1].x, v[3], v[1].y)
		own(tank, pools)
		_water_link(pools, "Acqua" + String(v[0]), tank, "res://addons/acqua/presets/stile_3_scura.tres", false)


## Superficie d'acqua dell'addon acqua che segue una vasca del gioco (livello, scarico).
func _water_link(parent: Node, node_name: String, tank: Node3D, style_path: String, planar: bool) -> void:
	var link: Node3D = (load("res://addons/acqua/scenes/acqua_per_vasca.tscn") as PackedScene).instantiate()
	link.name = node_name
	link.set(&"tank", tank)
	link.set(&"style", load(style_path))
	# Il riflesso planare rende di nuovo la scena: solo sulla pozza, che si guarda di più.
	link.set(&"planar_reflection_on_high", planar)
	# Scatola della sala (coordinate del mondo) per i riflessi di riserva.
	link.set(&"env_box_min", Vector3(-20, -2.5, -24))
	link.set(&"env_box_max", Vector3(20, 11.5, 12))
	own(link, parent)


# --- Area bimbi: la ruota a pale gira col getto e riempie il secchio gigante, che si ribalta -------

func _kids_toys() -> void:
	var toy: Node3D = load("res://scripts/mechanisms/bucket_wheel.gd").new()
	toy.name = "RuotaESecchio"
	toy.set(&"wheel_path", NodePath("../Sala/AreaBimbi/sala_ruota_pale"))
	toy.set(&"bucket_path", NodePath("../Sala/AreaBimbi/sala_secchio_gigante"))
	toy.set(&"gate_wheel_path", NodePath("../Sala/Interattivi/sala_ruota_cancello"))
	toy.set(&"gate_path", NodePath("../Sala/Interattivi/sala_cancello_spiaggia"))
	toy.set(&"panel_path", NodePath("../Sala/Interattivi/sala_quadro_elettrico"))
	own(toy)


# --- Le 10 Polaroid -----------------------------------------------------------------------------

func _polaroids() -> void:
	var g := group(level, "Polaroid")
	# Le zone del documento del livello che non sono ancora modellate (corridoio, spogliatoi,
	# stanzino, camera delle onde, sala pompe, ponte inferiore) hanno un posto provvisorio in sala.
	var spots := [
		[1, Vector3(-1.6, 0.0, 10.4), 0.4],     # vicino a dove si entra
		[2, Vector3(-6.0, 0.6, 8.0), 1.2],      # su un lettino
		[3, Vector3(4.6, 0.85, 11.35), 2.9],    # sulla rastrelliera dei bagnini, accanto allo zaino
		[4, Vector3(-11.3, 6.4, -17.4), 0.2],   # in cima alla struttura di gioco, accanto al secchio
		[5, Vector3(1.2, -2.0, 2.9), 2.0],      # sul fondo della piscina, sotto la pozza
		[6, Vector3(-4.6, -1.9, 4.2), 0.9],     # vicino alle bocchette della camera delle onde
		[7, Vector3(8.2, 1.2, -2.4), 1.6],      # sulla sedia del bagnino
		[8, Vector3(-8.5, 0.0, 6.6), 0.7],      # sul bordo della vasca d'arrivo
		[9, Vector3(-9.9, 0.0, -9.4), 2.4],     # accanto alle vasche basse
		[10, Vector3(13.5, 9.0, -17.5), 0.6],   # in cima alla torre degli scivoli
	]
	for s in spots:
		var p: Node3D = S.polaroid.instantiate()
		p.name = "Polaroid%02d" % s[0]
		p.position = s[1]
		p.rotation = Vector3(0, s[2], 0)
		p.set(&"photo", s[0])
		p.set(&"entry_id", StringName("p%02d" % s[0]))
		own(p, g)


# --- Atmosfera: riflessi della sala, nebbia bassa, polvere nella luce, gocce dal soffitto --------

func _atmosphere() -> void:
	var fx := group(level, "Atmosfera")
	# Una sonda dei riflessi per tutta la sala (interno, proiezione a scatola): i pavimenti
	# bagnati e l'acqua riflettono la sala anche fuori dallo schermo (dove SSR non arriva).
	var probe := ReflectionProbe.new()
	probe.name = "RiflessiSala"
	probe.position = Vector3(0.0, 4.0, -6.0)
	probe.size = Vector3(40.0, 15.0, 36.0)
	probe.origin_offset = Vector3(0.0, -2.4, 6.0)
	probe.box_projection = true
	probe.interior = true
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
	probe.mesh_lod_threshold = 4.0
	own(probe, fx)
	# Nebbia bassa che striscia sul pavimento e riempie la piscina vuota.
	var fm := FogMaterial.new()
	fm.density = 0.06
	fm.albedo = Color(0.7, 0.75, 0.8)
	fm.height_falloff = 1.6
	for f in [["NebbiaBassa", Vector3(40, 2.0, 36), Vector3(0, 0.3, -6)], ["NebbiaPiscina", Vector3(14, 2.4, 18), Vector3(0, -1.3, -4)]]:
		var fog := FogVolume.new()
		fog.name = f[0]
		fog.size = f[1]
		fog.position = f[2]
		fog.material = fm
		own(fog, fx)
	# Polvere che si vede nella luce della lampada sopra la statua e nella torcia.
	var dust: Node3D = load("res://addons/grafica/pulviscolo.gd").new()
	dust.name = "PolvereStatua"
	dust.set(&"volume", Vector3(6, 4, 6))
	dust.position = Vector3(PEDESTAL.x, 2.4, PEDESTAL.z + 0.6)
	own(dust, fx)
	# Gocce che cadono nella pozza e fanno cerchi (addon acqua).
	var drip: Node3D = (load("res://addons/acqua/scenes/gocciolatoio.tscn") as PackedScene).instantiate()
	drip.name = "GocceNellaPozza"
	drip.position = Vector3(DRAIN.x + 0.9, 4.5, DRAIN.z + 0.6)
	own(drip, fx)
	# Gocce dal soffitto (con lo schizzo) vicino all'ingresso e sul bordo della piscina.
	for g in [Vector3(-3.4, 4.0, 9.8), Vector3(6.2, 4.0, 5.6), Vector3(-7.6, 4.0, -3.0)]:
		var drops: Node3D = load("res://addons/grafica/gocce.gd").new()
		drops.name = "Gocce"
		drops.position = g
		own(drops, fx)


# --- Giocatore, checkpoint, trigger -----------------------------------------------------------

func _gameplay() -> void:
	var gp := group(level, "Gioco")
	var player: Node3D = S.player.instantiate()
	player.name = "Player"
	player.position = SPAWN
	own(player, level)
	checkpoint(gp, "CheckpointIngresso", 0, SPAWN + Vector3(0, 1.5, 0), Vector3(4, 3, 1.4), Vector3(0, -1.5, 0), 0.0)
	checkpoint(gp, "CheckpointStatua", 1, Vector3(0, 1.5, 4.6), Vector3(8, 3, 1.5), Vector3(0, -1.5, 0), 0.0)
	checkpoint(gp, "CheckpointSpiaggia", 2, Vector3(0, 1.5, -14.2), Vector3(14, 3, 1.5), Vector3(0, -1.5, 0), PI)
	checkpoint(gp, "CheckpointFondo", 3, Vector3(0, -0.6, -1.0), Vector3(12, 3, 1.5), Vector3(0, -1.5, 0), PI)
	var trig := Area3D.new()
	trig.name = "AccendiLampione"
	trig.collision_layer = 0
	trig.collision_mask = Layers.PLAYER
	trig.monitorable = false
	trig.position = Vector3(0, 1.5, 9.0)
	own(trig, gp)
	shape_box(trig, Vector3(7, 3, 1.0))
	level.set(&"lamp_trigger", trig)


# --- B5: i bambini sulla balconata, visti in un lampo mentre sali sulla torre -------------------

func _kid_sighting() -> void:
	var trig := Area3D.new()
	trig.name = "SalitaTorre"
	trig.collision_layer = 0
	trig.collision_mask = Layers.PLAYER
	trig.monitorable = false
	trig.position = Vector3(13.5, 5.0, -16.5)
	own(trig, level.get_node("Gioco"))
	shape_box(trig, Vector3(7.0, 4.0, 9.0))
	var ks: Node3D = load("res://scripts/environment/kid_sighting.gd").new()
	ks.name = "BambiniBalconata"
	var models: Array[PackedScene] = [load("res://assets/models/bambini/cubo_calmo.glb"), load("res://assets/models/bambini/agnello_calmo.glb")]
	ks.set(&"models", models)
	# Sulla balconata ovest, dall'altra parte della sala rispetto alla torre.
	ks.set(&"spots", PackedVector3Array([Vector3(-18.4, 4.3, -11.2), Vector3(-18.6, 4.3, -9.7),
		Vector3(-18.3, 4.3, -8.1), Vector3(-18.5, 4.3, -6.6), Vector3(-18.4, 4.3, -5.0)]))
	ks.set(&"trigger", trig)
	ks.set(&"storm", level.get_node("Tempesta"))
	own(ks)


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


func csg_root(parent: Node, node_name: String) -> CSGCombiner3D:
	var c := CSGCombiner3D.new()
	c.name = node_name
	c.use_collision = true
	c.collision_layer = Layers.WORLD
	c.collision_mask = 0
	own(c, parent)
	return c


const UNION := CSGShape3D.OPERATION_UNION


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


func shape_box(parent: Node, size: Vector3, pos := Vector3.ZERO) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	cs.name = "CollisionShape3D"
	var s := BoxShape3D.new()
	s.size = size
	cs.shape = s
	cs.position = pos
	own(cs, parent)
	return cs


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
