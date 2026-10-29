class_name LeiTunnel
extends Node3D
## Lei nel tunnel del viaggio sottomarino (scelte del 24 ottobre, GDD): fluttua intera sopra il canale a bocca
## spalancata, l'occhio pieno di vene, le braccia tese verso di te; sotto VICINA metri morde a vuoto; un getto in
## faccia la fa ritrarre strizzando l'occhio; sotto i 2,5 m ti prende (la presa dell'inseguimento); alla fine sbatte
## contro il portello con la faccia sull'oblò.
## Le animazioni sono quelle di tools/blender/medusa_inseguimento.py ("inseguimento/insegue_aperta", ...), la voce la
## mette l'addon audio sulle animazioni (Audio.Statua).
##
## Chi la comanda (la logica del tunnel) decide dove sta lungo la strada e la chiama:
## - riemergi(pos, verso): risale dal canale (pos: il punto sul pelo dell'acqua) e comincia a inseguire;
## - vai(pos, verso, delta): a ogni fotogramma, il punto a centro canale sul pelo dell'acqua e la direzione della
##   strada; lei ci sta sopra a QUOTA, si gira e si inclina in curva da sola;
## - respinta(): il getto in faccia (lo segnala getto_in_faccia: la logica la rimanda indietro e chiama respinta);
## - prendi(): sotto i 2,5 m;
## - schianto(centro_oblo, normale): il portello chiuso (normale verso di lei).
## L'origine del modello è sul piano dei tentacoli: nella corsa lei va da 0 a 5,2 m (5,5 nel ritrarsi e nel
## riemergere, misurati sulla mesh in Blender), di lato fino a 2,5 m dall'asse; a QUOTA sopra l'acqua sta sotto la
## volta più bassa del tunnel (6,5 m sopra l'acqua) con 30 cm di margine.

## Il getto in faccia ha preso abbastanza acqua (litri, come nelle vasche): la logica decide che cosa fare.
signal getto_in_faccia
## Lo schianto sull'oblò è arrivato al portello (la faccia tocca il vetro).
signal schianto_contro
## Lo schianto è finito: lei resta premuta sul portello.
signal schianto_finito

enum Stato { VIA, RIEMERGE, INSEGUE, RITRAE, PRESA, SCHIANTO }

const ANIM := "inseguimento/"
## L'origine di lei sopra il pelo dell'acqua (m): le punte dei tentacoli restano sopra il piano delle banchine (0,42 m
## sopra l'acqua nel tunnel di ambienti-2), la testa arriva al più a 6,2 m sopra l'acqua.
const QUOTA := 0.72
## Schianto: il piano del portello davanti all'origine e il centro dell'oblò sopra (medusa_inseguimento.py, OBLO).
const OBLO := Vector2(0.95, 4.62)
## Quando la faccia tocca il vetro nello schianto (s).
const SCHIANTO_CONTRO := 0.35
const ROSA := Color(1.0, 0.35, 0.6)

## Litri di getto in faccia per farla ritrarre (circa mezzo secondo di getto, come nelle vasche).
@export var getto_litri := 0.6
## Sotto questa distanza dal giocatore morde a vuoto (m).
@export var vicina := 7.0
## Quanto si inclina di lato in curva al massimo (gradi) e quanto in avanti quando va veloce.
@export var virata_max := 12.0
@export var avanti_max := 6.0
## Quanto in fretta si gira verso la strada (1/s).
@export var giro_rapidita := 3.0

var lei: MedusaAffacciata
var stato := Stato.VIA
var morbidezza: MorbidezzaLei
var _ap: AnimationPlayer
var _viso: WaterHitbox
var _getto := 0.0
var _t := 0.0
var _dir := Vector3.FORWARD
var _virata := 0.0
var _velocita := 0.0
var _pos_prima := Vector3.ZERO
var _anim := &""


func _ready() -> void:
	lei = MedusaAffacciata.new()
	lei.name = "Lei"
	lei.model = load("res://assets/models/medusa/medusa.glb")
	lei.bell_material = load("res://assets/models/medusa/medusa_campana.tres")
	lei.material_map = {
		"M_capelli": load("res://assets/models/medusa/medusa_capelli_bagnata.tres"),
		"M_ciocche": load("res://assets/models/medusa/medusa_ciocche_bagnata.tres"),
		"M_mani": load("res://assets/models/medusa/medusa_mani_bagnata.tres"),
		"M_occhio_bulbo": load("res://assets/models/medusa/medusa_occhio.tres"),
		"M_orbita": load("res://assets/models/medusa/medusa_orbita_bagnata.tres"),
		"M_pelle": load("res://assets/models/medusa/medusa_pelle_bagnata.tres"),
		"M_tentacoli": load("res://assets/models/medusa/medusa_tentacoli_bagnata.tres"),
	}
	lei.animazioni_inseguimento = true
	lei.animazione = StringName(ANIM + "insegue_aperta")
	lei.morbidezza = 1.0          # i tentacoli e la campana morbidi (MorbidezzaLei), accesi quando compare
	lei.visible = false
	add_child(lei)
	var luce := OmniLight3D.new()
	luce.light_color = ROSA
	luce.light_energy = 6.0
	luce.omni_range = 9.0
	luce.light_volumetric_fog_energy = 3.0
	luce.shadow_enabled = true
	luce.position = Vector3(0, 2.6, 0.9)
	luce.set_meta(&"risveglio_ignora", true)
	# (la sua luce rosa fa l'alone nella nebbia viola del tunnel prima delle lampade)
	luce.add_to_group(NebbiaViola.GRUPPO_ALONE)
	lei.add_child(luce)
	# il viso: lì il getto la fa ritrarre (segue l'occhio a ogni fotogramma)
	_viso = WaterHitbox.new()
	_viso.name = "Viso"
	var cs := CollisionShape3D.new()
	var sf := SphereShape3D.new()
	sf.radius = 0.9
	cs.shape = sf
	_viso.add_child(cs)
	_viso.position = Vector3(0, 4.6, 0.5)
	lei.add_child(_viso)
	_viso.water_hit.connect(_su_getto)
	if not Engine.has_meta(&"morbidezza_spenta"):
		morbidezza = MorbidezzaLei.su(lei)
	_ap = lei.get_model_instance().find_child("AnimationPlayer", true, false) as AnimationPlayer \
			if lei.get_model_instance() else null


## La disegna una volta fuori vista mentre il tunnel si prepara (RiscaldamentoShader.disegna_a_pezzi: un pezzo per
## fotogramma sullo strato di preparazione, nella sua luce rosa con le ombre), anche le parti che compaiono dopo (la
## bocca dei morsi) e nelle pose della riemersione, dell'inseguimento, della presa e della ritratta: quando riemerge
## alle spalle del giocatore non compila più niente (prima 16 "draw" in un fotogramma, misura_tunnel_lei del 28
## ottobre). Alla fine torna com'era: nascosta, nella posa dell'inseguimento.
func prepara(principale: Viewport) -> void:
	if lei == null or principale == null or not is_inside_tree() or DisplayServer.get_name() == "headless":
		return
	var nascosti: Array[GeometryInstance3D] = []
	for g in lei.find_children("*", "GeometryInstance3D", true, false):
		if not (g as GeometryInstance3D).visible:
			nascosti.append(g)
			(g as GeometryInstance3D).visible = true
	var era := lei.visible
	lei.visible = true
	var pose := func() -> void:
		for nome in ["riemerge", "insegue_aperta", "presa", "ritrae"]:
			_anima(nome, 0.0)
			for i in 2:
				await get_tree().process_frame
		await _giro_nella_sua_luce(principale)
	await RiscaldamentoShader.disegna_a_pezzi(self, principale, 2, Callable(), pose)
	if not is_instance_valid(lei):
		return
	lei.visible = era
	for g in nascosti:
		if is_instance_valid(g):
			g.visible = false
	_anima("insegue_aperta", 0.0)


## Il giro nella sua luce, come agli oblò (ObloLei.giro_nella_sua_luce di mascotte): lei nel canale a metà tunnel, con
## la sua luce rosa accesa (sullo strato di preparazione), e una camera fuori schermo che vede tutti gli strati dalla
## banchina, davanti e dietro, e da lei verso i muri, l'acqua e la volta. Così muri, banchine e acqua compilano adesso
## la variante con la sua luce (dopo la sola preparazione a pezzi restavano 6 "draw" quando riemergeva, test del 28
## ottobre). Poi torna dov'era.
func _giro_nella_sua_luce(principale: Viewport, fotogrammi := 2) -> void:
	var sala := get_parent() as SalaSottomarino
	if sala == null or not is_inside_tree():
		return
	var era := global_transform
	var s := minf(60.0, sala.lunghezza() * 0.5)
	var p := sala.punto(s)
	p.y = sala.acqua
	global_position = sala.to_global(p) + Vector3.UP * QUOTA
	var sv := SubViewport.new()
	sv.name = "PreparaLeiTunnel"
	sv.size = Vector2i(320, 180)
	RiscaldamentoShader.copia_viewport(sv, principale)
	sv.world_3d = principale.find_world_3d()
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var cam := Camera3D.new()
	var cam_gioco := principale.get_camera_3d()
	if cam_gioco:
		cam.environment = cam_gioco.environment
		cam.attributes = cam_gioco.attributes
		cam.fov = cam_gioco.fov
	sv.add_child(cam)
	add_child(sv)
	cam.current = true
	var viso := global_position + Vector3.UP * 4.0
	var punti: Array = []
	for ds: float in [8.0, 3.0, -6.0]:
		for lato: float in [-1.0, 1.0]:
			var q := sala.punto(s + ds)
			punti.append([sala.to_global(sala._al(q, sala.destra(s + ds), Vector2(lato * (sala.canale + sala.banchina * 0.5), sala.piano + 1.6))), viso])
	for d: Vector3 in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT, Vector3.DOWN, Vector3.UP]:
		punti.append([viso, viso + d])
	for pt in punti:
		var su := Vector3.UP if absf(((pt[1] as Vector3) - (pt[0] as Vector3)).normalized().y) < 0.9 else Vector3.FORWARD
		cam.look_at_from_position(pt[0], pt[1], su)
		for i in fotogrammi:
			await get_tree().process_frame
			if not is_inside_tree():
				sv.queue_free()
				return
	sv.queue_free()
	global_transform = era


## Risale dal canale nel punto [param pos] (sul pelo dell'acqua) guardando lungo [param verso], e comincia a
## inseguire. [param profondita]: quanto c'è d'acqua sotto (l'animazione parte da 5 m sotto: con meno parte già a
## metà salita, sempre con l'inizio sott'acqua).
func riemergi(pos: Vector3, verso: Vector3, profondita := 5.0) -> void:
	_dir = _orizzontale(verso, _dir)
	global_position = pos + Vector3.UP * QUOTA
	_pos_prima = global_position
	_orienta(0.0)
	lei.visible = true
	stato = Stato.RIEMERGE
	_t = 0.0
	_getto = 0.0
	if morbidezza:
		# l'acqua del canale (sotto il pelo i tentacoli fluttuano, sopra pendono e frustano)
		morbidezza.acqua_pianta = Rect2(-1e4, -1e4, 2e4, 2e4)
		morbidezza.acqua_pelo = pos.y
		morbidezza.quanto = 1.0
		morbidezza.accendi(true)
	_anima("riemerge", 0.0)
	var t0 := _quando_radice(&"riemerge", profondita)
	if t0 > 0.0 and _ap:
		_ap.seek(t0, true)
	_t = t0
	lei.attacca(0.9, &"")
	lei.segui_con_la_testa(0.0, 0.01)


## A ogni fotogramma mentre insegue: [param pos] il punto a centro canale sul pelo dell'acqua, [param verso] la
## direzione della strada (dove va lei). Si gira con calma verso la strada e in curva si inclina verso l'interno.
func vai(pos: Vector3, verso: Vector3, delta: float) -> void:
	if stato == Stato.VIA or stato == Stato.PRESA or stato == Stato.SCHIANTO:
		return
	var nuovo := pos + Vector3.UP * QUOTA
	if delta > 0.0:
		_velocita = lerpf(_velocita, (nuovo - _pos_prima).length() / delta, minf(1.0, delta * 4.0))
	_pos_prima = nuovo
	global_position = nuovo
	var voglio := _orizzontale(verso, _dir)
	var prima := _dir
	_dir = _dir.slerp(voglio, minf(1.0, delta * giro_rapidita)).normalized()
	# l'inclinazione in curva: come chi vira, dall'accelerazione di lato (velocità per quanto gira al secondo), un
	# poco di più perché si legga
	var giro := prima.signed_angle_to(_dir, Vector3.UP) / maxf(delta, 1e-4)
	var vuole := rad_to_deg(atan(_velocita * giro / 9.8)) * 1.5
	_virata = lerpf(_virata, clampf(vuole, -virata_max, virata_max), minf(1.0, delta * 3.0))
	_orienta(clampf(_velocita / 6.0, 0.0, 1.0) * avanti_max)


## Il getto in faccia: si ritrae strizzando l'occhio per 2 s (animazione "ritrae"), poi riprende a inseguire. La
## distanza (indietro di circa 6 m) la decide chi la comanda.
func respinta() -> void:
	if stato != Stato.INSEGUE:
		return
	stato = Stato.RITRAE
	_t = 0.0
	_anima("ritrae", 0.1)
	lei.chiudi_occhio(0.9)


## Ti prende (sotto i 2,5 m): la presa dell'inseguimento, rivolta verso di te.
func prendi() -> void:
	if stato == Stato.PRESA or stato == Stato.VIA:
		return
	stato = Stato.PRESA
	_t = 0.0
	var p := GameState.player
	if p and is_instance_valid(p):
		_dir = _orizzontale(p.global_position - global_position, _dir)
		_virata = 0.0
		_orienta(0.0)
	lei.segui_con_la_testa(0.0, 0.1)
	_anima("presa", 0.15)
	lei.attacca(0.4, &"")
	lei.add_to_group(&"medusa_che_prende")
	GameState.kill_player(&"medusa")


## Il portello chiuso: arriva lanciata e sbatte la faccia sull'oblò ([param centro_oblo], il centro del vetro dalla
## sua parte; [param normale]: la normale del portello verso di lei), i palmi ai lati; poi resta premuta.
func schianto(centro_oblo: Vector3, normale: Vector3) -> void:
	if stato == Stato.PRESA:
		return
	var n := _orizzontale(normale, -_dir)
	_dir = -n
	_virata = 0.0
	global_position = centro_oblo + n * OBLO.x - Vector3.UP * OBLO.y
	_orienta(0.0)
	lei.visible = true
	stato = Stato.SCHIANTO
	_t = 0.0
	lei.segui_con_la_testa(0.0, 0.1)
	_anima("schianto", 0.12)


## Vero mentre si ritrae dal getto (2 s).
func in_ritrae() -> bool:
	return stato == Stato.RITRAE


## Nasconde lei (per i checkpoint: si riparte con riemergi).
func via() -> void:
	stato = Stato.VIA
	lei.visible = false
	if morbidezza:
		morbidezza.azzera()


func _process(delta: float) -> void:
	if stato == Stato.VIA:
		return
	_t += delta
	var occhio := lei.get_eye_position()
	if occhio != Vector3.ZERO:
		_viso.global_position = occhio
	match stato:
		Stato.RIEMERGE:
			if _t >= _durata(&"riemerge"):
				_insegui()
		Stato.INSEGUE:
			_morsi()
		Stato.RITRAE:
			if _t >= _durata(&"ritrae"):
				_insegui()
		Stato.SCHIANTO:
			if _t - delta < SCHIANTO_CONTRO and _t >= SCHIANTO_CONTRO:
				schianto_contro.emit()
			if _t - delta < _durata(&"schianto") and _t >= _durata(&"schianto"):
				schianto_finito.emit()


func _insegui() -> void:
	stato = Stato.INSEGUE
	_t = 0.0
	_getto = 0.0
	_anima("insegue_aperta", 0.0)
	lei.segui_con_la_testa(1.0, 0.5)


## Vicina al giocatore morde a vuoto: lo stesso ciclo con i morsi, alla stessa posizione (così non scatta).
func _morsi() -> void:
	var p := GameState.player
	if p == null or not is_instance_valid(p) or _ap == null:
		return
	var vuole := &"insegue_morde" if global_position.distance_to(p.global_position) < vicina else &"insegue_aperta"
	if vuole != _anim:
		var pos := _ap.current_animation_position
		_anima(String(vuole), 0.0)
		_ap.seek(pos, true)


func _su_getto(litri: float, _p: Vector3, _d: Vector3) -> void:
	if stato != Stato.INSEGUE:
		return
	_getto += litri
	if _getto >= getto_litri:
		_getto = 0.0
		getto_in_faccia.emit()


func _anima(nome: String, sfuma: float) -> void:
	if _ap == null:
		return
	_anim = StringName(nome)
	_ap.play(StringName(ANIM + nome), sfuma)


func _durata(nome: StringName) -> float:
	var a := _ap.get_animation(StringName(ANIM + nome)) if _ap else null
	return a.length if a else 1.0


## Il primo tempo dell'animazione [param anim] in cui la radice è a meno di [param sotto] metri sotto la sua quota
## finale (come SalaInseguimento._quando_radice): con 5 m o più, l'inizio.
func _quando_radice(anim: StringName, sotto: float) -> float:
	var a := _ap.get_animation(StringName(ANIM + anim)) if _ap else null
	if a == null or sotto >= 4.99:
		return 0.0
	for i in a.get_track_count():
		if a.track_get_type(i) == Animation.TYPE_POSITION_3D and String(a.track_get_path(i)).ends_with(":radice"):
			var n := a.track_get_key_count(i)
			var rif: float = (a.track_get_key_value(i, n - 1) as Vector3).y
			for k in n:
				if (a.track_get_key_value(i, k) as Vector3).y >= rif - sotto:
					return a.track_get_key_time(i, k)
	return 0.0


## La direzione [param v] in orizzontale e di lunghezza 1 ([param altrimenti] se è troppo corta).
static func _orizzontale(v: Vector3, altrimenti: Vector3) -> Vector3:
	v.y = 0.0
	return v.normalized() if v.length() > 1e-3 else altrimenti


## Lei guarda lungo _dir (il modello guarda verso +Z), inclinata in curva di _virata gradi (positivo: gira a sinistra,
## la testa va verso la sua sinistra, +X) e in avanti di [param avanti] gradi.
func _orienta(avanti: float) -> void:
	var b := Basis.looking_at(_dir, Vector3.UP, true)
	b = b * Basis(Vector3.BACK, deg_to_rad(-_virata)) * Basis(Vector3.RIGHT, deg_to_rad(avanti))
	global_basis = b
