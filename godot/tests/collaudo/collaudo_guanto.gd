extends Node
## Collaudo del guanto sulla lancia (0.3.22, enigmi; il guanto l'ha fatto ambienti-1). Livello di prova, camera del
## giocatore. Tre parti, scelte dal secondo argomento ("occhi,vicino,scene"):
##  - occhi: in 4 formati (16:9, 16:10, 21:9, 4:3) e 3 campi visivi (50°, 62° predefinito, 90°), in ogni stato
##    (fermo, camminando, correndo, carica, sparo, aspirando, accovacciato, salto e atterraggio, su per una scala e una
##    scaletta, in acqua e nel guado, tutto in su e tutto in giù, contro un muro, la raccolta dello zaino) si proiettano i
##    vertici del guanto con la camera del giocatore: quanti stanno nello schermo e quanto in alto arrivano. Più l'elenco
##    delle mesh visibili della lancia (niente di grigio). Scatti: tutti gli stati nel formato e campo predefiniti, e il
##    fotogramma peggiore dove il guanto entra nello schermo;
##  - vicino: una camera fuori dal giocatore attorno al guanto (7 lati) da fermo, e 2 lati in ogni posa; e la posizione
##    del guanto rispetto alla lancia in ogni fotogramma delle pose (il guanto segue la lancia);
##  - scene: la morte (camera che cade), la presa di lei (camera tirata verso il suo viso), la ripartenza: fotogrammi dalla
##    camera del giocatore e proiezione del guanto.
## Uso: xvfb-run -a -s "-screen 0 1920x1080x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##   --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/collaudo_guanto.gd <cartella> \
##   [occhi,vicino,soglia,scene,punti,aspetto] (CONF="16x9:62,4x3:90" e FOV_SCENE=90 nell'ambiente)

const LEVEL := "res://scenes/test/test_level.tscn"
const FORMATI := [["16x9", Vector2i(1280, 720)], ["16x10", Vector2i(1280, 800)], ["21x9", Vector2i(1680, 720)], ["4x3", Vector2i(960, 720)]]
const CAMPI := [50.0, 62.0, 90.0]

var cart := ""
var p: Player
var guanto: MeshInstance3D
var _punti := PackedVector3Array()
var _conf := ""
var _scatti_conf := false
## [stato] -> [vertici nello schermo al massimo, altezza massima sopra il bordo in basso (frazione), fotogramma]
var _peggio := {}
var _stato := ""
var _k := 0


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
		await _misura()


func _scatto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(cart.path_join(nome + ".jpg"), 0.88)
	print("SCATTO ", nome)


## Il guanto nello schermo adesso: [vertici dentro, altezza massima sopra il bordo in basso in frazione dell'altezza].
func _nello_schermo() -> Array:
	if guanto == null or not is_instance_valid(guanto) or not guanto.is_inside_tree() or not guanto.is_visible_in_tree():
		return [0, 0.0]
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return [0, 0.0]
	var r := get_viewport().get_visible_rect().size
	var n := 0
	var alto := 0.0
	var xf := guanto.global_transform
	for v in _punti:
		var w := xf * v
		if cam.is_position_behind(w):
			continue
		var s := cam.unproject_position(w)
		if s.x >= 0.0 and s.x <= r.x and s.y >= 0.0 and s.y <= r.y:
			n += 1
			alto = maxf(alto, (r.y - s.y) / r.y)
	return [n, alto]


func _misura() -> void:
	if _stato == "":
		return
	_k += 1
	var m := _nello_schermo()
	var prima: Array = _peggio.get(_stato, [0, 0.0, -1])
	if int(m[0]) > int(prima[0]):
		_peggio[_stato] = [m[0], m[1], _k]
		# il guanto entra nello schermo: lo scatto del fotogramma peggiore (al più uno ogni 10 vertici in più)
		if int(m[0]) >= int(prima[0]) + 10 or int(prima[0]) == 0:
			await _scatto("entra_%s_%s" % [_conf, _stato])


func _trova_guanto() -> void:
	guanto = null
	var rig := p.water_pack.lance_rig as Node3D
	var tutte := []
	_tutte(rig, tutte)
	for m: MeshInstance3D in tutte:
		var mat := m.mesh.surface_get_material(0) if m.mesh and m.mesh.get_surface_count() > 0 else null
		if mat and String(mat.resource_name).begins_with("Guanto"):
			guanto = m
	_punti = PackedVector3Array()
	if guanto:
		var f := guanto.mesh.get_faces()
		for i in range(0, f.size(), 3):
			_punti.append(f[i])


func _tutte(n: Node, out: Array) -> void:
	for c in n.get_children(true):
		if c is MeshInstance3D:
			out.append(c)
		_tutte(c, out)


## Le mesh visibili della lancia (e del ViewModel): nome, colore, strati.
func _elenco_mesh() -> void:
	var vm := p.water_pack.view_model
	var tutte := []
	_tutte(vm, tutte)
	for m: MeshInstance3D in tutte:
		var mat: Material = m.material_override
		if mat == null and m.mesh and m.mesh.get_surface_count() > 0:
			mat = m.get_active_material(0)
		var col := (mat as BaseMaterial3D).albedo_color if mat is BaseMaterial3D else Color(-1, -1, -1)
		if mat is BaseMaterial3D and (mat as BaseMaterial3D).albedo_texture and (mat as BaseMaterial3D).albedo_texture.get_width() <= 8:
			col = (mat as BaseMaterial3D).albedo_texture.get_image().get_pixel(0, 0)   # (texture uniforme: il suo colore)
		print("MESH: %s (%s), visibile %s, colore %s, materiale %s" % [vm.get_path_to(m), m.mesh.resource_name if m.mesh else "-",
				m.is_visible_in_tree(), col, mat.resource_name if mat else "-"])


func _premi(azioni: Array) -> void:
	for a in azioni:
		Input.action_press(a)


func _lascia(azioni: Array) -> void:
	for a in azioni:
		Input.action_release(a)


func _in_stato(nome: String, scatto_a: int, durata: int) -> void:
	_stato = nome
	for i in durata:
		await get_tree().physics_frame
		await _misura()
		if i == scatto_a and _scatti_conf:
			await _scatto("occhi_%s_%s" % [_conf, nome])
	_stato = ""


func _muro_davanti(distanza: float) -> StaticBody3D:
	var b := StaticBody3D.new()
	var c := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = Vector3(3.0, 3.0, 0.2)
	c.shape = s
	b.add_child(c)
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = s.size
	m.mesh = bm
	b.add_child(m)
	b.collision_layer = Layers.WORLD
	get_tree().current_scene.add_child(b)
	var aim := p.get_aim_transform()
	var avanti := -aim.basis.z
	avanti.y = 0.0
	b.global_position = aim.origin + avanti.normalized() * (distanza + 0.1)
	b.look_at(aim.origin, Vector3.UP)
	return b


## Una scala di 10 gradini (17 cm di alzata, 28 di pedata) lontano dalla stanza, col suo pavimento.
func _scala_a(o: Vector3) -> Node3D:
	var n := Node3D.new()
	get_tree().current_scene.add_child(n)
	n.global_position = o
	var pezzi := [[Vector3(4, 0.2, 8), Vector3(0, -0.1, 0)]]
	for i in 10:
		pezzi.append([Vector3(2.0, 0.17 * (i + 1), 0.28), Vector3(0, 0.17 * (i + 1) * 0.5, -1.0 - 0.28 * i)])
	for d in pezzi:
		var b := StaticBody3D.new()
		var c := CollisionShape3D.new()
		var s := BoxShape3D.new()
		s.size = d[0]
		c.shape = s
		b.add_child(c)
		var m := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = d[0]
		m.mesh = bm
		b.add_child(m)
		b.collision_layer = Layers.WORLD
		n.add_child(b)
		b.position = d[1]
	return n


func _stati() -> void:
	var wp := p.water_pack
	p.teleport(Vector3(0.0, 0.0, 2.0), 0.0, 0.0)
	await _frames(20)
	await _in_stato("fermo", 30, 60)
	_premi(["move_forward"])
	await _in_stato("camminando", 45, 90)
	_premi(["sprint"])
	await _in_stato("correndo", 45, 90)
	_lascia(["sprint", "move_forward"])
	p.teleport(Vector3(0.0, 0.0, 2.0), 0.0, 0.0)
	wp.set_tank_amount(18.0)
	await _frames(20)
	_premi(["spray"])
	_stato = "carica"
	var k := 0
	while not wp.is_spraying and k < 90:
		await get_tree().physics_frame
		await _misura()
		if k == 5 and _scatti_conf:
			await _scatto("occhi_%s_carica" % _conf)
		k += 1
	_stato = ""
	await _in_stato("sparo", 30, 60)
	_lascia(["spray"])
	await _frames(20)
	wp.set_tank_amount(2.0)
	_premi(["suck"])
	await _in_stato("aspirando", 30, 60)
	_lascia(["suck"])
	await _frames(20)
	_premi(["crouch"])
	await _in_stato("accovacciato", 40, 60)
	_premi(["move_forward"])
	await _in_stato("accovacciato_camminando", 30, 50)
	_lascia(["move_forward", "crouch"])
	await _frames(30)
	p.teleport(Vector3(0.0, 0.0, 2.0), 0.0, 0.0)
	await _frames(10)
	_stato = "salto_atterraggio"
	Input.action_press("jump")
	await get_tree().physics_frame
	Input.action_release("jump")
	for i in 90:
		await get_tree().physics_frame
		await _misura()
		if i == 20 and _scatti_conf:
			await _scatto("occhi_%s_salto" % _conf)
		if i == 50 and _scatti_conf:
			await _scatto("occhi_%s_atterraggio" % _conf)
	_stato = ""
	p.teleport(Vector3(0.0, 0.0, 2.0), 0.0, deg_to_rad(88.0))
	await _in_stato("tutto_su", 20, 30)
	p.teleport(Vector3(0.0, 0.0, 2.0), 0.0, deg_to_rad(-88.0))
	await _in_stato("tutto_giu", 20, 30)
	p.teleport(Vector3(0.0, 0.0, 2.0), 0.0, 0.0)
	await _frames(10)
	var muro := _muro_davanti(0.25)
	await _in_stato("contro_un_muro", 30, 50)
	muro.queue_free()
	# la scala di prova, lontano dalla stanza: su a passo normale
	var scala := _scala_a(Vector3(60.0, 0.0, 60.0))
	p.teleport(Vector3(60.0, 0.1, 60.5), 0.0, 0.0)
	await _frames(20)
	_premi(["move_forward"])
	await _in_stato("scale", 40, 90)
	_lascia(["move_forward"])
	scala.queue_free()
	# la scaletta a pioli del livello di prova (x 4,5, z -4)
	p.teleport(Vector3(4.5, 0.0, -3.3), 0.0, 0.0)
	await _frames(10)
	_premi(["move_forward"])
	await _in_stato("scaletta", 60, 90)
	_lascia(["move_forward"])
	await _frames(10)
	# in acqua (la vasca piccola, x 3,5, z -0,5) e il guado (avanti nell'acqua)
	p.teleport(Vector3(3.5, 0.3, -0.5), 0.0, 0.0)
	await _frames(30)
	await _in_stato("acqua", 30, 40)
	_premi(["move_forward"])
	await _in_stato("guado", 20, 40)
	_lascia(["move_forward"])
	p.teleport(Vector3(0.0, 0.0, 2.0), 0.0, 0.0)
	await _frames(10)
	# la raccolta dello zaino: la lancia sale dal basso
	wp.set_equipped(false, false)
	await _frames(10)
	wp.set_equipped(true, true)
	await _in_stato("raccolta", 12, 50)


func _occhi() -> void:
	# (CONF="16x10:62,21x9:90,...": solo quelle configurazioni)
	var solo := OS.get_environment("CONF").split(",", false)
	for f in FORMATI:
		get_window().size = f[1]
		for campo in CAMPI:
			if not solo.is_empty() and not ("%s:%d" % [f[0], int(campo)]) in solo:
				continue
			Grafica.imposta("fov", campo)
			await _frames(10)
			_conf = "%s_fov%d" % [f[0], int(campo)]
			_scatti_conf = f[0] == "16x9" and is_equal_approx(campo, 62.0)
			_peggio.clear()
			print("OCCHI: %s, finestra %s, vista %s, fov della camera %.0f" % [_conf, get_window().size, get_viewport().get_visible_rect().size, p.camera.fov])
			await _stati()
			var righe := PackedStringArray()
			for s in _peggio:
				var v: Array = _peggio[s]
				if int(v[0]) > 0:
					righe.append("%s: %d vertici, fino al %.1f%% dell'altezza" % [s, v[0], float(v[1]) * 100.0])
			print("OCCHI %s: guanto nello schermo in %d stati su 17%s" % [_conf, righe.size(), (": " + "; ".join(righe)) if righe.size() > 0 else ""])
	get_window().size = Vector2i(1280, 720)
	Grafica.imposta("fov", 62.0)
	await _frames(10)


func _soglia() -> void:
	p.teleport(Vector3(0.0, 0.0, 2.0), 0.0, 0.0)
	await _frames(20)
	for f in FORMATI:
		get_window().size = f[1]
		var prima := -1
		var righe := PackedStringArray()
		for campo in range(60, 91, 2):
			Grafica.imposta("fov", float(campo))
			await _frames(8)
			var m := _nello_schermo()
			righe.append("%d°: %d" % [campo, m[0]])
			if prima < 0 and int(m[0]) > 0:
				prima = campo
		print("SOGLIA %s: il guanto entra da fermo da %s (vertici nello schermo per campo: %s)" % [f[0], ("%d°" % prima) if prima > 0 else "mai fino a 90°", ", ".join(righe)])
	get_window().size = Vector2i(1280, 720)
	Grafica.imposta("fov", 62.0)
	await _frames(10)


func _camera_vicino() -> Camera3D:
	var c := Camera3D.new()
	c.fov = 40.0
	c.near = 0.005
	c.cull_mask = 0xFFFFF
	get_tree().current_scene.add_child(c)
	var luce := OmniLight3D.new()
	luce.omni_range = 2.0
	luce.light_energy = 1.0
	luce.light_cull_mask = 0xFFFFF  # strati: fuori scena
	c.add_child(luce)
	return c


## Il centro del guanto e gli assi della lancia, nel mondo.
func _vista(c: Camera3D, dir_lancia: Vector3, distanza := 0.28) -> void:
	var rig := p.water_pack.lance_rig as Node3D
	var centro: Vector3 = rig.global_transform * Vector3(0.017, -0.245, 0.52)
	var d := (rig.global_basis * dir_lancia).normalized()
	c.global_position = centro + d * distanza
	var su := rig.global_basis.y if absf(dir_lancia.normalized().y) < 0.9 else rig.global_basis.z
	c.look_at(centro, su)


func _vicino() -> void:
	var wp := p.water_pack
	p.teleport(Vector3(0.0, 0.0, 2.0), 0.0, 0.0)
	await _frames(30)
	var c := _camera_vicino()
	var lati := [["destra", Vector3(1, 0.1, 0)], ["sinistra", Vector3(-1, 0.1, 0)], ["davanti", Vector3(0, 0.15, -1)],
			["dietro", Vector3(0, 0.15, 1)], ["sotto", Vector3(0.05, -1, 0.05)], ["sopra", Vector3(0.05, 1, 0.1)],
			["dietro_sotto_polsino", Vector3(0.2, -0.6, 1)], ["dietro_destra_polsino", Vector3(0.6, -0.2, 1)]]
	for l in lati:
		_vista(c, l[1])
		c.make_current()
		await get_tree().physics_frame
		await _scatto("vicino_fermo_%s" % l[0])
	p.camera.make_current()
	# il guanto rispetto alla lancia in ogni fotogramma delle pose
	var rig := wp.lance_rig as Node3D
	var modello: Node3D = null
	var tutte := []
	_tutte(rig, tutte)
	for m: MeshInstance3D in tutte:
		if m != guanto and m.mesh and m.mesh.get_aabb().size.length() > 0.3:
			modello = m
	var rel0 := modello.global_transform.affine_inverse() * guanto.global_transform
	var scarto := 0.0
	var pose := [["carica", ["spray"], 8], ["sparo", ["spray"], 60], ["aspirando", ["suck"], 50], ["correndo", ["move_forward", "sprint"], 60], ["accovacciato", ["crouch"], 50]]
	for po in pose:
		if po[0] == "aspirando":
			wp.set_tank_amount(2.0)
		else:
			wp.set_tank_amount(18.0)
		p.teleport(Vector3(0.0, 0.0, 2.0), 0.0, 0.0)
		await get_tree().physics_frame
		_premi(po[1])
		for i in int(po[2]):
			await get_tree().physics_frame
			var rel := modello.global_transform.affine_inverse() * guanto.global_transform
			for v in [Vector3(0, -0.2, 0.5), Vector3(0.06, -0.25, 0.6), Vector3(-0.05, -0.18, 0.45)]:
				scarto = maxf(scarto, (rel * v).distance_to(rel0 * v))
		for l in [["destra", Vector3(1, 0.1, 0)], ["sotto", Vector3(0.05, -1, 0.05)]]:
			_vista(c, l[1])
			c.make_current()
			await get_tree().physics_frame
			await _scatto("vicino_%s_%s" % [po[0], l[0]])
		p.camera.make_current()
		_lascia(po[1])
		await _frames(20)
	print("VICINO: il guanto rispetto alla lancia, in tutte le pose: si sposta al più di %.4f mm" % (scarto * 1000.0))
	c.queue_free()


## Ingrandimenti mirati: la camera a [param distanza] da un punto del guanto (coordinate glTF della lancia), da una
## direzione (assi della lancia), senza la sua luce (le luci del livello) e con la sua luce.
const PUNTI := [
	["indice_vecchio_strappo_davanti", Vector3(-0.044, -0.197, 0.424), Vector3(0, 0.15, -1)],
	["indice_vecchio_strappo_sinistra", Vector3(-0.044, -0.197, 0.424), Vector3(-1, 0.1, 0)],
	["indice_piega_nuova_sinistra", Vector3(-0.026, -0.196, 0.433), Vector3(-1, 0.3, -0.3)],
	["indice_piega_nuova_davanti", Vector3(-0.026, -0.196, 0.433), Vector3(-0.2, 0.3, -1)],
	["indice_base_destra", Vector3(0.036, -0.196, 0.50), Vector3(1, 0.15, 0.1)],
	["indice_base_destra_alto", Vector3(0.036, -0.196, 0.50), Vector3(0.8, 0.5, 0.2)],
	["indice_bordo_alto_davanti", Vector3(0.036, -0.194, 0.48), Vector3(0.3, 0.4, -1)],
	["indice_bordo_alto_sinistra", Vector3(-0.032, -0.194, 0.478), Vector3(-1, 0.4, 0)],
	["spiraglio_anulare_mignolo", Vector3(0.034, -0.262, 0.463), Vector3(1, 0.1, 0)],
]


func _punti_vicini(distanza := 0.11) -> void:
	p.teleport(Vector3(0.0, 0.0, 2.0), 0.0, 0.0)
	await _frames(30)
	var c := _camera_vicino()
	c.set_meta(&"grafica_fov_fisso", true)   # (senza, la grafica le rimette il campo visivo delle opzioni)
	var luce := c.get_child(0) as OmniLight3D
	var rig := p.water_pack.lance_rig as Node3D
	for q in PUNTI:
		var centro: Vector3 = rig.global_transform * (q[1] as Vector3)
		var d := (rig.global_basis * (q[2] as Vector3)).normalized()
		c.global_position = centro + d * distanza
		var su := rig.global_basis.y if absf((q[2] as Vector3).normalized().y) < 0.9 else rig.global_basis.z
		c.look_at(centro, su)
		c.make_current()
		await get_tree().process_frame
		c.fov = 40.0
		for l in [true, false]:
			luce.visible = l
			await _frames(3)
			await _scatto("punto_%s%s" % [q[0], "" if l else "_luce_del_livello"])
	p.camera.make_current()
	c.queue_free()


## L'aspetto col materiale di prima (mani_col_materiale_del_modello falso) e col nuovo, nella stessa luce: le luci del
## livello (quella degli scatti approvati) e poi in più una luce rosa come quella di lei (LeiOblo.ROSA, energia 4) a
## 1,2 m davanti alla lancia. Da vicino (destra, sinistra, dietro) senza la luce della camera, e dagli occhi a 90°.
## Per ogni scatto anche il guanto nascosto, per la maschera dei suoi pixel: il colore medio del guanto.
func _aspetto() -> void:
	p.teleport(Vector3(0.0, 0.0, 2.0), 0.0, 0.0)
	await _frames(30)
	var rig := p.water_pack.lance_rig as Node3D
	var rosa := OmniLight3D.new()
	rosa.light_color = Color(1.0, 0.35, 0.6)
	rosa.light_energy = 4.0
	rosa.omni_range = 4.0
	get_tree().current_scene.add_child(rosa)
	rosa.visible = false
	var c := _camera_vicino()
	(c.get_child(0) as OmniLight3D).visible = false
	for luce in ["livello", "rosa"]:
		rosa.visible = luce == "rosa"
		for versione in ["prima", "nuovo"]:
			rig.set(&"mani_col_materiale_del_modello", versione == "nuovo")
			await _frames(5)
			_trova_guanto()
			rosa.global_position = rig.global_transform * Vector3(-0.3, 0.1, -0.9)
			var mat := guanto.get_active_material(0) as BaseMaterial3D
			print("ASPETTO %s %s: materiale %s, albedo %s, ruvidezza %s, metallo %s" % [luce, versione, mat.resource_name,
					mat.albedo_texture.get_image().get_pixel(0, 0) if mat.albedo_texture else mat.albedo_color,
					mat.roughness_texture.get_image().get_pixel(0, 0) if mat.roughness_texture else mat.roughness,
					mat.metallic])
			for v in [["destra", Vector3(1, 0.1, 0)], ["sinistra", Vector3(-1, 0.1, 0)], ["dietro", Vector3(0, 0.15, 1)]]:
				_vista(c, v[1], 0.28)
				c.make_current()
				await get_tree().process_frame
				c.fov = 40.0
				await _frames(4)
				await _scatto("aspetto_%s_%s_%s" % [luce, v[0], versione])
				guanto.visible = false
				await _frames(3)
				await _scatto("aspetto_%s_%s_senza" % [luce, v[0]])
				guanto.visible = true
			p.camera.make_current()
			Grafica.imposta("fov", 90.0)
			await _frames(6)
			await _scatto("aspetto_%s_occhi90_%s" % [luce, versione])
			guanto.visible = false
			await _frames(3)
			await _scatto("aspetto_%s_occhi90_senza" % luce)
			guanto.visible = true
			Grafica.imposta("fov", 62.0)
	rosa.queue_free()
	c.queue_free()
	rig.set(&"mani_col_materiale_del_modello", true)
	await _frames(5)
	_trova_guanto()


func _scene() -> void:
	# la morte (camera che cade a terra) e la ripartenza
	# FOV_SCENE=90 nell'ambiente: le scene col campo visivo più largo (il guanto nello schermo)
	var campo := OS.get_environment("FOV_SCENE")
	var suf := ""
	_conf = "16x9_fov62"
	if campo != "":
		Grafica.imposta("fov", float(campo))
		suf = "_fov" + campo
		_conf = "16x9_fov" + campo
		print("SCENE: campo visivo %s, fov della camera %.0f" % [campo, p.camera.fov])
	p.teleport(Vector3(0.0, 0.0, 2.0), 0.0, 0.0)
	await _frames(20)
	_stato = "morte"
	GameState.kill_player(&"collaudo")
	for i in 70:
		await get_tree().process_frame
		await _misura()
		if i in [10, 30, 50]:
			await _scatto("scena_morte_%02d%s" % [i, suf])
	_stato = ""
	var seq: Node = GameState.get(&"_death_sequence")
	if is_instance_valid(seq):
		seq.emit_signal(&"finished", true)
	await _aspetta_giocatore()
	_stato = "ripartenza"
	for i in 40:
		await get_tree().process_frame
		await _misura()
		if i in [2, 20]:
			await _scatto("scena_ripartenza_%02d%s" % [i, suf])
	_stato = ""
	# la presa di lei: la camera tirata verso il suo viso (una lei finta, nel gruppo "medusa_che_prende")
	p.teleport(Vector3(0.0, 0.0, 2.0), 0.0, 0.0)
	await _frames(20)
	var lei := Node3D.new()
	lei.add_to_group(&"medusa_che_prende")
	get_tree().current_scene.add_child(lei)
	lei.global_position = p.global_position + Vector3(0.0, 0.3, -2.5)
	_stato = "presa_di_lei"
	GameState.kill_player(&"medusa")
	for i in 80:
		await get_tree().process_frame
		await _misura()
		if i in [15, 40, 60]:
			await _scatto("scena_presa_%02d%s" % [i, suf])
	_stato = ""
	seq = GameState.get(&"_death_sequence")
	if is_instance_valid(seq):
		seq.emit_signal(&"finished", true)
	await _aspetta_giocatore()
	await _frames(20)
	for s in _peggio:
		print("SCENE: %s: guanto nello schermo al più %d vertici, fino al %.1f%% dell'altezza" % [s, _peggio[s][0], float(_peggio[s][1]) * 100.0])
	for s in ["morte", "ripartenza", "presa_di_lei"]:
		if not _peggio.has(s):
			print("SCENE: %s: il guanto non entra mai nello schermo" % s)


func _aspetta_giocatore() -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < 60000:
		await get_tree().process_frame
		var q := GameState.player
		if q and is_instance_valid(q) and q.input_enabled and not GameState.is_dying and q != p:
			break
	await _frames(5)
	p = GameState.player
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	_trova_guanto()
	print("SCENE: ripartito, guanto trovato %s, lancia visibile %s" % [guanto != null, p.water_pack.view_model.visible])


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	cart = a[1] if a.size() > 1 else "user://collaudo_guanto"
	var cosa: String = a[2] if a.size() > 2 else "occhi,vicino,scene"
	DirAccess.make_dir_recursive_absolute(cart)
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset("alto")
	get_tree().change_scene_to_file(LEVEL)
	await get_tree().process_frame
	for i in 300:
		await get_tree().process_frame
		p = GameState.player
		if p and p.input_enabled:
			break
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	p.add_item(&"zaino_pompa", 1, "Zaino-pompa")
	p.water_pack.set_equipped(true, false)
	p.water_pack.set_tank_amount(18.0)
	await _frames(30)
	# il checkpoint della stanza con lo zaino addosso: dopo la morte si riparte con la lancia
	var cp := get_tree().current_scene.find_child("CheckpointPartenza", true, false)
	if cp:
		GameState.reach_checkpoint(cp)
	_trova_guanto()
	print("GUANTO: trovato %s (%s), %d punti, colore %s" % [guanto != null, guanto.get_path() if guanto else "-", _punti.size(),
			(guanto.get_active_material(0) as BaseMaterial3D).albedo_color if guanto and guanto.get_active_material(0) is BaseMaterial3D else "-"])
	_elenco_mesh()
	if cosa.contains("punti"):
		await _punti_vicini()
	if cosa.contains("aspetto"):
		await _aspetto()
	if cosa.contains("vicino"):
		await _vicino()
	if cosa.contains("soglia"):
		await _soglia()
	if cosa.contains("occhi"):
		await _occhi()
	if cosa.contains("scene"):
		await _scene()
	print("GUANTO: FINE")
	get_tree().quit()
