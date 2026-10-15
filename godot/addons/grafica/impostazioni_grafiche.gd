extends Node
## Autoload "Grafica": tiene le impostazioni grafiche, i preset, il salvataggio
## in user://settings.cfg e le applica subito a finestra, viewport, Environment,
## luci, VoxelGI e particelle della scena corrente.
##
## Uso dal gioco:
##   Grafica.imposta("ombre", 3)            # cambia un valore e lo applica
##   Grafica.applica_preset("alto")
##   Grafica.valore("fov")
## Le scene non devono fare niente di speciale: l'autoload trova da solo
## l'Environment, le luci (Light3D) e i nodi VoxelGI che entrano nell'albero.
## Opzionale: meta "grafica_priorita_ombra" su una luce (0 = sempre, es. torcia;
## 1 = importante, valore predefinito; 2 = secondaria) e gruppo "grafica_particelle".

signal impostazione_cambiata(chiave: String, valore: Variant)
signal applicate

const PERCORSO := "user://settings.cfg"
const SEZIONE := "grafica"
const POST_SHADER := preload("res://addons/grafica/post_processing.gdshader")

const RISOLUZIONI: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080),
	Vector2i(2560, 1440), Vector2i(3840, 2160)]
const PRESET_NOMI: Array[String] = ["basso", "medio", "alto", "ultra"]

## Valori iniziali. Le chiavi presenti anche in PRESET le decide il preset.
const PREDEFINITI := {
	"preset": "alto",
	# Schermo
	"modalita_finestra": 0,     # 0 finestra, 1 schermo intero, 2 schermo intero esclusivo
	"risoluzione": 0,           # indice in RISOLUZIONI (solo in finestra)
	"vsync": 1,                 # 0 no, 1 sì, 2 adattivo, 3 mailbox
	"limite_fps": 0,            # 0 = nessun limite
	"fov": 62.0,                # verticale (circa 92° orizzontali in 16:9)
	# Resa (dal preset)
	"scala_rendering": 1.0,
	"upscaler": 0,              # 0 bilineare, 1 FSR 1, 2 FSR 2
	"nitidezza_fsr": 0.2,       # 0 = massima nitidezza, 2 = minima (come in Godot)
	"antialiasing": 3,          # 0 no, 1 FXAA, 2 SMAA, 3 TAA, 4 MSAA 2x, 5 MSAA 4x, 6 MSAA 8x
	"ombre": 3,                 # 0 minime (solo torcia), 1 basse, 2 medie, 3 alte, 4 ultra
	"gi": 1,                    # 0 nessuna, 1 VoxelGI, 2 SDFGI
	"nebbia": 1,                # 0 semplice, 1 volumetrica, 2 volumetrica alta
	"ssr": 2,                   # 0 no, 1 bassi, 2 medi, 3 alti
	"ssao": 3,                  # 0 no, 1..4
	"ssil": 2,                  # 0 no, 1..4
	"qualita_texture": 2,       # 0 bassa, 1 media, 2 alta
	"particelle": 2,            # 0 poche, 1 medie, 2 tutte
	# Post-processing (non toccati dai preset)
	"luminosita": 1.0,          # gamma della calibrazione
	"esposizione": 1.0,
	"contrasto": 1.0,
	"saturazione": 1.0,
	"color_grading": 1,         # indice in GRADING
	"glow": true,
	"grana": true,
	"vignetta": true,
	"aberrazione": true,
	"riduci_lampi": false,      # accessibilità: lampi più deboli e senza sfarfallio
	"calibrato": false,         # true dopo la prima calibrazione della luminosità
	# Controlli (li legge il controller del giocatore)
	"sensibilita_mouse": 1.0,   # moltiplicatore
	"inverti_y": false,
	"oscillazione_camera": true,
}

const PRESET := {
	"basso": {"scala_rendering": 0.67, "upscaler": 1, "nitidezza_fsr": 0.3, "antialiasing": 1,
		"ombre": 0, "gi": 0, "nebbia": 0, "ssr": 0, "ssao": 0, "ssil": 0,
		"qualita_texture": 0, "particelle": 0},
	"medio": {"scala_rendering": 0.77, "upscaler": 2, "nitidezza_fsr": 0.2, "antialiasing": 0,
		"ombre": 2, "gi": 0, "nebbia": 1, "ssr": 1, "ssao": 2, "ssil": 0,
		"qualita_texture": 1, "particelle": 1},
	"alto": {"scala_rendering": 1.0, "upscaler": 0, "nitidezza_fsr": 0.2, "antialiasing": 3,
		"ombre": 3, "gi": 1, "nebbia": 1, "ssr": 2, "ssao": 3, "ssil": 2,
		"qualita_texture": 2, "particelle": 2},
	"ultra": {"scala_rendering": 1.0, "upscaler": 2, "nitidezza_fsr": 0.2, "antialiasing": 0,
		"ombre": 4, "gi": 1, "nebbia": 2, "ssr": 3, "ssao": 4, "ssil": 3,
		"qualita_texture": 2, "particelle": 2},
}

## Livelli delle ombre: atlante direzionale, atlante delle luci puntiformi,
## filtro morbido, priorità massima delle luci con ombra, cascate, distanza.
const OMBRE := [
	{"dir": 1024, "pos": 2048, "filtro": RenderingServer.SHADOW_QUALITY_HARD, "priorita": 0, "cascate": 2, "distanza": 25.0},
	{"dir": 2048, "pos": 2048, "filtro": RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW, "priorita": 1, "cascate": 2, "distanza": 35.0},
	{"dir": 2048, "pos": 4096, "filtro": RenderingServer.SHADOW_QUALITY_SOFT_LOW, "priorita": 2, "cascate": 2, "distanza": 45.0},
	{"dir": 4096, "pos": 4096, "filtro": RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM, "priorita": 2, "cascate": 4, "distanza": 60.0},
	{"dir": 8192, "pos": 8192, "filtro": RenderingServer.SHADOW_QUALITY_SOFT_HIGH, "priorita": 2, "cascate": 4, "distanza": 80.0},
]

const GRADING: Array[String] = ["Neutro", "Notte fredda", "Anni '90 sbiadito", "Bleach bypass"]

var valori := {}
## Se false le modifiche non vengono scritte su disco (usato dalle catture automatiche).
var salva_su_disco := true
var _env_base := {}            # valori originali dell'Environment della scena
var _env: Environment
var _post_layer: CanvasLayer
var _post_rect: ColorRect
var _lut_cache := {}
var _salvataggio_pendente := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	valori = PREDEFINITI.duplicate()
	carica()
	_assicura_azioni_input()
	_crea_post_processing()
	get_tree().node_added.connect(_su_nodo_aggiunto)
	applica_tutto.call_deferred()


# --- API ---------------------------------------------------------------------

func valore(chiave: String) -> Variant:
	return valori.get(chiave, PREDEFINITI.get(chiave))


## Cambia un'impostazione, la applica subito e la salva.
func imposta(chiave: String, v: Variant) -> void:
	if valori.get(chiave) == v:
		return
	valori[chiave] = v
	if PRESET["alto"].has(chiave):
		valori["preset"] = _preset_corrispondente()
	_applica_chiave(chiave)
	impostazione_cambiata.emit(chiave, v)
	_salva_dopo()


func applica_preset(nome: String) -> void:
	if not PRESET.has(nome):
		return
	for k in PRESET[nome]:
		valori[k] = PRESET[nome][k]
	valori["preset"] = nome
	applica_tutto()
	impostazione_cambiata.emit("preset", nome)
	_salva_dopo()


func ripristina_predefiniti() -> void:
	valori = PREDEFINITI.duplicate()
	for k in PRESET[valori["preset"]]:
		valori[k] = PRESET[valori["preset"]][k]
	applica_tutto()
	impostazione_cambiata.emit("preset", valori["preset"])
	_salva_dopo()


func applica_tutto() -> void:
	_applica_finestra()
	_applica_viewport()
	_applica_ombre()
	_applica_environment()
	_applica_gi()
	_applica_particelle()
	_applica_post()
	_applica_fov()
	applicate.emit()


func carica() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PERCORSO) != OK:
		for k in PRESET[valori["preset"]]:
			valori[k] = PRESET[valori["preset"]][k]
		return
	for k in PREDEFINITI:
		var v: Variant = cfg.get_value(SEZIONE, k, PREDEFINITI[k])
		if typeof(v) == typeof(PREDEFINITI[k]) or (typeof(v) in [TYPE_INT, TYPE_FLOAT] and typeof(PREDEFINITI[k]) in [TYPE_INT, TYPE_FLOAT]):
			valori[k] = v


func salva() -> void:
	_salvataggio_pendente = false
	if not salva_su_disco:
		return
	var cfg := ConfigFile.new()
	cfg.load(PERCORSO)  # mantiene le altre sezioni (audio, comandi...)
	for k in valori:
		cfg.set_value(SEZIONE, k, valori[k])
	cfg.save(PERCORSO)


## Campo visivo orizzontale (gradi) corrispondente a un FOV verticale, per un rapporto dato.
static func fov_orizzontale(fov_verticale: float, rapporto := 16.0 / 9.0) -> float:
	return rad_to_deg(2.0 * atan(tan(deg_to_rad(fov_verticale) / 2.0) * rapporto))


## Moltiplicatore dei lampi per l'opzione di accessibilità.
func fattore_lampi() -> float:
	return 0.35 if valori["riduci_lampi"] else 1.0


# --- Applicazione ------------------------------------------------------------

func _applica_chiave(chiave: String) -> void:
	match chiave:
		"modalita_finestra", "risoluzione", "vsync", "limite_fps":
			_applica_finestra()
		"scala_rendering", "upscaler", "nitidezza_fsr", "antialiasing", "qualita_texture":
			_applica_viewport()
		"ombre":
			_applica_ombre()
		"gi":
			_applica_environment()
			_applica_gi()
		"particelle":
			_applica_particelle()
		"luminosita", "grana", "vignetta", "aberrazione":
			_applica_post()
		"fov":
			_applica_fov()
		_:
			_applica_environment()


func _applica_finestra() -> void:
	if DisplayServer.get_name() == "headless":
		return
	match int(valori["modalita_finestra"]):
		0:
			if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			var r: Vector2i = RISOLUZIONI[clampi(int(valori["risoluzione"]), 0, RISOLUZIONI.size() - 1)]
			var schermo := DisplayServer.screen_get_usable_rect()
			r = Vector2i(mini(r.x, schermo.size.x), mini(r.y, schermo.size.y))
			if DisplayServer.window_get_size() != r:
				DisplayServer.window_set_size(r)
				DisplayServer.window_set_position(schermo.position + (schermo.size - r) / 2)
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	var modi := [DisplayServer.VSYNC_DISABLED, DisplayServer.VSYNC_ENABLED,
		DisplayServer.VSYNC_ADAPTIVE, DisplayServer.VSYNC_MAILBOX]
	DisplayServer.window_set_vsync_mode(modi[clampi(int(valori["vsync"]), 0, 3)])
	Engine.max_fps = int(valori["limite_fps"])


func _applica_viewport() -> void:
	var vp := get_viewport()
	var upscaler := int(valori["upscaler"])
	vp.scaling_3d_mode = [Viewport.SCALING_3D_MODE_BILINEAR, Viewport.SCALING_3D_MODE_FSR,
		Viewport.SCALING_3D_MODE_FSR2][clampi(upscaler, 0, 2)]
	vp.scaling_3d_scale = clampf(float(valori["scala_rendering"]), 0.25, 2.0)
	vp.fsr_sharpness = float(valori["nitidezza_fsr"])
	var aa := int(valori["antialiasing"])
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if aa == 1 else (
		Viewport.SCREEN_SPACE_AA_SMAA if aa == 2 else Viewport.SCREEN_SPACE_AA_DISABLED)
	# FSR 2 fa già da antialiasing temporale: il TAA va spento.
	vp.use_taa = aa == 3 and upscaler != 2
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X,
		Viewport.MSAA_8X][clampi(aa - 3, 0, 3)] if aa >= 4 else Viewport.MSAA_DISABLED
	vp.use_debanding = true
	var q := int(valori["qualita_texture"])
	vp.anisotropic_filtering_level = [Viewport.ANISOTROPY_2X, Viewport.ANISOTROPY_4X,
		Viewport.ANISOTROPY_16X][clampi(q, 0, 2)]
	# Bias dei mipmap: valori positivi = texture più sfocate e leggere da campionare.
	# Godot aggiunge da solo il bias negativo necessario quando la scala è < 1.
	vp.texture_mipmap_bias = [0.75, 0.25, 0.0][clampi(q, 0, 2)]


func _applica_ombre() -> void:
	var o: Dictionary = OMBRE[clampi(int(valori["ombre"]), 0, OMBRE.size() - 1)]
	RenderingServer.directional_shadow_atlas_set_size(o["dir"], true)
	RenderingServer.directional_soft_shadow_filter_set_quality(o["filtro"])
	RenderingServer.positional_soft_shadow_filter_set_quality(o["filtro"])
	get_viewport().positional_shadow_atlas_size = o["pos"]
	for luce in get_tree().root.find_children("*", "Light3D", true, false):
		_applica_luce(luce as Light3D)


func _applica_luce(luce: Light3D) -> void:
	if not luce.has_meta("grafica_ombra_originale"):
		luce.set_meta("grafica_ombra_originale", luce.shadow_enabled)
	if not luce.get_meta("grafica_ombra_originale"):
		return
	var o: Dictionary = OMBRE[clampi(int(valori["ombre"]), 0, OMBRE.size() - 1)]
	var priorita := int(luce.get_meta("grafica_priorita_ombra", 1))
	luce.shadow_enabled = priorita <= int(o["priorita"])
	if luce is DirectionalLight3D:
		var d := luce as DirectionalLight3D
		d.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if o["cascate"] == 4 \
			else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		d.directional_shadow_max_distance = o["distanza"]


func _trova_environment() -> Environment:
	var vp := get_viewport()
	var w := vp.find_world_3d()
	var env: Environment = null
	var cam := vp.get_camera_3d()
	if cam and cam.environment:
		env = cam.environment
	elif w:
		env = w.environment if w.environment else w.fallback_environment
	return env


func _base(env: Environment) -> Dictionary:
	if env != _env:
		_env = env
		_env_base = {
			"fog_enabled": env.fog_enabled, "fog_density": env.fog_density,
			"volumetric_fog_enabled": env.volumetric_fog_enabled,
			"volumetric_fog_density": env.volumetric_fog_density,
			"tonemap_exposure": env.tonemap_exposure, "glow_enabled": env.glow_enabled,
			"ssr_enabled": env.ssr_enabled, "ssao_enabled": env.ssao_enabled,
			"ssil_enabled": env.ssil_enabled,
		}
	return _env_base


func _applica_environment() -> void:
	var env := _trova_environment()
	if env == null:
		return
	var base := _base(env)
	var rid := env.get_rid()
	# Nebbia: volumetrica se possibile; con "semplice" una nebbia di profondità
	# con lo stesso colore, che non reagisce alle luci ma costa poco.
	var nebbia := int(valori["nebbia"])
	if base["volumetric_fog_enabled"]:
		env.volumetric_fog_enabled = nebbia > 0
		env.fog_enabled = base["fog_enabled"] or nebbia == 0
		if nebbia == 0 and not base["fog_enabled"]:
			env.fog_light_color = env.volumetric_fog_albedo * 0.04
			env.fog_density = base["volumetric_fog_density"] * 0.35
			env.fog_sky_affect = 0.0
		var dim: int = [48, 64, 96][nebbia]
		RenderingServer.environment_set_volumetric_fog_volume_size(dim, dim)
		RenderingServer.environment_set_volumetric_fog_filter_active(nebbia >= 1)
	# Riflessi nello spazio schermo
	var ssr := int(valori["ssr"])
	env.ssr_enabled = base["ssr_enabled"] and ssr > 0
	env.ssr_max_steps = [16, 32, 64, 96][ssr]
	# Occlusione ambientale e luce indiretta nello spazio schermo
	var ssao := int(valori["ssao"])
	env.ssao_enabled = base["ssao_enabled"] and ssao > 0
	if ssao > 0:
		RenderingServer.environment_set_ssao_quality(ssao as RenderingServer.EnvironmentSSAOQuality,
			ssao <= 2, 0.5, 2, 50.0, 300.0)
	var ssil := int(valori["ssil"])
	env.ssil_enabled = base["ssil_enabled"] and ssil > 0
	if ssil > 0:
		RenderingServer.environment_set_ssil_quality(ssil as RenderingServer.EnvironmentSSILQuality,
			ssil <= 2, 0.5, 4, 50.0, 300.0)
	# Illuminazione globale
	env.sdfgi_enabled = int(valori["gi"]) == 2
	RenderingServer.environment_set_sdfgi_ray_count(RenderingServer.ENV_SDFGI_RAY_COUNT_32)
	# Tonemap ed esposizione
	env.tonemap_exposure = base["tonemap_exposure"] * float(valori["esposizione"])
	env.glow_enabled = base["glow_enabled"] and bool(valori["glow"])
	env.adjustment_enabled = true
	env.adjustment_contrast = float(valori["contrasto"])
	env.adjustment_saturation = float(valori["saturazione"])
	env.adjustment_color_correction = _lut(int(valori["color_grading"]))


func _applica_gi() -> void:
	RenderingServer.voxel_gi_set_quality(RenderingServer.VOXEL_GI_QUALITY_HIGH if int(valori["ombre"]) >= 4
		else RenderingServer.VOXEL_GI_QUALITY_LOW)
	for n in get_tree().root.find_children("*", "VoxelGI", true, false):
		_applica_voxel_gi(n as VoxelGI)


func _applica_voxel_gi(v: VoxelGI) -> void:
	var attivo := int(valori["gi"]) == 1
	v.visible = attivo
	# I VoxelGI creati da codice non hanno dati: li calcoliamo la prima volta che servono.
	if attivo and v.data == null and v.is_inside_tree() and v.get_meta("grafica_bake_automatico", true):
		var t0 := Time.get_ticks_msec()
		v.bake()
		print_verbose("VoxelGI %s calcolato in %d ms" % [v.name, Time.get_ticks_msec() - t0])


func _applica_particelle() -> void:
	var r: float = [0.3, 0.6, 1.0][clampi(int(valori["particelle"]), 0, 2)]
	for p in get_tree().get_nodes_in_group("grafica_particelle"):
		if p is GPUParticles3D:
			(p as GPUParticles3D).amount_ratio = r


func _applica_post() -> void:
	if _post_rect == null:
		return
	var m := _post_rect.material as ShaderMaterial
	m.set_shader_parameter("gamma", float(valori["luminosita"]))
	m.set_shader_parameter("grana", 1.0 if valori["grana"] else 0.0)
	m.set_shader_parameter("vignetta", 1.0 if valori["vignetta"] else 0.0)
	m.set_shader_parameter("aberrazione", 1.0 if valori["aberrazione"] else 0.0)


func _applica_fov() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam and not cam.has_meta("grafica_fov_fisso"):
		cam.fov = float(valori["fov"])


func _su_nodo_aggiunto(n: Node) -> void:
	if n is Light3D:
		_applica_luce.call_deferred(n)
	elif n is VoxelGI:
		_applica_voxel_gi.call_deferred(n)
	elif n is WorldEnvironment:
		_env = null
		_applica_environment.call_deferred()
	elif n is Camera3D:
		_applica_fov.call_deferred()
	elif n is GPUParticles3D and n.is_in_group("grafica_particelle"):
		_applica_particelle.call_deferred()


# --- Post-processing ---------------------------------------------------------

func _crea_post_processing() -> void:
	_post_layer = CanvasLayer.new()
	_post_layer.name = "PostProcessing"
	_post_layer.layer = 50  # sopra il gioco e l'HUD, sotto i menu (layer 100)
	_post_rect = ColorRect.new()
	_post_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_post_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = POST_SHADER
	_post_rect.material = m
	_post_layer.add_child(_post_rect)
	add_child(_post_layer)


## Mostra o nasconde il post-processing (per esempio nelle schermate 2D).
func post_processing_visibile(v: bool) -> void:
	_post_layer.visible = v


## LUT 3D generata da codice per il color grading.
func _lut(indice: int) -> Texture3D:
	if indice <= 0:
		return null
	if _lut_cache.has(indice):
		return _lut_cache[indice]
	const N := 32
	var fette: Array[Image] = []
	for b in N:
		var img := Image.create_empty(N, N, false, Image.FORMAT_RGB8)
		for g in N:
			for r in N:
				var c := Color(r / float(N - 1), g / float(N - 1), b / float(N - 1))
				img.set_pixel(r, g, _grading(indice, c))
		fette.append(img)
	var tex := ImageTexture3D.new()
	tex.create(Image.FORMAT_RGB8, N, N, N, false, fette)
	_lut_cache[indice] = tex
	return tex


static func _grading(indice: int, c: Color) -> Color:
	var l := c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722
	var v := Vector3(c.r, c.g, c.b)
	match indice:
		1:  # Notte fredda: ombre verso il blu-verde, alte luci neutre, un po' desaturato
			v = v.lerp(Vector3(l, l, l), 0.18)
			var ombra := 1.0 - smoothstep(0.0, 0.55, l)
			v += Vector3(-0.025, 0.006, 0.035) * ombra
			v = (v - Vector3(0.5, 0.5, 0.5)) * 1.06 + Vector3(0.5, 0.5, 0.5)
		2:  # Anni '90 sbiadito: neri sollevati, contrasto basso, toni caldi pastello
			v = v.lerp(Vector3(l, l, l), 0.22)
			v = v * 0.88 + Vector3(0.05, 0.04, 0.035)
			v *= Vector3(1.03, 1.0, 0.94)
		3:  # Bleach bypass: desaturato e contrastato
			v = v.lerp(Vector3(l, l, l), 0.5)
			v = (v - Vector3(0.45, 0.45, 0.45)) * 1.2 + Vector3(0.45, 0.45, 0.45)
	return Color(clampf(v.x, 0, 1), clampf(v.y, 0, 1), clampf(v.z, 0, 1))


# --- Varie -------------------------------------------------------------------

func _preset_corrispondente() -> String:
	for nome in PRESET_NOMI:
		var uguale := true
		for k in PRESET[nome]:
			if not is_equal_approx(float(valori[k]), float(PRESET[nome][k])):
				uguale = false
				break
		if uguale:
			return nome
	return "personalizzato"


func _salva_dopo() -> void:
	if not _salvataggio_pendente:
		_salvataggio_pendente = true
		salva.call_deferred()


func _assicura_azioni_input() -> void:
	_azione("torcia", KEY_F)
	_azione("menu_opzioni", KEY_ESCAPE)


static func _azione(nome: String, tasto: Key) -> void:
	if InputMap.has_action(nome):
		return
	InputMap.add_action(nome)
	var ev := InputEventKey.new()
	ev.physical_keycode = tasto
	InputMap.action_add_event(nome, ev)
