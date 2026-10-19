class_name ParatiaFiume
extends Node3D
## La paratia di un bivio del fiume lento (FiumeLento): manda la corrente a [member sinistra] o a
## [member destra]. Si gira colpendo col getto il suo bersaglio, un disco grande su un palo prima del
## bivio ([member posizione_bersaglio], globale). Il bersaglio risponde solo mentre la ciambella è sul
## tratto che arriva al bivio ([member attiva], lo decide FiumeLento): dopo il bivio non più.
## Ogni colpo la inverte. Lo stato resta (anche nei checkpoint): al giro dopo la ritrovi com'era.
## Grafica provvisoria: un pannello che si gira e un disco a strisce.

signal girata(a_destra: bool)

@export var sinistra: TrattoFiume
@export var destra: TrattoFiume
## Da che parte manda la corrente.
@export var a_destra := false
## Dove sta il bersaglio (globale).
@export var posizione_bersaglio := Vector3.ZERO
## Raggio del bersaglio (m).
@export var raggio_bersaglio := 0.4
## Litri del getto che servono per girarla, e quanto aspetta prima di un altro colpo (s).
@export var litri_per_girare := 0.5
@export var pausa := 0.8

var attiva := false
var colpi := 0

var _presa := 0.0
var _pausa_t := 0.0
var _pannello: Node3D
var _bersaglio: WaterHitbox
var _mat_bersaglio: StandardMaterial3D


func _ready() -> void:
	add_to_group(&"persist")
	_pannello = Node3D.new()
	_pannello.name = "Pannello"
	add_child(_pannello)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.5, 0.1)
	Graybox.box(_pannello, Vector3(2.6, 1.6, 0.15), Vector3(0.0, 0.8, -1.5), mat)
	_bersaglio = WaterHitbox.new()
	_bersaglio.name = "Bersaglio"
	add_child(_bersaglio)
	_bersaglio.global_position = posizione_bersaglio
	var forma := CollisionShape3D.new()
	var sfera := SphereShape3D.new()
	sfera.radius = raggio_bersaglio
	forma.shape = sfera
	_bersaglio.add_child(forma)
	var disco := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = raggio_bersaglio
	cil.bottom_radius = raggio_bersaglio
	cil.height = 0.08
	disco.mesh = cil
	disco.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	_mat_bersaglio = StandardMaterial3D.new()
	_mat_bersaglio.emission_enabled = true
	disco.material_override = _mat_bersaglio
	_bersaglio.add_child(disco)
	var palo := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.05
	pm.bottom_radius = 0.05
	pm.height = posizione_bersaglio.y + 0.5
	palo.mesh = pm
	_bersaglio.add_child(palo)
	palo.position = Vector3(0.0, -pm.height * 0.5, 0.0)
	_bersaglio.water_hit.connect(_on_colpo)
	_metti()


## Il tratto dove va adesso la corrente.
func uscita_attuale() -> TrattoFiume:
	return destra if a_destra else sinistra


func gira() -> void:
	a_destra = not a_destra
	colpi += 1
	_metti()
	girata.emit(a_destra)


func _on_colpo(litri: float, _punto: Vector3, _dir: Vector3) -> void:
	if not attiva or _pausa_t > 0.0:
		return
	_presa += litri
	if _presa >= litri_per_girare:
		_presa = 0.0
		_pausa_t = pausa
		gira()


func _physics_process(delta: float) -> void:
	_pausa_t = maxf(_pausa_t - delta, 0.0)
	_presa = maxf(_presa - delta * 0.5, 0.0)
	# Il bersaglio acceso (giallo) solo quando risponde.
	_mat_bersaglio.albedo_color = Color(1.0, 0.85, 0.1) if attiva else Color(0.3, 0.3, 0.3)
	_mat_bersaglio.emission = _mat_bersaglio.albedo_color * (0.6 if attiva else 0.0)


## Il pannello chiude, di traverso, l'imbocco del ramo dove la corrente non va.
func _metti() -> void:
	if _pannello == null:
		return
	var verso := (destra if not a_destra else sinistra)
	if verso == null:
		return
	var d := verso.direzione(0.5)
	_pannello.global_basis = Basis.looking_at(d, Vector3.UP)


# --- Checkpoint -------------------------------------------------------------------------------

func save_state() -> Dictionary:
	return {"a_destra": a_destra}


func load_state(data: Dictionary) -> void:
	a_destra = bool(data.get("a_destra", a_destra))
	_presa = 0.0
	_metti()
