extends SceneTree
## Calcola (bake) l'illuminazione globale VoxelGI della sala principale con il metodo di LuciSala
## (LookSala.cuoci_gi: emissioni delle lampade spente durante il calcolo) e la salva nel file del
## suo dati_gi (scenes/sala/gi/sala.res). Così il gioco non deve calcolarla all'avvio.
## Serve il renderer vero (Vulkan), ma la vista 3D resta spenta: niente rendering della scena, e
## la memoria resta sotto quella di uno scatto. Da rilanciare quando cambiano i GLB della sala.
## Uso: xvfb-run -a godot --path godot --rendering-driver vulkan --script res://tools/bake_voxel_gi.gd

const LEVEL := "res://scenes/sala_principale.tscn"

var _level: Node
var _frames := 0


func _initialize() -> void:
	root.disable_3d = true
	_level = (load(LEVEL) as PackedScene).instantiate()
	root.add_child(_level)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 5:
		return false
	var look: Node = null
	for n in _level.find_children("*", "Node3D", true, false):
		if n.has_method(&"cuoci_gi"):
			look = n
			break
	if look == null or look.get_node_or_null(^"VoxelGI_Sala") == null:
		printerr("bake_voxel_gi: nessun LookSala con VoxelGI_Sala nella sala")
		quit(1)
		return true
	var out: String = look.get(&"dati_gi")
	var before := FileAccess.get_modified_time(out) if FileAccess.file_exists(out) else 0
	var t0 := Time.get_ticks_msec()
	look.call(&"cuoci_gi")
	var ok := FileAccess.file_exists(out) and FileAccess.get_modified_time(out) >= before and Time.get_ticks_msec() - t0 > 0
	print("bake_voxel_gi: %s in %d ms -> %s" % ["OK" if ok else "FALLITO", Time.get_ticks_msec() - t0, out])
	quit(0 if ok else 1)
	return true
