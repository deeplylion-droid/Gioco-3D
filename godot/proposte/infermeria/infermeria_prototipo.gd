extends Node3D
## Prototipo grigio dell'infermeria (enigma-logica, nota approvata il 18 ottobre,
## docs/proposte/fiume_infermeria/nota_logica.md): la catena dei 4 passi, al buio, senza testi.
## 1. Col getto si colpisce l'interruttore (WaterButton) e il negatoscopio smette di sfarfallare.
## 2. La Polaroid del medico sulla scrivania mostra lo schedario con il cassetto dall'adesivo rosa;
##    nello schedario quel cassetto ha l'adesivo fosforescente: dentro c'è la radiografia.
## 3. La radiografia sul negatoscopio: i puntini rosa nelle ossa dell'agnello, 4 in testa, 1 nel corpo,
##    7 nella coda.
## 4. La cassaforte con tre rotelle (testa, corpo, coda): 4-1-7. Dentro la keycard e la Polaroid della
##    pecora (qui un segnaposto: la Polaroid vera la mette chi fa le Polaroid).
## Serve alle squadre per provare la catena; non è un ambiente da mostrare.

## Quale cassetto ha l'adesivo (da 0, per colonne).
const CASSETTO_GIUSTO := 5

var negatoscopio: Negatoscopio
var cassaforte: CassaforteRotelle
var interruttore: WaterButton
var cassetti: Array[CassettoSchedario] = []


func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.01, 0.01, 0.015)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.3, 0.05, 0.05)
	env.environment.ambient_light_energy = 0.3
	add_child(env)
	# La stanza: pavimento, quattro muri e il soffitto, una luce rossa d'emergenza.
	var muri := StaticBody3D.new()
	muri.name = "Stanza"
	add_child(muri)
	for b in [[Vector3(6.4, 0.2, 6.4), Vector3(0, -0.1, 0), Graybox.FLOOR], [Vector3(6.4, 0.2, 6.4), Vector3(0, 3.1, 0), Graybox.WALL],
			[Vector3(0.2, 3.0, 6.4), Vector3(-3.1, 1.5, 0), Graybox.WALL], [Vector3(0.2, 3.0, 6.4), Vector3(3.1, 1.5, 0), Graybox.WALL],
			[Vector3(6.4, 3.0, 0.2), Vector3(0, 1.5, -3.1), Graybox.WALL], [Vector3(6.4, 3.0, 0.2), Vector3(0, 1.5, 3.1), Graybox.WALL]]:
		Graybox.box(muri, b[0], b[1], b[2])
		Graybox.box_shape(muri, b[0], b[1])
	var rossa := OmniLight3D.new()
	rossa.light_color = Color(1.0, 0.1, 0.05)
	rossa.light_energy = 0.4
	rossa.omni_range = 6.0
	add_child(rossa)
	rossa.position = Vector3(0, 2.8, 2.5)
	# 1. L'interruttore sotto il negatoscopio.
	interruttore = WaterButton.new()
	interruttore.name = "Interruttore"
	interruttore.mode = WaterButton.Mode.LATCH
	add_child(interruttore)
	interruttore.position = Vector3(0.9, 0.9, -2.95)
	negatoscopio = Negatoscopio.new()
	negatoscopio.name = "Negatoscopio"
	negatoscopio.alimentazione = interruttore
	_forma(negatoscopio, Vector3(1.2, 0.8, 0.1))
	add_child(negatoscopio)
	negatoscopio.position = Vector3(0.0, 1.6, -2.95)
	# 2. Lo schedario sul muro ovest: 2 colonne x 4 cassetti, guardano verso +X.
	var radiografia := _pickup("Radiografia", &"radiografia", "Radiografia")
	for c in 2:
		for r in 4:
			var k := CassettoSchedario.new()
			k.name = "Cassetto%d" % (c * 4 + r)
			k.adesivo = c * 4 + r == CASSETTO_GIUSTO
			_forma(k, Vector3(0.45, 0.28, 0.1))
			add_child(k)
			k.global_transform = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-2.95, 0.35 + r * 0.32, -0.6 + c * 0.5))
			if k.adesivo:
				k.contenuto = radiografia
				k.call(&"_metti")
			cassetti.append(k)
	radiografia.global_position = cassetti[CASSETTO_GIUSTO].global_position + Vector3(0.45, 0.0, 0.0)
	cassetti[CASSETTO_GIUSTO].call(&"_metti")
	# La Polaroid del medico sulla scrivania (segnaposto: un riquadro con il rosa del cassetto).
	var scrivania := StaticBody3D.new()
	scrivania.name = "Scrivania"
	add_child(scrivania)
	Graybox.box(scrivania, Vector3(1.4, 0.75, 0.7), Vector3(1.6, 0.375, -2.2))
	Graybox.box_shape(scrivania, Vector3(1.4, 0.75, 0.7), Vector3(1.6, 0.375, -2.2))
	var foto := MeshInstance3D.new()
	foto.name = "PolaroidMedico"
	var q := BoxMesh.new()
	q.size = Vector3(0.09, 0.005, 0.11)
	foto.mesh = q
	var mf := StandardMaterial3D.new()
	mf.albedo_color = Color(1.0, 0.45, 0.75)
	foto.material_override = mf
	add_child(foto)
	foto.position = Vector3(1.4, 0.76, -2.1)
	# 4. La cassaforte sul muro est, guarda verso -X; dentro la keycard e la Polaroid della pecora.
	var keycard := _pickup("Keycard", &"keycard", "Keycard")
	var polaroid := _pickup("PolaroidPecora", &"polaroid_pecora", "Polaroid")
	cassaforte = CassaforteRotelle.new()
	cassaforte.name = "Cassaforte"
	cassaforte.contenuto = [keycard, polaroid]
	add_child(cassaforte)
	cassaforte.global_transform = Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(2.95, 1.2, 0.3))
	keycard.global_position = Vector3(2.85, 1.15, 0.0)
	polaroid.global_position = Vector3(2.85, 1.25, -0.15)
	cassaforte.call(&"_metti")


func _pickup(nome: String, id: StringName, testo: String) -> Pickup:
	var p := Pickup.new()
	p.name = nome
	p.item_id = id
	p.item_name = testo
	_forma(p, Vector3(0.2, 0.2, 0.2))
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.9, 1.0)
	Graybox.box(p, Vector3(0.09, 0.01, 0.06), Vector3.ZERO, mat)
	add_child(p)
	return p


func _forma(n: Node, dim: Vector3) -> void:
	var f := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = dim
	f.shape = b
	n.add_child(f)
