extends Node
## Collaudo dei bersagli da luna park (grafica-2, 0.3.21) sulle 6 paratie delle vasche dei bivi. La torre con le condotte
## (sala_torre.tscn), l'ambiente della sala, il blackout, il giocatore vero col getto, lei che non sale. Fasi (secondo
## argomento, separate da virgole) e vasche (terzo, es. 0,1,2):
##  - numeri: per ogni paratia i pezzi del pannello (mesh sotto il nodo) e quelli vicini; le collisioni del pannello che
##    entrano in altro (intersect_shape), chiusa e aperta; l'anello di led: dove sta e se sale col pannello (NUMERI:);
##  - chiuse: ravvicinati con una lampadina tecnica: i 4 angoli del pannello, i montanti (giù, a metà, su, nei due lati),
##    l'anello della giusta di sbieco, la faccia da 1,2 m senza lampadina;
##  - apertura: da 2,5 m, scatti mentre il pannello sale; poi aperta: la faccia, il bordo di sotto del pannello alzato;
##  - tubo: dal tubo dietro la paratia, guardando la bocca, chiusa, mentre si apre e aperta;
##  - getto: il getto vero dal checkpoint sul bersaglio, quanti fotogrammi per aprirla (GETTO:), poi richiusa.
## Uso: xvfb-run -a -s "-screen 0 960x540x24" godot --path godot --rendering-driver vulkan --resolution 960x540 \
##   --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/paratie_giro.gd <cartella> <fasi> [vasche]

const PLAYER := "res://scenes/player/player.tscn"
var cart := ""
var p: Player
var ins: SalaInseguimento


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _scatto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(cart.path_join(nome + ".jpg"), 0.9)


func _libera(da: Vector3, verso: Vector3, nome: String, luce := true, fov := 55.0, attesa := 8) -> void:
	var c := Camera3D.new()
	c.fov = fov
	c.near = 0.02
	c.attributes = p.camera.attributes
	add_child(c)
	c.global_position = da
	c.look_at(verso, Vector3.UP if absf((verso - da).normalized().y) < 0.95 else Vector3.RIGHT)
	c.current = true
	if luce:
		var o := OmniLight3D.new()
		o.light_energy = 1.2
		o.omni_range = 3.0
		c.add_child(o)
	await _frames(attesa)
	await _scatto(nome)
	c.current = false
	c.queue_free()
	p.camera.current = true


func _aabb(n: Node3D) -> AABB:
	var a := AABB()
	var primo := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var b := m.global_transform * m.get_aabb()
		a = b if primo else a.merge(b)
		primo = false
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var b2 := (n as MeshInstance3D).global_transform * (n as MeshInstance3D).get_aabb()
		a = b2 if primo else a.merge(b2)
	return a


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	var a := OS.get_cmdline_user_args()
	cart = a[1]
	var fasi := a[2].split(",")
	var vasche := [0, 1, 2]
	if a.size() > 3:
		vasche = Array(a[3].split(",")).map(func(x): return int(x))
	DirAccess.make_dir_recursive_absolute(cart)
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	env.environment.sdfgi_enabled = false
	env.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
	add_child(env)
	GameState.luci = GameState.Luci.BLACKOUT
	var torre := (load("res://scenes/sala/torre/sala_torre.tscn") as PackedScene).instantiate() as SalaTorre
	add_child(torre)
	await _frames(30)
	ins = torre.inseguimento as SalaInseguimento
	ins.tempo_presa = 9999.0
	ins.comparsa = PackedFloat32Array([9999.0, 9999.0, 9999.0])
	if ins.lei:
		ins.lei.visible = false
	p = (load(PLAYER) as PackedScene).instantiate() as Player
	add_child(p)
	await _frames(10)
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	p.water_pack.call(&"set_equipped", true, false)
	for k in ins.paratie.size():
		var d: Dictionary = ins.paratie[k]
		if not int(d["vasca"]) in vasche:
			continue
		var nome := "v%d_%s" % [int(d["vasca"]) + 1, "giusta" if bool(d["giusta"]) else "sbagliata"]
		for f in fasi:
			match f:
				"numeri": await _numeri(k, nome)
				"chiuse": await _chiuse(k, nome)
				"apertura": await _apertura(k, nome)
				"tubo": await _tubo(k, nome)
				"getto": await _getto(k, nome)
	print("PARATIE: finito")
	get_tree().quit()


func _chiudi(k: int) -> void:
	var d: Dictionary = ins.paratie[k]
	d["apre"] = false
	d["aperta"] = 0.0
	d["getto"] = 0.0
	var pn := d["pannello_nodo"] as Node3D
	if pn:
		pn.global_position = d["chiuso"]
	await _frames(5)


func _apri_tutta(k: int) -> void:
	ins.apri_paratia(k)
	for i in 600:
		await get_tree().physics_frame
		if float(ins.paratie[k]["aperta"]) >= 1.0:
			break
	await _frames(5)


func _assi(k: int) -> Array:
	var d: Dictionary = ins.paratie[k]
	var n := SalaInseguimento.b(d["verso"])
	n.y = 0.0
	n = n.normalized()
	var lat := n.cross(Vector3.UP).normalized()
	return [n, lat, SalaInseguimento.b(d["bersaglio"])]


func _vicini(pn: Node3D, a: AABB) -> Array:
	var out := []
	for mi in ins.get_parent().find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or not m.is_visible_in_tree() or pn.is_ancestor_of(m) or m == pn:
			continue
		var b := m.global_transform * m.get_aabb()
		if b.size.length() > 60.0:
			continue
		if b.grow(0.05).intersects(a):
			out.append(String(m.name))
	return out


func _collisioni(pn: Node3D) -> Array:
	var out := []
	var spazio := get_viewport().world_3d.direct_space_state
	var miei := []
	for c in pn.find_children("*", "CollisionObject3D", true, false):
		miei.append((c as CollisionObject3D).get_rid())
	if pn is CollisionObject3D:
		miei.append((pn as CollisionObject3D).get_rid())
	for cs in pn.find_children("*", "CollisionShape3D", true, false):
		var s := cs as CollisionShape3D
		if s.shape == null or s.disabled:
			continue
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = s.shape
		q.transform = s.global_transform
		q.exclude = miei + [p.get_rid()]
		q.margin = -0.005
		for r in spazio.intersect_shape(q, 16):
			var nome := String((r["collider"] as Node).name)
			var par := (r["collider"] as Node).get_parent()
			out.append("%s/%s" % [par.name if par else "", nome])
	return out


func _numeri(k: int, nome: String) -> void:
	var d: Dictionary = ins.paratie[k]
	var pn := d["pannello_nodo"] as Node3D
	var ax := _assi(k)
	var mesh_pn := pn.find_children("*", "MeshInstance3D", true, false).map(func(m): return String(m.name))
	var a := _aabb(pn)
	print("NUMERI: %s (paratia %d, nodo %s): pannello %s .. %s, mesh %s; corsa %.2f m" % [nome, k, pn.name, a.position.snapped(Vector3.ONE * 0.001),
			a.end.snapped(Vector3.ONE * 0.001), mesh_pn, float(d["corsa"])])
	print("NUMERI: %s chiusa: vicini (scatole a meno di 5 cm) %s; collisioni del pannello dentro altro %s" % [nome, _vicini(pn, a), _collisioni(pn)])
	# l'anello di led: mesh col nome che lo dice, vicino al bersaglio
	var anelli := []
	for mi in ins.get_parent().find_children("*", "MeshInstance3D", true, false):
		var s := String(mi.name).to_lower()
		if (s.contains("led") or s.contains("anello") or s.contains("ring")) and (mi as Node3D).global_position.distance_to(ax[2]) < 2.0:
			anelli.append(mi)
	var prima := {}
	for m in anelli:
		prima[m] = (m as Node3D).global_position
	var luci_prima := {}
	for l in ins.find_children("*", "Light3D", true, false):
		if (l as Node3D).global_position.distance_to(ax[2]) < 1.5:
			luci_prima[l] = (l as Node3D).global_position
	var pn0 := pn.global_position
	await _apri_tutta(k)
	var sale := pn.global_position.y - pn0.y
	var a2 := _aabb(pn)
	print("NUMERI: %s aperta: il pannello è salito %.3f m; vicini %s; collisioni dentro altro %s" % [nome, sale, _vicini(pn, a2), _collisioni(pn)])
	for m in anelli:
		print("NUMERI: %s anello/led %s (sotto il pannello %s): salito %.3f m" % [nome, (m as Node).name, pn.is_ancestor_of(m), (m as Node3D).global_position.y - float(prima[m].y)])
	for l in luci_prima:
		print("NUMERI: %s luce %s (sotto il pannello %s): salita %.3f m" % [nome, (l as Node).name, pn.is_ancestor_of(l), (l as Node3D).global_position.y - float(luci_prima[l].y)])
	await _chiudi(k)


func _chiuse(k: int, nome: String) -> void:
	var d: Dictionary = ins.paratie[k]
	var pn := d["pannello_nodo"] as Node3D
	var ax := _assi(k)
	var n: Vector3 = ax[0]
	var lat: Vector3 = ax[1]
	var bk: Vector3 = ax[2]
	var a := _aabb(pn)
	var c := a.get_center()
	# metà larghezza lungo lat e metà altezza
	var hw := absf((a.size * lat).length()) * 0.5
	var hh := a.size.y * 0.5
	var fronte := c - n * (absf((a.size * n).length()) * 0.5)
	p.teleport(bk - n * 6.0 + Vector3.UP * 0.2)
	await _frames(10)
	await _libera(fronte - n * 1.2, fronte, "%s_chiusa_faccia" % nome, false, 60.0, 15)
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var ang: Vector3 = fronte + lat * hw * float(sx) + Vector3.UP * hh * float(sy)
			await _libera(ang - n * 0.45 + lat * 0.2 * sx + Vector3.UP * 0.1 * sy, ang, "%s_chiusa_angolo_%s_%s" % [nome, "dx" if sx > 0 else "sx", "su" if sy > 0 else "giu"])
		for hi in 3:
			var h: float = [-0.9, 0.0, 0.9][hi]
			var g: Vector3 = fronte + lat * (hw + 0.08) * float(sx) + Vector3.UP * hh * h
			await _libera(g - n * 0.5 - lat * 0.25 * sx, g, "%s_chiusa_montante_%s_%s" % [nome, "dx" if sx > 0 else "sx", ["giu", "meta", "su"][hi]])
	if bool(d["giusta"]):
		await _libera(bk - n * 0.6 + lat * 0.45 + Vector3.UP * 0.25, bk, "%s_chiusa_anello_di_sbieco" % nome)
		await _libera(bk - n * 0.35 + lat * 0.05, bk + lat * 0.45, "%s_chiusa_anello_bordo" % nome)


func _apertura(k: int, nome: String) -> void:
	var ax := _assi(k)
	var n: Vector3 = ax[0]
	var bk: Vector3 = ax[2]
	var cp: Dictionary = ins.dati["checkpoint"][int(ins.paratie[k]["vasca"])]
	var da := bk - n * 2.5
	da.y = SalaInseguimento.b(cp["pos"]).y + 0.05
	p.teleport(da)
	await _frames(10)
	p.look_at_point(bk)
	await _frames(30)
	await _scatto("%s_apertura_00" % nome)
	ins.apri_paratia(k)
	var i := 0
	var s := 1
	while float(ins.paratie[k]["aperta"]) < 1.0 and i < 900:
		await get_tree().physics_frame
		p.look_at_point(bk)
		i += 1
		if i % 20 == 0:
			await _scatto("%s_apertura_%02d" % [nome, s])
			s += 1
	await _frames(20)
	p.look_at_point(bk)
	await _frames(5)
	await _scatto("%s_aperta" % nome)
	var pn := ins.paratie[k]["pannello_nodo"] as Node3D
	var a := _aabb(pn)
	var sotto := Vector3(a.get_center().x, a.position.y, a.get_center().z) - n * (absf((a.size * n).length()) * 0.5)
	await _libera(sotto - n * 0.6 + Vector3.DOWN * 0.3, sotto, "%s_aperta_bordo_sotto" % nome)
	if bool(ins.paratie[k]["giusta"]):
		var anello := bk + Vector3.UP * float(ins.paratie[k]["corsa"])
		await _libera(anello - n * 0.7 + Vector3.DOWN * 0.2, anello, "%s_aperta_anello" % nome)
	await _chiudi(k)


func _tubo(k: int, nome: String) -> void:
	var bk: Vector3 = _assi(k)[2]
	var meglio := ""
	var dmin := INF
	for t: String in ins.dati["tubi"]:
		var l0 := SalaInseguimento.b(ins.dati["tubi"][t][0])
		if l0.distance_to(bk) < dmin:
			dmin = l0.distance_to(bk)
			meglio = t
	var linea: Array = ins.dati["tubi"][meglio]
	var dentro := SalaInseguimento.b(linea[mini(5, linea.size() - 1)])
	var bocca := SalaInseguimento.b(linea[0])
	print("NUMERI: %s: dietro c'è %s (inizio a %.2f m dal bersaglio)" % [nome, meglio, dmin])
	p.teleport(bk - _assi(k)[0] * 6.0)
	await _frames(5)
	await _libera(dentro + Vector3.UP * 0.1, bocca + Vector3.UP * 0.3, "%s_tubo_chiusa" % nome, true, 70.0)
	ins.apri_paratia(k)
	var c := Camera3D.new()
	c.fov = 70.0
	c.near = 0.02
	c.attributes = p.camera.attributes
	add_child(c)
	c.global_position = dentro + Vector3.UP * 0.1
	c.look_at(bocca + Vector3.UP * 0.3, Vector3.UP)
	var o := OmniLight3D.new()
	o.light_energy = 1.2
	o.omni_range = 4.0
	c.add_child(o)
	c.current = true
	var i := 0
	var s := 1
	while float(ins.paratie[k]["aperta"]) < 1.0 and i < 900:
		await get_tree().physics_frame
		i += 1
		if i % 25 == 0:
			await _scatto("%s_tubo_si_apre_%02d" % [nome, s])
			s += 1
	await _frames(10)
	await _scatto("%s_tubo_aperta" % nome)
	c.current = false
	c.queue_free()
	p.camera.current = true
	await _chiudi(k)


func _getto(k: int, nome: String) -> void:
	var d: Dictionary = ins.paratie[k]
	var bk: Vector3 = _assi(k)[2]
	var cp: Dictionary = ins.dati["checkpoint"][int(d["vasca"])]
	var da := SalaInseguimento.b(cp["pos"])
	p.teleport(da + Vector3.UP * 0.05)
	await _frames(20)
	p.look_at_point(bk)
	await _frames(20)
	p.water_pack.set_tank_amount(20.0)
	Input.action_press(&"spray")
	var f := 0
	var primo := -1
	while f < 60 * 12 and not bool(d["apre"]):
		await get_tree().physics_frame
		p.look_at_point(bk)
		f += 1
		if primo < 0 and float(d["getto"]) > 0.0:
			primo = f
	Input.action_release(&"spray")
	var f2 := 0
	while float(d["aperta"]) < 1.0 and f2 < 900:
		await get_tree().physics_frame
		f2 += 1
	print("GETTO: %s: dal checkpoint (a %.1f m), primo colpo dopo %d fotogrammi, si apre dopo %d (%.2f s), alzata del tutto dopo altri %d (%.2f s)" % [nome,
			da.distance_to(bk), primo, f, f / 60.0, f2, f2 / 60.0])
	await _chiudi(k)
	p.water_pack.set_tank_amount(20.0)
	await _frames(30)
