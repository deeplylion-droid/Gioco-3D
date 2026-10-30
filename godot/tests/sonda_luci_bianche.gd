extends Node
## Sonda: nel gioco vero, dopo una partenza del menu di prova (come F9), le luci bianche e i materiali delle lampade
## che al momento del disegno NON sono a fattore × base (LuciBianche, 0,4). Prima di disegnare si legge l'energia
## "di base" (in _process), poi in frame_pre_draw, dopo LuciBianche.applica, quella che si disegna: le bianche non
## escluse devono essere al 40%. Stampa le luci e i materiali piene, poi muore, riparte dal checkpoint e rifà la
## misura.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/sonda_luci_bianche.gd <fiume|tunnel|inseguimento>

var _lb: Node
var _base_luci := {}
var _base_mat := {}
var _misura := false
var _piene := {}
var _mat_pieni := {}
var _escluse := {}
var _disegnata := {}
var _mat_vicini := {}
var _mat_al_disegno := {}


func _ready() -> void:
	_lb = get_node(^"/root/LuciBianche")
	process_priority = -1000
	_run.call_deferred()


func _process(_d: float) -> void:
	if not _misura:
		return
	_base_luci.clear()
	for l: Light3D in get_tree().root.find_children("*", "Light3D", true, false):
		_base_luci[l.get_instance_id()] = l.light_energy
	_base_mat.clear()
	for g: GeometryInstance3D in get_tree().root.find_children("*", "GeometryInstance3D", true, false):
		for m in _materiali(g):
			if m.emission_enabled and VarianteLuci.is_bianca(m.emission) and m.emission_energy_multiplier >= 0.3:
				_base_mat[m.get_instance_id()] = [m, m.emission_energy_multiplier, g]
				if g.is_visible_in_tree() and GameState.player and is_instance_valid(GameState.player) \
						and GameState.player.global_position.distance_to(g.global_position) < 30.0:
					_mat_vicini[m.get_instance_id()] = [m, m.emission_energy_multiplier, g]
	# (senza schermo non si disegna e LuciBianche non applica: lo fa la sonda a fine fotogramma, come il disegno)
	if DisplayServer.get_name() == "headless":
		_disegno_finto.call_deferred()


func _disegno_finto() -> void:
	_lb.call(&"applica")
	_prima_del_disegno()
	_lb.call(&"ripristina")


func _materiali(g: GeometryInstance3D) -> Array:
	var out := []
	for m in [g.material_override, g.material_overlay]:
		if m is BaseMaterial3D:
			out.append(m)
	if g is MeshInstance3D and (g as MeshInstance3D).mesh:
		var mi := g as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			for m in [mi.get_surface_override_material(s), mi.mesh.surface_get_material(s)]:
				if m is BaseMaterial3D:
					out.append(m)
	return out


var _chiamate := 0
var _bianche_viste := 0


func _prima_del_disegno() -> void:
	if not _misura:
		return
	_chiamate += 1
	var p := GameState.player
	for l: Light3D in get_tree().root.find_children("*", "Light3D", true, false):
		_disegnata[l.get_instance_id()] = l.light_energy
		if not l.is_visible_in_tree() or not VarianteLuci.is_bianca(l.light_color):
			continue
		if _lb.call(&"_esclusa", l) or _lb.call(&"_nome_colorato", l.name):
			if p and is_instance_valid(p) and p.global_position.distance_to(l.global_position) < 30.0 and l.light_energy > 0.0:
				_escluse[l.get_instance_id()] = "%s energia %.2f a %.1f m%s" % [l.get_path(), l.light_energy,
					p.global_position.distance_to(l.global_position), " (nome colorato)" if _lb.call(&"_nome_colorato", l.name) else ""]
			continue
		var b: float = _base_luci.get(l.get_instance_id(), -1.0)
		if b <= 0.0:
			continue
		_bianche_viste += 1
		if l.light_energy > b * 0.5:
			var d := p.global_position.distance_to(l.global_position) if p and is_instance_valid(p) else -1.0
			_piene[l.get_instance_id()] = "%s energia %.2f (base %.2f) a %.1f m" % [l.get_path(), l.light_energy, b, d]
	for id in _mat_vicini:
		_mat_al_disegno[id] = (_mat_vicini[id][0] as BaseMaterial3D).emission_energy_multiplier
	for id in _base_mat:
		var e: Array = _base_mat[id]
		var m: BaseMaterial3D = e[0]
		if is_instance_valid(e[2]) and m.emission_energy_multiplier > float(e[1]) * 0.5 and _lb.call(&"_lampada", e[2]) \
				and not _lb.call(&"_esclusa", e[2]):
			_mat_pieni[id] = "%s su %s emissione %.2f" % [m.resource_name, (e[2] as Node).get_path(), m.emission_energy_multiplier]


func _misura_per(fotogrammi: int, titolo: String) -> void:
	_piene.clear()
	_mat_pieni.clear()
	_escluse.clear()
	_misura = true
	for i in fotogrammi:
		await get_tree().process_frame
	_misura = false
	print("   (pre_draw chiamato %d volte, luci bianche guardate %d)" % [_chiamate, _bianche_viste])
	var nv: Object = Grafica.get(&"nebbia_viola")
	if nv:
		var zone := []
		for z in get_tree().get_nodes_in_group(&"zone_nebbia_viola"):
			zone.append("%s dentro=%s" % [z.get_path(), z.call(&"contiene", GameState.player.global_position) if z.has_method(&"contiene") else "?"])
		print("   nebbia viola: quanto %.2f, in zona %s, accesa %s, giocatore %s; zone %s" % [nv.get(&"quanto"), nv.call(&"in_zona"), nv.get(&"accesa"), GameState.player.global_position, zone])
	_chiamate = 0
	_bianche_viste = 0
	print("== %s: %d luci bianche piene, %d materiali di lampade pieni (LuciBianche: %d luci, %d materiali raccolti)" % [
		titolo, _piene.size(), _mat_pieni.size(), (_lb.call(&"luci_raccolte") as Array).size(),
		(_lb.call(&"materiali_raccolti") as Array).size()])
	for k in _piene:
		print("  LUCE ", _piene[k])
	for k in _mat_pieni:
		print("  MATERIALE ", _mat_pieni[k])
	for k in _escluse:
		print("  ESCLUSA ", _escluse[k])
	for id in _mat_vicini:
		var e: Array = _mat_vicini[id]
		print("  MATVICINO %s su %s base %.2f al disegno %.2f" % [(e[0] as Resource).resource_name, (e[2] as Node).name if is_instance_valid(e[2]) else "?",
			e[1], _mat_al_disegno.get(id, -1.0)])
	_mat_vicini.clear()
	_ambiente()
	# tutte le luci accese entro 30 m, come si disegnano (per il confronto fra le versioni)
	var pg := GameState.player.global_position
	for l: Light3D in get_tree().root.find_children("*", "Light3D", true, false):
		if l.is_visible_in_tree() and pg.distance_to(l.global_position) < 30.0:
			print("  TUTTE %s col %s energia %.2f a %.1f m ombra %s" % [l.get_path(), l.light_color.to_html(false),
				_disegnata.get(l.get_instance_id(), l.light_energy), pg.distance_to(l.global_position), l.shadow_enabled])


func _aspetta_giocatore(vecchio: Node) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 240000:
		await get_tree().process_frame
		var p := GameState.player
		if p and is_instance_valid(p) and p != vecchio and p.is_inside_tree() and p.input_enabled and not GameState.is_dying:
			break
	await Game.aspetta_caricamenti(get_tree().current_scene, 120.0)
	for i in 60:
		await get_tree().process_frame


func _run() -> void:
	Game.pause_on_focus_loss = false
	RenderingServer.frame_pre_draw.connect(_prima_del_disegno)
	var id: String = OS.get_cmdline_user_args()[1] if OS.get_cmdline_user_args().size() > 1 else "fiume"
	print("partenza ", id, " fattore ", _lb.get(&"fattore"))
	var poi_fiume := id == "risalita_poi_fiume"
	if poi_fiume:
		id = "risalita"
	if not MenuProva.parti(get_tree(), id):
		print("partenza non trovata")
		Game.esci(1)
		return
	await _aspetta_giocatore(null)
	if poi_fiume:
		# (la Risalita caricata più tardi, come nel gioco: dalla sua partenza si va al fiume e si aspettano le zone)
		await _misura_per(30, "alla partenza della Risalita")
		GameState.player.teleport(Vector3(-7.6, -5.35, 66.0), 0.0, 0.0)
		await Game.aspetta_caricamenti(get_tree().current_scene, 120.0)
		for i in 300:
			await get_tree().process_frame
	await _misura_per(30, "dopo la partenza")
	var vecchio := GameState.player
	GameState.kill_player()
	await _aspetta_giocatore(vecchio)
	await _misura_per(30, "dopo una morte")
	Game.esci(0)


## L'ambiente che si disegna, gli attributi della camera e gli strati sopra la scena (per il confronto fra le versioni).
func _ambiente() -> void:
	var vp := get_viewport()
	var cam := vp.get_camera_3d()
	var env: Environment = vp.world_3d.environment if vp.world_3d else null
	if cam and cam.environment:
		env = cam.environment
	for we in get_tree().root.find_children("*", "WorldEnvironment", true, false):
		print("  AMB WorldEnvironment %s dentro %s env %s" % [we.get_path(), we.is_inside_tree(), (we as WorldEnvironment).environment])
	if env:
		for k in ["background_mode", "background_energy_multiplier", "ambient_light_source", "ambient_light_energy", "ambient_light_color",
				"ambient_light_sky_contribution", "tonemap_mode", "tonemap_exposure", "tonemap_white", "glow_enabled", "glow_intensity",
				"glow_bloom", "fog_enabled", "fog_density", "fog_light_color", "fog_light_energy", "volumetric_fog_enabled",
				"volumetric_fog_density", "volumetric_fog_albedo", "volumetric_fog_emission", "volumetric_fog_emission_energy",
				"volumetric_fog_gi_inject", "volumetric_fog_ambient_inject", "ssao_enabled", "ssil_enabled", "sdfgi_enabled",
				"ssr_enabled", "adjustment_enabled", "adjustment_brightness", "adjustment_contrast", "adjustment_saturation",
				"adjustment_color_correction"]:
			print("  AMB %s = %s" % [k, env.get(k)])
	if cam and cam.attributes:
		for k in ["exposure_multiplier", "exposure_sensitivity", "auto_exposure_enabled", "dof_blur_far_enabled"]:
			print("  AMB cam %s = %s" % [k, cam.attributes.get(k)])
	for c: CanvasLayer in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if c.visible:
			for f in c.get_children():
				if f is CanvasItem and (f as CanvasItem).visible:
					print("  AMB strato %s layer %d figlio %s modulate %s" % [c.get_path(), c.layer, f.name, (f as CanvasItem).modulate])
	print("  AMB grafica %s" % [Grafica.get(&"valori")])
