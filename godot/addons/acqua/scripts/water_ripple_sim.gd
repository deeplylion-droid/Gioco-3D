class_name WaterRippleSim
extends RefCounted
## Simulazione delle increspature interattive su GPU (compute shader, solo Forward+/Mobile).
##
## Copre il rettangolo di una vasca con una griglia di `resolution` texel sul lato lungo.
## Il risultato e' una Texture2DRD (R = altezza in metri, B = schiuma) che WaterBody passa agli
## shader tramite le variabili globali `water_ripple_tex` e `water_ripple_rect`.
## Gli impulsi (oggetti che entrano in acqua, scie, getto, gocce) si aggiungono con add_impulse().

const SHADER_PATH := "res://addons/acqua/compute/ripple_sim.glsl"
const MAX_IMPULSES := 32
const STEP_RATE := 60.0

## Velocita' delle onde (m/s) e smorzamento per passo.
var wave_speed := 0.55
var damping := 0.012
var foam_decay := 0.992
var foam_from_motion := 6.0
var foam_spread := 0.15

var texture := Texture2DRD.new()
var size := Vector2i.ZERO
var rect := Rect2()   # in pianta: posizione = (min x, min z), dimensione = (larghezza x, profondita' z)

var _rd: RenderingDevice
var _shader: RID
var _pipeline: RID
var _tex: Array[RID] = [RID(), RID()]
var _set_src: Array[RID] = [RID(), RID()]
var _set_dst: Array[RID] = [RID(), RID()]
var _imp_buffer: RID
var _imp_set: RID
var _current := 0
var _pending: PackedFloat32Array = PackedFloat32Array()
var _pending_count := 0
var _accum := 0.0
var _gpu_ready := false


func setup(world_rect: Rect2, resolution: int) -> void:
	rect = world_rect
	var aspect := world_rect.size.y / maxf(world_rect.size.x, 0.001)
	if aspect <= 1.0:
		size = Vector2i(resolution, maxi(8, int(round(resolution * aspect))))
	else:
		size = Vector2i(maxi(8, int(round(resolution / aspect))), resolution)
	# il file dello shader si carica sul thread principale; sul thread di rendering solo chiamate RD
	var shader_file: RDShaderFile = load(SHADER_PATH)
	var spirv := shader_file.get_spirv()
	if spirv.compile_error_compute != "":
		push_error("WaterRippleSim: " + spirv.compile_error_compute)
		return
	RenderingServer.call_on_render_thread(_init_gpu.bind(size, spirv))


func is_ready() -> bool:
	return _gpu_ready


## Metri per texel.
func cell_size() -> Vector2:
	return rect.size / Vector2(size)


## Aggiunge un impulso: `amplitude` in metri (positivo = l'acqua sale), raggio in metri.
func add_impulse(world_pos: Vector3, radius: float, amplitude: float, foam := 0.0) -> void:
	if _pending_count >= MAX_IMPULSES:
		return
	var uv := (Vector2(world_pos.x, world_pos.z) - rect.position) / rect.size
	if uv.x < -0.05 or uv.y < -0.05 or uv.x > 1.05 or uv.y > 1.05:
		return
	var cell := cell_size()
	var r_tex := maxf(radius / cell.x, 1.5)
	_pending.append_array([uv.x * size.x, uv.y * size.y, r_tex, amplitude, foam, 0.0, 0.0, 0.0])
	_pending_count += 1


## Avanza la simulazione di `delta` secondi (passi fissi a 60 Hz, al massimo 4 per fotogramma).
func step(delta: float) -> void:
	if not _gpu_ready:
		return
	_accum = minf(_accum + delta, 4.0 / STEP_RATE)
	var steps := int(_accum * STEP_RATE)
	if steps <= 0:
		return
	_accum -= steps / STEP_RATE
	# Texture2DRD va aggiornata sul thread principale (emette "changed")
	var cell := cell_size()
	var courant := clampf(wave_speed / STEP_RATE / minf(cell.x, cell.y), 0.05, 0.7)
	var impulses := _pending.duplicate()
	var count := _pending_count
	_pending.clear()
	_pending_count = 0
	RenderingServer.call_on_render_thread(_gpu_steps.bind(steps, courant * courant, impulses, count))
	_current = (_current + steps) % 2
	var latest: RID = _tex[_current]
	if latest.is_valid() and texture.texture_rd_rid != latest:
		texture.texture_rd_rid = latest


func free_gpu() -> void:
	texture.texture_rd_rid = RID()
	_gpu_ready = false
	RenderingServer.call_on_render_thread(_free_gpu.bind(_tex.duplicate(), _imp_buffer, _shader))


# --- thread di rendering ---------------------------------------------------------------------

func _init_gpu(tex_size: Vector2i, spirv: RDShaderSPIRV) -> void:
	_rd = RenderingServer.get_rendering_device()
	if _rd == null:
		return
	_shader = _rd.shader_create_from_spirv(spirv)
	_pipeline = _rd.compute_pipeline_create(_shader)

	var tf := RDTextureFormat.new()
	tf.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	tf.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	tf.width = tex_size.x
	tf.height = tex_size.y
	tf.depth = 1
	tf.array_layers = 1
	tf.mipmaps = 1
	tf.usage_bits = (RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
			| RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
			| RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
			| RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT)
	for i in 2:
		_tex[i] = _rd.texture_create(tf, RDTextureView.new(), [])
		_rd.texture_clear(_tex[i], Color(0, 0, 0, 0), 0, 1, 0, 1)
	for i in 2:
		_set_src[i] = _make_image_set(_tex[i], 0)
		_set_dst[i] = _make_image_set(_tex[i], 1)
	var zeros := PackedFloat32Array()
	zeros.resize(MAX_IMPULSES * 8)
	_imp_buffer = _rd.storage_buffer_create(zeros.size() * 4, zeros.to_byte_array())
	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u.binding = 0
	u.add_id(_imp_buffer)
	_imp_set = _rd.uniform_set_create([u], _shader, 2)
	_gpu_ready = true


func _make_image_set(tex: RID, set_index: int) -> RID:
	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	u.binding = 0
	u.add_id(tex)
	return _rd.uniform_set_create([u], _shader, set_index)


func _gpu_steps(steps: int, courant2: float, impulses: PackedFloat32Array, count: int) -> void:
	if not _gpu_ready:
		return
	if count > 0:
		_rd.buffer_update(_imp_buffer, 0, impulses.size() * 4, impulses.to_byte_array())
	var groups_x := (size.x + 7) / 8
	var groups_y := (size.y + 7) / 8
	var cur := _current_gpu
	for i in steps:
		var pc := PackedFloat32Array([
			size.x, size.y, courant2, damping,
			foam_decay, foam_from_motion, float(count if i == 0 else 0), foam_spread,
		])
		var cl := _rd.compute_list_begin()
		_rd.compute_list_bind_compute_pipeline(cl, _pipeline)
		_rd.compute_list_bind_uniform_set(cl, _set_src[cur], 0)
		_rd.compute_list_bind_uniform_set(cl, _set_dst[1 - cur], 1)
		_rd.compute_list_bind_uniform_set(cl, _imp_set, 2)
		_rd.compute_list_set_push_constant(cl, pc.to_byte_array(), pc.size() * 4)
		_rd.compute_list_dispatch(cl, groups_x, groups_y, 1)
		_rd.compute_list_end()
		cur = 1 - cur
	_current_gpu = cur


var _current_gpu := 0


func _free_gpu(texs: Array[RID], imp_buffer: RID, shader: RID) -> void:
	var rd := RenderingServer.get_rendering_device()
	if rd == null:
		return
	for t in texs:
		if t.is_valid():
			rd.free_rid(t)
	if imp_buffer.is_valid():
		rd.free_rid(imp_buffer)
	if shader.is_valid():
		rd.free_rid(shader)
