class_name Neon
extends Node3D
## Lampada al neon (o qualsiasi lampada) che può sfarfallare, guastarsi o spegnersi.
## Se il nodo non ha figli, crea da solo plafoniera, tubo emissivo e luce ad area
## (AreaLight3D, la luce rettangolare di Godot 4.7). Altrimenti usa le Light3D e le
## MeshInstance3D emissive che trova tra i figli.
## Segnali per l'audio: "acceso_cambiato" (clic e ronzio), "scintilla" (crepitio).

signal acceso_cambiato(acceso: bool)
signal scintilla

enum Modalita { STABILE, SFARFALLA, GUASTO, MORENTE, SPENTO }

@export var modalita := Modalita.STABILE
@export var colore := Color(0.82, 0.93, 1.0)
@export var energia_luce := 6.0
@export var energia_emissiva := 6.0
@export var lunghezza := 1.4
@export var portata := 9.0
@export var ombre := false
@export var energia_nebbia := 0.8

var livello := 1.0          # luminosità attuale 0..1
var _luci: Array[Light3D] = []
var _energie: Array[float] = []
var _materiali: Array[BaseMaterial3D] = []
var _emissioni: Array[float] = []
var _attesa := 0.0          # tempo al prossimo evento della modalità
var _raffica := 0.0         # durata residua di una raffica di sfarfallio
var _passo := 0.0           # tempo al prossimo scatto della raffica
var _dopo := 1.0            # livello a fine raffica
var _acceso := true


func _ready() -> void:
	if get_child_count() == 0:
		_crea_geometria()
	for n in find_children("*", "Light3D", true, false):
		_luci.append(n)
		_energie.append((n as Light3D).light_energy)
	for n in find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		for s in mi.mesh.get_surface_count() if mi.mesh else 0:
			var m := mi.get_active_material(s)
			if m is BaseMaterial3D and (m as BaseMaterial3D).emission_enabled:
				var copia := m.duplicate() as BaseMaterial3D
				mi.set_surface_override_material(s, copia)
				_materiali.append(copia)
				_emissioni.append(copia.emission_energy_multiplier)
	_applica(0.0 if modalita in [Modalita.SPENTO, Modalita.MORENTE] else 1.0)
	_attesa = randf_range(0.0, 2.0)


## Spegne la lampada, con una breve raffica di scintille.
func spegni(con_scintilla := true) -> void:
	modalita = Modalita.SPENTO
	if con_scintilla:
		scintilla.emit()
		_inizia_raffica(0.35, 0.0)


## Riaccende la lampada: i neon partono con qualche colpo.
func accendi(nuova := Modalita.STABILE) -> void:
	modalita = nuova
	_inizia_raffica(0.5, 1.0)


func _inizia_raffica(durata: float, livello_finale: float) -> void:
	_raffica = durata
	_passo = 0.0
	_dopo = livello_finale


func _process(delta: float) -> void:
	if _raffica > 0.0:
		_raffica -= delta
		_passo -= delta
		var l := livello
		if _passo <= 0.0:
			l = 0.0 if livello > 0.3 else randf_range(0.6, 1.0)
			_passo = randf_range(0.025, 0.09)
		_applica(_dopo if _raffica <= 0.0 else l)
		return
	_attesa -= delta
	match modalita:
		Modalita.STABILE:
			_applica(1.0)
		Modalita.SPENTO:
			_applica(0.0)
		Modalita.SFARFALLA:
			if _attesa <= 0.0:
				_inizia_raffica(randf_range(0.3, 1.6), 1.0)
				_attesa = randf_range(1.0, 4.0)
		Modalita.GUASTO:
			if _attesa <= 0.0:
				_inizia_raffica(randf_range(0.08, 0.35), 1.0)
				_attesa = randf_range(2.5, 9.0)
		Modalita.MORENTE:
			# Quasi sempre spento: ogni tanto prova ad accendersi e a volte resta su, debole.
			if _attesa <= 0.0:
				var resta := randf() < 0.35
				_inizia_raffica(randf_range(0.2, 0.9), randf_range(0.35, 0.7) if resta else 0.0)
				_attesa = randf_range(0.8, 2.5) if resta else randf_range(1.5, 5.0)


func _applica(l: float) -> void:
	var acceso := l > 0.05
	if acceso != _acceso:
		_acceso = acceso
		acceso_cambiato.emit(acceso)
	livello = l
	for i in _luci.size():
		# (una luce figlia può essere già liberata mentre il neon c'è ancora: le zone che si scaricano si liberano un
		# nodo per fotogramma, dalle foglie, AccensioneAPezzi.libera; errore a caso alla fine di test_torre)
		if not is_instance_valid(_luci[i]):
			continue
		_luci[i].light_energy = _energie[i] * l
		_luci[i].visible = l > 0.01
	for i in _materiali.size():
		# Un tubo spento resta appena grigio-luminoso ai capi: qui basta un minimo.
		_materiali[i].emission_energy_multiplier = _emissioni[i] * maxf(l, 0.004)


func _crea_geometria() -> void:
	var metallo := StandardMaterial3D.new()
	metallo.albedo_color = Color(0.32, 0.33, 0.33)
	metallo.metallic = 0.6
	metallo.roughness = 0.55
	var plafoniera := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(lunghezza + 0.12, 0.06, 0.16)
	b.material = metallo
	plafoniera.mesh = b
	plafoniera.position.y = 0.03
	add_child(plafoniera)
	var tubo := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.022
	c.bottom_radius = 0.022
	c.height = lunghezza
	c.radial_segments = 10
	c.rings = 1
	var vetro := StandardMaterial3D.new()
	vetro.albedo_color = Color(0.9, 0.92, 0.95)
	vetro.emission_enabled = true
	vetro.emission = colore
	vetro.emission_energy_multiplier = energia_emissiva
	c.material = vetro
	tubo.mesh = c
	tubo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tubo.rotation.z = PI / 2
	tubo.position.y = -0.025
	add_child(tubo)
	var luce := AreaLight3D.new()
	luce.area_size = Vector2(lunghezza, 0.05)
	luce.area_range = portata
	luce.light_color = colore
	luce.light_energy = energia_luce
	luce.light_volumetric_fog_energy = energia_nebbia
	luce.shadow_enabled = ombre
	luce.rotation.x = -PI / 2   # verso il basso
	luce.position.y = -0.05
	luce.set_meta("grafica_priorita_ombra", 2)
	add_child(luce)
