extends SceneTree
## Avvia uno script di test (un Node) come figlio della radice, così sopravvive ai cambi
## di scena (morte e ripartenza ricaricano il livello).
## Lo script viene caricato a runtime: gli script che usano gli autoload (GameState) non si
## possono compilare prima che gli autoload esistano.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/test_mechanics.gd


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var path := args[0] if args.size() > 0 else "res://tests/test_mechanics.gd"
	var script: GDScript = load(path)
	if script == null:
		printerr("Script di test non trovato: ", path)
		quit(2)
		return
	var node: Node = script.new()
	node.name = "TestRunner"
	root.add_child.call_deferred(node)
