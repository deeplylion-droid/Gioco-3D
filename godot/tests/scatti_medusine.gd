extends Node
## Scatti delle micro medusine luminose della piscina a onde (tappa 5) in una vasca di prova, senza
## la sala: da vicino come dal bordo, molto da vicino e da lontano come dalla spiaggia, con l'acqua
## torbida della piscina e l'ambiente della sala. Serve a regolarne l'aspetto in fretta; gli scatti
## veri sono nella sala (scatti_sala.gd con SCATTI_PISCINA, screenshots_zaino.gd).
## Uso: xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --fixed-fps 60 \
##        --resolution 1280x720 --script res://tests/run.gd -- res://tests/scatti_medusine.gd <cartella>

var out_dir := "user://scatti_medusine"
var _med: Medusine


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 1:
		out_dir = args[1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _run() -> void:
	var game := get_node_or_null(^"/root/Game")
	if game and &"pause_on_focus_loss" in game:
		game.set(&"pause_on_focus_loss", false)
	var mondo := Node3D.new()
	mondo.name = "VascaDiProva"
	get_tree().root.add_child(mondo)
	var we := WorldEnvironment.new()
	we.environment = (load("res://assets/env/sala_environment.tres") as Environment).duplicate()
	mondo.add_child(we)
	# La vasca: fondo a -0,55, pareti fino a 0,25; intorno il pavimento.
	var piastrelle := StandardMaterial3D.new()
	piastrelle.albedo_color = Color(0.5, 0.58, 0.6)
	piastrelle.roughness = 0.45
	var bordo := StandardMaterial3D.new()
	bordo.albedo_color = Color(0.62, 0.6, 0.55)
	bordo.roughness = 0.7
	_scatola(mondo, Vector3(0.0, -0.65, 0.0), Vector3(10.0, 0.2, 7.0), piastrelle)
	_scatola(mondo, Vector3(5.1, -0.15, 0.0), Vector3(0.2, 0.8, 7.4), piastrelle)
	_scatola(mondo, Vector3(-5.1, -0.15, 0.0), Vector3(0.2, 0.8, 7.4), piastrelle)
	_scatola(mondo, Vector3(0.0, -0.15, 3.6), Vector3(10.4, 0.8, 0.2), piastrelle)
	_scatola(mondo, Vector3(0.0, -0.15, -3.6), Vector3(10.4, 0.8, 0.2), piastrelle)
	_scatola(mondo, Vector3(0.0, 0.15, 12.0), Vector3(30.0, 0.2, 16.6), bordo)
	_scatola(mondo, Vector3(0.0, 0.15, -12.0), Vector3(30.0, 0.2, 16.6), bordo)
	_scatola(mondo, Vector3(10.0, 0.15, 0.0), Vector3(9.6, 0.2, 7.6), bordo)
	_scatola(mondo, Vector3(-10.0, 0.15, 0.0), Vector3(9.6, 0.2, 7.6), bordo)
	var tank: WaterTank = (load("res://scenes/props/water_tank.tscn") as PackedScene).instantiate()
	tank.name = "Pozza"
	tank.build_walls = false
	tank.inner_size = Vector3(10.0, 0.55, 7.0)
	tank.capacity_liters = 80.0
	tank.max_fill = 1.0
	tank.fill = 1.0
	tank.position = Vector3(0.0, -0.55, 0.0)
	mondo.add_child(tank)
	var acqua: Node3D = (load("res://addons/acqua/scenes/acqua_per_vasca.tscn") as PackedScene).instantiate()
	acqua.set(&"tank", tank)
	acqua.set(&"style", load("res://addons/acqua/presets/stile_2_torbida.tres"))
	acqua.set(&"planar_reflection_on_high", false)
	mondo.add_child(acqua)
	# La luce della sala di notte: una lampada d'emergenza lontana e un po' di luce fredda dall'alto.
	var lampada := OmniLight3D.new()
	lampada.position = Vector3(6.0, 4.0, -4.0)
	lampada.light_color = Color(1.0, 0.82, 0.62)
	lampada.light_energy = 1.4
	lampada.omni_range = 16.0
	mondo.add_child(lampada)
	var cielo := DirectionalLight3D.new()
	cielo.rotation = Vector3(deg_to_rad(-55.0), deg_to_rad(30.0), 0.0)
	cielo.light_color = Color(0.6, 0.7, 0.9)
	cielo.light_energy = 0.15
	mondo.add_child(cielo)
	_med = Medusine.new()
	_med.vasca = tank
	mondo.add_child(_med)
	var cam := Camera3D.new()
	cam.fov = 75.0
	mondo.add_child(cam)
	cam.current = true
	# La torcia del giocatore (come nella sala): un cono di luce calda dalla camera.
	var torcia := SpotLight3D.new()
	torcia.light_color = Color(1.0, 0.92, 0.8)
	torcia.light_energy = 6.0
	torcia.spot_angle = 20.0
	torcia.spot_range = 25.0
	torcia.shadow_enabled = true
	cam.add_child(torcia)
	cam.global_position = Vector3(0.0, 1.6, 6.5)
	cam.look_at(Vector3(0.0, -0.3, 0.5))
	# Nuotano un po' prima dello scatto.
	await _frames(240)
	await _scatto(cam, "medusine_bordo", Vector3(0.0, 1.5, 4.6), Vector3(0.0, -0.3, 0.8))
	await _scatto(cam, "medusine_spiaggia", Vector3(0.0, 1.6, 15.0), Vector3(0.0, -0.3, 0.0))
	# Molto da vicino: la medusina più vicina al bordo sud.
	var pos := _med.posizioni()
	var vicina := pos[0]
	for q in pos:
		if q.z > vicina.z:
			vicina = q
	await _scatto(cam, "medusine_vicino", vicina + Vector3(0.25, 0.32, 0.38), vicina)
	print("scatti salvati in ", ProjectSettings.globalize_path(out_dir))
	get_tree().quit()


func _scatto(cam: Camera3D, nome: String, da: Vector3, verso: Vector3) -> void:
	cam.global_position = da
	cam.look_at(verso)
	await _frames(20)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(out_dir.path_join(nome + ".jpg"), 0.92)
	print("salvato ", nome)


func _scatola(padre: Node3D, centro: Vector3, misure: Vector3, mat: Material) -> void:
	var corpo := StaticBody3D.new()
	corpo.position = centro
	var forma := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = misure
	forma.shape = box
	corpo.add_child(forma)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = misure
	mi.mesh = bm
	mi.material_override = mat
	corpo.add_child(mi)
	padre.add_child(corpo)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
