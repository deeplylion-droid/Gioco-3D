class_name WaterEnvCapture
extends Node
## Cattura una cubemap della stanza da sopra il centro della vasca (una volta, all'avvio, o quando
## si chiama capture()). Lo shader dell'acqua la usa, con la proiezione su scatola, come riflesso di
## riserva dove SSR non trova niente (per esempio il soffitto fuori dallo schermo).
## Costo: 6 rendering della scena a `face_size` x `face_size`, solo al momento della cattura.

signal captured(cubemap: Cubemap)

var face_size := 128

# Orientamenti delle sei facce nell'ordine dei layer delle cubemap (+X, -X, +Y, -Y, +Z, -Z).
# Ogni base e' (destra, su, indietro) della camera che guarda lungo la direzione della faccia;
# le immagini vengono poi ribaltate orizzontalmente perche' le cubemap usano un sistema sinistrorso.
const FACES := [
	[Vector3(1, 0, 0), Vector3(0, -1, 0)],
	[Vector3(-1, 0, 0), Vector3(0, -1, 0)],
	[Vector3(0, 1, 0), Vector3(0, 0, 1)],
	[Vector3(0, -1, 0), Vector3(0, 0, -1)],
	[Vector3(0, 0, 1), Vector3(0, -1, 0)],
	[Vector3(0, 0, -1), Vector3(0, -1, 0)],
]


func capture(body: Node3D) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(face_size, face_size)
	vp.use_hdr_2d = true
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	vp.audio_listener_enable_3d = false
	add_child(vp)
	var cam := Camera3D.new()
	cam.fov = 90.0
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.near = 0.05
	cam.cull_mask = 0xFFFFF & ~WaterBody.WATER_LAYER
	vp.add_child(cam)
	cam.current = true
	var env: Environment
	var we := get_tree().root.find_children("*", "WorldEnvironment", true, false)
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
	cam.environment = env
	var origin: Vector3 = body.global_position
	origin.y = body.level + body.env_capture_height
	var images: Array[Image] = []
	for f in FACES:
		var fwd: Vector3 = f[0]
		var up: Vector3 = -f[1]
		cam.global_transform = Transform3D(Basis.looking_at(fwd, up), origin)
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.flip_x()
		img.generate_mipmaps()
		images.append(img)
	var cm := Cubemap.new()
	var err := cm.create_from_images(images)
	vp.queue_free()
	if err != OK:
		push_warning("WaterEnvCapture: cubemap non creata (%d)" % err)
		return
	if body.material:
		body.material.set_shader_parameter("env_cubemap", cm)
		body.material.set_shader_parameter("env_cubemap_valid", true)
		body.material.set_shader_parameter("env_capture_pos", origin)
	captured.emit(cm)
