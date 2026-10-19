class_name Negatoscopio
extends Interactable
## La lavagna luminosa delle radiografie nell'infermeria (enigma-logica, nota approvata il 18 ottobre).
## Senza corrente sfarfalla; con la corrente ([member alimentazione], l'interruttore colpito col getto)
## si accende fisso. Con E ci si appoggia la radiografia ([member oggetto], dall'inventario). Accesa e
## con la radiografia sopra, fa vedere i puntini rosa che brillano nelle ossa dell'agnello, in tre
## gruppi: testa, corpo e coda ([member puntini], il codice della cassaforte).
## Grafica provvisoria: un pannello bianco e i puntini come sferette. Lo stato si salva.

signal acceso
signal radiografia_appoggiata

## La corrente: di solito il pulsante (WaterButton) da colpire col getto.
@export var alimentazione: PowerSource
@export var oggetto: StringName = &"radiografia"
## Quanti puntini in testa, nel corpo e nella coda.
@export var puntini := PackedInt32Array([4, 1, 7])
@export var colore_puntini := Color(1.0, 0.35, 0.7)

var con_radiografia := false

var _mat: StandardMaterial3D
var _luce: OmniLight3D
var _lastra: Node3D
var _gruppi: Array[Node3D] = []
var _t := 0.0
var _era_acceso := false


func _init() -> void:
	super()
	prompt = "Appoggia la radiografia"


func _ready() -> void:
	add_to_group(&"persist")
	_mat = StandardMaterial3D.new()
	_mat.emission_enabled = true
	_mat.emission = Color(0.9, 0.95, 1.0)
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.2, 0.8, 0.06)
	mi.mesh = box
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
	_lastra.position = Vector3(0.0, 0.0, 0.04)
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


# --- Checkpoint -------------------------------------------------------------------------------

func save_state() -> Dictionary:
	return {"con_radiografia": con_radiografia}


func load_state(data: Dictionary) -> void:
	con_radiografia = bool(data.get("con_radiografia", false))
	_aggiorna(0.0)
