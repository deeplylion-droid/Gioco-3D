extends Node
## Prova diagnostica della camminata su una pedana della discesa: dal checkpoint k all'imbocco del tratto k.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/sim_cammina.gd <k> [margine]
const Camminatore := preload("res://tests/camminatore.gd")

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var k := int(a[1]) if a.size() > 1 else 1
	var m := float(a[2]) if a.size() > 2 else 0.5
	var torre: SalaTorre = (load("res://scenes/sala/torre/sala_torre.tscn") as PackedScene).instantiate()
	torre.crea_luci = false
	torre.caduta_mortale = 1000.0
	get_tree().root.add_child(torre)
	var p: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(p)
	for i in 5:
		await get_tree().physics_frame
	p.global_position = torre.checkpoint[k].global_position + Vector3(0, 0.2, 0)
	for i in 10:
		await get_tree().physics_frame
	var cam = Camminatore.new(torre, p, self)
	cam.margine = m
	cam.stampa = true
	var tr: Dictionary = torre.dati["tratti"][k]
	var entrata := SalaTorre.b(tr["entrata"])
	var bocca := entrata
	var giro := cam.percorso(p.global_position, bocca)
	var t := ""
	for q in giro:
		t += "(%.1f, %.1f) " % [q.x, -q.z]
	print("da (%.1f, %.1f, %.1f) a bocca (%.1f, %.1f): %s" % [p.global_position.x, -p.global_position.z, p.global_position.y, bocca.x, -bocca.z, t])
	var ok: bool = await cam.verso(bocca, 0.35)
	print("esito: ", ok, " a ", p.global_position)
	get_tree().quit(0)
