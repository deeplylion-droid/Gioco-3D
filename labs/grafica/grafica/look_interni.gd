class_name LookInterni
extends Node3D
## Look degli interni (corridoio del risveglio, spogliatoi, stanzino): luci a pozze,
## illuminazione globale per stanza, Environment proprio quando la camera è dentro.
## Va messo come figlio della scena degli interni (scenes/interni/luci_interni.tscn),
## separato dai modelli: chi rifà modelli e texture non tocca le luci.
##
## Cosa fa all'avvio (dopo che interni.gd ha creato i Neon e le LuceEmergenza):
## - regola per nome le luci: rosse d'emergenza più raccolte (pozze di rosso, non pareti
##   tutte rosse), neon freddi che fanno le pozze di luce, la lampada calda dello zaino;
## - crea un VoxelGI per stanza, con i dati cotti in [member cartella_gi] se ci sono;
## - quando la camera è dentro gli interni le dà [member ambiente] e [member attributi]
##   (in gioco gli interni stanno dentro la sala, che ha un Environment diverso).

@export var ambiente: Environment = preload("res://grafica/interni/ambiente_interni.tres")
@export var attributi: CameraAttributesPractical = preload("res://grafica/interni/attributi_interni.tres")
## Nodo con i modelli delle stanze (figli diretti = stanze), relativo al genitore.
@export var percorso_ambienti := NodePath("Ambienti")
## Dove stanno i dati del VoxelGI cotti (uno per stanza: <nome stanza>.res).
@export_dir var cartella_gi := ""
@export var crea_gi := true
## Se vero il GI si cuoce anche con la luce delle superfici emissive (lampade, neon): più
## luce rimbalzata, come nella versione approvata. Se falso le lampade spente al buio non
## lasciano luce cotta (serve una seconda cottura per i blackout).
@export var gi_con_emissioni := true
@export_group("Luci")
@export var energia_emergenza := 2.8
@export var portata_emergenza := 4.2
@export var colore_emergenza := Color(1.0, 0.05, 0.03)
@export var energia_neon := 6.0   # circa la luce di prima (luce del neon + luce ad area doppia)
## Eccezioni per singolo neon (nome del nodo -> energia). Lo stanzino ha il soffitto basso
## e chiaro, vicino al tubo: con l'energia piena era il 18% più chiaro della versione approvata.
@export var energia_neon_per_nome := {&"neon_stanzino_neon": 4.8}
@export var portata_neon := 7.5
@export var colore_neon := Color(0.76, 0.98, 0.9)
@export var energia_zaino := 2.6

var _ambienti: Node3D
var _zona := AABB()
var _dentro := false
var _cam_env_prima: Environment
var _cam_attr_prima: CameraAttributes


func _ready() -> void:
	_ambienti = get_parent().get_node_or_null(percorso_ambienti) as Node3D
	# Le luci le crea interni.gd nel suo _ready, che arriva dopo quello dei figli.
	_prepara.call_deferred()


func _prepara() -> void:
	if _ambienti == null:
		push_warning("LookInterni: non trovo %s" % percorso_ambienti)
		return
	_regola_luci()
	_libera_luci_dalle_plafoniere()
	_pozze_nello_shader()
	for stanza in _ambienti.get_children():
		if stanza is Node3D:
			var box := _aabb(stanza)
			_zona = box if _zona.size == Vector3.ZERO else _zona.merge(box)
			if crea_gi:
				_crea_gi(stanza, box)
	_zona = _zona.grow(0.3)


func _regola_luci() -> void:
	var radice := get_parent()
	for n in radice.find_children("*", "Node3D", true, false):
		var nome := String(n.name)
		var cls: String = n.get_script().get_global_name() if n.get_script() else ""
		if cls == "LuceEmergenza":
			# Pozze di rosso raccolte attorno alla lampada: il resto della parete resta buio.
			n.set(&"colore", colore_emergenza)
			n.set(&"energia", energia_emergenza)
			n.set(&"portata", portata_emergenza)
			n.set(&"energia_nebbia", 0.7)
			for l in n.find_children("*", "OmniLight3D", true, false):
				var o := l as OmniLight3D
				o.light_color = colore_emergenza
				o.light_energy = energia_emergenza
				o.omni_range = portata_emergenza
				o.omni_attenuation = 1.8
				o.light_specular = 0.5
		elif cls == "Neon":
			# I neon fanno la luce "di lavoro": freddi, morbidi, con ombre.
			for l in n.find_children("*", "Light3D", true, false):
				var luce := l as Light3D
				luce.light_color = colore_neon
				luce.light_energy = energia_neon_per_nome.get(n.name, energia_neon)
				luce.light_volumetric_fog_energy = 0.25
				luce.shadow_enabled = true
				luce.shadow_blur = 1.5
				if luce is OmniLight3D:
					(luce as OmniLight3D).omni_range = portata_neon
					(luce as OmniLight3D).omni_attenuation = 1.4
			# Neon salva le energie iniziali in _ready: le aggiorniamo.
			var energie: Array[float] = []
			for l in n.find_children("*", "Light3D", true, false):
				energie.append((l as Light3D).light_energy)
			n.set(&"_energie", energie)
		elif nome == "LuceZaino" and n is SpotLight3D:
			# L'unica luce calda: lo zaino si fa notare.
			var s := n as SpotLight3D
			s.light_color = Color(1.0, 0.72, 0.42)
			s.light_energy = energia_zaino
			s.light_size = 0.08
			s.shadow_enabled = true
			s.light_volumetric_fog_energy = 0.6


## Le plafoniere dei modelli (cassa del neon, gabbia delle luci rosse) racchiudono la loro
## luce: se fanno ombra la spengono (stanzino quasi nero). Non fanno ombra alla loro luce e
## la luce del neon scende appena sotto la cassa.
func _libera_luci_dalle_plafoniere() -> void:
	var meshes := _ambienti.find_children("*", "MeshInstance3D", true, false)
	for l in get_parent().find_children("*", "Light3D", true, false):
		var luce := l as Light3D
		if not luce.visible or luce is DirectionalLight3D:
			continue
		var p := luce.global_position
		var fondo := INF
		for m in meshes:
			var mi := m as MeshInstance3D
			if mi.mesh == null:
				continue
			var b := mi.global_transform * mi.get_aabb()
			if b.size.length() < 4.0 and b.grow(0.12).has_point(p):
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				fondo = minf(fondo, b.position.y)
		var neon := luce.get_parent()
		if fondo < INF and neon and neon.get_script() and String(neon.get_script().get_global_name()) == "Neon":
			luce.global_position.y = minf(p.y, fondo - 0.06)
			_sotto_il_soffitto(neon as Node3D, luce, fondo, meshes)


## Se il soffitto (mesh grande della stanza) passa sotto la plafoniera del neon, la luce
## resta chiusa sopra il controsoffitto: plafoniera e neon scendono finché la cima della
## plafoniera tocca il soffitto da sotto.
func _sotto_il_soffitto(neon: Node3D, luce: Light3D, _fondo: float, meshes: Array) -> void:
	var p := luce.global_position
	var plafoniere: Array[Node3D] = []
	var cima := -INF
	var grandi: Array[MeshInstance3D] = []
	for m in meshes:
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		var b := mi.global_transform * mi.get_aabb()
		if b.size.length() < 4.0:
			# I pezzi della plafoniera: sopra la luce, a meno di 30 cm.
			if b.grow(0.05).has_point(Vector3(p.x, b.get_center().y, p.z)) and b.position.y > p.y - 0.05 and b.position.y < p.y + 0.3:
				if not neon.is_ancestor_of(mi):
					plafoniere.append(mi)
				cima = maxf(cima, b.end.y)
		elif b.position.x <= p.x and p.x <= b.end.x and b.position.z <= p.z and p.z <= b.end.z:
			grandi.append(mi)
	if cima == -INF:
		return
	# Primo soffitto sopra un punto 30 cm sotto la luce (raggio verso l'alto).
	var soffitto := INF
	var da := Vector3(p.x, p.y - 0.3, p.z)
	for mi in grandi:
		var f := mi.mesh.get_faces()
		var xf := mi.global_transform
		for i in range(0, f.size(), 3):
			var hit: Variant = Geometry3D.ray_intersects_triangle(da, Vector3.UP, xf * f[i], xf * f[i + 1], xf * f[i + 2])
			if hit != null and (hit as Vector3).y < soffitto:
				soffitto = (hit as Vector3).y
	if soffitto == INF or soffitto >= cima:
		return   # la plafoniera è già sotto il soffitto
	var giu := cima - soffitto + 0.005
	neon.global_position.y -= giu
	for pl in plafoniere:
		pl.global_position.y -= giu
	print_verbose("LookInterni: %s abbassato di %.2f m sotto il soffitto" % [neon.name, giu])


## Le pozze d'acqua diventano parte dello shader del pavimento (piastrelle.gdshader): una
## maschera vista dall'alto con le forme dei piani delle pozze. Nell'acqua le piastrelle si
## vedono, le fughe si riempiono e gli SSR riflettono la scena; i piani si nascondono.
func _pozze_nello_shader() -> void:
	var pozze := _ambienti.find_children("acqua_pozz*", "MeshInstance3D", true, false)
	if pozze.is_empty():
		return
	var area := AABB()
	for p in pozze:
		var b := (p as MeshInstance3D).global_transform * (p as MeshInstance3D).get_aabb()
		area = b if area.size == Vector3.ZERO else area.merge(b)
	area = area.grow(0.5)
	const PASSO := 0.05   # 5 cm per pixel
	var w := int(ceil(area.size.x / PASSO))
	var h := int(ceil(area.size.z / PASSO))
	var img := Image.create_empty(w, h, false, Image.FORMAT_L8)
	for p in pozze:
		var mi := p as MeshInstance3D
		var xf := mi.global_transform
		var f := mi.mesh.get_faces()
		for i in range(0, f.size(), 3):
			var a := _px(xf * f[i], area, PASSO)
			var b := _px(xf * f[i + 1], area, PASSO)
			var c := _px(xf * f[i + 2], area, PASSO)
			_triangolo(img, a, b, c)
		mi.visible = false
	# Bordi morbidi: rimpicciolire e ingrandire fa da sfocatura.
	img.resize(maxi(w / 4, 1), maxi(h / 4, 1), Image.INTERPOLATE_BILINEAR)
	img.resize(w, h, Image.INTERPOLATE_CUBIC)
	var tex := ImageTexture.create_from_image(img)
	var rett := Vector4(area.position.x, area.position.z, area.size.x, area.size.z)
	for n in _ambienti.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		for s in mi.mesh.get_surface_count() if mi.mesh else 0:
			var m := mi.get_active_material(s)
			if m is ShaderMaterial and (m as ShaderMaterial).shader and \
					(m as ShaderMaterial).shader.resource_path.ends_with("piastrelle.gdshader"):
				(m as ShaderMaterial).set_shader_parameter("maschera_pozze", tex)
				(m as ShaderMaterial).set_shader_parameter("rettangolo_pozze", rett)


static func _px(v: Vector3, area: AABB, passo: float) -> Vector2:
	return Vector2((v.x - area.position.x) / passo, (v.z - area.position.z) / passo)


static func _triangolo(img: Image, a: Vector2, b: Vector2, c: Vector2) -> void:
	var minx := maxi(int(floor(minf(a.x, minf(b.x, c.x)))), 0)
	var maxx := mini(int(ceil(maxf(a.x, maxf(b.x, c.x)))), img.get_width() - 1)
	var miny := maxi(int(floor(minf(a.y, minf(b.y, c.y)))), 0)
	var maxy := mini(int(ceil(maxf(a.y, maxf(b.y, c.y)))), img.get_height() - 1)
	for y in range(miny, maxy + 1):
		for x in range(minx, maxx + 1):
			if Geometry2D.point_is_inside_triangle(Vector2(x + 0.5, y + 0.5), a, b, c):
				img.set_pixel(x, y, Color.WHITE)


func _crea_gi(stanza: Node3D, box: AABB) -> void:
	var gi := VoxelGI.new()
	gi.name = "GI_" + stanza.name
	gi.size = box.size + Vector3.ONE * 0.4
	gi.subdiv = VoxelGI.SUBDIV_128
	var file := cartella_gi.path_join(String(stanza.name) + ".res")
	if cartella_gi != "" and ResourceLoader.exists(file):
		gi.data = load(file)
		gi.set_meta("grafica_bake_automatico", false)
	gi.set_meta("stanza", stanza)
	if gi.data == null:
		gi.set_meta("grafica_bake_automatico", false)  # il bake generico cercherebbe nei figli sbagliati
	add_child(gi)
	gi.global_position = box.get_center()
	if gi.data == null and is_instance_valid(Grafica) and int(Grafica.valore("gi")) == 1:
		gi.bake(stanza)  # senza dati cotti: calcolo all'avvio (lento, solo per le prove)


## Calcola i dati del VoxelGI di ogni stanza e li salva in cartella_gi (da lanciare una
## volta, a luci a posto; vedi tests/cuoci_gi_interni.gd).
func cuoci_gi() -> void:
	DirAccess.make_dir_recursive_absolute(cartella_gi)
	# Le lampade emissive non vanno "cotte" nel GI: la loro luce la fanno le Light3D, che
	# il VoxelGI segue in tempo reale. Cotte, resterebbero accese anche al buio.
	var spente := [] if gi_con_emissioni else LookInterni.spegni_emissioni(get_parent())
	for gi in find_children("GI_*", "VoxelGI", false, false):
		var v := gi as VoxelGI
		v.bake(v.get_meta("stanza"))   # la geometria sta nella stanza, non tra i figli di LookInterni
		var file := cartella_gi.path_join(String(v.name).trim_prefix("GI_") + ".res")
		print("GI ", v.name, " celle ", v.data.get_octree_cells().size(), " dati ", v.data.get_data_cells().size(),
			" -> ", file, " ", ResourceSaver.save(v.data, file))
	LookInterni.ripristina_emissioni(spente)


## Toglie l'emissione a tutte le superfici emissive sotto [param radice]; restituisce cosa
## ripristinare con [method ripristina_emissioni]. Serve per cuocere il GI senza la luce
## delle lampade (la fanno le Light3D) e per gli scatti "al buio".
static func spegni_emissioni(radice: Node) -> Array:
	var fatte := []
	for n in radice.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(i)
			if mat is BaseMaterial3D and (mat as BaseMaterial3D).emission_enabled:
				var copia := mat.duplicate() as BaseMaterial3D
				copia.emission_enabled = false
				fatte.append([mi, i, mi.get_surface_override_material(i)])
				mi.set_surface_override_material(i, copia)
	return fatte


static func ripristina_emissioni(fatte: Array) -> void:
	for f in fatte:
		(f[0] as MeshInstance3D).set_surface_override_material(f[1], f[2])


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or _zona.size == Vector3.ZERO:
		return
	var dentro := _zona.has_point(cam.global_position)
	if dentro == _dentro:
		return
	_dentro = dentro
	if dentro:
		_cam_env_prima = cam.environment
		_cam_attr_prima = cam.attributes
		cam.environment = ambiente
		cam.attributes = attributi
	else:
		cam.environment = _cam_env_prima
		cam.attributes = _cam_attr_prima
	if is_instance_valid(Grafica):
		Grafica.aggiorna_environment()


static func _aabb(n: Node3D) -> AABB:
	var box := AABB()
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var b := m.global_transform * m.get_aabb()
		box = b if box.size == Vector3.ZERO else box.merge(b)
	return box
