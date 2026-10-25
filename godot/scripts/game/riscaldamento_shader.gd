class_name RiscaldamentoShader
extends Node
## Il riscaldamento degli shader dietro la schermata di caricamento dell'avvio (blocchi al primo avvio, v0.3.14: su un
## PC nuovo, con la cache degli shader vuota, ogni shader nuovo si compila al primo uso sul thread principale; i
## materiali campione delle zone (torre, oblò, Risalita, tunnel) si creavano tutti insieme entrando nella sala o a
## gioco avviato, 100-150 ms l'uno sulla CPU della CI). Qui, mentre la barra della schermata si muove:
## 1. gli shader dei materiali campione si creano uno alla volta, al più [constant MS_PER_FOTOGRAMMA] ms per
##    fotogramma (sempre almeno uno);
## 2. poi gli stessi materiali si disegnano su una sfera in un SubViewport fuori vista, con luci con le ombre e
##    l'ambiente della sala, qualcuno per fotogramma, così anche le loro pipeline finiscono nella cache.
## I materiali restano tenuti per tutta la partita ([member _tenuti]): i loro shader non si ricompilano più quando le
## zone li creano di nuovo. Con la cache già piena tutto dura pochi fotogrammi.

signal finito

## Quanto lavoro per fotogramma (la schermata non deve mai fermarsi più di 100 ms).
const MS_PER_FOTOGRAMMA := 30.0
const RISALITA := "res://scenes/risalita/materiali_campione.tres"
const AMBIENTE := "res://addons/grafica/sala/ambiente_sala.tres"

## I materiali già passati di qui: tenuti per tutta la partita (gli shader vivono finché c'è un materiale).
static var _tenuti: Array[Material] = []

## Quanti materiali in tutto e quanti fatti (shader creati e disegnati).
var totale := 0
var fatti := 0
var concluso := false
var _materiali: Array[Material] = []


func _ready() -> void:
	_materiali = materiali()
	totale = _materiali.size() * 2
	_run.call_deferred()


## Tutti i materiali campione delle zone che si caricano a gioco avviato.
static func materiali() -> Array[Material]:
	var out: Array[Material] = []
	out.append_array(SalaTorre.materiali_campione(false))
	if ResourceLoader.exists(RISALITA):
		for m in load(RISALITA).get_meta(&"materiali", []):
			out.append(m as Material)
	for m in CampioniTunnel.carica(false):
		out.append(m as Material)
	return out


## L'ambiente della sala con le impostazioni grafiche di adesso (come Grafica lo applica nel gioco): la luce globale
## SDFGI e la nebbia volumetrica cambiano le pipeline dei materiali, quindi il riscaldamento le deve avere uguali.
static func ambiente() -> Environment:
	if not ResourceLoader.exists(AMBIENTE):
		return null
	var env := (load(AMBIENTE) as Environment).duplicate() as Environment
	var g: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null(^"Grafica") if Engine.get_main_loop() is SceneTree else null
	if g:
		env.sdfgi_enabled = int(g.call(&"valore", "gi")) == 2
		if env.volumetric_fog_enabled:
			env.volumetric_fog_enabled = int(g.call(&"valore", "nebbia")) > 0
		env.ssr_enabled = env.ssr_enabled and int(g.call(&"valore", "ssr")) > 0
		env.ssao_enabled = env.ssao_enabled and int(g.call(&"valore", "ssao")) > 0
		env.ssil_enabled = env.ssil_enabled and int(g.call(&"valore", "ssil")) > 0
		env.glow_enabled = env.glow_enabled and bool(g.call(&"valore", "glow"))
	return env


## Avanzamento 0..1.
func avanzamento() -> float:
	return 1.0 if totale == 0 else clampf(float(fatti) / totale, 0.0, 1.0)


func _run() -> void:
	# 1. gli shader, uno alla volta
	var i := 0
	while i < _materiali.size():
		var t0 := Time.get_ticks_usec()
		while i < _materiali.size():
			_materiali[i].get_rid()
			_tenuti.append(_materiali[i])
			i += 1
			fatti += 1
			if (Time.get_ticks_usec() - t0) / 1000.0 >= MS_PER_FOTOGRAMMA:
				break
		await get_tree().process_frame
		if not is_inside_tree():
			return
	# 2. le pipeline: i materiali disegnati fuori vista (solo col renderer vero)
	if DisplayServer.get_name() != "headless" and RenderingServer.get_rendering_device() != null:
		await _disegna()
	fatti = totale
	concluso = true
	finito.emit()


## Le impostazioni di [param principale] che cambiano le pipeline (antialiasing, scala e upscaler: con FSR 2 o col
## TAA ci sono i vettori di movimento, che sono pipeline loro; atlante delle ombre), copiate in [param sv]: se no si
## compilano varianti che il gioco non usa e al primo fotogramma vero mancano le sue (draw 8 per lei all'oblò,
## test_riscaldamento_pipeline del 25 ottobre).
static func copia_viewport(sv: SubViewport, principale: Viewport) -> void:
	sv.msaa_3d = principale.msaa_3d
	sv.screen_space_aa = principale.screen_space_aa
	sv.use_taa = principale.use_taa
	sv.use_debanding = principale.use_debanding
	sv.use_hdr_2d = principale.use_hdr_2d
	sv.scaling_3d_mode = principale.scaling_3d_mode
	sv.scaling_3d_scale = principale.scaling_3d_scale
	sv.fsr_sharpness = principale.fsr_sharpness
	sv.anisotropic_filtering_level = principale.anisotropic_filtering_level
	sv.texture_mipmap_bias = principale.texture_mipmap_bias
	sv.positional_shadow_atlas_size = principale.positional_shadow_atlas_size
	sv.positional_shadow_atlas_16_bits = principale.positional_shadow_atlas_16_bits


func _disegna() -> void:
	var sv := SubViewport.new()
	sv.name = "RiscaldamentoShader"
	sv.size = Vector2i(64, 64)
	sv.own_world_3d = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	copia_viewport(sv, get_viewport())
	add_child(sv)
	var amb := ambiente()
	if amb:
		var env := WorldEnvironment.new()
		env.environment = amb
		sv.add_child(env)
	# le luci come nel gioco: col sole, i punti e i faretti con le ombre (le varianti degli shader con le ombre)
	var sole := DirectionalLight3D.new()
	sole.shadow_enabled = true
	sole.rotation_degrees = Vector3(-50, 30, 0)
	sv.add_child(sole)
	var punto := OmniLight3D.new()
	punto.shadow_enabled = true
	punto.position = Vector3(0, 1.5, 1.5)
	sv.add_child(punto)
	var faro := SpotLight3D.new()
	faro.shadow_enabled = true
	faro.position = Vector3(1.5, 1.5, 1.5)
	sv.add_child(faro)
	faro.look_at(Vector3.ZERO)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0, 3)
	sv.add_child(cam)
	cam.current = true
	_luci = [sole, punto, faro]
	var sfera := SphereMesh.new()
	sfera.radial_segments = 8
	sfera.rings = 4
	# un materiale per volta, e per ognuno un passo per fotogramma: prima senza ombre (il colore e la profondità),
	# poi l'ombra di ogni tipo di luce da sola (ogni passo sono pipeline sue: tutte insieme erano 3-10 per materiale,
	# test_riscaldamento_pipeline del 25 ottobre)
	for i in _materiali.size():
		var mi := MeshInstance3D.new()
		mi.mesh = sfera
		mi.material_override = _materiali[i]
		mi.scale = Vector3.ONE * 0.6
		sv.add_child(mi)
		await _passi_ombre()
		if not is_inside_tree():
			return
		mi.queue_free()
		fatti += 1
	# lei dietro gli oblò (mascotte, 25 ottobre) con l'oblò vero: le sue mesh con lo scheletro (le ossa cambiano il
	# formato dei vertici: la sfera non basta) e quelle dell'oblò (piastra, vetro, vasca), un pezzo per volta
	await _disegna_oblo(sv)
	await get_tree().process_frame
	sv.queue_free()


var _luci: Array[Light3D] = []
## Il pezzo dell'oblò che si sta disegnando (per i test: dove cadono le pipeline).
var pezzo := ""


## I passi di un pezzo appena mostrato: un fotogramma senza ombre, poi uno con l'ombra di ogni luce, da sola.
func _passi_ombre() -> void:
	for l in _luci:
		l.shadow_enabled = false
	for k in _luci.size() + 1:
		if k > 0:
			_luci[k - 1].shadow_enabled = true
			if k > 1:
				_luci[k - 2].shadow_enabled = false
		await get_tree().process_frame
		if not is_inside_tree():
			return
	_luci[-1].shadow_enabled = false


## Il modello di lei: crearlo compila insieme tutti i suoi materiali, sul formato dei vertici di ogni sua mesh (ossa e
## blend shape), anche nascosto (32 pipeline in un fotogramma, test_riscaldamento_pipeline del 25 ottobre). Qui prima
## il modello con un materiale neutro, una mesh per volta; poi ogni superficie col suo materiale del GLB e con quelli che
## gli si mettono al suo posto (medusa_<nome>*.tres: asciutta, bagnata), uno per volta: quando lei si crea davvero non
## c'è più niente da compilare. (Lo stesso materiale su tutte le mesh insieme erano 12-28 pipeline per fotogramma.)
const MODELLO_LEI := "res://assets/models/medusa/medusa.glb"
const MATERIALI_LEI := "res://assets/models/medusa/"


func _disegna_modello_lei(sv: SubViewport) -> void:
	var scena := load(MODELLO_LEI) as PackedScene
	if scena == null:
		return
	var tres: Array[Material] = []
	for f in ResourceLoader.list_directory(MATERIALI_LEI):
		if f.ends_with(".tres") and f.begins_with("medusa_"):
			var m := load(MATERIALI_LEI + f) as Material
			if m:
				tres.append(m)
	var modello := scena.instantiate() as Node3D
	var neutro := StandardMaterial3D.new()
	var mesh: Array[MeshInstance3D] = []
	var box := AABB()
	for n in modello.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		for k in mi.mesh.get_surface_count():
			mi.set_surface_override_material(k, neutro)
		mi.visible = false
		mesh.append(mi)
		box = box.merge(mi.get_aabb()) if box.size != Vector3.ZERO else mi.get_aabb()
	# davanti alla camera di prova, piccola: tutta nell'inquadratura e nelle ombre delle luci
	modello.scale = Vector3.ONE * (1.2 / maxf(box.size.length(), 0.01))
	modello.position = -box.get_center() * modello.scale.x
	sv.add_child(modello)
	for mi in mesh:
		mi.visible = true
		pezzo = "lei: %s" % mi.name
		await _passi_ombre()
		if not is_inside_tree():
			return
		for k in mi.mesh.get_surface_count():
			var suo := mi.mesh.surface_get_material(k)
			var prove: Array[Material] = []
			if suo:
				prove.append(suo)
				var nome := suo.resource_name.trim_prefix("M_").split("_")[0]
				for m in tres:
					if m.resource_path.get_file().begins_with("medusa_" + nome):
						prove.append(m)
			for m in prove:
				pezzo = "lei: %s %d %s" % [mi.name, k, m.resource_path.get_file()]
				mi.set_surface_override_material(k, m)
				await _passi_ombre()
				if not is_inside_tree():
					return
			mi.set_surface_override_material(k, neutro)
		mi.visible = false
	pezzo = ""
	modello.queue_free()


func _disegna_oblo(sv: SubViewport) -> void:
	await _disegna_modello_lei(sv)
	if not is_inside_tree():
		return
	var o := ObloLei.new()
	sv.add_child(o)
	o.set_process(false)
	# prima la struttura dell'oblò (le sue mesh e i suoi materiali fatti nel codice), poi lei: insieme erano 16 pipeline
	pezzo = "oblò: struttura"
	await _passi_ombre()
	if not is_inside_tree():
		return
	pezzo = "oblò: lei"
	o._mostra()
	# (il riscaldamento dell'oblò stesso, un SubViewport suo: qui non serve)
	var suo := o.get_node_or_null(^"Riscaldamento") as SubViewport
	if suo:
		suo.render_target_update_mode = SubViewport.UPDATE_DISABLED
	# (la luce rosa di lei fa le stesse ombre della luce di prova: spenta, i passi delle ombre li fanno le luci di prova)
	for l in o.find_children("*", "Light3D", true, false):
		(l as Light3D).visible = false
	var pezzi: Array[GeometryInstance3D] = []
	for g in o.find_children("*", "GeometryInstance3D", true, false):
		var gi := g as GeometryInstance3D
		if gi.visible:
			pezzi.append(gi)
			gi.visible = false
	await get_tree().process_frame
	for gi in pezzi:
		if not is_instance_valid(gi):
			continue
		gi.visible = true
		pezzo = "%s (%s)" % [gi.name, gi.get_class()]
		await _passi_ombre()
		if not is_inside_tree():
			return
		if is_instance_valid(gi):
			gi.visible = false
	o.queue_free()


## Disegna una zona appena costruita una volta fuori vista (una camera sua in un SubViewport con le stesse
## impostazioni di [param principale] e lo stesso mondo), così il motore compila adesso le pipeline dei suoi
## materiali e al primo fotogramma vero non si ferma. Intanto la zona sta su uno strato che la camera del gioco non
## disegna, e le sue luci illuminano solo quello; alla fine torna com'era (nascosta, se lo era). Era
## SalaTorre.prepara_materiali; la usa anche la Risalita.
static func disegna_fuori_vista(radice: Node3D, principale: Viewport, fotogrammi := 4) -> void:
	if principale == null or not radice.is_inside_tree():
		return
	var visuali := radice.find_children("*", "VisualInstance3D", true, false)
	var aabb := AABB()
	var primo := true
	var strati := {}
	var maschere := {}
	for v in visuali:
		var vi := v as VisualInstance3D
		strati[vi] = vi.layers
		vi.layers = SalaTorre.STRATO_PREPARA
		if vi is Light3D:
			maschere[vi] = (vi as Light3D).light_cull_mask
			(vi as Light3D).light_cull_mask = SalaTorre.STRATO_PREPARA
		elif vi is GeometryInstance3D:
			var box := vi.global_transform * vi.get_aabb()
			aabb = box if primo else aabb.merge(box)
			primo = false
	var era_visibile := radice.visible
	radice.visible = true
	var sv := SubViewport.new()
	sv.name = "PreparaMateriali"
	sv.size = Vector2i(320, 180)
	copia_viewport(sv, principale)
	sv.world_3d = principale.find_world_3d()
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var cam := Camera3D.new()
	cam.cull_mask = SalaTorre.STRATO_PREPARA
	cam.fov = 100.0
	cam.far = 500.0
	sv.add_child(cam)
	radice.add_child(sv)
	var centro := aabb.get_center()
	var raggio := aabb.size.length() * 0.5
	# da fuori, guardando il centro: tutta la sala nell'inquadratura (niente scartato dal frustum)
	cam.look_at_from_position(centro + Vector3(0.6, 0.5, 0.8).normalized() * raggio * 1.3, centro, Vector3.UP)
	cam.current = true
	# a fotogrammi del gioco (frame_post_draw senza renderer, nei test headless, non arriva)
	for i in fotogrammi + 1:
		await radice.get_tree().process_frame
		if not radice.is_inside_tree():
			break
	sv.queue_free()
	for vi in strati:
		if is_instance_valid(vi):
			(vi as VisualInstance3D).layers = strati[vi]
	for l in maschere:
		if is_instance_valid(l):
			(l as Light3D).light_cull_mask = maschere[l]
	radice.visible = era_visibile



## Come [method disegna_fuori_vista], ma un pezzo (GeometryInstance3D) per volta: [param radice] (per esempio lei
## dietro un oblò, creata nascosta mentre la sua zona si costruisce a pezzi) si disegna fuori vista nel mondo della
## sua zona (con la sua luce globale, la sua nebbia e le sue luci), un pezzo ogni [param fotogrammi] fotogrammi, così
## le pipeline si compilano poche per volta e quando la si mostra davvero non se ne compila nessuna. Alla fine tutto
## torna com'era (nascosto, se lo era).
static func disegna_a_pezzi(radice: Node3D, principale: Viewport, fotogrammi := 2) -> void:
	if principale == null or not radice.is_inside_tree():
		return
	var pezzi: Array[GeometryInstance3D] = []
	var accesi := {}
	for g in radice.find_children("*", "GeometryInstance3D", true, false):
		var gi := g as GeometryInstance3D
		accesi[gi] = gi.visible
		if gi.visible:
			pezzi.append(gi)
		gi.visible = false
	# lo strato fuori vista e la camera, come disegna_fuori_vista; poi un pezzo per volta
	var finito := [false]
	var prepara := func() -> void:
		# (ogni pezzo sta 1 + fotogrammi fotogrammi, poi tutti insieme: la camera fuori vista resta finché non si finisce;
		# prima durava meno e gli ultimi pezzi non si disegnavano: 8 "draw" quando lei compariva davvero)
		await disegna_fuori_vista(radice, principale, (fotogrammi + 1) * (pezzi.size() + 1) + 2)
		finito[0] = true
	prepara.call()
	for gi in pezzi:
		await radice.get_tree().process_frame
		if not is_instance_valid(radice) or not radice.is_inside_tree():
			return
		if is_instance_valid(gi):
			gi.visible = true
		for i in fotogrammi:
			await radice.get_tree().process_frame
		if is_instance_valid(gi):
			gi.visible = false
	# e alla fine tutti insieme, come quando compare davvero: un pezzo per volta, lei mostrata intera compilava ancora
	# 8 "draw" al primo fotogramma (test_riscaldamento_pipeline del 25 ottobre)
	for gi in pezzi:
		if is_instance_valid(gi):
			gi.visible = true
	for i in fotogrammi + 1:
		await radice.get_tree().process_frame
	if not is_instance_valid(radice) or not radice.is_inside_tree():
		return
	for gi in pezzi:
		if is_instance_valid(gi):
			gi.visible = false
	while not finito[0] and is_instance_valid(radice) and radice.is_inside_tree():
		await radice.get_tree().process_frame
	for gi in accesi:
		if is_instance_valid(gi):
			(gi as GeometryInstance3D).visible = accesi[gi]
