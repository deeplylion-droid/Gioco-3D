extends "res://tests/test_squalo_viola.gd"
## test_squalo_viola col preset più basso ("basso": ombre 0, nebbia 0, GI 0), quello in cui la luce viola perdeva l'ombra
## (D1 del collaudo). Uso: [xvfb-run ...] godot --path godot [--rendering-driver vulkan] --script res://tests/run.gd -- \
##        res://tests/collaudo/squalo_minimo.gd


func _ready() -> void:
	Grafica.salva_su_disco = false
	Grafica.applica_preset("basso")
	print("SQUALO: preset basso, ombre %s" % Grafica.get(&"valori").get("ombre", "?") if Grafica.get(&"valori") is Dictionary else "SQUALO: preset basso")
	super._ready()
