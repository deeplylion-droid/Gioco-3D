extends Node
## Collaudo: nella risalita vera (risalita.tscn, stato ritorno, stanze subito) aspetta il fiume costruito e scrive le
## ciambelle (nodo, centro e riquadro nel mondo) e le stampe "ciambella a riva" del fiume.
## Uso: xvfb-run ... godot --path godot --rendering-driver vulkan --script res://tests/run.gd -- \
##        res://tests/cz/sonda_ciambelle_risalita.gd <uscita.json>

const STATI := preload("res://tests/collaudo/stati.gd")


func _ready() -> void:
	Engine.set_meta(&"precarica_torre_spento", true)
	_run.call_deferred()


func _run() -> void:
	var uscita: String = OS.get_cmdline_user_args()[1]
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	Engine.set_meta(&"risalita_subito", true)
	var livello: Node3D = (load("res://scenes/risalita/risalita.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(livello)
	get_tree().current_scene = livello
	for i in 30:
		await get_tree().process_frame
	get_tree().paused = false
	STATI.applica(livello, "ritorno")
	var trovate := []
	for i in 3600:
		await get_tree().process_frame
		trovate = livello.find_children("CiambellaRiva*", "Node3D", true, false)
		if trovate.size() >= 3 and i > 240:
			break
	var out := []
	for n in livello.find_children("*", "Node3D", true, false):
		if not String(n.name).to_lower().contains("ciambella") or not (n as Node3D).is_visible_in_tree():
			continue
		var tot := AABB()
		var prima := true
		for m in n.find_children("*", "GeometryInstance3D", true, false) + ([n] if n is GeometryInstance3D else []):
			var gm := m as GeometryInstance3D
			var bb: AABB = gm.global_transform * gm.get_aabb()
			tot = bb if prima else tot.merge(bb)
			prima = false
		if not prima:
			out.append({"nodo": String(livello.get_path_to(n)), "centro": _v(tot.get_center()), "box": [_v(tot.position), _v(tot.size)],
					"basis": [_v((n as Node3D).global_basis.x), _v((n as Node3D).global_basis.y), _v((n as Node3D).global_basis.z)]})
	var f := FileAccess.open(uscita, FileAccess.WRITE)
	f.store_string(JSON.stringify(out, " "))
	f.close()
	print("SONDA CIAMBELLE: %d a riva, %d in tutto" % [trovate.size(), out.size()])
	get_tree().quit()


func _v(v: Vector3) -> Array:
	return [snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001)]
