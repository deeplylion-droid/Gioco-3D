extends Node3D
## Prototipo grigio del fiume lento (enigma-logica, docs/proposte/fiume_infermeria/nota_logica.md):
## serve alle squadre per provare se la corrente e il colpo alle chiuse sono divertenti e fattibili;
## non è un ambiente da mostrare. Un anello con tre bivi:
## - bivio 1: la paratia manda nel ramo sbagliato, va girata (bersaglio dritto davanti);
## - bivio 2: è già giusta; se la colpisci la sbagli;
## - bivio 3: il bersaglio è dietro una colonna, si vede solo dopo esserci passati: ti giri e spari.
## I rami sbagliati (più veloci) riportano all'imbarco; il ramo giusto del bivio 3 finisce all'approdo.
## Sulla banchina dell'approdo, al posto dell'infermeria, la keycard e la serranda del magazzino con il
## lettore (scelta dell'utente del 18 ottobre).
## La strada è costruita qui da elenchi di punti (in pianta, quota dell'acqua 0).

const PUNTI := {
	"Imbarco": [Vector3(0, 0, 0), Vector3(0, 0, -30)],
	"Giusto1": [Vector3(0, 0, -30), Vector3(8, 0, -40), Vector3(16, 0, -45), Vector3(16, 0, -75)],
	"Sbagliato1": [Vector3(0, 0, -30), Vector3(-8, 0, -38), Vector3(-14, 0, -30), Vector3(-14, 0, 8), Vector3(-6, 0, 12), Vector3(0, 0, 0)],
	"Giusto2": [Vector3(16, 0, -75), Vector3(10, 0, -85), Vector3(0, 0, -90), Vector3(-20, 0, -90)],
	"Sbagliato2": [Vector3(16, 0, -75), Vector3(24, 0, -82), Vector3(26, 0, -40), Vector3(20, 0, 10), Vector3(0, 0, 0)],
	"Uscita": [Vector3(-20, 0, -90), Vector3(-28, 0, -96), Vector3(-34, 0, -96)],
	"Sbagliato3": [Vector3(-20, 0, -90), Vector3(-28, 0, -84), Vector3(-30, 0, -40), Vector3(-20, 0, 10), Vector3(0, 0, 0)],
}
## Velocità dei rami sbagliati (lo scivolo che riporta all'imbarco).
const VELOCITA_RITORNO := 5.0

var fiume: FiumeLento


func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.03, 0.04, 0.05)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.5, 0.55, 0.6)
	add_child(env)
	var luce := DirectionalLight3D.new()
	luce.rotation_degrees = Vector3(-60.0, 30.0, 0.0)
	luce.light_energy = 0.6
	add_child(luce)
	fiume = FiumeLento.new()
	fiume.name = "FiumeLento"
	var tratti := {}
	for nome in PUNTI:
		var t := TrattoFiume.new()
		t.name = nome
		t.curve = Curve3D.new()
		for p in PUNTI[nome]:
			t.curve.add_point(p)
		if nome.begins_with("Sbagliato"):
			t.ramo_sbagliato = true
			t.velocita = VELOCITA_RITORNO
		fiume.add_child(t)
		tratti[nome] = t
		_canale(PUNTI[nome])
	tratti["Uscita"].uscita = true
	for nome in ["Sbagliato1", "Sbagliato2", "Sbagliato3"]:
		tratti[nome].prossimo = tratti["Imbarco"]
	fiume.imbarco = tratti["Imbarco"]
	tratti["Imbarco"].paratia = _paratia("Paratia1", Vector3(0, 0, -30), tratti["Sbagliato1"], tratti["Giusto1"], false, Vector3(2.4, 1.4, -17))
	tratti["Giusto1"].paratia = _paratia("Paratia2", Vector3(16, 0, -75), tratti["Sbagliato2"], tratti["Giusto2"], true, Vector3(18.4, 1.4, -62))
	tratti["Giusto2"].paratia = _paratia("Paratia3", Vector3(-20, 0, -90), tratti["Sbagliato3"], tratti["Uscita"], false, Vector3(-6, 1.4, -92.4))
	add_child(fiume)
	# I cartelli d'uscita sopra l'imbocco di ogni ramo dei bivi: accesi solo sui rami giusti.
	for t in [tratti["Giusto1"], tratti["Sbagliato1"], tratti["Giusto2"], tratti["Sbagliato2"], tratti["Uscita"], tratti["Sbagliato3"]]:
		var c := CartelloUscita.new()
		c.name = "Cartello" + String(t.name)
		c.tratto = t
		add_child(c)
		var dove: Vector3 = t.punto(4.0)
		c.global_transform = Transform3D(Basis.looking_at(-t.direzione(4.0), Vector3.UP), dove + Vector3(0, 2.6, 0))
	# La colonna che nasconde il bersaglio del bivio 3 a chi arriva.
	var colonna := StaticBody3D.new()
	colonna.name = "Colonna"
	add_child(colonna)
	Graybox.box(colonna, Vector3(1.2, 4.0, 1.2), Vector3(-4.0, 2.0, -91.7))
	Graybox.box_shape(colonna, Vector3(1.2, 4.0, 1.2), Vector3(-4.0, 2.0, -91.7))
	# Le banchine dell'imbarco e dell'approdo.
	var banchine := StaticBody3D.new()
	banchine.name = "Banchine"
	add_child(banchine)
	for b in [[Vector3(3.0, 0.2, 6.0), Vector3(2.5, -0.1, 1.0)], [Vector3(6.0, 0.2, 6.0), Vector3(-38.0, -0.1, -96.0)]]:
		Graybox.box(banchine, b[0], b[1], Graybox.FLOOR)
		Graybox.box_shape(banchine, b[0], b[1])
	_keycard_e_serranda()


## Dopo l'approdo, al posto dell'infermeria: la keycard (sarebbe nella cassaforte) e la serranda del
## magazzino con il lettore (SerrandaMagazzino vera, senza il modello del raccordo).
func _keycard_e_serranda() -> void:
	var tessera := Pickup.new()
	tessera.name = "Keycard"
	tessera.item_id = &"keycard"
	tessera.item_name = "Keycard"
	var forma := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.3, 0.3, 0.3)
	forma.shape = box
	tessera.add_child(forma)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.9, 1.0)
	Graybox.box(tessera, Vector3(0.09, 0.005, 0.055), Vector3.ZERO, mat)
	add_child(tessera)
	tessera.global_position = Vector3(-36.5, 0.9, -94.0)
	var lettore := LettoreTessera.new()
	lettore.name = "LettoreTessera"
	var fl := CollisionShape3D.new()
	var bl := BoxShape3D.new()
	bl.size = Vector3(0.3, 0.35, 0.2)
	fl.shape = bl
	lettore.add_child(fl)
	add_child(lettore)
	lettore.global_position = Vector3(-36.4, 1.2, -98.9)
	var serranda := (load("res://scripts/tecnici/serranda_magazzino.gd") as GDScript).new() as PoweredDoor
	serranda.name = "SerrandaMagazzino"
	serranda.set(&"size", Vector3(1.8, 2.5, 0.2))
	serranda.set(&"open_offset", Vector3(0.0, 1.95, 0.0))
	serranda.set(&"open_speed", 0.4)
	serranda.set(&"lettore", lettore)
	add_child(serranda)
	serranda.global_position = Vector3(-38.0, 0.0, -99.2)


func _paratia(nome: String, dove: Vector3, sx: TrattoFiume, dx: TrattoFiume, a_destra: bool, bersaglio: Vector3) -> ParatiaFiume:
	var p := ParatiaFiume.new()
	p.name = nome
	p.position = dove
	p.sinistra = sx
	p.destra = dx
	p.a_destra = a_destra
	p.posizione_bersaglio = bersaglio
	p.raggio_bersaglio = 0.4
	fiume.add_child(p)
	return p


## Un canale grigio sotto la strada dell'acqua (solo grafica).
func _canale(punti: Array) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.35, 0.5)
	for i in range(1, punti.size()):
		var a: Vector3 = punti[i - 1]
		var b: Vector3 = punti[i]
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(2.4, 0.05, a.distance_to(b) + 2.4)
		mi.mesh = box
		mi.material_override = mat
		add_child(mi)
		mi.global_transform = Transform3D(Basis.looking_at(b - a, Vector3.UP), (a + b) * 0.5 + Vector3(0, -0.2, 0))
