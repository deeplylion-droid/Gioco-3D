class_name FarettoSoffitto
extends RefCounted
## Un faretto piccolo a soffitto (quelli dell'infermeria sul negatoscopio e sulla cassaforte, e quello bianco sul
## cartello delle pozze): la piastra avvitata al soffitto, il gambo, il barattolo puntato sul bersaglio col vetro appena
## acceso e la SpotLight. Il cavo corre dritto contro il soffitto fino a una scatola di derivazione (sul soffitto, contro
## il muro). Come LampadaMuro.monta.


## Monta il faretto in [param padre] e lo restituisce (il nodo [param nome], con la luce "Luce"). [param attacco]: il
## punto del soffitto dove si avvita; [param bersaglio]: dove punta; [param scatola]: la scatola di derivazione, sul
## soffitto contro il muro. Tutto nelle coordinate di [param padre].
static func monta(padre: Node3D, nome: String, attacco: Vector3, bersaglio: Vector3, scatola: Vector3, colore: Color,
		energia: float, angolo: float) -> Node3D:
	var n := Node3D.new()
	n.name = nome
	padre.add_child(n)
	var ferro := _colore(Color(0.16, 0.16, 0.17), 0.6, 0.45)
	_box(n, Vector3(0.1, 0.012, 0.1), attacco + Vector3(0, -0.006, 0), ferro)
	var testa := attacco + Vector3(0, -0.16, 0)
	_cilindro(n, attacco + Vector3(0, -0.012, 0), testa, 0.012, ferro)
	var dir := (bersaglio - testa).normalized()
	# il barattolo col fondo sulla testa del gambo, aperto verso il bersaglio
	var lato := dir.cross(Vector3.UP).normalized() if absf(dir.y) < 0.99 else Vector3.RIGHT
	var b := Basis(lato, dir, lato.cross(dir).normalized())
	var can := MeshInstance3D.new()
	can.name = "Barattolo"
	var cm := CylinderMesh.new()
	cm.top_radius = 0.05
	cm.bottom_radius = 0.042
	cm.height = 0.13
	can.mesh = cm
	can.material_override = ferro
	n.add_child(can)
	can.transform = Transform3D(b, testa + dir * 0.055)
	var vetro := MeshInstance3D.new()
	vetro.name = "Vetro"
	var vc := CylinderMesh.new()
	vc.top_radius = 0.047
	vc.bottom_radius = 0.047
	vc.height = 0.004
	vetro.mesh = vc
	var mv := StandardMaterial3D.new()
	mv.albedo_color = Color(0.9, 0.9, 0.85)
	mv.emission_enabled = true
	mv.emission = colore
	mv.emission_energy_multiplier = 1.2
	vetro.material_override = mv
	n.add_child(vetro)
	vetro.transform = Transform3D(b, testa + dir * 0.122)
	var sp := SpotLight3D.new()
	sp.name = "Luce"
	sp.light_color = colore
	sp.light_energy = energia
	sp.spot_range = testa.distance_to(bersaglio) + 1.5
	sp.spot_angle = angolo
	sp.spot_attenuation = 0.6
	sp.shadow_enabled = false
	sp.set_meta(&"risveglio_ignora", true)
	n.add_child(sp)
	sp.transform = Transform3D(Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.BACK), testa + dir * 0.125)
	# il cavo: dentro la piastra, poi a contatto col soffitto fino dentro la scatola (12 cm, contro il muro e il soffitto)
	var verso := (Vector3(scatola.x, attacco.y, scatola.z) - attacco).normalized()
	_cilindro(n, attacco + Vector3(0, -0.005, 0), scatola - verso * 0.06 + Vector3(0, -0.005, 0), 0.005, _colore(Color(0.04, 0.04, 0.04), 0.0, 0.6))
	_box(n, Vector3(0.12, 0.06, 0.12), scatola - verso * 0.06 + Vector3(0, -0.03, 0), ferro)
	return n


static func _colore(c: Color, metallo: float, ruvido: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metallo
	m.roughness = ruvido
	return m


static func _box(padre: Node3D, size: Vector3, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	padre.add_child(mi)
	return mi


static func _cilindro(padre: Node3D, a: Vector3, b: Vector3, r: float, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = a.distance_to(b)
	mi.mesh = cm
	mi.material_override = m
	padre.add_child(mi)
	var y := (b - a).normalized()
	var x := y.cross(Vector3.FORWARD).normalized() if absf(y.z) < 0.99 else Vector3.RIGHT
	mi.transform = Transform3D(Basis(x, y, x.cross(y).normalized()), (a + b) * 0.5)
