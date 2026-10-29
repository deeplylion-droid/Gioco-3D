class_name LuceEmergenza
extends Node3D
## Luce d'emergenza rossa: fissa, pulsante o rotante (lampeggiante a specchio).
## Crea da sola la lampada (base, cupola emissiva) e le luci. Il "su" della
## lampada è l'asse Y locale: per montarla a parete ruotare il nodo.

signal stato_cambiato(accesa: bool)

enum Modalita { FISSA, PULSANTE, ROTANTE, SPENTA }

@export var modalita := Modalita.FISSA:
	set(v):
		modalita = v
		if is_inside_tree():
			_aggiorna_tipo()
@export var colore := Color(1.0, 0.07, 0.03)
@export var energia := 3.0
@export var portata := 11.0
@export var ombre := true
@export var giri_al_secondo := 0.55
@export var pulsazioni_al_secondo := 0.7
@export var energia_nebbia := 2.0

var _omni: OmniLight3D
var _perno: Node3D
var _spot: Array[SpotLight3D] = []
var _cupola_mat: StandardMaterial3D
var _t := 0.0


func _ready() -> void:
	var base := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.09
	bm.bottom_radius = 0.11
	bm.height = 0.06
	var metallo := StandardMaterial3D.new()
	metallo.albedo_color = Color(0.12, 0.12, 0.12)
	metallo.roughness = 0.6
	bm.material = metallo
	base.mesh = bm
	base.position.y = 0.03
	add_child(base)
	var cupola := MeshInstance3D.new()
	var cm := SphereMesh.new()
	cm.radius = 0.085
	cm.height = 0.17
	cm.is_hemisphere = true
	_cupola_mat = StandardMaterial3D.new()
	_cupola_mat.albedo_color = Color(0.5, 0.02, 0.01)
	_cupola_mat.roughness = 0.15
	_cupola_mat.emission_enabled = true
	_cupola_mat.emission = colore
	_cupola_mat.emission_energy_multiplier = 3.0
	cm.material = _cupola_mat
	cupola.mesh = cm
	cupola.position.y = 0.06
	cupola.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cupola)
	_omni = OmniLight3D.new()
	_omni.light_color = colore
	_omni.omni_range = portata
	_omni.omni_attenuation = 1.4
	_omni.shadow_enabled = ombre
	_omni.shadow_bias = 0.06
	_omni.light_volumetric_fog_energy = energia_nebbia
	_omni.position.y = 0.2  # un po' fuori dalla lampada, così non si fa ombra da sola
	add_child(_omni)
	_perno = Node3D.new()
	_perno.position.y = 0.11
	add_child(_perno)
	for k in 2:
		var s := SpotLight3D.new()
		s.light_color = colore
		s.spot_range = portata * 1.6
		s.spot_angle = 22.0
		s.spot_attenuation = 1.2
		s.shadow_enabled = ombre
		s.shadow_bias = 0.05
		s.light_volumetric_fog_energy = energia_nebbia * 1.5
		s.rotation.y = PI * k + PI / 2
		s.rotation.x = -0.12
		s.position = Vector3(0, 0, 0)
		s.set_meta("grafica_priorita_ombra", 2)
		_perno.add_child(s)
		_spot.append(s)
	_aggiorna_tipo()


func _aggiorna_tipo() -> void:
	if not _luci_vive():
		return
	var rotante := modalita == Modalita.ROTANTE
	_omni.visible = modalita in [Modalita.FISSA, Modalita.PULSANTE]
	# Con il lampeggiante resta una luce tenue tutt'intorno, senza ombra.
	if rotante:
		_omni.visible = true
		_omni.light_energy = energia * 0.15
		_omni.shadow_enabled = false
	else:
		_omni.shadow_enabled = ombre
	for s in _spot:
		if not is_instance_valid(s):
			continue
		s.visible = rotante
		s.light_energy = energia * 2.5
	_cupola_mat.emission_energy_multiplier = 0.0 if modalita == Modalita.SPENTA else 3.0
	stato_cambiato.emit(modalita != Modalita.SPENTA)


func _process(delta: float) -> void:
	# (la luce e il perno sono figli: quando una zona si scarica si liberano dalle foglie, un po' per fotogramma,
	# AccensioneAPezzi.libera, e la lampada resta qualche fotogramma senza; ricontrollo del 29 ottobre)
	if not _luci_vive():
		return
	_t += delta
	match modalita:
		Modalita.FISSA:
			_omni.light_energy = energia
		Modalita.PULSANTE:
			var p := 0.5 + 0.5 * sin(_t * TAU * pulsazioni_al_secondo)
			p = p * p
			_omni.light_energy = energia * lerpf(0.08, 1.0, p)
			_cupola_mat.emission_energy_multiplier = lerpf(0.3, 4.0, p)
		Modalita.ROTANTE:
			_perno.rotation.y = _t * TAU * giri_al_secondo


## La luce e il perno ci sono ancora (vedi [method _process]).
func _luci_vive() -> bool:
	return is_instance_valid(_omni) and is_instance_valid(_perno)
