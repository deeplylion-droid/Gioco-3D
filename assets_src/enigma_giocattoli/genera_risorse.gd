extends SceneTree
## Le risorse dell'enigma "I giocattoli al loro posto" (piscina a onde, 28 ottobre) in godot/assets/enigma_giocattoli/:
## - paperella.tscn, palla_rossa.tscn, balena_blu.tscn: RigidBody3D col modello e una collisione semplice (la sfera
##   per la palla, l'involucro convesso del modello per paperella e balena), origine in basso al centro, davanti +Z;
##   massa da giocattolo di gomma pieno d'acqua a metà ([constant MASSE]);
## - cerchio_giallo/rosso/blu.tres: il materiale del cerchio a mosaico (cerchio_mosaico.gdshader) nei tre colori;
##   cerchio_mosaico.tscn: il piano di 1,1 m col materiale giallo, appena sopra l'origine (2 mm), da mettere sul fondo;
## - disegno_giocattoli.res / .tscn: il disegno a pastello dei bambini (30 x 40 cm, disegno_giocattoli.jpg, dalla
##   variante v2 di assets_src/enigma_giocattoli/disegno/) attaccato al muro coi quattro pezzi di nastro di carta come
##   quello degli acquari; origine al centro del foglio sulla faccia del muro, il foglio guarda +Z (1 mm dal muro).
## Uso (dopo l'importazione dei GLB): godot --headless --path godot --script res://../assets_src/enigma_giocattoli/genera_risorse.gd
## (oppure copiato in godot/ e lanciato da lì).

const DIR := "res://assets/enigma_giocattoli/"
## kg: metà del volume pieno d'acqua più la gomma (paperella ~0,045 m3, palla ~0,087, balena ~0,04).
const MASSE := {"paperella": 24.0, "palla_rossa": 45.0, "balena_blu": 22.0}
## I colori del mosaico (vetro colorato un po' scolorito, come i giocattoli).
const COLORI := {"giallo": Color(0.86, 0.68, 0.12), "rosso": Color(0.72, 0.13, 0.1), "blu": Color(0.13, 0.32, 0.7)}


func _initialize() -> void:
	for nome in MASSE:
		_giocattolo(nome)
	var shader := load(DIR + "cerchio_mosaico.gdshader") as Shader
	for c in COLORI:
		var m := ShaderMaterial.new()
		m.resource_name = "cerchio_" + c
		m.shader = shader
		m.set_shader_parameter(&"colore", COLORI[c])
		ResourceSaver.save(m, DIR + "cerchio_" + c + ".tres")
	var piano := MeshInstance3D.new()
	piano.name = "CerchioMosaico"
	var pm := PlaneMesh.new()
	pm.size = Vector2(1.1, 1.1)
	pm.center_offset = Vector3(0, 0.002, 0)
	pm.material = load(DIR + "cerchio_giallo.tres")
	piano.mesh = pm
	piano.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_salva(piano, DIR + "cerchio_mosaico.tscn")
	_disegno()
	print("risorse salvate in ", DIR)
	quit()


func _disegno() -> void:
	var w := 0.3
	var h := 0.4
	var carta := StandardMaterial3D.new()
	carta.resource_name = "disegno_carta"
	carta.albedo_texture = load(DIR + "disegno_giocattoli.jpg")
	carta.albedo_color = Color(0.86, 0.84, 0.78)
	carta.roughness = 0.85
	var mesh := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var z := 0.001
	var q := [[Vector3(-w / 2, -h / 2, z), Vector2(0, 1)], [Vector3(w / 2, -h / 2, z), Vector2(1, 1)],
			[Vector3(w / 2, h / 2, z), Vector2(1, 0)], [Vector3(-w / 2, h / 2, z), Vector2(0, 0)]]
	for i in [0, 2, 1, 0, 3, 2]:   # (in senso orario visto da +Z: la faccia davanti)
		st.set_normal(Vector3.BACK)
		st.set_uv(q[i][1])
		st.add_vertex(q[i][0])
	st.generate_tangents()
	st.set_material(carta)
	st.commit(mesh)
	# i quattro pezzi di nastro agli angoli, inclinati di 40 gradi (come sul disegno degli acquari)
	var nastro := StandardMaterial3D.new()
	nastro.resource_name = "nastro_carta"
	nastro.albedo_color = Color(0.78, 0.72, 0.55, 0.85)
	nastro.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	nastro.roughness = 0.6
	var sn := SurfaceTool.new()
	sn.begin(Mesh.PRIMITIVE_TRIANGLES)
	for c in [Vector2(-1, 1), Vector2(1, 1), Vector2(-1, -1), Vector2(1, -1)]:
		var rot := deg_to_rad(40.0 if c.x * c.y > 0 else -40.0)
		var ux := Vector3(cos(rot), sin(rot), 0)
		var uy := Vector3(-sin(rot), cos(rot), 0)
		var centro := Vector3(c.x * (w / 2 - 0.01), c.y * (h / 2 - 0.01), 0.002)
		var hx := ux * 0.0375
		var hy := uy * 0.014
		var v := [centro - hx - hy, centro + hx - hy, centro + hx + hy, centro - hx + hy]
		for i in [0, 2, 1, 0, 3, 2]:
			sn.set_normal(Vector3.BACK)
			sn.add_vertex(v[i])
	sn.set_material(nastro)
	sn.commit(mesh)
	ResourceSaver.save(mesh, DIR + "disegno_giocattoli.res")
	var mi := MeshInstance3D.new()
	mi.name = "DisegnoGiocattoli"
	mi.mesh = load(DIR + "disegno_giocattoli.res")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_salva(mi, DIR + "disegno_giocattoli.tscn")


func _giocattolo(nome: String) -> void:
	var corpo := RigidBody3D.new()
	corpo.name = nome.to_pascal_case()
	corpo.mass = MASSE[nome]
	corpo.linear_damp = 0.6
	corpo.angular_damp = 1.5
	var fis := PhysicsMaterial.new()
	fis.friction = 0.7
	fis.bounce = 0.05
	corpo.physics_material_override = fis
	var modello := (load(DIR + nome + ".glb") as PackedScene).instantiate()
	modello.name = "Modello"
	corpo.add_child(modello)
	var col := CollisionShape3D.new()
	col.name = "Collisione"
	corpo.add_child(col)
	if nome == "palla_rossa":
		var s := SphereShape3D.new()
		s.radius = 0.275
		col.shape = s
		col.position = Vector3(0, 0.275, 0)
	else:
		var mi := modello.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var conv := mi.mesh.create_convex_shape(true, true)
		# i punti nel sistema del corpo (il modello non ha trasformazioni, ma per sicurezza)
		var t := (modello as Node3D).transform * mi.transform
		var punti := PackedVector3Array()
		for p in conv.points:
			punti.append(t * p)
		conv.points = punti
		col.shape = conv
	_salva(corpo, DIR + nome + ".tscn")


func _salva(radice: Node, percorso: String) -> void:
	for n in radice.get_children():
		n.owner = radice
	var ps := PackedScene.new()
	ps.pack(radice)
	ResourceSaver.save(ps, percorso)
	radice.free()
