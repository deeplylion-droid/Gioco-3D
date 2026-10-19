extends Node
## Rifà solo lo schermo del monitor a tubo della sala pompe (assets/tecnici/schermo_crt_sul_vetro.res),
## come lo fa tools/build_sala_principale.gd, senza ricostruire tutta la sala.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tools/rigenera_schermo_crt.gd

const SP := "Ambienti/SalaPompe/"
const OUT := "res://assets/tecnici/schermo_crt_sul_vetro.res"


func _ready() -> void:
	var tec: Node3D = (load("res://scenes/tecnici/tecnici.tscn") as PackedScene).instantiate()
	var schermo := tec.get_node(SP + "SCHERMO_CRT") as MeshInstance3D
	var tv := tec.get_node(SP + "MONITOR_CRT") as MeshInstance3D
	var mesh: ArrayMesh = MonitorCrt.costruisci_schermo_sul_vetro(schermo.mesh, tv.mesh,
			_relativa(tv, tec).affine_inverse() * _relativa(schermo, tec))
	if mesh == null:
		printerr("lo schermo non trova il vetro")
		get_tree().quit(1)
		return
	ResourceSaver.save(mesh, OUT)
	print("schermo: %d vertici, %s" % [int(mesh.get_meta(&"vertici_sul_vetro")), mesh.get_aabb()])
	tec.free()
	get_tree().quit()


func _relativa(n: Node3D, radice: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var x: Node = n
	while x and x != radice:
		if x is Node3D:
			t = (x as Node3D).transform * t
		x = x.get_parent()
	return t
