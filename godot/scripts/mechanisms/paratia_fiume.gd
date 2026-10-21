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
## Falso: niente pannello e disco provvisori. Il disco a strisce vero (con [member materiale_disco]) su
## un palo giallo con la sua lampada; le chiuse vere le muove la scena del fiume guardando
## [member a_destra].
@export var mostra_segnaposto := true
@export var materiale_disco: Material
@export var modello_lampada: PackedScene
## Da dove si guarda il disco (globale): il disco gira la faccia verso quel punto.
@export var guarda_da := Vector3.ZERO

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
	if mostra_segnaposto:
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
	if mostra_segnaposto:
		_disco_provvisorio()
	else:
		_disco_vero()
	_bersaglio.water_hit.connect(_on_colpo)
	_metti()


## Il disco provvisorio: giallo quando risponde, grigio se no.
func _disco_provvisorio() -> void:
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


## Il disco a strisce di 80 cm sul palo giallo, girato verso [member guarda_da], con la lampada
## d'emergenza sopra che lo illumina (come nella proposta approvata).
func _disco_vero() -> void:
	# il piede del palo sulla banchina, alla quota della paratia
	var piede := Vector3(posizione_bersaglio.x, global_position.y, posizione_bersaglio.z)
	var dove := guarda_da if guarda_da != Vector3.ZERO else posizione_bersaglio + Vector3(0, 0, 1)
	var verso := dove - posizione_bersaglio
	verso.y = 0.0
	verso = verso.normalized() if verso.length_squared() > 0.0001 else Vector3.BACK
	var alto := posizione_bersaglio.y - piede.y
	var palo := MeshInstance3D.new()
	palo.name = "Palo"
	var pm := CylinderMesh.new()
	pm.top_radius = 0.045
	pm.bottom_radius = 0.05
	pm.height = alto + 0.2
	palo.mesh = pm
	var mp := StandardMaterial3D.new()
	mp.albedo_color = Color(0.85, 0.7, 0.1)
	mp.metallic = 0.4
	mp.roughness = 0.5
	palo.material_override = mp
	add_child(palo)
	palo.global_position = piede + Vector3(0, (alto + 0.2) * 0.5, 0) - verso * 0.08
	var disco := MeshInstance3D.new()
	disco.name = "Disco"
	var dm := CylinderMesh.new()
	dm.top_radius = raggio_bersaglio
	dm.bottom_radius = raggio_bersaglio
	dm.height = 0.04
	disco.mesh = dm
	disco.material_override = materiale_disco
	add_child(disco)
	disco.global_transform = Transform3D(Basis.looking_at(verso, Vector3.UP) * Basis(Vector3.RIGHT, PI * 0.5), posizione_bersaglio)
	_mat_bersaglio = StandardMaterial3D.new()
	if modello_lampada:
		var l := modello_lampada.instantiate() as Node3D
		add_child(l)
		l.global_position = posizione_bersaglio + Vector3(0, 0.5, 0) - verso * 0.12
		l.look_at(posizione_bersaglio + verso * 0.6, Vector3.UP)
	var s := SpotLight3D.new()
	s.name = "LuceDisco"
	add_child(s)
	s.global_position = posizione_bersaglio + verso * 0.5 + Vector3(0, 0.6, 0)
	s.look_at(posizione_bersaglio, Vector3.UP)
	s.light_color = Color(1.0, 0.9, 0.7)
	s.light_energy = 1.2
	s.spot_range = 3.0
	s.spot_angle = 30.0
	s.set_meta(&"risveglio_ignora", true)


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
	if not mostra_segnaposto:
		return
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
