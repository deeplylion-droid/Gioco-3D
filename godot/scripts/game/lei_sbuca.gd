class_name LeiSbuca
extends Node3D
## Tappa 8 di docs/livello/capitolo1.md, "lei sbuca dal bordo" (concept medusa_sbircia.jpg). Dopo
## il risveglio (GameState.luci = BLACKOUT) la scia di bava porta all'area bimbi: le vasche basse
## si stanno riempiendo dalla fossa (lo scarico di compensazione rotto, attaccato alla VascaBimbi1)
## e lei è già affacciata al bordo quando arrivi: le mani sulle piastrelle, l'occhio fisso su di te
## (riscontro sulla v0.3.1: "doveva già essere lì quando io arrivo"). Prima sbucava quando ti
## avvicinavi, ma solo con l'acqua già alta: arrivando presto dalla sala pompe l'acqua non c'era,
## lei restava sotto finché non le eri addosso e allora sbucava e ti prendeva subito; ripartendo dal
## checkpoint, vicino alla fossa, l'acqua saliva in fretta e la si vedeva.
## - Resta affacciata finché non l'hai vista bene: nell'inquadratura, vicino al centro, senza niente
##   in mezzo ed entro [member distanza_vista], per [member tempo_vista] secondi di fila (riscontro
##   dell'utente sulla v0.3.0: "non l'ho vista, forse mi sono allontanato ed è sparita?").
## - Solo dopo, se resti lontano, passati [member attesa] secondi scivola sotto e la sua luce si
##   allontana sott'acqua lungo il condotto in fondo alla fossa (concept medusa_sottacqua.jpg).
## - Se le arrivi troppo vicino ([member distanza_presa]) o la tocchi, ti prende: la fauce si apre,
##   l'occhio si riempie di vene e parte la sequenza di morte (GameState.kill_player(&"medusa")).
##   Si riparte dal checkpoint prima della scena e la scena si ripete. Mentre ti prende si gira verso
##   di te, da qualsiasi lato arrivi (prima la camera la trovava di traverso).
## - Scivola sotto all'indietro: prima si stacca dal bordo (si alza di scatto, così mani e tentacoli
##   appoggiati fuori dal bordo lo superano, e arretra sopra l'acqua della fossa), poi va giù e intanto
##   svanisce nell'acqua torbida, prima che i tentacoli stesi oltre il bordo arrivino al pavimento
##   (prima scendeva dritta e mani e tentacoli passavano attraverso il bordo e il pavimento). Nella
##   fossa i tentacoli non ci stanno: senza un'animazione che li ritiri, svanire è il modo per non
##   farli entrare nel pavimento.
## La fossa (con i marker medusa_sbuca, medusa_fuga, livello_acqua_pieno e il coperchio) la fa
## l'ambiente. Le animazioni nuove (sbuca, scivola sotto, via sott'acqua, afferra) le fa l'agente
## medusa: per ora la posa è "affacciata" e il resto lo fa il codice (sale, scende, la luce).

signal sbucata
## Il giocatore l'ha vista bene (da qui parte l'attesa prima che scivoli sotto).
signal vista
signal andata_via
signal presa

enum Fase {ATTESA, SBUCA, GUARDA, SCIVOLA, FUGA, FINITA, PRESA}

## La medusa (MedusaAffacciata): nascosta fino al blackout, poi affacciata.
@export var medusa: Node3D
## Dove sbuca: l'origine della posa "affacciata", rivolta verso il giocatore (+Z locale).
@export var punto_sbuca: Node3D
## In fondo al condotto della fossa: lì la sua luce si perde.
@export var punto_fuga: Node3D
## Il coperchio di collisione della fossa: acceso, così non ci si cade dentro.
@export var coperchio: CollisionObject3D
## Le vasche che si riempiono (WaterTank) e la loro acqua (WaterTankLink, per gli schizzi): la
## prima è la VascaBimbi1, quella della fossa.
@export var vasche: Array[Node3D] = []
@export var acque: Array[Node3D] = []
## La superficie dell'acqua della fossa (la pianta con l'angolo tagliato): stessa acqua della
## prima vasca, alla sua quota e col suo materiale.
@export var superficie_fossa: MeshInstance3D
## Quota del pelo dell'acqua quando le vasche sono piene (marker livello_acqua_pieno).
@export var livello_pieno := 0.43
## Velocità con cui sale l'acqua (m/s): piano da quando ripartono le pompe, più in fretta quando
## il giocatore arriva nell'area bimbi (a meno di [member distanza_riempimento] dalla fossa).
@export var velocita_lenta := 0.0008
@export var velocita_riempimento := 0.006
@export var distanza_riempimento := 16.0
## Quando lei si affaccia l'acqua della fossa è almeno a questa quota (la posa vuole il pelo 0,88 m
## sopra la sua origine: con un po' di margine il seno resta coperto, come vuole il GDD). Al blackout
## le pompe ripartono e la fossa ci arriva subito; poi sale piano fino a [member livello_pieno].
@export var pelo_minimo := 0.37
## Più vicino di così al suo occhio (in pianta) ti prende.
@export var distanza_presa := 2.4
## Secondi che ti guarda, dopo che l'hai vista bene, prima di scivolare sotto (se resti lontano).
@export var attesa := 6.0
@export_group("Vederla bene")
## Secondi di fila in cui la devi avere nell'inquadratura perché conti come vista.
@export var tempo_vista := 2.0
## Angolo massimo (gradi) tra il centro dello schermo e il suo occhio.
@export var angolo_vista := 18.0
## Distanza massima (m) dai tuoi occhi al suo.
@export var distanza_vista := 14.0
## Uno sguardo interrotto per meno di così (s) non fa ripartire il conto.
@export var tolleranza_vista := 0.3
@export_group("")
@export var durata_sbuca := 1.8
@export var durata_scivola := 1.6
## Scivolando sotto: quanto si alza e quanto arretra (m) per staccarsi dal bordo prima di scendere,
## in che parte della discesa (0..1) lo fa, e in che parte della discesa vera e propria svanisce.
@export var scivola_su := 0.5
@export var scivola_indietro := 0.5
@export var scivola_stacco := 0.45
@export var scivola_svanisce := 0.5
## Mentre ti prende si gira verso di te in questi secondi.
@export var durata_girata := 0.2
@export var durata_fuga := 4.5
## Quanto sotto il punto in cui sbuca sta, prima di salire (e dopo essere scivolata giù).
@export var profondita := 2.3
## Falso finché la fossa non c'è: niente scena, niente acqua che sale.
@export var abilitata := true
## Quando scivola sotto, un geyser d'acqua (GeyserFossa) si alza dalla fossa e la copre tutta: lei
## sparisce solo quando è coperta (scelta dell'utente del 17 ottobre). Falso: scivola e svanisce come
## prima.
@export var geyser := true

var fase := Fase.ATTESA
var _t := 0.0
## Secondi di fila in cui la stai guardando (fino a [member tempo_vista]).
var vista_t := 0.0
## Vero quando l'hai vista bene: parte l'attesa prima che scivoli sotto.
var vista_bene := false
var _non_vista_t := 0.0
var _luce: OmniLight3D
var _tocco: Area3D
var _prossima_bolla := 0.0
var _rng := RandomNumberGenerator.new()
var _geyser: GeyserFossa


func _ready() -> void:
	add_to_group(&"persist")
	_rng.seed = 8
	GameState.luci_cambiate.connect(_on_luci)
	_nascondi()
	if coperchio:
		coperchio.collision_layer = Layers.WORLD
	if medusa:
		# Toccarla vuol dire farsi prendere: un'area intorno a testa, spalle e mani.
		_tocco = Area3D.new()
		_tocco.name = "Tocco"
		_tocco.collision_layer = 0
		_tocco.collision_mask = Layers.PLAYER
		_tocco.monitorable = false
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.9, 1.3, 1.2)
		cs.shape = box
		cs.position = Vector3(0.0, 1.35, 1.75)
		_tocco.add_child(cs)
		medusa.add_child(_tocco)
		_tocco.body_entered.connect(func(b: Node3D):
			if b is Player and (fase == Fase.GUARDA or fase == Fase.SBUCA):
				_prendi())


func _process(_delta: float) -> void:
	if superficie_fossa == null or vasche.is_empty() or not vasche[0] is WaterTank:
		return
	if superficie_fossa.material_override == null and acque.size() > 0 and acque[0] and "material" in acque[0]:
		superficie_fossa.material_override = acque[0].get(&"material")
	superficie_fossa.global_position.y = (vasche[0] as WaterTank).get_surface_global_y()


func _on_luci(f: GameState.Luci) -> void:
	# Ripartendo da prima del risveglio la scena torna in attesa.
	if f == GameState.Luci.PRIMA_DEL_RISVEGLIO and fase != Fase.ATTESA:
		_ricomincia()


func _physics_process(delta: float) -> void:
	if not abilitata or GameState.luci != GameState.Luci.BLACKOUT:
		return
	var p := GameState.player
	if p == null or not is_instance_valid(p) or GameState.is_dying:
		return
	_riempi(delta, p)
	_t += delta
	match fase:
		Fase.ATTESA:
			# Già affacciata quando arrivi: dal blackout (o ripartendo al buio) è sul bordo.
			if punto_sbuca:
				_affaccia()
		Fase.SBUCA:
			var k := clampf(_t / durata_sbuca, 0.0, 1.0)
			_metti_a(1.0 - _ease_out(k))
			_controlla_presa(p)
			_conta_vista(p, delta)
			if k >= 1.0:
				fase = Fase.GUARDA
				_t = 0.0
		Fase.GUARDA:
			_controlla_presa(p)
			if fase != Fase.GUARDA:
				return
			# Resta lì finché non l'hai vista bene: solo dopo parte l'attesa.
			if not vista_bene:
				_conta_vista(p, delta)
				_t = 0.0
			elif _t >= attesa:
				_scivola()
		Fase.SCIVOLA:
			if _geyser and _geyser.in_corso():
				# Col geyser resta ferma e si vede tutta finché l'acqua non la copre, poi sparisce lì dentro.
				if _t >= _geyser.copre:
					_fuga()
				return
			var k := clampf(_t / durata_scivola, 0.0, 1.0)
			_scivola_a(k)
			if k < 0.35:
				_controlla_presa(p)
			# Appena tutta sott'acqua sparisce: nell'acqua torbida resta solo la sua luce.
			if k >= 1.0 or (k > scivola_stacco and _testa_sotto()):
				_fuga()
		Fase.FUGA:
			var k := clampf(_t / durata_fuga, 0.0, 1.0)
			if _luce and punto_sbuca and punto_fuga:
				var da := punto_sbuca.global_position + Vector3(0.0, 0.2 - profondita * 0.6, 0.0)
				_luce.global_position = da.lerp(punto_fuga.global_position, _ease_out(k))
				_luce.light_energy = lerpf(2.6, 0.0, k * k)
			if k >= 1.0:
				_finita()


## Le vasche basse si riempiono dalla fossa: piano da quando ripartono le pompe, poi, quando
## arrivi, il livello sale davanti a te.
func _riempi(delta: float, p: Player) -> void:
	if punto_sbuca == null:
		return
	var vicino := _in_pianta(p.global_position, punto_sbuca.global_position) < distanza_riempimento
	var velocita := velocita_riempimento if vicino else velocita_lenta
	var sale := false
	for v in vasche:
		var tank := v as WaterTank
		if tank == null:
			continue
		var fondo := tank.get_floor_global_y()
		var target := clampf((livello_pieno - fondo) / maxf(tank.inner_size.y, 0.01), 0.0, tank.max_fill)
		if tank.fill < target - 0.0005:
			tank.fill = minf(tank.fill + velocita * delta / maxf(tank.inner_size.y, 0.01), target)
			sale = true
	# L'acqua risale ribollendo dalla fossa.
	_prossima_bolla -= delta
	if sale and vicino and _prossima_bolla <= 0.0 and acque.size() > 0:
		_prossima_bolla = _rng.randf_range(0.25, 0.7)
		var a := acque[0]
		if a and a.has_method(&"splash"):
			var c := punto_sbuca.global_position + punto_sbuca.global_basis.z * 0.6
			c += Vector3(_rng.randf_range(-0.6, 0.6), 0.0, _rng.randf_range(-0.6, 0.6))
			a.call(&"splash", c, _rng.randf_range(0.08, 0.2))


## Conta i secondi di fila in cui la stai guardando bene; arrivato a [member tempo_vista] è vista.
func _conta_vista(p: Player, delta: float) -> void:
	if vista_bene:
		return
	if la_stai_guardando(p):
		vista_t += delta
		_non_vista_t = 0.0
	else:
		_non_vista_t += delta
		if _non_vista_t > tolleranza_vista:
			vista_t = 0.0
	if vista_t >= tempo_vista:
		vista_bene = true
		vista.emit()


## Vero se in questo momento lei è nell'inquadratura del giocatore, vicino al centro, entro
## [member distanza_vista] e senza muri od oggetti in mezzo.
func la_stai_guardando(p: Player) -> bool:
	if medusa == null or not medusa.visible or p.camera == null:
		return false
	var occhio: Vector3 = medusa.call(&"get_eye_position") if medusa.has_method(&"get_eye_position") else medusa.global_position
	var da := p.camera.global_position
	var verso := occhio - da
	var dist := verso.length()
	if dist > distanza_vista or dist < 0.05:
		return false
	if rad_to_deg((-p.camera.global_basis.z).angle_to(verso)) > angolo_vista:
		return false
	# Niente in mezzo: raggi dagli occhi fin quasi al suo viso (lei non ha collisioni). Ne basta
	# uno libero su tre (occhio e 12 cm ai lati), così un cavo o una sbarra sottile non contano,
	# ma una colonna o un muro davanti al viso sì.
	var space := p.get_world_3d().direct_space_state
	var lato := verso.cross(Vector3.UP).normalized() * 0.12
	for dx in [Vector3.ZERO, lato, -lato]:
		var punto: Vector3 = occhio + dx
		var q := PhysicsRayQueryParameters3D.create(da, punto - (punto - da).normalized() * 0.15, Layers.WORLD | Layers.PROPS, [p.get_rid()])
		if space.intersect_ray(q).is_empty():
			return true
	return false


## Lei è già sul bordo della fossa, affacciata, senza la salita né il suono di quando sbuca: la fossa
## arriva subito almeno a [member pelo_minimo]. Ti segue con l'occhio e aspetta che la guardi bene.
func _affaccia() -> void:
	var tank := vasche[0] as WaterTank if vasche.size() > 0 else null
	if tank:
		var minimo := clampf((minf(pelo_minimo, livello_pieno) - tank.get_floor_global_y()) / maxf(tank.inner_size.y, 0.01), 0.0, tank.max_fill)
		if tank.fill < minimo:
			tank.fill = minimo
	fase = Fase.GUARDA
	_t = 0.0
	vista_t = 0.0
	vista_bene = false
	_non_vista_t = 0.0
	medusa.visible = true
	medusa.process_mode = Node.PROCESS_MODE_INHERIT
	_metti_a(0.0)
	_svanisci(0.0)
	medusa.reset_physics_interpolation()


func _sbuca() -> void:
	fase = Fase.SBUCA
	_t = 0.0
	vista_t = 0.0
	vista_bene = false
	_non_vista_t = 0.0
	medusa.visible = true
	medusa.process_mode = Node.PROCESS_MODE_INHERIT
	_metti_a(1.0)
	_svanisci(0.0)
	_schizzo(1.4)
	_suona(&"lei_sbuca")
	sbucata.emit()


func _scivola() -> void:
	fase = Fase.SCIVOLA
	_t = 0.0
	_schizzo(0.8)
	if geyser and punto_sbuca:
		if _geyser == null:
			_geyser = GeyserFossa.new()
			_geyser.name = "Geyser"
			add_child(_geyser)
		# Sul pavimento (l'origine della posa), al centro della fossa davanti al bordo.
		# Getti più piccoli anche sui suoi tentacoli stesi oltre il bordo (i punti delle gocce).
		var punti := PackedVector3Array()
		if medusa and "punti_gocce" in medusa:
			for q in medusa.get(&"punti_gocce"):
				punti.append(medusa.global_transform * q)
		_geyser.scoppia(punto_sbuca.global_transform * Vector3(0.0, 0.0, 1.5), acque, punti)
		_suona(&"lei_esplosione")
	else:
		_suona(&"lei_scivola_sotto")


## Sotto: la medusa sparisce e resta la sua luce, che si allontana lungo il condotto.
func _fuga() -> void:
	fase = Fase.FUGA
	_t = 0.0
	_nascondi()
	_luce = OmniLight3D.new()
	_luce.name = "LuceSottacqua"
	_luce.light_color = Color(1.0, 0.45, 0.75)
	_luce.light_energy = 2.6
	_luce.omni_range = 4.5
	_luce.shadow_enabled = false
	_luce.set_meta(&"risveglio_ignora", true)
	add_child(_luce)
	if punto_sbuca:
		_luce.global_position = punto_sbuca.global_position + Vector3(0.0, 0.2 - profondita * 0.6, 0.0)


func _finita() -> void:
	fase = Fase.FINITA
	if is_instance_valid(_luce):
		_luce.queue_free()
	_luce = null
	andata_via.emit()


func _prendi() -> void:
	if fase == Fase.PRESA:
		return
	fase = Fase.PRESA
	_metti_a(0.0)
	_svanisci(0.0)
	_girati_verso(GameState.player)
	if medusa.has_method(&"attacca"):
		medusa.call(&"attacca")
	medusa.add_to_group(&"medusa_che_prende")
	presa.emit()
	GameState.kill_player(&"medusa")


func _controlla_presa(p: Player) -> void:
	if medusa == null or not medusa.visible:
		return
	var occhio: Vector3 = medusa.call(&"get_eye_position") if medusa.has_method(&"get_eye_position") else medusa.global_position
	if _in_pianta(p.global_position, occhio) < distanza_presa:
		_prendi()


## Il pelo dell'acqua dove sbuca (la prima vasca: la fossa).
func _pelo() -> float:
	for v in vasche:
		if v is WaterTank:
			return (v as WaterTank).get_surface_global_y()
	return livello_pieno


## 0 = al suo posto sul bordo, 1 = giù nella fossa.
func _metti_a(giu: float) -> void:
	if medusa == null or punto_sbuca == null:
		return
	medusa.global_transform = punto_sbuca.global_transform.translated(Vector3.DOWN * profondita * giu)


## Scivola sotto ([param k] da 0 a 1): fino a [member scivola_stacco] si alza (prima) e arretra (poi)
## verso il centro della fossa, così mani e tentacoli passano sopra il bordo; poi scende sempre più in
## fretta e intanto svanisce: è trasparente del tutto a [member scivola_svanisce] della discesa, quando
## i tentacoli stesi oltre il bordo sono ancora sopra il pavimento.
func _scivola_a(k: float) -> void:
	if medusa == null or punto_sbuca == null:
		return
	var a := clampf(k / maxf(scivola_stacco, 0.01), 0.0, 1.0)
	var b := clampf((k - scivola_stacco) / maxf(1.0 - scivola_stacco, 0.01), 0.0, 1.0)
	var su := scivola_su * smoothstep(0.0, 0.35, a)
	var indietro := scivola_indietro * smoothstep(0.35, 1.0, a)
	var giu := profondita * b * b
	var xf := punto_sbuca.global_transform
	medusa.global_transform = Transform3D(xf.basis, xf.origin + Vector3.UP * (su - giu) - xf.basis.z.normalized() * indietro)
	_svanisci(smoothstep(0.0, maxf(scivola_svanisce, 0.01), b))


## Quanto è trasparente (0 si vede tutta, 1 non si vede più): GeometryInstance3D.transparency delle
## sue mesh.
func _svanisci(t: float) -> void:
	if medusa == null:
		return
	for m in medusa.find_children("*", "GeometryInstance3D", true, false):
		(m as GeometryInstance3D).transparency = t


## Quanto si vede adesso (1 tutta, 0 per niente).
func opacita() -> float:
	if medusa == null or not medusa.visible:
		return 0.0
	for m in medusa.find_children("*", "GeometryInstance3D", true, false):
		return 1.0 - (m as GeometryInstance3D).transparency
	return 1.0


## Vero quando la testa (fino alla cima dei capelli, 35 cm sopra l'occhio) è sotto il pelo dell'acqua.
func _testa_sotto() -> bool:
	if medusa == null or not medusa.has_method(&"get_eye_position"):
		return false
	return (medusa.call(&"get_eye_position") as Vector3).y + 0.35 < _pelo() - 0.05


## Mentre ti prende si gira verso di te, intorno alla verticale del suo occhio: così da qualsiasi
## lato arrivi la camera della sequenza di morte la trova di fronte.
func _girati_verso(p: Player) -> void:
	if p == null or not is_instance_valid(p) or medusa == null or punto_sbuca == null:
		return
	var testa := _testa_prevista()
	var verso := p.camera.global_position - testa
	verso.y = 0.0
	var avanti := punto_sbuca.global_basis.z
	avanti.y = 0.0
	if verso.length() < 0.05 or avanti.length() < 0.05:
		return
	var angolo := avanti.normalized().signed_angle_to(verso.normalized(), Vector3.UP)
	var da := medusa.global_transform
	# L'occhio resta fermo: si gira intorno alla sua verticale.
	var gira := func(k: float):
		if is_instance_valid(medusa):
			medusa.global_transform = Transform3D(Basis(Vector3.UP, angolo * k), testa) * Transform3D(Basis.IDENTITY, -testa) * da
	var tw := create_tween()
	tw.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_method(gira, 0.0, 1.0, maxf(durata_girata, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _nascondi() -> void:
	if medusa == null:
		return
	medusa.visible = false
	medusa.process_mode = Node.PROCESS_MODE_DISABLED
	medusa.remove_from_group(&"medusa_che_prende")


func _ricomincia() -> void:
	fase = Fase.ATTESA
	_t = 0.0
	vista_t = 0.0
	vista_bene = false
	_non_vista_t = 0.0
	_nascondi()
	if is_instance_valid(_luce):
		_luce.queue_free()
	_luce = null


## Dove sarà il suo occhio quando sbuca (prima che ci sia): sopra il bordo, davanti all'origine.
func _testa_prevista() -> Vector3:
	return punto_sbuca.global_transform * Vector3(0.0, 1.63, 1.8)


func _schizzo(forza: float) -> void:
	if punto_sbuca == null:
		return
	var c := punto_sbuca.global_transform * Vector3(0.0, 0.0, 1.4)
	for a in acque:
		if a and a.has_method(&"splash"):
			a.call(&"splash", c, forza)
			break


func _suona(nome: StringName, db := 0.0, tono := 1.0) -> void:
	var audio := get_node_or_null(^"/root/Audio")
	if audio and punto_sbuca:
		audio.call(&"suona", nome, punto_sbuca.global_position, db, tono)


static func _in_pianta(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


static func _ease_out(k: float) -> float:
	return 1.0 - pow(1.0 - k, 3.0)


func save_state() -> Dictionary:
	return {"finita": fase == Fase.FINITA}


func load_state(data: Dictionary) -> void:
	_ricomincia()
	if bool(data.get("finita", false)):
		fase = Fase.FINITA
