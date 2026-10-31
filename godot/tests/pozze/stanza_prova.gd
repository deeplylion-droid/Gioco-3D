extends RefCounted
## Una stanza grigia per le prove della logica delle pozze colorate (EnigmaPozze), finché la stanza vera di ambienti-1
## non c'è: pavimento della passerella intorno alla griglia, vasche col fondo e i bordini fra le pozze (tutto con la
## collisione), la porta stagna finta, il lampeggiante e il checkpoint a enigma risolto.

const PORTA := preload("res://tests/pozze/porta_prova.gd")
## Larghezza della passerella (m), come nel GDD.
const PASSERELLA := 1.2


## Costruisce la stanza sotto [param radice], con la griglia centrata in [param centro]; ritorna l'enigma.
static func costruisci(radice: Node, centro := Vector3.ZERO) -> EnigmaPozze:
	var stanza := Node3D.new()
	stanza.name = "StanzaPozzeProva"
	stanza.position = centro
	radice.add_child(stanza)
	var e := EnigmaPozze.new()
	e.name = "EnigmaPozze"
	var mezza := e.passo * 2.5
	var corpo := StaticBody3D.new()
	corpo.name = "Pavimenti"
	corpo.collision_layer = Layers.WORLD
	stanza.add_child(corpo)
	var esterno := mezza + PASSERELLA
	# la passerella: quattro blocchi pieni dal fondo delle vasche al piano di calpestio
	_blocco(corpo, Vector3(0, -0.5, -(mezza + PASSERELLA * 0.5)), Vector3(esterno * 2.0, 1.0, PASSERELLA))
	_blocco(corpo, Vector3(0, -0.5, mezza + PASSERELLA * 0.5), Vector3(esterno * 2.0, 1.0, PASSERELLA))
	_blocco(corpo, Vector3(-(mezza + PASSERELLA * 0.5), -0.5, 0), Vector3(PASSERELLA, 1.0, mezza * 2.0))
	_blocco(corpo, Vector3(mezza + PASSERELLA * 0.5, -0.5, 0), Vector3(PASSERELLA, 1.0, mezza * 2.0))
	# il fondo delle vasche e i bordini fra le pozze
	_blocco(corpo, Vector3(0, -e.profondita - 0.1, 0), Vector3(mezza * 2.0, 0.2, mezza * 2.0))
	var b := e.passo - e.lato
	for i in range(1, 5):
		var k := -mezza + i * e.passo
		_blocco(corpo, Vector3(k, -e.profondita * 0.5, 0), Vector3(b, e.profondita, mezza * 2.0))
		_blocco(corpo, Vector3(0, -e.profondita * 0.5, k), Vector3(mezza * 2.0, e.profondita, b))
	var porta := Node3D.new()
	porta.name = "PortaStagna"
	porta.set_script(PORTA)
	porta.position = Vector3(0, 0, -esterno)
	stanza.add_child(porta)
	var lamp := Node3D.new()
	lamp.name = "LampeggianteErrore"
	lamp.position = Vector3(1.5, 2.6, -esterno + 0.2)
	stanza.add_child(lamp)
	var luce := OmniLight3D.new()
	luce.light_color = Color(1, 0.1, 0.05)
	luce.omni_range = 6.0
	lamp.add_child(luce)
	var cp := Checkpoint.new()
	cp.name = "CheckpointRisolto"
	cp.order = 15
	cp.monitoring = false
	cp.position = Vector3(0, 0, -mezza - PASSERELLA * 0.5)
	cp.rotation_degrees.y = 0.0
	stanza.add_child(cp)
	stanza.add_child(e)
	return e


static func _blocco(corpo: StaticBody3D, pos: Vector3, misura: Vector3) -> void:
	var s := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = misura
	s.shape = box
	s.position = pos
	corpo.add_child(s)
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = misura
	m.mesh = bm
	m.position = pos
	corpo.add_child(m)
