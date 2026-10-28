extends Node
## Collaudo delle Polaroid (squadra collaudo): nella sala intera, in uno stato del capitolo (stati.gd), per ogni Polaroid
## quanto sta staccata dalla superficie che si vede sotto (dalla mesh, non dalla collisione): sotto i quattro angoli e
## il centro, la mesh visibile più alta; distacco = fondo della Polaroid - quella superficie (negativo: dentro).
## Poi se si raccoglie: il giocatore a 0,9 m dalla parte più libera, la guarda e preme E; la collezione deve salire.
## Stampa anche il totale della collezione. Con "partenze": per ogni partenza del menu F9 quali Polaroid sono già
## raccolte (nell'istantanea) e quali sono ancora nel mondo.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/sonda_polaroid.gd \
##        <stato|partenze> [solo,id,...]

const LEVEL := "res://scenes/sala_principale.tscn"
const STATI := preload("res://tests/collaudo/stati.gd")
var solo := PackedStringArray()


func _ready() -> void:
	_run.call_deferred()


func _passa(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var stato := a[1]
	if a.size() > 2:
		solo = a[2].split(",")
	Game.pause_on_focus_loss = false
	if stato == "partenze":
		await _partenze()
		get_tree().quit()
		return
	GameState.reset_progress()
	get_tree().change_scene_to_file(LEVEL)
	for i in 900:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and get_tree().current_scene:
			break
	var level := get_tree().current_scene
	var p := GameState.player
	for i in 3600:
		if p.input_enabled:
			break
		await get_tree().physics_frame
	STATI.applica(level, stato)
	# le stanze della Risalita e la torre, come più avanti nel gioco
	var ris := level.get_node_or_null(^"Risalita")
	if ris and ris.get(&"fiume") == null and ris.has_method(&"carica_subito"):
		ris.call(&"carica_subito")
	if level.has_method(&"_carica_torre"):
		level.call(&"_carica_torre")
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 240000:
		await get_tree().process_frame
		var lavori := level.has_method(&"lavori_in_corso") and bool(level.call(&"lavori_in_corso"))
		if not lavori and not Game.caricamenti_in_corso() and level.get(&"sala_torre") != null \
				and (ris == null or ris.get(&"fiume") != null):
			break
	# le Polaroid nuove si appoggiano dopo (Posa, fino a 20 s se il pavimento arriva dopo)
	await get_tree().create_timer(3.0).timeout
	STATI.mostra_nascosti(level)
	await _passa(10)
	print("POLAROID: stato %s, torre %s, fiume %s, totale della collezione %d, raccolte %d" % [stato, level.get(&"sala_torre") != null,
		ris != null and ris.get(&"fiume") != null, GameState.get_total(&"polaroid"), GameState.get_collected_count(&"polaroid")])
	var foto: Array = level.find_children("*", "PolaroidPhoto", true, false)
	foto.sort_custom(func(x, y): return int(x.photo) < int(y.photo))
	for f in foto:
		if not solo.is_empty() and not String(f.entry_id) in solo:
			continue
		_misura(f as PolaroidPhoto, level)
	# la P13 sotto l'oblò del fiume: lei compare dietro il vetro e poi si stacca
	var p13: PolaroidPhoto = null
	for f in foto:
		if int(f.photo) == 13:
			p13 = f
	var oblo := level.find_child("ObloFiume", true, false)
	if p13 and oblo and oblo.has_method(&"_mostra"):
		GameState.imposta_luci(GameState.Luci.BLACKOUT)
		oblo.call(&"_mostra")
		await _passa(90)
		print("POLAROID: oblò del fiume con lei comparsa (stato %s)" % oblo.get(&"stato"))
		_misura(p13, level)
		_vicino_a_lei(p13, oblo, level)
		if oblo.has_method(&"_stacca"):
			oblo.call(&"_stacca")
		await _passa(240)
		print("POLAROID: oblò del fiume, lei staccata (stato %s)" % oblo.get(&"stato"))
		_misura(p13, level)
	for f in foto:
		if not solo.is_empty() and not String(f.entry_id) in solo:
			continue
		if is_instance_valid(f) and (f as Node3D).is_visible_in_tree():
			await _raccogli(f as PolaroidPhoto, p)
	print("POLAROID: finito, raccolte %d su %d" % [GameState.get_collected_count(&"polaroid"), GameState.get_total(&"polaroid")])
	get_tree().quit()


func _mesh_di(n: Node) -> Array:
	var out := []
	for m in n.find_children("*", "MeshInstance3D", true, false):
		if (m as MeshInstance3D).is_visible_in_tree() and (m as MeshInstance3D).mesh:
			out.append(m)
	return out


func _misura(f: PolaroidPhoto, level: Node) -> void:
	var proprie := _mesh_di(f)
	if proprie.is_empty():
		print("POLAROID: %s P%d senza mesh visibile (in %s)" % [f.entry_id, f.photo, f.global_position])
		return
	var bb := AABB()
	var primo := true
	for m in proprie:
		var b := (m as MeshInstance3D).global_transform * (m as MeshInstance3D).get_aabb()
		bb = b if primo else bb.merge(b)
		primo = false
	var fondo := bb.position.y
	# i punti: i quattro angoli (un po' dentro) e il centro del riquadro della Polaroid, nel suo piano
	var bas := f.global_transform.basis.orthonormalized()
	var mezzo := bb.size * 0.5
	var ax := Vector3(bas.x.x, 0, bas.x.z).normalized()
	var az := Vector3(bas.z.x, 0, bas.z.z).normalized()
	var lx: float = 0.0
	var lz: float = 0.0
	for m in proprie:
		var ab := (m as MeshInstance3D).get_aabb()
		lx = maxf(lx, ab.size.x * 0.5 * (m as MeshInstance3D).global_transform.basis.get_scale().x)
		lz = maxf(lz, ab.size.z * 0.5 * (m as MeshInstance3D).global_transform.basis.get_scale().z)
	var c := bb.get_center()
	var punti := [c]
	for sx in [-0.85, 0.85]:
		for sz in [-0.85, 0.85]:
			punti.append(c + ax * lx * sx + az * lz * sz)
	# le mesh vicine visibili (non della Polaroid)
	var vicine := []   # [facce, trasformazione, nome]
	var zona := AABB(c - Vector3(0.4, 0.6, 0.4), Vector3(0.8, 0.9, 0.8))
	for m in level.find_children("*", "GeometryInstance3D", true, false):
		var gi := m as GeometryInstance3D
		if gi in proprie or not gi.is_visible_in_tree() or f.is_ancestor_of(gi):
			continue
		if not (gi.global_transform * gi.get_aabb()).intersects(zona):
			continue
		if gi is MeshInstance3D and (gi as MeshInstance3D).mesh:
			vicine.append([(gi as MeshInstance3D).mesh.get_faces(), gi.global_transform, String(gi.name)])
		elif gi is MultiMeshInstance3D and (gi as MultiMeshInstance3D).multimesh and (gi as MultiMeshInstance3D).multimesh.mesh:
			var mm := (gi as MultiMeshInstance3D).multimesh
			var facce := mm.mesh.get_faces()
			for k in mm.instance_count:
				var t := gi.global_transform * mm.get_instance_transform(k)
				if (t * mm.mesh.get_aabb()).intersects(zona):
					vicine.append([facce, t, String(gi.name)])
	var distacchi: PackedFloat32Array = []
	var sotto: PackedStringArray = []
	for q in punti:
		var piu_alta := -INF
		var chi := ""
		var da: Vector3 = Vector3(q.x, fondo + 0.25, q.z)
		for v in vicine:
			var facce: PackedVector3Array = v[0]
			var t: Transform3D = v[1]
			for i in range(0, facce.size(), 3):
				var hit = Geometry3D.ray_intersects_triangle(da, Vector3.DOWN, t * facce[i], t * facce[i + 1], t * facce[i + 2])
				if hit != null and (hit as Vector3).y > piu_alta:
					piu_alta = (hit as Vector3).y
					chi = v[2]
		distacchi.append(fondo - piu_alta if piu_alta > -INF else 99.0)
		sotto.append(chi)
	var mn := 99.0
	var mx := -99.0
	for d in distacchi:
		mn = minf(mn, d)
		mx = maxf(mx, d)
	var esito := "OK"
	if mx > 0.008 or mn < -0.003:
		esito = "DA GUARDARE"
	print("POLAROID: %s P%d in %s, fondo %.3f, distacco sotto centro e angoli (mm) %s, sotto %s, fra %d mesh vicine: %s" % [
		f.entry_id, f.photo, f.global_position.snapped(Vector3.ONE * 0.001), fondo,
		", ".join(Array(distacchi).map(func(d): return "%.1f" % (d * 1000.0))), ",".join(sotto), vicine.size(), esito])


func _raccogli(f: PolaroidPhoto, p: Player) -> void:
	var eid := String(f.entry_id)
	var num := f.photo
	var prima := GameState.get_collected_count(&"polaroid")
	var c := f.global_position
	var spazio := p.get_world_3d().direct_space_state
	var dove := Vector3.INF
	for k in 12:
		var ang := TAU * k / 12.0
		var q := c + Vector3(sin(ang), 0, cos(ang)) * 0.9
		var su := PhysicsRayQueryParameters3D.create(c + Vector3.UP * 0.3, q + Vector3.UP * 0.3)
		su.exclude = [p.get_rid()]
		if not spazio.intersect_ray(su).is_empty():
			continue
		var giu := PhysicsRayQueryParameters3D.create(q + Vector3.UP * 1.0, q + Vector3.DOWN * 1.0)
		var h := spazio.intersect_ray(giu)
		if not h.is_empty() and absf((h.position as Vector3).y - c.y) < 0.4:
			dove = h.position
			break
	if dove == Vector3.INF:
		print("POLAROID: %s P%d nessun posto libero a 0,9 m per raccoglierla" % [eid, num])
		return
	p.teleport(dove + Vector3.UP * 0.05, 0.0, 0.0)
	for i in 10:
		await get_tree().physics_frame
	var mira := f.global_position + Vector3.UP * 0.01
	p.look_at_point(mira)
	for i in 4:
		await get_tree().physics_frame
	var vista = p.interactor.current
	Input.action_press(&"interact")
	await _passa(3)
	Input.action_release(&"interact")
	await _passa(20)
	# il visore della foto: si chiude
	Input.action_press(&"interact")
	await _passa(3)
	Input.action_release(&"interact")
	await _passa(10)
	Input.action_press(&"ui_cancel")
	await _passa(3)
	Input.action_release(&"ui_cancel")
	await _passa(20)
	if get_tree().paused:
		get_tree().paused = false
	print("POLAROID: %s P%d raccolta %s (collezione da %d a %d), dal punto %s il raggio trovava %s" % [eid, num,
		GameState.get_collected_count(&"polaroid") > prima, prima, GameState.get_collected_count(&"polaroid"),
		dove.snapped(Vector3.ONE * 0.01), vista])


func _partenze() -> void:
	for pt in MenuProva.PARTENZE:
		var id := String(pt["id"])
		var d := MenuProva.istantanea(id)
		if d.is_empty():
			continue
		var coll: Dictionary = d.get("collectibles", {})
		var lista: Array = coll.get("polaroid", [])
		lista = lista.duplicate()
		lista.sort()
		print("POLAROID: partenza %s (checkpoint %s): Polaroid raccolte %d: %s" % [id, d.get("checkpoint", "-"), lista.size(), ", ".join(lista)])


## Le mesh di lei e della sua vasca dietro l'oblò vicino alla Polaroid: se il loro riquadro tocca quello della Polaroid.
func _vicino_a_lei(f: PolaroidPhoto, oblo: Node, level: Node) -> void:
	var bb := AABB()
	var primo := true
	for m in _mesh_di(f):
		var b := (m as MeshInstance3D).global_transform * (m as MeshInstance3D).get_aabb()
		bb = b if primo else bb.merge(b)
		primo = false
	var tocca: PackedStringArray = []
	var n := 0
	for m in oblo.find_children("*", "GeometryInstance3D", true, false):
		var gi := m as GeometryInstance3D
		if not gi.is_visible_in_tree():
			continue
		n += 1
		if (gi.global_transform * gi.get_aabb()).intersects(bb.grow(0.02)):
			tocca.append(String(gi.name))
	print("POLAROID: P13 con lei all'oblò: %d mesh dell'oblò visibili, quelle che toccano la Polaroid (2 cm): %s" % [n, ", ".join(tocca) if tocca.size() else "nessuna"])
