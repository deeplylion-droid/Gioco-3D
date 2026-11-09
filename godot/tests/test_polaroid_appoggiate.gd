extends Node
## Test: ogni Polaroid appoggiata ha il fondo a filo della superficie sotto (collaudo di grafica del 9 novembre,
## docs/collaudo/polaroid_fiume: l'origine a 4 mm dal pavimento lasciava il fondo della foto 3,2-3,9 mm sollevato, la
## P05 e la P08 a 7-8 mm; di lato, radente, si vedeva uno spicchio scuro sotto il bordo).
## Su una griglia di 5 x 5 punti sotto la foto, il fondo vero (dalla mesh della foto) e la superficie che si vede sotto
## (Posa: la mesh visibile, se no la collisione): nel punto più vicino al più 1 mm, e nessun punto dentro.
## 1. La sala con tutte le sue Polaroid (anche quelle della risalita: le stanze messe subito, e il giocatore nel
##    corridoio del fiume perché si accendano).
## 2. La torre (partenza F9 "torre"): la P10 sul lettino e la P12 sul grigliato.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_polaroid_appoggiate.gd

const LEVEL := "res://scenes/sala_principale.tscn"
## Al più quanto può restare staccato il fondo, nel punto più vicino (m), e quanto può entrare (m, tolleranza dei raggi).
const MASSIMO := 0.001
const DENTRO := 0.0001

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


## [distanza minima, distanza massima, punti dentro, punti misurati] del fondo di [param ph] dalla superficie sotto.
static func misura(ph: PolaroidPhoto) -> Array:
	var mesh := ph.find_children("*", "MeshInstance3D", true, false)
	var su := ph.global_basis.y.normalized()
	var zona := AABB(ph.global_position, Vector3.ZERO).grow(0.08)
	zona = zona.expand(ph.global_position - su * 0.35)
	var vicine := Posa.mesh_vicine(ph, zona, ph.get_parent())
	var minimo := INF
	var massimo := -INF
	var dentro := 0
	var punti := 0
	var righe: PackedStringArray = []
	# (una griglia più fitta di quella con cui la foto si adagia: 7 x 7)
	for i in 7:
		var riga := ""
		for j in 7:
			var pl := Vector3(-0.042 + 0.014 * i, 0.0, -0.051 + 0.017 * j)
			var fondo = ph._fondo_in(pl, mesh)
			if fondo == null:
				riga += "     -"
				continue
			var w: Vector3 = fondo
			var h := Posa._raggio(ph, w + su * 0.03, w - su * 0.3, [], vicine)
			if h.is_empty():
				riga += "     ?"
				continue
			var d := (w - (h.position as Vector3)).dot(su)
			riga += " %5.1f" % (d * 1000.0)
			punti += 1
			minimo = minf(minimo, d)
			massimo = maxf(massimo, d)
			if d < -DENTRO:
				dentro += 1
		righe.append(riga)
	return [minimo, massimo, dentro, punti, righe]


func _controlla(ph: PolaroidPhoto) -> void:
	var m := misura(ph)
	var nome := "P%02d (%s, in %s)" % [ph.photo, ph.name, ph.global_position.snappedf(0.001)]
	if int(m[3]) == 0:
		check(false, "%s: niente sotto la foto" % nome)
		return
	check(float(m[0]) >= -DENTRO and float(m[0]) <= MASSIMO and int(m[2]) == 0,
			"%s: fondo a %.2f mm dalla superficie nel punto più vicino (al più %.2f mm, %d punti dentro su %d)" % [
			nome, float(m[0]) * 1000.0, float(m[1]) * 1000.0, int(m[2]), int(m[3])])
	# (sotto la foto, in mm, dove qualche punto è staccato più di 3 mm: righe lungo x, colonne lungo z)
	if float(m[1]) > 0.003:
		for r in m[4]:
			print("        ", r)


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	Engine.set_meta(&"precarica_torre_spento", true)
	Engine.set_meta(&"risalita_subito", true)
	print("1. La sala e la risalita")
	GameState.reset_progress()
	get_tree().change_scene_to_file(LEVEL)
	for i in 600:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and get_tree().current_scene:
			break
	var level := get_tree().current_scene as Node3D
	var p := GameState.player as Player
	for i in 60:
		await get_tree().physics_frame
	# nel corridoio del fiume: le stanze della risalita si accendono
	p.teleport(Vector3(-4.9, -5.4, 55.0))
	var ris := level.get_node_or_null(^"Risalita")
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 300000:
		await get_tree().process_frame
		var f: Node3D = ris.get(&"fiume") as Node3D if ris else null
		if f and bool(f.get(&"costruita")) and f.can_process() and f.visible and not bool(ris.get(&"_riaccendendo")):
			break
	# (le foto si appoggiano qualche fotogramma dopo: due fotogrammi di fisica, o fino a 20 s col pavimento che arriva)
	await get_tree().create_timer(3.0).timeout
	var foto := level.find_children("*", "PolaroidPhoto", true, false)
	foto.sort_custom(func(a, b): return int(a.get(&"photo")) < int(b.get(&"photo")))
	check(foto.size() >= 14, "le Polaroid della sala e della risalita ci sono (%d)" % foto.size())
	for n in foto:
		_controlla(n as PolaroidPhoto)
	Engine.remove_meta(&"risalita_subito")

	print("2. La torre: la P10 e la P12")
	var vecchio := GameState.player
	MenuProva.parti(get_tree(), "torre")
	for i in 3000:
		await get_tree().process_frame
		var pl := GameState.player
		if pl and is_instance_valid(pl) and pl != vecchio and pl.is_inside_tree():
			break
	var torre: Node3D = null
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 240000:
		await get_tree().process_frame
		var sala := get_tree().current_scene
		torre = sala.get(&"sala_torre") if sala else null
		if torre and is_instance_valid(torre) and bool(torre.get(&"costruita")) and torre.is_visible_in_tree():
			break
	check(torre != null, "la torre c'è")
	if torre:
		await get_tree().create_timer(3.0).timeout
		var nella_torre := torre.find_children("*", "PolaroidPhoto", true, false)
		check(nella_torre.size() == 2, "nella torre ci sono la P10 e la P12 (%d)" % nella_torre.size())
		for n in nella_torre:
			_controlla(n as PolaroidPhoto)
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	get_tree().quit(1 if _ko > 0 else 0)
