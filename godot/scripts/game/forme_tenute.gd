class_name FormeTenute
extends RefCounted
## Le forme di collisione costruite dalle mesh (create_trimesh_shape), tenute per tutta la partita: a ogni ripartenza la
## sala si ricarica, ma le sue mesh sono le stesse risorse (il PackedScene resta in cache) e la forma esce uguale. Rifarla
## costava 0,6 s per la struttura dell'area bimbi e 0,1 s per ogni statua della mascotte (ritocco "ripartenze"
## dell'utente del 4 novembre: niente lavoro che serve solo la prima volta). Una mesh nuova ha la sua forma nuova.

static var _forme := {}


## La forma a triangoli di [param mesh] (la stessa per la stessa mesh: non va cambiata da chi la usa, se non come la
## cambia la prima volta).
static func trimesh(mesh: Mesh) -> ConcavePolygonShape3D:
	if mesh == null:
		return null
	var f: ConcavePolygonShape3D = _forme.get(mesh)
	if f == null:
		f = mesh.create_trimesh_shape()
		_forme[mesh] = f
	return f
