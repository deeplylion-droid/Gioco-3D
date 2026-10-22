extends PoweredDoor
## La serranda tra il magazzino dei gonfiabili e la sala grande, nell'angolo sud-ovest (tappa 7, strada
## B). Resta chiusa finché il giocatore non ci arriva dal magazzino, risalendo dopo la sala pompe
## (riscontro sulla v0.3.1: "la porta nuova che ti riporta su dalla stanza dei generatori è già
## aperta, deve essere chiusa fino a che non risali"). Allora si alza fino a dove l'hanno modellata
## gli ambienti tecnici, con la barra a strisce a 1,95 m. Il motore e il colpo a fine corsa li suona
## l'addon audio, come per ogni PoweredDoor che sale: per questo lo script non ha un class_name.
## Il modello della serranda è nel glTF del raccordo, fuso con gli altri dettagli (RACCORDO_dettagli):
## le sue lamelle e la barra si tolgono da lì e diventano una pila di lamelle che scende fino a terra.
## Si vedono solo quelle sotto l'architrave: le altre stanno dentro il muro.
## L'origine è in basso al centro del vano, sul piano della serranda; +Z locale va verso il magazzino.

## La mesh del raccordo con la serranda dentro (RACCORDO_dettagli).
@export var modello: NodePath
## Il riquadro della serranda nelle coordinate della mesh del modello: lamelle e barra, senza le guide
## ai lati né l'architrave.
@export var riquadro := AABB(Vector3(18.9, 10.99, 13.9), Vector3(0.2, 0.51, 2.2))
## Passo delle lamelle (m) e quante sono in tutto (chiusa arrivano fin dentro il muro).
@export var passo := 0.07
@export var lamelle := 38
## Le lamelle si vedono solo se finiscono sotto questa quota (locale): l'architrave è a 2,5 m.
@export var quota_architrave := 2.45
## Dove deve arrivare il giocatore per aprirla (coordinate locali, dalla parte del magazzino).
@export var zona_apertura := AABB(Vector3(-1.2, 0.0, 0.7), Vector3(2.4, 2.5, 3.0))
## Il lettore della keycard (LettoreTessera, scelta dell'utente del 18 ottobre): se c'è, la serranda
## si apre solo quando il lettore ha letto la tessera, e allora si apre subito. Vuoto = come prima.
@export var lettore: Node

## Vero quando il giocatore ci è arrivato dal magazzino: si apre e resta aperta.
var aperta := false

var _lamelle: MultiMeshInstance3D
var _barra: MeshInstance3D
var _altezza_lamella := 0.066
var _pronta := false


func _ready() -> void:
	stay_open = true
	safety_check = false
	super._ready()
	# Si vede solo il modello: del pannello del graybox resta solo la collisione (via la mesh, non nascosta:
	# nascosta, il controllo di posizionamento la rendeva visibile e la trovava dentro la barra)
	for c in get_children(true):
		for m in c.find_children("*", "MeshInstance3D", true, false):
			(m as MeshInstance3D).mesh = null
	var zona := Area3D.new()
	zona.name = "ZonaApertura"
	zona.collision_layer = 0
	zona.collision_mask = Layers.PLAYER
	zona.monitorable = false
	var forma := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = zona_apertura.size
	forma.shape = box
	forma.position = zona_apertura.get_center()
	zona.add_child(forma)
	add_child(zona)
	zona.body_entered.connect(func(b: Node3D):
		if b is Player:
			apri())
	if lettore and lettore.has_signal(&"sbloccato"):
		lettore.connect(&"sbloccato", apri)
	# Dopo che la sala e gli ambienti tecnici hanno sistemato i materiali.
	_prepara_modello.call_deferred()


## Si alza (e resta su). Con il lettore, solo dopo che ha letto la keycard.
func apri() -> void:
	if lettore and not bool(lettore.get(&"aperto")):
		return
	aperta = true


func should_open() -> bool:
	return aperta or super.should_open()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_aggiorna_modello()


func save_state() -> Dictionary:
	var d := super.save_state()
	d["aperta"] = aperta
	return d


func load_state(data: Dictionary) -> void:
	super.load_state(data)
	aperta = bool(data.get("aperta", false))
	_aggiorna_modello()
	for n in [_lamelle, _barra]:
		if n:
			(n as Node3D).reset_physics_interpolation()


## Toglie lamelle e barra dalla mesh del raccordo e ne fa la serranda che si muove.
func _prepara_modello() -> void:
	var mi := get_node_or_null(modello) as MeshInstance3D
	var src := mi.mesh as ArrayMesh if mi else null
	if src == null:
		push_warning("SerrandaMagazzino: modello della serranda non trovato (%s)" % modello)
		return
	# Dalle coordinate della mesh a quelle della serranda.
	var verso := global_transform.affine_inverse() * mi.global_transform
	var nuova := ArrayMesh.new()
	var lamella: Array = []
	var barra: Array = []
	var materiale_lamelle: Material = null
	var materiale_barra: Material = null
	for s in src.get_surface_count():
		var arr := src.surface_get_arrays(s)
		var mat := mi.get_active_material(s)
		var nome := src.surface_get_material(s).resource_name if src.surface_get_material(s) else ""
		if nome == "ferro_arrugginito" or nome == "strisce_pericolo":
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			var resta := PackedInt32Array()
			var presi := PackedInt32Array()
			for t in range(0, idx.size(), 3):
				if riquadro.has_point(verts[idx[t]]) and riquadro.has_point(verts[idx[t + 1]]) and riquadro.has_point(verts[idx[t + 2]]):
					presi.append_array([idx[t], idx[t + 1], idx[t + 2]])
				else:
					resta.append_array([idx[t], idx[t + 1], idx[t + 2]])
			if not presi.is_empty():
				arr[Mesh.ARRAY_INDEX] = resta
				var pezzo := _sotto_mesh(src.surface_get_arrays(s), presi, verso)
				if nome == "strisce_pericolo":
					barra = pezzo
					materiale_barra = mat
				else:
					lamella = pezzo
					materiale_lamelle = mat
		nuova.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		nuova.surface_set_material(s, src.surface_get_material(s))
		nuova.surface_set_name(s, src.surface_get_name(s))
	if lamella.is_empty():
		push_warning("SerrandaMagazzino: nella mesh %s non ci sono le lamelle" % mi.name)
		return
	mi.mesh = nuova
	# Della pila di lamelle serve solo la più bassa: le altre sono copie, una ogni [member passo].
	var v: PackedVector3Array = lamella[Mesh.ARRAY_VERTEX]
	var basso := INF
	for p in v:
		basso = minf(basso, p.y)
	var una := _solo_sotto(lamella, basso + passo * 0.95)
	var alto := -INF
	for p in (una[Mesh.ARRAY_VERTEX] as PackedVector3Array):
		alto = maxf(alto, p.y)
	_altezza_lamella = alto - basso
	var mesh_lamella := ArrayMesh.new()
	mesh_lamella.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, una)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh_lamella
	mm.instance_count = lamelle
	for k in lamelle:
		mm.set_instance_transform(k, Transform3D(Basis.IDENTITY, Vector3(0.0, k * passo, 0.0)))
	_lamelle = MultiMeshInstance3D.new()
	_lamelle.name = "Lamelle"
	_lamelle.multimesh = mm
	_lamelle.material_override = materiale_lamelle
	_lamelle.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	_lamelle.set_meta(&"base", basso)
	add_child(_lamelle)
	if not barra.is_empty():
		var mesh_barra := ArrayMesh.new()
		mesh_barra.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, barra)
		_barra = MeshInstance3D.new()
		_barra.name = "Barra"
		_barra.mesh = mesh_barra
		_barra.material_override = materiale_barra
		_barra.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
		add_child(_barra)
	_pronta = true
	_aggiorna_modello()


## Le lamelle e la barra dove le porta l'apertura: aperta stanno come le ha modellate il raccordo;
## chiusa scendono di [member open_offset].
func _aggiorna_modello() -> void:
	if not _pronta:
		return
	var giu := -open_offset.y * (1.0 - _ease(open_amount))
	var base := float(_lamelle.get_meta(&"base"))
	var mm := _lamelle.multimesh
	var visibili := 0
	for k in mm.instance_count:
		if base + k * passo + giu + _altezza_lamella <= quota_architrave + 0.001:
			visibili = k + 1
	mm.visible_instance_count = visibili
	# Si spostano i nodi, non le istanze: così l'interpolazione della fisica li fa scorrere lisci.
	_lamelle.position = Vector3(0.0, giu, 0.0)
	if _barra:
		_barra.position = Vector3(0.0, giu, 0.0)


## Quante lamelle si vedono adesso (per i test).
func lamelle_visibili() -> int:
	return _lamelle.multimesh.visible_instance_count if _lamelle else 0


## I triangoli [param tri] (indici) di una superficie, come mesh a sé nelle coordinate della serranda.
static func _sotto_mesh(arr: Array, tri: PackedInt32Array, xf: Transform3D) -> Array:
	var mappa := {}
	var nuovi := PackedInt32Array()
	var ordine := PackedInt32Array()
	for i in tri:
		if not mappa.has(i):
			mappa[i] = ordine.size()
			ordine.append(i)
		nuovi.append(mappa[i])
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	var basis := xf.basis
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var vv := PackedVector3Array()
	for i in ordine:
		vv.append(xf * v[i])
	out[Mesh.ARRAY_VERTEX] = vv
	if arr[Mesh.ARRAY_NORMAL] != null:
		var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var nn := PackedVector3Array()
		for i in ordine:
			nn.append((basis * n[i]).normalized())
		out[Mesh.ARRAY_NORMAL] = nn
	if arr[Mesh.ARRAY_TANGENT] != null:
		var t: PackedFloat32Array = arr[Mesh.ARRAY_TANGENT]
		var tt := PackedFloat32Array()
		for i in ordine:
			var d := (basis * Vector3(t[i * 4], t[i * 4 + 1], t[i * 4 + 2])).normalized()
			tt.append_array([d.x, d.y, d.z, t[i * 4 + 3]])
		out[Mesh.ARRAY_TANGENT] = tt
	for k in [Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]:
		if arr[k] != null:
			var u: PackedVector2Array = arr[k]
			var uu := PackedVector2Array()
			for i in ordine:
				uu.append(u[i])
			out[k] = uu
	if arr[Mesh.ARRAY_COLOR] != null:
		var c: PackedColorArray = arr[Mesh.ARRAY_COLOR]
		var cc := PackedColorArray()
		for i in ordine:
			cc.append(c[i])
		out[Mesh.ARRAY_COLOR] = cc
	out[Mesh.ARRAY_INDEX] = nuovi
	return out


## Solo i triangoli che stanno tutti sotto la quota [param y] (la lamella più bassa).
static func _solo_sotto(arr: Array, y: float) -> Array:
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var tri := PackedInt32Array()
	for t in range(0, idx.size(), 3):
		if v[idx[t]].y < y and v[idx[t + 1]].y < y and v[idx[t + 2]].y < y:
			tri.append_array([idx[t], idx[t + 1], idx[t + 2]])
	return _sotto_mesh(arr, tri, Transform3D.IDENTITY)
