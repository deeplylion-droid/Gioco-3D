extends SceneTree
## Le risorse dell'enigma degli acquari per la scena del gioco (godot/scenes/sala/enigma_acquari.tscn),
## con le stesse misure della proposta approvata (godot/proposte/acquari/proposta_acquari.gd):
## - disegno_curvo.res: il disegno dei bambini piegato sul vetro del cilindro giallo (raggio 0,576 m,
##   30 x 40 cm, centro a 28 gradi verso il miscuglio e a 0,6 m dal fondo interno), con i quattro pezzi
##   di nastro di carta; coordinate dell'acquario (origine al centro del fondo interno);
## - lampadine_portone.res e portalampade_portone.res: le lampadine da luna park intorno al portone
##   della torre (MultiMesh), coordinate della sala; lampadine_accese / lampadine_spente: i materiali.
## Uso: godot --headless --path godot --script res://../assets_src/enigma_acquari/genera_risorse.gd
## (oppure copiato in godot/ e lanciato da lì).

const DIR := "res://assets/enigma_acquari/"


func _initialize() -> void:
	_disegno()
	_lampadine()
	print("risorse salvate in ", DIR)
	quit()


func _mat_carta() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = "disegno_carta"
	m.albedo_texture = load(DIR + "disegno_bambini.jpg")
	m.albedo_color = Color(0.86, 0.84, 0.78)
	m.roughness = 0.85
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	# carta sottile su un vetro illuminato: la luce dell'acquario passa dal foglio (scelta del 18 ottobre)
	m.backlight_enabled = true
	m.backlight = Color(0.55, 0.5, 0.3)
	m.emission_enabled = true
	m.emission_texture = m.albedo_texture
	m.emission = Color(1.0, 0.9, 0.55)
	m.emission_energy_multiplier = 0.55
	return m


func _mat_nastro() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = "nastro_carta"
	m.albedo_color = Color(0.78, 0.72, 0.55, 0.85)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.6
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _disegno() -> void:
	var r := 0.576
	var y := 0.6
	var w := 0.3
	var h := 0.4
	var nx := 12
	var a0 := deg_to_rad(28.0) - w / r * 0.5
	var mesh := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in nx:
		var u0 := float(i) / nx
		var u1 := float(i + 1) / nx
		var aa := a0 + u0 * w / r
		var ab := a0 + u1 * w / r
		var p00 := Vector3(sin(aa) * r, y - h * 0.5, cos(aa) * r)
		var p10 := Vector3(sin(ab) * r, y - h * 0.5, cos(ab) * r)
		var p01 := p00 + Vector3(0, h, 0)
		var p11 := p10 + Vector3(0, h, 0)
		var n0 := Vector3(sin(aa), 0, cos(aa))
		var n1 := Vector3(sin(ab), 0, cos(ab))
		for v in [[p00, n0, Vector2(u0, 1)], [p10, n1, Vector2(u1, 1)], [p11, n1, Vector2(u1, 0)],
				[p00, n0, Vector2(u0, 1)], [p11, n1, Vector2(u1, 0)], [p01, n0, Vector2(u0, 0)]]:
			st.set_normal(v[1])
			st.set_uv(v[2])
			st.add_vertex(v[0])
	st.generate_tangents()
	st.set_material(_mat_carta())
	st.commit(mesh)
	# i quattro pezzi di nastro agli angoli, inclinati di 40 gradi, appena fuori dal foglio
	var sn := SurfaceTool.new()
	sn.begin(Mesh.PRIMITIVE_TRIANGLES)
	for c in [Vector2(0.0, 0.19), Vector2(1.0, 0.19), Vector2(0.0, -0.19), Vector2(1.0, -0.19)]:
		var a: float = a0 + c.x * w / r
		var n := Vector3(sin(a), 0, cos(a))
		var t := Vector3(cos(a), 0, -sin(a))   # tangente orizzontale
		var rot := deg_to_rad(40.0 if (c.x - 0.5) * c.y > 0 else -40.0)
		var ux := t * cos(rot) + Vector3.UP * sin(rot)
		var uy := -t * sin(rot) + Vector3.UP * cos(rot)
		var centro := n * (r + 0.002) + Vector3(0, y + c.y, 0)
		var hx := ux * 0.0375
		var hy := uy * 0.014
		var q := [centro - hx - hy, centro + hx - hy, centro + hx + hy, centro - hx + hy]
		for idx in [0, 1, 2, 0, 2, 3]:
			sn.set_normal(n)
			sn.add_vertex(q[idx])
	sn.set_material(_mat_nastro())
	sn.commit(mesh)
	ResourceSaver.save(mesh, DIR + "disegno_curvo.res")


func _lampadine() -> void:
	var x := 19.6
	var z0 := -18.45
	var z1 := -11.55
	var y_top := 5.5
	var y_bot := 0.9
	var passo := 0.34
	var punti: Array[Vector3] = []
	for k in int((y_top - y_bot) / passo) + 1:
		punti.append(Vector3(x, y_bot + k * passo, z0))
		punti.append(Vector3(x, y_bot + k * passo, z1))
	for k in range(1, int((z1 - z0) / passo)):
		punti.append(Vector3(x, y_top, z0 + k * passo))
	var porta := CylinderMesh.new()
	porta.top_radius = 0.028
	porta.bottom_radius = 0.032
	porta.height = 0.06
	var mp := StandardMaterial3D.new()
	mp.resource_name = "portalampada"
	mp.albedo_color = Color(0.12, 0.11, 0.1)
	mp.metallic = 0.7
	mp.roughness = 0.45
	porta.material = mp
	var spente := StandardMaterial3D.new()
	spente.resource_name = "lampadina_spenta"
	spente.albedo_color = Color(0.42, 0.40, 0.36)
	spente.roughness = 0.25
	spente.metallic_specular = 0.8
	var accese := StandardMaterial3D.new()
	accese.resource_name = "lampadina_accesa"
	accese.albedo_color = Color(1.0, 0.85, 0.55)
	accese.emission_enabled = true
	accese.emission = Color(1.0, 0.72, 0.35)
	accese.emission_energy_multiplier = 7.0
	accese.roughness = 0.3
	var b := Basis(Vector3(0, 0, 1), PI * 0.5)   # asse dei cilindri lungo -X (fuori dal muro)
	for parte in [["portalampade_portone", porta, -0.01, null],
			["lampadine_spente", _bulbo(0.042, spente), -0.075, null],
			["lampadine_accese", _bulbo(0.045, accese), -0.075, null]]:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = parte[1]
		mm.instance_count = punti.size()
		# le stesse trasformazioni anche in un meta, che si salva con la risorsa: senza schermo il buffer del MultiMesh
		# arriva vuoto (tutte le istanze nell'origine), e il controllo di posizionamento le legge da qui
		var tr: Array[Transform3D] = []
		for i in punti.size():
			tr.append(Transform3D(b, punti[i] + Vector3(parte[2], 0, 0)))
			mm.set_instance_transform(i, tr[i])
		mm.set_meta(&"trasformazioni", tr)
		ResourceSaver.save(mm, DIR + parte[0] + ".res")


func _bulbo(r: float, m: Material) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.25
	s.material = m
	return s
