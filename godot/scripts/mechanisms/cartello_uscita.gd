class_name CartelloUscita
extends Node3D
## Il cartello d'uscita d'emergenza della nave (l'omino verde che corre) sopra l'imbocco di un ramo
## del fiume lento: è l'indizio scelto dall'utente il 18 ottobre. Dopo il blackout funzionano solo i
## cartelli sui rami giusti: acceso se il suo [member tratto] non è un ramo sbagliato, spento e rotto
## (ogni tanto uno sfarfallio) se lo è. Grafica provvisoria: una scatola luminosa.

@export var tratto: TrattoFiume
@export var colore := Color(0.1, 1.0, 0.35)

var acceso := false

var _mat: StandardMaterial3D
var _luce: OmniLight3D
var _t := 0.0


func _ready() -> void:
	acceso = tratto != null and not tratto.ramo_sbagliato
	_mat = StandardMaterial3D.new()
	_mat.emission_enabled = true
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.9, 0.35, 0.08)
	mi.mesh = box
	mi.material_override = _mat
	add_child(mi)
	_luce = OmniLight3D.new()
	_luce.light_color = colore
	_luce.omni_range = 4.0
	_luce.set_meta(&"risveglio_ignora", true)
	add_child(_luce)
	_luce.position = Vector3(0.0, 0.0, 0.3)
	_accendi(1.0 if acceso else 0.0)


func _process(delta: float) -> void:
	if acceso:
		return
	# Rotto: quasi sempre spento, ogni tanto uno sfarfallio debole.
	_t += delta
	var k := 0.25 if fmod(_t, 3.7) < 0.08 else 0.0
	_accendi(k)


func _accendi(k: float) -> void:
	_mat.albedo_color = colore * (0.15 + 0.35 * k)
	_mat.emission = colore
	_mat.emission_energy_multiplier = 2.5 * k
	_luce.light_energy = 1.2 * k
	_luce.visible = k > 0.0
