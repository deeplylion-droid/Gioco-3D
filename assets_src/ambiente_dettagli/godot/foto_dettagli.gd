extends Node3D
# Screenshot della sala con e senza i dettagli. Argomenti utente: <con|senza> <camera> <uscita.jpg>
var frame := 0
var args
func _ready():
	args = OS.get_cmdline_user_args()
	var sala = Node3D.new()
	sala.set_script(load("res://sala_luci_ambiente.gd"))
	add_child(sala)
	for f in ["architettura", "cupola", "piscina", "area_bimbi", "torre_scivoli", "oggetti", "luci", "interattivi"]:
		sala.add_child(load("res://sala/sala_%s.glb" % f).instantiate())
	if args[0] == "con":
		var dati = JSON.parse_string(FileAccess.get_file_as_string("res://posizionamento.json"))
		var cache = {}
		var det = Node3D.new(); det.name = "Dettagli"; add_child(det)
		for p in dati.posti:
			if not cache.has(p.glb):
				cache[p.glb] = load("res://det/" + p.glb.get_file()).instantiate()
			var nodo = cache[p.glb].get_node(NodePath(p.nodo)).duplicate()
			var b = p.basis
			nodo.transform = Transform3D(Basis(Vector3(b[0][0], b[0][1], b[0][2]), Vector3(b[1][0], b[1][1], b[1][2]), Vector3(b[2][0], b[2][1], b[2][2])), Vector3(p.posizione[0], p.posizione[1], p.posizione[2]))
			det.add_child(nodo)
	var dati_sala = JSON.parse_string(FileAccess.get_file_as_string("res://sala_dati.json"))
	var c = dati_sala.camere[args[1]]
	var pos = Vector3(c.pos_blender[0], c.pos_blender[2], -c.pos_blender[1])
	var mira = Vector3(c.guarda_blender[0], c.guarda_blender[2], -c.guarda_blender[1])
	if args.size() > 3:
		pos = Vector3(float(args[3]), float(args[4]), float(args[5])); mira = Vector3(float(args[6]), float(args[7]), float(args[8]))
	var cam = Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.fov = rad_to_deg(2.0 * atan(18.0 / c.lente_mm))
	add_child(cam)
	cam.look_at_from_position(pos, mira, Vector3.UP)
	cam.current = true
func _process(_d):
	frame += 1
	if frame == 40:
		get_viewport().get_texture().get_image().save_jpg(args[2], 0.9)
		get_tree().quit()
