extends Node
## Ricontrollo (ambienti-1) del disegno guida dei giocattoli sulla struttura dell'area bimbi, i tre punti aperti del
## collaudo: le quattro fascette una per una (di fronte e di lato, sul bordo del cartoncino e sul corrimano), la Polaroid 4
## come la vede chi sale la scala della struttura, e il muro ovest della parte profonda della piscina a onde senza il
## disegno, con la piscina piena e vuota. Come scatti_disegno_torre.gd (di enigmi): la sala per parti, le mesh accese solo
## vicino alla camera.
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##     --script res://tests/run.gd -- res://tests/collaudo/ricontrollo_area_bimbi.gd <cartella> [luci]

const SALA := "res://scenes/sala_principale.tscn"
const PARTI := ["Sala", "LuciSala", "Piscina", "Polaroid"]
## La struttura (sala_struttura_gioco): x da -18,3 a -9,7, z da -20,7 a -14,3; la scala da x -14,95 (in basso) a
## -16,25 (in cima, 1,24 m), z da -16,55 a -14,45; la pedana verde a 1,24 m (x -18,15..-16,25, z -16,55..-14,65).
## [nome, occhi, verso] (gli occhi a 1,65 m da terra).
const VISTE_ENIGMI := {
	"giro": [
		["g1_da_sud_lontano", Vector3(-14.0, 1.65, -4.5), Vector3(-15.0, 1.6, -16.5)],
		["g2_da_sud_est", Vector3(-8.5, 1.65, -12.0), Vector3(-15.0, 1.6, -16.5)],
		["g3_piede_scala", Vector3(-13.2, 1.65, -14.6), Vector3(-16.5, 1.5, -15.5)],
		["g4_pedana_verde_da_sud", Vector3(-17.0, 1.65, -12.3), Vector3(-17.2, 1.7, -14.7)],
		["g5_da_ovest", Vector3(-22.0, 1.65, -15.5), Vector3(-17.5, 1.6, -17.0)],
		["g6_da_est_scivolo", Vector3(-6.5, 1.65, -15.0), Vector3(-12.5, 1.5, -18.0)],
		["g7_in_cima_scala", Vector3(-16.6, 1.24 + 1.65, -15.4), Vector3(-17.6, 1.24 + 1.0, -16.0)],
		["g8_da_nord_est", Vector3(-9.5, 1.65, -23.5), Vector3(-14.5, 1.6, -18.5)],
		["g9_piede_scala_verso_nord", Vector3(-13.6, 1.65, -14.6), Vector3(-14.2, 2.1, -17.45)],
		["g10_torre_arancio_da_sud", Vector3(-14.0, 1.65, -9.0), Vector3(-14.2, 2.0, -17.45)],
	],
	"disegno": [],
}

var raggio := float(OS.get_environment("SCATTI_RAGGIO")) if OS.has_environment("SCATTI_RAGGIO") else 22.0
var _cartella := ""
var _gruppo := "giro"
var _radice: Node3D
var _prima := {}
var _accese := {}


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	_cartella = a[1] if a.size() > 1 else "user://scatti_disegno_torre"
	_gruppo = "ricontrollo"
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	Grafica.salva_su_disco = false
	var radice := Node3D.new()
	radice.name = "SalaPerDisegno"
	_radice = radice
	get_tree().node_added.connect(_aggiunto)
	var tutta := (load(SALA) as PackedScene).instantiate()
	var look: LookSala = null
	for percorso in PARTI:
		var n := tutta.get_node_or_null(NodePath(percorso)) as Node3D
		if n == null:
			print("manca ", percorso)
			continue
		var tr := _globale(n, tutta)
		n.get_parent().remove_child(n)
		n.transform = tr
		radice.add_child(n)
		if n is LookSala:
			look = n
	tutta.free()
	if look == null:
		for c in radice.find_children("*", "LookSala", true, false):
			look = c
	var we := WorldEnvironment.new()
	we.environment = look.ambiente if look else (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment)
	we.camera_attributes = look.attributi_camera if look else null
	radice.add_child(we)
	var cam := Camera3D.new()
	cam.fov = 75.0
	radice.add_child(cam)
	get_tree().root.add_child(radice)
	get_tree().current_scene = radice
	cam.make_current()
	for i in 20:
		await get_tree().process_frame
	var luci := OS.get_cmdline_user_args()[2] if OS.get_cmdline_user_args().size() > 2 else "prima"
	GameState.imposta_luci(GameState.Luci.BLACKOUT if luci == "blackout" else GameState.Luci.PRIMA_DEL_RISVEGLIO)
	DirAccess.make_dir_recursive_absolute(_cartella)
	var viste: Array = _viste_ricontrollo()
	var piscina: Node = null
	for c in _radice.find_children("*", "Node", true, false):
		var sc := (c as Node).get_script() as Script
		if sc and sc.resource_path.ends_with("piscina_onde.gd"):
			piscina = c
	for v in viste:
		var riempi: Variant = v[3] if v.size() > 3 else null
		if riempi != null and piscina and piscina.get(&"vasca"):
			(piscina.get(&"vasca") as Object).set(&"fill", float(v[3]))
			print("PISCINA: fill %.1f" % float(v[3]))
		cam.fov = 75.0 if v.size() < 5 else float(v[4])
		cam.global_position = v[1]
		cam.look_at(v[2], Vector3.UP)
		_accendi(cam.global_position)
		for i in (12 if riempi == null else 90):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_jpg(_cartella.path_join("%s_%s.jpg" % [luci, v[0]]), 0.9)
		print("SCATTO ", v[0])
	print("memoria massima del processo %d MB" % (OS.get_static_memory_peak_usage() / 1048576))
	print("FINE")
	get_tree().quit()


## La Polaroid 4 com'è nella scena della sala (sala_principale.tscn).
const P4_SCENA := Transform3D(Basis(Vector3(0.980033, -0.006981, -0.198714), Vector3(0.009703, 0.999872, 0.012727),
		Vector3(0.198599, -0.014401, 0.979975)), Vector3(-16.03, 1.2416, -15.3499))


## Le viste del ricontrollo: [nome, camera, verso, (riempimento della piscina), (fov)]. Con SOLO=p4 solo la Polaroid, con
## SOLO=fascette solo le fascette.
func _viste_ricontrollo() -> Array:
	var out := []
	var solo := OS.get_environment("SOLO")
	var d := _radice.find_child("Disegno", true, false) as Node3D
	if d and solo in ["", "fascette"]:
		var n := d.global_basis.z.normalized()
		var lato := n.cross(Vector3.UP).normalized()
		for k in range(1, 5):
			var f := d.find_child("Fascetta%d" % k, true, false) as Node3D
			if f == null:
				print("manca Fascetta%d" % k)
				continue
			# (il centro della mesh dell'anello: nella versione ad anello l'origine del nodo è al centro del cartoncino)
			var c := f.global_position
			var box := AABB()
			var primo := true
			for m in [f] + f.find_children("*", "MeshInstance3D", true, false):
				if m is MeshInstance3D:
					var b := (m as MeshInstance3D).global_transform * (m as MeshInstance3D).get_aabb()
					box = b if primo else box.merge(b)
					primo = false
			if not primo:
				c = box.get_center()
			var fuori := signf((c - d.global_position).dot(lato))   # verso il bordo del cartoncino
			print("FASCETTA %d in %s" % [k, str(c.snapped(Vector3.ONE * 0.001))])
			out.append(["f%d_di_fronte" % k, c + n * 0.22 + Vector3.UP * 0.02, c, null, 40.0])
			out.append(["f%d_dal_bordo" % k, c + n * 0.06 + lato * fuori * 0.2 + Vector3.UP * 0.03, c - n * 0.03, null, 50.0])
			out.append(["f%d_da_dietro" % k, c - n * 0.25 + lato * fuori * 0.08 + Vector3.UP * 0.03, c - n * 0.03, null, 50.0])
	# la Polaroid 4 sulla pedana verde (1,24 m), come la vede chi sale la scala (da est verso ovest) e da sopra
	var p4 := _radice.find_child("Polaroid04", true, false) as Node3D
	if p4 and solo in ["", "p4"]:
		# (nella sala a pezzi Posa la appoggia su quello che trova sotto: qui la struttura non ha la collisione e la
		# Polaroid cadeva 63 cm più giù; si rimette dov'è nella scena, sulla pedana a 1,24 m, come nel gioco)
		print("P4 dopo Posa in %s" % str(p4.global_position.snapped(Vector3.ONE * 0.01)))
		p4.global_transform = P4_SCENA
		var c := p4.global_position
		print("P4 in %s" % str(c.snapped(Vector3.ONE * 0.01)))
		out.append(["p4_dal_piede_della_scala", Vector3(-13.6, 1.6, -15.4), c])
		out.append(["p4_a_meta_scala", Vector3(-15.5, 0.6 + 1.6, -15.45), c])
		out.append(["p4_sul_penultimo_gradino", Vector3(-15.95, 1.05 + 1.6, -15.45), c])
		out.append(["p4_da_sud", Vector3(-15.2, 1.6, -12.8), c])
		out.append(["p4_da_vicino", c + Vector3(0.35, 0.45, 0.1), c, null, 50.0])
	var e := _radice.find_child("EnigmaGiocattoli", true, false) as Node3D
	if e and solo.is_empty():
		for pieno in [1.0, 0.0]:
			var nome := "piena" if pieno > 0.5 else "vuota"
			out.append(["muro_piscina_%s" % nome, e.to_global(Vector3(-3.5, 0.9, -0.2)), e.to_global(Vector3(-6.97, -0.8, -0.2)), pieno])
			out.append(["muro_piscina_%s_da_vicino" % nome, e.to_global(Vector3(-5.2, 0.4, -0.2)), e.to_global(Vector3(-6.97, -1.2, -0.2)), pieno])
	return out


## Le viste del disegno sulla struttura (dove l'ha messo EnigmaGiocattoli) e del muro della piscina dove stava.
func _viste_disegno() -> Array:
	var out := []
	var solo := OS.get_environment("SOLO")
	var d := _radice.find_child("Disegno", true, false) as Node3D
	if d and solo.is_empty():
		var c := d.global_position
		var n := d.global_basis.z.normalized()
		var lato := n.cross(Vector3.UP).normalized()
		var terra := Vector3(c.x, 0.0, c.z)
		# (davanti alla pedana, a sud-ovest, c'è un fungo: le viste da lontano sono da sud e da sud-est)
		out.append(["d1_da_sud_est_4m", terra + n * 4.0 - lato * 2.5 + Vector3(0, 1.65, 0), c])
		out.append(["d2_davanti_1m", terra + n * 0.9 - lato * 0.3 + Vector3(0, 1.65, 0), c])
		out.append(["d3_di_sbieco", terra + n * 3.0 - lato * 4.0 + Vector3(0, 1.65, 0), c])
		out.append(["d4_dal_percorso_lontano", Vector3(-14.0, 1.65, -9.0), c])
		out.append(["d5_attacchi_da_vicino", terra + n * 0.45 + lato * 0.35 + Vector3(0, c.y - 0.05, 0), c + lato * 0.3])
		out.append(["d6_di_lato_distacco", c + n * 0.12 + lato * 0.9, c])
	var e := _radice.find_child("EnigmaGiocattoli", true, false) as Node3D
	if e:
		# il muro ovest della parte profonda, dove stava (a -6,97, -0,8, -0,2 nel sistema dell'enigma)
		out.append(["d7_muro_piscina", e.to_global(Vector3(-3.5, 0.9, -0.2)), e.to_global(Vector3(-6.97, -0.8, -0.2))])
	return out


static func _globale(n: Node3D, tutta: Node) -> Transform3D:
	var tr := n.transform
	var q := n.get_parent()
	while q and q != tutta:
		if q is Node3D:
			tr = (q as Node3D).transform * tr
		q = q.get_parent()
	if tutta is Node3D:
		tr = (tutta as Node3D).transform * tr
	return tr


func _aggiunto(n: Node) -> void:
	if n is GeometryInstance3D and _radice and _radice.is_ancestor_of(n) and not _accese.has(n):
		if not _prima.has(n):
			_prima[n] = (n as GeometryInstance3D).visible
		(n as GeometryInstance3D).visible = false


func _accendi(da: Vector3) -> void:
	_accese.clear()
	var n_accese := 0
	for n in _radice.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if not _prima.has(g):
			_prima[g] = g.visible
		var b := g.global_transform * g.get_aabb()
		var vicino := da.clamp(b.position, b.end).distance_to(da) < raggio and bool(_prima[g])
		if vicino:
			_accese[g] = true
			n_accese += 1
		g.visible = vicino
	print("mesh accese %d di %d" % [n_accese, _prima.size()])
