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
## Livello di render solo dello squalo: la luce della corsa illumina lui e nient'altro (né il corridoio né
## la nebbia).
const STRATO_SQUALO := 1 << 16
## La camera non entra mai nello squalo: resta almeno a tanto dalla sua superficie (i vertici della mesh
## deformati dallo scheletro, presi uno ogni CELLA di spazio nella posa di riposo).
const DISTANZA_PELLE := 0.24
const CELLA := 0.08

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
var _passo_t := -1.0        # quando ha toccato terra l'ultimo passo (per la scossa della camera)
var _passo_forza := 0.0     # quanto forte la scossa di quel passo (0-1)
var _passo_lato := 1.0      # da che parte rolla la camera (si alterna a ogni passo)
var _tetti: Array = []      # [player 3D, il suo max_db di prima, quando rimetterlo]
var _fine := 0.0
var _luce_corsa: OmniLight3D
var _torcia_accesa = null    # com'era la torcia prima della scena (null: niente torcia)
var _pelle: Array = []       # [posizione a riposo, PackedInt32Array ossa della skin, PackedFloat32Array pesi]
var _pelle_mi: MeshInstance3D
var _pelle_bind: Array = []  # per ogni bind della skin: [osso dello scheletro, matrice di bind]
var _spinta := Vector3.ZERO  # di quanto la camera è spostata fuori dalla pelle (nello spazio del mondo)


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
	# il tasto F non la tocca durante la scena (Torcia guarda input_enabled); alla fine torna com'era
	var torcia := _torcia()
	_torcia_accesa = torcia.accesa if torcia else null
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
	for nome in ["bocca", "mento_punta", "testa", "spina", "radice", "collo", "petto", "mano.L", "mano.R", "coda2"]:
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
	# nella corsa il corridoio è buio e la nebbia rossa se lo mangia: una luce morbida, solo per lui, lo
	# tiene leggibile fino alla porta (il corridoio resta com'è)
	for vi in squalo.find_children("*", "VisualInstance3D", true, false):
		(vi as VisualInstance3D).layers |= STRATO_SQUALO
	_luce_corsa = OmniLight3D.new()
	_luce_corsa.name = "LuceCorsa"
	_luce_corsa.light_cull_mask = STRATO_SQUALO
	_luce_corsa.light_color = Color(1.0, 0.45, 0.32)
	_luce_corsa.light_energy = 0.0
	_luce_corsa.omni_range = 3.2
	_luce_corsa.omni_attenuation = 1.4
	_luce_corsa.shadow_enabled = false
	_luce_corsa.light_volumetric_fog_energy = 0.0
	_luce_corsa.light_specular = 0.3
	squalo.add_child(_luce_corsa)
	if _anim:
		# l'animazione avanza qui, prima della camera: la camera la sposta fuori dalla posa di questo fotogramma
		_anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		_anim.play(_anim.get_animation_list()[0] if not _anim.has_animation("risveglio") else "risveglio")
		_anim.seek(0.0, true)
	_prepara_pelle()


## I punti della pelle per tenere fuori la camera: un vertice per ogni cella di CELLA metri.
func _prepara_pelle() -> void:
	_pelle.clear()
	_pelle_bind.clear()
	_spinta = Vector3.ZERO
	for n in squalo.find_children("*", "MeshInstance3D", true, false):
		if (n as MeshInstance3D).skin:
			_pelle_mi = n as MeshInstance3D
	if _pelle_mi == null or _scheletro == null:
		return
	var skin := _pelle_mi.skin
	for i in skin.get_bind_count():
		var osso := skin.get_bind_bone(i)
		if osso < 0:
			osso = _scheletro.find_bone(skin.get_bind_name(i))
		_pelle_bind.append([osso, skin.get_bind_pose(i)])
	var visti := {}
	var m := _pelle_mi.mesh
	for sup in m.get_surface_count():
		var a := m.surface_get_arrays(sup)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var b: PackedInt32Array = a[Mesh.ARRAY_BONES]
		var w: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
		var k := b.size() / maxi(v.size(), 1)
		for i in v.size():
			var c := Vector3i((v[i] / CELLA).floor())
			if visti.has(c):
				continue
			visti[c] = true
			_pelle.append([v[i], b.slice(i * k, i * k + k), w.slice(i * k, i * k + k)])


## Quanto spostare la camera (nel mondo) perché stia almeno a DISTANZA_PELLE dalla pelle dello squalo: indietro,
## via da lui (in orizzontale, dal suo corpo verso la camera), del minimo che basta.
func _fuori_dalla_pelle(occhio: Vector3) -> Vector3:
	var punti := _pelle_vicina(occhio)
	if punti.is_empty():
		return Vector3.ZERO
	var via := occhio - _bone_mondo("spina")
	via.y = 0.0
	via = via.normalized() if via.length() > 0.01 else _p.global_basis.z
	var d2 := DISTANZA_PELLE * DISTANZA_PELLE
	var t := 0.0
	while t <= 1.2:
		var q := occhio + via * t
		var libera := true
		for pt in punti:
			if q.distance_squared_to(pt) < d2:
				libera = false
				break
		if libera:
			return via * t
		t += 0.02
	return via * 1.2


## I punti della pelle (deformati) che possono stare vicino alla camera: quelli delle ossa entro 1,5 m, e di
## questi quelli entro 1,5 m dalla camera.
func _pelle_vicina(occhio: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	if _pelle.is_empty() or squalo == null or not squalo.visible:
		return out
	var pose: Array = []
	var vicino: Array = []
	for bd in _pelle_bind:
		var gp := _scheletro.global_transform * _scheletro.get_bone_global_pose(int(bd[0]))
		pose.append(gp * (bd[1] as Transform3D))
		vicino.append(gp.origin.distance_squared_to(occhio) < 2.25)
	for pv in _pelle:
		var ossa: PackedInt32Array = pv[1]
		var pesi: PackedFloat32Array = pv[2]
		var serve := false
		for j in ossa.size():
			if pesi[j] > 0.0 and vicino[ossa[j]]:
				serve = true
		if not serve:
			continue
		var q := Vector3.ZERO
		var tot := 0.0
		for j in ossa.size():
			if pesi[j] > 0.0:
				q += (pose[ossa[j]] as Transform3D) * (pv[0] as Vector3) * pesi[j]
				tot += pesi[j]
		if tot > 0.0:
			q /= tot
			if q.distance_squared_to(occhio) < 2.25:
				out.append(q)
	return out


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
	if _anim and _anim.is_playing():
		_anim.advance(delta)
	var M: float = tempi.get("minaccia", 2.4)
	var R: float = tempi.get("richiamo", 5.4)
	var G: float = tempi.get("giro", 5.85)
	var E: float = tempi.get("esita", 6.75)
	var porta_t: float = tempi.get("porta", 10.15)
	_suoni_e_porta(R, E, porta_t)
	_rimetti_tetti(false)
	_aggiorna_luce_corsa(E, porta_t)
	_camera(M, R, G, E, porta_t, delta)
	if _t >= _fine:
		_termina()


func _suona(chiave: String, nome: StringName, dove: Variant, tono := 1.0, volume := 0.0) -> void:
	if _suoni.has(chiave):
		return
	_suoni[chiave] = true
	var a := get_node_or_null(^"/root/Audio")
	if a:
		var piu := float(PIU_FORTE.get(nome, 0.0))
		var p = a.call(&"suona", nome, dove, volume + piu, tono)
		# i suoni nello spazio hanno un tetto (max_db 0): vicino a lui il guadagno in più si perderebbe. Il tetto
		# si alza solo per questo suono e torna com'era quando finisce (i player sono di tutti)
		if p is AudioStreamPlayer3D and piu > 0.0:
			var p3 := p as AudioStreamPlayer3D
			_tetti.append([p3, p3.max_db, _t + (p3.stream.get_length() if p3.stream else 2.0) + 0.1])
			p3.max_db = piu


## Quanto più forti dei loro file suonano qui (dB): è il primo spavento del gioco (riscontro dell'utente sulla
## v0.3.8, "aggiungiamo anche i suoni": prima la scena stava circa 7 dB sotto l'urlo di lei).
## Dal 23 ottobre la minaccia e il ringhio sono quelli nuovi (B, "coccodrillo") e restano bassi, senza guadagno in
## più: l'utente, "ma tienila bassa".
const PIU_FORTE := {&"squalo_minaccia": 0.0, &"jilly_richiamo": 3.0, &"squalo_sbuffo": 6.0, &"squalo_passo": 5.0,
	&"squalo_denti": 5.0, &"squalo_ringhio": 0.0}


func _suoni_e_porta(R: float, E: float, porta_t: float) -> void:
	var M: float = tempi.get("minaccia", 2.4)
	var G: float = tempi.get("giro", 5.85)
	if _t > 0.8:
		_suona("minaccia", &"squalo_minaccia", _nodo_bocca())
	# i denti che scattano a ogni morso nell'aria (gli scatti della testa: mostro_anim.posa, MINACCIA + 0,7,
	# 1,6 e 2,5 s; le fauci si chiudono appena dopo il picco)
	for k in 3:
		if _t > M + [0.7, 1.6, 2.5][k] + 0.08:
			_suona("denti%d" % k, &"squalo_denti", _nodo_bocca())
	if _t > R:
		_suona("richiamo", &"jilly_richiamo", to_global(Vector3(0, 1.3, -8.5)))
	# il ringhio quando si gira verso la porta
	if _t > G - 0.1:
		_suona("ringhio", &"squalo_ringhio", _nodo_bocca())
	if _t > float(tempi.get("sbuffo", E + 1.0)) - 0.07:
		_suona("sbuffo", &"squalo_sbuffo", _nodo_bocca())
	var passi: Array = tempi.get("passi", [])
	while _passi_fatti < passi.size() and _t >= float(passi[_passi_fatti]):
		_suona("passo%d" % _passi_fatti, &"squalo_passo", _bone_mondo("radice"))
		_passo_della_camera()
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


## Ogni passo dal giro alla porta scuote la camera, insieme al suono: forte vicino (e nel giro, addosso al
## giocatore), sempre più debole mentre si allontana (richiesta dell'utente del 22 ottobre: "un bel tremolio della
## camera in corrispondenza dei suoi passi").
func _passo_della_camera() -> void:
	if _p == null:
		return
	var d := _p.camera.global_position.distance_to(_bone_mondo("radice"))
	_passo_forza = clampf(1.8 / maxf(d, 0.1), 0.0, 1.0)
	_passo_forza *= _passo_forza * 0.5 + 0.5     # cala più in fretta lontano
	_passo_t = _t
	_passo_lato = -_passo_lato


## La scossa del passo adesso: [scesa della camera (m), beccheggio (radianti), rollio (radianti)]. Breve e
## marcata: giù di colpo in 35 ms, poi torna su smorzata in 0,2 s con un piccolo rimbalzo.
func _scossa_passo() -> Vector3:
	if _passo_t < 0.0:
		return Vector3.ZERO
	var x := _t - _passo_t
	if x > 0.35:
		return Vector3.ZERO
	var botta := x / 0.035 if x < 0.035 else exp(-(x - 0.035) / 0.07) * cos((x - 0.035) * 28.0)
	var f := _passo_forza * botta
	return Vector3(0.045 * f, deg_to_rad(1.6) * f, deg_to_rad(1.1) * f * _passo_lato)


## La luce della corsa: dietro e sopra di lui, dalla parte del giocatore; si accende quando si gira verso la
## porta e si spegne mentre ci passa.
func _aggiorna_luce_corsa(E: float, porta_t: float) -> void:
	if _luce_corsa == null or not is_instance_valid(_luce_corsa):
		return
	var schiena := _bone_mondo("spina")
	var verso_giocatore := (_p.global_position - schiena) * Vector3(1, 0, 1)
	verso_giocatore = verso_giocatore.normalized() if verso_giocatore.length() > 0.01 else Vector3.ZERO
	_luce_corsa.global_position = schiena + Vector3.UP * 0.9 + verso_giocatore * 1.1
	_luce_corsa.light_energy = 1.6 * (_liscio(0.0, 1.0, E, E + 0.8) - _liscio(0.0, 1.0, porta_t - 0.1, porta_t + 0.5))


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
	var occhio0 := occhio_base + Vector3.UP * (h - _p.stand_eye_height)
	var su := occhio_base + Vector3.UP * 3.0 + _p.global_basis.z * -0.3
	# dal soffitto alla bocca girando la testa (direzioni, non punti: se no resta al soffitto fino all'ultimo)
	var d_su := (su - occhio0).normalized()
	var d_bocca := (bocca - occhio0).normalized()
	var obiettivo := occhio0 + d_su.slerp(d_bocca, _liscio(0.0, 1.0, 0.95, 2.15)) * occhio0.distance_to(bocca)
	var corpo := _bone_mondo("spina").lerp(_bone_mondo("testa"), 0.5)
	var segui := _liscio(0.0, 1.0, R + 0.15, R + 0.9) - _liscio(0.0, 1.0, porta_t + 0.6, porta_t + 2.2)
	obiettivo = obiettivo.lerp(corpo, clampf(segui, 0.0, 1.0))
	var avanti := occhio_base + (_dir_yaw(_yaw0)) * 4.0
	obiettivo = obiettivo.lerp(avanti, _liscio(0.0, 1.0, porta_t + 0.6, porta_t + 2.2))
	# lo sguardo insegue il bersaglio con un po' di ritardo (più svelto quando si spaventa)
	var rapido := 9.0 if _t < R + 0.6 else 5.0
	_sguardo = _sguardo.lerp(obiettivo, 1.0 - exp(-rapido * delta)) if delta > 0.0 else obiettivo
	var occhio := occhio_base + Vector3.UP * (h - _p.stand_eye_height)
	# si ritrae: dalla bocca sotto i 40 cm, e dal corpo che si gira e dalle mani sotto i 55 cm
	var dist := occhio.distance_to(bocca)
	var indietro := clampf(0.40 - dist, 0.0, 0.25) * 1.3 * (1.0 - _liscio(0.0, 1.0, R, R + 0.6))
	# mentre si rialza la faccia non deve passare dentro il mento o il muso
	for osso in ["mento_punta", "bocca"]:
		indietro = maxf(indietro, clampf(0.42 - occhio.distance_to(_bone_mondo(osso)), 0.0, 0.3) * 1.2)
	if _t > R:
		for osso in ["testa", "collo", "petto", "mano.L", "mano.R", "coda2"]:
			indietro = maxf(indietro, clampf(0.55 - occhio.distance_to(_bone_mondo(osso)), 0.0, 0.3))
	# tremore: forte nella minaccia, poi meno; sobbalzo al richiamo e alla porta
	if _t > R and _t < R + 0.1:
		_scossa = maxf(_scossa, 0.7)
	_scossa = maxf(0.0, _scossa - delta * 2.5)
	var paura := 1.0 if _t < R else lerpf(1.0, 0.45, _liscio(0.0, 1.0, R, porta_t))
	paura *= 1.0 - _liscio(0.0, 1.0, alzati, alzati + 1.4) * 0.8
	var tr := Vector3(_rumore(_t, 7.0, 1.0), _rumore(_t, 6.0, 2.0), _rumore(_t, 5.0, 3.0)) * 0.012 * paura
	tr += Vector3(_rumore(_t, 21.0, 4.0), _rumore(_t, 19.0, 5.0), 0.0) * 0.03 * _scossa
	var sp := _scossa_passo()
	var d := _sguardo - occhio
	var yaw := atan2(-d.x, -d.z) + tr.x
	var pitch := atan2(d.y, Vector2(d.x, d.z).length()) + tr.y - sp.y
	_p.set_look(yaw, pitch)
	# la testa sdraiata è girata su un fianco e si raddrizza mentre si rialza
	cam.rotation.z = deg_to_rad(_liscio(70.0, 0.0, 1.1, 2.4)) + tr.z + sp.z
	# (la scossa del passo prima della distanza dalla pelle: anche scossa resta fuori da lui)
	cam.position = Vector3(0.0, h - _p.stand_eye_height - indietro * 0.3 - sp.x, indietro)
	# mai dentro lo squalo: fuori dalla sua pelle (la spinta sale subito e cala piano, senza scatti)
	# la testa del giocatore subito con lo sguardo di adesso (lo rifà lui dopo, uguale): così la posizione
	# della camera nel mondo è già quella che si vedrà
	_p.call(&"_update_head", Engine.get_physics_interpolation_fraction())
	var base := cam.global_position
	var serve := _fuori_dalla_pelle(base)
	if serve.length() >= _spinta.length():
		_spinta = serve
	else:
		_spinta = _spinta.lerp(serve, 1.0 - exp(-6.0 * delta)) if delta > 0.0 else serve
		_spinta += _fuori_dalla_pelle(base + _spinta)
	cam.global_position = base + _spinta


func _rimetti_tetti(tutti: bool) -> void:
	for i in range(_tetti.size() - 1, -1, -1):
		var tt: Array = _tetti[i]
		if tutti or _t >= float(tt[2]):
			if is_instance_valid(tt[0]):
				(tt[0] as AudioStreamPlayer3D).max_db = float(tt[1])
			_tetti.remove_at(i)


func _termina() -> void:
	_rimetti_tetti(true)
	_attivo = false
	set_process(false)
	var cam := _p.camera
	cam.position = Vector3.ZERO
	cam.rotation = Vector3.ZERO
	_p.set_look(_p.yaw, 0.0)
	_p.input_enabled = true
	var torcia := _torcia()
	if torcia and _torcia_accesa != null:
		torcia.imposta_accesa(_torcia_accesa)
	if squalo:
		squalo.queue_free()
		squalo = null
	if _perno:
		_perno.rotation.y = 0.0
	finito.emit()


func _torcia() -> Torcia:
	for t in _p.find_children("*", "Node3D", true, false):
		if t is Torcia:
			return t as Torcia
	return null


func _dir_yaw(y: float) -> Vector3:
	return Vector3(-sin(y), 0.0, -cos(y))


func _liscio(a: float, b: float, t0: float, t1: float) -> float:
	var x := clampf((_t - t0) / (t1 - t0), 0.0, 1.0)
	return lerpf(a, b, x * x * (3.0 - 2.0 * x))


func _rumore(t: float, f: float, seme: float) -> float:
	return sin(t * f * 6.283 + seme) * 0.5 + sin(t * f * 2.71 * 6.283 + seme * 1.7) * 0.3 \
		+ sin(t * f * 5.13 * 6.283 + seme * 2.3) * 0.2
