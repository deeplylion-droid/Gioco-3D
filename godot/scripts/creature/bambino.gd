class_name Bambino
extends Node3D
## Un bambino del capitolo 1 (creatura minore): la testa a cubo o l'agnellino.
## Si vede di sfuggita: fa paura con la postura, la lentezza e lo sguardo, mai con scatti.
##
## La scena ha due modelli con lo stesso scheletro e le stesse animazioni (fermo,
## inclina_testa, cammina, corsa, si_gira): "Calmo" (travestito) e "Rivelato". rivela() passa
## dall'uno all'altro senza interrompere l'animazione.
##
## Modalità (si sceglie dall'Inspector e si cambia con i metodi):
##   STATUA   immobile finché il giocatore non lo guarda; allora reagisce (si gira o inclina la
##            testa), emette "visto" e passa a OSSERVA.
##   OSSERVA  respira fermo e segue il giocatore con la testa (l'agnellino rivelato anche con
##            l'occhio, spostando le UV); ogni tanto inclina la testa. Gira piano il corpo.
##   CAMMINA  cammina piano lungo "percorso", poi osserva (o sparisce, se richiesto).
##   SCAPPA   corre lungo "punti_fuga" (l'ultimo dietro un angolo) e sparisce.
## Dalla statua, dall'osservazione e dalla camminata scappa se il giocatore si avvicina troppo
## (non dalla luce della torcia: scelta dell'utente del 21 ottobre, "lascia come ora"). È nel gruppo "bambini". I segnali servono per l'audio.

signal visto      ## il giocatore lo ha guardato (fine della modalità statua)
signal si_gira    ## comincia a girarsi verso il giocatore
signal rivelato   ## il travestimento si apre
signal scappa     ## comincia a scappare (giocatore troppo vicino)
signal sparito    ## è sparito, alla fine della fuga o del percorso

enum Modalita { STATUA, OSSERVA, CAMMINA, SCAPPA, SPARITO }
enum Reazione { NESSUNA, INCLINA_TESTA, SI_GIRA }

const ANIMAZIONI: Array[StringName] = [&"fermo", &"inclina_testa", &"cammina", &"corsa", &"si_gira"]
const CICLICHE: Array[StringName] = [&"fermo", &"inclina_testa", &"cammina", &"corsa"]
## Accelerazione della camminata (m/s²): parte e si ferma con il passo, non di colpo.
const ACCEL_CAMMINATA := 1.2
## Quanto gira al massimo camminando (gradi al secondo): curve, non giri sul posto.
const GIRO_CAMMINATA := 110.0

@export var modalita := Modalita.STATUA
## Comincia già rivelato (il cubo spaccato, l'agnellino con il muso aperto).
@export var rivelato_all_inizio := false

@export_group("Statua")
## Cosa fa quando il giocatore lo guarda. Con SI_GIRA all'inizio dà le spalle al punto verso
## cui è girato il nodo: giralo verso dove arriverà il giocatore.
@export var reazione := Reazione.SI_GIRA
## Per quanto tempo il giocatore deve guardarlo prima che reagisca (secondi).
@export var tempo_per_vederlo := 0.6
@export var distanza_vista := 22.0
## Quanto vicino al centro dello sguardo deve stare (gradi).
@export_range(2.0, 45.0) var angolo_vista := 12.0

@export_group("Osserva")
@export var segue_con_la_testa := true
## Quanto può girare la testa (gradi).
@export_range(10.0, 90.0) var limite_testa := 60.0
## Quanta parte dell'angolo copre la testa (il resto lo fa l'occhio dell'agnellino rivelato:
## la testa si gira a metà e l'occhio ti fissa).
@export_range(0.0, 1.0) var quota_testa := 0.7
## Gira piano anche il corpo verso il giocatore.
@export var gira_il_corpo := true
@export var velocita_rotazione := 22.0
## L'agnellino rivelato segue il giocatore anche con l'occhio (sposta le UV dell'iride).
@export var occhio_segue := true
## Quanto si può spostare l'iride (in UV; 0,1 = un quinto del bulbo).
@export var spostamento_occhio := 0.1
## Ogni quanti secondi inclina la testa mentre osserva (0 = mai).
@export var inclina_ogni := 8.0

@export_group("Cammina")
@export var percorso: Array[Node3D] = []
@export var velocita_camminata := 0.5
## Alla fine del percorso sparisce (per esempio dietro un angolo) invece di fermarsi a osservare.
@export var sparisce_a_fine_percorso := false

## Quanto avanzano i piedi a terra nelle animazioni di camminata e corsa (m/s, a velocità 1), misurato sugli
## ossa dei piedi (tests/test_bambini_passi.gd): il corpo avanza alla stessa velocità e i piedi non scivolano.
## L'agnellino ha le gambe più corte del bambino a cubo.
@export var vel_camminata_anim := 0.45
@export var vel_corsa_anim := 2.45
## Correndo: accelerazione (m/s²) e quanto gira al massimo (gradi al secondo). Più svelto dove scappa in una
## corsia stretta col giocatore che gli corre dietro (l'agnellino della scala).
@export var accel_corsa := 4.5
@export var giro_corsa := 260.0

@export_group("Fuga")
## Se il giocatore arriva più vicino di così, scappa (0 = mai).
@export var distanza_fuga := 3.5
## Dove corre; l'ultimo punto va messo dietro un angolo. Se è vuoto corre via dal giocatore.
@export var punti_fuga: Array[Node3D] = []
@export var velocita_corsa := 2.8
## Senza punti di fuga: quanto lontano corre prima di sparire.
@export var distanza_fuga_libera := 7.0
@export var rivela_quando_scappa := false
## Vero: in fuga sparisce solo quando il giocatore non lo vede (fuori dall'inquadratura o dietro un muro), anche
## prima della fine del percorso; se alla fine lo stai ancora guardando resta fermo finché non lo perdi di vista.
## Falso: sparisce alla fine del percorso.
@export var sparisce_fuori_vista := false
## Con [member sparisce_fuori_vista]: per almeno tanti secondi lo si vede correre via.
@export var fuga_minima := 0.4
## Quando sparisce si toglie dalla scena (altrimenti resta nascosto e si può riusare).
@export var libera_quando_sparisce := true

var e_rivelato := false

var _modelli: Array[Node3D] = []
var _player_anim: Array[AnimationPlayer] = []
var _sguardi: Array[LookAtModifier3D] = []
var _occhio_mat: StandardMaterial3D
var _occhio_testa: Array = []          # [Skeleton3D, indice osso Head] del modello rivelato
var _bersaglio: Marker3D
var _visto_da := 0.0
var _reazione_in_corso := false
var _prossima_inclinazione := 0.0
var _punti: Array[Vector3] = []
var _in_fuga := 0.0
var _fermo_a_fine_fuga := false
var _influenza := 0.0
var _vel := 0.0           # velocità del corpo adesso (m/s), verso dove guarda


func _ready() -> void:
	add_to_group(&"bambini")
	for n in ["Calmo", "Rivelato"]:
		var m := get_node_or_null(n) as Node3D
		if m:
			_prepara_modello(m)
	_bersaglio = Marker3D.new()
	_bersaglio.name = "BersaglioSguardo"
	_bersaglio.top_level = true
	add_child(_bersaglio)
	_bersaglio.global_position = global_position + global_basis.z * 3.0 + Vector3.UP * 1.5
	for s in _sguardi:
		s.target_node = s.get_path_to(_bersaglio)
	_mostra(rivelato_all_inizio)
	_prossima_inclinazione = inclina_ogni * randf_range(0.6, 1.2)
	match modalita:
		Modalita.STATUA:
			statua()
		Modalita.OSSERVA:
			osserva()
		Modalita.CAMMINA:
			cammina(percorso)
		Modalita.SCAPPA:
			scappa_ora()
		Modalita.SPARITO:
			visible = false


func _prepara_modello(m: Node3D) -> void:
	_modelli.append(m)
	var ap := m.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap:
		for a in CICLICHE:
			if ap.has_animation(a):
				ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR
		if _player_anim.is_empty():   # un solo segnale di fine (i modelli vanno insieme)
			ap.animation_finished.connect(_fine_animazione)
		_player_anim.append(ap)
	var scheletri := m.find_children("*", "Skeleton3D", true, false)
	if scheletri.is_empty():
		return
	var sk := scheletri[0] as Skeleton3D
	var testa := sk.find_bone("Head")
	if testa < 0:
		return
	# La testa che guarda il giocatore: assi dell'osso ricavati dalla posa di riposo.
	var sguardo := LookAtModifier3D.new()
	sguardo.name = "SguardoTesta"
	sguardo.bone_name = "Head"
	var inv := (sk.global_basis * sk.get_bone_global_rest(testa).basis).orthonormalized().inverse()
	sguardo.forward_axis = _asse_osso(inv * global_basis.z.normalized()) as SkeletonModifier3D.BoneAxis
	var su := inv * global_basis.y.normalized()
	var ax := su.abs().max_axis_index()
	sguardo.primary_rotation_axis = ax as Vector3.Axis
	sguardo.use_secondary_rotation = true
	sguardo.use_angle_limitation = true
	sguardo.symmetry_limitation = true
	sguardo.primary_limit_angle = deg_to_rad(limite_testa * 2.0)
	sguardo.secondary_limit_angle = deg_to_rad(50.0)
	sguardo.primary_damp_threshold = 0.6
	sguardo.secondary_damp_threshold = 0.6
	sguardo.duration = 0.9
	sguardo.transition_type = Tween.TRANS_SINE
	sguardo.ease_type = Tween.EASE_IN_OUT
	sguardo.influence = 0.0
	sk.add_child(sguardo)
	_sguardi.append(sguardo)
	# L'occhio dell'agnellino (guscio a parte, attaccato all'osso della testa).
	var occhio := m.find_child("occhio_bulbo*", true, false) as MeshInstance3D
	if occhio == null:
		for c in m.find_children("*", "MeshInstance3D", true, false):
			if String(c.name).begins_with("occhio_bulbo"):
				occhio = c
				break
	if occhio and occhio.get_active_material(0) is StandardMaterial3D:
		_occhio_mat = (occhio.get_active_material(0) as StandardMaterial3D).duplicate()
		occhio.set_surface_override_material(0, _occhio_mat)
		# assi del modello (destra, su, avanti) nello spazio dello scheletro: fissi
		var a := sk.global_basis.inverse() * global_basis
		_occhio_testa = [sk, testa, a.orthonormalized()]


func _asse_osso(v: Vector3) -> int:
	var i := v.abs().max_axis_index()
	return i * 2 + (0 if v[i] >= 0.0 else 1)


# ---------------------------------------------------------------- comandi
## Immobile; reagisce quando il giocatore lo guarda.
func statua() -> void:
	modalita = Modalita.STATUA
	_visto_da = 0.0
	_reazione_in_corso = false
	var posa := &"si_gira" if reazione == Reazione.SI_GIRA else &"fermo"
	_anima(posa, 0.0)
	for ap in _player_anim:
		ap.seek(0.0, true)
		ap.pause()


## Fermo a respirare, segue il giocatore con lo sguardo.
func osserva() -> void:
	modalita = Modalita.OSSERVA
	_anima(&"fermo")


## Cammina piano lungo i punti dati (nodi della scena).
func cammina(punti: Array[Node3D]) -> void:
	modalita = Modalita.CAMMINA
	_punti.clear()
	for n in punti:
		if n:
			_punti.append(n.global_position)
	if _punti.is_empty():
		osserva()
		return
	_anima(&"cammina")
	_vel = 0.0
	_passo_animazione(vel_camminata_anim)


## Scappa subito (lungo punti_fuga, oppure via dal giocatore) e poi sparisce.
func scappa_ora() -> void:
	if modalita == Modalita.SCAPPA or modalita == Modalita.SPARITO:
		return
	modalita = Modalita.SCAPPA
	_reazione_in_corso = false
	_in_fuga = 0.0
	_fermo_a_fine_fuga = false
	if rivela_quando_scappa and not e_rivelato:
		rivela()
	_punti.clear()
	for n in punti_fuga:
		if n:
			_punti.append(n.global_position)
	if _punti.is_empty():
		var via := global_basis.z
		if GameState.player:
			via = global_position - GameState.player.global_position
		via.y = 0.0
		if via.length() < 0.01:
			via = global_basis.z
		_punti.append(global_position + via.normalized() * distanza_fuga_libera)
	_anima(&"corsa", 0.3)
	_passo_animazione(vel_corsa_anim)
	scappa.emit()


## Apre il travestimento (stessa animazione, stesso istante).
func rivela() -> void:
	if e_rivelato:
		return
	_mostra(true)
	rivelato.emit()


## Torna travestito (per riusare il nodo).
func richiudi() -> void:
	_mostra(false)


# ---------------------------------------------------------------- ogni frame
func _process(delta: float) -> void:
	var p: Player = GameState.player
	_aggiorna_sguardo(delta, p)
	if p == null:
		return
	match modalita:
		Modalita.STATUA:
			if _reazione_in_corso:
				return
			if _guardato_da(p):
				_visto_da += delta
				if _visto_da >= tempo_per_vederlo:
					_reagisci()
			else:
				_visto_da = 0.0
		Modalita.OSSERVA:
			if _deve_scappare(p):
				scappa_ora()
				return
			if gira_il_corpo and not _reazione_in_corso:
				_gira_verso(p.global_position, deg_to_rad(velocita_rotazione) * delta)
			if inclina_ogni > 0.0 and not _reazione_in_corso:
				_prossima_inclinazione -= delta
				if _prossima_inclinazione <= 0.0:
					_prossima_inclinazione = inclina_ogni * randf_range(0.7, 1.3)
					_reazione_in_corso = true
					_anima(&"inclina_testa", 0.6)
		Modalita.CAMMINA:
			if _deve_scappare(p):
				scappa_ora()
				return
			if _segui_punti(delta, velocita_camminata, GIRO_CAMMINATA, ACCEL_CAMMINATA, vel_camminata_anim, true):
				if sparisce_a_fine_percorso:
					_sparisci()
				else:
					for ap in _player_anim:
						ap.speed_scale = 1.0
					osserva()
		Modalita.SCAPPA:
			_in_fuga += delta
			var arrivato := _segui_punti(delta, velocita_corsa, giro_corsa, accel_corsa, vel_corsa_anim, false)
			if not sparisce_fuori_vista:
				if arrivato:
					_sparisci()
			elif (arrivato or _in_fuga >= fuga_minima) and not visibile_da(p):
				_sparisci()
			elif arrivato and not _fermo_a_fine_fuga:
				_fermo_a_fine_fuga = true
				for ap in _player_anim:
					ap.speed_scale = 1.0
				_anima(&"fermo", 0.2)


func _reagisci() -> void:
	visto.emit()
	match reazione:
		Reazione.SI_GIRA:
			_reazione_in_corso = true
			si_gira.emit()
			for ap in _player_anim:
				ap.play(&"si_gira")
		Reazione.INCLINA_TESTA:
			_reazione_in_corso = true
			_anima(&"inclina_testa", 0.5)
	modalita = Modalita.OSSERVA


func _fine_animazione(nome: StringName) -> void:
	if nome == &"si_gira" or nome == &"inclina_testa":
		_reazione_in_corso = false
		if modalita == Modalita.OSSERVA:
			_anima(&"fermo", 0.5)


func _deve_scappare(p: Player) -> bool:
	return distanza_fuga > 0.0 and global_position.distance_to(p.global_position) < distanza_fuga


## Il giocatore guarda verso di lui (vicino al centro dello sguardo), senza muri in mezzo.
func _guardato_da(p: Player) -> bool:
	var occhio := p.get_eye_position()
	var testa := punto_testa()
	var verso := testa - occhio
	if verso.length() > distanza_vista:
		return false
	if rad_to_deg(p.get_aim_direction().angle_to(verso)) > angolo_vista:
		return false
	return _vista_libera(occhio, testa, p)


## Il giocatore lo può vedere: qualche punto del corpo (dai piedi alla testa) è nell'inquadratura e senza
## muri in mezzo.
func visibile_da(p: Player) -> bool:
	var cam := get_viewport().get_camera_3d()
	var occhio := p.get_eye_position()
	for i in 9:   # una griglia di punti sul corpo (solo in fuga): basta uno in vista
		for j in 5:
			var punto: Vector3 = global_position + global_basis.y * (0.05 + i * 0.15) + global_basis.x * (j * 0.15 - 0.3)
			if cam and not cam.is_position_in_frustum(punto):
				continue
			if _vista_libera(occhio, punto, p):
				return true
	return false


func _vista_libera(da: Vector3, a: Vector3, p: Player) -> bool:
	var q := PhysicsRayQueryParameters3D.create(da, a)
	q.exclude = [p.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit.is_empty() or hit.position.distance_to(a) < 0.35


## Punto della testa (per lo sguardo del giocatore).
func punto_testa() -> Vector3:
	return global_position + global_basis.y * 1.0


func _aggiorna_sguardo(delta: float, p: Player) -> void:
	var vuole := p != null and segue_con_la_testa and modalita == Modalita.OSSERVA and not _reazione_in_corso
	if vuole:
		var target := p.get_eye_position()
		_bersaglio.global_position = _bersaglio.global_position.lerp(target, 1.0 - exp(-4.0 * delta))
	_influenza = move_toward(_influenza, quota_testa if vuole else 0.0, delta / 0.8)
	for s in _sguardi:
		s.influence = _influenza
	_aggiorna_occhio(p)


## L'iride dell'agnellino rivelato guarda il giocatore: sposta le UV del guscio dell'occhio.
func _aggiorna_occhio(p: Player) -> void:
	if _occhio_mat == null or _occhio_testa.is_empty():
		return
	var off := Vector2.ZERO
	if p != null and occhio_segue and e_rivelato and modalita != Modalita.SPARITO:
		var sk := _occhio_testa[0] as Skeleton3D
		var osso: int = _occhio_testa[1]
		var assi_sk: Basis = _occhio_testa[2]
		# quanto la testa è girata rispetto al riposo, applicato agli assi del modello
		var dev := sk.get_bone_global_pose(osso).basis.orthonormalized() * sk.get_bone_global_rest(osso).basis.orthonormalized().inverse()
		var assi := (sk.global_basis * dev * assi_sk).orthonormalized()
		var centro := sk.global_transform * sk.get_bone_global_pose(osso).origin
		var dir := (p.get_eye_position() - centro).normalized()
		var x := dir.dot(assi.x)
		var y := dir.dot(assi.y)
		var z := dir.dot(assi.z)
		var yaw := clampf(atan2(x, maxf(z, 0.05)) / deg_to_rad(45.0), -1.0, 1.0)
		var pitch := clampf(atan2(y, maxf(z, 0.05)) / deg_to_rad(45.0), -1.0, 1.0)
		off = Vector2(-yaw, pitch) * spostamento_occhio
	var cur := Vector2(_occhio_mat.uv1_offset.x, _occhio_mat.uv1_offset.y)
	cur = cur.lerp(off, 0.08)
	_occhio_mat.uv1_offset = Vector3(cur.x, cur.y, 0.0)


func _gira_verso(punto: Vector3, passo: float) -> void:
	var verso := punto - global_position
	verso.y = 0.0
	if verso.length() < 0.05:
		return
	var voluto := atan2(verso.x, verso.z)
	rotation.y = rotate_toward(rotation.y, voluto, passo)


## Avanza verso il prossimo punto come si cammina davvero: accelera e rallenta ([param accel]), gira in curva al
## massimo di [param giro] gradi al secondo (più piano quando deve girare molto), e va sempre dove guarda; l'animazione
## va alla stessa velocità del corpo ([param vel_anim]: quanto avanzano i piedi a terra), così i piedi non
## scivolano. Con [param ferma] rallenta fino a fermarsi sull'ultimo punto. True quando è arrivato all'ultimo.
func _segui_punti(delta: float, vel_max: float, giro: float, accel: float, vel_anim: float, ferma: bool) -> bool:
	# (un punto in mezzo vale raggiunto da un po' prima, meno se dopo c'è una curva stretta: non taglia lo spigolo)
	while not _punti.is_empty() and global_position.distance_to(_punti[0]) < (0.12 if _punti.size() == 1 else (0.25 if _curva_stretta() else 0.45)):
		_punti.pop_front()
	if _punti.is_empty():
		_vel = 0.0
		return true
	var prossimo := _punti[0]
	var verso := prossimo - global_position
	verso.y = 0.0
	var errore := absf(angle_difference(rotation.y, atan2(verso.x, verso.z)))
	_gira_verso(prossimo, deg_to_rad(giro) * delta)
	# girandosi molto rallenta (non va di lato); se deve voltarsi (oltre 75 gradi, per esempio per scappare da chi
	# guardava) prima si volta quasi sul posto, a passi lenti, e poi parte: non fa la curva larga dentro un muro.
	# Vicino all'ultimo punto si ferma col passo
	var voluta := vel_max * clampf(cos(errore), 0.2, 1.0) if errore < deg_to_rad(75.0) else 0.0
	# non più veloce di quanto serve per arrivare al punto girando (sennò gli gira intorno o lo manca)...
	var d := verso.length()
	var w := deg_to_rad(giro)
	if errore > deg_to_rad(3.0):
		voluta = minf(voluta, w * d / (2.0 * sin(errore)))
	# ...e prima di una curva stretta rallenta, per farla col passo (raggio 0,35 m)
	if _curva_stretta():
		voluta = minf(voluta, sqrt(pow(w * 0.35, 2.0) + 2.0 * accel * d))
	if ferma and _punti.size() == 1:
		voluta = minf(voluta, sqrt(2.0 * accel * d))
	_vel = move_toward(_vel, voluta, accel * delta)
	var avanti := global_basis.z
	avanti.y = 0.0
	var passo := minf(_vel * delta, verso.length()) if _punti.size() == 1 else _vel * delta
	global_position += avanti.normalized() * passo
	_passo_animazione(vel_anim)
	return false


## Dopo il prossimo punto la strada gira di più di 45 gradi.
func _curva_stretta() -> bool:
	if _punti.size() < 2:
		return false
	var a := (_punti[0] - global_position) * Vector3(1, 0, 1)
	var b := (_punti[1] - _punti[0]) * Vector3(1, 0, 1)
	return a.length() > 0.01 and b.length() > 0.01 and a.angle_to(b) > deg_to_rad(45.0)


## L'animazione di camminata o corsa alla velocità del corpo (i piedi non scivolano); da fermo un passo minimo.
func _passo_animazione(vel_anim: float) -> void:
	var scala := clampf(_vel / maxf(vel_anim, 0.01), 0.25, 1.6)
	for ap in _player_anim:
		ap.speed_scale = scala


func _sparisci() -> void:
	modalita = Modalita.SPARITO
	visible = false
	for ap in _player_anim:
		ap.stop()
	sparito.emit()
	if libera_quando_sparisce:
		queue_free()


func _mostra(aperto: bool) -> void:
	e_rivelato = aperto and _modelli.size() > 1
	var da: AnimationPlayer = _player_anim[0] if not _player_anim.is_empty() else null
	for i in _modelli.size():
		_modelli[i].visible = (i == 1) == e_rivelato
	# il modello che si vede riparte dallo stesso istante dell'altro
	if da and _player_anim.size() > 1 and da.current_animation != &"":
		var t := da.current_animation_position
		for ap in _player_anim:
			if ap != da and ap.current_animation != da.current_animation:
				ap.play(da.current_animation)
			if ap != da:
				ap.seek(t, true)


func _anima(nome: StringName, fusione := 0.4) -> void:
	for ap in _player_anim:
		if not ap.has_animation(nome):
			continue
		ap.speed_scale = 1.0
		ap.play(nome, fusione)
