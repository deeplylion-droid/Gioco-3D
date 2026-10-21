extends SceneTree
## Elenca, per ogni risorsa del progetto (scene, risorse, modelli importati), le sue dipendenze dirette
## (ResourceLoader.get_dependencies: non carica niente). Serve a trovare i file che nessuno usa.
## Uso: godot --headless --path godot --script res://tools/dipendenze.gd -- <file di uscita>

func _init() -> void:
	var uscita := OS.get_cmdline_user_args()[0]
	var f := FileAccess.open(uscita, FileAccess.WRITE)
	var pila: Array[String] = ["res://"]
	while not pila.is_empty():
		var dir: String = pila.pop_back()
		for d in DirAccess.get_directories_at(dir):
			if not d.begins_with("."):
				pila.append(dir.path_join(d))
		for nome in DirAccess.get_files_at(dir):
			if nome.ends_with(".import") or nome.ends_with(".uid"):
				continue
			var p := dir.path_join(nome)
			if not ResourceLoader.exists(p):
				continue
			for dep in ResourceLoader.get_dependencies(p):
				var percorso := dep.get_slice("::", 2) if dep.contains("::") else dep
				if percorso.begins_with("uid://"):
					percorso = ResourceUID.uid_to_path(percorso) if ResourceUID.has_id(ResourceUID.text_to_id(percorso)) else percorso
				f.store_line(p + "\t" + percorso)
	f.close()
	quit()
