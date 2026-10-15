extends SceneTree
## Calcola (bake) l'illuminazione globale VoxelGI della sala principale e la salva in un file,
## così il preset Alto non deve calcolarla all'avvio del gioco (sarebbe un blocco di secondi).
## Serve il renderer vero (Vulkan), ma la vista 3D resta spenta: niente rendering della scena.
## Uso: xvfb-run -a godot --path godot --rendering-driver vulkan --script res://tools/bake_voxel_gi.gd

const LEVEL := "res://scenes/sala_principale.tscn"
const OUT := "res://assets/ambiente/sala/voxel_gi_sala.res"

var _level: Node
var _frames := 0


func _initialize() -> void:
	root.disable_3d = true
	_level = (load(LEVEL) as PackedScene).instantiate()
	root.add_child(_level)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 3:
		return false
	var gis := _level.find_children("*", "VoxelGI", true, false)
	if gis.is_empty():
		printerr("bake_voxel_gi: nessun VoxelGI nella sala")
		quit(1)
		return true
	var gi := gis[0] as VoxelGI
	gi.data = null
	var t0 := Time.get_ticks_msec()
	gi.bake()
	if gi.data == null:
		printerr("bake_voxel_gi: il bake non ha prodotto dati")
		quit(1)
		return true
	var err := ResourceSaver.save(gi.data, OUT)
	print("bake_voxel_gi: %s in %d ms, dimensioni %s, suddivisione %d -> %s" % [
		error_string(err), Time.get_ticks_msec() - t0, gi.size, gi.subdiv, OUT])
	quit(0 if err == OK else 1)
	return true
