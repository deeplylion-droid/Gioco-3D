class_name InclinaTesta
extends SkeletonModifier3D
## La testa che si inclina di lato mentre si gira (dopo lo sguardo, LookAtModifier3D, in Bambino): girandosi verso chi
## guarda, la piega un poco dalla stessa parte, come fa chi osserva incuriosito; dritta quando guarda davanti a sé.
## Gli assi sono nello spazio dello scheletro, presi dalla posa di riposo (il corpo non si piega nelle animazioni che
## lo usano: fermo e inclina_testa).

## L'osso della testa.
var osso := -1
## Dove guarda la testa, negli assi dell'osso (presi dalla sua posa di riposo nello scheletro).
var avanti_osso := Vector3.FORWARD
## Il su e l'avanti del corpo nello spazio dello scheletro.
var su_corpo := Vector3.UP
var avanti_corpo := Vector3.BACK
## Radianti di inclinazione per radiante di giro.
var quanto := 0.25
## Al massimo (radianti).
var massimo := deg_to_rad(10.0)


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or osso < 0:
		return
	var g := sk.get_bone_global_pose(osso)
	# (avanti_osso è negli assi dell'osso: girato con la posa dell'osso adesso)
	var avanti := (g.basis.orthonormalized() * avanti_osso).normalized()
	# il giro della testa rispetto al corpo, intorno al su del corpo
	var a := (avanti - su_corpo * avanti.dot(su_corpo))
	if a.length() < 1e-4:
		return
	var giro := avanti_corpo.signed_angle_to(a.normalized(), su_corpo)
	var roll := clampf(-giro * quanto, -massimo, massimo)
	if absf(roll) < 1e-5:
		return
	g.basis = Basis(avanti, roll) * g.basis
	sk.set_bone_global_pose(osso, g)
