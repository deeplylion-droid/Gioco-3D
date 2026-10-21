extends Node
## Prova (non è nella CI): perché mettere nella scena la collisione grande della torre costa tanto.

func _ready() -> void:
	_run.call_deferred()

func _ms(t: int) -> float:
	return (Time.get_ticks_usec() - t) / 1000.0

func _run() -> void:
	var glb := (load("res://assets/ambiente/torre/torre_struttura.glb") as PackedScene).instantiate()
	var forma: ConcavePolygonShape3D = null
	for c in glb.find_children("*", "CollisionShape3D", true, false):
		var f := (c as CollisionShape3D).shape as ConcavePolygonShape3D
		if f and (forma == null or f.get_faces().size() > forma.get_faces().size()):
			forma = f
	print("FORMA facce %d backface %s" % [forma.get_faces().size() / 3, forma.backface_collision])
	var t := Time.get_ticks_usec()
	var dm := forma.get_debug_mesh()
	print("FORMA debug mesh %.1f ms" % _ms(t))
	var corpo := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = forma
	corpo.add_child(cs)
	t = Time.get_ticks_usec()
	add_child(corpo)
	print("FORMA add_child con forma già usata %.1f ms" % _ms(t))
	var copia := forma.duplicate() as ConcavePolygonShape3D
	t = Time.get_ticks_usec()
	copia.set_faces(forma.get_faces())
	print("FORMA set_faces (BVH) %.1f ms" % _ms(t))
	var corpo2 := StaticBody3D.new()
	var cs2 := CollisionShape3D.new()
	cs2.shape = copia
	corpo2.add_child(cs2)
	t = Time.get_ticks_usec()
	add_child(corpo2)
	print("FORMA add_child con forma nuova %.1f ms" % _ms(t))
	print("FORMA debug collisioni %s" % get_tree().debug_collisions_hint)
	glb.free()
	get_tree().quit()
