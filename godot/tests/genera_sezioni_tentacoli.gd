extends Node
## Genera assets/models/medusa/medusa_sezioni_tentacoli.json: la sezione vera di ogni osso dei tentacoli di lei, dalla
## pelle di medusa.glb, per la collisione di MorbidezzaLei (che tiene fuori dal mondo tutta la pelle, non solo l'asse).
## Per ogni osso "tentacolo_*": i vertici che muove di più, a riposo, e quanto si allontanano dal suo asse (dalla testa
## alla testa del figlio, o alla punta) nel piano dei suoi assi X e Z (Y è lungo l'osso): un'ellisse girata come le
## direzioni principali, [angolo dall'asse X, mezza larghezza, mezzo spessore], in unità dello scheletro (la morbidezza
## le moltiplica per la scala). Il massimo dei vertici, non una media: il test della
## pelle vera (misura_morbidezza.gd, pelle) li conta tutti.
## Da rilanciare quando cambia la pelle dei tentacoli in medusa.glb.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/genera_sezioni_tentacoli.gd

const MODELLO := "res://assets/models/medusa/medusa.glb"
const USCITA := "res://assets/models/medusa/medusa_sezioni_tentacoli.json"


func _ready() -> void:
	var lei := (load(MODELLO) as PackedScene).instantiate()
	add_child(lei)
	var sk := lei.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var ext := {}       # osso -> Vector2 (massimo |X|, massimo |Z|)
	var conta := {}
	for mi in sk.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		var skin := (mi as MeshInstance3D).skin
		if mesh == null or skin == null:
			continue
		var bind_osso := PackedInt32Array()
		for b in skin.get_bind_count():
			var nome := skin.get_bind_name(b)
			bind_osso.append(sk.find_bone(nome) if nome != "" else skin.get_bind_bone(b))
		for s in mesh.get_surface_count():
			var a := mesh.surface_get_arrays(s)
			if a[Mesh.ARRAY_BONES] == null:
				continue
			var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var bo = a[Mesh.ARRAY_BONES]
			var we = a[Mesh.ARRAY_WEIGHTS]
			var per: int = bo.size() / vs.size()
			for v in vs.size():
				var mig := -1
				var pm := 0.0
				for j in per:
					if float(we[v * per + j]) > pm:
						pm = float(we[v * per + j])
						mig = int(bo[v * per + j])
				if mig < 0:
					continue
				var osso := bind_osso[mig]
				if not sk.get_bone_name(osso).begins_with("tentacolo_"):
					continue
				var rest := sk.get_bone_global_rest(osso)
				var q: Vector3 = rest * (skin.get_bind_pose(mig) * vs[v])
				var a0 := rest.origin
				var a1 := _fine(sk, osso)
				var off := q - Geometry3D.get_closest_point_to_segment(q, a0, a1)
				var bx := rest.basis.x.normalized()
				var bz := rest.basis.z.normalized()
				if not ext.has(osso):
					ext[osso] = []
				ext[osso].append(Vector2(off.dot(bx), off.dot(bz)))
				conta[osso] = conta.get(osso, 0) + 1
	# la sezione: un'ellisse nel piano X-Z dell'osso, girata come le due direzioni principali dei vertici (i tentacoli
	# sono nastri: larghi e sottili); [angolo dall'asse X, mezza misura lungo quella direzione, mezza misura di traverso]
	var out := {}
	var piatti := 0
	for osso in ext:
		var pts: Array = ext[osso]
		var cxx := 0.0
		var czz := 0.0
		var cxz := 0.0
		for o: Vector2 in pts:
			cxx += o.x * o.x
			czz += o.y * o.y
			cxz += o.x * o.y
		var ang := 0.5 * atan2(2.0 * cxz, cxx - czz)
		var e1 := Vector2(cos(ang), sin(ang))
		var e2 := Vector2(-e1.y, e1.x)
		var a := 0.0
		var b := 0.0
		for o: Vector2 in pts:
			a = maxf(a, absf(o.dot(e1)))
			b = maxf(b, absf(o.dot(e2)))
		if b < 0.6 * a:
			piatti += 1
		out[sk.get_bone_name(osso)] = [snappedf(ang, 0.0001), snappedf(a, 0.0001), snappedf(b, 0.0001)]
	print("ossa piatte (spessore sotto il 60%% della larghezza): %d su %d" % [piatti, out.size()])
	var f := FileAccess.open(USCITA, FileAccess.WRITE)
	f.store_string(JSON.stringify({"modello": MODELLO, "ossa": out}, "\t", true))
	f.close()
	print("sezioni di %d ossa scritte in %s" % [out.size(), USCITA])
	get_tree().quit()


## La fine dell'asse dell'osso: la testa del figlio "tentacolo_", o la punta (lunga come l'osso prima).
func _fine(sk: Skeleton3D, osso: int) -> Vector3:
	var rest := sk.get_bone_global_rest(osso)
	for f in sk.get_bone_children(osso):
		if sk.get_bone_name(f).begins_with("tentacolo_"):
			return sk.get_bone_global_rest(f).origin
	var p := sk.get_bone_parent(osso)
	var l := rest.origin.distance_to(sk.get_bone_global_rest(p).origin) if p >= 0 else 0.1
	return rest.origin + rest.basis.y.normalized() * l
