extends Node
## Test dei disegni del bambino con la scatola (DisegnoBambino, build 0.5.0):
## 1. il componente da solo, in una stanza di prova: il foglio A3 (e A4) con quattro pezzi di nastro, il retro sul
##    muro; i pastelli si vedono appena al buio (emissione 0,12); il pastello per terra (il fondo sul pavimento); le
##    impronte vanno da dove arrivano fin sotto il foglio, alternate, sul pavimento, le prime più asciutte;
## 2. i disegni nella sala vera (ognuno, anche quelli che metteranno le altre squadre): il foglio sul muro che si vede,
##    a contatto in tutti i 25 punti (niente che sporge sotto la carta, niente staccato più di 3 mm, salvo le fughe
##    dietro), niente davanti; il centro fra 0,8 e 1,25 m sopra il pavimento; il pastello appoggiato (entro 5 mm); le
##    impronte sul pavimento (entro 2 cm);
## 3. gli stessi controlli per i disegni delle condotte (D4), nella scena di prova delle condotte.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_disegni_bambino.gd [solo_componente]

const LEVEL := "res://scenes/sala_principale.tscn"
## La sala delle condotte nella sua scena di prova (D4).
const CONDOTTE := "res://scenes/test/inseguimento_prova.tscn"

var _ok := 0
var _ko := 0


func _ready() -> void:
	_run.call_deferred()


func check(c: bool, msg: String) -> void:
	if c:
		_ok += 1
		print("  ok  ", msg)
	else:
		_ko += 1
		print("  KO  ", msg)


func _fisica(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	await _componente()
	var args := OS.get_cmdline_user_args()
	if not (args.size() > 1 and args[1] == "solo_componente"):
		await _sala()
		await _condotte()
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	get_tree().quit(1 if _ko > 0 else 0)


## Una stanza di prova: pavimento a y = 0, muro col retro... davanti a z = 0 (guarda +Z).
func _stanza() -> Node3D:
	var r := Node3D.new()
	add_child(r)
	for d in [[Vector3(6, 0.2, 6), Vector3(0, -0.1, 2)], [Vector3(6, 3, 0.2), Vector3(0, 1.5, -0.1)]]:
		var corpo := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = d[0]
		cs.shape = box
		corpo.add_child(cs)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = d[0]
		mi.mesh = bm
		corpo.add_child(mi)
		r.add_child(corpo)
		corpo.position = d[1]
	return r


func _componente() -> void:
	print("== il componente")
	var r := _stanza()
	var d := DisegnoBambino.new()
	d.disegno = load("res://assets/storia_disegni/disegno_d1.jpg") as Texture2D
	d.altezza = 1.1
	d.pastello = true
	d.impronte = true
	d.impronte_da = Vector2(-1.6, 1.4)
	r.add_child(d)
	d.position = Vector3(0, 1.1, 0)
	await _fisica(3)
	var foglio := d.get_node_or_null(^"Foglio") as MeshInstance3D
	var pastelli := d.get_node_or_null(^"Pastelli") as MeshInstance3D
	check(foglio != null and pastelli != null, "c'è il foglio, col disegno davanti")
	if foglio == null or pastelli == null:
		return
	var a := foglio.global_transform * foglio.get_aabb()
	check(is_equal_approx(a.size.x, 0.297) and is_equal_approx(a.size.y, 0.42), "A3 verticale: 29,7 × 42 cm (%s)" % a.size)
	check(absf(a.position.z) < 0.0005, "il retro del foglio tocca il muro (%.4f m)" % a.position.z)
	var mat := pastelli.material_override as StandardMaterial3D
	check(mat.albedo_texture == d.disegno and mat.emission_enabled and is_equal_approx(mat.emission_energy_multiplier, 0.12),
			"i pastelli si vedono appena al buio (emissione %.2f)" % mat.emission_energy_multiplier)
	var nastri := d.find_children("Nastro*", "MeshInstance3D", false, false)
	var attaccati := 0
	for n: MeshInstance3D in nastri:
		var na := n.global_transform * n.get_aabb()
		# a cavallo dell'angolo: in parte sul foglio, in parte fuori; sopra la carta
		var sul_foglio := na.intersects(a.grow(0.001))
		var fuori := na.position.x < a.position.x or na.end.x > a.end.x or na.position.y < a.position.y or na.end.y > a.end.y
		if sul_foglio and fuori and na.position.z >= a.end.z - 0.0002 and na.position.z < a.end.z + 0.001:
			attaccati += 1
	check(nastri.size() == 4 and attaccati == 4, "quattro pezzi di nastro, a cavallo fra il foglio e il muro (%d su %d)" % [attaccati, nastri.size()])
	var p := d.get_node_or_null(^"Pastello") as Node3D
	var pa := _aabb(p) if p else AABB()
	check(p != null and absf(pa.position.y) < 0.001 and pa.size.y > 0.008 and pa.size.y < 0.015,
			"il pastello per terra, sdraiato (fondo a %.4f m, alto %.3f)" % [pa.position.y, pa.size.y])
	var impronte := d.find_children("Impronta*", "Decal", false, false)
	var sul_pavimento := impronte.all(func(x: Decal): return absf(x.global_position.y) < 0.001)
	var sempre_piu := true
	for k in range(1, impronte.size()):
		sempre_piu = sempre_piu and (impronte[k] as Decal).modulate.a >= (impronte[k - 1] as Decal).modulate.a
	var ultima := impronte[-1] as Decal if not impronte.is_empty() else null
	check(impronte.size() >= 6 and sul_pavimento and sempre_piu and ultima and ultima.global_position.z < 0.5,
			"le impronte (%d) arrivano sotto il foglio, sul pavimento, le prime più asciutte" % impronte.size())
	d.formato = DisegnoBambino.Formato.A4
	await _fisica(2)
	var a4 := (d.get_node(^"Foglio") as MeshInstance3D)
	var aa := a4.global_transform * a4.get_aabb()
	check(is_equal_approx(aa.size.x, 0.21) and is_equal_approx(aa.size.y, 0.297), "A4 per il foglio del finale (%s)" % aa.size)
	d.formato = DisegnoBambino.Formato.A3_ORIZZONTALE
	await _fisica(2)
	var ao := (d.get_node(^"Foglio") as MeshInstance3D)
	var ab := ao.global_transform * ao.get_aabb()
	check(is_equal_approx(ab.size.x, 0.42) and is_equal_approx(ab.size.y, 0.297) and d.find_children("Nastro*", "MeshInstance3D", false, false).size() == 4,
			"A3 orizzontale per D4 (%s), coi suoi quattro nastri" % ab.size)
	r.queue_free()
	await _fisica(2)


func _aabb(n: Node3D) -> AABB:
	var out := AABB()
	var primo := true
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var b := mi.global_transform * mi.get_aabb()
		out = b if primo else out.merge(b)
		primo = false
	return out


func _sala() -> void:
	print("== i disegni nella sala")
	GameState.reset_progress()
	get_tree().change_scene_to_file(LEVEL)
	for i in 900:
		await get_tree().process_frame
		var s := get_tree().current_scene
		if s and s.scene_file_path == LEVEL and GameState.player and is_instance_valid(GameState.player):
			break
	await _fisica(30)
	var level := get_tree().current_scene
	var disegni := level.find_children("*", "DisegnoBambino", true, false)
	check(disegni.size() >= 2, "nella sala ci sono i disegni (%d)" % disegni.size())
	_controlla(level, disegni)


## Le condotte (D4 di ambienti-2, sul muro accanto alla porta di servizio in cima alla scaletta del bacino): la sala
## delle condotte nella sua scena di prova, costruita, coi suoi disegni.
func _condotte() -> void:
	print("== i disegni nelle condotte")
	GameState.reset_progress()
	get_tree().change_scene_to_file(CONDOTTE)
	for i in 900:
		await get_tree().process_frame
		var s := get_tree().current_scene
		if s and s.scene_file_path == CONDOTTE and GameState.player and is_instance_valid(GameState.player):
			break
	await _fisica(30)
	var level := get_tree().current_scene
	var disegni := level.find_children("*", "DisegnoBambino", true, false)
	check(disegni.size() >= 1, "nelle condotte c'è il disegno D4 (%d)" % disegni.size())
	_controlla(level, disegni)


## Per ogni disegno: il foglio sul muro, niente davanti, l'altezza, il pastello e le impronte.
func _controlla(level: Node, disegni: Array) -> void:
	var space := (level as Node3D).get_world_3d().direct_space_state
	for d: DisegnoBambino in disegni:
		var nome := String(level.get_path_to(d))
		var verso := d.global_basis.z.normalized()
		var m := d.misura()
		d.visible = false
		var peggio_fuori := 0.0
		var peggio_dentro := 0.0
		var davanti := []
		for i in 5:
			for j in 5:
				var loc := Vector3((i / 4.0 - 0.5) * m.x, (j / 4.0 - 0.5) * m.y, 0.0)
				var q := Node3D.new()
				level.add_child(q)
				q.global_position = d.to_global(loc)
				Posa.fissa_al_muro(q, verso)
				var z := d.to_local(q.global_position).z
				peggio_fuori = maxf(peggio_fuori, z)
				peggio_dentro = minf(peggio_dentro, z)
				var h := space.intersect_ray(PhysicsRayQueryParameters3D.create(d.to_global(loc) + verso * 0.4, d.to_global(loc) + verso * 0.03))
				if h:
					davanti.append((h.collider as Node).name)
				q.queue_free()
		d.visible = true
		# (una fuga o un incavo dietro la carta va bene, fino a 15 mm; niente che sporge sotto, il foglio tocca)
		check(peggio_fuori < 0.0015 and peggio_dentro > -0.015 and davanti.is_empty(),
				"%s: il foglio sul muro (sporge %.4f, incavi %.4f m), niente davanti %s" % [nome, peggio_fuori, peggio_dentro, davanti])
		var giu := space.intersect_ray(PhysicsRayQueryParameters3D.create(d.global_position + verso * 0.2, d.global_position + verso * 0.2 + Vector3.DOWN * 3))
		var pav: float = (giu.position as Vector3).y if giu else NAN
		var alto := d.global_position.y - pav
		check(alto >= 0.8 and alto <= 1.25 and absf(alto - d.altezza) < 0.005,
				"%s: il centro a %.2f m dal pavimento (altezza %.2f)" % [nome, alto, d.altezza])
		var p := d.get_node_or_null(^"Pastello") as Node3D
		if p:
			var pa := _aabb(p)
			check(absf(pa.position.y - pav) < 0.005, "%s: il pastello appoggiato (%.4f m)" % [nome, pa.position.y - pav])
		for dec: Decal in d.find_children("Impronta*", "Decal", false, false):
			var g := space.intersect_ray(PhysicsRayQueryParameters3D.create(dec.global_position + Vector3.UP * 0.3, dec.global_position + Vector3.DOWN * 0.3))
			if not g or absf((g.position as Vector3).y - dec.global_position.y) > 0.02:
				check(false, "%s: l'impronta %s sul pavimento" % [nome, dec.name])
				break
