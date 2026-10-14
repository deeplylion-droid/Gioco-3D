extends SceneTree
## Controllo rapido: carica (compila) tutti gli script e le scene del progetto e segnala errori.
## Uso: godot --headless --path godot --script res://tests/check_scripts.gd

var _errors := 0


func _initialize() -> void:
	_scan("res://")
	print("CHECK: %d errori" % _errors)
	quit(1 if _errors > 0 else 0)


func _scan(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null or FileAccess.file_exists(dir_path.path_join(".gdignore")):
		return
	for sub in dir.get_directories():
		if sub.begins_with("."):
			continue
		_scan(dir_path.path_join(sub))
	for f in dir.get_files():
		var path := dir_path.path_join(f)
		if path == get_script().resource_path:
			continue
		if f.ends_with(".gd") or f.ends_with(".tscn") or f.ends_with(".tres"):
			var res := ResourceLoader.load(path)
			if res == null:
				printerr("CHECK: non si carica: ", path)
				_errors += 1
			elif res is GDScript and not (res as GDScript).can_instantiate() and not (res as GDScript).is_abstract():
				printerr("CHECK: script non valido: ", path)
				_errors += 1
