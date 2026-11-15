extends Node
## Test del motore «l'acqua è sua» (AcquaDiLei, build 0.4.0), in una scena di prova col giocatore vero:
## 1. prima che le pompe siano riaccese lei non viene; dopo sì;
## 2. le fasi in ordine (lontana, arriva, silenzio, esce, su, scende, calma, lontana) coi loro tempi, la luce rosa che
##    arriva sotto il punto d'uscita, vicinanza da 0 a 1, il gruppo per il canto;
## 3. mai in due posti: mentre è in una vasca, l'altra non la può chiamare; libera dopo;
## 4. la respinta: 0,5 s di getto in faccia mentre è su la ricacciano sotto, e lo specchio resta calmo;
## 5. «solo paura» (letale spento): vicina non prende;
## 6. l'uscita dimostrativa: dal punto più lontano, non prende; la volta dopo dal più vicino;
## 7. la presa: vicina, esce e ti prende (GameState.kill_player(&"medusa")).
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_acqua_di_lei.gd

var _ok := 0
var _ko := 0
var _radice: Node3D
var _p: Player


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


## Aspetta (al più [param secondi]) che [param a] arrivi alla fase [param f]; ritorna i secondi passati (-1 se no).
func _aspetta_fase(a: AcquaDiLei, f: AcquaDiLei.Fase, secondi: float) -> float:
	var t := 0.0
	while t < secondi:
		if a.fase == f:
			return t
		await get_tree().physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
	return t if a.fase == f else -1.0


func _vasca(nome: String, punti: Array) -> AcquaDiLei:
	var a := AcquaDiLei.new()
	a.name = nome
	a.pelo = 0.0
	a.pausa_dopo = 0.5
	a.pausa_respinta = 1.0
	var lista: Array[Node3D] = []
	for i in punti.size():
		var m := Marker3D.new()
		m.name = "Uscita%d" % i
		a.add_child(m)
		m.position = punti[i]
		lista.append(m)
	a.punti_uscita = lista
	_radice.add_child(a)
	return a


func _metti_giocatore(pos: Vector3) -> void:
	for i in 3:
		_p.teleport(pos)
		await get_tree().physics_frame


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	GameState.imposta_luci(GameState.Luci.PRIMA_DEL_RISVEGLIO)
	_radice = Node3D.new()
	_radice.name = "ProvaAcquaDiLei"
	get_tree().root.add_child(_radice)
	get_tree().current_scene = _radice
	var pav := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 0.2, 80)
	cs.shape = box
	pav.add_child(cs)
	pav.position = Vector3(0, -0.1, 0)
	_radice.add_child(pav)
	_p = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	_radice.add_child(_p)
	await _fisica(5)
	await _metti_giocatore(Vector3(0, 0.05, -10))
	var a := _vasca("VascaA", [Vector3(0, 0, 6)])
	var b := _vasca("VascaB", [Vector3(25, 0, 0)])
	b.zona_raggio = 40.0     # (la B a 27 m dal giocatore: la sua zona arriva fin qui; la regola della zona è nel punto 11)
	await _fisica(10)

	print("1. Le pompe")
	check(not a.chiama(), "prima che le pompe siano riaccese lei non viene")
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	await _fisica(2)
	check(get_tree().get_nodes_in_group(AcquaDiLei.GRUPPO).size() == 2, "le due vasche sono nel gruppo del canto")

	print("2. Le fasi")
	check(a.chiama() and a.fase == AcquaDiLei.Fase.ARRIVA, "dopo il blackout la si chiama: arriva")
	print("3. Mai in due posti")
	check(not b.chiama() and b.fase == AcquaDiLei.Fase.LONTANA and AcquaDiLei.chi_la_usa() == a,
			"mentre arriva nella vasca A, la B non la può chiamare")
	check(a.fase_canto == &"arriva", "per il canto: arriva (%s)" % a.fase_canto)
	await _fisica(60)
	var v_meta := a.vicinanza
	var t_spe := await _aspetta_fase(a, AcquaDiLei.Fase.SPEGNE, 4.0)
	check(t_spe >= 0.0 and v_meta > 0.05 and v_meta < 0.9, "la luce arriva in 2 s (vicinanza a metà %.2f), poi il canto si spegne" % v_meta)
	var sotto := Vector3(0, -0.6, 6)
	check(a.punto_luce.distance_to(sotto) < 0.2 and a.vicinanza >= 0.99 and a.fase_canto == &"spegne",
			"mentre il canto si spegne la luce è sotto il punto d'uscita (%s), vicinanza 1, fase per il canto %s" % [str(a.punto_luce), a.fase_canto])
	var t_sil := await _aspetta_fase(a, AcquaDiLei.Fase.SILENZIO, 2.0)
	check(t_sil >= 0.9 and t_sil <= 1.1 and a.fase_canto == &"silenzio", "dopo 1 s di spegnimento il silenzio vero (%.2f s)" % t_sil)
	var t_esce := await _aspetta_fase(a, AcquaDiLei.Fase.ESCE, 1.5)
	check(t_esce >= 0.4 and t_esce <= 0.6 and a.fase_canto == &"fuori", "esce dopo mezzo secondo di silenzio (%.2f s)" % t_esce)
	var t_su := await _aspetta_fase(a, AcquaDiLei.Fase.SU, 3.0)
	check(t_su > 0.3, "è fuori dall'acqua (salita %.2f s)" % t_su)
	var t_giu := await _aspetta_fase(a, AcquaDiLei.Fase.SCENDE, 4.0)
	check(t_giu >= 2.0 and not GameState.is_dying, "lontano non ti prende: ti cerca per %.2f s e torna sotto" % t_giu)
	await _aspetta_fase(a, AcquaDiLei.Fase.CALMA, 4.0)
	var t_lon := await _aspetta_fase(a, AcquaDiLei.Fase.LONTANA, 2.0)
	check(t_lon >= 0.4 and AcquaDiLei.chi_la_usa() == null, "poi di nuovo lontana, libera (%.2f s di calma)" % t_lon)
	check(b.chiama(), "adesso la B la può chiamare")
	await _aspetta_fase(b, AcquaDiLei.Fase.LONTANA, 12.0)
	await _fisica(5)

	print("4. La respinta")
	check(a.chiama(), "di nuovo nella vasca A")
	await _aspetta_fase(a, AcquaDiLei.Fase.SU, 6.0)
	var viso := a.find_child("Viso", true, false) as WaterHitbox
	check(viso != null, "c'è il viso da colpire")
	if viso:
		for i in 12:     # 0,2 s di getto: non basta
			viso.water_hit.emit(0.1, viso.global_position, Vector3.FORWARD)
			await get_tree().physics_frame
		check(a.fase == AcquaDiLei.Fase.SU, "0,2 s di getto non bastano")
		for i in 30:     # altri 0,5 s
			viso.water_hit.emit(0.1, viso.global_position, Vector3.FORWARD)
			await get_tree().physics_frame
			if a.fase == AcquaDiLei.Fase.SCENDE:
				break
	check(a.fase == AcquaDiLei.Fase.SCENDE, "col getto in faccia per 0,5 s torna sotto")
	await _aspetta_fase(a, AcquaDiLei.Fase.CALMA, 4.0)
	await _fisica(20)
	check(a.fase == AcquaDiLei.Fase.CALMA and not a.chiama(), "dopo la respinta lo specchio resta calmo")
	await _aspetta_fase(a, AcquaDiLei.Fase.LONTANA, 3.0)

	print("5. Solo paura")
	await _metti_giocatore(Vector3(0, 0.05, 4.5))
	a.letale = false
	check(a.chiama(), "chiamata col giocatore a 1,5 m dall'uscita")
	var t_giu2 := await _aspetta_fase(a, AcquaDiLei.Fase.SCENDE, 9.0)
	check(t_giu2 >= 0.0 and not GameState.is_dying, "con letale spento non prende: torna sotto")
	await _aspetta_fase(a, AcquaDiLei.Fase.LONTANA, 6.0)
	a.letale = true

	print("6. L'uscita dimostrativa")
	var c := _vasca("VascaC", [Vector3(-3, 0, 2), Vector3(-3, 0, 14)])
	c.prima_volta_dimostrativa = true
	await _metti_giocatore(Vector3(-3, 0.05, 3.5))
	await _fisica(5)
	check(c.chiama(), "la prima volta")
	await _aspetta_fase(c, AcquaDiLei.Fase.ESCE, 4.0)
	check(c.get(&"_punto") == c.punti_uscita[1], "la prima volta esce dal punto più lontano")
	await _aspetta_fase(c, AcquaDiLei.Fase.SCENDE, 8.0)
	check(not GameState.is_dying, "e non prende")
	await _aspetta_fase(c, AcquaDiLei.Fase.LONTANA, 6.0)

	print("8. La luce che passa senza che lei esca")
	await _metti_giocatore(Vector3(10, 0.05, -10))
	var giro := PackedVector3Array([Vector3(25, -0.6, 8), Vector3(25, -0.6, 2), Vector3(25, -0.6, -4)])
	check(b.percorri(giro, 4.0) and AcquaDiLei.chi_la_usa() == b, "la luce percorre la vasca B: lei è lì")
	check(not a.chiama(), "intanto non può venire nella A")
	await _fisica(60)
	check(b.fase == AcquaDiLei.Fase.LONTANA and b.in_giro() and b.punto_luce.distance_to(Vector3(25, -0.6, 4)) < 3.0,
			"la luce passa sott'acqua senza che lei esca (%s)" % str(b.punto_luce))
	for i in 240:
		await get_tree().physics_frame
		if not b.in_giro():
			break
	check(not b.in_giro() and AcquaDiLei.chi_la_usa() == null and b.fase == AcquaDiLei.Fase.LONTANA,
			"alla fine la luce si spegne e lei se ne va (libera)")
	var giro2 := PackedVector3Array([Vector3(30, -0.6, 8), Vector3(25, -0.6, 0)])
	check(b.percorri(giro2, 4.0, b.punti_uscita[0]), "un percorso che finisce sotto un punto d'uscita")
	var t_arr := await _aspetta_fase(b, AcquaDiLei.Fase.ARRIVA, 4.0)
	check(t_arr >= 0.0, "alla fine del percorso lei viene lì: l'avviso")
	await _aspetta_fase(b, AcquaDiLei.Fase.LONTANA, 15.0)
	await _fisica(5)

	print("9. Il giro e il punto sopra cui passa la luce")
	var anello := PackedVector3Array([Vector3(25, -0.6, 4), Vector3(25, -0.6, -4)])
	check(b.gira(anello, 6.0), "la luce gira nella vasca B")
	var visto := false
	for i in 120:
		await get_tree().physics_frame
		if b.punto_vicino_alla_luce(1.0) == b.punti_uscita[0]:
			visto = true
			break
	check(visto, "la luce passa sopra il punto d'uscita e la zona lo sa")
	b.smetti_giro(Vector3(25, -0.6, 0), 0.3)
	for i in 60:
		await get_tree().physics_frame
	check(not b.in_giro() and AcquaDiLei.chi_la_usa() == null, "finito il giro lei è libera")

	print("10. La luce che si ferma, la si chiama da lì o la si manda via")
	var corto := PackedVector3Array([Vector3(30, -0.6, 4), Vector3(25, -0.6, 3)])
	check(b.percorri(corto, 6.0, null, 0.0), "un percorso con la luce che resta accesa alla fine")
	for i in 120:
		await get_tree().physics_frame
	check(b.in_giro() and AcquaDiLei.chi_la_usa() == b and b.fase == AcquaDiLei.Fase.LONTANA
			and b.punto_luce.distance_to(Vector3(25, -0.6, 3)) < 0.05, "alla fine resta ferma lì, lei è qui")
	b.manda_via(0.3)
	for i in 40:
		await get_tree().physics_frame
	check(not b.in_giro() and AcquaDiLei.chi_la_usa() == null and b.fase == AcquaDiLei.Fase.LONTANA,
			"mandata via: la luce si allontana e si spegne, lei è libera")
	check(b.percorri(corto, 6.0, null, 0.0), "di nuovo, ferma alla fine")
	for i in 120:
		await get_tree().physics_frame
	check(b.chiama(b.punti_uscita[0]) and b.fase == AcquaDiLei.Fase.ARRIVA, "e la si chiama da dove sta")
	await _fisica(30)
	b.manda_via(0.3)
	for i in 40:
		await get_tree().physics_frame
	check(b.fase == AcquaDiLei.Fase.LONTANA and AcquaDiLei.chi_la_usa() == null, "mandata via durante l'avviso: non esce")
	check(b.chiama(), "si può chiamare di nuovo")
	await _aspetta_fase(b, AcquaDiLei.Fase.SU, 8.0)
	b.manda_via()
	check(b.fase == AcquaDiLei.Fase.SCENDE, "mandata via quando è fuori: come la respinta")
	await _aspetta_fase(b, AcquaDiLei.Fase.LONTANA, 6.0)

	print("11. La zona: nessuno specchio tiene lei da lontano")
	var z := _vasca("VascaZ", [Vector3(-40, 0, 0)])
	await _metti_giocatore(Vector3(-40, 0.05, -10))
	await _fisica(3)
	check(z.gira(PackedVector3Array([Vector3(-42, -0.6, 0), Vector3(-38, -0.6, 0)]), 1.6) and AcquaDiLei.chi_la_usa() == z,
			"col giocatore nella zona la luce gira qui")
	await _metti_giocatore(Vector3(-40, 0.05, -40))
	await _fisica(3)
	check(AcquaDiLei.chi_la_usa() == null and not z.in_giro() and not z.puo_venire(),
			"uscito dalla zona (30 m): lei se ne va subito e da qui non viene")
	await _metti_giocatore(Vector3(-40, 9.05, -5))
	await _fisica(3)
	check(not z.puo_venire(), "vicino in pianta ma 9 m sopra (un altro piano): non viene")
	z.queue_free()
	await _fisica(2)

	print("7. La presa")
	await _metti_giocatore(Vector3(-3, 0.05, 3.5))
	check(c.chiama(), "la seconda volta")
	await _aspetta_fase(c, AcquaDiLei.Fase.ESCE, 4.0)
	check(c.get(&"_punto") == c.punti_uscita[0], "esce dal punto più vicino")
	var t_presa := await _aspetta_fase(c, AcquaDiLei.Fase.PRESA, 6.0)
	check(t_presa >= 0.0 and GameState.is_dying and GameState.last_death_cause == &"medusa",
			"vicina ti prende: la scena di morte della medusa")
	_fine()


func _fine() -> void:
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	Game.esci(1 if _ko > 0 else 0)
