class_name AgnellinoPozze
extends Node
## L'agnellino nella stanza delle pozze (build 0.5.0, «La storia»: ostacola, e si sente soltanto). Una volta sola per
## partita, dopo il secondo colore che il giocatore toglie: zampette che corrono sotto il pavimento, un volantino che
## gira, poi il PRIMO colore tolto si riempie di nuovo e va svuotato ancora. L'agnellino non si vede. L'enigma si
## risolve allo stesso modo; le pozze riempite tornano acqua vera (lei può uscirne). Non comincia mentre lei è fuori:
## aspetta che sia tornata sotto. Figlio di EnigmaPozze, che lo crea.

## Spento: non succede niente (l'interruttore).
@export var attivo := true
## Dopo quanti colori tolti.
@export var dopo_colori := 2
## Quanto aspetta dopo il colore tolto prima delle zampette (s), quanto corrono, quanto gira il volantino.
@export var attesa := 2.0
@export var durata_zampette := 2.6
@export var durata_volantino := 1.8
## Quanto ci mette il colore a riempirsi di nuovo (s).
@export var durata_riempimento := 5.0
## Sotto il pavimento: quanto sotto il fondo delle pozze passano le zampette e sta il volantino (m).
@export var sotto_il_fondo := 0.35

signal comincia
signal riempito(colore: String)

var _enigma: EnigmaPozze
var _in_corso := false


func _ready() -> void:
	_enigma = get_parent() as EnigmaPozze
	if _enigma:
		_enigma.colore_tolto.connect(_su_colore_tolto)


func fatto() -> bool:
	return preload("res://scripts/game/stato_storia.gd").agnellino_pozze


func in_corso() -> bool:
	return _in_corso


func _su_colore_tolto(_c: String) -> void:
	if not attivo or fatto() or _in_corso or _enigma.stato != EnigmaPozze.Stato.APERTO:
		return
	if _enigma.tolti.size() != dopo_colori:
		return
	_fai()


func _fai() -> void:
	_in_corso = true
	var primo: String = _enigma.tolti[0]
	await get_tree().create_timer(attesa, false).timeout
	# (mai mentre lei è fuori: aspetta che sia tornata sotto)
	while is_inside_tree() and _lei_fuori():
		await get_tree().physics_frame
	if not _ancora_valido(primo):
		_in_corso = false
		return
	preload("res://scripts/game/stato_storia.gd").agnellino_pozze = true
	comincia.emit()
	# le zampette sotto il pavimento: dal lato opposto della stanza verso le pozze del primo colore
	var verso := _centro_colore(primo)
	var da := _enigma.global_position + (_enigma.global_position - verso).normalized() * 3.0
	da.y = verso.y
	var passi := 4
	for i in passi:
		if not is_inside_tree():
			return
		Audio.suona(&"zampette_condotto", da.lerp(verso, float(i) / (passi - 1)), -3.0, 1.0)
		await get_tree().create_timer(durata_zampette / passi, false).timeout
	if not _ancora_valido(primo):
		_in_corso = false
		return
	Audio.suona(&"cancello_ruota", verso, 0.0, 1.0)
	await get_tree().create_timer(durata_volantino, false).timeout
	if not _ancora_valido(primo):
		_in_corso = false
		return
	await _enigma.riempi_di_nuovo(primo, durata_riempimento)
	_in_corso = false
	riempito.emit(primo)


func _ancora_valido(c: String) -> bool:
	return is_inside_tree() and _enigma.stato == EnigmaPozze.Stato.APERTO and c in _enigma.tolti


func _lei_fuori() -> bool:
	var l := _enigma.lei
	if l == null or l.acqua == null:
		return false
	return not (l.acqua.fase in [AcquaDiLei.Fase.LONTANA, AcquaDiLei.Fase.CALMA])


## Sotto il fondo, al centro delle pozze del colore [param c].
func _centro_colore(c: String) -> Vector3:
	var somma := Vector3.ZERO
	var tanks := _enigma.pozze_del_colore(c)
	for t: WaterTank in tanks:
		somma += t.global_position
	var centro := somma / maxf(tanks.size(), 1) if not tanks.is_empty() else _enigma.global_position
	var fondo := (tanks[0] as WaterTank).get_floor_global_y() if not tanks.is_empty() else _enigma.global_position.y
	centro.y = fondo - sotto_il_fondo
	return centro
