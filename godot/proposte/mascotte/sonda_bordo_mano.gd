extends Node
## Sonda: il bordo della vasca 3 (vasca_2) davanti a lei, girata verso il muro (perpendicolare), per la salita con la mano
## sul bordo (0.3.21, scelta C dell'utente). Per vari spostamenti di lato: la faccia del muro dalla parte di lei, la cima
## (altezza) e dove finisce la cima (la faccia dentro la vasca). Nello spazio di lei: avanti, lato (+ a sinistra di lei),
## su; e nello spazio del modello di Blender (x a sinistra di lei, -y avanti, z su).
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://proposte/mascotte/sonda_bordo_mano.gd

const SCENA := "res://scenes/sala/inseguimento/sala_inseguimento.tscn"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var sala := (load(SCENA) as PackedScene).instantiate() as SalaInseguimento
	sala.crea_luci = false
	add_child(sala)
	for i in 10:
		await get_tree().physics_frame
	sala.set_physics_process(false)
	var spazio := get_viewport().world_3d.direct_space_state
	var d := sala.dati
	var r: Array = d["vasche"][2]["rett"]
	var su := sala._posto_vasca(2)
	var muro := SalaInseguimento.b([(r[0] + r[2]) / 2.0, r[1], float(d["vasche"][2]["fondo"])])
	var avanti := (muro - su) * Vector3(1, 0, 1)
	avanti = avanti.normalized()
	var sinistra := Vector3.UP.cross(avanti).normalized()     # la sinistra di lei, che guarda avanti
	print("lei a %s, avanti %s, sinistra %s" % [su, avanti, sinistra])
	for lato in [-0.8, -0.6, -0.45, -0.3, 0.0, 0.3, 0.45, 0.6]:
		var a: Vector3 = su + sinistra * lato + Vector3.UP * 3.3
		var hit := spazio.intersect_ray(PhysicsRayQueryParameters3D.create(a, a + avanti * 5.0))
		if hit.is_empty():
			print("lato %+.2f: niente" % lato)
			continue
		var faccia: float = (hit["position"] - su).dot(avanti)
		var cima := NAN
		var fine := NAN
		var k := 0.005
		while k < 0.8:
			var x: Vector3 = su + sinistra * lato + avanti * (faccia + k)
			var h := spazio.intersect_ray(PhysicsRayQueryParameters3D.create(x + Vector3.UP * 3.0 + Vector3.UP * su.y * 0.0 + Vector3(0, 6.0, 0) * 0.0 + Vector3(0, 4.0, 0), x + Vector3(0, 1.0, 0)))
			var y := NAN if h.is_empty() else float(h["position"].y - su.y)
			if is_nan(cima) and not is_nan(y):
				cima = y
			if not is_nan(cima) and (is_nan(y) or absf(y - cima) > 0.02):
				fine = k
				break
			k += 0.005
		print("lato %+.2f: faccia del muro a %.3f m avanti, cima a %+.3f m, la cima finisce %.3f m dopo la faccia (normale %s)" % [
			lato, faccia, cima, fine, hit["normal"]])
	get_tree().quit(0)
