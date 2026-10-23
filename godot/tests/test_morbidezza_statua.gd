extends Node
## Test della statua di lei (MedusaStatue, nel menu e al centro della sala): la morbidezza c'è ma a 0, e la statua è
## ferma davvero: le ossa con la morbidezza e senza sono le stesse, e il calcolo non parte (costo zero).
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/test_morbidezza_statua.gd

const SCENA := "res://scenes/ui/menu_principale.tscn"
const Misura := preload("res://tests/misura_morbidezza.gd")

var _ok := 0
var _ko := 0


func _ready() -> void:
	_run.call_deferred()


func _check(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  ok  ", msg)
	else:
		_ko += 1
		print("  KO  ", msg)


func _run() -> void:
	get_tree().change_scene_to_file(SCENA)
	for i in 30:
		await get_tree().process_frame
	var statue := get_tree().current_scene.find_children("*", "MedusaStatue", true, false).filter(func(n): return not n is MedusaAffacciata)
	_check(statue.size() > 0, "nel menu c'è la statua (%d)" % statue.size())
	for s in statue:
		var m := MorbidezzaLei.su(s)
		_check(m != null and m.quanto == 0.0, "%s: la morbidezza c'è, a 0" % s.name)
		if m == null:
			continue
		var sk := m.get_parent() as Skeleton3D
		var mis = Misura.new(sk, m)
		var con: Array = mis.punti()
		var costo_max := 0
		for i in 30:
			await get_tree().process_frame
			costo_max = maxi(costo_max, m.durata_usec)
		var con2: Array = mis.punti()
		m.active = false
		for i in 3:
			await get_tree().process_frame
		var senza: Array = mis.punti()
		m.active = true
		var diff := 0.0
		var mosso := 0.0
		for k in con.size():
			for i in (con[k] as PackedVector3Array).size():
				diff = maxf(diff, (con2[k] as PackedVector3Array)[i].distance_to((senza[k] as PackedVector3Array)[i]))
				mosso = maxf(mosso, (con2[k] as PackedVector3Array)[i].distance_to((con[k] as PackedVector3Array)[i]))
		_check(diff < 1e-5, "%s: le ossa con la morbidezza a 0 sono quelle senza (scarto %.6f m)" % [s.name, diff])
		_check(mosso < 1e-5, "%s: ferma in 30 fotogrammi (%.6f m)" % [s.name, mosso])
		_check(costo_max == 0, "%s: il calcolo non parte (costo zero)" % s.name)
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	get_tree().quit(1 if _ko > 0 else 0)
