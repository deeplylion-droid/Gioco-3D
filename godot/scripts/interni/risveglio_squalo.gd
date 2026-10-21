class_name RisveglioSqualo
extends Node3D
## L'inizio con il mostro-squalo (GDD, "L'inizio con il mostro-squalo", scelte dell'utente del 21
## ottobre). Il giocatore si sveglia per terra nel corridoio del ponte inferiore e lo squalo A gli è
## addosso, chino, con la bocca spalancata a pochi centimetri dalla faccia. Dalla porta tagliafuoco in
## fondo al corridoio arriva il verso lontano e profondo di Jilly che lo chiama: lui si gira, esita
## (si volta a guardarti), poi corre verso la porta, ci passa abbassandosi, e la porta gli sbatte dietro e
## resta chiusa. Poi il giocatore si rialza e riprende il controllo.
##
## La camera è guidata e si muove come la testa di chi è terrorizzato: si rialza da terra, si ritrae
## dalla bocca quando la testa scatta in avanti, trema, segue lo squalo che si gira e scappa, sobbalza
## alla porta. Il nodo sta dove parte lo squalo e guarda verso il giocatore (asse +Z locale): la porta è
## dietro di lui, verso -Z. Lo squalo e i tempi vengono da assets_src/mascotte/mostro_rig.py
## (mostro_squalo_A_rig.glb e .json): l'animazione "risveglio" contiene già la corsa.

signal finito

const MODELLO := "res://assets/models/mascotte/mostro_squalo_A_rig.glb"
const TEMPI := "res://assets/models/mascotte/mostro_squalo_A_rig.json"
const SHADER_BOCCA := preload("res://shaders/creature/bocca_squalo.gdshader")

## La porta tagliafuoco (il nodo del modello del corridoio) e il suo cardine, nello spazio degli interni.
@export var porta: Node3D
@export var cardine := Vector3(21.965, 0.0, -0.72)
## Di quanto è aperta all'inizio (verso il corridoio).
@export var apertura_porta := 100.0
## Altezza degli occhi mentre si è in ginocchio, a terra, davanti allo squalo.
@export var occhi_a_terra := 0.98

var tempi := {}
var squalo: Node3D
var _anim: AnimationPlayer
var _scheletro: Skeleton3D
var _ossa := {}
var _p: Player
var _t := 0.0
var _attivo := false
var _perno: Node3D
var _porta_chiusa := false
var _passi_fatti := 0
var _suoni := {}
var _yaw0 := 0.0
var _sguardo := Vector3.ZERO
var _scossa := 0.0          # sobbalzo della camera (si smorza)
var _fine := 0.0


func _ready() -> void:
	process_priority = -10       # prima del giocatore: la sua testa usa lo sguardo deciso qui
	set_process(false)
	var f := FileAccess.open(TEMPI, FileAccess.READ)
	if f:
		tempi = JSON.parse_string(f.get_as_text())
	_fine = float(tempi.get("porta", 10.0)) + 3.4
	# la porta tagliafuoco: sul suo cardine e con la collisione, chiusa (anche quando si riparte da un
	# checkpoint e la scena non c'è)
	if porta == null:
		var interni := get_parent().get_parent() if get_parent() else null
		var amb := interni.get_node_or_null(^"Ambienti") if interni else null
		if amb:
			porta = amb.find_child("porta_tagliafuoco", true, false) as Node3D
	_prepara_porta()


## La scena del risveglio: blocca il giocatore e parte.
func avvia(p: Player) -> void:
	_p = p
	_p.input_enabled = false
	_yaw0 = p.yaw
	_crea_squalo()
	_apri_porta()
	_t = 0.0
	_passi_fatti = 0
	_attivo = true
	_sguardo = _punto_bocca()
	set_process(true)
	_process(0.0)


func in_corso() -> bool:
	return _attivo


func _crea_squalo() -> void:
	if squalo:
		squalo.queue_free()
	squalo = (load(MODELLO) as PackedScene).instantiate() as Node3D
	squalo.name = "MostroSqualo"
	add_child(squalo)
	_anim = squalo.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for s in squalo.find_children("*", "Skeleton3D", true, false):
		_scheletro = s as Skeleton3D
	for nome in ["bocca", "mento_punta", "testa", "spina", "radice"]:
		_ossa[nome] = _scheletro.find_bone(nome) if _scheletro else -1
	# l'interno della bocca: carne bagnata che scurisce verso la gola
	var mat := ShaderMaterial.new()
	mat.shader = SHADER_BOCCA
	for mi in squalo.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).mesh
		for i in m.get_surface_count():
			var sm := m.surface_get_material(i)
			if sm and (sm.resource_name.begins_with("bocca_interno") or sm.resource_name.begins_with("gengiva")):
				(mi as MeshInstance3D).set_surface_override_material(i, mat)
	if _anim:
		_anim.play(_anim.get_animation_list()[0] if not _anim.has_animation("risveglio") else "risveglio")
		_anim.seek(0.0, true)


func _prepara_porta() -> void:
	if porta == null or _perno != null:
		return
	_perno = Node3D.new()
	_perno.name = "PernoPortaTagliafuoco"
	porta.get_parent().add_child.call_deferred(_perno)
	_perno.position = cardine
	_aggancia_porta.call_deferred()


func _aggancia_porta() -> void:
	var r := _perno.rotation.y      # la porta si aggancia chiusa, poi il perno torna dov'era
	_perno.rotation.y = 0.0
	porta.reparent(_perno, true)
	_perno.rotation.y = r
	# la collisione della porta (il corridoio ha il vano libero): gira con lei, chiusa blocca il passaggio
	var corpo := StaticBody3D.new()
	corpo.name = "Collisione"
	corpo.collision_layer = Layers.WORLD
	corpo.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.07, 2.07, 1.16)
	cs.shape = box
	cs.position = Vector3(0.0, 1.045, -0.58)
	corpo.add_child(cs)
	_perno.add_child(corpo)


func _apri_porta() -> void:
	if _perno == null:
		return
	_porta_chiusa = false
	_perno.rotation.y = deg_to_rad(apertura_porta)


func _bone_mondo(nome: String) -> Vector3:
	var i: int = _ossa.get(nome, -1)
	if i < 0:
		return squalo.global_position + Vector3.UP * 1.2
	return (_scheletro.global_transform * _scheletro.get_bone_global_pose(i)).origin


## Il centro della bocca aperta (tra il labbro di sopra e il mento).
func _punto_bocca() -> Vector3:
	return _bone_mondo("bocca").lerp(_bone_mondo("mento_punta"), 0.45)


func _process(delta: float) -> void:
	if not _attivo:
		return
	_t += delta
	var M: float = tempi.get("minaccia", 2.4)
	var R: float = tempi.get("richiamo", 5.4)
	var G: float = tempi.get("giro", 5.85)
	var E: float = tempi.get("esita", 6.75)
	var porta_t: float = tempi.get("porta", 10.15)
	_suoni_e_porta(R, E, porta_t)
	_camera(M, R, G, E, porta_t, delta)
	if _t >= _fine:
		_termina()


func _suona(chiave: String, nome: StringName, dove: Variant, tono := 1.0, volume := 0.0) -> void:
	if _suoni.has(chiave):
		return
	_suoni[chiave] = true
	var a := get_node_or_null(^"/root/Audio")
	if a:
		a.call(&"suona", nome, dove, volume, tono)


func _suoni_e_porta(R: float, E: float, porta_t: float) -> void:
	if _t > 0.8:
		_suona("minaccia", &"squalo_minaccia", _nodo_bocca())
	if _t > R:
		_suona("richiamo", &"jilly_richiamo", to_global(Vector3(0, 1.3, -8.5)))
	if _t > E + 0.92:
		_suona("sbuffo", &"squalo_sbuffo", _nodo_bocca())
	var passi: Array = tempi.get("passi", [])
	while _passi_fatti < passi.size() and _t >= float(passi[_passi_fatti]):
		_suona("passo%d" % _passi_fatti, &"squalo_passo", _bone_mondo("radice"))
		_passi_fatti += 1
	# la porta: lui ci passa, poi sbatte e resta chiusa; lui non si vede più
	if _perno and not _porta_chiusa:
		var x := clampf((_t - (porta_t + 0.30)) / 0.28, 0.0, 1.0)
		_perno.rotation.y = deg_to_rad(apertura_porta) * (1.0 - x * x)
		if x >= 1.0:
			_porta_chiusa = true
			_scossa = 1.0
			_suona("porta", &"porta_chiusa", _perno.global_position + Vector3.UP * 1.2, 0.72, 4.0)
	if squalo and _t > porta_t + 0.62:
		squalo.visible = false
		if _anim:
			_anim.pause()


var _bocca_nodo: Node3D
func _nodo_bocca() -> Node3D:
	if _bocca_nodo == null:
		_bocca_nodo = Node3D.new()
		_bocca_nodo.name = "Fiato"
		add_child(_bocca_nodo)
	_bocca_nodo.global_position = _punto_bocca()
	return _bocca_nodo


## La camera: occhi a terra che si rialzano, sguardo che va dal soffitto alla bocca, poi segue lo
## squalo; rinculo dalla bocca, tremore, sobbalzi. Alla fine si alza in piedi.
func _camera(M: float, R: float, G: float, E: float, porta_t: float, delta: float) -> void:
	var cam := _p.camera
	if _bocca_nodo:
		_bocca_nodo.global_position = _punto_bocca()
	var bocca := _punto_bocca()
	var occhio_base := _p.global_position + Vector3.UP * _p.stand_eye_height
	# altezza degli occhi: sdraiato (0,25 m), poi in ginocchio, poi in piedi alla fine
	var alzati := porta_t + 1.9
	var h := _liscio(0.25, occhi_a_terra, 1.2, 2.7)
	h = lerpf(h, _p.stand_eye_height, _liscio(0.0, 1.0, alzati, alzati + 1.4))
	# dove guarda: il soffitto, poi la bocca, poi lo squalo che si gira e scappa, poi davanti a sé
	var su := occhio_base + Vector3.UP * 3.0 + _p.global_basis.z * -0.3
	var obiettivo := su.lerp(bocca, _liscio(0.0, 1.0, 1.15, 2.3))
	var corpo := _bone_mondo("spina").lerp(_bone_mondo("testa"), 0.5)
	var segui := _liscio(0.0, 1.0, R + 0.15, R + 0.9) - _liscio(0.0, 1.0, porta_t + 0.6, porta_t + 2.2)
	obiettivo = obiettivo.lerp(corpo, clampf(segui, 0.0, 1.0))
	var avanti := occhio_base + (_dir_yaw(_yaw0)) * 4.0
	obiettivo = obiettivo.lerp(avanti, _liscio(0.0, 1.0, porta_t + 0.6, porta_t + 2.2))
	# lo sguardo insegue il bersaglio con un po' di ritardo (più svelto quando si spaventa)
	var rapido := 9.0 if _t < R + 0.6 else 5.0
	_sguardo = _sguardo.lerp(obiettivo, 1.0 - exp(-rapido * delta)) if delta > 0.0 else obiettivo
	var occhio := occhio_base + Vector3.UP * (h - _p.stand_eye_height)
	# si ritrae dalla bocca: sotto i 40 cm la testa va indietro e un po' giù
	var dist := occhio.distance_to(bocca)
	var indietro := clampf(0.40 - dist, 0.0, 0.25) * 1.3 * (1.0 - _liscio(0.0, 1.0, R, R + 0.6))
	# tremore: forte nella minaccia, poi meno; sobbalzo al richiamo e alla porta
	if _t > R and _t < R + 0.1:
		_scossa = maxf(_scossa, 0.7)
	_scossa = maxf(0.0, _scossa - delta * 2.5)
	var paura := 1.0 if _t < R else lerpf(1.0, 0.45, _liscio(0.0, 1.0, R, porta_t))
	paura *= 1.0 - _liscio(0.0, 1.0, alzati, alzati + 1.4) * 0.8
	var tr := Vector3(_rumore(_t, 7.0, 1.0), _rumore(_t, 6.0, 2.0), _rumore(_t, 5.0, 3.0)) * 0.012 * paura
	tr += Vector3(_rumore(_t, 21.0, 4.0), _rumore(_t, 19.0, 5.0), 0.0) * 0.03 * _scossa
	var d := _sguardo - occhio
	var yaw := atan2(-d.x, -d.z) + tr.x
	var pitch := atan2(d.y, Vector2(d.x, d.z).length()) + tr.y
	_p.set_look(yaw, pitch)
	# la testa sdraiata è girata su un fianco e si raddrizza mentre si rialza
	cam.rotation.z = deg_to_rad(_liscio(70.0, 0.0, 1.1, 2.4)) + tr.z
	cam.position = Vector3(0.0, h - _p.stand_eye_height - indietro * 0.3, indietro)


func _termina() -> void:
	_attivo = false
	set_process(false)
	var cam := _p.camera
	cam.position = Vector3.ZERO
	cam.rotation = Vector3.ZERO
	_p.set_look(_p.yaw, 0.0)
	_p.input_enabled = true
	if squalo:
		squalo.queue_free()
		squalo = null
	if _perno:
		_perno.rotation.y = 0.0
	finito.emit()


func _dir_yaw(y: float) -> Vector3:
	return Vector3(-sin(y), 0.0, -cos(y))


func _liscio(a: float, b: float, t0: float, t1: float) -> float:
	var x := clampf((_t - t0) / (t1 - t0), 0.0, 1.0)
	return lerpf(a, b, x * x * (3.0 - 2.0 * x))


func _rumore(t: float, f: float, seme: float) -> float:
	return sin(t * f * 6.283 + seme) * 0.5 + sin(t * f * 2.71 * 6.283 + seme * 1.7) * 0.3 \
		+ sin(t * f * 5.13 * 6.283 + seme * 2.3) * 0.2
