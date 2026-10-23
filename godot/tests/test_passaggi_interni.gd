extends Node
## Test dei passaggi degli interni col giocatore vero (scenes/interni/interni.tscn): il controller cammina premendo
## avanti attraverso ogni porta e varco, in tutti e due i sensi, e lungo i corridoi accanto agli oggetti con la
## collisione. Nella v0.3.9 la collisione della porta aperta dello stanzino (una scatola allineata agli assi intorno a
## una porta ruotata) copriva il vano e non si entrava più (segnalazione dell'utente, 23 ottobre).
## Tornello e saracinesca si aprono come nel gioco (tornello sbloccato, saracinesca su); la porta di servizio in fondo
## al corridoio è chiusa a chiave e non conta.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_passaggi_interni.gd

const LEVEL := "res://scenes/interni/interni.tscn"
## Le strade, in coordinate di Godot (y 0): punti in fila, si cammina dall'uno all'altro.
const STRADE := [
	["corridoio, dalla porta tagliafuoco al passaggio verso gli spogliatoi", [Vector3(20.5, 0, -1.3), Vector3(6.8, 0, -1.3)]],
	["passaggio corridoio -> spogliatoi", [Vector3(6.8, 0, -1.3), Vector3(6.8, 0, -4.3)]],
	["passaggio spogliatoi -> corridoio", [Vector3(6.8, 0, -4.3), Vector3(6.8, 0, -1.3)]],
	["corridoio, dal passaggio fino in fondo a ovest", [Vector3(6.8, 0, -1.3), Vector3(2.2, 0, -1.3)]],
	["corridoio, dal fondo alla porta della sala pompe", [Vector3(2.2, 0, -1.3), Vector3(17.5, 0, -1.3)]],
	["spogliatoi verso la porta dello stanzino", [Vector3(6.8, 0, -4.3), Vector3(9.6, 0, -8.45)]],
	["porta spogliatoi -> stanzino", [Vector3(9.6, 0, -8.45), Vector3(12.4, 0, -8.45)]],
	["dentro lo stanzino, fino allo zaino", [Vector3(12.4, 0, -8.45), Vector3(13.6, 0, -8.43)]],
	["porta stanzino -> spogliatoi", [Vector3(13.6, 0, -8.43), Vector3(12.4, 0, -8.45), Vector3(9.6, 0, -8.45)]],
	["spogliatoi -> corridoio della vasca lava-piedi", [Vector3(9.6, 0, -8.45), Vector3(9.7, 0, -10.0), Vector3(9.7, 0, -12.0)]],
	["lungo la vasca lava-piedi fino al tornello", [Vector3(9.7, 0, -12.0), Vector3(9.5, 0, -15.6)]],
	["dal tornello (sbloccato)", [Vector3(9.5, 0, -15.6), Vector3(9.5, 0, -17.3)]],
	["alla saracinesca (su) e fuori", [Vector3(9.5, 0, -17.3), Vector3(9.7, 0, -19.6), Vector3(9.7, 0, -21.3)]],
	["e di nuovo dentro dalla saracinesca", [Vector3(9.7, 0, -21.3), Vector3(9.7, 0, -19.6), Vector3(9.5, 0, -17.3)]],
	["indietro dal tornello", [Vector3(9.5, 0, -17.3), Vector3(9.5, 0, -15.6)]],
	["dalla vasca lava-piedi agli spogliatoi", [Vector3(9.5, 0, -15.6), Vector3(9.7, 0, -12.0), Vector3(9.7, 0, -10.0)]],
]

var level: Node
var p: Player
var _passed := 0
var _failed := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	get_tree().change_scene_to_file(LEVEL)
	for i in 300:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player):
			break
	await _frames(5)
	level = get_tree().current_scene
	p = GameState.player
	check(p != null, "il giocatore è stato creato")
	if p == null:
		_fine()
		return
	# il tornello sbloccato e la saracinesca su, come dopo i loro enigmi
	level.call(&"_sblocca_tornello")
	var sar := level.get_node("Meccanismi/Saracinesca") as Node
	sar.call(&"load_state", {"latched": true, "open": 1.0})
	await _frames(10)
	print("Si passa da ogni porta e varco, col giocatore vero")
	for s in STRADE:
		var punti: Array = s[1]
		p.teleport(punti[0], p.yaw, 0.0)
		await _frames(5)
		var ok := true
		var dove := ""
		for k in range(1, punti.size()):
			var arrivato: bool = await _cammina(punti[k])
			if not arrivato:
				ok = false
				dove = "fermo in %s, andando verso %s" % [str(p.global_position.snapped(Vector3.ONE * 0.01)), str(punti[k])]
				break
		check(ok, "%s%s" % [s[0], (" (" + dove + ")") if dove != "" else ""])
	_fine()


## Cammina verso w premendo avanti (guardando w). Vero se ci arriva entro 25 cm; falso se resta fermo 1,5 s.
func _cammina(w: Vector3) -> bool:
	var fermo := 0
	var prima := p.global_position
	for i in 60 * 30:
		var d := Vector2(w.x - p.global_position.x, w.z - p.global_position.z)
		if d.length() < 0.25:
			Input.action_release(&"move_forward")
			await _frames(2)
			return true
		p.look_at_point(Vector3(w.x, p.global_position.y + 1.6, w.z))
		Input.action_press(&"move_forward")
		await get_tree().physics_frame
		if i % 30 == 29:
			if p.global_position.distance_to(prima) < 0.05:
				fermo += 1
				if fermo >= 3:
					Input.action_release(&"move_forward")
					return false
			else:
				fermo = 0
			prima = p.global_position
	Input.action_release(&"move_forward")
	return false


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func check(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
		print("  ok  ", msg)
	else:
		_failed += 1
		print("  FALLITO ", msg)


func _fine() -> void:
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)
