extends Node
## Test del modo MANO di AcquaDiLei (build 0.4.0, le pozze della Risalita; scelta C dell'utente):
## 1. esce col marker (non si gira): pozza_esce, la mano sbatte sul grigliato vicino al marker, poi pozza_attesa;
## 2. il bersaglio del getto è la mano: 0,5 s di getto sulla mano la ricacciano sotto (pozza_respinta), poi sparisce;
## 3. fuori dalla portata della mano (1,2 m) non prende e torna sotto da sola (pozza_scende);
## 4. sulla passerella davanti alla pozza (0,6 m) ti prende alla caviglia: pozza_presa e la scena di morte della medusa.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_acqua_di_lei_mano.gd

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


func _aspetta_fase(a: AcquaDiLei, f: AcquaDiLei.Fase, secondi: float) -> float:
	var t := 0.0
	while t < secondi:
		if a.fase == f:
			return t
		await get_tree().physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
	return t if a.fase == f else -1.0


func _metti_giocatore(pos: Vector3) -> void:
	for i in 3:
		_p.teleport(pos)
		await get_tree().physics_frame


func _in_corso(a: AcquaDiLei) -> StringName:
	var ap := a.find_child("AnimationPlayer", true, false) as AnimationPlayer
	return ap.current_animation if ap else &""


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	_radice = Node3D.new()
	_radice.name = "ProvaMano"
	get_tree().root.add_child(_radice)
	get_tree().current_scene = _radice
	var pav := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 0.2, 40)
	cs.shape = box
	pav.add_child(cs)
	pav.position = Vector3(0, -0.1, 0)
	_radice.add_child(pav)
	_p = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	_radice.add_child(_p)
	await _fisica(5)
	# la pozza: il marker dove sbatte la mano, girato di 90 gradi (la passerella verso +X del mondo)
	var a := AcquaDiLei.new()
	a.name = "Pozza"
	a.modo = AcquaDiLei.Modo.MANO
	a.pelo = -0.0525
	a.pausa_dopo = 0.5
	a.pausa_respinta = 1.0
	var m := Marker3D.new()
	m.name = "Uscita0"
	a.add_child(m)
	m.position = Vector3(2, 0, 3)
	m.rotation = Vector3(0, PI * 0.5, 0)
	var lista: Array[Node3D] = [m]
	a.punti_uscita = lista
	_radice.add_child(a)
	var fuori := m.global_transform * Vector3(0, 0, 1.6)     # sulla passerella, fuori dalla portata della mano
	var davanti := m.global_transform * Vector3(0, 0, 0.6)   # davanti alla pozza: la caviglia
	await _metti_giocatore(Vector3(fuori.x, 0.05, fuori.z))
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	await _fisica(5)

	print("1. Esce la mano")
	a.letale = false
	check(a.chiama(), "si chiama")
	var t_esce := await _aspetta_fase(a, AcquaDiLei.Fase.ESCE, 5.0)
	var lei := a.find_child("LeiNellAcqua", true, false) as Node3D
	check(t_esce >= 0.0 and lei != null and lei.visible and _in_corso(a) == &"inseguimento/pozza_esce", "esce con pozza_esce")
	check(lei != null and lei.global_transform.is_equal_approx(m.global_transform), "col marker: non si gira verso il giocatore")
	await _fisica(int((AcquaDiLei.MANO_SBATTE + 0.15) * 60))
	var viso := a.find_child("Viso", true, false) as WaterHitbox
	var d_mano := viso.global_position.distance_to(m.global_position) if viso else 99.0
	check(d_mano < 0.25, "la mano sbatte sul grigliato al marker e il bersaglio del getto la segue (a %.2f m)" % d_mano)
	var t_su := await _aspetta_fase(a, AcquaDiLei.Fase.SU, 3.0)
	check(t_su >= 0.0 and _in_corso(a) == &"inseguimento/pozza_attesa", "poi i tentacoli e l'attesa (pozza_attesa)")

	print("2. Il getto sulla mano")
	for i in 40:
		viso.water_hit.emit(0.1, viso.global_position, Vector3.DOWN)
		await get_tree().physics_frame
		if a.fase == AcquaDiLei.Fase.SCENDE:
			break
	check(a.fase == AcquaDiLei.Fase.SCENDE and _in_corso(a) == &"inseguimento/pozza_respinta", "col getto sulla mano torna sotto (pozza_respinta)")
	await _aspetta_fase(a, AcquaDiLei.Fase.CALMA, 3.0)
	check(not lei.visible, "e sparisce sotto il fondo")
	await _aspetta_fase(a, AcquaDiLei.Fase.LONTANA, 3.0)

	print("3. Fuori dalla portata della mano")
	a.letale = true
	check(a.chiama(), "si chiama di nuovo, col giocatore a 1,6 m")
	await _aspetta_fase(a, AcquaDiLei.Fase.SU, 8.0)
	var t_giu := await _aspetta_fase(a, AcquaDiLei.Fase.SCENDE, 4.0)
	check(t_giu >= 0.0 and not GameState.is_dying and _in_corso(a) == &"inseguimento/pozza_scende", "non ti arriva: torna sotto da sola (pozza_scende)")
	await _aspetta_fase(a, AcquaDiLei.Fase.LONTANA, 4.0)

	print("4. La presa alla caviglia")
	await _metti_giocatore(Vector3(davanti.x, 0.05, davanti.z))
	check(a.chiama(), "si chiama col giocatore davanti alla pozza")
	var t_presa := await _aspetta_fase(a, AcquaDiLei.Fase.PRESA, 8.0)
	check(t_presa >= 0.0 and _in_corso(a) == &"inseguimento/pozza_presa", "ti prende: pozza_presa")
	check(GameState.is_dying and GameState.last_death_cause == &"medusa", "con la scena di morte della medusa")
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	Game.esci(1 if _ko > 0 else 0)
