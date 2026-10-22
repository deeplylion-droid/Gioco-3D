extends SceneTree
## Costruisce res://scenes/sala_principale.tscn, la demo giocabile della sala principale:
## l'architettura vera dell'acquapark (i GLB di assets/ambiente/sala, tutti in 0,0,0), la medusa
## sul piedistallo, le luci della sala e l'atmosfera (addon grafica), le meccaniche della demo
## (zaino sulla rastrelliera dei bagnini, la piscina a onde da svuotare con lo zaino, il pulsante
## della botola, vasche) e le Polaroid (9 nella demo: P10 torna con la sala della torre).
## Le coordinate vengono da assets/ambiente/sala/sala_dati.json (vedi INTEGRAZIONE.md).
## Uso: godot --headless --path godot --script res://tools/build_sala_principale.gd

const OUT := "res://scenes/sala_principale.tscn"
const SALA := "res://assets/ambiente/sala/"
## Il kit di dettagli della sala (ambienti-2): posizionamento.json e i glTF in gltf/.
const DETTAGLI := "res://assets/ambiente/dettagli/"
const MAT_DIR := "res://assets/materials/sala/"

const SPAWN := Vector3(0.0, 0.0, 19.2)
## Lo scarico sul fondo della piscina a onde: fondo a conca intorno allo scarico.
const DRAIN := Vector3(0.0, -2.24, 2.0)
## L'acqua della piscina a onde (tappa 5, deciso dall'utente il 15 ottobre): copre la parte profonda
## fino a questa quota (0,5 m sopra il fondo piatto, 0,76 sulla conca dello scarico).
const POOL_LEVEL := -1.5
## La sua pianta: tutta la larghezza della vasca (x da -7 a 7), dalla parete sud (z 5) a dove la
## spiaggia esce dall'acqua (z -4 a quota -1,5), con un po' di margine. La superficie è un piano:
## dove la spiaggia è più alta del pelo la copre la spiaggia, quindi si ritira da sola scendendo.
const POOL_RECT := Rect2(-7.0, -4.3, 14.0, 9.3)
## La vasca sollevata al centro della sala (sala_vasca_centrale.glb, INTEGRAZIONE.md dell'ambiente):
## centro, interno del muro (x, z), pelo dell'acqua e cima del bordo.
const VASCA := Vector3(0.0, 0.0, 10.0)
const VASCA_INTERNO := Vector2(5.4, 3.9)
const VASCA_PELO := 0.88
const VASCA_BORDO := 1.0
## La medusa affacciata (LEGGIMI della medusa): origine al livello del pavimento, guarda verso +Z.
const MEDUSA_DIR := "res://assets/models/medusa/"
const MEDUSA_AFFACCIATA := Vector3(0.0, 0.0, 10.15)
## Dove sta il suo occhio (per la luce del lampione).
const OCCHIO_MEDUSA := Vector3(0.0, 1.63, 11.95)
## Il pulsante della sigla sul muro davanti della vasca (sala_dati.json), rivolto a +Z.
const JINGLE_BUTTON := Vector3(0.0, 0.62, 12.35)
## Senza gli interni lo zaino sta su una rastrelliera davanti all'ingresso, girata verso lo spawn.
const PACK_STATION := Vector3(-1.8, 0.0, 17.0)

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
	_hall()
	_vasca_centrale()
	var has_interiors := _interiors()
	# SALA_SENZA_ZAINO=1: senza la rastrelliera (variante per gli screenshot della sala).
	if not has_interiors and OS.get_environment("SALA_SENZA_ZAINO") != "1":
		_pack_station()
	_pool()
	_pools()
	var tecnici := _tecnici()
	_polaroids(has_interiors or OS.get_environment("SALA_SENZA_ZAINO") == "1", tecnici)
	_atmosphere()
	_gameplay(has_interiors)
	_tappa7(has_interiors)
	_tappa8()
	_kid_sighting()
	var packed := PackedScene.new()
	var err := packed.pack(level)
	if err == OK:
		# SALA_OUT: un'altra destinazione (per esempio una variante per gli screenshot).
		var out := OS.get_environment("SALA_OUT")
		err = ResourceSaver.save(packed, out if out != "" else OUT)
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
	# Metallo verniciato e arrugginito (texture CC0 di Poly Haven, in triplanare).
	var rust := StandardMaterial3D.new()
	var tex := "res://assets/textures/metallo_ruggine/green_metal_rust_"
	rust.albedo_texture = load(tex + "diff.jpg")
	rust.albedo_color = Color(0.85, 0.9, 0.9)
	rust.normal_enabled = true
	rust.normal_texture = load(tex + "nor_gl.jpg")
	rust.roughness_texture = load(tex + "rough.jpg")
	rust.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	rust.metallic = 0.45
	rust.uv1_triplanar = true
	rust.uv1_world_triplanar = true
	rust.uv1_scale = Vector3.ONE * 1.6
	rust.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	M.metal = _save(rust, "metallo_verniciato")
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


# --- Sala: i GLB dell'ambiente, le luci e la toppa delle collisioni ------------------------

func _hall() -> void:
	var sala := Node3D.new()
	sala.name = "Sala"
	own(sala)
	for part in [["Architettura", "sala_architettura"], ["Cupola", "sala_cupola"], ["Piscina", "sala_piscina"],
			["AreaBimbi", "sala_area_bimbi"], ["TorreScivoli", "sala_torre_scivoli"], ["Oggetti", "sala_oggetti"],
			["Interattivi", "sala_interattivi"], ["VascaCentrale", "sala_vasca_centrale"], ["Luci", "sala_luci"]]:
		var inst: Node3D = (load(SALA + part[1] + ".glb") as PackedScene).instantiate()
		inst.name = part[0]
		own(inst, sala)
	_details(sala)
	level.set(&"dome_glass", M.dome_glass)
	level.set(&"puddle_material", load("res://addons/acqua/materials/pozzanghera.tres"))
	# Superfici bagnabili (addon acqua): pavimenti con pozzanghere e cerchi delle gocce, pareti
	# e vasche con la banda bagnata e le caustiche vicino all'acqua.
	var roots: Array[NodePath] = [NodePath("../Architettura"), NodePath("../Piscina"), NodePath("../AreaBimbi"), NodePath("../TorreScivoli")]
	var floors: Node = (load("res://addons/acqua/scenes/convertitore_bagnato.tscn") as PackedScene).instantiate()
	floors.name = "PavimentiBagnati"
	floors.set(&"roots", roots)
	floors.set(&"name_filter", PackedStringArray(["pavimento"]))
	# Valori della revisione di qualità (README dell'addon acqua): pavimenti bagnati davvero.
	floors.set(&"base_wetness", 0.65)
	floors.set(&"wet_darkening", 0.5)
	floors.set(&"puddle_amount", 0.6)
	floors.set(&"puddle_scale", 0.18)
	own(floors, sala)
	var walls: Node = (load("res://addons/acqua/scenes/convertitore_bagnato.tscn") as PackedScene).instantiate()
	walls.name = "SuperficiBagnate"
	walls.set(&"roots", roots)
	walls.set(&"exclude_filter", PackedStringArray(["pavimento", "pozzanghere", "vetro", "glass", "griglia", "grata", "neon", "luce", "insegna", "lampad", "cartellone", "colature"]))
	walls.set(&"base_wetness", 0.2)
	own(walls, sala)
	# Il look della sala (addon grafica) è una scena a parte, LuciSala (scenes/sala/luci_sala.tscn):
	# luci di sala_luci.glb riconosciute per nome, ambiente notturno, GI cotto, sonde dei riflessi,
	# tempesta coi lampi, nebbia bassa, polvere, controluce e luce da ritratto della statua.
	var luci: Node3D = (load("res://scenes/sala/luci_sala.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	luci.name = "LuciSala"
	# I due fari della ringhiera sud puntano dritti sul viso della medusa affacciata (a 6 m): a 7
	# erano quasi tre quarti della luce sulla testa e con il lampione bruciavano testa e capelli.
	# A 2 la luce principale sul viso è il lampione, e la medusa resta la cosa più chiara.
	luci.set(&"energia_fari", 2.0)
	luci.set(&"vetro_cupola", M.dome_glass)
	# Il lampione illumina il viso della medusa affacciata: punta sul suo occhio vero, e a 3 m
	# basta metà dell'energia di serie (a 6, con i fari, testa e capelli si bruciano).
	luci.set(&"ritratto_mira", OCCHIO_MEDUSA)
	luci.set(&"energia_ritratto", 3.0)
	own(luci)


## Detriti, cartelli, cavi, tubi e macchie (1219 posti): li crea DettagliSala all'avvio, con i
## MultiMesh. I modelli stanno nella scena, così si caricano nel thread del caricamento.
func _details(sala: Node3D) -> void:
	# SALA_SENZA_DETTAGLI=1: variante senza il kit (screenshot sul renderer software).
	if not FileAccess.file_exists(DETTAGLI + "posizionamento.json") or OS.get_environment("SALA_SENZA_DETTAGLI") == "1":
		return
	var det: Node3D = load("res://scripts/environment/dettagli_sala.gd").new()
	det.name = "Dettagli"
	det.set(&"cartella", DETTAGLI.trim_suffix("/"))
	var models: Array[PackedScene] = []
	for f in DirAccess.get_files_at(DETTAGLI + "gltf"):
		if f.ends_with(".gltf"):
			models.append(load(DETTAGLI + "gltf/" + f) as PackedScene)
	det.set(&"modelli", models)
	own(det, sala)


# --- La medusa sul piedistallo, la lampada e il pulsante della sigla ---------------------------

func _vasca_centrale() -> void:
	var g := group(level, "Vasca")
	# L'acqua quasi al bordo (addon acqua): limpida, così sotto si vede brillare la campana. Non si
	# aspira e non si riempie: la medusa resta immersa fino al seno.
	var tank: WaterTank = S.tank.instantiate()
	tank.name = "VascaCentrale"
	tank.build_walls = false
	tank.inner_size = Vector3(VASCA_INTERNO.x, VASCA_BORDO, VASCA_INTERNO.y)
	tank.capacity_liters = 600.0
	tank.fill = VASCA_PELO / VASCA_BORDO
	tank.max_fill = tank.fill
	tank.suckable = false
	tank.water_material = M.clean
	tank.position = VASCA
	own(tank, g)
	_water_link(g, "AcquaVascaCentrale", tank, "res://addons/acqua/presets/stile_1_limpida.tres", false)
	# La medusa vera affacciata al bordo (animazione "affacciata" in ciclo, aspetto bagnato).
	var medusa := _medusa_bagnata("Medusa")
	medusa.position = MEDUSA_AFFACCIATA
	own(medusa, g)
	level.set(&"statue", medusa)
	# Una sonda dei riflessi per lei: il bagnato di pelle e capelli, il vetro dell'occhio, l'acqua.
	var probe := ReflectionProbe.new()
	probe.name = "SondaVasca"
	probe.size = Vector3(8.0, 5.0, 7.0)
	probe.position = Vector3(0.0, 1.8, 11.0)
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probe.interior = false
	probe.box_projection = true
	own(probe, g)
	# Il pulsante per i bambini sul muro davanti della vasca (è nel modello: qui c'è solo il
	# bersaglio per il getto).
	var jingle: WaterButton = S.button.instantiate()
	jingle.name = "PulsanteSigla"
	jingle.mode = WaterButton.Mode.MOMENTARY
	jingle.radius = 0.14
	jingle.show_model = false
	jingle.position = JINGLE_BUTTON + Vector3(0, 0, 0.03)
	own(jingle, g)
	level.set(&"jingle_button", jingle)
	level.set(&"jingle_button_mesh", NodePath("Sala/Interattivi/sala_pulsante_piedistallo"))
	# La lampada sul palo (luce_lampione in sala_luci.glb): la orienta LuciSala sul viso della
	# medusa; parte spenta e si accende quando ti avvicini.
	var flicker: Node = load("res://scripts/environment/flicker_light.gd").new()
	flicker.name = "Sfarfallio"
	flicker.set(&"base_energy", 3.5)
	flicker.set(&"base_emission", 6.0)
	flicker.set(&"flicker_rate", 0.05)
	flicker.set(&"min_level", 0.35)
	flicker.set(&"start_off", true)
	own(flicker, g)
	level.set(&"statue_lamp", flicker)
	level.set(&"statue_lamp_light", NodePath("Sala/Luci/luce_lampione"))


# --- Corridoio, spogliatoi e stanzino (scena degli interni, se c'è) ----------------------------

const INTERNI := "res://scenes/interni/interni.tscn"
## Traslazione che porta l'uscita degli spogliatoi (9,7; 0; -20,7) sul vano del muro sud (0; 0; 20,2).
const INTERNI_OFFSET := Vector3(-9.7, 0.0, 40.9)


func _interiors() -> bool:
	# SALA_SENZA_INTERNI=1: variante senza gli interni (screenshot sul renderer software).
	if not ResourceLoader.exists(INTERNI) or OS.get_environment("SALA_SENZA_INTERNI") == "1":
		return false
	var inst: Node3D = (load(INTERNI) as PackedScene).instantiate()
	inst.name = "Interni"
	inst.position = INTERNI_OFFSET
	# Il giocatore e l'ambiente sono quelli della sala (README degli interni).
	inst.set(&"giocatore_proprio", false)
	own(inst)
	return true


# --- La postazione dei bagnini all'ingresso: rastrelliera con lo zaino-pompa ---------------------

func _pack_station() -> void:
	# Senza gli interni (spogliatoi e stanzino dei bagnini) lo zaino sta su una rastrelliera dei
	# bagnini appena dentro la sala, davanti a chi entra.
	var st := group(level, "PostazioneBagnini")
	st.position = PACK_STATION
	# Il davanti della rastrelliera (+Z locale) guarda lo spawn: la si vede appena si entra.
	st.rotation = Vector3(0, atan2(SPAWN.x - PACK_STATION.x, SPAWN.z - PACK_STATION.z), 0)
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
	# Una luce calda e debole davanti alla rastrelliera, giusto per far notare lo zaino.
	var spot := SpotLight3D.new()
	spot.name = "LuceZaino"
	spot.position = Vector3(-0.1, 1.55, 1.05)
	own(spot, st)
	spot.look_at_from_position(spot.position, Vector3(-0.25, 1.0, 0.0), Vector3.UP)
	spot.light_color = Color(1.0, 0.8, 0.58)
	spot.light_energy = 0.45
	spot.spot_range = 1.8
	spot.spot_angle = 32.0
	spot.light_volumetric_fog_energy = 0.0
	spot.shadow_enabled = false


# --- Piscina a onde: l'acqua da togliere con lo zaino, il pulsante e la botola --------------------

func _pool() -> void:
	var pool := group(level, "Piscina")
	# L'acqua della piscina a onde: il fondo è la conca dello scarico; svuotandola il pelo scende
	# sotto la spiaggia e poi sotto il fondo piatto, e sparisce nella conca.
	var puddle: WaterTank = S.tank.instantiate()
	puddle.name = "Pozza"
	puddle.build_walls = false
	var fondo := DRAIN.y - 0.02
	puddle.inner_size = Vector3(POOL_RECT.size.x, POOL_LEVEL - fondo, POOL_RECT.size.y)
	# I litri li decide la taratura di SvuotaPiscina (di serie circa 30 secondi, 4 zainate).
	puddle.capacity_liters = 180.0
	puddle.max_fill = 1.0
	puddle.fill = 1.0
	puddle.water_material = M.murky
	puddle.position = Vector3(POOL_RECT.get_center().x, fondo, POOL_RECT.get_center().y)
	own(puddle, pool)
	# L'acqua vera (addon acqua): superficie torbida con riflessi.
	_water_link(pool, "AcquaPozza", puddle, "res://addons/acqua/presets/stile_2_torbida.tres", false)
	# Portello della camera delle onde sul fondo, sotto la pozza (cerniera sul lato nord), e il
	# suo pulsante sulla parete sud. Sotto il portello c'è il pozzo vero (scena degli ambienti
	# tecnici): il buco nel fondo lo apre il GLB della sala.
	var hatch_button: WaterButton = S.button.instantiate()
	hatch_button.name = "PulsantePortello"
	hatch_button.mode = WaterButton.Mode.LATCH
	hatch_button.radius = 0.26
	hatch_button.show_model = false
	# Pulsante A (16 ottobre): sulla testa del fungo rosso Ø 50 cm (sala_dati.json, "pulsante_botola").
	hatch_button.position = Vector3(2.25, -1.12, 4.6)
	hatch_button.rotation = Vector3(0, PI, 0)
	# Si attiva solo a piscina vuota (lo accende SvuotaPiscina).
	hatch_button.enabled = false
	own(hatch_button, pool)
	# Lo svuotamento con lo zaino: taratura dei litri, l'acqua sparata dentro la vasca che ci
	# ritorna, il pulsante che si attiva a piscina vuota con il suo lampeggiante, le micro
	# medusine luminose (le crea lui).
	var svuota: Node3D = load("res://scripts/game/piscina_onde.gd").new()
	svuota.name = "SvuotaPiscina"
	svuota.set(&"vasca", puddle)
	svuota.set(&"pulsante", hatch_button)
	# Il vetro del lampeggiante sopra il pulsante A (GLB della sala).
	svuota.set(&"vetro_lampeggiante", level.get_node_or_null("Sala/Interattivi/sala_lampeggiante_portello"))
	# Lo scarico, dove gira il gorgo quando l'ultima acqua scola da sola: il portellone.
	svuota.set(&"scarico", level.get_node_or_null("Sala/Interattivi/sala_portello_scarico"))
	own(svuota, pool)
	var hatch: Node3D = load("res://scripts/mechanisms/hinged_hatch.gd").new()
	hatch.name = "Portello"
	hatch.set(&"target_path", NodePath("../../Sala/Interattivi/sala_portello_scarico"))
	hatch.set(&"axis", Vector3.RIGHT)
	# Si apre fino a terra, verso nord: la scala del pozzo è sul lato della cerniera e salendo si
	# esce da quella parte, sopra il portello (in piedi lo si avrebbe davanti alla faccia).
	hatch.set(&"open_angle", -170.0)
	var hatch_sources: Array[PowerSource] = [hatch_button]
	hatch.set(&"sources", hatch_sources)
	own(hatch, pool)
	level.set(&"hatch", hatch)
	# La luce del portellone (riscontro della v0.3.1, punto 3): anello color ambra e bagliore
	# nell'acqua torbida, si vede già dalla spiaggia a piscina piena.
	var luce_portellone: Node3D = load("res://scripts/game/luce_portellone.gd").new()
	luce_portellone.name = "LucePortellone"
	luce_portellone.set(&"portellone", level.get_node_or_null("Sala/Interattivi/sala_portello_scarico"))
	luce_portellone.set(&"vasca", puddle)
	own(luce_portellone, pool)
	# Checkpoint di quando la piscina è vuota (un passo dell'enigma): lo raggiunge lo script della
	# sala; si riparte sul fondo, davanti al portello.
	var cp: Area3D = load("res://scripts/game/checkpoint.gd").new()
	cp.name = "CheckpointPozzaVuota"
	cp.set(&"order", 4)
	cp.position = Vector3(1.4, -2.2, 0.4)
	own(cp, pool)
	var spawn := Marker3D.new()
	spawn.name = "Ripartenza"
	spawn.rotation = Vector3(0.0, PI * 0.8, 0.0)
	own(spawn, cp)
	cp.set(&"spawn_point", spawn)
	level.set(&"checkpoint_pozza", cp)
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


# --- Le altre vasche: si può aspirare anche da lì -----------------------------------------------

func _pools() -> void:
	var pools := group(level, "Vasche")
	# [nome, centro xz, fondo, livello, bordo, litri, materiale]
	for v in [["VascaArrivo", Vector2(-12.5, 2.0), Vector2(7.0, 10.0), -1.1, -0.22, -0.05, 400.0],
			["VascaBimbi1", Vector2(-12.6, -9.6), Vector2(4.4, 3.2), 0.02, 0.30, 0.45, 120.0],
			["VascaBimbi2", Vector2(-9.6, -18.2), Vector2(2.8, 2.8), 0.02, 0.22, 0.45, 60.0]]:
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
	# Il riflesso planare rende di nuovo la scena (raddoppia draw call e triangoli): spento anche
	# sulla pozza, che prende i riflessi con l'SSR dello shader.
	link.set(&"planar_reflection_on_high", planar)
	# Scatola della sala (coordinate del mondo) per i riflessi di riserva.
	link.set(&"env_box_min", Vector3(-20, -2.5, -24))
	link.set(&"env_box_max", Vector3(20, 11.5, 20))
	own(link, parent)


# --- Tappe 5-6: pozzo, camera delle onde, sala pompe e raccordo (scenes/tecnici/LEGGIMI.md) ------

const TECNICI := "res://scenes/tecnici/tecnici.tscn"
## La scena degli ambienti tecnici girata di -90° su Y: il pozzo sotto il portello sul fondo della
## piscina a onde, il raccordo ai piedi della scala degli interni (LEGGIMI).
const TECNICI_XF := Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(0.0, -9.05, 1.36))
## L'immagine della telecamera della sala sul monitor della sala pompe (uno scatto vero).
## Dal marker della leva al mozzo vero della base (scena dei tecnici): (46,097; 3,789; -5,205) ->
## (46,114; 3,716; -4,954), misurato da ambienti-1.
const LEVA_MOZZO := Vector3(0.017, -0.07327, 0.25125)
const MONITOR_IMMAGINE := "res://assets/tecnici/monitor_sala.jpg"
## Lo schermo del monitor appoggiato sul vetro bombato del tubo (lo calcola questo costruttore).
const SCHERMO_SUL_VETRO := "res://assets/tecnici/schermo_crt_sul_vetro.res"


func _tecnici() -> Node3D:
	# SALA_SENZA_TECNICI=1: variante senza (screenshot della sala sul renderer software).
	if not ResourceLoader.exists(TECNICI) or OS.get_environment("SALA_SENZA_TECNICI") == "1":
		return null
	var tec: Node3D = (load(TECNICI) as PackedScene).instantiate()
	tec.name = "Tecnici"
	tec.transform = TECNICI_XF
	tec.set(&"giocatore_proprio", false)
	own(tec)
	level.set(&"tecnici", tec)
	var lg := group(tec, "Logica")
	_sala_pompe(tec, lg)
	_checkpoint_tecnici(tec, lg)
	return tec


## La trasformazione di [param n] nelle coordinate di [param radice] (anche fuori dall'albero).
func _relativa(n: Node3D, radice: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var x: Node = n
	while x and x != radice:
		if x is Node3D:
			t = (x as Node3D).transform * t
		x = x.get_parent()
	return t


func _marker(tec: Node3D, nome: String) -> Vector3:
	return (tec.get_node("Marker/" + nome) as Node3D).position


## L'AABB di una mesh del modello nelle coordinate della scena degli ambienti tecnici.
func _aabb_tecnici(tec: Node3D, mi: MeshInstance3D) -> AABB:
	var xf := Transform3D.IDENTITY
	var n: Node = mi
	while n and n != tec:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf * mi.get_aabb()


func _sala_pompe(tec: Node3D, lg: Node3D) -> void:
	# (Gli script della logica si caricano con load(): nominarne le classi qui le compilerebbe
	# prima degli autoload, che usano.)
	var sp := "Ambienti/SalaPompe/"
	var T := "res://scripts/tecnici/"
	var g := group(lg, "SalaPompe")
	var ris: Node = load(T + "risveglio_sala_pompe.gd").new()
	ris.name = "Risveglio"
	# Turbine e pompe nell'ordine dello schema a colori sul muro: blu, giallo, rosso
	# (TURBINA_3, TURBINA_1, TURBINA_2; ogni pompa sta dietro la sua turbina).
	for n in [3, 1, 2]:
		var t: Turbine = S.turbine.instantiate()
		t.name = "Turbina%d" % n
		t.radius = 0.75
		t.show_model = false
		t.position = _marker(tec, "marker_turbina_%d" % n)
		own(t, g)
		(ris.get(&"turbine") as Array).append(t)
		# La girante del modello ha l'origine sul bordo basso: la fa girare GiranteTurbina.
		var gir: Node = load(T + "girante_turbina.gd").new()
		gir.name = "Girante%d" % n
		gir.set(&"turbina", t)
		own(gir, g)
		gir.set(&"girante_path", gir.get_path_to(tec.get_node(sp + "TURBINA_%d" % n)))
		var pm: Node3D = load(T + "pompa.gd").new()
		pm.name = "Pompa%d" % n
		pm.position = _marker(tec, "marker_pompa_%d" % n)
		own(pm, g)
		var corpi := pm.get(&"corpi") as Array
		corpi.append(pm.get_path_to(tec.get_node(sp + "POMPA_%d" % n)))
		var hq := tec.get_node_or_null(sp + "POMPA_%d_modello" % n)
		if hq:
			corpi.append(pm.get_path_to(hq))
		pm.set(&"vapore_path", pm.get_path_to(tec.get_node(sp + "VAPORE_pompa_%d" % n)))
		(ris.get(&"pompe") as Array).append(pm)
	# La leva grande in alto dietro la grata.
	var leva: Node3D = load(T + "leva_grande.gd").new()
	leva.name = "Leva"
	# Sul mozzo vero della base, il centro dell'occhio del braccio (ambienti-1, 16 ottobre): il braccio
	# gira intorno a questo punto e resta attaccato al perno. Il marker sta un poco più in alto.
	leva.position = _marker(tec, "marker_leva") + LEVA_MOZZO
	own(leva, g)
	leva.set(&"leva_path", leva.get_path_to(tec.get_node(sp + "LEVA")))
	var reti := leva.get(&"reti") as Array
	reti.append(leva.get_path_to(tec.get_node(sp + "GRATA_leva")))
	reti.append(leva.get_path_to(tec.get_node(sp + "gabbia_leva")))
	ris.set(&"leva", leva)
	# Le paratie della camera delle onde.
	for d in [["PARATIA_1", 2.65], ["PARATIA_2", 2.2]]:
		var pa: Node = load(T + "paratia.gd").new()
		pa.name = String(d[0]).capitalize().replace(" ", "")
		pa.set(&"discesa", float(d[1]))
		own(pa, g)
		pa.set(&"pannello_path", pa.get_path_to(tec.get_node("Ambienti/CameraOnde/" + String(d[0]))))
		(ris.get(&"paratie") as Array).append(pa)
	# La porta del ponte inferiore: cardine sul bordo sud (l'origine del modello è al centro),
	# maniglione dal lato della sala.
	var porta_mi := tec.get_node(sp + "PORTA_ponte") as MeshInstance3D
	var bb := _aabb_tecnici(tec, porta_mi)
	var cardine := Marker3D.new()
	cardine.name = "CardinePorta"
	cardine.position = Vector3(bb.get_center().x, 0.0, bb.end.z)
	own(cardine, g)
	var man := _aabb_tecnici(tec, tec.get_node(sp + "PORTA_ponte/PORTA_ponte_maniglione") as MeshInstance3D)
	var porta: Area3D = load(T + "porta_maniglione.gd").new()
	porta.name = "Maniglione"
	porta.position = man.get_center()
	own(porta, g)
	shape_box(porta, Vector3(0.45, 0.45, man.size.z + 0.1))
	porta.set(&"porta_path", porta.get_path_to(porta_mi))
	porta.set(&"cardine_path", porta.get_path_to(cardine))
	ris.set(&"porta", porta)
	# Il monitor a tubo sulla scrivania.
	var mon: Node = load(T + "monitor_crt.gd").new()
	mon.name = "Monitor"
	own(mon, g)
	mon.set(&"schermo_path", mon.get_path_to(tec.get_node(sp + "SCHERMO_CRT")))
	mon.set(&"luce_path", mon.get_path_to(tec.get_node(sp + "LUCE_crt")))
	if ResourceLoader.exists(MONITOR_IMMAGINE):
		mon.set(&"immagine", load(MONITOR_IMMAGINE))
	# Lo schermo appoggiato sul vetro bombato del tubo (riscontro E5: il rettangolo piatto del modello
	# sembrava un foglio attaccato sul televisore). Si calcola qui, senza scheda video, e si salva:
	# nel gioco leggere le mesh mentre la scena entra bloccava il renderer Vulkan.
	var schermo := tec.get_node_or_null(sp + "SCHERMO_CRT") as MeshInstance3D
	var tv := tec.get_node_or_null(sp + "MONITOR_CRT") as MeshInstance3D
	if schermo and tv:
		var sul_vetro: ArrayMesh = load(T + "monitor_crt.gd").costruisci_schermo_sul_vetro(schermo.mesh, tv.mesh,
				_relativa(tv, tec).affine_inverse() * _relativa(schermo, tec))
		if sul_vetro:
			ResourceSaver.save(sul_vetro, SCHERMO_SUL_VETRO)
			sul_vetro.take_over_path(SCHERMO_SUL_VETRO)
			mon.set(&"schermo_sul_vetro", sul_vetro)
		else:
			push_warning("build_sala_principale: lo schermo del monitor non trova il vetro del televisore")
	ris.set(&"monitor", mon)
	# Chi tiene insieme tutto: ordine delle pompe, leva, risveglio, paratie, porta.
	own(ris, g)
	var vapori := ris.get(&"vapori") as Array
	vapori.append(ris.get_path_to(tec.get_node(sp + "VAPORE_collettore")))
	vapori.append(ris.get_path_to(tec.get_node(sp + "VAPORE_perdita_ovest")))
	# La plastica che si piega e il tonfo arrivano da lontano, dalla vasca della medusa.
	ris.set(&"punto_lontano", VASCA + Vector3(0.0, 0.6, 0.0))
	level.set(&"risveglio", ris)


## Checkpoint invisibili delle tappe 5-7 (ordine dopo CheckpointFondo, 3): in fondo al pozzo,
## all'ingresso della sala pompe, dopo il risveglio (da codice) e, sulla strada B della tappa 7
## (16 ottobre), appena fuori dalla porta col maniglione, in cima al raccordo, all'entrata del
## magazzino dei gonfiabili e appena usciti dalla serranda nella sala (marker_t7_* del LEGGIMI).
func _checkpoint_tecnici(tec: Node3D, lg: Node3D) -> void:
	var g := group(lg, "Checkpoint")
	var arrivo := _marker(tec, "marker_arrivo_scala")
	# Si riparte in fondo alla scala, guardando lungo la camera (+X della scena: yaw -90°).
	# (L'area comprende il piede della scala: ci si arriva scendendo.)
	checkpoint(g, "CheckpointPozzo", 5, arrivo + Vector3(-0.3, 1.5, 0.0), Vector3(2.6, 3.0, 3.0), Vector3(0.3, -1.5, 0.0), -PI * 0.5)
	checkpoint(g, "CheckpointSalaPompe", 6, Vector3(29.8, 1.5, 0.0), Vector3(1.2, 3.0, 2.8), Vector3(0.6, -1.5, 0.0), -PI * 0.5)
	# Dopo il risveglio: davanti alla porta del ponte inferiore (lo raggiunge il codice).
	var cp: Area3D = load("res://scripts/game/checkpoint.gd").new()
	cp.name = "CheckpointRisveglio"
	cp.set(&"order", 7)
	cp.position = _marker(tec, "marker_porta_ponte") + Vector3(-0.6, 0.0, 0.0)
	own(cp, g)
	var spawn := Marker3D.new()
	spawn.name = "Ripartenza"
	spawn.rotation = Vector3(0.0, -PI * 0.5, 0.0)
	own(spawn, cp)
	cp.set(&"spawn_point", spawn)
	(level.get(&"risveglio") as Node).set(&"checkpoint", cp)
	# Tappa 7: appena fuori dalla porta col maniglione, si guarda lungo il corridoio (+X della scena).
	checkpoint(g, "CheckpointT7Inizio", 8, _marker(tec, "marker_t7_inizio") + Vector3(0.0, 1.5, 0.0), Vector3(1.4, 3.0, 2.0), Vector3(0.0, -1.5, 0.0), -PI * 0.5)
	# In cima al raccordo, sul pianerottolo davanti alla grata della scala degli interni (chiusa): si
	# guarda verso il corridoio C2 (+Z della scena).
	var cima := _marker(tec, "marker_raccordo_interni")
	checkpoint(g, "CheckpointRaccordo", 9, cima + Vector3(0.0, 1.5, 0.0), Vector3(1.6, 3.0, 1.6), Vector3(0.0, -1.5, 0.0), PI)
	# All'entrata del magazzino dei gonfiabili e appena usciti dalla serranda nella sala: si guarda
	# verso la serranda e poi a nord (-X della scena).
	checkpoint(g, "CheckpointMagazzino", 10, _marker(tec, "marker_t7_magazzino") + Vector3(0.0, 1.5, 0.0), Vector3(1.6, 3.0, 3.0), Vector3(0.0, -1.5, 0.0), PI * 0.5)
	checkpoint(g, "CheckpointSerranda", 11, _marker(tec, "marker_t7_serranda") + Vector3(0.0, 1.5, 0.0), Vector3(1.4, 3.0, 2.4), Vector3(0.0, -1.5, 0.0), PI * 0.5)
	_serranda_magazzino(tec, lg)


## La serranda del magazzino dei gonfiabili nell'angolo sud-ovest della sala (riscontro sulla v0.3.1):
## chiusa finché non ci arrivi dal magazzino, poi si alza fino a dove è modellata (barra a 1,95 m).
## Coordinate della scena dei tecnici (glTF del raccordo): il vano va da z 14,1 a 15,9, il pavimento è
## a y 9,05 e le lamelle stanno su x 18,97..19,01; il magazzino è dalla parte delle x più grandi.
const SERRANDA_MAGAZZINO := Vector3(18.99, 9.05, 15.0)


func _serranda_magazzino(tec: Node3D, lg: Node3D) -> void:
	var s: PoweredDoor = load("res://scripts/tecnici/serranda_magazzino.gd").new()
	s.name = "SerrandaMagazzino"
	# +Z locale verso il magazzino (+X della scena dei tecnici), X lungo il vano.
	s.transform = Transform3D(Basis(Vector3.UP, PI * 0.5), SERRANDA_MAGAZZINO)
	s.size = Vector3(1.8, 2.5, 0.2)
	s.open_offset = Vector3(0.0, 1.95, 0.0)
	s.open_speed = 0.4
	own(s, lg)
	s.set(&"modello", s.get_path_to(tec.get_node("Ambienti/Raccordo/RACCORDO_dettagli")))


# --- Le Polaroid (9 nella demo) -------------------------------------------------------------------

## Polaroid che per ora non sono nella demo. P10 stava in cima alla torre degli scivoli, che non è
## più nella sala (16 ottobre): torna con la torre nella sala nuova, dove l'utente sceglierà il posto.
const POLAROID_FUORI_DEMO := [10]


func _polaroids(has_interiors := false, tecnici: Node3D = null) -> void:
	var g := group(level, "Polaroid")
	# P3 sta sulla rastrelliera dello zaino, sul ripiano accanto a lui.
	var rack_yaw := atan2(SPAWN.x - PACK_STATION.x, SPAWN.z - PACK_STATION.z)
	var p3 := PACK_STATION + Basis(Vector3.UP, rack_yaw) * Vector3(0.5, 0.83, 0.02)
	# Le zone del documento del livello che non sono ancora modellate (corridoio, spogliatoi,
	# stanzino, camera delle onde, sala pompe, ponte inferiore) hanno un posto provvisorio in sala.
	# Le quote sono quelle dopo l'appoggio (snap_to_surface), così le Polaroid stanno già sul loro sostegno anche
	# prima che lo snap parta (controllo di posizionamento del 22 ottobre).
	var spots := [
		[1, Vector3(-1.6, 0.0, 18.4), 0.4],     # vicino a dove si entra
		[2, Vector3(-6.0, 0.6, 8.0), 1.2],      # su un lettino
		[3, p3, rack_yaw + 0.35],                # sulla rastrelliera dei bagnini, accanto allo zaino
		[4, Vector3(-16.03, 1.2416, -15.35), 0.2],  # sulla struttura di gioco: in cima alla scala, dove ci si arriva a piedi
		[5, Vector3(1.19978, -2.164, 2.899858), 2.0],   # sul fondo della piscina, sotto la pozza: piatta, senza snap (fondo a conca)
		[6, Vector3(-4.6, -1.9, 4.2), 0.9],     # vicino alle bocchette della camera delle onde
		[7, Vector3(8.2, 1.2, -2.4), 1.6],      # sulla sedia del bagnino
		[8, Vector3(-8.9, 0.016, 6.6), 0.7],      # sul bordo della vasca d'arrivo (sulla copertina: non sotto il pannello caduto)
		[9, Vector3(-9.9, 0.004, -9.4), 2.4],     # accanto alle vasche basse
		[10, Vector3(13.5, 9.0, -17.5), 0.6],   # in cima alla torre degli scivoli (fuori dalla demo)
	]
	if tecnici:
		# Negli ambienti tecnici (coordinate della loro scena, LEGGIMI): P6 nella camera delle
		# onde, a terra contro il muro sud tra le bocchette; P7 sulla scrivania accanto al monitor, nello
		# spazio libero dietro lo schermo, tutta dentro il piano (prima era sul bordo, mezza fuori) e
		# fuori dai fogli della scrivania (ci stava sotto: prova del 19 ottobre).
		for t in [[6, Vector3(9.2, 0.004, 1.75), 0.4], [7, Vector3(42.0, 0.7839, 3.23), 2.92]]:
			var i := spots.find_custom(func(x): return int(x[0]) == int(t[0]))
			spots[i] = [t[0], TECNICI_XF * (t[1] as Vector3), float(t[2]) - PI * 0.5]
	for s in spots:
		# Con gli interni montati, P1-P3 stanno nel corridoio, negli spogliatoi e nello stanzino.
		if (has_interiors and int(s[0]) <= 3) or int(s[0]) in POLAROID_FUORI_DEMO:
			continue
		var p: Node3D = S.polaroid.instantiate()
		p.name = "Polaroid%02d" % s[0]
		p.position = s[1]
		p.rotation = Vector3(0, s[2], 0)
		p.set(&"photo", s[0])
		p.set(&"entry_id", StringName("p%02d" % s[0]))
		if int(s[0]) == 5:
			# sul fondo a conca lo snap la inclinava su un punto solo e un angolo entrava nel fondo: piatta, poggia
			# sull'angolo più alto (fondo visibile misurato da tests/sonda_p05.gd)
			p.set(&"snap_to_surface", false)
		own(p, g)


# --- Atmosfera: riflessi della sala, nebbia bassa, polvere nella luce, gocce dal soffitto --------

func _atmosphere() -> void:
	var fx := group(level, "Atmosfera")
	# Niente più pozzanghere a specchio sull'asse dell'ingresso: dove l'SSR non trova niente da
	# riflettere sembravano buchi neri nel pavimento. I riflessi li danno i pavimenti bagnati e le
	# pozzanghere della sala (addon acqua).
	# Gocce che cadono nella pozza e fanno cerchi (addon acqua). Il resto dell'atmosfera
	# (sonde, nebbia bassa, polvere, gocce dal soffitto) lo crea il look della sala.
	var drip: Node3D = (load("res://addons/acqua/scenes/gocciolatoio.tscn") as PackedScene).instantiate()
	drip.name = "GocceNellaPozza"
	drip.position = Vector3(DRAIN.x + 0.9, 4.5, DRAIN.z + 0.6)
	own(drip, fx)


# --- Giocatore, checkpoint, trigger -----------------------------------------------------------

func _gameplay(has_interiors := false) -> void:
	var gp := group(level, "Gioco")
	var player: Node3D = S.player.instantiate()
	player.name = "Player"
	player.position = SPAWN
	if has_interiors:
		# Ci si sveglia a terra nel corridoio (marker_risveglio degli interni), guardando a ovest.
		player.position = INTERNI_OFFSET + Vector3(20.40, 0.0, -1.25)
		player.rotation = Vector3(0.0, PI * 0.5, 0.0)
	own(player, level)
	checkpoint(gp, "CheckpointIngresso", 0, SPAWN + Vector3(0, 1.5, 0), Vector3(4, 3, 1.4), Vector3(0, -1.5, 0), 0.0)
	checkpoint(gp, "CheckpointStatua", 1, Vector3(0, 1.5, 14.4), Vector3(8, 3, 1.5), Vector3(0, -1.5, 0), 0.0)
	checkpoint(gp, "CheckpointSpiaggia", 2, Vector3(0, 1.5, -14.2), Vector3(14, 3, 1.5), Vector3(0, -1.5, 0), PI)
	checkpoint(gp, "CheckpointFondo", 3, Vector3(0, -0.6, -1.0), Vector3(12, 3, 1.5), Vector3(0, -1.5, 0), PI)
	var trig := Area3D.new()
	trig.name = "AccendiLampione"
	trig.collision_layer = 0
	trig.collision_mask = Layers.PLAYER
	trig.monitorable = false
	trig.position = Vector3(0, 1.5, 15.8)
	own(trig, gp)
	shape_box(trig, Vector3(8, 3, 1.0))
	level.set(&"lamp_trigger", trig)
	# Le luci di tutto il livello seguono GameState.luci (risveglio della tappa 6) finché la
	# grafica non ha le sue (LuciRisveglio.attivo).
	var luci: Node = load("res://scripts/tecnici/luci_risveglio.gd").new()
	luci.name = "LuciRisveglio"
	own(luci, gp)


# --- Tappa 7: il ritorno al buio (scripts/game/ritorno_al_buio.gd) -----------------------------

## La scia della bava (tappe 7 e 8): parte dalla vasca centrale, da dove lei era affacciata (riscontro
## sulla v0.3.1), a terra sotto la bava che scende dal bordo; dentro il cordone gira intorno al
## salvagente appoggiato al muro, passa sotto la corda e va verso ovest a sud dei lettini, fin quasi al
## muro ovest; poi lungo il muro, tra il muro e la vasca d'arrivo, come la strada B approvata il 16
## ottobre, fino alla fossa dell'area bimbi dove lei è affacciata (tappa 8). Uscendo dalla serranda
## (angolo sud-ovest) la si vede davanti, 7 m a nord, che attraversa la sala.
const SCIA := [Vector3(-0.5, 0.0, 12.45), Vector3(-1.0, 0.0, 12.75), Vector3(-1.8, 0.0, 13.0),
	Vector3(-2.8, 0.0, 12.95), Vector3(-3.6, 0.0, 12.7), Vector3(-4.6, 0.0, 12.55), Vector3(-6.0, 0.0, 12.5),
	Vector3(-7.5, 0.0, 12.55), Vector3(-9.0, 0.0, 12.5), Vector3(-10.5, 0.0, 12.45), Vector3(-12.0, 0.0, 12.5),
	Vector3(-13.5, 0.0, 12.45), Vector3(-15.0, 0.0, 12.4), Vector3(-16.3, 0.0, 12.2), Vector3(-17.4, 0.0, 11.7),
	Vector3(-18.2, 0.0, 10.8), Vector3(-18.3, 0.0, 9.25), Vector3(-18.3, 0.0, 7.8), Vector3(-18.3, 0.0, 6.0),
	Vector3(-18.3, 0.0, 4.3), Vector3(-18.3, 0.0, 2.9), Vector3(-18.3, 0.0, 1.3), Vector3(-18.3, 0.0, -0.5),
	Vector3(-18.3, 0.0, -2.3), Vector3(-18.3, 0.0, -4.1), Vector3(-17.3, 0.0, -4.9), Vector3(-16.3, 0.0, -5.5),
	Vector3(-15.3, 0.0, -5.95), Vector3(-14.7, 0.0, -6.1)]


func _tappa7(has_interiors: bool) -> void:
	var gp := level.get_node("Gioco")
	var r: Node = load("res://scripts/game/ritorno_al_buio.gd").new()
	r.name = "RitornoAlBuio"
	r.set(&"medusa", level.get_node("Vasca/Medusa"))
	r.set(&"acqua_vasca", level.get_node("Vasca/AcquaVascaCentrale"))
	r.set(&"centro_increspature", Vector3(VASCA.x, VASCA_PELO, VASCA.z + 1.0))
	r.set(&"pulsante_sigla", level.get_node("Vasca/PulsanteSigla"))
	r.set(&"scia", PackedVector3Array(SCIA))
	# Si è tirata fuori dalla vasca dove era affacciata (bordo sud, sopra il pulsante della sigla): la
	# bava sul bordo e giù per il muro (verticale, a lato del pulsante, 2 cm fuori dalla parete), fino
	# all'inizio della scia a terra; e da lì gocciola ancora.
	var muro_z := VASCA.z + VASCA_INTERNO.y * 0.5 + 0.42
	r.set(&"bordo_vasca", PackedVector3Array([Vector3(-0.95, VASCA_BORDO, muro_z - 0.22), Vector3(-0.35, VASCA_BORDO, muro_z - 0.24),
		Vector3(0.45, VASCA_BORDO, muro_z - 0.2)]))
	r.set(&"muro_vasca", PackedVector3Array([Vector3(-0.5, VASCA_BORDO - 0.01, muro_z + 0.02), Vector3(-0.5, 0.5, muro_z + 0.02),
		Vector3(-0.5, 0.02, muro_z + 0.02)]))
	r.set(&"gocciolatoi", PackedVector3Array([Vector3(-0.55, VASCA_BORDO - 0.03, muro_z + 0.03), Vector3(0.45, VASCA_BORDO - 0.03, muro_z + 0.03)]))
	own(r, gp)
	level.set(&"ritorno", r)
	if has_interiors:
		var interni := level.get_node("Interni")
		# La porta "sala pompe" del corridoio degli interni: chiusa, con la sua collisione. Con la
		# strada B della tappa 7 non si apre più (la scala sotto è chiusa dalla grata) e il ritorno
		# non passa dagli spogliatoi: RitornoAlBuio non ha più interni e porta_interni.
		var porta_mi := interni.get_node("Ambienti/Corridoio/porta_sala_pompe") as MeshInstance3D
		var bb := porta_mi.transform * porta_mi.get_aabb()
		var cardine := Marker3D.new()
		cardine.name = "CardinePortaSalaPompe"
		cardine.position = INTERNI_OFFSET + Vector3(bb.end.x, 0.0, bb.get_center().z)
		own(cardine, gp)
		var porta: Area3D = load("res://scripts/tecnici/porta_maniglione.gd").new()
		porta.name = "PortaSalaPompeInterni"
		porta.position = INTERNI_OFFSET + Vector3(bb.get_center().x, 1.0, bb.end.z + 0.35)
		# aperta contro il muro del corridoio (collaudo del 22 ottobre: a 95 gradi sporgeva 1 m sulla strada del ritorno)
		porta.set(&"angolo_apertura", -172.0)
		porta.set(&"collisione_propria", true)
		own(porta, gp)
		shape_box(porta, Vector3(1.0, 1.6, 0.5))
		porta.set(&"porta_path", porta.get_path_to(porta_mi))
		porta.set(&"cardine_path", porta.get_path_to(cardine))
	# I checkpoint del ritorno sono sulla strada B, nella scena dei tecnici (_checkpoint_tecnici).
	# Fine della demo dove finisce la scia, davanti all'area bimbi (la tappa 8 viene dopo).
	var fine := Area3D.new()
	fine.name = "FineDemo"
	fine.collision_layer = 0
	fine.collision_mask = Layers.PLAYER
	fine.monitorable = false
	fine.position = SCIA[SCIA.size() - 1] + Vector3(0.0, 1.5, 0.0)
	own(fine, gp)
	shape_box(fine, Vector3(2.4, 3.0, 2.4))
	level.set(&"fine_demo_trigger", fine)


## Un vettore da una lista [x, y, z] di sala_dati.json.
static func _v3(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


## La medusa vera nella posa "affacciata" (in ciclo), con l'aspetto bagnato e le gocce che cadono
## da dita, mento, capelli e tentacoli sul bordo (LEGGIMI della medusa).
func _medusa_bagnata(nome: String) -> Node3D:
	var medusa: Node3D = load("res://scripts/environment/medusa_affacciata.gd").new()
	medusa.name = nome
	medusa.set(&"bell_material", load(MEDUSA_DIR + "medusa_campana.tres"))
	medusa.set(&"model", load(MEDUSA_DIR + "medusa.glb"))
	var bagnata := {}
	for coppia in [["M_pelle", "medusa_pelle_bagnata"], ["M_capelli", "medusa_capelli_bagnata"],
			["M_orbita", "medusa_orbita_bagnata"], ["M_mani", "medusa_mani_bagnata"],
			["M_ciocche", "medusa_ciocche_bagnata"], ["M_tentacoli", "medusa_tentacoli_bagnata"],
			["M_occhio_bulbo", "medusa_occhio"]]:
		bagnata[coppia[0]] = load(MEDUSA_DIR + coppia[1] + ".tres")
	medusa.set(&"material_map", bagnata)
	# Gocce (coordinate della medusa, misurate sulla vasca centrale).
	var o := MEDUSA_AFFACCIATA
	medusa.set(&"punti_gocce", PackedVector3Array([
		Vector3(-0.6, 0.91, 12.31) - o, Vector3(0.6, 0.91, 12.31) - o, Vector3(0.0, 1.42, 12.02) - o,
		Vector3(-0.35, 1.30, 11.98) - o, Vector3(0.38, 1.28, 11.98) - o,
		Vector3(-1.48, 1.0, 12.3) - o, Vector3(1.48, 1.0, 12.3) - o]))
	return medusa


# --- Tappa 8: lei sbuca dal bordo nell'area bimbi, poi la spiaggia fino alla torre ----------------

## Fossa provvisoria (proposta mandata all'ambiente) finché non arrivano i suoi marker: lato sud
## della VascaBimbi1, metà ovest. Origine della posa "affacciata" e direzione in cui guarda (verso
## il giocatore che arriva dal muro ovest), fondo del condotto.
const FOSSA_PROVVISORIA := Vector3(-13.0, -0.45, -7.6)
const FOSSA_SGUARDO := Vector3(-0.7071, 0.0, 0.7071)
const FOSSA_FUGA_PROVVISORIA := Vector3(-11.0, -2.6, -6.9)
## La torre degli scivoli: piede della prima scala (sala_dati.json, "torre"). Dal 16 ottobre la
## torre è nella sala nuova dietro la parete est (PORTONE_TORRE).
const PIEDE_TORRE := Vector3(10.6, 0.0, -14.3)
## Il portone della sala della torre: perno al centro della base dell'anta (sala_dati.json,
## "sala_torre"); scorre di 2 m verso sud (+Z).
const PORTONE_TORRE := Vector3(19.84, 0.0, -15.0)


func _tappa8() -> void:
	var gp := level.get_node("Gioco")
	var sala := level.get_node("Sala")
	var lei: Node3D = load("res://scripts/game/lei_sbuca.gd").new()
	lei.name = "LeiSbuca"
	own(lei, gp)
	level.set(&"lei_sbuca", lei)
	# La fossa dell'ambiente (sala_dati.json, "fossa_bimbi": marker medusa_sbuca, medusa_fuga e
	# livello_acqua_pieno). Se non c'è ancora la scena resta spenta, su una fossa provvisoria
	# (per i test).
	var dati = JSON.parse_string(FileAccess.get_file_as_string(SALA + "sala_dati.json"))
	var fossa: Dictionary = dati.get("fossa_bimbi", {}) if dati is Dictionary else {}
	var pronta := fossa.has("medusa_sbuca") and fossa.has("medusa_fuga")
	lei.set(&"abilitata", pronta)
	var sbuca := Marker3D.new()
	var fuga := Marker3D.new()
	if pronta:
		sbuca.name = "MedusaSbuca"
		var ms: Dictionary = fossa["medusa_sbuca"]
		sbuca.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(float(ms["rotazione_gradi_godot"][1]))), _v3(ms["posizione_godot"]))
		fuga.name = "MedusaFuga"
		fuga.position = _v3(fossa["medusa_fuga"]["posizione_godot"])
		lei.set(&"livello_pieno", float(fossa.get("livello_acqua_pieno", {}).get("y", 0.42)))
	else:
		sbuca.name = "SbucaProvvisorio"
		sbuca.transform = Transform3D(Basis.looking_at(-FOSSA_SGUARDO, Vector3.UP), FOSSA_PROVVISORIA)
		fuga.name = "FugaProvvisoria"
		fuga.position = FOSSA_FUGA_PROVVISORIA
	own(sbuca, lei)
	own(fuga, lei)
	lei.set(&"punto_sbuca", sbuca)
	lei.set(&"punto_fuga", fuga)
	# Il coperchio di collisione della fossa (sala_area_bimbi.glb): acceso, non ci si cade dentro.
	for c in sala.find_children("coperchio_fossa*", "CollisionObject3D", true, false):
		lei.set(&"coperchio", c)
		break
	var medusa := _medusa_bagnata("MedusaFossa")
	# niente gocce: i punti sono misurati sulla medusa della vasca centrale, e con la posa della fossa finivano in
	# aria (controllo di posizionamento del 22 ottobre, stato lei_fossa)
	medusa.set(&"punti_gocce", PackedVector3Array())
	medusa.transform = sbuca.transform
	medusa.visible = false
	own(medusa, lei)
	lei.set(&"medusa", medusa)
	var vasche: Array[Node3D] = []
	var acque: Array[Node3D] = []
	if pronta:
		lei.set(&"superficie_fossa", _superficie_fossa())
	for n in ["VascaBimbi1", "VascaBimbi2"]:
		vasche.append(level.get_node("Vasche/" + n) as Node3D)
		acque.append(level.get_node("Vasche/Acqua" + n) as Node3D)
	lei.set(&"vasche", vasche)
	lei.set(&"acque", acque)
	# Checkpoint prima della scena (sulla scia, lungo il muro ovest, a 7 m da dove sbuca), poi
	# la strada verso il portone della sala della torre: giù nella spiaggia della piscina vuota,
	# lungo la spiaggia verso est e fuori dal lato est, fino al portone sulla parete est.
	checkpoint(gp, "CheckpointAreaBimbi", 12, Vector3(-18.3, 1.5, -0.5), Vector3(2.6, 3.0, 1.6), Vector3(0.0, -1.5, 0.0), 0.0)
	checkpoint(gp, "CheckpointSpiaggiaBuio", 13, Vector3(2.0, 1.4, -12.6), Vector3(2.6, 3.0, 2.6), Vector3(0.0, -1.5, 0.0), -PI * 0.5)
	var anta := sala.get_node_or_null("Interattivi/sala_portone_torre") as Node3D
	if anta:
		# Ripartenza davanti al portone, girati verso di lui (+X).
		checkpoint(gp, "CheckpointTorre", 14, PORTONE_TORRE + Vector3(-3.34, 1.5, 0.0), Vector3(1.6, 3.0, 4.0), Vector3(0.0, -1.5, 0.0), -PI * 0.5)
	else:
		checkpoint(gp, "CheckpointTorre", 14, PIEDE_TORRE + Vector3(-1.2, 1.5, 0.0), Vector3(1.6, 3.0, 2.6), Vector3(0.0, -1.5, 0.0), -PI * 0.5)
	# Il portone della sala della torre (PortoneTorre): chiuso fino a dopo la tappa 8, poi si apre
	# da solo appena lei va via (scelta dell'utente del 16 ottobre; con ALL_ARRIVO quando arrivi).
	var portone: Node3D = load("res://scripts/mechanisms/portone_torre.gd").new()
	portone.name = "PortoneTorre"
	portone.position = PORTONE_TORRE
	own(portone, gp)
	portone.set(&"anta", anta)
	portone.set(&"vetro", sala.get_node_or_null("Interattivi/sala_lampeggiante_torre"))
	portone.set(&"tappa8", lei)
	level.set(&"portone", portone)
	# Con la fossa pronta la demo finisce davanti al portone (la sala della torre viene dopo).
	if pronta:
		var fine := level.get(&"fine_demo_trigger") as Area3D
		if anta:
			fine.position = PORTONE_TORRE + Vector3(-2.34, 1.5, 0.0)
			for c in fine.get_children():
				if c is CollisionShape3D and (c as CollisionShape3D).shape is BoxShape3D:
					((c as CollisionShape3D).shape as BoxShape3D).size = Vector3(3.0, 3.0, 6.0)
		else:
			fine.position = PIEDE_TORRE + Vector3(0.4, 1.5, 0.0)
		level.set(&"fine_demo_testo", "La torre degli scivoli ti aspetta.\nGrazie per aver giocato!")


## L'acqua della fossa (la parte profonda della VascaBimbi1, sala_dati.json "fossa_bimbi"): è la
## stessa acqua della vasca, ma la pianta ha l'angolo sud-ovest tagliato e l'acqua dell'addon è
## rettangolare (e al massimo 8 masse d'acqua nel livello). Così la superficie è il segnaposto
## dell'ambiente (sala_acqua.glb, il poligono giusto) col materiale dell'acqua della VascaBimbi1:
## LeiSbuca la tiene alla quota della vasca.
func _superficie_fossa() -> MeshInstance3D:
	var glb := (load(SALA + "sala_acqua.glb") as PackedScene).instantiate()
	var segnaposto := glb.find_child("sala_fossa_bimbi_acqua", true, false) as MeshInstance3D
	var mi: MeshInstance3D = null
	if segnaposto:
		mi = MeshInstance3D.new()
		mi.name = "AcquaFossaBimbi"
		mi.mesh = segnaposto.mesh
		mi.transform = segnaposto.transform
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		own(mi, level.get_node("Vasche"))
	glb.free()
	return mi


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
	# I bambini animati (scenes/creature): ti seguono con la testa mentre sali.
	var models: Array[PackedScene] = [load("res://scenes/creature/bambino_cubo.tscn"), load("res://scenes/creature/bambino_agnello.tscn")]
	ks.set(&"models", models)
	# Sulla balconata ovest, dall'altra parte della sala rispetto alla torre.
	ks.set(&"spots", PackedVector3Array([Vector3(-18.4, 4.3, -11.2), Vector3(-18.6, 4.3, -9.7),
		Vector3(-18.3, 4.3, -8.1), Vector3(-18.5, 4.3, -6.6), Vector3(-18.4, 4.3, -5.0)]))
	ks.set(&"trigger", trig)
	# 16 ottobre: il soppalco non c'è più e B5 si ripropone con la sala della torre: spento.
	ks.set(&"attivo", false)
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


## I checkpoint del ritorno al buio (tappe 7-8): valgono solo dopo il risveglio (Checkpoint.solo_al_buio).
const CHECKPOINT_AL_BUIO := ["CheckpointT7Inizio", "CheckpointRaccordo", "CheckpointMagazzino", "CheckpointSerranda",
	"CheckpointAreaBimbi", "CheckpointSpiaggiaBuio", "CheckpointTorre"]


func checkpoint(parent: Node, node_name: String, order: int, pos: Vector3, size: Vector3, spawn_offset: Vector3, spawn_yaw: float) -> Area3D:
	var cp: Area3D = load("res://scripts/game/checkpoint.gd").new()
	cp.name = node_name
	cp.set(&"order", order)
	if node_name in CHECKPOINT_AL_BUIO:
		cp.set(&"solo_al_buio", true)
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
