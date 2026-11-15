extends Node
## Test dei movimenti del bambino col cubo della build 0.5.0 «la storia» (Bambino, modalità DISEGNA e PORGE), nella scena
## di prova:
## 1. i due modelli hanno le animazioni nuove, la matita (nascosta) e il punto del foglio;
## 2. disegna: in ginocchio con la matita in mano; se non lo guardi continua a disegnare; quando lo guardi alza la testa
##    verso di te per 1 s (segnale alza_la_testa, lo sguardo ti segue), si tira su (si_alza, 0,6 s) e scappa (parte e corsa);
## 3. porge: due passi (cammina) e porge il foglio con le due mani (segnale porge_il_foglio, porge e poi porge_tiene); il
##    punto del foglio sta fra le mani, davanti al petto, dritto verso dove guarda il bambino; non scappa anche se gli sei
##    vicino.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_bambino_storia.gd

const LEVEL := "res://scenes/test/test_level.tscn"
const CUBO := "res://scenes/creature/bambino_cubo.tscn"

var level: Node
var p: Player
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


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	_modelli()
	get_tree().change_scene_to_file(LEVEL)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 90000:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and not GameState.is_dying:
			break
	await _frames(3)
	level = get_tree().current_scene
	p = GameState.player
	var manichino := level.get_node_or_null("SalaVasche/Manichino")
	if manichino:
		manichino.process_mode = Node.PROCESS_MODE_DISABLED
	await _disegna()
	await _porge()
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	Game.esci(1 if _ko > 0 else 0)


func _modelli() -> void:
	print("1. Le animazioni, la matita, il foglio")
	var b := (load(CUBO) as PackedScene).instantiate() as Bambino
	for nome in ["Calmo", "Rivelato"]:
		var m := b.get_node(nome)
		var ap := m.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var mancano: Array[String] = []
		for a in Bambino.STORIA:
			if ap == null or not ap.has_animation(a):
				mancano.append(a)
		check(mancano.is_empty(), "%s ha disegna, alza_testa, si_alza, porge e porge_tiene %s" % [nome, mancano])
		check(not m.find_children("matita*", "", true, false).is_empty(), "%s ha la matita nella mano destra" % nome)
		var sk := m.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		check(sk.find_bone("foglio") >= 0, "%s ha l'osso del foglio" % nome)
	b.free()


func _bambino(dove: Vector3, verso_y: float) -> Bambino:
	var b := (load(CUBO) as PackedScene).instantiate() as Bambino
	b.modalita = Bambino.Modalita.SPARITO
	b.libera_quando_sparisce = false
	b.partenza_continua = true
	b.fermo_vivo = true
	level.add_child(b)
	b.global_position = dove
	b.rotation.y = verso_y
	b.visible = true
	await _frames(2)
	return b


func _disegna() -> void:
	print("2. Disegna, alza la testa, scappa")
	var b := await _bambino(Vector3(0.5, 0.0, 1.0), 0.0)
	var ev := {}
	for s in [&"alza_la_testa", &"scappa", &"sparito"]:
		b.connect(s, func() -> void: ev[s] = ev.get(s, 0) + 1)
	b.distanza_alza_testa = 3.0
	b.punti_fuga = []
	b.distanza_fuga_libera = 6.0
	b.disegna()
	# il giocatore a 4,2 m, girato dall'altra parte
	p.teleport(Vector3(0.5, 0.0, 5.2), 0.0, 0.0)
	p.look_at_point(Vector3(6.0, 1.4, 5.2))
	await _frames(int(60 * 3.0))
	var ap := b.get_node("Calmo").find_child("AnimationPlayer", true, false) as AnimationPlayer
	var matite := b.get_node("Calmo").find_children("matita*", "", true, false)
	check(b.modalita == Bambino.Modalita.DISEGNA and ap.current_animation == &"disegna" and not ev.has(&"alza_la_testa"),
			"se non lo guardi resta in ginocchio a disegnare (%s)" % ap.current_animation)
	check(not matite.is_empty() and (matite[0] as Node3D).is_visible_in_tree(), "con la matita in mano")
	# lo guardi
	var t := 0.0
	var t_alza := -1.0
	var t_scappa := -1.0
	var sguardo_max := -1.0
	var sk := b.get_node("Calmo").find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var testa := sk.find_bone("Head")
	for i in 60 * 5:
		p.look_at_point(b.punto_testa() + Vector3.DOWN * 0.5)
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		if ev.has(&"alza_la_testa") and t_alza < 0.0:
			t_alza = t
		if t_alza >= 0.0 and t_scappa < 0.0 and t - t_alza > 0.7 and t - t_alza < 1.0:
			# la faccia del cubo (avanti a riposo, +Z del modello) verso il giocatore
			var dev := sk.get_bone_global_pose(testa).basis.orthonormalized() * sk.get_bone_global_rest(testa).basis.orthonormalized().inverse()
			var avanti := (sk.global_basis * dev * (sk.global_basis.inverse() * b.global_basis.z)).normalized()
			var c := sk.global_transform * sk.get_bone_global_pose(testa).origin
			sguardo_max = maxf(sguardo_max, avanti.dot((p.get_eye_position() - c).normalized()))
		if ev.has(&"scappa") and t_scappa < 0.0:
			t_scappa = t
			break
	check(t_alza >= 0.0 and t_alza < 1.0, "quando lo guardi alza la testa (dopo %.2f s)" % t_alza)
	check(sguardo_max > 0.85, "e ti guarda (faccia verso di te: %.2f)" % sguardo_max)
	var dopo := t_scappa - t_alza
	check(t_scappa >= 0.0 and absf(dopo - 1.6) < 0.2, "1 s con la testa alzata, si tira su in 0,6 s e scappa (%.2f s)" % dopo)
	# (il giocatore è davanti: prima si volta sul posto coi passi della camminata, poi corre)
	var corre := false
	for i in 60 * 3:
		await get_tree().physics_frame
		if ap.current_animation == &"corsa":
			corre = true
			break
	check(corre, "si volta e scappa di corsa")
	b.queue_free()
	await _frames(2)


func _porge() -> void:
	print("3. Porge il foglio")
	var b := await _bambino(Vector3(0.5, 0.0, 1.0), 0.0)
	var ev := {}
	for s in [&"porge_il_foglio", &"scappa"]:
		b.connect(s, func() -> void: ev[s] = ev.get(s, 0) + 1)
	var meta := Marker3D.new()
	level.add_child(meta)
	meta.global_position = Vector3(0.5, 0.0, 1.8)
	p.teleport(Vector3(0.5, 0.0, 3.5), 0.0, 0.0)
	p.look_at_point(Vector3(0.5, 0.8, 1.0))
	b.porge([meta] as Array[Node3D])
	var ap := b.get_node("Calmo").find_child("AnimationPlayer", true, false) as AnimationPlayer
	var cammina := false
	var t := 0.0
	var t_porge := -1.0
	for i in 60 * 8:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		if ap.current_animation == &"cammina":
			cammina = true
		if ev.has(&"porge_il_foglio") and t_porge < 0.0:
			t_porge = t
	check(cammina and t_porge > 0.5, "fa i passi e porge il foglio (dopo %.1f s)" % t_porge)
	check(b.global_position.distance_to(meta.global_position) < 0.15, "fermo dove doveva arrivare (%.2f m)" % b.global_position.distance_to(meta.global_position))
	check(ap.current_animation == &"porge_tiene", "poi lo tiene (%s)" % ap.current_animation)
	check(not ev.has(&"scappa") and b.modalita == Bambino.Modalita.PORGE, "non scappa anche col giocatore a meno di 2 m")
	var f := b.punto_foglio()
	check(f != null, "c'è il punto del foglio")
	if f == null:
		return
	var sk := b.get_node("Calmo").find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var ml := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("LeftHand")).origin
	var mr := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("RightHand")).origin
	var c := f.global_position
	var loc := b.to_local(c)
	check(c.distance_to(ml) < 0.2 and c.distance_to(mr) < 0.2 and absf(b.to_local((ml + mr) / 2).x - loc.x) < 0.03,
			"il foglio fra le mani (%.2f e %.2f m dai polsi)" % [c.distance_to(ml), c.distance_to(mr)])
	check(loc.z > 0.15 and loc.y > 0.45 and loc.y < 0.75, "davanti al petto (%s)" % loc)
	var bs := f.global_basis
	check(bs.z.normalized().dot(b.global_basis.z) > 0.98 and bs.y.normalized().dot(Vector3.UP) > 0.98 \
			and absf(bs.get_scale().x - 1.0) < 0.02, "dritto, la faccia verso dove guarda il bambino, scala 1 (%s)" % bs.get_scale())
	b.queue_free()
