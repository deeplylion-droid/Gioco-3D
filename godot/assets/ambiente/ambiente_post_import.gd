@tool
extends EditorScenePostImport
## Script di post-import per i GLB dell'ambiente (assets_src/ambiente/glb/...).
## In Godot: seleziona il GLB > Import > Import Script = questo file > Reimport.
## Sistema i materiali che l'importer glTF non imposta da solo:
##  - M_amb_*: il colore dei vertici (sporco, umidità in basso) moltiplica l'albedo;
##  - M_amb_alfa_* (grigliati, rosa dei venti): alpha scissor, doppia faccia;
##  - vetri: trasparenza alpha, doppia faccia;
##  - pozzanghere: lucidissime (con SSR riflettono);
##  - neon, luci rosse, lampadina, insegna: emissione più forte (per il glow).

func _post_import(scene: Node) -> Object:
	_visita(scene)
	return scene


func _visita(n: Node) -> void:
	if n is MeshInstance3D:
		var mesh: Mesh = (n as MeshInstance3D).mesh
		if mesh:
			for i in mesh.get_surface_count():
				var m := mesh.surface_get_material(i)
				if m is StandardMaterial3D:
					_sistema(m as StandardMaterial3D)
	for c in n.get_children():
		_visita(c)


func _sistema(m: StandardMaterial3D) -> void:
	var nome := m.resource_name
	if not nome.begins_with("M_amb_"):
		return
	m.vertex_color_use_as_albedo = true
	if nome.begins_with("M_amb_alfa_"):
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
		m.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	elif nome.begins_with("M_amb_decal_"):
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	elif nome.begins_with("M_amb_vetro"):
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	elif nome == "M_amb_pozzanghera":
		m.roughness = 0.02
		m.metallic_specular = 0.7
	elif nome in ["M_amb_neon", "M_amb_luce_rossa", "M_amb_lampadina", "M_amb_neon_rosa"]:
		m.emission_enabled = true
		m.emission_energy_multiplier = maxf(m.emission_energy_multiplier, 4.0)
	elif nome.begins_with("M_amb_gioco") or nome.begins_with("M_amb_scivolo"):
		m.cull_mode = BaseMaterial3D.CULL_DISABLED  # mezze canne e tettoie si vedono da sotto
