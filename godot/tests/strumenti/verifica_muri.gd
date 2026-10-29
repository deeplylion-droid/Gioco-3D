extends "res://tests/strumenti/cerca_muri.gd"
## Strumento (non in CI): ricontrolla i muri degli scarabocchi (docs/proposte/scarabocchi/scelti.json, o VERIFICA=<json>)
## con una griglia fitta, 13 × 7 raggi come il collaudo: per ognuno quanti raggi non trovano il muro, lo trovano
## inclinato o fuori dal piano (più di 3,5 cm) o colpiscono altro che architettura. Poi le mesh che entrano nella scatola
## della decal (±12 cm dal muro, che verrebbero dipinte) e l'acqua, anche nascosta (si allaga dopo), con il margine fra
## l'acqua e il bordo basso del disegno.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/strumenti/verifica_muri.gd [scena]

var _lista: Array = []


func _run() -> void:
	Engine.set_meta(&"risalita_subito", true)
	var file := OS.get_environment("VERIFICA") if OS.get_environment("VERIFICA") != "" else "res://../docs/proposte/scarabocchi/scelti.json"
	_lista = JSON.parse_string(FileAccess.get_file_as_string(file))
	var solo := OS.get_cmdline_user_args().slice(1)
	for s in SCENE:
		if not solo.is_empty() and not solo.has(String(s).get_file().get_basename()):
			continue
		if _lista.any(func(m): return String(m["scena"]) == s):
			await _scena(s)
	get_tree().quit()


## Al posto della ricerca: il controllo dei muri di questa scena.
func _candidati(spazio: PhysicsDirectSpaceState3D, _punti: Array) -> Array:
	var acque := []
	for n in _radice.find_children("*", "MeshInstance3D", true, false):
		var p := String(_radice.get_path_to(n)).to_lower()
		if p.contains("acqua") or p.contains("water") or p.contains("allag"):
			acque.append(n)
	for m in _lista:
		if String(m["scena"]) != _radice.scene_file_path:
			continue
		var c := Vector3(m["centro"][0], m["centro"][1], m["centro"][2])
		var n := Vector3(m["normale"][0], m["normale"][1], m["normale"][2]).normalized()
		var w := float(m["largo"])
		var h := float(m["alto"])
		var tang := Vector3.UP.cross(n).normalized()
		var piano := n.dot(c)
		var vuoti := 0
		var storti := 0
		var altro := {}
		for iu in 13:
			for iv in 7:
				var q := c + tang * (w * (float(iu) / 12.0 - 0.5)) + Vector3.UP * (h * (float(iv) / 6.0 - 0.5))
				var hh := _raggio(spazio, q + n * 0.6, q - n * 0.2)
				if hh.is_empty():
					vuoti += 1
					continue
				if absf(n.dot(hh.position as Vector3) - piano) > 0.035 or (hh.normal as Vector3).dot(n) < 0.95:
					storti += 1
				var mi: MeshInstance3D = _corpi.get(hh.rid)
				if mi == null or not _architettura(mi):
					var k := String(_radice.get_path_to(mi)) if mi else "?"
					altro[k] = int(altro.get(k, 0)) + 1
		# le mesh nella scatola della decal (verrebbero dipinte), e quanto sono lontane quelle vicine (entro 0,5 m)
		var scatola := AABB(c, Vector3.ZERO)
		for su in [-0.5, 0.5]:
			for la in [-0.5, 0.5]:
				for pr in [-0.12, 0.12]:
					scatola = scatola.expand(c + tang * w * la + Vector3.UP * h * su + n * pr)
		var dentro := []
		var vicine := []
		for o in _oggetti_box:
			var b := o[0] as AABB
			if b.intersects(scatola):
				dentro.append(o[1])
			elif b.intersects(scatola.grow(0.5)):
				vicine.append("%s a %.2f m" % [o[1], _distanza_box(b, scatola)])
		var acqua := []
		for a in acque:
			var b := (a as MeshInstance3D).global_transform * (a as MeshInstance3D).get_aabb()
			var orizz := AABB(Vector3(scatola.position.x, -1000, scatola.position.z), Vector3(scatola.size.x, 2000, scatola.size.z)).grow(0.3)
			if b.intersects(orizz) and b.size.y < 3.0:
				var pelo := b.end.y
				acqua.append("%s pelo %.2f, bordo basso del disegno %.2f (margine %.2f)" % [String(_radice.get_path_to(a)), pelo, c.y - h / 2.0, c.y - h / 2.0 - pelo])
		var ok := vuoti == 0 and storti == 0 and altro.is_empty() and dentro.is_empty()
		print("VERIFICA %s %s: vuoti %d, storti %d, altro %s, dentro %s" % [m["nome"], "OK" if ok else "NO", vuoti, storti, altro, dentro])
		for v in vicine:
			print("    vicino: ", v)
		for a in acqua:
			print("    acqua: ", a)
	return []


static func _distanza_box(a: AABB, b: AABB) -> float:
	var d := Vector3.ZERO
	for i in 3:
		d[i] = maxf(0.0, maxf(a.position[i] - b.end[i], b.position[i] - a.end[i]))
	return d.length()
