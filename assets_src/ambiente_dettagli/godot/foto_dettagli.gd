extends Node3D
# Screenshot della sala dallo spawn, con o senza i dettagli. Argomenti: <con|senza> <uscita.jpg> [px py pz mx my mz]
var frame := 0
var args
func _ready():
	args = OS.get_cmdline_user_args()
	var sala = Node3D.new()
	sala.set_script(load("res://sala_luci_ambiente.gd"))
	add_child(sala)
	for f in ["architettura", "cupola", "piscina", "area_bimbi", "torre_scivoli", "oggetti", "luci", "interattivi", "monumento"]:
		sala.add_child(load("res://sala/sala_%s.glb" % f).instantiate())
	if args[0] == "con":
		var det = Node3D.new(); det.name = "Dettagli"
		det.set_script(load("res://dettagli_sala.gd"))
		det.cartella = "res://assets/ambiente_dettagli"
		add_child(det)
	var pos = Vector3(0, 1.65, 19.2); var mira = Vector3(0, 2.6, 10.0)
	if args.size() > 2:
		pos = Vector3(float(args[2]), float(args[3]), float(args[4])); mira = Vector3(float(args[5]), float(args[6]), float(args[7]))
	var cam = Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.fov = 80.0
	add_child(cam)
	cam.look_at_from_position(pos, mira, Vector3.UP)
	cam.current = true
func _process(_d):
	frame += 1
	if frame == 40:
		var rs = RenderingServer
		print("DRAW ", rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), " PRIMITIVE ", rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME), " OGGETTI ", rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))
		get_viewport().get_texture().get_image().save_jpg(args[1], 0.9)
		get_tree().quit()
