extends SceneTree
## Costruisce la libreria delle animazioni di lei per l'inseguimento
## (res://assets/models/medusa/medusa_inseguimento.res) dalle pose di tools/blender/medusa_inseguimento.py
## (assets_src/medusa/build/inseguimento.json): per ogni osso una traccia di posizione e una di rotazione,
## con lo stesso percorso dello Skeleton3D delle animazioni di medusa.glb. Nella presa si aggiungono le
## blend shape della fauce (strappo, denti, gola) prese da "fauce_apre", nel tempo della presa.
## Uso (da godot/, con il lock):
##   godot --headless --path . --script res://tools/medusa_inseguimento_libreria.gd
## In gioco: MedusaAffacciata.animazioni_inseguimento = true, poi "inseguimento/<nome>".

const MODELLO := "res://assets/models/medusa/medusa.glb"
const USCITA := "res://assets/models/medusa/medusa_inseguimento.res"
## Nella presa la fauce si apre da qui alla fine (secondi).
const FAUCE_DA := 0.45


func _init() -> void:
	var dati_path := ProjectSettings.globalize_path("res://").path_join("../assets_src/medusa/build/inseguimento.json")
	var f := FileAccess.open(dati_path, FileAccess.READ)
	if f == null:
		printerr("manca ", dati_path, ": prima tools/blender/medusa_inseguimento.py")
		quit(1)
		return
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	var scena := (load(MODELLO) as PackedScene).instantiate()
	var ap := scena.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var sk := scena.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var radice := ap.get_node(ap.root_node)
	var percorso := String(radice.get_path_to(sk))
	var ossa: Array = d["ossa"]
	for nome in ossa:
		if sk.find_bone(nome) < 0:
			printerr("osso che non c'è nello scheletro: ", nome)
			quit(1)
			return
	var fps := float(d["fps"])
	var lib := AnimationLibrary.new()
	for nome: String in d["animazioni"]:
		var an: Dictionary = d["animazioni"][nome]
		var a := Animation.new()
		a.length = float(an["durata"])
		a.loop_mode = Animation.LOOP_LINEAR if an["ciclo"] else Animation.LOOP_NONE
		a.step = 1.0 / fps
		var chiavi: Array = an["chiavi"]
		for i in ossa.size():
			var tp := a.add_track(Animation.TYPE_POSITION_3D)
			a.track_set_path(tp, "%s:%s" % [percorso, ossa[i]])
			var tr := a.add_track(Animation.TYPE_ROTATION_3D)
			a.track_set_path(tr, "%s:%s" % [percorso, ossa[i]])
			var prima := Quaternion.IDENTITY
			for k in chiavi.size():
				var v: Array = chiavi[k][i]
				var t := minf(k / fps, a.length)
				a.position_track_insert_key(tp, t, Vector3(v[0], v[1], v[2]))
				var q := Quaternion(v[3], v[4], v[5], v[6])
				if k > 0 and prima.dot(q) < 0.0:
					q = -q
				prima = q
				a.rotation_track_insert_key(tr, t, q)
		if nome == "presa":
			_fauce(ap.get_animation(&"fauce_apre"), a)
		lib.add_animation(StringName(nome), a)
		print("ANIMAZIONE ", nome, ": ", chiavi.size(), " fotogrammi, ", a.get_track_count(), " tracce")
	var err := ResourceSaver.save(lib, USCITA, ResourceSaver.FLAG_COMPRESS)
	print("SALVATA ", USCITA, " (", err, ")")
	scena.free()
	quit(0 if err == OK else 1)


## Le blend shape della fauce di "fauce_apre" (in 1 s) copiate nella presa, da FAUCE_DA alla fine.
func _fauce(src: Animation, dst: Animation) -> void:
	if src == null:
		printerr("manca fauce_apre")
		return
	var scala := (dst.length - FAUCE_DA) / maxf(src.length, 0.01)
	for i in src.get_track_count():
		if src.track_get_type(i) != Animation.TYPE_BLEND_SHAPE:
			continue
		var t := dst.add_track(Animation.TYPE_BLEND_SHAPE)
		dst.track_set_path(t, src.track_get_path(i))
		dst.blend_shape_track_insert_key(t, 0.0, 0.0)
		for k in src.track_get_key_count(i):
			dst.blend_shape_track_insert_key(t, FAUCE_DA + src.track_get_key_time(i, k) * scala,
				float(src.track_get_key_value(i, k)))
