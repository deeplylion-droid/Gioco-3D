extends SceneTree
## grafica-2: le animazioni di due medusa_inseguimento.res, traccia per traccia, chiave per chiave.
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var v = load(a[0])
	var n = load(a[1])
	var lv := _anim(v)
	var ln := _anim(n)
	print("CONFRONTO vecchia %d animazioni, nuova %d" % [lv.size(), ln.size()])
	var uguali := 0
	for k in lv:
		if not ln.has(k):
			print("CONFRONTO manca nella nuova: ", k); continue
		var d := _diff(lv[k], ln[k])
		if d == "":
			uguali += 1
		else:
			print("CONFRONTO diversa %s: %s" % [k, d])
	for k in ln:
		if not lv.has(k):
			print("CONFRONTO nuova: %s (%.2f s, %d tracce)" % [k, ln[k].length, ln[k].get_track_count()])
	print("CONFRONTO identiche %d su %d" % [uguali, lv.size()])
	quit()

func _anim(r) -> Dictionary:
	var out := {}
	if r is AnimationLibrary:
		for k in r.get_animation_list(): out[String(k)] = r.get_animation(k)
	elif r is PackedScene:
		var s: Node = r.instantiate()
		for ap in s.find_children("*", "AnimationPlayer", true, false):
			for lib in ap.get_animation_library_list():
				for k in ap.get_animation_library(lib).get_animation_list():
					out[String(lib) + "/" + String(k)] = ap.get_animation(String(lib) + "/" + String(k)) if lib != "" else ap.get_animation(k)
	elif r is Animation:
		out["unica"] = r
	else:
		print("CONFRONTO tipo ", r)
	return out

func _diff(a: Animation, b: Animation) -> String:
	if a.length != b.length or a.loop_mode != b.loop_mode: return "durata o ciclo"
	if a.get_track_count() != b.get_track_count(): return "numero di tracce"
	for t in a.get_track_count():
		if a.track_get_path(t) != b.track_get_path(t) or a.track_get_type(t) != b.track_get_type(t): return "traccia %d" % t
		var c := a.track_get_key_count(t)
		if c != b.track_get_key_count(t): return "chiavi traccia %d" % t
		for i in c:
			if a.track_get_key_time(t, i) != b.track_get_key_time(t, i) or a.track_get_key_value(t, i) != b.track_get_key_value(t, i):
				return "valore traccia %s chiave %d" % [a.track_get_path(t), i]
	return ""
