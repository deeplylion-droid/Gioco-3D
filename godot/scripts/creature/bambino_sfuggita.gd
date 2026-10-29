class_name BambinoSfuggita
extends Node3D
## Un bambino visto di sfuggita (proposta approvata dall'utente la sera del 25 ottobre, con la nota "attenzione alle
## animazioni. falle bene"): il bambino a cubo o l'agnellino compare per un attimo lontano, sta fermo a guardarti e
## scappa dietro un angolo prima che tu ci arrivi. Niente aggressioni: fa paura col modo in cui sta fermo e scappa.
##
## Il bambino sta dove sta questo nodo, coi piedi a terra, girato verso il suo asse +Z. Come va:
## 1. ATTESA: quando il giocatore entra nella [member zona] (coordinate del genitore) e [member aspetta] (se c'è, per
##    esempio l'oblò dello stesso corridoio) ha finito (lei è stata vista ed è andata via), il bambino si mette al suo
##    posto, ma solo mentre il giocatore non può vederlo (o, con [member compare_lontano], molto lontano nel buio): non compare mai sotto gli occhi;
## 2. GUARDA: fermo, ti segue con la testa (Bambino in OSSERVA). Quando lo hai guardato per [member tempo_visto]
##    secondi, o ti avvicini sotto [member distanza_fuga] metri, aspetta ancora [member attesa_prima_di_scappare]
##    secondi (inclina piano la testa) e scappa lungo [member via] (coordinate del genitore; l'ultimo punto dietro un
##    angolo o oltre una porta), con la partenza e le curve della corsa di Bambino;
## 3. sparisce solo fuori dalla vista del giocatore (Bambino.sparisce_fuori_vista). Se il giocatore non lo guarda mai,
##    dopo [member tempo_max] secondi se ne va lo stesso, quando non lo vede nessuno.
## Una volta sola: lo stato si salva coi checkpoint (gruppo "persist").
## Niente pipeline nuove quando compare: appena entra nella scena (con la zona) il bambino si crea nascosto e si disegna
## una volta fuori vista, al suo posto, con le luci della zona e da dove lo vedrà il giocatore ([member da_dove]).

signal comparso
signal scappato
signal finito

enum Stato { ATTESA, GUARDA, SCAPPA, FINITO }

## La scena del bambino (bambino_cubo.tscn o bambino_agnello.tscn).
@export var scena: PackedScene
## Dove deve stare il giocatore perché il bambino compaia (coordinate del genitore).
@export var zona := AABB()
## Un nodo da aspettare (un ObloLei: il bambino compare solo dopo lei, mai insieme). Vuoto: nessuna attesa.
@export var aspetta: Node
## La strada della fuga (coordinate del genitore).
@export var via := PackedVector3Array()
## Il punto da cui il giocatore lo vede di solito (coordinate del genitore), per il riscaldamento.
@export var da_dove := Vector3.ZERO
@export var tempo_visto := 1.2
@export var distanza_fuga := 9.0
@export var attesa_prima_di_scappare := 1.4
@export var tempo_max := 25.0
@export var velocita_corsa := 2.4
## Oltre questa distanza (m) può comparire anche se il posto è in vista: lontano, nel buio (il tunnel, dove si
## corre guardando avanti). 0: solo fuori vista.
@export var compare_lontano := 0.0
## Quanto deve essere vicino al centro dello sguardo per contare come "visto" (gradi).
@export var angolo_visto := 14.0

var stato := Stato.ATTESA
var bambino: Bambino
var _t := 0.0
var _visto := 0.0
var _fuga_tra := -1.0
var _punti: Array[Node3D] = []


func _ready() -> void:
	add_to_group(&"persist")
	if scena == null:
		return
	bambino = scena.instantiate() as Bambino
	bambino.modalita = Bambino.Modalita.SPARITO
	bambino.libera_quando_sparisce = false
	bambino.sparisce_fuori_vista = true
	bambino.distanza_fuga = 0.0          # la fuga la decide questo nodo
	bambino.reazione = Bambino.Reazione.NESSUNA
	bambino.velocita_corsa = velocita_corsa
	bambino.inclina_ogni = 3.5
	bambino.gira_il_corpo = false        # sta girato com'è, ti segue con la testa
	# (top_level: Bambino si gira e cammina in coordinate del mondo, e questo nodo può essere girato)
	bambino.top_level = true
	add_child(bambino)
	bambino.global_transform = global_transform
	bambino.visible = false
	bambino.process_mode = Node.PROCESS_MODE_DISABLED
	for q in via:
		var m := Marker3D.new()
		m.top_level = true
		add_child(m)
		m.global_position = get_parent().to_global(q) if get_parent() is Node3D else q
		_punti.append(m)
	bambino.punti_fuga = _punti
	bambino.sparito.connect(_sparito)
	_riscalda.call_deferred()


func _process(delta: float) -> void:
	var p := GameState.player
	if p == null or not is_instance_valid(p) or bambino == null:
		return
	match stato:
		Stato.ATTESA:
			if not _pronto(p):
				return
			var lontano := compare_lontano > 0.0 and global_position.distance_to(p.global_position) > compare_lontano
			if not lontano and _vede_il_posto(p):
				return
			_mostra()
		Stato.GUARDA:
			_t += delta
			if _guardato(p):
				_visto += delta
			var vicino := global_position.distance_to(p.global_position) < distanza_fuga
			if _fuga_tra < 0.0 and (_visto >= tempo_visto or vicino):
				_fuga_tra = 0.0 if vicino else attesa_prima_di_scappare
			if _fuga_tra >= 0.0:
				_fuga_tra -= delta
				if _fuga_tra <= 0.0:
					_scappa()
			elif _t > tempo_max and not bambino.visibile_da(p):
				_fine()


## Il giocatore è nella zona e quello che si aspetta è finito.
func _pronto(p: Player) -> bool:
	if zona.size != Vector3.ZERO:
		var dove: Vector3 = get_parent().to_local(p.global_position) if get_parent() is Node3D else p.global_position
		if not zona.has_point(dove):
			return false
	# (lei dietro l'oblò dello stesso posto: mai insieme a lei, solo dopo che è stata vista ed è andata via; se lei non
	# c'è stata, perché il giocatore non l'ha vista, il bambino non compare: ritornando lei ricompare per prima)
	if aspetta and is_instance_valid(aspetta) and aspetta is ObloLei:
		var o := aspetta as ObloLei
		return o.stato == ObloLei.Stato.FINITA or not o.attivo
	return true


## Il giocatore vede il posto dove starà (una qualsiasi parte del corpo): allora non compare ancora.
func _vede_il_posto(p: Player) -> bool:
	bambino.visible = true
	var vede := bambino.visibile_da(p)
	bambino.visible = false
	return vede


func _mostra() -> void:
	stato = Stato.GUARDA
	_t = 0.0
	_visto = 0.0
	_fuga_tra = -1.0
	bambino.global_transform = global_transform
	bambino.visible = true
	bambino.process_mode = Node.PROCESS_MODE_INHERIT
	bambino.osserva()
	comparso.emit()


func _guardato(p: Player) -> bool:
	var occhio := p.get_eye_position()
	var testa := bambino.punto_testa()
	return rad_to_deg(p.get_aim_direction().angle_to(testa - occhio)) < angolo_visto and bambino.visibile_da(p)


func _scappa() -> void:
	stato = Stato.SCAPPA
	bambino.scappa_ora()
	scappato.emit()


func _sparito() -> void:
	_fine()


func _fine() -> void:
	stato = Stato.FINITO
	if bambino:
		bambino.visible = false
		bambino.process_mode = Node.PROCESS_MODE_DISABLED
	finito.emit()


func save_state() -> Dictionary:
	return {"finito": stato == Stato.FINITO}


func load_state(s: Dictionary) -> void:
	if bool(s.get("finito", false)):
		_fine()
	else:
		# ripartendo da prima: di nuovo in attesa, nascosto
		stato = Stato.ATTESA
		if bambino:
			bambino.modalita = Bambino.Modalita.SPARITO
			bambino.visible = false
			bambino.process_mode = Node.PROCESS_MODE_DISABLED
			bambino.global_transform = global_transform


# ---------------------------------------------------------------- riscaldamento
## Disegna il bambino una volta fuori vista al suo posto (sullo strato che la camera del gioco non disegna), prima un
## pezzo per volta (RiscaldamentoShader.disegna_a_pezzi), poi da [member da_dove] con una camera che vede tutti gli
## strati, così anche le luci della zona lo illuminano come nel gioco (le varianti con le luci accese). Solo gli strati
## dei suoi nodi visibili cambiano, mai la cull mask delle luci.
func _riscalda() -> void:
	if DisplayServer.get_name() == "headless" or bambino == null or not is_inside_tree():
		return
	for i in 600:
		if get_viewport() and get_viewport().get_camera_3d():
			break
		await get_tree().process_frame
		if not is_inside_tree():
			return
	if stato != Stato.ATTESA:
		return
	var principale := get_viewport()
	bambino.visible = true
	await RiscaldamentoShader.disegna_a_pezzi(bambino, principale, 2, Callable(), _giro.bind(principale))
	if stato == Stato.ATTESA and is_instance_valid(bambino):
		bambino.visible = false


func _giro(principale: Viewport) -> void:
	var sv := SubViewport.new()
	sv.size = Vector2i(320, 180)
	RiscaldamentoShader.copia_viewport(sv, principale)
	sv.world_3d = principale.find_world_3d()
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var cam := Camera3D.new()
	var cam_gioco := principale.get_camera_3d()
	if cam_gioco:
		cam.environment = cam_gioco.environment
		cam.attributes = cam_gioco.attributes
	cam.fov = 70.0
	sv.add_child(cam)
	add_child(sv)
	cam.current = true
	var da: Vector3 = get_parent().to_global(da_dove) if get_parent() is Node3D else da_dove
	if da.distance_to(global_position) < 0.5:
		da = global_position + global_basis.z * 6.0 + Vector3.UP * 1.6
	cam.look_at_from_position(da, global_position + Vector3.UP * 0.8, Vector3.UP)
	for i in 4:
		await get_tree().process_frame
		if not is_inside_tree():
			break
	sv.queue_free()
