extends Node
## Cosa porta in memoria la sala principale (per confrontare due versioni: la crescita della v0.3.9 su
## llvmpipe). Istanzia la sala (headless, senza disegnarla) e, per ogni figlio diretto, conta: mesh, superfici,
## materiali unici, shader unici (quelli che diventano pipeline da compilare), luci, texture uniche e i loro
## MB (dimensione delle immagini, mipmap comprese circa x1,33), triangoli. Stampa anche i totali e le scene
## caricate a parte (sala della torre, inseguimento) se ci sono.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/misura_sala_contenuto.gd

const LEVEL := "res://scenes/sala_principale.tscn"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	var level := (load(LEVEL) as PackedScene).instantiate()
	var totale := _nuovo()
	print("parte | mesh | superfici | materiali | shader | luci | texture | MB texture | triangoli (k)")
	for c in level.get_children():
		var d := _nuovo()
		_conta(c, d)
		_somma(totale, d)
		if d.mesh > 0 or d.luci > 0:
			_stampa(String(c.name), d)
	_stampa("TOTALE", totale)
	print("memoria statica: %.2f GB" % (OS.get_static_memory_usage() / 1e9))
	level.free()
	get_tree().quit()


func _nuovo() -> Dictionary:
	return {mesh = 0, superfici = 0, materiali = {}, shader = {}, luci = 0, texture = {}, triangoli = 0}


func _somma(a: Dictionary, b: Dictionary) -> void:
	a.mesh += b.mesh
	a.superfici += b.superfici
	a.luci += b.luci
	a.triangoli += b.triangoli
	a.materiali.merge(b.materiali)
	a.shader.merge(b.shader)
	a.texture.merge(b.texture)


func _stampa(nome: String, d: Dictionary) -> void:
	var mb := 0.0
	for t in d.texture:
		mb += float(d.texture[t])
	print("%s | %d | %d | %d | %d | %d | %d | %.0f | %.0f" % [nome, d.mesh, d.superfici, d.materiali.size(),
		d.shader.size(), d.luci, d.texture.size(), mb, d.triangoli / 1000.0])


func _conta(n: Node, d: Dictionary) -> void:
	if n is Light3D:
		d.luci += 1
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var mi := n as MeshInstance3D
		d.mesh += 1
		for s in mi.mesh.get_surface_count():
			d.superfici += 1
			var arr := mi.mesh.surface_get_arrays(s) if mi.mesh is ArrayMesh else []
			if arr.size() > Mesh.ARRAY_INDEX and arr[Mesh.ARRAY_INDEX] != null:
				d.triangoli += (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
			var m: Material = mi.get_active_material(s)
			if m:
				_materiale(m, d)
	if n is GPUParticles3D and (n as GPUParticles3D).process_material:
		_materiale((n as GPUParticles3D).process_material, d)
	for c in n.get_children():
		_conta(c, d)


func _materiale(m: Material, d: Dictionary) -> void:
	d.materiali[m.get_instance_id()] = true
	if m is ShaderMaterial and (m as ShaderMaterial).shader:
		d.shader[(m as ShaderMaterial).shader.resource_path + str((m as ShaderMaterial).shader.get_instance_id())] = true
	elif m is BaseMaterial3D:
		# un BaseMaterial3D è uno shader per ogni combinazione di funzioni accese
		d.shader[_firma(m as BaseMaterial3D)] = true
		for p in ["albedo_texture", "normal_texture", "roughness_texture", "metallic_texture", "orm_texture",
				"emission_texture", "ao_texture", "detail_albedo"]:
			var t = m.get(p)
			if t is Texture2D:
				var tx := t as Texture2D
				d.texture[tx.get_instance_id()] = tx.get_width() * tx.get_height() * 4 * 1.33 / 1e6
	if m.next_pass:
		_materiale(m.next_pass, d)


func _firma(m: BaseMaterial3D) -> String:
	var f := []
	for i in BaseMaterial3D.FEATURE_MAX:
		f.append(int(m.get_feature(i)))
	f.append(m.transparency)
	f.append(m.shading_mode)
	f.append(m.cull_mode)
	f.append(int(m.vertex_color_use_as_albedo))
	f.append(m.texture_filter)
	f.append(int(m is ORMMaterial3D))
	return "std:" + str(f)
