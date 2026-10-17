class_name AgnellinoScala
extends Node3D
## L'apparizione dei bambini sulla strada di risalita (tappa 7 B, scelta dell'utente del 17 ottobre: la 1).
## Col blackout, quando il giocatore sale la rampa F2 verso il pianerottolo davanti alla grata, un agnellino
## compare in cima alla scala del corridoio C2 (non si vede ancora: è dietro l'angolo). Fermo a guardarti;
## quando lo guardi inclina la testa; se ti avvicini scappa lungo il corridoio e sparisce dietro l'angolo
## di C3. Succede una volta sola (anche ripartendo da un checkpoint).
## Le posizioni sono nelle coordinate del genitore (la scena dei tecnici).

const AGNELLO := preload("res://scenes/creature/bambino_agnello.tscn")

## Falso: non compare.
@export var attivo := true
## Dove sta: in cima alla scala di C2, piedi a terra.
@export var posizione := Vector3(44.55, 9.05, 1.6)
## Verso dove guarda (il pianerottolo davanti alla grata, da dove arriva il giocatore).
@export var guarda_verso := Vector3(44.55, 7.25, -7.0)
## Compare quando il giocatore è più vicino di [member raggio_innesco] a questo punto (in cima alla rampa F2).
@export var innesco := Vector3(46.0, 7.25, -7.8)
@export var raggio_innesco := 3.0
## Dove scappa: giù per C2 e dietro l'angolo di C3.
@export var punti_fuga := PackedVector3Array([Vector3(44.55, 9.05, 7.0), Vector3(44.55, 9.05, 14.9), Vector3(41.84, 9.05, 15.0)])
@export var distanza_fuga := 3.6

var bambino: Bambino
var _fatto := false


func _ready() -> void:
	add_to_group(&"persist")


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
	bambino = AGNELLO.instantiate() as Bambino
	bambino.name = "Agnellino"
	bambino.modalita = Bambino.Modalita.STATUA
	bambino.reazione = Bambino.Reazione.INCLINA_TESTA
	bambino.tempo_per_vederlo = 0.5
	bambino.distanza_fuga = distanza_fuga
	bambino.scappa_con_la_torcia = false
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


func save_state() -> Dictionary:
	return {"fatto": _fatto}


func load_state(s: Dictionary) -> void:
	_fatto = _fatto or bool(s.get("fatto", false))   # una volta sola: ripartendo da prima non ricompare
	if _fatto and bambino and is_instance_valid(bambino):
		bambino.queue_free()
