extends Node
## Collaudo delle lingue: sceglie la lingua [code]<it|en>[/code] dal menu a tendina delle opzioni aperte sul titolo, come
## farebbe il giocatore, e chiude il gioco. Poi si riapre il gioco vero (senza --script) per vedere che riparte nella
## lingua scelta. Uso: godot --path godot --script res://tests/run.gd -- res://tests/collaudo/scegli_lingua.gd en

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var voluta := OS.get_cmdline_user_args()[1]
	Grafica.salva_su_disco = false
	get_tree().change_scene_to_file("res://scenes/ui/menu_principale.tscn")
	for i in 20:
		await get_tree().process_frame
	get_tree().current_scene.call(&"apri_opzioni")
	for i in 10:
		await get_tree().process_frame
	for o in get_tree().root.find_children("*", "OptionButton", true, false):
		var ob := o as OptionButton
		if ob.get_item_text(0) == "Italiano":
			var i := Lingua.LINGUE.find(voluta)
			ob.select(i)
			ob.item_selected.emit(i)
	for i in 5:
		await get_tree().process_frame
	var cfg := ConfigFile.new()
	cfg.load(Lingua.PERCORSO)
	print("LINGUA SALVATA ", cfg.get_value(Lingua.SEZIONE, "lingua", ""), " in ", ProjectSettings.globalize_path(Lingua.PERCORSO))
	get_tree().quit()
