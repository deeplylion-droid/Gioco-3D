class_name RisveglioSqualo
extends Node3D
## L'inizio con il mostro-squalo (GDD, "L'inizio con il mostro-squalo", scelte dell'utente del 21
## ottobre). Il giocatore si sveglia per terra nel corridoio del ponte inferiore e lo squalo A gli è
## addosso, chino, con la bocca spalancata a pochi centimetri dalla faccia. Dalla porta tagliafuoco in
## fondo al corridoio arriva il verso lontano e profondo di Jilly che lo chiama: lui si gira, esita
## (si volta a guardarti), poi corre verso la porta, ci passa abbassandosi, e la porta gli sbatte dietro e
## resta chiusa. Poi il giocatore si rialza e riprende il controllo.
##
## Dalla 0.3.23 (le tre proposte per far più paura, sì dell'utente: GDD 29f78c94; tempi in mostro_anim.py) prima c'è
## il buio: il corridoio è spento, si sentono il fiato e le gocce di bava, e la luce sfarfalla tre volte (i lampi): a
## ogni lampo lui è più vicino; poi la luce resta accesa e lui è chino sul giocatore, la bocca chiusa, e lo annusa (il
## muso che passa dalla sua sinistra alla sua destra e sale verso la faccia, il fiuto); una goccia di bava gli cade
## sulla faccia (sullo schermo, [constant SHADER_GOCCIA]); poi la bocca si spalanca, e i morsi non sono più a tempo:
## due svelti, una pausa a bocca spalancata e ferma, e uno scatto fin quasi alla faccia con la bocca chiusa 0,3 s e un
## colpo più secco e basso.
##
## La camera è guidata e si muove come la testa di chi è terrorizzato: si rialza da terra, si ritrae
## dalla bocca quando la testa scatta in avanti, segue lo squalo che si gira e scappa. Dalla 0.3.22 non trema più
## (né il tremore della paura, né le scosse dei passi e della porta: riscontro dell'utente sulla 0.3.21, "togliamo il
## tremore della camera che non fa nessun effetto") e sta [constant ARRETRA] m più indietro. Il nodo sta dove parte lo squalo e guarda verso il giocatore (asse +Z locale): la porta è
## dietro di lui, verso -Z. Lo squalo e i tempi vengono da assets_src/mascotte/mostro_rig.py
## (mostro_squalo_A_rig.glb e .json): l'animazione "risveglio" contiene già la corsa.

signal finito

const MODELLO := "res://assets/models/mascotte/mostro_squalo_A_rig.glb"
const TEMPI := "res://assets/models/mascotte/mostro_squalo_A_rig.json"
const SHADER_BOCCA := preload("res://shaders/creature/bocca_squalo.gdshader")
## I denti in più (file di squalo dietro quelli del modello): avorio sporco, le file dentro in ombra.
const SHADER_DENTI := preload("res://shaders/creature/denti_squalo.gdshader")
## La goccia di bava sullo schermo (dalla 0.3.23).
const SHADER_GOCCIA := preload("res://shaders/creature/goccia_schermo.gdshader")
## Dove stanno le luci del corridoio che si spengono nel buio (spazio di questo nodo: x di lato, z verso il giocatore;
## la porta è verso -z): dalla porta a 6 m dietro il giocatore, dove la lampada 02 illumina ancora.
const CORRIDOIO := AABB(Vector3(-1.8, -0.5, -7.2), Vector3(3.6, 4.0, 13.4))
## Fotogrammi in cui la goccia si disegna (trasparente) col livello: shader e pipeline pronti prima della scena.
const FOTOGRAMMI_GOCCIA := 10
## Livello di render solo dello squalo: la luce della corsa illumina lui e nient'altro (né il corridoio né
## la nebbia).
const STRATO_SQUALO := 1 << 16
## La camera non entra mai nello squalo: resta almeno a tanto dalla sua superficie (i vertici della mesh
## deformati dallo scheletro, presi uno ogni CELLA di spazio nella posa di riposo). La spinta cerca 1 cm in più
## ([constant MARGINE_PELLE]): il controllo in test_interni vuole almeno DISTANZA_PELLE in ogni fotogramma.
const DISTANZA_PELLE := 0.24
const MARGINE_PELLE := 0.01
## La spinta è continua (collaudo di grafica-2 su 86ab11f9: saliva di mezzo metro in un fotogramma): la camera comincia
## ad allontanarsi già a [constant PELLE_MORBIDA] m in più della distanza minima, a non più di [constant VEL_SPINTA] m/s;
## la distanza minima resta comunque garantita.
const PELLE_MORBIDA := 0.15
## Dalla bocca che si apre il margine morbido è più stretto: la bocca spalancata deve arrivare addosso alla camera.
const PELLE_MORBIDA_MINACCIA := 0.04
const VEL_SPINTA := 2.0
const CELLA := 0.08

## La porta tagliafuoco (il nodo del modello del corridoio) e il suo cardine, nello spazio degli interni.
@export var porta: Node3D
@export var cardine := Vector3(21.965, 0.0, -0.72)
## Di quanto è aperta all'inizio (verso il corridoio).
@export var apertura_porta := 120.0
## Di quanto la camera sta più indietro, in orizzontale, via dallo squalo (dalla direzione in cui guarda all'inizio),
## per tutta la scena; torna a 0 mentre ci si alza in piedi (riscontro dell'utente sulla 0.3.21: "arretriamo
## leggermente la camera, pochissimo").
const ARRETRA := 0.10
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
var _tetti: Array = []      # [player 3D, il suo max_db di prima, quando rimetterlo]
var _fine := 0.0
var _luce_corsa: OmniLight3D
var _pelle: Array = []       # [posizione a riposo, PackedInt32Array ossa della skin, PackedFloat32Array pesi]
var _pelle_mi: MeshInstance3D
var _pelle_bind: Array = []  # per ogni bind della skin: [osso dello scheletro, matrice di bind]
var _spinta := Vector3.ZERO  # di quanto la camera è spostata fuori dalla pelle (nello spazio del mondo)
var _lampade: Array = []     # le LuceEmergenza del corridoio (si spengono nel buio)
var _vetri: Array = []       # [vetro della lampada, il suo materiale acceso, la sua emissione]
var _luce := 1.0             # quanto è accesa la luce del corridoio adesso (0 nel buio, 1 nei lampi e dopo)
var _luce_lampo: OmniLight3D  # nei lampi: la lampada più vicina che illumina lui (solo lui)
var _goccia_strato: CanvasLayer
var _goccia: ColorRect


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
	# la luce viola di Jilly dietro la porta e la nebbia del corridoio (grafica: atmosfera_squalo.gd)
	var atmosfera := AtmosferaSqualo.new()
	atmosfera.name = "Atmosfera"
	add_child(atmosfera)
	_crea_goccia()


## La scena parte solo a schermo chiaro (passaggio finale di ambienti-2 su b18a9003: al primo avvio la prova della
## qualità teneva lo schermo nero mentre la scena era già partita, e i primi due lampi cadevano nel nero; anche negli
## avvii normali la sala entra con la dissolvenza di 1,6 s): finché c'è il velo nero della dissolvenza, anche solo un
## poco, o la prova della qualità, il giocatore resta sdraiato al buio come all'inizio della scena, senza tempo che
## passa e senza suoni. Dopo [constant ATTESA_MASSIMA] s parte comunque.
const ATTESA_MASSIMA := 30.0
## Solo per i test: la scena parte anche nelle prove automatiche (Interni.fai_risveglio).
static var forza_nei_test := false
var _in_attesa := false
var _attesa := 0.0


## Lo schermo è chiaro: niente velo della dissolvenza e niente prova della qualità.
static func schermo_pronto(albero: SceneTree) -> bool:
	return Dissolvenza.schermo_libero(albero) and not QualitaAutomatica.in_corso(albero)


## Vero mentre la scena aspetta lo schermo chiaro (è avviata ma il suo tempo non è ancora partito).
func in_attesa() -> bool:
	return _attivo and _in_attesa


## La scena del risveglio: blocca il giocatore e parte (appena lo schermo è chiaro).
func avvia(p: Player) -> void:
	_p = p
	_p.input_enabled = false
	_yaw0 = p.yaw
	_crea_squalo()
	_apri_porta()
	_prendi_luci()
	_t = 0.0
	_passi_fatti = 0
	_attivo = true
	_attesa = 0.0
	_in_attesa = not schermo_pronto(get_tree())
	_sguardo = _punto_bocca()
	set_process(true)
	_process(0.0)


func in_corso() -> bool:
	return _attivo


const BAVA := preload("res://scripts/interni/bava_squalo.gd")
var _bava: Node


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
	# la bava: fili tra le labbra e gocce dal mento (si spegne quando si gira)
	if _scheletro:
		_bava = BAVA.new()
		_bava.name = "Bava"
		squalo.add_child(_bava)
		_bava.prepara(_scheletro)
	# nella corsa il corridoio è buio e la nebbia rossa se lo mangia: una luce morbida, solo per lui, lo
	# tiene leggibile fino alla porta (il corridoio resta com'è)
	for vi in squalo.find_children("*", "VisualInstance3D", true, false):
		Strati.metti(vi as VisualInstance3D, (vi as VisualInstance3D).layers | STRATO_SQUALO)
	_luce_corsa = OmniLight3D.new()
	_luce_corsa.name = "LuceCorsa"
	Strati.maschera_luce(_luce_corsa, STRATO_SQUALO)
	_luce_corsa.light_color = Color(1.0, 0.45, 0.32)
	_luce_corsa.light_energy = 0.0
	_luce_corsa.omni_range = 3.2
	_luce_corsa.omni_attenuation = 1.4
	_luce_corsa.shadow_enabled = false
	_luce_corsa.light_volumetric_fog_energy = 0.0
	_luce_corsa.light_specular = 0.3
	squalo.add_child(_luce_corsa)
	# (0.3.23) nei lampi la lampada del corridoio più vicina illumina anche lui: senza, nel primo lampo (a 2,8 m) era
	# una sagoma nera sul viola, luminosità media 2,5 su 255 (collaudo di grafica-2 su 86ab11f9)
	_luce_lampo = OmniLight3D.new()
	_luce_lampo.name = "LuceLampo"
	Strati.maschera_luce(_luce_lampo, STRATO_SQUALO)
	_luce_lampo.light_color = Color(1.0, 0.32, 0.22)
	_luce_lampo.light_energy = 0.0
	_luce_lampo.omni_range = 5.5
	_luce_lampo.omni_attenuation = 1.0
	_luce_lampo.shadow_enabled = false
	_luce_lampo.light_volumetric_fog_energy = 0.0
	_luce_lampo.light_specular = 0.6
	squalo.add_child(_luce_lampo)
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
func _fuori_dalla_pelle(occhio: Vector3, distanza := DISTANZA_PELLE + MARGINE_PELLE) -> Vector3:
	var punti := _pelle_vicina(occhio)
	if punti.is_empty():
		return Vector3.ZERO
	var via := occhio - _bone_mondo("spina")
	via.y = 0.0
	via = via.normalized() if via.length() > 0.01 else _p.global_basis.z
	var d2 := distanza * distanza
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
	var M: float = tempi.get("minaccia", 2.4)
	var R: float = tempi.get("richiamo", 5.4)
	var G: float = tempi.get("giro", 5.85)
	var E: float = tempi.get("esita", 6.75)
	var porta_t: float = tempi.get("porta", 10.15)
	if _in_attesa:
		_attesa += delta
		if schermo_pronto(get_tree()) or _attesa >= ATTESA_MASSIMA:
			_in_attesa = false
		else:
			# fermo all'inizio della scena: al buio, sdraiato, lui in fondo al corridoio; niente tempo, niente suoni
			_luci_del_buio()
			_muovi_goccia()
			_camera(M, R, G, E, porta_t, 0.0)
			return
	_t += delta
	if _anim and _anim.is_playing():
		_anim.advance(delta)
	_suoni_e_porta(R, E, porta_t)
	_luci_del_buio()
	_muovi_goccia()
	if _bava:
		_bava.set(&"attivo", _t < G)
	_rimetti_tetti(false)
	# la luce morbida su di lui da quando arretra (giro C, 23 ottobre: se no arretra e si gira nel buio)
	_aggiorna_luce_corsa(float(tempi.get("arretra", E)), porta_t)
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
const PIU_FORTE := {&"squalo_annusa": 3.0, &"squalo_minaccia": 0.0, &"jilly_richiamo": 3.0, &"squalo_sbuffo": 6.0, &"squalo_passo": 5.0,
	&"squalo_denti": 5.0, &"squalo_ringhio": 0.0}


func _suoni_e_porta(R: float, E: float, porta_t: float) -> void:
	var G: float = tempi.get("giro", 5.85)
	# (0.3.23) nel buio e annusando: il fiato, le gocce, il fiuto (attaccati alla bocca: da lontano, poi addosso)
	_suona("annusa", &"squalo_annusa", _nodo_bocca())
	# la luce che sfarfalla: lo scatto del relè della lampada più vicina a lui, a ogni lampo e quando resta accesa
	var lampi: Array = tempi.get("lampi", [])
	for k in lampi.size():
		if _t > float(lampi[k][0]):
			_suona("lampo%d" % k, &"neon_clic", _lampada_vicina(), 1.0, -4.0)
	if _t > float(tempi.get("luce", 0.0)):
		_suona("luce", &"neon_clic", _lampada_vicina(), 0.9, -2.0)
	# la goccia di bava che cade sulla faccia
	if _t > float(tempi.get("goccia", INF)):
		_suona("goccia", &"goccia_acqua", _p.camera, 0.8, 2.0)
	if _t > float(tempi.get("suono_minaccia", 0.8)):
		_suona("minaccia", &"squalo_minaccia", _nodo_bocca())
	# i denti che scattano a ogni morso (gli scatti della testa: mostro_anim.MORSI; le fauci si chiudono appena dopo
	# il picco). L'ultimo, dopo la pausa: un colpo più secco e più basso
	var morsi: Array = tempi.get("morsi", [])
	for k in morsi.size():
		if _t > float(morsi[k][0]) + 0.08:
			var ultimo := k == morsi.size() - 1
			_suona("denti%d" % k, &"squalo_denti", _nodo_bocca(), 0.72 if ultimo else 1.0, 4.0 if ultimo else 0.0)
	if _t > R:
		_suona("richiamo", &"jilly_richiamo", to_global(Vector3(0, 1.3, -8.5)))
	# il ringhio quando comincia ad arretrare guardandoti (prima del 23 ottobre: quando si girava)
	if _t > float(tempi.get("ringhio", G)) - 0.1:
		_suona("ringhio", &"squalo_ringhio", _nodo_bocca())
	if _t > float(tempi.get("sbuffo", E + 1.0)) - 0.07:
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
			_suona("porta", &"porta_chiusa", _perno.global_position + Vector3.UP * 1.2, 0.72, 4.0)
	if squalo and _t > porta_t + 0.62:
		squalo.visible = false
		if _anim:
			_anim.pause()


## Le luci del corridoio (dalla 0.3.23): le LuceEmergenza e i vetri delle loro lampade dentro [constant CORRIDOIO].
## I vetri prendono un loro materiale (lo stesso shader: niente pipeline nuove) per spegnersi senza toccare quelli delle
## altre stanze.
func _prendi_luci() -> void:
	_rimetti_luci()
	var interni := get_parent().get_parent() if get_parent() else null
	if interni == null:
		return
	for n in interni.find_children("*", "Node3D", true, false):
		if n is LuceEmergenza and CORRIDOIO.has_point(to_local((n as Node3D).global_position)):
			_lampade.append(n)
	for n in interni.find_children("*_vetro", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if not CORRIDOIO.has_point(to_local(mi.global_position)):
			continue
		var mat := mi.get_active_material(0) as BaseMaterial3D
		if mat == null or not mat.emission_enabled:
			continue
		var copia := mat.duplicate() as BaseMaterial3D
		_vetri.append([mi, copia, mat.emission_energy_multiplier])
		mi.material_override = copia


func _rimetti_luci() -> void:
	for le in _lampade:
		if is_instance_valid(le):
			le.set(&"fattore", 1.0)
	for v in _vetri:
		if is_instance_valid(v[0]):
			(v[0] as MeshInstance3D).material_override = null
	_lampade.clear()
	_vetri.clear()
	_luce = 1.0


## Quanto è accesa la luce del corridoio all'istante [param t] (0-1): quasi spenta nel buio, accesa nei lampi (che
## sfarfallano: accesa, un attimo spenta, di nuovo accesa) e da LUCE in poi (sfarfalla anche lì, poi resta accesa).
func luce_al(t: float) -> float:
	var luce: float = tempi.get("luce", 0.0)
	if t >= luce:
		var x := t - luce
		return 0.0 if (x > 0.06 and x < 0.14) else 1.0
	for l in tempi.get("lampi", []):
		var x := t - float(l[0])
		if x >= 0.0 and x < float(l[1]):
			return BUIO if (x > 0.05 and x < 0.08) else 1.0
	return BUIO


## Quanto resta della luce nel buio: un filo (le sagome si intuiscono appena, la nebbia è nera).
const BUIO := 0.03


## La luce di adesso (per l'atmosfera viola: si spegne e si accende con il corridoio).
func luce_scena() -> float:
	return _luce if _attivo else 1.0


## Quanto è forte la luce su di lui in ogni lampo (dall'alto, dalla parte del giocatore): più lontano, più forte.
const LAMPO_SU_DI_LUI := [7.0, 3.0, 1.6]


func _luci_del_buio() -> void:
	_luce = luce_al(_t)
	if _luce_lampo and is_instance_valid(_luce_lampo):
		var e := 0.0
		var lampi: Array = tempi.get("lampi", [])
		if _t < float(tempi.get("luce", 0.0)) and _luce > 0.5:
			for k in lampi.size():
				if _t >= float(lampi[k][0]) and _t < float(lampi[k][0]) + float(lampi[k][1]):
					e = float(LAMPO_SU_DI_LUI[mini(k, LAMPO_SU_DI_LUI.size() - 1)])
		_luce_lampo.light_energy = e
		if e > 0.0 and _p:
			# dalla parte della camera, in alto (come la lampada sopra il giocatore): lo illumina davanti, la testa e il
			# corpo; dalla lampada più vicina a lui gli illuminava la schiena
			var testa := _bone_mondo("testa")
			var verso := (_p.camera.global_position - testa) * Vector3(1, 0, 1)
			verso = verso.normalized() if verso.length() > 0.01 else Vector3.ZERO
			_luce_lampo.global_position = Vector3(testa.x, 0.0, testa.z) + verso * 1.3 + Vector3.UP * 2.3
	for le in _lampade:
		if is_instance_valid(le):
			le.set(&"fattore", _luce)
	for v in _vetri:
		(v[1] as BaseMaterial3D).emission_energy_multiplier = float(v[2]) * _luce


## La lampada del corridoio più vicina allo squalo (per lo scatto del relè quando la luce sfarfalla).
func _lampada_vicina() -> Vector3:
	var radice := _bone_mondo("radice")
	var meglio: Node3D = null
	for le in _lampade:
		if not is_instance_valid(le):
			continue
		var n := le as Node3D
		if meglio == null or n.global_position.distance_to(radice) < meglio.global_position.distance_to(radice):
			meglio = n
	return meglio.global_position if meglio else to_global(Vector3(0.0, 2.4, -1.5))


## La goccia di bava sullo schermo (dalla 0.3.23): uno strato sopra la scena, col suo shader; nasce col livello e si
## disegna trasparente per [constant FOTOGRAMMI_GOCCIA] fotogrammi (shader, copia dello schermo e pipeline pronti
## prima della scena), poi si nasconde, e si vede solo dalla GOCCIA per [constant DURATA_GOCCIA] s, mentre la scena è
## in corso: alla fine, se la scena si interrompe o il livello se ne va, non resta niente sullo schermo.
func _crea_goccia() -> void:
	_goccia_strato = CanvasLayer.new()
	_goccia_strato.name = "GocciaSchermo"
	_goccia_strato.layer = 2
	add_child(_goccia_strato)
	_goccia = ColorRect.new()
	_goccia.name = "Goccia"
	_goccia.set_anchors_preset(Control.PRESET_FULL_RECT)
	_goccia.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = SHADER_GOCCIA
	mat.set_shader_parameter(&"forza", 0.0)
	_goccia.material = mat
	_goccia_strato.add_child(_goccia)
	_nascondi_goccia_dopo.call_deferred()


func _nascondi_goccia_dopo() -> void:
	for i in FOTOGRAMMI_GOCCIA:
		if not is_inside_tree():
			return
		await get_tree().process_frame
	_goccia_disegnata = true
	if _goccia:
		_muovi_goccia()


## Vero quando la goccia trasparente dell'inizio si è disegnata per [constant FOTOGRAMMI_GOCCIA] fotogrammi: prima
## [method _muovi_goccia] non la nasconde (la scena parte subito dopo il livello: la nascondeva al primo fotogramma, prima
## che si disegnasse, e la pipeline si compilava quando compariva; sonda di grafica-2 della 0.3.24, giro senza la
## schermata di caricamento)
var _goccia_disegnata := false


## Per quanto si vede la goccia (s), dalla GOCCIA.
const DURATA_GOCCIA := 2.7


## Vero se la goccia è sullo schermo (per i test).
func goccia_visibile() -> bool:
	return _goccia != null and _goccia.is_visible_in_tree() and float((_goccia.material as ShaderMaterial).get_shader_parameter(&"forza")) > 0.0


func _muovi_goccia() -> void:
	if _goccia == null:
		return
	var x := _t - float(tempi.get("goccia", INF))
	var dentro := _attivo and x >= 0.0 and x < DURATA_GOCCIA
	_goccia.visible = dentro or not _goccia_disegnata
	var mat := _goccia.material as ShaderMaterial
	if not dentro:
		mat.set_shader_parameter(&"forza", 0.0)
		return
	var vp := get_viewport().get_visible_rect().size
	mat.set_shader_parameter(&"aspetto", vp.x / maxf(vp.y, 1.0))
	# (goccia B dalla 0.3.23, scelta dell'utente) cade e si schiaccia (0,06 s) e resta appesa al muso con un filo di bava
	# per FILO_GOCCIA s, tirata in su; poi il filo si spezza, i due capi si ritirano col rimbalzo (0,3 s), la goccia ricade un poco
	# e scivola giù sempre più svelta, lasciando la scia spessa; alla fine si assottiglia e sparisce. Tutto a tempo di
	# scena: uguale a 30 e a 60 fps
	var arrivo := clampf(x / 0.06, 0.0, 1.0)
	var spezzato := clampf((x - FILO_GOCCIA) / 0.3, 0.0, 1.0)
	var tirata := arrivo * (1.0 - spezzato) * (0.7 + 0.3 * sin(x * 9.0))
	var scivola := maxf(x - FILO_GOCCIA - 0.1, 0.0)
	var giu := 0.12 * scivola * scivola + 0.03 * scivola
	var centro := Vector2(0.37 + 0.015 * sin(scivola * 2.3), 0.28 - 0.012 * tirata + 0.01 * spezzato + giu)
	mat.set_shader_parameter(&"centro", centro)
	mat.set_shader_parameter(&"raggio", lerpf(0.035, 0.08, arrivo) * (1.0 - 0.3 * clampf(scivola / 2.0, 0.0, 1.0)))
	mat.set_shader_parameter(&"scia", clampf(giu / 0.05, 0.0, 9.0))
	mat.set_shader_parameter(&"tirata", tirata)
	# (spezzato i due capi si ritirano in 0,3 s col rimbalzo, poi il filo sparisce)
	mat.set_shader_parameter(&"rottura", spezzato)
	mat.set_shader_parameter(&"filo", arrivo * (1.0 - smoothstep(0.75, 1.0, spezzato)))
	mat.set_shader_parameter(&"tempo", x)
	mat.set_shader_parameter(&"aggancio", _muso_sullo_schermo(centro))
	mat.set_shader_parameter(&"forza", arrivo * (1.0 - clampf((x - (DURATA_GOCCIA - 0.7)) / 0.7, 0.0, 1.0)))


## Per quanto la goccia resta appesa al muso col filo di bava (s), prima che il filo si spezzi.
const FILO_GOCCIA := 0.55


## Dove sta il muso (la punta del mento) sullo schermo, in UV: lì si attacca il filo della goccia. Se è dietro la
## camera o fuori dallo schermo, sopra la goccia, al bordo.
func _muso_sullo_schermo(centro: Vector2) -> Vector2:
	var cam := _p.camera if _p else null
	if cam == null or squalo == null:
		return Vector2(centro.x, -0.02)
	var m := _bone_mondo("mento_punta")
	if cam.is_position_behind(m):
		return Vector2(centro.x, -0.02)
	var vp := get_viewport().get_visible_rect().size
	var uv := cam.unproject_position(m) / Vector2(maxf(vp.x, 1.0), maxf(vp.y, 1.0))
	return Vector2(clampf(uv.x, -0.05, 1.05), clampf(uv.y, -0.05, 1.05))


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
	# (0.3.23) sdraiato nel buio; quando la luce resta accesa si tira su a sedere di scatto, poi, mentre lui lo annusa,
	# piano in ginocchio (gli occhi seguono il muso che sale verso la faccia)
	var luce: float = tempi.get("luce", 0.0)
	var apre: float = tempi.get("apre", M - 0.4)
	var h := _liscio(0.25, 0.72, luce + 0.1, luce + 0.6)
	h = lerpf(h, occhi_a_terra, _liscio(0.0, 1.0, luce + 1.4, apre - 0.1))
	h = lerpf(h, _p.stand_eye_height, _liscio(0.0, 1.0, alzati, alzati + 1.4))
	# dove guarda: nel buio lui che arriva (il corpo e la testa), dalla luce la bocca, poi lo squalo che si gira e
	# scappa, poi davanti a sé
	var lui := _bone_mondo("spina").lerp(_bone_mondo("testa"), 0.6)
	# annusando la testa segue poco il muso (15%), dritta davanti a sé: il muso e il fiuto passano davvero dalla
	# sua sinistra alla sua destra (collaudo di grafica-2 su 86ab11f9: seguendo la bocca, in cuffia il fiuto restava al
	# centro); quando la bocca si apre la guarda di nuovo in pieno
	var davanti := occhio_base + _dir_yaw(_yaw0) * 0.9
	davanti.y = bocca.y
	var muso := davanti.lerp(bocca, lerpf(0.15, 1.0, _liscio(0.0, 1.0, apre - 0.6, apre)))
	var obiettivo := lui.lerp(muso, _liscio(0.0, 1.0, luce - 0.3, luce + 0.4))
	var corpo := _bone_mondo("spina").lerp(_bone_mondo("testa"), 0.5)
	var segui := _liscio(0.0, 1.0, R + 0.15, R + 0.9) - _liscio(0.0, 1.0, porta_t + 0.6, porta_t + 2.2)
	obiettivo = obiettivo.lerp(corpo, clampf(segui, 0.0, 1.0))
	var avanti := occhio_base + (_dir_yaw(_yaw0)) * 4.0
	obiettivo = obiettivo.lerp(avanti, _liscio(0.0, 1.0, porta_t + 0.6, porta_t + 2.2))
	# lo sguardo insegue il bersaglio con un po' di ritardo (più svelto quando si spaventa)
	var rapido := (3.0 if _t < luce else 9.0) if _t < R + 0.6 else 5.0
	_sguardo = _sguardo.lerp(obiettivo, 1.0 - exp(-rapido * delta)) if delta > 0.0 else obiettivo
	var occhio := occhio_base + Vector3.UP * (h - _p.stand_eye_height)
	# si ritrae: dalla bocca sotto i 40 cm, e dal corpo che si gira e dalle mani sotto i 55 cm
	var dist := occhio.distance_to(bocca)
	var indietro := clampf(0.40 - dist, 0.0, 0.25) * 1.3 * (1.0 - _liscio(0.0, 1.0, R, R + 0.6))
	# mentre si rialza la faccia non deve passare dentro il mento o il muso
	for osso in ["mento_punta", "bocca"]:
		indietro = maxf(indietro, clampf(0.42 - occhio.distance_to(_bone_mondo(osso)), 0.0, 0.3) * 1.2)
	# (entra in 0,3 s: di colpo, al richiamo, la camera saltava indietro di 8 cm in un fotogramma; c'era già nella
	# 0.3.22, coperto dal tremore)
	if _t > R:
		var dal_richiamo := _liscio(0.0, 1.0, R, R + 0.3)
		for osso in ["testa", "collo", "petto", "mano.L", "mano.R", "coda2"]:
			indietro = maxf(indietro, clampf(0.55 - occhio.distance_to(_bone_mondo(osso)), 0.0, 0.3) * dal_richiamo)
	# (dalla 0.3.22 niente tremore, né scosse ai passi, al richiamo o alla porta)
	var d := _sguardo - occhio
	var yaw := atan2(-d.x, -d.z)
	var pitch := atan2(d.y, Vector2(d.x, d.z).length())
	_p.set_look(yaw, pitch)
	# la testa sdraiata è girata su un fianco e si raddrizza mentre si tira su
	cam.rotation.z = deg_to_rad(_liscio(25.0, 0.0, luce + 0.1, luce + 0.9))
	cam.position = Vector3(0.0, h - _p.stand_eye_height - indietro * 0.3, indietro)
	# mai dentro lo squalo: fuori dalla sua pelle (la spinta sale subito e cala piano, senza scatti)
	# la testa del giocatore subito con lo sguardo di adesso (lo rifà lui dopo, uguale): così la posizione
	# della camera nel mondo è già quella che si vedrà
	_p.call(&"_update_head", Engine.get_physics_interpolation_fraction())
	# un filo più indietro, in orizzontale via dallo squalo; mentre ci si alza torna a 0 (alla fine la camera è
	# quella del giocatore, senza scatti)
	var base := cam.global_position - _dir_yaw(_yaw0) * arretra(_t, alzati)
	# la spinta va verso quella che tiene la camera a DISTANZA_PELLE + PELLE_MORBIDA, a non più di VEL_SPINTA m/s; se
	# non basta per la distanza minima, quanto manca subito (i test vogliono che non succeda: niente salti)
	var margine := lerpf(PELLE_MORBIDA, PELLE_MORBIDA_MINACCIA, _liscio(0.0, 1.0, apre - 0.3, apre))
	var morbida := _fuori_dalla_pelle(base, DISTANZA_PELLE + MARGINE_PELLE + margine)
	_spinta = _spinta.move_toward(morbida, VEL_SPINTA * delta) if delta > 0.0 else morbida
	_spinta += _fuori_dalla_pelle(base + _spinta)
	cam.global_position = base + _spinta


func _exit_tree() -> void:
	# (la scena interrotta, il livello che se ne va: le lampade e i vetri del corridoio tornano com'erano)
	if _attivo:
		_rimetti_luci()


func _rimetti_tetti(tutti: bool) -> void:
	for i in range(_tetti.size() - 1, -1, -1):
		var tt: Array = _tetti[i]
		if tutti or _t >= float(tt[2]):
			if is_instance_valid(tt[0]):
				(tt[0] as AudioStreamPlayer3D).max_db = float(tt[1])
			_tetti.remove_at(i)


func _termina() -> void:
	_rimetti_tetti(true)
	_rimetti_luci()
	if _goccia:
		_goccia.visible = false
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


## L'arretramento orizzontale della camera (m) all'istante [param t] della scena: [constant ARRETRA], che cala a 0
## mentre ci si alza in piedi (da [param alzati] a [param alzati] + 1,4 s).
func arretra(t: float, alzati: float) -> float:
	var x := clampf((t - alzati) / 1.4, 0.0, 1.0)
	return ARRETRA * (1.0 - x * x * (3.0 - 2.0 * x))


func _dir_yaw(y: float) -> Vector3:
	return Vector3(-sin(y), 0.0, -cos(y))


func _liscio(a: float, b: float, t0: float, t1: float) -> float:
	var x := clampf((_t - t0) / (t1 - t0), 0.0, 1.0)
	return lerpf(a, b, x * x * (3.0 - 2.0 * x))
