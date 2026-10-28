extends Node
## Test della luce viola e della nebbia della scena dello squalo all'inizio (AtmosferaSqualo, richiesta dell'utente del
## 24 ottobre sera): la luce e la nebbia ci sono già col livello, spente (niente scatti al primo uso); durante la scena
## la luce viola dietro la porta è accesa, con l'ombra (lo squalo in controluce), e la nebbia è densa; quando la porta
## si chiude la luce si spegne di colpo; quando torna il controllo la nebbia si dirada e in circa 4 s non c'è più.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/test_squalo_viola.gd

const LEVEL := "res://scenes/interni/interni.tscn"

var _ok := 0
var _ko := 0


func _ready() -> void:
	_run.call_deferred()


func _check(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  ok  ", msg)
	else:
		_ko += 1
		print("  KO  ", msg)


func _run() -> void:
	Game.pause_on_focus_loss = false
	get_tree().change_scene_to_file(LEVEL)
	for i in 300:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player):
			break
	for i in 5:
		await get_tree().physics_frame
	var level := get_tree().current_scene
	var p := GameState.player
	var s := level.get_node_or_null("Gioco/RisveglioSqualo") as RisveglioSqualo
	var a := s.get_node_or_null("Atmosfera") as AtmosferaSqualo if s else null
	_check(a != null and a.luce != null and a.nebbia != null and a.luce.is_inside_tree() and a.nebbia.is_inside_tree(),
			"la luce viola e la nebbia ci sono già col livello (pronte prima della scena)")
	if a == null:
		_fine()
		return
	_check(a.luce.light_energy == 0.0 and (a.nebbia.material as FogMaterial).density == 0.0, "prima della scena sono spente")
	# la luce viene da dietro la porta (più in là dello squalo, guardando dal giocatore) e punta verso il giocatore
	var porta := s.get(&"_perno") as Node3D
	level.call(&"fai_risveglio", p, true)
	for i in 30:
		await get_tree().process_frame
	var occhio := p.camera.global_position
	var dalla_luce := (occhio - a.luce.global_position).normalized()
	_check(a.luce.light_energy > 10.0 and a.luce.shadow_enabled, "durante la scena la luce viola è accesa, fortissima e con l'ombra (%.0f)" % a.luce.light_energy)
	_check(porta == null or a.luce.global_position.distance_to(occhio) > porta.global_position.distance_to(occhio),
			"la luce sta dietro la porta, più in là dello squalo")
	_check((-a.luce.global_basis.z).dot(dalla_luce) > 0.8, "la luce punta verso il giocatore (lo squalo in controluce)")
	_check((a.nebbia.material as FogMaterial).density > 0.03,
			"la nebbia del corridoio è densa (%.2f)" % (a.nebbia.material as FogMaterial).density)
	# la nebbia sta fra il giocatore e la porta, più fitta verso la porta (il suo centro più vicino alla porta)
	_check(porta == null or a.nebbia.global_position.distance_to(porta.global_position) < a.nebbia.global_position.distance_to(occhio),
			"la nebbia è più fitta verso la porta")
	_check(a.bordo != null and a.bordo.light_energy > 1.0 and a.bordo.light_cull_mask == RisveglioSqualo.STRATO_SQUALO,
			"la controluce dietro lo squalo è accesa e illumina solo lui")
	# la porta si chiude dietro di lui: il viola si spegne
	var t := 0.0
	while t < 16.0 and not bool(s.get(&"_porta_chiusa")):
		await get_tree().process_frame
		t += get_process_delta_time()
	await get_tree().process_frame
	_check(bool(s.get(&"_porta_chiusa")) and a.luce.light_energy == 0.0, "a porta chiusa la luce viola è spenta")
	_check((a.nebbia.material as FogMaterial).density > 0.03, "la nebbia resta finché il giocatore non riprende il controllo")
	# il controllo torna: la nebbia si dirada in circa 4 s
	while t < 20.0 and not p.input_enabled:
		await get_tree().process_frame
		t += get_process_delta_time()
	_check(p.input_enabled, "il giocatore riprende il controllo")
	var t1 := 0.0
	var a_meta := -1.0
	while t1 < 5.0:
		await get_tree().process_frame
		t1 += get_process_delta_time()
		if a_meta < 0.0 and t1 >= 2.0:
			a_meta = (a.nebbia.material as FogMaterial).density
	var dopo := (a.nebbia.material as FogMaterial).density
	_check(a_meta > 0.0 and a_meta < a.densita, "a metà la nebbia si sta diradando (%.2f)" % a_meta)
	_check(dopo == 0.0 and a.luce.light_energy == 0.0 and a.bordo.light_energy == 0.0, "dopo 4 s la nebbia non c'è più (resta quella normale del gioco)")
	for i in AtmosferaSqualo.FOTOGRAMMI_PRONTA + 2:
		await get_tree().process_frame
	_check(not a.nebbia.visible, "e il volume della nebbia è nascosto (a densità zero costava lo stesso, per tutto il gioco)")
	_fine()


func _fine() -> void:
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	get_tree().quit(1 if _ko > 0 else 0)
