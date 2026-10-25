class_name WaterPlanarReflection
extends Node3D
## Riflesso planare per la qualita' alta: una camera speculare rispetto al pelo dell'acqua rende
## la scena in una SubViewport a risoluzione ridotta. La camera esclude la superficie dell'acqua
## (WaterBody.WATER_LAYER) e l'interno delle vasche (WaterBody.POOL_INTERIOR_LAYER), che altrimenti
## starebbero tra la camera speculare e il piano dell'acqua.
## Lo shader campiona la texture con u = 1 - u (la camera speculare vede l'immagine ribaltata).

## Frazione della risoluzione dello schermo (0.5 = mezza risoluzione).
var resolution_scale := 0.5
## Nebbia volumetrica anche nel riflesso (costa come una seconda nebbia).
var volumetric_fog_in_reflection := true
## Ombre delle luci puntiformi nel riflesso.
var shadows_in_reflection := true

var viewport: SubViewport
var camera: Camera3D
var _body: Node3D


func setup(body: Node3D) -> void:
	_body = body
	viewport = SubViewport.new()
	viewport.name = "ReflectionViewport"
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.use_hdr_2d = true
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.positional_shadow_atlas_size = 2048 if shadows_in_reflection else 0
	viewport.audio_listener_enable_3d = false
	add_child(viewport)
	camera = Camera3D.new()
	# (e non lo strato 18, delle zone che il gioco prepara fuori vista: SalaTorre.STRATO_PREPARA)
	camera.cull_mask = 0xFFFFF & ~(WaterBody.WATER_LAYER | WaterBody.POOL_INTERIOR_LAYER | (1 << 17))
	viewport.add_child(camera)
	camera.current = true
	_setup_environment()
	_resize()
	get_tree().root.size_changed.connect(_resize)
	# aggiorna la camera speculare dopo che tutti gli altri nodi hanno mosso la camera principale
	process_priority = 100000
	body.material.set_shader_parameter("planar_reflection_tex", viewport.get_texture())


func _process(_delta: float) -> void:
	_update_camera()


func _setup_environment() -> void:
	# stesso ambiente della scena ma lineare (niente tonemap ne' bagliore): i valori finiscono
	# nell'illuminazione dell'acqua, che poi passa dal tonemap della camera principale
	var we := get_tree().root.find_children("*", "WorldEnvironment", true, false)
	var env: Environment = null
	if not we.is_empty() and we[0].environment:
		env = we[0].environment.duplicate()
	else:
		env = Environment.new()
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	env.glow_enabled = false
	env.ssr_enabled = false
	env.ssao_enabled = false
	env.ssil_enabled = false
	env.adjustment_enabled = false
	env.volumetric_fog_enabled = env.volumetric_fog_enabled and volumetric_fog_in_reflection
	camera.environment = env


func _resize() -> void:
	var s := get_tree().root.get_visible_rect().size
	viewport.size = Vector2i(maxi(16, int(s.x * resolution_scale)), maxi(16, int(s.y * resolution_scale)))


func _update_camera() -> void:
	var main_cam := get_tree().root.get_camera_3d()
	if main_cam == null or not is_instance_valid(_body):
		return
	var plane_y: float = _body.level
	var t := main_cam.global_transform
	var p := t.origin
	p.y = 2.0 * plane_y - p.y
	var bx := t.basis.x
	var by := t.basis.y
	var bz := t.basis.z
	bx.y = -bx.y
	by.y = -by.y
	bz.y = -bz.y
	# base destrorsa: si ribalta l'asse x (l'immagine viene specchiata, lo shader la raddrizza)
	camera.global_transform = Transform3D(Basis(-bx, by, bz), p)
	camera.fov = main_cam.fov
	camera.near = main_cam.near
	camera.far = main_cam.far
	camera.keep_aspect = main_cam.keep_aspect
	camera.h_offset = -main_cam.h_offset
	camera.v_offset = main_cam.v_offset
