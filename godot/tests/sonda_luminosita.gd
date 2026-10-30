extends Node
## grafica-2, 30 ottobre: «diversi ambienti più luminosi di prima?» (riscontro dell'utente sulla 0.3.16).
## Senza schermo, nel gioco vero: per ogni partenza del menu di prova (come F9), e di nuovo dopo una morte, quello che
## illumina il giocatore come lo disegnerebbe il motore (LuciBianche applicata, come al disegno):
## - le luci accese entro 30 m: quante, e la luce che arriva agli occhi (somma di energia × luminanza del colore / d²,
##   senza ombre né coni: una misura per confrontare le versioni, non i lux);
## - le lampade bianche (emissione) e l'ambiente (luce ambiente, cielo, esposizione, tonemap, regolazioni, glow, nebbie);
## - le opzioni grafiche che toccano la luce.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/sonda_luminosita.gd [partenze]

const PARTENZE := ["fiume", "tunnel", "risalita", "torre", "inseguimento"]
const RAGGIO := 30.0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	var a := OS.get_cmdline_user_args()
	var lista: Array = Array(a[1].split(",")) if a.size() > 1 else PARTENZE
	print("SONDA versione %s" % ProjectSettings.get_setting("application/config/version"))
	print("SONDA opzioni: %s" % _opzioni())
	for id in lista:
		if not MenuProva.parti(get_tree(), id):
			print("SONDA %s: partenza assente" % id)
			continue
		await _aspetta_giocatore(null)
		_sonda("%s_partenza" % id)
		var vecchio := GameState.player
		GameState.kill_player()
		await _aspetta_giocatore(vecchio)
		_sonda("%s_morte" % id)
	print("SONDA FINE")
	Game.esci(0)


func _opzioni() -> String:
	var g := get_node_or_null(^"/root/Grafica")
	if g == null:
		return "-"
	var v: Dictionary = g.get(&"valori")
	var out := []
	for k in v:
		if k is String and (k.contains("lumin") or k.contains("gamma") or k.contains("glow") or k.contains("esposiz")
				or k.contains("nebbia") or k.contains("preset") or k.contains("contrast") or k.contains("grana")
				or k.contains("vignet") or k.contains("ombre") or k.contains("gi")):
			out.append("%s=%s" % [k, v[k]])
	return ", ".join(out)


func _sonda(nome: String) -> void:
	var p := GameState.player as Node3D
	var cam := get_viewport().get_camera_3d()
	var occhio: Vector3 = cam.global_position if cam else p.global_position + Vector3.UP * 1.6
	var lb := get_node_or_null(^"/root/LuciBianche")
	if lb and lb.has_method(&"applica"):
		lb.call(&"applica")
	var n := 0
	var arriva := 0.0
	var arriva_bianche := 0.0
	var energia := 0.0
	var dettagli := []
	for l: Light3D in get_tree().root.find_children("*", "Light3D", true, false):
		if not l.is_visible_in_tree() or l.light_energy <= 0.0:
			continue
		if l is DirectionalLight3D:
			dettagli.append("dir %s %.2f" % [l.name, l.light_energy])
			continue
		var d := l.global_position.distance_to(occhio)
		if d > RAGGIO:
			continue
		n += 1
		var e := l.light_energy * l.light_color.get_luminance() / maxf(d * d, 1.0)
		arriva += e
		energia += l.light_energy
		if lb and VarianteLuci.is_bianca(l.light_color):
			arriva_bianche += e
		dettagli.append([e, "%s %.2f a %.1f m" % [l.name, l.light_energy, d]])
	var bianche := 0.0
	for g: GeometryInstance3D in get_tree().root.find_children("*", "GeometryInstance3D", true, false):
		if not g.is_visible_in_tree() or g.global_position.distance_to(occhio) > RAGGIO:
			continue
		var m := g.material_override as BaseMaterial3D
		if m and m.emission_enabled and VarianteLuci.is_bianca(m.emission):
			bianche += m.emission_energy_multiplier
	if lb and lb.has_method(&"ripristina"):
		lb.call(&"ripristina")
	var forti := dettagli.filter(func(x): return x is Array)
	forti.sort_custom(func(x, y): return x[0] > y[0])
	print("SONDA %s: luci %d, energia %.1f, arriva agli occhi %.3f (bianche %.3f), lampade bianche (override) %.1f; occhio %s" % [
			nome, n, energia, arriva, arriva_bianche, bianche, occhio.snapped(Vector3.ONE * 0.1)])
	print("SONDA %s forti: %s" % [nome, ", ".join(forti.slice(0, 6).map(func(x): return "%s (%.3f)" % [x[1], x[0]]))])
	print("SONDA %s ambiente: %s" % [nome, _ambiente(cam)])
	var nv := get_node_or_null(^"/root/Grafica/NebbiaViola")
	if nv:
		print("SONDA %s nebbia viola: quanto %.2f, accesa %s" % [nome, float(nv.get(&"quanto")), nv.get(&"accesa")])


func _ambiente(cam: Camera3D) -> String:
	var env: Environment = null
	var attr: CameraAttributes = null
	if cam:
		env = cam.environment
		attr = cam.attributes
	var we := get_tree().root.find_children("*", "WorldEnvironment", true, false)
	for w: WorldEnvironment in we:
		if w.is_inside_tree():
			if env == null:
				env = w.environment
			if attr == null:
				attr = w.camera_attributes
	if env == null:
		return "nessuno"
	var s := "ambiente %s %.2f col %s, cielo %.2f, tonemap %d esp %.2f bianco %.2f, regola %s lum %.2f contr %.2f sat %.2f, glow %s %.2f, nebbia %s %.4f, volumetrica %s %.4f, ssao %s, ssil %s, sdfgi %s" % [
			env.ambient_light_source, env.ambient_light_energy, env.ambient_light_color.to_html(false), env.background_energy_multiplier,
			env.tonemap_mode, env.tonemap_exposure, env.tonemap_white, env.adjustment_enabled, env.adjustment_brightness,
			env.adjustment_contrast, env.adjustment_saturation, env.glow_enabled, env.glow_intensity, env.fog_enabled,
			env.fog_density, env.volumetric_fog_enabled, env.volumetric_fog_density, env.ssao_enabled, env.ssil_enabled,
			env.sdfgi_enabled]
	if attr:
		s += ", esposizione camera %.2f auto %s" % [attr.exposure_multiplier, attr.auto_exposure_enabled]
	return s


func _aspetta_giocatore(vecchio: Node) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 240000:
		await get_tree().process_frame
		var p := GameState.player
		if p and is_instance_valid(p) and p != vecchio and p.is_inside_tree() and p.input_enabled and not GameState.is_dying:
			break
	if Game.has_method(&"aspetta_caricamenti"):
		await Game.aspetta_caricamenti(get_tree().current_scene, 120.0)
	for i in 60:
		await get_tree().process_frame
