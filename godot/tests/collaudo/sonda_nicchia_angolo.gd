extends Node
## Sonda della pila dell'angolo a sinistra dell'ingresso del capannone (fiume lento) e della nicchia dove sparisce il
## bambino col cubo, come il ricontrollo di grafica-2 (ric_a1_g2.gd): raggi sulle collisioni da dove sta il giocatore
## (soglia, 40 cm, 1, 2 e 4 m dentro, 2 m dentro e 80 cm a ovest, accucciato) verso 48 punti della nicchia; e lo
## spazio fra la pila e il muro nord. Le pile si costruiscono dal codice (non dal file), così si provano le modifiche
## prima di rifare il file. Coordinate del fiume.
## Uso (sotto il render.lock):
##   godot --headless --path godot --script res://tests/run.gd -- res://tests/collaudo/sonda_nicchia_angolo.gd

const SCENA := "res://tests/scene/fiume_gioco_prova.tscn"
const FIUME := preload("res://scripts/risalita/fiume_gioco.gd")

var fiume: Node3D


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Engine.set_meta(&"costruisci_pile", true)
	get_tree().change_scene_to_file(SCENA)
	for i in 12000:
		await get_tree().process_frame
		var s := get_tree().current_scene
		if s == null:
			continue
		for f in s.find_children("*", "Node3D", true, false):
			if (f as Node).get_script() == FIUME and f.get(&"costruita") == true:
				fiume = f
		if fiume:
			break
	Engine.remove_meta(&"costruisci_pile")
	for i in 5:
		await get_tree().physics_frame
	var z0: float = FIUME.Z0
	var ix: float = FIUME.INGRESSO_X
	# la nicchia: i punti di grafica-2, e quelli della nicchia nuova se si sposta (NICCHIA_X, NICCHIA_Z)
	var xs := [-30.25, -30.0, -29.75, -29.58]
	var zs := [-28.5, -28.15, -27.8, -27.4]
	if OS.has_environment("NICCHIA_Z"):
		zs = Array(OS.get_environment("NICCHIA_Z").split(",")).map(func(v): return float(v))
	if OS.has_environment("NICCHIA_X"):
		xs = Array(OS.get_environment("NICCHIA_X").split(",")).map(func(v): return float(v))
	var nicchia := []
	for x in xs:
		for z in zs:
			for y in [0.25, 0.7, 1.1]:
				nicchia.append(Vector3(x, y, z))
	var occhi := [["soglia", Vector3(ix, 1.6, z0 - 0.15)], ["soglia_dentro_40cm", Vector3(ix, 1.6, z0 + 0.4)],
			["strada_1m", Vector3(ix, 1.6, z0 + 1.0)], ["strada_2m", Vector3(ix, 1.6, z0 + 2.0)],
			["strada_3m", Vector3(ix, 1.6, z0 + 3.0)], ["strada_4m", Vector3(ix, 1.6, z0 + 4.0)],
			["strada_6m", Vector3(ix + 1.0, 1.6, z0 + 6.0)], ["strada_2m_ovest", Vector3(ix - 0.8, 1.6, z0 + 2.0)],
			["accovacciato_1m", Vector3(ix, 0.9, z0 + 1.0)]]
	# altri occhi, coordinate del fiume: OCCHI="x,y,z;x,y,z"
	if OS.has_environment("OCCHI"):
		for t in OS.get_environment("OCCHI").split(";"):
			var v := t.split(",")
			occhi.append(["occhio_%s" % t, Vector3(float(v[0]), float(v[1]), float(v[2]))])
	var totale := 0
	for o in occhi:
		var visti := []
		for q: Vector3 in nicchia:
			if not _ray(o[1], q):
				visti.append(q.snapped(Vector3.ONE * 0.01))
		totale += visti.size()
		print("NICCHIA: da %s %d su %d visibili %s" % [o[0], visti.size(), nicchia.size(), str(visti) if visti.size() <= 12 else ""])
	print("NICCHIA: totale %d" % totale)
	# lo spazio fra la pila e il muro nord: dalla faccia nord della pila verso nord, a 0,3, 1,0 e 1,8 m
	for x in [-29.4, -28.9, -28.4]:
		for y in [0.3, 1.0, 1.8]:
			var da := Vector3(x, y, -27.0)
			var r := _colpo(da, da + Vector3(0, 0, -2.5))
			var r2 := {}
			if not r.is_empty():
				var dentro: Vector3 = fiume.to_local(r.position) + Vector3(0, 0, -0.002)
				r2 = _colpo(dentro, dentro + Vector3(0, 0, -1.5))
			print("MURO: x %.1f y %.1f: pila a z %s, poi muro a z %s" % [x, y, ("%.3f" % fiume.to_local(r.position).z) if not r.is_empty() else "-",
					("%.3f" % fiume.to_local(r2.position).z) if not r2.is_empty() else "-"])
	print("SONDA: finito")
	get_tree().quit()


## Vero se fra [param a] e [param b] (coordinate del fiume) c'è qualcosa.
func _ray(a: Vector3, b: Vector3) -> bool:
	return not _colpo(a, b).is_empty()


func _colpo(a: Vector3, b: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(fiume.to_global(a), fiume.to_global(b))
	q.hit_from_inside = false
	return fiume.get_world_3d().direct_space_state.intersect_ray(q)
