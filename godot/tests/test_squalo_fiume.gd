extends Node
## Test della macchina a stati dello squalo nel fiume lento (SqualoFiume, build 0.5.0), con un fiume finto (un canale
## dritto lungo -Z: la guida) e il giocatore vero che fa da camera:
## 1. comincia: la pinna e la scia, a 12 m alla velocità della corrente; più vicino con la ciambella lenta (1,2 m/s),
##    più lontano con quella veloce (3,2 m/s), mai sotto 4 m;
## 2. non attacca quando la guida dice di no (imbarco, scivolo, nero, dopo una ripartenza);
## 3. l'attacco: accelera, la testa esce a 6 m, il morso dopo 4 s la prima volta (3 s dopo la prima respinta);
## 4. mezzo secondo di getto sul muso lo ricaccia sotto; poi niente attacchi per almeno 8 s;
## 5. con letale acceso arriva e morde (segnale morde); con letale spento urta (segnale urta) e torna indietro;
## 6. riparti(): di nuovo a 12 m e calmo per 3 s; tre attacchi per giro (con la durata del giro dalla guida).
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_squalo_fiume.gd

class Guida extends RefCounted:
	var s := 0.0
	var v := 2.2
	var attacca := true
	var giro := 0.0
	func ciambella() -> Vector3:
		return Vector3(0.0, 0.0, -s)
	func dietro(m: float) -> Vector3:
		return Vector3(0.0, 0.0, -s + m)
	func avanti(m: float) -> Vector3:
		return Vector3(0.0, 0.0, -s - m)
	func velocita() -> float:
		return v
	func puo_attaccare() -> bool:
		return attacca
	func durata_giro() -> float:
		return giro


var _ok := 0
var _ko := 0
var _radice: Node3D
var _g := Guida.new()
var _sq: SqualoFiume
var _segnali := {}


func _ready() -> void:
	_run.call_deferred()


func check(c: bool, msg: String) -> void:
	if c:
		_ok += 1
		print("  ok  ", msg)
	else:
		_ko += 1
		print("  KO  ", msg)


func _passa(secondi: float) -> void:
	var n := int(secondi * Engine.physics_ticks_per_second)
	for i in n:
		_g.s += _g.v / Engine.physics_ticks_per_second
		await get_tree().physics_frame


func _fino(cond: Callable, secondi: float) -> float:
	var t := 0.0
	while t < secondi:
		if cond.call():
			return t
		_g.s += _g.v / Engine.physics_ticks_per_second
		await get_tree().physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
	return -1.0


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	_radice = Node3D.new()
	_radice.name = "ProvaSqualo"
	get_tree().root.add_child(_radice)
	get_tree().current_scene = _radice
	var cam := Camera3D.new()
	_radice.add_child(cam)
	cam.current = true
	_sq = SqualoFiume.new()
	_sq.name = "Squalo"
	_radice.add_child(_sq)
	_sq.guida = _g
	for nome in ["compare", "attacca", "respinto", "morde", "urta"]:
		_segnali[nome] = 0
		_sq.connect(nome, func(): _segnali[nome] += 1)
	await get_tree().physics_frame

	print("0. Una copia sola delle texture")
	var con_tex := 0
	var superfici := 0
	for mi in _sq.squalo.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).mesh
		for i in m.get_surface_count():
			superfici += 1
			var o := (mi as MeshInstance3D).get_surface_override_material(i)
			if o is BaseMaterial3D and (o as BaseMaterial3D).albedo_texture != null \
					and (o as BaseMaterial3D).albedo_texture.resource_path.begins_with("res://assets/models/mascotte/mostro_squalo_A_rig"):
				con_tex += 1
	check(con_tex >= 1, "la pelle usa le texture del modello col rig (%d superfici su %d)" % [con_tex, superfici])

	print("1. Segue la ciambella")
	_g.attacca = false
	_sq.comincia()
	check(_sq.stato == SqualoFiume.Stato.SEGUE and _segnali["compare"] == 1 and _sq.squalo.visible, "comincia: compare, la pinna e la scia")
	await _passa(20.0)
	check(absf(_sq.dietro - 12.0) < 0.5, "alla velocità della corrente resta a 12 m (%.1f)" % _sq.dietro)
	var p := _sq.squalo.global_position
	check(absf(p.y) < 0.01 and absf(p.z - (_g.dietro(_sq.dietro).z)) < 0.01, "sul pelo, dietro la ciambella (%s)" % p)
	var sk := _sq.squalo.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var b_loc := _sq.squalo.global_transform.affine_inverse() * (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("bocca")).origin)
	var verso_ciambella := (_g.ciambella() - _sq.squalo.global_position).normalized()
	var b_mondo := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("bocca")).origin
	check(b_loc.z > 0.5 and b_loc.y < 0.0 and (b_mondo - _sq.squalo.global_position).slide(Vector3.UP).normalized().dot(verso_ciambella.slide(Vector3.UP).normalized()) > 0.95,
			"il muso avanti, verso la ciambella, e sott'acqua mentre nuota (bocca a %s)" % b_loc)
	_g.v = 1.2
	await _passa(25.0)
	var vicino := _sq.dietro
	_g.v = 3.2
	await _passa(25.0)
	var lontano := _sq.dietro
	check(vicino < 7.0 and vicino >= 4.0 and lontano > 16.0, "lenta: si avvicina (%.1f m); veloce: resta indietro (%.1f m)" % [vicino, lontano])
	_g.v = 2.2
	await _passa(20.0)

	print("2. Quando non può attaccare")
	await _passa(40.0)
	check(_segnali["attacca"] == 0 and _sq.stato == SqualoFiume.Stato.SEGUE, "40 s con la guida che dice di no: nessun attacco")

	print("3. L'attacco")
	_g.attacca = true
	var t_carica := await _fino(func(): return _sq.stato == SqualoFiume.Stato.CARICA, 30.0)
	check(t_carica >= 0.0, "quando può, accelera (dopo %.1f s)" % t_carica)
	var t_testa := await _fino(func(): return _sq.stato == SqualoFiume.Stato.ATTACCO, 10.0)
	check(t_testa >= 0.0 and _segnali["attacca"] == 1 and absf(_sq.dietro - 6.0) < 0.3, "la testa esce a 6 m (%.1f)" % _sq.dietro)
	_sq.letale = false
	var t_urto := await _fino(func(): return _segnali["urta"] > 0, 6.0)
	check(absf(t_urto - 4.0) < 0.1, "senza letale, la prima volta arriva dopo 4 s e urta la ciambella (%.2f s)" % t_urto)
	await _fino(func(): return _sq.stato == SqualoFiume.Stato.SEGUE, 5.0)
	check(_sq.stato == SqualoFiume.Stato.SEGUE and _sq.dietro > 1.0, "poi torna indietro a seguire")

	print("4. Il getto sul muso")
	await _fino(func(): return _sq.stato == SqualoFiume.Stato.ATTACCO, 60.0)
	var muso := _sq.find_child("Muso", true, false) as WaterHitbox
	await _passa(0.3)
	for i in 12:
		muso.water_hit.emit(0.1, muso.global_position, Vector3.FORWARD)
		await get_tree().physics_frame
	check(_sq.stato == SqualoFiume.Stato.ATTACCO, "0,2 s di getto non bastano")
	for i in 30:
		muso.water_hit.emit(0.1, muso.global_position, Vector3.FORWARD)
		await get_tree().physics_frame
		if _sq.stato != SqualoFiume.Stato.ATTACCO:
			break
	check(_sq.stato == SqualoFiume.Stato.RESPINTO and _segnali["respinto"] == 1, "mezzo secondo di getto sul muso: va sotto")
	var t_dopo := await _fino(func(): return _sq.stato == SqualoFiume.Stato.CARICA, 40.0)
	check(t_dopo >= 8.0, "poi niente attacchi per almeno 8 s (%.1f s)" % t_dopo)

	print("5. Il morso")
	_sq.letale = true
	await _fino(func(): return _sq.stato == SqualoFiume.Stato.ATTACCO, 20.0)
	var t_morso := await _fino(func(): return _segnali["morde"] > 0, 6.0)
	check(absf(t_morso - (3.0 + SqualoFiume.MORSO_T)) < 0.15, "dopo la prima respinta arriva in 3 s e morde (%.2f s, la bocca si chiude a +%.2f)" % [t_morso, SqualoFiume.MORSO_T])
	var bocca := _sq.squalo.global_position.distance_to(cam.global_position)
	check(bocca < 2.0, "nel morso è davanti alla camera (%.2f m)" % bocca)

	print("6. Ripartenza e attacchi per giro")
	_sq.riparti(true)
	check(_sq.stato == SqualoFiume.Stato.SEGUE and absf(_sq.dietro - 12.0) < 0.01, "riparti: di nuovo a 12 m")
	_g.giro = 60.0
	_segnali["attacca"] = 0
	_sq.letale = false
	_sq.respinto_una_volta = true
	var primo := await _fino(func(): return _sq.stato == SqualoFiume.Stato.CARICA, 4.0)
	check(primo < 0.0, "nei 3 s dopo la ripartenza non attacca")
	await _passa(120.0)
	check(_segnali["attacca"] >= 5 and _segnali["attacca"] <= 7, "in due giri da 60 s, tre attacchi per giro (%d)" % _segnali["attacca"])
	_sq.ferma()
	check(not _sq.squalo.visible and _sq.stato == SqualoFiume.Stato.ASSENTE, "ferma: sparisce")
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	Game.esci(1 if _ko > 0 else 0)
