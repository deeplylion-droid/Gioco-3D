class_name BavaRosa
extends Node3D
## Bava rosa fosforescente lasciata dalla medusa (tappe 7 e 8): un nastro continuo appoggiato a
## terra lungo [member punti], del colore delle vene dei tentacoli, che si vede bene al buio.
## Bordi irregolari, chiazze più dense e più rade, un respiro lento della luce; qualche luce
## magenta debole lungo il percorso tinge il pavimento intorno. Le sue luci hanno il meta
## risveglio_ignora: è luce della medusa, il blackout non la spegne.
##   var b := BavaRosa.new(); b.punti = [...]; add_child(b)

## Il percorso, in coordinate globali (in ordine). Con [member chiusa] l'ultimo si unisce al primo.
@export var punti := PackedVector3Array()
@export var chiusa := false
## Larghezza media del nastro (m) e quanto varia lungo il percorso.
@export var larghezza := 0.32
@export var variazione := 0.45
## Quanto sta sopra la superficie (contro lo z-fighting).
@export var sollevamento := 0.008
## Colore delle vene dei tentacoli (medusa/tentacoli_emissione.jpg: circa 126, 19, 86).
@export var colore := Color(1.0, 0.16, 0.68)
@export var emissione := 1.5
## Luci magenta lungo il percorso: una ogni [member passo_luci] metri (0 = nessuna).
@export var passo_luci := 3.0
@export var energia_luci := 0.45
@export var portata_luci := 2.2
@export var seme := 3

const PASSO := 0.12   # lunghezza dei segmenti del nastro (m)

static var _shader: Shader


func _ready() -> void:
	if punti.size() >= 2:
		costruisci()


func costruisci() -> void:
	for c in get_children():
		c.queue_free()
	var percorso := _liscio(punti, chiusa)
	if percorso.size() < 2:
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rumore := FastNoiseLite.new()
	rumore.seed = seme
	rumore.frequency = 0.55
	var lungo := 0.0
	var prec_s := Vector3.ZERO
	var prec_d := Vector3.ZERO
	var prec_u := 0.0
	for i in percorso.size():
		var p := percorso[i]
		var avanti := (percorso[mini(i + 1, percorso.size() - 1)] - percorso[maxi(i - 1, 0)])
		avanti.y = 0.0
		avanti = avanti.normalized() if avanti.length() > 0.0001 else Vector3.FORWARD
		var lato := avanti.cross(Vector3.UP).normalized()
		if i > 0:
			lungo += percorso[i - 1].distance_to(p)
		var w := larghezza * (1.0 + variazione * rumore.get_noise_1d(lungo * 3.0))
		# Il centro ondeggia un po': la scia non è una riga dritta.
		var centro := p + lato * rumore.get_noise_1d(lungo * 1.3 + 40.0) * larghezza * 0.6 + Vector3.UP * sollevamento
		var s := centro - lato * w * 0.5
		var d := centro + lato * w * 0.5
		if i > 0:
			_quad(st, prec_s, prec_d, s, d, prec_u, lungo)
		prec_s = s
		prec_d = d
		prec_u = lungo
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Nastro"
	mi.mesh = st.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.material_override = _materiale()
	add_child(mi)
	mi.global_transform = Transform3D.IDENTITY
	if passo_luci > 0.0:
		var fatta := passo_luci * 0.5
		var tot := 0.0
		for i in range(1, percorso.size()):
			tot += percorso[i - 1].distance_to(percorso[i])
			if tot >= fatta:
				fatta += passo_luci
				var o := OmniLight3D.new()
				o.light_color = colore
				o.light_energy = energia_luci
				o.omni_range = portata_luci
				o.omni_attenuation = 1.6
				o.shadow_enabled = false
				o.light_specular = 0.3
				o.light_volumetric_fog_energy = 0.6
				o.set_meta(&"risveglio_ignora", true)
				add_child(o)
				o.global_position = percorso[i] + Vector3.UP * 0.25


func _quad(st: SurfaceTool, a_s: Vector3, a_d: Vector3, b_s: Vector3, b_d: Vector3, ua: float, ub: float) -> void:
	for v in [[a_s, ua, 0.0], [b_s, ub, 0.0], [b_d, ub, 1.0], [a_s, ua, 0.0], [b_d, ub, 1.0], [a_d, ua, 1.0]]:
		st.set_uv(Vector2(v[1], v[2]))
		st.add_vertex(v[0])


## Catmull-Rom con segmenti di circa [constant PASSO] metri.
static func _liscio(p: PackedVector3Array, chiuso: bool) -> PackedVector3Array:
	var out := PackedVector3Array()
	var n := p.size()
	if n < 2:
		return out
	var tratti := n if chiuso else n - 1
	for i in tratti:
		var p0 := p[(i - 1 + n) % n] if (chiuso or i > 0) else p[i]
		var p1 := p[i]
		var p2 := p[(i + 1) % n]
		var p3 := p[(i + 2) % n] if (chiuso or i + 2 < n) else p2
		var passi := maxi(int(p1.distance_to(p2) / PASSO), 1)
		for k in passi:
			var t := float(k) / passi
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t))
	out.append(p[0] if chiuso else p[n - 1])
	return out


func _materiale() -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;
uniform vec4 colore : source_color = vec4(1.0, 0.16, 0.68, 1.0);
uniform float emissione = 1.5;

float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n2(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	float lungo = UV.x;
	float trasv = abs(UV.y * 2.0 - 1.0);
	// Bordo irregolare e chiazze: dove la bava è più densa brilla di più.
	float bordo = 0.72 + 0.28 * n2(vec2(lungo * 6.0, UV.y * 3.0));
	float forma = 1.0 - smoothstep(bordo - 0.25, bordo, trasv);
	float dense = 0.55 + 0.45 * n2(vec2(lungo * 1.7, 3.0));
	float filamenti = smoothstep(0.55, 0.9, n2(vec2(lungo * 9.0, UV.y * 7.0)));
	float alpha = forma * (0.55 + 0.45 * dense);
	// Respiro lento della luce lungo la scia.
	float respiro = 0.8 + 0.2 * sin(TIME * 1.3 - lungo * 0.8);
	ALBEDO = colore.rgb * 0.25;
	ROUGHNESS = 0.08;
	SPECULAR = 0.7;
	EMISSION = colore.rgb * emissione * (0.5 + 0.7 * dense + 0.6 * filamenti) * respiro * forma;
	ALPHA = clamp(alpha, 0.0, 1.0);
}
"""
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter(&"colore", colore)
	m.set_shader_parameter(&"emissione", emissione)
	return m
