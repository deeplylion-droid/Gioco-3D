extends Node
## Test: la sala della torre è la stessa da qualunque strada ci si arrivi (collaudo di ambienti-1 su 4e9551c8: dal
## portone la torre si costruisce nascosta, e Posa, che guardava solo le mesh visibili, metteva le lampade d'emergenza 0
## e 4 dentro il muro di 15 e 40 mm; da F9, una morte o Continua no; e la lampada 5 dopo F9 si appoggiava al tubo).
## 1. Dal portone (la torre preparata nascosta: SalaPrincipale._prepara_torre) e da F9 (la partenza "torre": la torre
##    costruita subito, visibile) i nodi della torre stanno negli stessi posti, al decimo di millimetro (tranne quelli che
##    si muovono da soli: lei, l'acqua, le cose animate, che si confrontano solo nel nome).
## 2. Le 7 lampade d'emergenza, nelle due strade: a 0-1 mm dal muro (fra i 9 raggi sul retro della scatola, il più
##    vicino), e niente dentro la scatola (nessuna mesh fra la faccia davanti e quella dietro, sui 9 raggi e su 9
##    raggi dall'alto in basso).
## 3. Le istanze dei MultiMesh della torre (i led degli imbocchi, appoggiati con la fisica) uguali nelle due strade.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_lampade_torre_strade.gd

const LEVEL := "res://scenes/sala_principale.tscn"

var _ok := 0
var _ko := 0


func _ready() -> void:
	_run.call_deferred()


func check(cond: bool, cosa: String) -> void:
	if cond:
		_ok += 1
		print("  ok    ", cosa)
	else:
		_ko += 1
		print("  KO    ", cosa)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _aspetta_giocatore(vecchio: Node = null) -> void:
	for i in 3000:
		await get_tree().process_frame
		var p := GameState.player
		if p and is_instance_valid(p) and p != vecchio and p.is_inside_tree():
			break
	await _frames(10)


## La torre della sala attuale, quando c'è ed è costruita (al più [param secondi] s).
func _torre(secondi: float) -> Node3D:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < secondi * 1000.0:
		var sala := get_tree().current_scene
		var t: Node3D = sala.get(&"sala_torre") if sala else null
		if t and is_instance_valid(t) and bool(t.get(&"costruita")) and t.is_visible_in_tree():
			return t
		await get_tree().process_frame
	return null


static func _nome(n: Node) -> String:
	var s := String(n.name)
	return "@" + s.split("@")[1] if s.begins_with("@") else s


## [percorso -> trasformazione] dei nodi della torre (nomi automatici senza il numero, contati se ripetuti).
static func _nodi(torre: Node3D) -> Dictionary:
	var out := {}
	for n in torre.find_children("*", "Node3D", true, false):
		var parti: PackedStringArray = []
		var x: Node = n
		while x != torre:
			parti.append(_nome(x))
			x = x.get_parent()
		parti.reverse()
		var k := "/".join(parti)
		var j := 0
		while out.has("%s#%d" % [k, j]):
			j += 1
		out["%s#%d" % [k, j]] = (n as Node3D).global_transform
	return out


## Le lampade d'emergenza (le scatole rosse sotto Luci, nell'ordine dei dati).
static func _lampade(torre: Node3D) -> Array:
	var out: Array = []
	var luci := torre.get_node_or_null(^"Luci")
	for c in (luci.get_children() if luci else []):
		if c is MeshInstance3D and (c as MeshInstance3D).mesh is BoxMesh:
			out.append(c)
	return out


## [distanza minima del retro dal muro sui 9 raggi (m), quante volte qualcosa sta dentro la scatola].
static func _misura(corpo: MeshInstance3D) -> Array:
	var bx := (corpo.mesh as BoxMesh).size
	var v := Vector3.RIGHT if bx.x < bx.z else Vector3.BACK
	# (il verso giusto: dietro c'è il muro)
	var p := corpo.global_position
	var a1 := v.cross(Vector3.UP).normalized()
	var a2 := v.cross(a1).normalized()
	var spessore := minf(bx.x, bx.z)
	var vicine := Posa.mesh_vicine(corpo, AABB(p, Vector3.ZERO).grow(1.2))
	var dietro_meno := INF
	var dietro_piu := INF
	for verso in [v, -v]:
		var gap := INF
		for i in [-1, 0, 1]:
			for j in [-1, 0, 1]:
				var o: Vector3 = a1 * (i * 0.14) + a2 * (j * 0.14)
				var h := Posa._raggio_mesh(corpo, p + o + verso * 0.05, p + o - verso * 0.6, vicine)
				if not h.is_empty():
					gap = minf(gap, ((p + o - verso * (spessore * 0.5)) - (h.position as Vector3)).dot(verso))
		if verso == v:
			dietro_piu = gap
		else:
			dietro_meno = gap
	# il muro è dalla parte del raggio più corto
	var gap: float = minf(dietro_piu, dietro_meno)
	var dir: Vector3 = v if dietro_piu <= dietro_meno else -v
	# dentro la scatola: raggi da una faccia all'altra (avanti-dietro e alto-basso), un millimetro dentro i bordi
	var dentro := 0
	var mezzo := bx * 0.5 - Vector3.ONE * 0.001
	for i in [-1, 0, 1]:
		for j in [-1, 0, 1]:
			var o: Vector3 = a1 * (i * 0.13) + a2 * (j * 0.13)
			var lungo := absf(mezzo.dot(dir.abs()))
			if not Posa._raggio_mesh(corpo, p + o + dir * lungo, p + o - dir * lungo, vicine).is_empty():
				dentro += 1
			var o2: Vector3 = a1 * (i * 0.13) + dir * (j * (spessore * 0.5 - 0.002))
			if not Posa._raggio_mesh(corpo, p + o2 + Vector3.UP * mezzo.y, p + o2 - Vector3.UP * mezzo.y, vicine).is_empty():
				dentro += 1
	return [gap, dentro]


func _strada(nome: String, torre: Node3D) -> Dictionary:
	var lamp := _lampade(torre)
	check(lamp.size() == 7, "%s: le 7 lampade d'emergenza ci sono (%d)" % [nome, lamp.size()])
	var pos: Array = []
	for k in lamp.size():
		var m := _misura(lamp[k])
		pos.append((lamp[k] as Node3D).global_position)
		print("    %s lampada %d in %s: dal muro %.1f mm, dentro la scatola %d" % [nome, k, (lamp[k] as Node3D).global_position.snappedf(0.0001), m[0] * 1000.0, m[1]])
		check(m[0] >= -0.0002 and m[0] <= 0.001 and m[1] == 0, "%s: lampada %d a filo del muro (%.1f mm) e niente dentro (%d)" % [nome, k, m[0] * 1000.0, m[1]])
	# e le istanze dei MultiMesh (i led degli imbocchi, appoggiati con la fisica)
	var mm := {}
	for n in torre.find_children("*", "MultiMeshInstance3D", true, false):
		var m := (n as MultiMeshInstance3D).multimesh
		if m == null:
			continue
		var testo := ""
		for i in m.instance_count:
			testo += str(((n as Node3D).global_transform * m.get_instance_transform(i)).origin.snappedf(0.0001))
		var k := String(torre.get_path_to(n)).split("@")[0]
		while mm.has(k):
			k += "+"
		mm[k] = testo.md5_text()
	return {"lampade": pos, "nodi": _nodi(torre), "mm": mm}


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	print("1. Dal portone: la torre preparata nascosta")
	GameState.reset_progress()
	get_tree().change_scene_to_file(LEVEL)
	await _aspetta_giocatore()
	var level := get_tree().current_scene
	var enigma := level.get_node_or_null(^"Gioco/EnigmaAcquari")
	if enigma:
		enigma.emit_signal(&"comparso")
	await get_tree().process_frame
	(level.get(&"portone") as PortoneTorre).apri_quando_pronta()
	var t1 := await _torre(240.0)
	check(t1 != null, "dal portone la torre si mostra")
	if t1 == null:
		_fine()
		return
	var a := _strada("portone", t1)
	print("2. Da F9: la partenza della torre, costruita subito e visibile")
	var vecchio := GameState.player
	MenuProva.parti(get_tree(), "torre")
	await _aspetta_giocatore(vecchio)
	var t2 := await _torre(240.0)
	check(t2 != null, "da F9 la torre c'è")
	if t2 == null:
		_fine()
		return
	var b := _strada("F9", t2)
	var uguali := 0
	var diverse: Array = []
	for k in (a["lampade"] as Array).size():
		if k < (b["lampade"] as Array).size() and (a["lampade"][k] as Vector3).distance_to(b["lampade"][k]) < 0.0001:
			uguali += 1
		else:
			diverse.append(k)
	check(uguali == 7, "le 7 lampade stanno negli stessi posti dal portone e da F9 (diverse: %s)" % [diverse])
	var na: Dictionary = a["nodi"]
	var nb: Dictionary = b["nodi"]
	var spostati: Array = []
	var mancano: Array = []
	for k in na:
		if not nb.has(k):
			mancano.append(k)
		elif not _mobile(k) and ((na[k] as Transform3D).origin.distance_to((nb[k] as Transform3D).origin) > 0.0001
				or not (na[k] as Transform3D).basis.is_equal_approx((nb[k] as Transform3D).basis)):
			spostati.append(k)
	for k in nb:
		if not na.has(k):
			mancano.append(k)
	for k in spostati.slice(0, 15):
		print("    spostato: %s %s -> %s" % [k, (na[k] as Transform3D).origin, (nb[k] as Transform3D).origin])
	for k in mancano.slice(0, 15):
		print("    solo in una strada: %s" % k)
	check(spostati.is_empty(), "i %d nodi della torre negli stessi posti nelle due strade (spostati %d)" % [na.size(), spostati.size()])
	check(mancano.size() <= 0, "gli stessi nodi nelle due strade (%d solo in una)" % mancano.size())
	var mma: Dictionary = a["mm"]
	var mmb: Dictionary = b["mm"]
	var mm_diversi: Array = []
	for k in mma:
		if not mmb.has(k) or mma[k] != mmb[k]:
			mm_diversi.append(k)
	check(mma.size() > 0 and mm_diversi.is_empty(), "le istanze dei %d MultiMesh della torre (i led degli imbocchi...) uguali nelle due strade (diversi: %s)" % [mma.size(), mm_diversi])
	_fine()


## I nodi che si muovono da soli (lei e le sue parti, l'acqua che scorre, i gommoni, il giocatore): solo il nome.
static func _mobile(k: String) -> bool:
	for parola in ["Lei", "lei", "Medusa", "Acqua", "acqua", "Scivol", "Gocc", "gocc", "Tentacol", "Morbid", "Oblo", "Catena"]:
		if k.contains(parola):
			return true
	return false


func _fine() -> void:
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	get_tree().quit(1 if _ko > 0 else 0)
