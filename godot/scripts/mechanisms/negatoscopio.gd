class_name Negatoscopio
extends Interactable
## La lavagna luminosa delle radiografie nell'infermeria (enigma-logica, nota approvata il 18 ottobre).
## Senza corrente sfarfalla; con la corrente ([member alimentazione], l'interruttore colpito col getto)
## si accende fisso. Con E ci si appoggia la radiografia ([member oggetto], dall'inventario). Accesa e
## con la radiografia sopra, fa vedere i puntini rosa che brillano nelle ossa dell'agnello, in tre
## gruppi: testa, corpo e coda ([member puntini], il codice della cassaforte).
## Grafica provvisoria (un pannello bianco e i puntini come sferette) o quella vera. Lo stato si salva.

signal acceso
signal radiografia_appoggiata

## La corrente: di solito il pulsante (WaterButton) da colpire col getto.
@export var alimentazione: PowerSource
@export var oggetto: StringName = &"radiografia"
## Quanti puntini in testa, nel corpo e nella coda.
@export var puntini := PackedInt32Array([4, 1, 7])
@export var colore_puntini := Color(1.0, 0.35, 0.7)
## Falso: invece del pannello e delle sferette provvisori, il pannello luminoso vero (davanti al
## diffusore del modello, misura [member misura_pannello]) e la radiografia vera ([member lastra_tex],
## con i puntini che brillano in [member puntini_tex], sopra solo quando è acceso).
@export var mostra_segnaposto := true
@export var misura_pannello := Vector2(0.84, 0.44)
@export var lastra_tex: Texture2D
@export var puntini_tex: Texture2D

var con_radiografia := false

var _mat: StandardMaterial3D
var _luce: OmniLight3D
var _lastra: Node3D
var _gruppi: Array[Node3D] = []
var _t := 0.0
var _era_acceso := false
var _mat_lastra: StandardMaterial3D
var _puntini_veri: MeshInstance3D


func _init() -> void:
	super()
	prompt = "Appoggia la radiografia"


func _ready() -> void:
	add_to_group(&"persist")
	_mat = StandardMaterial3D.new()
	_mat.emission_enabled = true
	_mat.emission = Color(0.9, 0.95, 1.0)
	var mi := MeshInstance3D.new()
	if mostra_segnaposto:
		var box := BoxMesh.new()
		box.size = Vector3(1.2, 0.8, 0.06)
		mi.mesh = box
	else:
		var q := QuadMesh.new()
		q.size = misura_pannello
		mi.mesh = q
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.material_override = _mat
	add_child(mi)
	_luce = OmniLight3D.new()
	_luce.light_color = Color(0.85, 0.92, 1.0)
	_luce.omni_range = 3.5
	_luce.position = Vector3(0.0, 0.0, 0.4)
	_luce.set_meta(&"risveglio_ignora", true)
	add_child(_luce)
	# La lastra con i puntini (si vede solo appoggiata).
	_lastra = Node3D.new()
	_lastra.name = "Lastra"
	add_child(_lastra)
	_lastra.position = Vector3(0.0, 0.0, 0.04 if mostra_segnaposto else 0.004)
	if not mostra_segnaposto:
		_lastra_vera()
	var mp := StandardMaterial3D.new()
	mp.albedo_color = colore_puntini
	mp.emission_enabled = true
	mp.emission = colore_puntini
	mp.emission_energy_multiplier = 3.0
	var centri := [Vector3(-0.38, 0.12, 0.0), Vector3(0.0, 0.0, 0.0), Vector3(0.4, -0.05, 0.0)]
	for g in puntini.size():
		var gruppo := Node3D.new()
		gruppo.name = ["Testa", "Corpo", "Coda"][g] if g < 3 else "Gruppo%d" % g
		_lastra.add_child(gruppo)
		gruppo.position = centri[g] if g < centri.size() else Vector3.ZERO
		for i in puntini[g]:
			if not mostra_segnaposto:
				# i puntini veri sono nella texture: qui restano solo per contarli
				gruppo.add_child(Node3D.new())
				continue
			var sf := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.018
			sm.height = 0.036
			sf.mesh = sm
			sf.material_override = mp
			gruppo.add_child(sf)
			sf.position = Vector3(cos(i * 2.4) * 0.05 * sqrt(i), sin(i * 2.4) * 0.05 * sqrt(i), 0.0)
		_gruppi.append(gruppo)
	_aggiorna(0.0)


## La radiografia vera agganciata a sinistra sul pannello e, sopra, i puntini rosa che brillano.
func _lastra_vera() -> void:
	var r := StandardMaterial3D.new()
	r.albedo_texture = lastra_tex
	r.emission_enabled = true
	r.emission_texture = lastra_tex
	r.albedo_color = Color(0.5, 0.5, 0.5)
	r.emission_energy_multiplier = 0.85
	r.roughness = 0.95
	r.metallic_specular = 0.0
	_mat_lastra = r
	var lq := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.32, 0.42)
	lq.mesh = q
	lq.material_override = r
	lq.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lq.position = Vector3(-0.15, 0.0, 0.0)
	_lastra.add_child(lq)
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.albedo_texture = puntini_tex
	pm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	pm.albedo_color = Color(1.6, 1.6, 1.6)
	_puntini_veri = MeshInstance3D.new()
	_puntini_veri.name = "Puntini"
	_puntini_veri.mesh = q
	_puntini_veri.material_override = pm
	_puntini_veri.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_puntini_veri.position = Vector3(-0.15, 0.0, 0.002)
	_lastra.add_child(_puntini_veri)


func e_acceso() -> bool:
	return alimentazione == null or alimentazione.powered


## I puntini si vedono: acceso e con la radiografia sopra.
func puntini_visibili() -> bool:
	return e_acceso() and con_radiografia


## Quanti puntini si vedono in ogni gruppo (per i test): vuoto se non si vedono.
func gruppi_visibili() -> PackedInt32Array:
	var r := PackedInt32Array()
	if puntini_visibili():
		for g in _gruppi:
			r.append(g.get_child_count())
	return r


func can_interact(by: Node) -> bool:
	return enabled and not con_radiografia and by is Player


func get_prompt(by: Node) -> String:
	return prompt if _ha(by) else ""


func _on_interact(by: Node) -> void:
	if not _ha(by):
		return
	by.call(&"remove_item", oggetto)
	con_radiografia = true
	radiografia_appoggiata.emit()
	_aggiorna(0.0)


func _ha(by: Node) -> bool:
	return by != null and by.has_method(&"has_item") and bool(by.call(&"has_item", oggetto))


func _process(delta: float) -> void:
	_t += delta
	_aggiorna(delta)


func _aggiorna(_delta: float) -> void:
	var on := e_acceso()
	if on and not _era_acceso:
		acceso.emit()
	_era_acceso = on
	# Senza corrente sfarfalla: quasi spento, con qualche lampo.
	var k := 1.0 if on else (0.35 if fmod(_t * 7.3, 5.0) < 0.6 else 0.03)
	_mat.albedo_color = Color(0.85, 0.9, 0.95) * (0.3 + 0.7 * k)
	_mat.emission_energy_multiplier = 1.8 * k
	_luce.light_energy = 1.4 * k
	_lastra.visible = con_radiografia
	for g in _gruppi:
		g.visible = puntini_visibili()
	if _puntini_veri:
		_puntini_veri.visible = puntini_visibili()
		_mat_lastra.emission_energy_multiplier = 0.85 * k


# --- Checkpoint -------------------------------------------------------------------------------

func save_state() -> Dictionary:
	return {"con_radiografia": con_radiografia}


func load_state(data: Dictionary) -> void:
	con_radiografia = bool(data.get("con_radiografia", false))
	_aggiorna(0.0)
