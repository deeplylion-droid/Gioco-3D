extends Node
## Sonda: la mano di lei sul bordo della vasca 3 nella salita sale_mano (0.3.21, scelta C dell'utente). Lei al suo posto
## della vasca_2, girata dritta verso il muro come nel gioco; fotogramma per fotogramma, la pelle vera della mano destra
## (i vertici della mesh pesati sulla mano e sulle dita, deformati dalle ossa): quanto sta sopra la cima del bordo dove
## la tocca (il distacco: deve essere 0-5 mm mentre si tiene), e quanti vertici entrano nel muro (sotto la cima, fra la
## faccia dalla sua parte e quella dentro la vasca, o oltre la faccia dalla sua parte sotto la cima).
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://proposte/mascotte/sonda_mano_bordo.gd

const SCENA := "res://scenes/sala/inseguimento/sala_inseguimento.tscn"
## Il bordo nello spazio di lei (sonda_bordo_mano.gd): la faccia dalla sua parte, la cima, la faccia dentro la vasca.
const FACCIA := 2.30
const CIMA := 3.485
const DENTRO := 2.485

var _sk: Skeleton3D
var _ossa := PackedInt32Array()
var _pesi := PackedFloat32Array()
var _bv := PackedVector3Array()
var _nv := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var sala := (load(SCENA) as PackedScene).instantiate() as SalaInseguimento
	sala.crea_luci = false
	add_child(sala)
	for i in 10:
		await get_tree().physics_frame
	sala.set_physics_process(false)
	var lei := sala.lei
	var su := sala._posto_vasca(2)
	var r: Array = sala.dati["vasche"][2]["rett"]
	var muro := SalaInseguimento.b([(r[0] + r[2]) / 2.0, r[1], 0.0])
	lei.visible = true
	lei.global_position = su
	lei.look_at(Vector3(muro.x, su.y, muro.z), Vector3.UP, true)
	var ap := lei.get_model_instance().find_child("AnimationPlayer", true, false) as AnimationPlayer
	_pelle(lei.get_model_instance())
	print("vertici della mano destra: ", _nv)
	ap.play(&"inseguimento/sale_mano")
	var inv := lei.global_transform.affine_inverse()
	var peggior_dentro := 0
	var distacco_max := -INF
	var distacco_min := INF
	for i in range(0, 49):
		var t := i / 30.0
		ap.seek(t, true)
		ap.advance(0.0)
		var ps := []
		for o in _sk.get_bone_count():
			ps.append(_sk.global_transform * _sk.get_bone_global_pose(o))
		var sopra := INF      # il vertice più basso sopra la cima (dove la tocca)
		var dentro := 0
		var piu_dentro := 0.0
		for v in _nv:
			var w := Vector3.ZERO
			for j in 4:
				var pw := _pesi[v * 4 + j]
				if pw > 0.0:
					w += ((ps[_ossa[v * 4 + j]] as Transform3D) * _bv[v * 4 + j]) * pw
			var l := inv * w
			var avanti := l.z
			if avanti >= FACCIA and avanti <= DENTRO:
				sopra = minf(sopra, l.y - CIMA)
				if l.y < CIMA - 0.002:
					dentro += 1
					piu_dentro = maxf(piu_dentro, CIMA - l.y)
		if sopra < INF and sopra < 0.3:
			print("t %.2f: la mano sopra la cima del bordo, il punto più basso a %+.1f mm; vertici dentro il muro %d (al più %.1f mm)" % [
				t, sopra * 1000.0, dentro, piu_dentro * 1000.0])
		if t >= 0.82 and t <= 1.03:
			distacco_max = maxf(distacco_max, sopra)
			distacco_min = minf(distacco_min, sopra)
			peggior_dentro = maxi(peggior_dentro, dentro)
	print("TENENDOSI (0,82-1,03 s): distacco da %+.1f a %+.1f mm, vertici dentro il muro al più %d" % [distacco_min * 1000.0,
		distacco_max * 1000.0, peggior_dentro])
	get_tree().quit(0)


## I vertici della mesh pesati soprattutto sulla mano destra o sulle sue dita (4 ossa per vertice, come lo skinning).
func _pelle(m: Node3D) -> void:
	_sk = m.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var mano := {}
	for o in _sk.get_bone_count():
		var n := _sk.get_bone_name(o)
		if n.ends_with(".R") and (n.begins_with("mano") or n.begins_with("pollice") or n.begins_with("indice")
				or n.begins_with("medio") or n.begins_with("anulare") or n.begins_with("mignolo")):
			mano[o] = true
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		var skin := (mi as MeshInstance3D).skin
		if mesh == null or skin == null:
			continue
		var bind_osso := PackedInt32Array()
		for b in skin.get_bind_count():
			var nome := skin.get_bind_name(b)
			bind_osso.append(_sk.find_bone(nome) if nome != "" else skin.get_bind_bone(b))
		for s in mesh.get_surface_count():
			var a := mesh.surface_get_arrays(s)
			if a[Mesh.ARRAY_BONES] == null:
				continue
			var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var bo = a[Mesh.ARRAY_BONES]
			var we = a[Mesh.ARRAY_WEIGHTS]
			var per: int = bo.size() / vs.size()
			for v in vs.size():
				var lista := []
				for j in per:
					if float(we[v * per + j]) > 0.0:
						lista.append([float(we[v * per + j]), int(bo[v * per + j])])
				if lista.is_empty():
					continue
				lista.sort_custom(func(x, y): return x[0] > y[0])
				if not mano.has(bind_osso[lista[0][1]]):
					continue
				lista = lista.slice(0, 4)
				var somma := 0.0
				for e in lista:
					somma += e[0]
				for j in 4:
					if j < lista.size():
						_ossa.append(bind_osso[lista[j][1]])
						_pesi.append(lista[j][0] / somma)
						_bv.append(skin.get_bind_pose(lista[j][1]) * vs[v])
					else:
						_ossa.append(0)
						_pesi.append(0.0)
						_bv.append(Vector3.ZERO)
				_nv += 1
