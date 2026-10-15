class_name Pompa
extends Node3D
## Una pompa della sala pompe (tappa 6): ferma, avviata dalla sua turbina (vibra piano e fuma
## un po') o, dopo la leva, che ruggisce (trema forte, vapore pieno). Fa vibrare il corpo del
## modello (POMPA_n) e il suo vapore. Lo stato si salva con i checkpoint.

signal stato_cambiato(stato: Stato)

enum Stato { FERMA, AVVIATA, RUGGISCE }

## Le parti del modello da far vibrare (per esempio Ambienti/SalaPompe/POMPA_1 e, per la blu,
## anche POMPA_3_modello).
@export var corpi: Array[NodePath] = []
## Dove esce il vapore (empty VAPORE_pompa_n del modello).
@export var vapore_path: NodePath
## Ampiezza della vibrazione (m) da avviata e quando ruggisce.
@export var tremito_avviata := 0.002
@export var tremito_ruggito := 0.007

var stato := Stato.FERMA

var _corpi: Array[Node3D] = []
var _riposi: Array[Vector3] = []
var _vapore: GPUParticles3D
var _t := 0.0


func _ready() -> void:
	add_to_group(&"persist")
	for c in corpi:
		var n := get_node_or_null(c) as Node3D
		if n:
			_corpi.append(n)
			_riposi.append(n.position)
	var punto := get_node_or_null(vapore_path) as Node3D
	if punto:
		var v := Vapore.new()
		v.name = "Vapore"
		v.portata = 0.8
		v.altezza = 1.6
		v.raggio = 0.12
		v.a_sbuffi = true
		v.emitting = false
		add_child(v)
		v.global_position = punto.global_position
		_vapore = v
	_aggiorna_vapore()


## La turbina l'ha avviata (nell'ordine giusto).
func avvia() -> void:
	_imposta(Stato.AVVIATA)


## Sequenza sbagliata: si ferma.
func ferma() -> void:
	_imposta(Stato.FERMA)


## La leva: tutte le pompe a pieno regime.
func ruggisci() -> void:
	_imposta(Stato.RUGGISCE)


func _imposta(s: Stato) -> void:
	if s == stato:
		return
	stato = s
	_aggiorna_vapore()
	if s == Stato.FERMA:
		for i in _corpi.size():
			_corpi[i].position = _riposi[i]
	stato_cambiato.emit(s)


func _aggiorna_vapore() -> void:
	if _vapore == null:
		return
	_vapore.emitting = stato != Stato.FERMA
	_vapore.a_sbuffi = stato == Stato.AVVIATA


func _process(delta: float) -> void:
	if _corpi.is_empty() or stato == Stato.FERMA:
		return
	_t += delta
	var a := tremito_ruggito if stato == Stato.RUGGISCE else tremito_avviata
	# Tre frequenze sovrapposte: un tremito meccanico, non un rumore bianco.
	var d := Vector3(sin(_t * 61.0) * a, sin(_t * 47.0 + 1.3) * a * 0.6, sin(_t * 53.0 + 0.4) * a)
	for i in _corpi.size():
		_corpi[i].position = _riposi[i] + d


func save_state() -> Dictionary:
	return {"stato": int(stato)}


func load_state(data: Dictionary) -> void:
	_imposta(clampi(int(data.get("stato", 0)), 0, Stato.RUGGISCE) as Stato)
