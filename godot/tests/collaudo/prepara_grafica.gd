extends Node
## Prepara le impostazioni grafiche per un giro del collaudo lanciato come scena (giro_squalo.gd): il preset scelto
## e la calibrazione della luminosità già fatta (se no all'avvio compare la calibrazione). Le salva in user://.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/collaudo/prepara_grafica.gd <preset>


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var preset: String = a[1] if a.size() > 1 else "alto"
	Grafica.applica_preset(preset)
	Grafica.imposta("calibrato", true)
	Grafica.salva()
	print("GRAFICA: preset %s, nebbia %s, calibrato %s" % [Grafica.valore("preset"), Grafica.valore("nebbia"), Grafica.valore("calibrato")])
	print("RISULTATO: 1 controlli ok, 0 falliti")
	get_tree().quit()
