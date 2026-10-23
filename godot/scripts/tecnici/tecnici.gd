extends Node3D
## Ambienti tecnici del capitolo 1 (tappe 5-6 di docs/livello/capitolo1.md): dal portello sul fondo
## della piscina a onde si scende nella camera delle onde (26 m), poi il tunnel porta alla sala pompe.
## Modelli: assets/ambienti_tecnici/*.gltf (script in tools/blender/ambienti2_*.py).
##
## Qui c'è solo la preparazione visiva e i segnaposto: materiali senza ripetizioni (gli stessi shader
## degli interni), luci segnaposto, decal. La logica di gioco (turbine, leva, porte, paratie, acqua)
## la monta l'integratore partendo dai marker in Marker/ (vedi scenes/tecnici/LEGGIMI.md).
##
## Da sola crea un giocatore in fondo alla scala del pozzo e l'Environment, per provarla e per gli scatti.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const NEON_SCRIPT := preload("res://addons/grafica/neon.gd")
const LUCE_EMERGENZA_SCRIPT := preload("res://addons/grafica/luce_emergenza.gd")
const PARETE := preload("res://shaders/interni/parete.gdshader")
const PIASTRELLE := preload("res://shaders/interni/piastrelle.gdshader")
const SHT := "res://assets/ambienti_interni/shader_tex/"
const TEXI := "res://assets/ambienti_interni/texture/"

## Vero quando la scena gira da sola: crea giocatore ed Environment.
@export var giocatore_proprio := true

## materiale importato -> come trattarlo
const PARETI_BASE := {
	# soglia_alto: la ruggine sopra la quota dei tubi, circa un terzo di prima; scrostatura delle lamiere dimezzata
	# (muri più calmi, proposta texture_muri del 23 ottobre: prima 0,35 e 0,15)
	"cemento": {"tinta": Color(0.95, 0.95, 0.95), "scrostatura": 0.0, "soglia_alto": 0.62},
	"cemento_bagnato": {"tinta": Color(0.9, 0.9, 0.9), "scrostatura": 0.0, "soglia_alto": 0.62},
	"lamiere_rivettate": {"tinta": Color(1, 1, 1), "scrostatura": 0.07, "soglia_alto": 0.62},
}
const PIASTRELLE_BASE := {
	"piastrelle_muro": {"per_lato": 0.0, "bagnato": 0.15},
	"pavimento_bagnato": {"per_lato": 0.0, "bagnato": 0.55},
}
const TINTE_TURBINE := {"TURBINA_1": Color(1.35, 1.05, 0.25), "TURBINA_2": Color(1.4, 0.35, 0.3), "TURBINA_3": Color(0.35, 0.6, 1.5)}

@onready var ambienti: Node3D = $Ambienti

static var _cache := {}


## Mesh dei modelli senza la loro scatola di collisione (*-convcolonly) nel generatore: si attraversavano
## camminando (controllo di posizionamento del 22 ottobre). Prendono la collisione della loro forma.
## (SALA_ringhiera no: ha le sue scatole nel generatore, e i montanti della scaletta della vasca, che sono nella
## stessa mesh, vanno lasciati liberi: si esce dalla vasca passandoci in mezzo.)
const SENZA_COLLISIONE := ["QUADRO_elettrico", "QUADRO_strumenti", "SALA_arredo", "SALA_tubi",
		"CAMERA_pozzo", "CAMERA_bocchette"]


func _ready() -> void:
	_applica_materiali(ambienti)
	_collisioni_mancanti()
	_fogli()
	_prepara_acqua()
	_prepara_luci()
	_decal()
	if giocatore_proprio:
		_crea_ambiente()
		_crea_giocatore()


func _collisioni_mancanti() -> void:
	for nome in SENZA_COLLISIONE:
		var mi := ambienti.find_child(nome, true, false) as MeshInstance3D
		if mi == null or mi.mesh == null:
			push_warning("Tecnici: %s non c'è, niente collisione da aggiungere" % nome)
			continue
		mi.create_trimesh_collision()   # un StaticBody3D figlio, sullo strato 1 (Layers.WORLD)


# --- Materiali --------------------------------------------------------------------------------

func _applica_materiali(radice: Node) -> void:
	var rumore: Texture2D = load(SHT + "rumore.png")
	for mi in radice.find_children("*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		if m3.mesh == null:
			continue
		for i in m3.mesh.get_surface_count():
			var m := m3.mesh.surface_get_material(i) as BaseMaterial3D
			if m == null:
				continue
			var nome := m.resource_name
			var nuovo: Material = null
			if _cache.has(nome):
				nuovo = _cache[nome]
			elif PARETI_BASE.has(nome):
				var d: Dictionary = PARETI_BASE[nome]
				var sm := ShaderMaterial.new()
				sm.shader = PARETE
				sm.set_shader_parameter("usa_base", true)
				sm.set_shader_parameter("pannelli", false)
				sm.set_shader_parameter("colore_vernice", d["tinta"])
				sm.set_shader_parameter("base_albedo", m.albedo_texture)
				sm.set_shader_parameter("base_normal", m.normal_texture)
				sm.set_shader_parameter("base_rough", m.roughness_texture)
				# variante "scrostata": ruggine degli interni (solo dove serve)
				sm.set_shader_parameter("scrostatura", d["scrostatura"])
				sm.set_shader_parameter("soglia_alto", d["soglia_alto"])
				sm.set_shader_parameter("scrostata_albedo", load(TEXI + "ruggine_col.jpg"))
				sm.set_shader_parameter("scrostata_normal", load(TEXI + "ruggine_nrm.jpg"))
				sm.set_shader_parameter("scrostata_rough", load(TEXI + "ruggine_met-ruggine_rgh.jpg"))
				sm.set_shader_parameter("lamiera_normal", load(SHT + "lamiera_nrm.jpg"))
				sm.set_shader_parameter("colature", load(SHT + "colature.png"))
				sm.set_shader_parameter("rumore", rumore)
				sm.set_shader_parameter("quota_tubi", 3.2)
				nuovo = sm
			elif PIASTRELLE_BASE.has(nome):
				var d: Dictionary = PIASTRELLE_BASE[nome]
				var sm := ShaderMaterial.new()
				sm.shader = PIASTRELLE
				sm.set_shader_parameter("albedo_tex", m.albedo_texture)
				sm.set_shader_parameter("normal_tex", m.normal_texture)
				sm.set_shader_parameter("rough_tex", m.roughness_texture)
				sm.set_shader_parameter("rumore", rumore)
				sm.set_shader_parameter("piastrelle_per_lato", d["per_lato"])
				sm.set_shader_parameter("bagnato", d["bagnato"])
				sm.set_shader_parameter("profondita_fughe", 0.0)
				nuovo = sm
			elif nome == "lamiera_forata":
				# La canaletta della camera delle onde (riscontro della v0.3.1, punto 5): è una scatola
				# sottile col fondo alla quota del pavimento. Con la trasparenza "blend" e le due facce, dai
				# fori si vedevano due superfici alla stessa quota che sfarfallavano a cerchietti. Fori ritagliati
				# (alpha scissor) e solo le facce davanti: dai fori si vede il pavimento, fermo.
				var lam := m.duplicate() as BaseMaterial3D
				lam.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				lam.alpha_scissor_threshold = 0.5
				lam.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
				lam.cull_mode = BaseMaterial3D.CULL_BACK
				nuovo = lam
			elif nome == "carta_sporca":
				# I fogli del glTF della sala pompe sono scatole piatte senza texture: sulla scrivania
				# sembravano una forma grigia e di lato spuntavano dietro il monitor (riscontro della
				# v0.3.7). Spariscono: al loro posto i fogli veri del kit di dettagli (_fogli).
				var via := StandardMaterial3D.new()
				via.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				via.albedo_color = Color(0, 0, 0, 0)
				via.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				nuovo = via
			elif m.albedo_texture and m.albedo_texture.resource_path.contains("Rust004"):
				# la ruggine calma più grande (proposta texture_muri del 23 ottobre: più fitta, le macchie si notavano)
				var rug := m.duplicate() as BaseMaterial3D
				rug.uv1_scale = m.uv1_scale * 0.7
				nuovo = rug
			elif nome.begins_with("ACQUA"):
				var acqua := StandardMaterial3D.new()
				acqua.albedo_color = Color(0.02, 0.025, 0.025, 0.85)
				acqua.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				acqua.roughness = 0.03
				acqua.metallic_specular = 0.8
				nuovo = acqua
			_cache[nome] = nuovo
			if nuovo:
				m3.set_surface_override_material(i, nuovo)
	# turbine colorate (la girante Meshy è d'acciaio: la tinta dice l'ordine dello schema)
	for nome in TINTE_TURBINE:
		var t := radice.find_child(nome, true, false) as MeshInstance3D
		if t and t.mesh:
			var b := t.mesh.surface_get_material(0) as BaseMaterial3D
			if b:
				var c := b.duplicate() as BaseMaterial3D
				c.albedo_color = TINTE_TURBINE[nome]
				t.material_override = c
	# neon spenti: il diffusore non brilla
	var spento := StandardMaterial3D.new()
	spento.albedo_color = Color(0.62, 0.64, 0.62)
	spento.roughness = 0.35
	for n in radice.find_children("*_tubi", "MeshInstance3D", true, false):
		(n as MeshInstance3D).material_override = spento
	for n in radice.find_children("*_vetro_spento", "MeshInstance3D", true, false):
		(n as MeshInstance3D).material_override = spento


# --- Fogli sulla scrivania e per terra (kit di dettagli) -------------------------------------------

## [nodo del kit, posizione nella sala pompe (coordinate del glTF), rotazione in gradi, scala]: due
## fogli e un appunto sul piano della scrivania, accanto al monitor; tre carte per terra.
const FOGLI := [
	["det_foglio_1", Vector3(4.98, 0.781, 5.43), 12.0, 0.8],
	["det_foglio_3", Vector3(5.12, 0.783, 5.36), -28.0, 0.7],
	["det_carta_accartocciata_2", Vector3(4.82, 0.78, 5.62), 0.0, 1.0],
	["det_foglio_2", Vector3(-1.5, 0.004, 0.4), 30.0, 1.0],
	["det_foglio_4", Vector3(1.1, 0.004, -0.4), -10.0, 1.0],
	["det_carta_accartocciata_1", Vector3(-4.2, 0.0, 3.6), 0.0, 1.0],
]


func _fogli() -> void:
	var sala := ambienti.get_node_or_null(^"SalaPompe") as Node3D
	if sala == null or not ResourceLoader.exists("res://assets/ambiente/dettagli/gltf/detriti.gltf"):
		return
	var kit: Node3D = (load("res://assets/ambiente/dettagli/gltf/detriti.gltf") as PackedScene).instantiate()
	for f in FOGLI:
		var n := kit.find_child(f[0], true, false) as Node3D
		if n == null:
			continue
		var copia := n.duplicate() as Node3D
		copia.name = "Foglio_" + String(f[0])
		# nel GLB del kit i nodi sono messi in fila: conta solo l'origine (alla base del foglio)
		copia.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(f[2])).scaled(Vector3.ONE * f[3]), f[1])
		sala.add_child(copia)
	kit.free()


# --- Acqua nera della vasca di raccolta (la disegna l'addon acqua: Acqua/AcquaVascaRaccolta) -----

func _prepara_acqua() -> void:
	var segnaposto := ambienti.find_child("ACQUA_vasca_raccolta", true, false) as Node3D
	if segnaposto:
		segnaposto.visible = false
	# scatola della sala pompe per i riflessi dell'acqua, in coordinate mondo (la scena nel livello è girata)
	var link := get_node_or_null("Acqua/AcquaVascaRaccolta")
	if link == null:
		return
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for i in 8:
		var p := global_transform * Vector3(46.3 if i & 1 else 28.3, 5.5 if i & 2 else -1.7, 3.8 if i & 4 else -8.2)
		lo = lo.min(p)
		hi = hi.max(p)
	link.set(&"env_box_min", lo)
	link.set(&"env_box_max", hi)
	if link.has_method(&"_apply_style"):
		link.call(&"_apply_style")


# --- Luci segnaposto (le finali le fa la sessione grafica) ------------------------------------

func _prepara_luci() -> void:
	for tubo in ambienti.find_children("*_tubo_sfarfalla", "MeshInstance3D", true, false):
		var neon: Node3D = NEON_SCRIPT.new()
		neon.name = String(tubo.name).replace("_tubo_sfarfalla", "_neon")
		neon.set(&"modalita", 1)
		neon.set(&"colore", Color(0.6, 0.95, 1.0))
		# Il Neon va montato completo (tubo del modello + luce) PRIMA di entrare nella scena,
		# come negli interni: se entra vuoto si costruisce da solo un'altra plafoniera con
		# un'altra luce (neon doppi) e non vede la luce aggiunta dopo.
		var genitore := tubo.get_parent()
		neon.transform = (tubo as Node3D).transform
		genitore.remove_child(tubo)
		neon.add_child(tubo)
		(tubo as Node3D).transform = Transform3D.IDENTITY
		var luce := OmniLight3D.new()
		luce.light_color = Color(0.6, 0.95, 1.0)
		luce.light_energy = 1.2
		luce.omni_range = 7.0
		luce.shadow_enabled = true
		luce.position = Vector3(0, -0.2, 0)
		neon.add_child(luce)
		genitore.add_child(neon)
	var i := 0
	for l in ambienti.find_children("LUCE_rossa_*", "Light3D", true, false):
		var le: Node3D = LUCE_EMERGENZA_SCRIPT.new()
		le.name = String(l.name).replace("LUCE_rossa_", "emergenza_")
		le.set(&"modalita", 1 if i % 3 == 2 else 0)
		le.set(&"energia", 2.0)
		le.set(&"portata", 8.0)
		le.set(&"energia_nebbia", 0.4)
		le.set(&"ombre", i % 2 == 0)
		l.get_parent().add_child(le)
		le.global_position = l.global_position
		l.visible = false
		_nascondi_lampada_addon.call_deferred(le)
		i += 1
	for l in ambienti.find_children("LUCE_*", "Light3D", true, false):
		if l.visible and not String(l.name).begins_with("LUCE_rossa_"):
			l.light_energy = minf(l.light_energy, 2.0)
			if l is OmniLight3D:
				(l as OmniLight3D).omni_range = 6.0
			l.shadow_enabled = true


func _nascondi_lampada_addon(le: Node) -> void:
	# la lampada c'è già nel modello: quella dell'addon si toglie (nascosta restava un doppione per il controllo
	# di posizionamento); il suo materiale, che pulsa, lo tiene l'addon
	for m in le.find_children("*", "MeshInstance3D", false, false):
		m.queue_free()


# --- Decal: macchie, colature di ruggine e crepe in punti scelti ------------------------------

func _decal() -> void:
	var camera: Node3D = $Ambienti/CameraOnde
	var sala: Node3D = $Ambienti/SalaPompe
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	MaterialiInterni.ruggine_contate = 0
	# camera delle onde: colature sul muro sud (z = 2,2) e sul soffitto, macchie a terra
	for x in [1.5, 4.8, 8.2, 11.7, 15.3, 19.6, 22.6]:
		MaterialiInterni.decal(camera, "ruggine", Vector3(x + rng.randf_range(-0.4, 0.4), 2.9, 2.18), Vector3(0, 0, -1), 0.7, 1.6, 0.8)
	for x in [3.0, 9.0, 13.0, 20.0]:
		MaterialiInterni.decal(camera, "macchia", Vector3(x, 4.18, rng.randf_range(-1.2, 1.2)), Vector3.DOWN, 1.8, 1.8, 0.75, rng.randf_range(0, TAU))
		MaterialiInterni.decal(camera, "macchia", Vector3(x + 1.3, 0.0, rng.randf_range(-1.4, 1.4)), Vector3.UP, 1.5, 1.5, 0.6, rng.randf_range(0, TAU))
	for x in [2.4, 12.6, 22.0]:
		MaterialiInterni.decal(camera, "crepa", Vector3(x, 0.6, 2.18), Vector3(0, 0, -1), 1.0, 1.0, 0.9, rng.randf_range(0, TAU))
	# sala pompe: colature sotto il collettore (muro nord, z = -6 nel glTF) e sopra la vasca
	for x in [-7.0, -3.5, 0.5, 4.0, 7.5]:
		MaterialiInterni.decal(sala, "ruggine", Vector3(x, 3.6, -5.98), Vector3(0, 0, 1), 0.8, 1.8, 0.8)
	for p in [Vector3(-2.0, 5.48, 2.0), Vector3(4.0, 5.48, -2.0), Vector3(-6.0, 5.48, 3.5)]:
		MaterialiInterni.decal(sala, "macchia", p, Vector3.DOWN, 2.2, 2.2, 0.7, rng.randf_range(0, TAU))
	for p in [Vector3(-4.6, 0.0, -1.2), Vector3(2.2, 0.0, 1.0), Vector3(6.4, 0.0, 3.4)]:
		MaterialiInterni.decal(sala, "macchia", p, Vector3.UP, 1.6, 1.6, 0.6, rng.randf_range(0, TAU))
	MaterialiInterni.decal(sala, "crepa", Vector3(-8.98, 0.7, 4.0), Vector3(1, 0, 0), 1.0, 1.0, 0.9, 1.0)
	# raccordo: colature sul muro sud del corridoio, macchie a terra e sul pianerottolo in cima
	var racc: Node3D = $Ambienti/Raccordo
	for x in [47.4, 49.9]:
		MaterialiInterni.decal(racc, "ruggine", Vector3(x, 1.9, 2.38), Vector3(0, 0, -1), 0.6, 1.4, 0.8)
	MaterialiInterni.decal(racc, "macchia", Vector3(48.2, 0.0, 1.4), Vector3.UP, 1.4, 1.4, 0.6, 0.7)
	MaterialiInterni.decal(racc, "macchia", Vector3(44.5, 7.25, -7.8), Vector3.UP, 1.4, 1.4, 0.6, 2.1)
	MaterialiInterni.decal(racc, "crepa", Vector3(52.58, 1.0, -1.0), Vector3(-1, 0, 0), 1.0, 1.0, 0.9, 0.4)


# --- Da sola: Environment e giocatore ---------------------------------------------------------

func _crea_ambiente() -> void:
	var we := WorldEnvironment.new()
	var env: Environment = AmbienteHorror.crea(false)
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.6, 0.7)
	env.ambient_light_energy = 0.12
	env.tonemap_exposure = 0.9
	we.environment = env
	add_child(we)


func _crea_giocatore() -> void:
	if GameState.player and is_instance_valid(GameState.player):
		return
	var p: Player = PLAYER_SCENE.instantiate()
	p.name = "Player"
	var inizio := get_node_or_null("Marker/marker_arrivo_scala") as Node3D
	p.transform = inizio.global_transform if inizio else Transform3D.IDENTITY
	add_child(p)
