class_name AgnellinoScala
extends Node3D
## L'apparizione dei bambini sulla strada di risalita (tappa 7 B, scelta dell'utente del 17 ottobre: la 1).
## Col blackout, quando il giocatore sale la rampa F2 verso il pianerottolo davanti alla grata, un agnellino
## compare in cima alla scala del corridoio C2 (non si vede ancora: è dietro l'angolo). Fermo a guardarti;
## quando lo guardi inclina la testa; se ti avvicini scappa lungo il corridoio e si infila in una grata di
## ventilazione sfondata alla base del muro di C2, troppo bassa per seguirlo; dentro è buio e lo si sente correre
## via nel condotto. Corre piano, con le zampe a tempo (v0.3.6: "sgambetta come una pazza, facciamo che invece
## corre piano ed entra in un buco nel muro invece che sparire"): parte abbastanza presto da infilarsi nel buco
## prima che il giocatore, anche correndo, lo raggiunga. Succede una volta sola (anche ripartendo da un
## checkpoint).
## Le posizioni sono nelle coordinate del genitore (la scena dei tecnici).

const AGNELLO := preload("res://scenes/creature/bambino_agnello.tscn")

## Falso: non compare.
@export var attivo := true
## La scena dell'agnellino (vuota: quello di serie). Per le proposte, per esempio quello fluorescente.
@export var scena: PackedScene
## Dove sta: in cima alla scala di C2, piedi a terra.
@export var posizione := Vector3(44.55, 9.05, 1.6)
## Verso dove guarda (il pianerottolo davanti alla grata, da dove arriva il giocatore).
@export var guarda_verso := Vector3(44.55, 7.25, -7.0)
## Compare quando il giocatore è più vicino di [member raggio_innesco] a questo punto (in cima alla rampa F2).
@export var innesco := Vector3(46.0, 7.25, -7.8)
@export var raggio_innesco := 3.0
## Dove scappa: lungo C2, nella corsia libera tra la roba accatastata ai due muri, poi si gira e si infila nella
## grata sfondata del muro sud (il buco è largo 0,85 m e alto 0,9, centrato in z = [member buco_z], davanti
## l'arredo lascia il varco: vedi tools/blender/ambienti2_raccordo.py e tappa7_arredo.py) fino in fondo alla
## cavità, dove sparisce al buio.
@export var punti_fuga := PackedVector3Array([Vector3(44.4, 9.05, 4.3), Vector3(44.4, 9.05, 4.9), Vector3(46.6, 9.05, 4.9)])
## Il muro col buco (x della faccia sul corridoio) e il centro del buco.
@export var muro_x := 45.5
@export var buco_z := 4.9
@export var distanza_fuga := 7.0
## Quanto corre (il giocatore corre a 5,8 m/s): l'animazione di corsa va a tempo con questa velocità.
@export var velocita_corsa := 3.0
## Per entrare nel buco si piega in avanti fino a tanto, cominciando a [member piega_da] m dal muro e finendo
## a [member piega_a] m (misurati dai piedi): così la testa passa sotto il bordo del buco.
@export var piega_max := 75.0
@export var piega_da := 1.15
@export var piega_a := 0.75

var bambino: Bambino
var _fatto := false


func _ready() -> void:
	add_to_group(&"persist")
	process_priority = 10   # dopo il bambino (che si sposta nel suo _process): la piega vale per il fotogramma


func _process(_delta: float) -> void:
	if bambino and is_instance_valid(bambino) and bambino.modalita == Bambino.Modalita.SCAPPA:
		_piega()


## Per infilarsi nel buco si piega in avanti (perno ai piedi) e si alza un po', così i piedi non entrano nel
## pavimento; solo quando corre verso il muro, nella striscia davanti al buco.
func _piega() -> void:
	var genitore := get_parent() as Node3D
	var l := genitore.to_local(bambino.global_position)
	var k := 0.0
	if absf(l.z - buco_z) < 0.6:
		k = clampf((piega_da - (muro_x - l.x)) / (piega_da - piega_a), 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)
	if k > 0.0:   # mentre si piega si mette dritto verso il buco (girandosi da solo arriverebbe di sbieco)
		var dentro := genitore.global_basis * Vector3(1, 0, 0)
		bambino.rotation.y = lerp_angle(bambino.rotation.y, atan2(dentro.x, dentro.z), minf(1.0, k * 4.0))
	bambino.rotation.x = deg_to_rad(piega_max) * k
	# l'alzata va sui modelli: il nodo segue i punti di fuga (all'altezza del pavimento) e deve arrivarci
	var su := bambino.global_basis.inverse() * Vector3.UP * (0.12 * k)
	for nome in [^"Calmo", ^"Rivelato"]:
		var m := bambino.get_node_or_null(nome) as Node3D
		if m:
			m.position = su


func _physics_process(_delta: float) -> void:
	if _fatto or not attivo or GameState.luci != GameState.Luci.BLACKOUT:
		return
	var p := GameState.player
	if p == null or not is_instance_valid(p):
		return
	var genitore := get_parent() as Node3D
	if p.global_position.distance_to(genitore.to_global(innesco)) < raggio_innesco:
		compari()


## Fa comparire l'agnellino (una volta sola).
func compari() -> void:
	if _fatto:
		return
	_fatto = true
	var genitore := get_parent() as Node3D
	bambino = (scena if scena else AGNELLO).instantiate() as Bambino
	bambino.name = "Agnellino"
	bambino.modalita = Bambino.Modalita.STATUA
	bambino.reazione = Bambino.Reazione.INCLINA_TESTA
	bambino.tempo_per_vederlo = 0.5
	bambino.distanza_fuga = distanza_fuga
	bambino.velocita_corsa = velocita_corsa
	bambino.sparisce_fuori_vista = false   # sparisce in fondo alla cavità, al buio
	bambino.sparito.connect(_corre_nel_muro)
	var da := genitore.to_global(posizione)
	var dir := (da - genitore.to_global(guarda_verso)) * Vector3(1, 0, 1)
	bambino.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), da)   # la faccia (+Z) verso il giocatore
	var fuga: Array[Node3D] = []
	for v in punti_fuga:
		var m := Marker3D.new()
		m.top_level = true
		add_child(m)
		m.global_position = genitore.to_global(v)
		fuga.append(m)
	bambino.punti_fuga = fuga
	bambino.top_level = true
	add_child(bambino)


## Dentro il muro: le zampette che si allontanano nel condotto.
func _corre_nel_muro() -> void:
	var genitore := get_parent() as Node3D
	Audio.suona(&"zampette_condotto", genitore.to_global(Vector3(muro_x + 0.9, posizione.y + 0.3, buco_z)))


func save_state() -> Dictionary:
	return {"fatto": _fatto}


func load_state(s: Dictionary) -> void:
	_fatto = _fatto or bool(s.get("fatto", false))   # una volta sola: ripartendo da prima non ricompare
	if _fatto and bambino and is_instance_valid(bambino):
		bambino.queue_free()
