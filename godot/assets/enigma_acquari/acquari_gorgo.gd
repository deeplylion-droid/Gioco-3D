class_name AcquariGorgo
extends Node
## Il gorgo dell'enigma degli acquari: quando la valvola rossa gira (EnigmaAcquari.gorgo_iniziato)
## nel cilindro basso del miscuglio l'acqua gira e scende formando un imbuto, con la schiuma che
## vortica, per [code]durata_gorgo[/code] secondi. L'imbuto è una mesh a disco abbassata al centro, sul
## pelo dell'acqua, con gorgo.gdshader (bracci di schiuma che girano, nucleo scuro e pieno); il pelo
## dell'addon gira con lui (corrente del gorgo, senza abbassarsi: l'imbuto lo fa la mesh); intanto suona il risucchio che gorgoglia (lo stesso
## gorgo della piscina a onde scelto dall'utente il 16 ottobre, più acuto: la vasca è piccola). Il
## colpo finale ("vasca svuotata") lo suona già l'addon audio quando l'acquario si svuota.
## Prepara anche, appena entra il livello, i materiali degli acquari (vetro, acqua vista dai vetri,
## disegno): compaiono di colpo rientrando dal magazzino e la prima compilazione bloccherebbe il gioco.
## È un Node (non Node3D): EnigmaAcquari non lo nasconde con gli acquari. Usa lo slot 0 dei gorghi
## della WaterBody (lo 1 lo usa lo zaino): il WaterTankLink lo riporta piano a zero a ogni fotogramma,
## ma questo nodo viene dopo nell'albero e ci rimette il gorgo.

## L'enigma (EnigmaAcquari).
@export var enigma: Node
## L'acqua dell'addon dell'acquario del miscuglio (WaterTankLink).
@export var acqua_misto: Node3D
## Rotazione del gorgo (+1 o -1) e profondità massima dell'imbuto (m).
@export var verso := 1.0
@export var imbuto := 0.16
const SHADER := preload("res://assets/enigma_acquari/gorgo.gdshader")

var _t := -1.0
var _durata := 4.0
var _suono: Node
var _prepara: Array[MeshInstance3D] = []
var _prepara_f := 0
var _mesh: MeshInstance3D
var _mat: ShaderMaterial
var _giro := 0.0


func _ready() -> void:
	if enigma and enigma.has_signal(&"gorgo_iniziato"):
		enigma.connect(&"gorgo_iniziato", inizia)
	_prepara_materiali.call_deferred()


func inizia() -> void:
	_durata = float(enigma.get(&"durata_gorgo")) if enigma and &"durata_gorgo" in enigma else 4.0
	_t = 0.0
	var audio := get_node_or_null(^"/root/Audio")
	if audio and acqua_misto and _suono == null:
		_suono = audio.call(&"crea_loop", &"piscina_svuota_loop", acqua_misto)
	if _suono:
		_suono.set(&"tono", 1.25)


## Vero mentre il gorgo gira (per i test e gli scatti).
func in_corso() -> bool:
	return _t >= 0.0


func _process(delta: float) -> void:
	_prepara_passo()
	if _t < 0.0 or acqua_misto == null:
		return
	_t += delta
	var k := clampf(_t / _durata, 0.0, 1.0)
	# parte in fretta, gira forte, e alla fine (poca acqua) l'imbuto si chiude
	var forza := smoothstep(0.0, 0.15, k) * (1.0 - smoothstep(0.85, 1.0, k))
	var c := acqua_misto.global_position
	var lv: float = acqua_misto.get(&"level")
	var fondo: float = acqua_misto.get(&"bottom")
	var profondo := clampf((lv - fondo) / 0.12, 0.0, 1.0)
	var r: float = minf((acqua_misto.get(&"size") as Vector2).x * 0.45, 0.75)
	acqua_misto.call(&"set_flow", 0, c, r, forza, verso * (1.2 + k), 0.0, 0.55, 0.0)
	_imbuto(c, lv, r, forza * profondo, delta)
	if randf() < 0.3 * forza:
		var a := randf() * TAU
		acqua_misto.call(&"add_impulse", c + Vector3(cos(a), 0, sin(a)) * r * 0.6, r * 0.2, -0.006 * forza, 0.25)
	if _suono:
		_suono.set(&"volume", forza * (0.5 + 0.5 * profondo))
	if _t >= _durata + 0.5:
		acqua_misto.call(&"clear_flow", 0)
		_t = -1.0
		if _mesh:
			_mesh.visible = false
		var surf := acqua_misto.call(&"get_surface") as Node3D
		if surf:
			surf.visible = lv_sopra_fondo(float(acqua_misto.get(&"level")))
		if _suono:
			_suono.set(&"volume", 0.0)


## La mesh dell'imbuto sul pelo: profonda [member imbuto] per [param k], che gira.
func _imbuto(c: Vector3, livello: float, r: float, k: float, delta: float) -> void:
	if _mesh == null:
		_mesh = MeshInstance3D.new()
		_mesh.name = "Imbuto"
		_mesh.mesh = _disco_imbuto()
		_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mat = ShaderMaterial.new()
		_mat.shader = SHADER
		var nt := NoiseTexture2D.new()
		nt.seamless = true
		nt.noise = FastNoiseLite.new()
		nt.noise.frequency = 0.05
		_mat.set_shader_parameter("rumore", nt)
		_mesh.material_override = _mat
		add_child(_mesh)
		_mesh.top_level = true
	var tank: Node = acqua_misto.get(&"tank")
	var m: Dictionary = tank.get(&"mix") if tank and &"mix" in tank else {}
	_mat.set_shader_parameter("colore", WaterMix.tinta(m) * 0.55 if not m.is_empty() else Color(0.3, 0.3, 0.3))
	_giro += delta * (2.5 + 4.0 * k) * verso
	_mat.set_shader_parameter("giro", _giro)
	_mat.set_shader_parameter("forza", clampf(k * 1.5, 0.0, 1.0))
	_mat.set_shader_parameter("raggio", 1.0)   # la mesh è di raggio 1, scalata
	# durante il gorgo la mesh fa da pelo (grande quanto il vetro): quello dell'addon, piatto, la
	# coprirebbe; si nasconde e torna alla fine
	var acceso := k > 0.03
	_mesh.visible = acceso
	var surf := acqua_misto.call(&"get_surface") as Node3D
	if surf:
		surf.visible = not acceso and lv_sopra_fondo(livello)
	var rv: float = (acqua_misto.get(&"size") as Vector2).x * 0.5 - 0.004
	_mesh.global_position = Vector3(c.x, livello, c.z)
	_mesh.scale = Vector3(rv, maxf(imbuto * k, 0.001), rv)


func lv_sopra_fondo(livello: float) -> bool:
	return livello > float(acqua_misto.get(&"bottom")) + 0.005


## Disco di raggio 1 abbassato al centro (y = -1 nel nucleo, 0 al bordo), con anelli fitti al centro.
func _disco_imbuto() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var anelli := 28
	var spicchi := 64
	var punti := []
	for a in anelli + 1:
		var rr := pow(float(a) / anelli, 1.6)
		var y := -1.0 / (1.0 + pow(rr / 0.14, 2.0)) * (1.0 - smoothstep(0.55, 1.0, rr))
		punti.append([rr, y])
	for a in anelli:
		for k in spicchi:
			var t0 := TAU * k / spicchi
			var t1 := TAU * (k + 1) / spicchi
			var q := []
			for v in [[a, t0], [a, t1], [a + 1, t0], [a + 1, t1]]:
				var pr: Array = punti[v[0]]
				q.append(Vector3(cos(v[1]) * pr[0], pr[1], sin(v[1]) * pr[0]))
			for i in [0, 3, 2, 0, 1, 3]:
				st.set_normal(Vector3.UP)
				st.add_vertex(q[i])
	st.generate_normals()
	return st.commit()


# --- Preparazione dei materiali ---------------------------------------------------------------

## Una copia piccola di ogni mesh degli acquari, davanti alla camera per qualche fotogramma.
func _prepara_materiali() -> void:
	if enigma == null:
		return
	for n in (enigma as Node).find_children("*", "GeometryInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var m := mi.material_override
		if m == null and mi.mesh.get_surface_count() > 0:
			m = mi.get_active_material(0)
		if m == null:
			continue
		var p := MeshInstance3D.new()
		p.mesh = mi.mesh
		p.material_override = mi.material_override
		p.scale = Vector3.ONE * 0.01
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(p)
		p.top_level = true
		_prepara.append(p)
	for n in (enigma as Node).find_children("*", "AcquarioVetro", true, false):
		for c in (n as Node).get_children(true):
			var mi := c as MeshInstance3D
			if mi:
				var p := MeshInstance3D.new()
				p.mesh = mi.mesh
				p.material_override = mi.material_override
				p.scale = Vector3.ONE * 0.01
				add_child(p)
				p.top_level = true
				_prepara.append(p)


func _prepara_passo() -> void:
	if _prepara.is_empty():
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	_prepara_f += 1
	var davanti := cam.global_transform * Vector3(0.0, 0.0, -1.5)
	for i in _prepara.size():
		_prepara[i].global_position = davanti + Vector3(0.002 * i, 0.0, 0.0)
	if _prepara_f > 6:
		for p in _prepara:
			p.queue_free()
		_prepara.clear()
