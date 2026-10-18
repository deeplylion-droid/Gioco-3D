extends Node3D
## Inizio del capitolo 1: corridoio del ponte inferiore (risveglio), spogliatoi con docce,
## corridoio lava-piedi con tornello e saracinesca, stanzino dei bagnini con lo zaino-pompa.
## Modelli: assets/ambienti_interni/*.gltf (sorgente e script in assets_src/ambienti_interni).
##
## Da sola (scena principale o F3) crea il giocatore sdraiato nel corridoio, l'Environment e
## fa la scena del risveglio. Dentro la sala principale si mette [member giocatore_proprio] a
## falso: giocatore ed Environment sono quelli della sala (vedi scenes/interni/README.md).
##
## Gameplay della tappa 2 (docs/livello/capitolo1.md):
## - zaino-pompa sulla rastrelliera dello stanzino;
## - si aspira l'acqua dalla vasca lava-piedi;
## - il getto colpisce il pulsante del tornello dietro il vetro rotto: il tornello si sblocca;
## - il getto tenuto sulla turbina alza la saracinesca, che resta su: si passa nella sala;
## - tensione: le docce si aprono da sole tutte insieme e poi si chiudono; un armadietto sbatte.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const NEON_SCRIPT := preload("res://addons/grafica/neon.gd")
const LUCE_EMERGENZA_SCRIPT := preload("res://addons/grafica/luce_emergenza.gd")

## Vero quando la scena gira da sola: crea giocatore ed Environment.
@export var giocatore_proprio := true
## Il giocatore parte sdraiato e si rialza (solo all'inizio, non dopo un checkpoint).
@export var risveglio_animato := true
## Secondi delle docce che si aprono da sole.
@export var durata_docce := 6.0

@onready var ambienti: Node3D = $Ambienti
@onready var corridoio: Node3D = $Ambienti/Corridoio
@onready var spogliatoi: Node3D = $Ambienti/Spogliatoi
@onready var stanzino: Node3D = $Ambienti/Stanzino
@onready var pulsante_tornello: WaterButton = $Meccanismi/PulsanteTornello
@onready var blocco_tornello: StaticBody3D = $Meccanismi/BloccoTornello
@onready var passaggio_tornello: Area3D = $Meccanismi/PassaggioTornello
@onready var perno_turbina: Node3D = $Meccanismi/PernoTurbina
@onready var risveglio: Marker3D = $Gioco/Risveglio
@onready var trigger_docce: Area3D = $Gioco/DocceDaSole
@onready var trigger_armadietto: Area3D = $Gioco/ArmadiettoSbatte

var tornello_sbloccato := false
var docce_aperte := false
var _docce: Array[Node] = []
var _vapore: Node
var _docce_fatte := false
var _armadietto_fatto := false
var _tornello_in_giro := false


func _ready() -> void:
	add_to_group(&"persist")
	MaterialiInterni.applica(ambienti)
	MaterialiInterni.metti_decal(self)
	_prepara_ambienti()
	_prepara_luci()
	_prepara_docce()
	pulsante_tornello.pressed.connect(_sblocca_tornello)
	passaggio_tornello.body_entered.connect(_on_passaggio_tornello)
	trigger_docce.body_entered.connect(_on_trigger_docce)
	trigger_armadietto.body_entered.connect(_on_trigger_armadietto)
	if giocatore_proprio:
		_crea_ambiente()
		_crea_giocatore()


# --- Modelli ---------------------------------------------------------------------------------

func _prepara_ambienti() -> void:
	# Pozze: superficie scura e lucidissima, semitrasparente (riflette con SSR e sonda).
	var pozza := StandardMaterial3D.new()
	pozza.albedo_color = Color(0.04, 0.05, 0.05, 0.55)
	pozza.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pozza.roughness = 0.02
	pozza.metallic = 0.2
	pozza.metallic_specular = 0.8
	for n in ambienti.find_children("acqua_pozz*", "MeshInstance3D", true, false):
		(n as MeshInstance3D).material_override = pozza
		(n as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Neon spenti: il diffusore del modello non deve brillare.
	var spento := StandardMaterial3D.new()
	spento.albedo_color = Color(0.62, 0.64, 0.62)
	spento.roughness = 0.35
	for n in ambienti.find_children("*_tubi", "MeshInstance3D", true, false):
		(n as MeshInstance3D).material_override = spento
	# Ante colorate degli armadietti (stile B): tinta sopra la texture del modello.
	for n in ambienti.find_children("armadietti_*", "MeshInstance3D", true, false):
		var colore := Color.WHITE
		if "_giallo" in n.name:
			colore = Color(1.25, 1.0, 0.35)
		elif "_rosso" in n.name:
			colore = Color(1.35, 0.45, 0.4)
		else:
			continue
		var mi := n as MeshInstance3D
		var base := mi.mesh.surface_get_material(0) as BaseMaterial3D
		if base:
			var t := base.duplicate() as BaseMaterial3D
			t.albedo_color = colore
			mi.material_override = t
	# L'acqua della vasca lava-piedi la disegna l'addon acqua (Acqua/AcquaLavapiedi).
	var lp := spogliatoi.find_child("acqua_lavapiedi", true, false)
	if lp:
		lp.visible = false
	# Vetri sporchi trasparenti: dietro il vetro rotto si deve vedere il pulsante del tornello.
	# Sporco e riflessi sui bordi (shaders/interni/vetro_sporco.gdshader): prima era quasi invisibile e la
	# finestra del gabbiotto sembrava vuota. Il bordo del buco e le crepe sono più chiari e quasi opachi.
	var vetro := ShaderMaterial.new()
	vetro.shader = preload("res://shaders/interni/vetro_sporco.gdshader")
	vetro.set_shader_parameter("rumore", load("res://assets/ambienti_interni/shader_tex/rumore.png"))
	var bordo := StandardMaterial3D.new()
	bordo.albedo_color = Color(0.8, 0.88, 0.86, 0.75)
	bordo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bordo.roughness = 0.15
	bordo.cull_mode = BaseMaterial3D.CULL_DISABLED
	for n in ambienti.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count() if mi.mesh else 0:
			var m := mi.mesh.surface_get_material(i)
			if m and m.resource_name.begins_with("vetro_sporco"):
				mi.set_surface_override_material(i, vetro)
			elif m and m.resource_name.begins_with("vetro_bordo"):
				mi.set_surface_override_material(i, bordo)
	# Vetri: niente ombre (altrimenti le luci rosse non passano dagli oblò).
	for n in ambienti.find_children("*vetro*", "MeshInstance3D", true, false):
		(n as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# La girante della turbina gira dentro il suo perno (asse Z del perno = asse della ruota).
	var ruota := spogliatoi.find_child("turbina_saracinesca", true, false) as Node3D
	if ruota:
		ruota.reparent(perno_turbina, true)


# --- Luci: neon dell'addon grafica e luci d'emergenza ------------------------------------------

## La lampada sopra la vasca lava-piedi davanti ai tornelli (scelta dell'utente del 18 ottobre, senza
## più la torcia): una plafoniera come le altre degli spogliatoi (la stessa del modello, appesa al
## soffitto), sempre accesa, con una luce bianca fredda da servizio sulla vasca e sui tornelli.
const LAMPADA_TORNELLI := Vector3(9.7, 2.7, -13.4)   # il soffitto sopra il centro della vasca


func _lampada_tornelli() -> void:
	var cassa := ambienti.find_child("neon_spogliatoi_4", true, false) as MeshInstance3D
	var tubi := ambienti.find_child("neon_spogliatoi_4_tubi", true, false) as MeshInstance3D
	if cassa == null or tubi == null:
		return
	var neon: Node3D = NEON_SCRIPT.new()
	neon.name = "LampadaTornelli"
	neon.set(&"colore", Color(0.85, 0.93, 1.0))
	var alto := cassa.get_aabb().end.y
	neon.transform = Transform3D(cassa.global_basis, LAMPADA_TORNELLI - Vector3(0.0, alto, 0.0))
	for m in [cassa, tubi]:
		var copia := MeshInstance3D.new()
		copia.name = String(m.name).replace("neon_spogliatoi_4", "lampada")
		copia.mesh = m.mesh   # senza il materiale "spento" dei tubi: il diffusore resta acceso
		neon.add_child(copia)
	var luce := OmniLight3D.new()
	luce.name = "Luce"
	luce.light_color = Color(0.85, 0.93, 1.0)
	luce.light_energy = 1.6
	luce.omni_range = 6.5
	luce.light_volumetric_fog_energy = 0.4
	luce.shadow_enabled = true
	luce.position = Vector3(0.0, -0.15, 0.0)
	neon.add_child(luce)
	add_child(neon)


func _prepara_luci() -> void:
	# Neon accesi che sfarfallano: il tubo del modello diventa una lampada Neon con la sua luce.
	for tubo in ambienti.find_children("*_tubo_sfarfalla", "MeshInstance3D", true, false):
		var neon: Node3D = NEON_SCRIPT.new()
		neon.name = String(tubo.name).replace("_tubo_sfarfalla", "_neon")
		neon.set(&"modalita", 1)          # SFARFALLA
		neon.set(&"colore", Color(0.78, 1.0, 0.9))
		# Il Neon va montato completo (tubo del modello + luce) PRIMA di entrare nella scena:
		# se entra vuoto si costruisce da solo un'altra plafoniera con un'altra luce (neon doppi)
		# e non vede la luce aggiunta dopo (che quindi non sfarfallava).
		var genitore := tubo.get_parent()
		neon.transform = (tubo as Node3D).transform
		genitore.remove_child(tubo)
		neon.add_child(tubo)
		(tubo as Node3D).transform = Transform3D.IDENTITY
		var luce := OmniLight3D.new()
		luce.light_color = Color(0.78, 1.0, 0.9)
		luce.light_energy = 0.7
		luce.omni_range = 5.0
		luce.light_volumetric_fog_energy = 0.3
		luce.shadow_enabled = true
		luce.position = Vector3(0, -0.15, 0)
		neon.add_child(luce)
		genitore.add_child(neon)
	_lampada_tornelli()
	# La lucina del pulsante del tornello: solo un alone sul pulsante.
	var spia := ambienti.find_child("luce_pulsante_tornello", true, false) as OmniLight3D
	if spia:
		spia.light_energy = 0.4
		spia.omni_range = 1.2
		spia.shadow_enabled = false
	# Le luci rosse del modello diventano LuceEmergenza (lampada del modello, luce dell'addon).
	var i := 0
	for l in ambienti.find_children("luce_emergenza_*_luce", "Light3D", true, false):
		var le: Node3D = LUCE_EMERGENZA_SCRIPT.new()
		le.name = String(l.name).replace("_luce", "_rossa")
		# Una ogni quattro pulsa piano; quella sopra la porta della sala pompe pure.
		var pulsa := i % 4 == 3 or String(l.name) == "luce_emergenza_04_luce"
		le.set(&"modalita", 1 if pulsa else 0)
		le.set(&"energia", 2.0)
		le.set(&"portata", 6.0)
		le.set(&"energia_nebbia", 0.4)
		le.set(&"ombre", i % 2 == 0)
		l.get_parent().add_child(le)
		le.global_position = l.global_position
		# La luce importata resta ma spenta (l'addon grafica la tiene già in elenco).
		l.visible = false
		_nascondi_lampada_addon.call_deferred(le)
		i += 1


## La LuceEmergenza crea una sua lampada: qui c'è già quella a gabbia del modello.
func _nascondi_lampada_addon(le: Node) -> void:
	for m in le.find_children("*", "MeshInstance3D", false, false):
		(m as MeshInstance3D).visible = false


# --- Docce ---------------------------------------------------------------------------------

func _prepara_docce() -> void:
	var bocchetta := preload("res://addons/acqua/scenes/bocchetta.tscn")
	for e in spogliatoi.find_children("emit_doccia_*", "", true, false):
		var b: Node3D = bocchetta.instantiate()
		b.name = String(e.name).replace("emit_", "getto_")
		b.set(&"exit_speed", 0.6)
		b.set(&"drops_per_second", 220)
		b.set(&"stream_width", 0.12)
		add_child(b)
		# Asse -Z della bocchetta verso il basso.
		b.global_transform = Transform3D(Basis.from_euler(Vector3(-PI / 2, 0, 0)), (e as Node3D).global_position)
		_docce.append(b)
	var v := spogliatoi.find_child("emit_vapore_docce", true, false) as Node3D
	if v:
		_vapore = preload("res://addons/grafica/vapore.gd").new()
		_vapore.set(&"portata", 1.2)
		_vapore.set(&"raggio", 1.8)
		_vapore.set(&"altezza", 1.6)
		add_child(_vapore)
		(_vapore as Node3D).global_position = v.global_position - Vector3(0, 1.4, 0)
	apri_docce(false)


## Apre o chiude tutte le docce (getti e vapore).
func apri_docce(aperte: bool) -> void:
	docce_aperte = aperte
	for b in _docce:
		b.set(&"always_on", aperte)
	if _vapore:
		(_vapore as Node3D).visible = aperte
		_vapore.set_process(aperte)


func _on_trigger_docce(body: Node3D) -> void:
	if _docce_fatte or not body is Player:
		return
	_docce_fatte = true
	apri_docce(true)
	await get_tree().create_timer(durata_docce).timeout
	apri_docce(false)


# --- Armadietto che sbatte (falso spavento) ---------------------------------------------------

func _on_trigger_armadietto(body: Node3D) -> void:
	if _armadietto_fatto or not body is Player:
		return
	var anta := spogliatoi.find_child("armadietto_sbatte_anta", true, false) as Node3D
	if anta == null:
		return
	_armadietto_fatto = true
	var chiusa := anta.rotation.y
	var t := create_tween()
	t.tween_property(anta, "rotation:y", chiusa - deg_to_rad(105.0), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(anta, "rotation:y", chiusa - deg_to_rad(85.0), 0.25).set_trans(Tween.TRANS_SINE)
	t.tween_property(anta, "rotation:y", chiusa - deg_to_rad(92.0), 0.4).set_trans(Tween.TRANS_SINE)


# --- Tornello ------------------------------------------------------------------------------

func _sblocca_tornello() -> void:
	if tornello_sbloccato:
		return
	tornello_sbloccato = true
	blocco_tornello.process_mode = Node.PROCESS_MODE_DISABLED
	var spia := spogliatoi.find_child("luce_pulsante_tornello", true, false) as Light3D
	if spia:
		spia.light_color = Color(0.2, 1.0, 0.3)


func _on_passaggio_tornello(body: Node3D) -> void:
	if not tornello_sbloccato or _tornello_in_giro or not body is Player:
		return
	var rotore := spogliatoi.find_child("tornello_rotore", true, false) as Node3D
	if rotore == null:
		return
	_tornello_in_giro = true
	var t := create_tween()
	t.tween_property(rotore, "rotation:y", rotore.rotation.y - TAU / 3.0, 0.9).set_trans(Tween.TRANS_SINE)
	t.tween_callback(func(): _tornello_in_giro = false)


## Stato per i checkpoint (gruppo "persist").
func save_state() -> Dictionary:
	return {"tornello": tornello_sbloccato, "docce": _docce_fatte, "armadietto": _armadietto_fatto}


func load_state(data: Dictionary) -> void:
	_docce_fatte = bool(data.get("docce", false))
	_armadietto_fatto = bool(data.get("armadietto", false))
	if bool(data.get("tornello", false)):
		_sblocca_tornello()


# --- Da sola: Environment, giocatore e risveglio ----------------------------------------------

func _crea_ambiente() -> void:
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	var env: Environment = AmbienteHorror.crea(false)
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.6, 0.7)
	env.ambient_light_energy = 0.1
	env.tonemap_exposure = 0.8
	env.glow_intensity = 0.35
	we.environment = env
	add_child(we)


func _crea_giocatore() -> void:
	if GameState.player and is_instance_valid(GameState.player):
		return
	var nuovo_livello: bool = GameState.snapshot.get("scene", "") != scene_file_path
	var p: Player = PLAYER_SCENE.instantiate()
	p.name = "Player"
	p.transform = risveglio.global_transform
	add_child(p)
	# Lo zaino si trova nello stanzino: si parte senza, anche dopo un checkpoint.
	if p.water_pack:
		p.water_pack.start_equipped = false
		if not p.has_item(&"zaino_pompa"):
			p.water_pack.set_equipped(false, false)
			p.water_pack.set_tank_amount(0.0)
	if nuovo_livello and risveglio_animato and not Game.is_automated():
		fai_risveglio(p)


## Il giocatore si sveglia per terra: la camera parte sdraiata, guarda il soffitto e si rialza.
func fai_risveglio(p: Player) -> void:
	p.input_enabled = false
	var cam := p.camera
	var yaw := p.yaw
	cam.position.y = -1.35
	cam.rotation.z = deg_to_rad(75.0)
	p.set_look(yaw, deg_to_rad(70.0))
	var t := create_tween().set_parallel(true)
	t.tween_interval(1.2)
	t.chain().tween_property(cam, "rotation:z", 0.0, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(cam, "position:y", 0.0, 2.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_method(func(a: float): p.set_look(yaw, a), deg_to_rad(70.0), 0.0, 2.4).set_trans(Tween.TRANS_SINE)
	t.chain().tween_callback(func(): p.input_enabled = true)
