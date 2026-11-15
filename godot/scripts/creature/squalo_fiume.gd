class_name SqualoFiume
extends Node3D
## Lo squalo nel fiume lento (build 0.5.0 «La storia», scelta A; GDD del 15 novembre). Il mostro-squalo del risveglio
## segue la ciambella nell'acqua scura: si vedono solo la pinna dorsale e la scia, e la testa con la bocca aperta quando
## attacca. Tre volte per giro accelera e arriva alla ciambella; un getto sul muso lo ricaccia sotto; se arriva, morde
## ([member letale]) o urta la ciambella e la fa girare.
##
## Il fiume (FiumeLento, di enigmi) gli dà una guida ([member guida], vedi [method _guida_ok] e
## docs/tecnico/squalo_fiume/LEGGIMI.md): dove sta la ciambella, il fiume dietro di lei, quanto va veloce, se adesso
## può attaccare. Lui dà i segnali [signal morde] (il fiume fa il nero e la ripartenza morbida dall'imbarco, poi chiama
## [method riparti]) e [signal urta] (il fiume fa girare la ciambella).
##
## I movimenti sono in assets_src/mascotte/squalo_fiume.py (mostro_squalo_A_fiume.glb): l'origine dello squalo sta sul
## pelo, lui guarda verso +Z.

## Comincia a seguire: lo sbuffo alle spalle, la pinna e la scia.
signal compare
## Testa fuori a bocca aperta: comincia l'attacco.
signal attacca
## Il getto sul muso l'ha ricacciato sotto.
signal respinto
## È arrivato e ha morso (con [member letale]): il fiume fa il nero e la ripartenza morbida dall'imbarco.
signal morde
## È arrivato senza [member letale]: ha urtato la ciambella (il fiume la fa girare per [member giro_urto] s).
signal urta

const MODELLO := "res://assets/models/mascotte/mostro_squalo_A_fiume.glb"
const SHADER_BOCCA := preload("res://shaders/creature/bocca_squalo.gdshader")
const SHADER_DENTI := preload("res://shaders/creature/denti_squalo.gdshader")
const SHADER_SCIA := preload("res://shaders/creature/scia_squalo.gdshader")
const ANIM_NUOTA := &"fiume_nuota"
const ANIM_EMERGE := &"fiume_emerge"
const ANIM_ATTACCO := &"fiume_attacco"
const ANIM_RESPINTO := &"fiume_respinto"
const ANIM_MORSO := &"fiume_morso"
## Quando la bocca si chiude in fiume_morso (s; MORSO_T di squalo_fiume.py).
const MORSO_T := 0.55
## Di quanto sta più giù alla fine di fiume_respinto (AFFONDO di squalo_fiume.py).
const AFFONDO := 0.9

enum Stato { ASSENTE, SEGUE, CARICA, ATTACCO, RESPINTO, MORSO, URTO }

@export var abilitato := true
## Se spento non morde: arriva, urta la ciambella e la fa girare.
@export var letale := true
@export_group("Distanze e velocità")
## La distanza a cui segue la ciambella che va alla velocità della corrente (m, lungo il fiume).
@export var distanza := 12.0
## La velocità della corrente a cui la distanza resta [member distanza] (m/s): più lenta la ciambella, più si avvicina.
@export var velocita_media := 2.2
## Quanto in fretta torna alla sua distanza (1/s): la sua velocità è la media più tanto per i metri in più.
@export var richiamo := 0.15
## Mai più vicino di così mentre segue (m).
@export var distanza_min := 4.0
## Accelerando per attaccare: di quanto va più veloce della ciambella (m/s).
@export var carica := 2.6
## A questa distanza la testa esce e comincia l'attacco (m).
@export var distanza_attacco := 6.0
@export_group("Tempi")
## Dalla testa fuori al morso (s); la prima volta, finché il giocatore non l'ha respinto una volta, [member primo_morso].
@export var tempo_morso := 3.0
@export var primo_morso := 4.0
## Secondi di getto sul muso (di fila) che lo ricacciano sotto: lo stesso numero di lei.
@export var getto_per_respingere := 0.5
## Dopo una respinta, niente attacchi per almeno tanto (s).
@export var pausa_respinta := 8.0
## Attacchi per giro del fiume (la guida dice quanto dura un giro; se no [member intervallo]).
@export var attacchi_per_giro := 3
@export var intervallo := Vector2(16.0, 24.0)
## Dopo una ripartenza, niente attacchi per tanto (s).
@export var calma_ripartenza := 3.0
## Senza [member letale]: per quanto gira la ciambella dopo l'urto (s; lo fa il fiume).
@export var giro_urto := 3.0

## La guida del fiume (vedi la descrizione della classe): un oggetto con i metodi ciambella(), dietro(metri),
## avanti(metri), velocita() e puo_attaccare(); facoltativo durata_giro().
var guida: Object
var stato := Stato.ASSENTE
## Metri dietro la ciambella, lungo il fiume.
var dietro := 12.0
var squalo: Node3D
var respinto_una_volta := false

var _anim: AnimationPlayer
var _scheletro: Skeleton3D
var _bocca_osso := -1
var _t := 0.0
var _prossimo := 0.0
var _calma := 0.0
var _affondo := 0.0
var _getto := 0.0
var _ultimo_getto := -1
var _muso: WaterHitbox
var _scia: MeshInstance3D
var _cam_da := Transform3D.IDENTITY
var _cam_locale := Transform3D.IDENTITY
var _cam: Camera3D


func _ready() -> void:
	_crea()
	_nascondi()


# --- La guida ----------------------------------------------------------------------------------------------------

func _guida_ok() -> bool:
	return guida != null and is_instance_valid(guida) and guida.has_method(&"ciambella") and guida.has_method(&"dietro")


func _velocita_ciambella() -> float:
	return float(guida.call(&"velocita")) if guida.has_method(&"velocita") else velocita_media


func _puo_attaccare() -> bool:
	return guida.has_method(&"puo_attaccare") and bool(guida.call(&"puo_attaccare"))


func _intervallo() -> float:
	if guida and guida.has_method(&"durata_giro") and attacchi_per_giro > 0:
		var g := float(guida.call(&"durata_giro"))
		if g > 1.0:
			# (il conto va solo mentre segue: tolto quanto dura un attacco, la carica, la testa fuori e il ritorno)
			var attacco := (distanza - distanza_attacco) / carica + primo_morso + 1.4
			return maxf(4.0, g / attacchi_per_giro - attacco) * randf_range(0.85, 1.15)
	return randf_range(intervallo.x, intervallo.y)


# --- Comandi dal fiume -------------------------------------------------------------------------------------------

## Comincia a seguire la ciambella (dopo il primo bivio): lo sbuffo alle spalle, poi la pinna e la scia.
func comincia() -> void:
	if not abilitato or stato != Stato.ASSENTE or not _guida_ok():
		return
	dietro = distanza
	_affondo = 0.0
	_prossimo = _intervallo()
	_cambia(Stato.SEGUE)
	squalo.visible = true
	_scia.visible = true
	_anima(ANIM_NUOTA)
	Audio.suona(&"squalo_sbuffo", _posizione_dietro(dietro), 0.0, 1.0)
	compare.emit()


## Dopo il nero del morso (ripartenza morbida dall'imbarco): torna indietro, calmo per [member calma_ripartenza] s.
## Se [param presente] è falso sparisce (il fiume lo richiama con [method comincia] dopo il primo bivio).
func riparti(presente := false) -> void:
	_rimetti_camera()
	dietro = distanza
	_affondo = 0.0
	_calma = calma_ripartenza
	_prossimo = maxf(_intervallo(), calma_ripartenza)
	if presente and abilitato:
		_cambia(Stato.SEGUE)
		squalo.visible = true
		_scia.visible = true
		_anima(ANIM_NUOTA)
	else:
		_nascondi()


## Sparisce (fuori dal fiume, interruttore spento).
func ferma() -> void:
	_rimetti_camera()
	_nascondi()


# --- Ogni fotogramma ---------------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if stato == Stato.ASSENTE or not _guida_ok():
		return
	if not abilitato:
		ferma()
		return
	_t += delta
	_calma = maxf(0.0, _calma - delta)
	var vc := _velocita_ciambella()
	match stato:
		Stato.SEGUE:
			# torna alla sua distanza: più lenta la ciambella, più vicino
			var vs := velocita_media + richiamo * (dietro - distanza)
			dietro = maxf(distanza_min, dietro + (vc - vs) * delta)
			_affondo = move_toward(_affondo, 0.0, 0.6 * delta)
			_prossimo -= delta
			if _prossimo <= 0.0 and _calma <= 0.0 and _puo_attaccare():
				_cambia(Stato.CARICA)
				Audio.suona(&"squalo_ringhio", _posizione_dietro(dietro), -4.0, 1.0)
		Stato.CARICA:
			dietro -= carica * delta
			if not _puo_attaccare():
				_cambia(Stato.SEGUE)
				_prossimo = 2.0
			elif dietro <= distanza_attacco:
				_cambia(Stato.ATTACCO)
				_getto = 0.0
				_anima(ANIM_EMERGE)
				_anim.queue(ANIM_ATTACCO)
				Audio.suona(&"squalo_minaccia", _posizione_dietro(dietro) + Vector3.UP * 0.4, 0.0, 1.0)
				attacca.emit()
		Stato.ATTACCO:
			# da distanza_attacco a 0 nel tempo del morso
			var tm := tempo_morso if respinto_una_volta else primo_morso
			dietro = maxf(0.0, distanza_attacco * (1.0 - _t / tm))
			_aggiorna_muso()
			if _t >= tm:
				if letale:
					_mordi()
				else:
					_urta()
		Stato.RESPINTO:
			# va giù e resta indietro
			_affondo = minf(AFFONDO, _affondo + 1.8 * delta)
			dietro += 1.5 * delta
			if _t >= 1.4:
				_cambia(Stato.SEGUE)
				_anima(ANIM_NUOTA)
				_prossimo = maxf(_intervallo(), pausa_respinta)
		Stato.URTO:
			_affondo = minf(AFFONDO, _affondo + 1.5 * delta)
			dietro += 2.0 * delta
			if _t >= 1.2:
				_cambia(Stato.SEGUE)
				_anima(ANIM_NUOTA)
				_prossimo = maxf(_intervallo(), pausa_respinta)
		Stato.MORSO:
			_morso_camera()
			return
	_metti()


func _cambia(s: Stato) -> void:
	stato = s
	_t = 0.0


## Lo squalo sul fiume, [member dietro] m dietro la ciambella, girato dove va la corrente, sul pelo (giù di
## [member _affondo] dopo una respinta). La scia dietro la pinna.
func _metti() -> void:
	var p := _posizione_dietro(dietro)
	var avanti := _verso_dietro(dietro)
	squalo.global_transform = Transform3D(Basis.looking_at(avanti, Vector3.UP, true), p + Vector3.DOWN * _affondo)
	_scia.global_transform = Transform3D(Basis.looking_at(avanti, Vector3.UP, true), p + Vector3.UP * 0.01)
	var vis := _affondo < 0.35
	_scia.visible = vis and squalo.visible
	(_scia.material_override as ShaderMaterial).set_shader_parameter(&"forza", clampf(1.0 - _affondo / 0.35, 0.0, 1.0)
			* (1.6 if stato == Stato.CARICA or stato == Stato.ATTACCO else 1.0))


func _posizione_dietro(m: float) -> Vector3:
	return guida.call(&"dietro", m) as Vector3


## Il verso della corrente [param m] m dietro la ciambella (da lì verso la ciambella).
func _verso_dietro(m: float) -> Vector3:
	var a := _posizione_dietro(m)
	var b: Vector3 = _posizione_dietro(m - 0.5) if m >= 0.5 else guida.call(&"avanti", 0.5 - m) as Vector3
	var d := b - a
	d.y = 0.0
	return d.normalized() if d.length() > 0.01 else Vector3.FORWARD


# --- Il getto sul muso -------------------------------------------------------------------------------------------

func _aggiorna_muso() -> void:
	if _bocca_osso >= 0:
		_muso.global_position = _scheletro.global_transform * _scheletro.get_bone_global_pose(_bocca_osso).origin
	_muso.monitorable = true


func _su_getto(_litri: float, _punto: Vector3, _dir: Vector3) -> void:
	if stato != Stato.ATTACCO:
		return
	# i secondi di getto di fila, nel tempo del gioco (come AcquaDiLei)
	var ora := Engine.get_physics_frames()
	var passo := 1.0 / Engine.physics_ticks_per_second
	if _ultimo_getto >= 0 and (ora - _ultimo_getto) * passo <= 0.2:
		_getto += (ora - _ultimo_getto) * passo
	else:
		_getto = 0.0
	_ultimo_getto = ora
	if _getto >= getto_per_respingere:
		respingi()


## Lo ricaccia sotto adesso (come mezzo secondo di getto sul muso).
func respingi() -> void:
	if stato != Stato.ATTACCO:
		return
	respinto_una_volta = true
	_cambia(Stato.RESPINTO)
	_anima(ANIM_RESPINTO, 0.05)
	Audio.suona(&"tuffo", squalo.global_position + Vector3.UP * 0.3, -2.0, 0.8)
	respinto.emit()


# --- Il morso e l'urto -------------------------------------------------------------------------------------------

func _urta() -> void:
	_cambia(Stato.URTO)
	_anima(ANIM_RESPINTO, 0.05)
	Audio.suona(&"atterraggio_acqua", squalo.global_position, 2.0, 0.7)
	urta.emit()


func _mordi() -> void:
	_cambia(Stato.MORSO)
	_anima(ANIM_MORSO, 0.05)
	_cam = get_viewport().get_camera_3d()
	if _cam:
		_cam_da = _cam.global_transform
		_cam_locale = _cam.transform
	get_tree().create_timer(MORSO_T, false).timeout.connect(func():
		if stato == Stato.MORSO:
			Audio.suona(&"morso", _cam_da.origin, 2.0, 0.85)
			Audio.suona(&"squalo_denti", _cam_da.origin, 0.0, 1.0)
			morde.emit())


## Nel morso la camera è tirata giù verso la bocca, e lui è girato verso la camera con la bocca davanti: come al
## risveglio, la bocca in faccia.
func _morso_camera() -> void:
	if _cam == null or not is_instance_valid(_cam):
		return
	var occhi := _cam_da.origin
	var verso := (squalo.global_position - occhi)
	verso.y = 0.0
	if verso.length() < 0.1:
		verso = -_cam_da.basis.z
		verso.y = 0.0
	verso = verso.normalized()
	# lui davanti alla camera, girato verso di lei, sul pelo
	var pelo := (guida.call(&"ciambella") as Vector3).y
	var k := clampf(_t / MORSO_T, 0.0, 1.0)
	var dove := occhi + verso * lerpf(1.6, 1.15, k)
	dove.y = pelo
	squalo.global_transform = Transform3D(Basis.looking_at(-verso, Vector3.UP, true), dove)
	_scia.visible = false
	# la camera scende verso la bocca
	var bocca := _scheletro.global_transform * _scheletro.get_bone_global_pose(_bocca_osso).origin if _bocca_osso >= 0 else dove + Vector3.UP * 0.3
	var arrivo := bocca - verso * 0.35 + Vector3.UP * 0.05
	var pos := occhi.lerp(arrivo, smoothstep(0.0, 1.0, k))
	_cam.global_transform = Transform3D(Basis.looking_at(bocca - pos, Vector3.UP), pos)


## Dopo il morso la camera torna dov'era sulla testa del giocatore.
func _rimetti_camera() -> void:
	if _cam and is_instance_valid(_cam) and stato == Stato.MORSO:
		_cam.transform = _cam_locale
	_cam = null


# --- Il modello ------------------------------------------------------------------------------------------------

func _crea() -> void:
	squalo = (load(MODELLO) as PackedScene).instantiate() as Node3D
	squalo.name = "SqualoFiume"
	add_child(squalo)
	_anim = squalo.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for s in squalo.find_children("*", "Skeleton3D", true, false):
		_scheletro = s as Skeleton3D
	_bocca_osso = _scheletro.find_bone("bocca") if _scheletro else -1
	# la bocca e i denti come al risveglio (RisveglioSqualo._crea_squalo)
	var mat := ShaderMaterial.new()
	mat.shader = SHADER_BOCCA
	var mat_denti := ShaderMaterial.new()
	mat_denti.shader = SHADER_DENTI
	for mi in squalo.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).mesh
		for i in m.get_surface_count():
			var sm := m.surface_get_material(i)
			if sm and (sm.resource_name.begins_with("bocca_interno") or sm.resource_name.begins_with("gengiva")):
				(mi as MeshInstance3D).set_surface_override_material(i, mat)
			elif sm and sm.resource_name.begins_with("denti"):
				(mi as MeshInstance3D).set_surface_override_material(i, mat_denti)
	# il muso da colpire col getto
	_muso = WaterHitbox.new()
	_muso.name = "Muso"
	var cs := CollisionShape3D.new()
	var sf := SphereShape3D.new()
	sf.radius = 0.45
	cs.shape = sf
	_muso.add_child(cs)
	add_child(_muso)
	_muso.water_hit.connect(_su_getto)
	# la scia: due baffi di schiuma a V dietro la pinna, sul pelo
	_scia = MeshInstance3D.new()
	_scia.name = "Scia"
	_scia.mesh = _mesh_scia()
	var ms := ShaderMaterial.new()
	ms.shader = SHADER_SCIA
	_scia.material_override = ms
	_scia.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_scia)


## La scia: una V di due strisce (lunghe 3,5 m, larghe 0,25 m) che si aprono dietro la pinna (verso -Z), col verso
## della striscia in UV.x (0 alla pinna, 1 in fondo).
static func _mesh_scia() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for lato in [-1.0, 1.0]:
		var n := 12
		for i in n:
			var a := float(i) / n
			var b := float(i + 1) / n
			var pa := Vector3(lato * (0.05 + a * 1.3), 0.0, -a * 3.5 + 0.2)
			var pb := Vector3(lato * (0.05 + b * 1.3), 0.0, -b * 3.5 + 0.2)
			var w := Vector3(lato * 0.12, 0.0, 0.03)
			var quad := [[pa - w, Vector2(a, 0.0)], [pa + w, Vector2(a, 1.0)], [pb + w, Vector2(b, 1.0)],
				[pa - w, Vector2(a, 0.0)], [pb + w, Vector2(b, 1.0)], [pb - w, Vector2(b, 0.0)]]
			for v in quad:
				st.set_normal(Vector3.UP)
				st.set_uv(v[1])
				st.add_vertex(v[0])
	return st.commit()


func _anima(nome: StringName, fondi := 0.15) -> void:
	if _anim and _anim.has_animation(nome):
		_anim.play(nome, fondi)


func _nascondi() -> void:
	stato = Stato.ASSENTE
	if squalo:
		squalo.visible = false
	if _scia:
		_scia.visible = false
	if _muso:
		_muso.monitorable = false


## Per il riscaldamento degli shader (RiscaldamentoShader.disegna_fuori_vista intorno al fiume): con [param acceso]
## lo mette visibile, a bocca aperta (fiume_attacco), con la scia, davanti a [param dove]; con falso lo nasconde.
## Non fa niente se sta già seguendo.
func posa_per_il_riscaldamento(acceso: bool, dove := Vector3.ZERO) -> void:
	if stato != Stato.ASSENTE:
		return
	squalo.visible = acceso
	_scia.visible = acceso
	if acceso:
		squalo.global_position = dove
		_scia.global_position = dove + Vector3.UP * 0.01
		_anima(ANIM_ATTACCO, 0.0)
