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
	print("Le ripartenze dei checkpoint sono libere (la capsula del giocatore non tocca niente)")
	await _ripartenze_libere()
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
	print("L'armadietto che sbatte resta fuori dal suo armadietto")
	await _anta_che_sbatte()
	_fine()


## L'anta che sbatte gira sul cardine vero (collaudo del 23 ottobre: girava intorno all'origine e finiva dentro il suo
## armadietto, x 10,5-11,0): dopo il colpo sta davanti al fronte (x <= 10,5), attaccata al cardine, con la collisione.
func _anta_che_sbatte() -> void:
	var anta := level.find_child("armadietto_sbatte_anta", true, false) as MeshInstance3D
	var cardine := level.find_child("cardine_armadietto_sbatte", true, false) as Node3D
	check(anta != null and cardine != null, "ci sono l'anta che sbatte e il suo cardine")
	if anta == null or cardine == null:
		return
	level.call(&"_on_trigger_armadietto", p)
	await _frames(90)
	var bb := anta.global_transform * anta.get_aabb()
	var c := cardine.global_position
	check(bb.end.x <= c.x + 0.02, "l'anta aperta è davanti al fronte, fuori dall'armadietto (x fino a %.3f, fronte %.3f)" % [bb.end.x, c.x])
	var vicino := Vector3(clampf(c.x, bb.position.x, bb.end.x), c.y, clampf(c.z, bb.position.z, bb.end.z))
	check(vicino.distance_to(c) < 0.03, "l'anta è attaccata al cardine (%.3f m)" % vicino.distance_to(c))
	check(anta.has_node(^"Collisione"), "l'anta aperta ha la collisione")


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


## La capsula del giocatore (la sua forma vera), messa su ogni ripartenza degli interni, non deve toccare niente:
## si rinascerebbe dentro qualcosa (collaudo del 23 ottobre: la ripartenza della vasca lava-piedi era nel cartello).
func _ripartenze_libere() -> void:
	var forma: CollisionShape3D = null
	for c in p.find_children("*", "CollisionShape3D", true, false):
		if (c as CollisionShape3D).shape is CapsuleShape3D:
			forma = c
			break
	check(forma != null, "il giocatore ha la capsula")
	if forma == null:
		return
	var spazio := p.get_world_3d().direct_space_state
	var ripartenze := level.find_children("Ripartenza", "Node3D", true, false)
	check(ripartenze.size() >= 6, "ci sono le ripartenze degli interni (%d)" % ripartenze.size())
	for r in ripartenze:
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = forma.shape
		# la capsula come sta sul giocatore, coi piedi sulla ripartenza (2 cm sopra, per non contare il pavimento)
		q.transform = Transform3D(forma.global_basis, (r as Node3D).global_position + (forma.global_position - p.global_position) + Vector3.UP * 0.02)
		q.exclude = [p.get_rid()]
		q.collision_mask = p.collision_mask
		var tocchi := spazio.intersect_shape(q, 8)
		var cosa := ", ".join(tocchi.map(func(t): return String((t.collider as Node).name)))
		check(tocchi.is_empty(), "%s libera%s" % [String(r.get_parent().name), (" (tocca " + cosa + ")") if cosa != "" else ""])


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
