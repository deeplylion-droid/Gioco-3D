extends Node
## Misure delle braccia dello squalo all'inizio, dall'animazione del GLB (caricato a runtime, senza import: così si
## confronta anche il GLB di un'altra versione): a ogni fotogramma dell'animazione (1/30 s) dal richiamo a dopo la porta,
## le ossa delle braccia nello spazio del modello e in quello del petto. Velocità, accelerazioni e scatti si fanno dopo,
## dal CSV. Senza schermo.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/collaudo/squalo_braccia_misure.gd \
##        <glb> <uscita.csv>

const OSSA := ["petto", "testa", "braccio.L", "avambraccio.L", "mano.L", "braccio.R", "avambraccio.R", "mano.R"]


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var doc := GLTFDocument.new()
	var stato := GLTFState.new()
	var err := doc.append_from_file(a[1], stato)
	if err != OK:
		printerr("non carico ", a[1], ": ", err)
		get_tree().quit(1)
		return
	var radice := doc.generate_scene(stato) as Node3D
	add_child(radice)
	var ap := radice.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var sk := radice.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var nome: StringName = ap.get_animation_list()[0]
	for n in ap.get_animation_list():
		if String(n).contains("risveglio"):
			nome = n
	print("animazione %s, %.2f s" % [nome, ap.get_animation(nome).length])
	ap.play(nome)
	var csv := FileAccess.open(a[2], FileAccess.WRITE)
	var testa := "t"
	for o in OSSA:
		testa += ",%s_x,%s_y,%s_z,%s_px,%s_py,%s_pz" % [o, o, o, o, o, o]
	csv.store_line(testa)
	var petto := sk.find_bone("petto")
	var k := 150
	while k <= 360:
		var t := k / 30.0
		ap.seek(t, true)
		var riga := "%.4f" % t
		var tp := sk.get_bone_global_pose(petto)
		for o in OSSA:
			var b := sk.find_bone(o)
			var g := sk.get_bone_global_pose(b).origin
			var l := tp.affine_inverse() * g
			riga += ",%.5f,%.5f,%.5f,%.5f,%.5f,%.5f" % [g.x, g.y, g.z, l.x, l.y, l.z]
		csv.store_line(riga)
		k += 1
	csv.close()
	print("FINE misure ", a[2])
	get_tree().quit()
