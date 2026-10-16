extends SceneTree
## Per ogni texture usata dai modelli della sala (e degli interni) calcola la risoluzione che
## serve davvero, dalla grandezza degli oggetti che la usano: un oggetto di 30 cm non ha bisogno
## di una texture 2K. Scrive un JSON {percorso texture: lato massimo} per tools/godot_vram_textures.py.
## Headless: godot --headless --path godot --script res://tests/dimensioni_texture.gd -- <file.json>
## La densità di riferimento è TEXEL_PER_METRO (da vicino, con la torcia, resta nitida).

const TEXEL_PER_METRO := 1024.0
const MINIMO := 256
const SCENE := [
	"res://assets/ambiente/sala/sala_architettura.glb", "res://assets/ambiente/sala/sala_cupola.glb",
	"res://assets/ambiente/sala/sala_piscina.glb", "res://assets/ambiente/sala/sala_area_bimbi.glb",
	"res://assets/ambiente/sala/sala_torre_scivoli.glb", "res://assets/ambiente/sala/sala_oggetti.glb",
	"res://assets/ambiente/sala/sala_interattivi.glb", "res://assets/ambiente/sala/sala_monumento.glb",
]

var _massimo := {}   # percorso texture -> lato dell'oggetto più grande che la usa (m)
var _ripetuta := {}  # percorso texture -> true se le UV escono da 0..1 (texture ripetuta)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://dimensioni_texture.json"
	for path in SCENE:
		var ps := load(path) as PackedScene
		if ps == null:
			continue
		var inst := ps.instantiate()
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			_mesh(mi as MeshInstance3D, inst)
		inst.free()
	var risultato := {}
	var risparmio := 0
	for t in _massimo:
		var tex := load(t) as Texture2D
		if tex == null:
			continue
		var lato := maxi(tex.get_width(), tex.get_height())
		var serve := MINIMO
		if _ripetuta.has(t):
			serve = lato    # texture ripetute (pavimenti, muri): non si toccano
		else:
			while serve < lato and serve < _massimo[t] * TEXEL_PER_METRO:
				serve *= 2
		if serve < lato:
			risultato[t] = serve
			risparmio += lato * lato - serve * serve
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify(risultato, "\t", true))
	f.close()
	print("DIMENSIONI %d texture ridotte su %d, pixel risparmiati %.1f M -> %s" % [risultato.size(), _massimo.size(), risparmio / 1e6, out])
	quit()


func _mesh(mi: MeshInstance3D, root: Node) -> void:
	if mi.mesh == null:
		return
	# Grandezza dell'oggetto nel mondo (il lato più lungo del suo riquadro).
	var xf := Transform3D.IDENTITY
	var n: Node = mi
	while n and n != root:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	var box := xf * mi.get_aabb()
	var lato := maxf(box.size.x, maxf(box.size.y, box.size.z))
	for s in mi.mesh.get_surface_count():
		var m := mi.get_surface_override_material(s)
		if m == null:
			m = mi.mesh.surface_get_material(s)
		var b := m as BaseMaterial3D
		if b == null:
			continue
		var ripetuta := _uv_fuori(mi.mesh, s)
		for tex in [b.albedo_texture, b.normal_texture, b.roughness_texture, b.metallic_texture,
				b.ao_texture, b.emission_texture]:
			if tex and (tex as Texture2D).resource_path != "":
				var p: String = (tex as Texture2D).resource_path
				_massimo[p] = maxf(float(_massimo.get(p, 0.0)), lato)
				if ripetuta:
					_ripetuta[p] = true


## Vero se le UV della superficie escono parecchio da 0..1 (la texture si ripete).
static func _uv_fuori(mesh: Mesh, s: int) -> bool:
	var arr := mesh.surface_get_arrays(s)
	if arr.size() <= Mesh.ARRAY_TEX_UV or arr[Mesh.ARRAY_TEX_UV] == null:
		return false
	var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	for i in range(0, uv.size(), maxi(1, uv.size() / 500)):
		var v := uv[i]
		if v.x < -0.05 or v.x > 1.05 or v.y < -0.05 or v.y > 1.05:
			return true
	return false
