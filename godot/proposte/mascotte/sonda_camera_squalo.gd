extends Node
## Sonda: la scena del risveglio con il mostro-squalo (scripts/interni/risveglio_squalo.gd) fatta girare a 60
## fotogrammi al secondo negli interni; a ogni fotogramma la distanza tra la camera e la superficie dello squalo
## (i vertici della mesh deformati dallo scheletro, come li disegna il motore: uno ogni [code]PASSO[/code]). Se la
## camera è più vicina di [code]SOGLIA[/code] (il piano vicino della camera e poco più) la stampa: lì la camera
## passa dentro di lui. Alla fine il minimo, quando e vicino a quale osso.
## Per la squadra (proposte/ è esclusa dall'export).
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- \
##        res://proposte/mascotte/sonda_camera_squalo.gd

const LEVEL := "res://scenes/interni/interni.tscn"
const PASSO := 3
const SOGLIA := 0.15

var _verts: Array = []       # [posizione nel riposo, [ossa], [pesi]] di ogni vertice preso
var _mi: MeshInstance3D
var _sk: Skeleton3D
var _skin: Skin
var _bind := {}              # indice nella skin -> [osso, matrice di bind]


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	get_tree().change_scene_to_file(LEVEL)
	for i in 300:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player):
			break
	for i in 5:
		await get_tree().physics_frame
	var level := get_tree().current_scene
	var p := GameState.player
	var s := level.get_node("Gioco/RisveglioSqualo") as RisveglioSqualo
	level.call(&"fai_risveglio", p, true)
	await get_tree().process_frame
	_prepara(s.squalo)
	var t := 0.0
	var minimo := 99.0
	var dove := ""
	var sotto := 0
	var costo := 0.0
	while s.in_corso():
		await get_tree().process_frame
		t += 1.0 / 60.0
		if s.squalo == null or not s.squalo.visible:
			continue
		var cam := p.camera.global_position
		var u0 := Time.get_ticks_usec()
		s.call(&"_fuori_dalla_pelle", cam)
		costo = maxf(costo, (Time.get_ticks_usec() - u0) / 1000.0)
		var r := _distanza(cam)
		if r[0] < minimo:
			minimo = r[0]
			dove = "%.2f s, vicino a %s" % [t, r[1]]
		if r[0] < SOGLIA:
			sotto += 1
			print("  %.2f s: camera a %.3f m dalla superficie (%s)" % [t, r[0], r[1]])
	print("minimo %.3f m (%s); fotogrammi sotto %.2f m: %d; durata %.2f s" % [minimo, dove, SOGLIA, sotto, t])
	print("camera fuori dalla pelle: %d punti, al più %.1f ms per fotogramma (qui, su llvmpipe e CPU lenta)" % [s._pelle.size(), costo])
	print("FINE")
	get_tree().quit()


func _prepara(squalo: Node3D) -> void:
	for n in squalo.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.skin:
			_mi = mi
	_sk = _mi.get_node(_mi.skeleton) as Skeleton3D
	_skin = _mi.skin
	for i in _skin.get_bind_count():
		var osso := _skin.get_bind_bone(i)
		if osso < 0:
			osso = _sk.find_bone(_skin.get_bind_name(i))
		_bind[i] = [osso, _skin.get_bind_pose(i)]
	var m := _mi.mesh
	for sup in m.get_surface_count():
		var a := m.surface_get_arrays(sup)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var b: PackedInt32Array = a[Mesh.ARRAY_BONES]
		var w: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
		var k := b.size() / v.size()
		for i in range(0, v.size(), PASSO):
			_verts.append([v[i], b.slice(i * k, i * k + k), w.slice(i * k, i * k + k)])


## [distanza minima dalla camera, l'osso col peso maggiore su quel vertice]
func _distanza(cam: Vector3) -> Array:
	var pose := {}
	var mondo := _mi.global_transform
	for i in _bind:
		var osso: int = _bind[i][0]
		pose[i] = _sk.global_transform * _sk.get_bone_global_pose(osso) * (_bind[i][1] as Transform3D)
	var best := 99.0
	var chi := ""
	for vv in _verts:
		var p := Vector3.ZERO
		var ossa: PackedInt32Array = vv[1]
		var pesi: PackedFloat32Array = vv[2]
		var tot := 0.0
		for j in ossa.size():
			if pesi[j] > 0.0:
				p += (pose[ossa[j]] as Transform3D) * (vv[0] as Vector3) * pesi[j]
				tot += pesi[j]
		if tot <= 0.0:
			p = mondo * (vv[0] as Vector3)
		else:
			p /= tot
		var d := p.distance_to(cam)
		if d < best:
			best = d
			var jm := 0
			for j in pesi.size():
				if pesi[j] > pesi[jm]:
					jm = j
			chi = _sk.get_bone_name(int(_bind[ossa[jm]][0]))
	return [best, chi]
