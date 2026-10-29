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
@export var sollevamento := 0.012
## Appoggia ogni vertice del nastro sul pavimento vero (un raggio verso il basso sui corpi del mondo),
## così segue gradini, soglie e bordi senza finire sotto il pavimento o staccarsene (prova della
## v0.3.2: "la scia si interrompe in alcuni punti e poi riparte"). Falso per i tratti in verticale.
@export var appoggia := true
## Quanto sopra (gradini, soglie: non i ripiani delle panche) e sotto il percorso cerca il pavimento (m).
@export var ricerca_su := 0.3
@export var ricerca_giu := 0.6
## Colore delle vene dei tentacoli (medusa/tentacoli_emissione.jpg: circa 126, 19, 86).
@export var colore := Color(1.0, 0.16, 0.68)
@export var emissione := 1.5
## Quanto si vede (1 = piena). L'utente la vuole "al 75% visibile": moltiplica la trasparenza e
## l'emissione nella stessa proporzione, così non sembra più luminosa.
@export_range(0.0, 1.0) var opacita := 0.75
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
		if appoggia:
			s = _a_terra(s)
			d = _a_terra(d)
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


## Il punto appoggiato sul pavimento sotto (o appena sopra) di lui, più [member sollevamento].
func _a_terra(q: Vector3) -> Vector3:
	var w := get_world_3d()
	if w == null:
		return q
	var rq := PhysicsRayQueryParameters3D.create(q + Vector3.UP * ricerca_su, q - Vector3.UP * ricerca_giu, Layers.WORLD)
	# (senza passare dalle crepe fra due triangoli, dove un raggio solo trova il pavimento sotto)
	var hit := RaggioSicuro.interseca(w.direct_space_state, rq)
	if hit.is_empty():
		return q
	return Vector3(q.x, (hit.position as Vector3).y + sollevamento, q.z)


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
		# in un file, così il campione della Risalita (materiali_campione.tres) usa lo stesso shader
		_shader = load("res://addons/grafica/bava_rosa.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter(&"colore", colore)
	m.set_shader_parameter(&"emissione", emissione)
	m.set_shader_parameter(&"opacita", opacita)
	return m
