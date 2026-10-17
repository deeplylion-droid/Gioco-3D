@tool
extends MeshInstance3D
## PROPOSTA: il tubo che collega la lancia allo zaino (dietro le spalle). Una curva di Bézier
## dal raccordo della lancia ([member da], con la direzione [member uscita]) a [member a], fuori
## dall'inquadratura, con anelli in rilievo ogni tanto.

@export var da := Vector3(0, -0.05, 0.6):
	set(v):
		da = v
		_costruisci()
@export var uscita := Vector3(0, -0.3, 1.0):
	set(v):
		uscita = v
		_costruisci()
@export var a := Vector3(0.25, -0.75, 1.1):
	set(v):
		a = v
		_costruisci()
@export var raggio := 0.028:
	set(v):
		raggio = v
		_costruisci()
@export var anelli := 0.0:   # passo degli anelli in rilievo (0 = liscio)
	set(v):
		anelli = v
		_costruisci()
@export var colore := Color(0.6, 0.08, 0.06):
	set(v):
		colore = v
		_costruisci()
@export var ruvidezza := 0.75


func _ready() -> void:
	_costruisci()


func _costruisci() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c1 := da + uscita.normalized() * 0.25
	var c2 := a + Vector3(0, 0.35, 0)
	var n := 40
	var lati := 14
	var prec: PackedVector3Array = []
	var lungo := 0.0
	var p_prec := da
	for i in n + 1:
		var t := float(i) / n
		var p := da.bezier_interpolate(c1, c2, a, t)
		var d := da.bezier_derivative(c1, c2, a, t).normalized()
		lungo += p.distance_to(p_prec)
		p_prec = p
		var x := d.cross(Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT).normalized()
		var y := x.cross(d).normalized()
		var r := raggio
		if anelli > 0.0:
			r *= 1.0 + 0.12 * smoothstep(0.6, 1.0, cos(lungo / anelli * TAU))
		var anello := PackedVector3Array()
		for k in lati:
			var ang := TAU * k / lati
			anello.append(p + (x * cos(ang) + y * sin(ang)) * r)
		if i > 0:
			for k in lati:
				var k2 := (k + 1) % lati
				for v in [prec[k], anello[k], anello[k2], prec[k], anello[k2], prec[k2]]:
					st.add_vertex(v)
		prec = anello
	st.generate_normals()
	mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.albedo_color = colore
	m.roughness = ruvidezza
	material_override = m
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	layers = 2
