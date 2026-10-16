class_name UnificaMateriali
extends RefCounted
## Riduce le varianti di shader dei materiali importati senza cambiarne l'aspetto.
## Ogni combinazione diversa di caratteristiche di un BaseMaterial3D (quali texture usa, mappa
## normale sì o no, canali di ruvidità e metallo...) diventa uno shader diverso, e ogni shader
## diventa decine di pipeline: sul renderer software sono gigabyte. Qui i materiali opachi
## "semplici" ricevono le texture che mancano in versione neutra (albedo bianco 1x1, normale
## piatta, ruvidità e metallo a 1 che moltiplicano i valori del materiale): il risultato a
## schermo è lo stesso, ma molti materiali finiscono sullo stesso shader.

static var _bianca: Texture2D
static var _normale: Texture2D


## Applica a tutte le mesh sotto [param root]. Restituisce quanti materiali ha cambiato.
static func unifica(root: Node) -> int:
	var fatti := {}
	var nodi: Array = root.find_children("*", "GeometryInstance3D", true, false)
	if root is GeometryInstance3D:
		nodi.append(root)
	for g in nodi:
		var mesh: Mesh = null
		if g is MeshInstance3D:
			mesh = (g as MeshInstance3D).mesh
			for s in (g as MeshInstance3D).get_surface_override_material_count():
				_unifica_materiale((g as MeshInstance3D).get_surface_override_material(s), fatti)
		elif g is MultiMeshInstance3D and (g as MultiMeshInstance3D).multimesh:
			mesh = (g as MultiMeshInstance3D).multimesh.mesh
		_unifica_materiale((g as GeometryInstance3D).material_override, fatti)
		if mesh:
			for s in mesh.get_surface_count():
				_unifica_materiale(mesh.surface_get_material(s), fatti)
	return fatti.size()


static func _unifica_materiale(m: Material, fatti: Dictionary) -> void:
	var b := m as BaseMaterial3D
	if b == null or fatti.has(b) or not _semplice(b):
		return
	fatti[b] = true
	if b.albedo_texture == null:
		b.albedo_texture = _tex_bianca()
	if not b.normal_enabled or b.normal_texture == null:
		b.normal_enabled = true
		b.normal_texture = _tex_normale()
	# Ruvidità e metallo da una texture ORM (canali G e B, come i materiali importati da glTF):
	# se non ce l'ha, una texture bianca fa restare i valori del materiale.
	if b.roughness_texture == null and b.metallic_texture == null:
		b.roughness_texture = _tex_bianca()
		b.metallic_texture = _tex_bianca()
		b.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		b.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE


## Solo i materiali "normali": niente effetti speciali che cambierebbero con le texture neutre.
static func _semplice(b: BaseMaterial3D) -> bool:
	if b.emission_enabled or b.refraction_enabled or b.subsurf_scatter_enabled or b.clearcoat_enabled:
		return false
	if b.rim_enabled or b.anisotropy_enabled or b.heightmap_enabled or b.detail_enabled or b.backlight_enabled:
		return false
	if b.uv1_triplanar or b.uv2_triplanar or b.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED:
		return false
	if b.shading_mode != BaseMaterial3D.SHADING_MODE_PER_PIXEL:
		return false
	# Ruvidità o metallo da un canale diverso da G/B: la texture neutra va bene lo stesso, ma
	# non si cambia un canale già scelto per una texture vera.
	if b.roughness_texture and b.roughness_texture_channel != BaseMaterial3D.TEXTURE_CHANNEL_GREEN:
		return false
	if b.metallic_texture and b.metallic_texture_channel != BaseMaterial3D.TEXTURE_CHANNEL_BLUE:
		return false
	return true


static func _tex_bianca() -> Texture2D:
	if _bianca == null:
		var img := Image.create_empty(4, 4, true, Image.FORMAT_RGBA8)
		img.fill(Color(1, 1, 1, 1))
		img.generate_mipmaps()
		_bianca = ImageTexture.create_from_image(img)
	return _bianca


static func _tex_normale() -> Texture2D:
	if _normale == null:
		var img := Image.create_empty(4, 4, true, Image.FORMAT_RGBA8)
		img.fill(Color(0.5, 0.5, 1.0, 1.0))
		img.generate_mipmaps()
		_normale = ImageTexture.create_from_image(img)
	return _normale
