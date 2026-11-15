extends "res://tests/collaudo/presa_ridotta.gd"
## presa_ridotta col renderer vero, e in più uno scatto ogni mezzo secondo nella cartella COLLAUDO_SCATTI (dalla presa
## alla sala ricaricata e oltre: il glitch, il nero, la ripartenza), per i fogli del collaudo.
## Uso: COLLAUDO_SCATTI=<cartella> xvfb-run ... godot --path godot --rendering-driver vulkan --resolution 640x360 \
##        --script res://tests/run.gd -- res://tests/collaudo/scatti_presa.gd <intera|saltata>

var _cart := ""
var _n := 0


func _ready() -> void:
	_cart = OS.get_environment("COLLAUDO_SCATTI")
	if _cart != "":
		DirAccess.make_dir_recursive_absolute(_cart)
		var t := Timer.new()
		t.wait_time = 0.5
		t.process_mode = Node.PROCESS_MODE_ALWAYS
		t.timeout.connect(_scatto)
		add_child(t)
		t.start()
	super._ready()


func _scatto() -> void:
	var im := get_viewport().get_texture().get_image()
	if im == null:
		return
	var sc := get_tree().current_scene
	var nome := "%03d_%s%s" % [_n, String(sc.name) if sc else "nessuna", "_morte" if GameState.is_dying else ""]
	im.save_jpg(_cart.path_join(nome + ".jpg"), 0.8)
	_n += 1
