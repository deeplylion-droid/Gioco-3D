extends Node
## Test dei tentacoli morbidi di lei che sbuca dalla fossa (tappa 8, LeiSbuca._sbuca):
## - la morbidezza accesa da quando compare: la posa sale tutta da 2,3 m sotto e i tentacoli stesi sul pavimento
##   salirebbero attraverso il pavimento; la morbidezza li tiene dentro la fossa e li fa uscire dal bordo mentre lei
##   emerge. Dalla salita a 1,5 s dopo, affacciata:
## - nessun punto o tratto dei tentacoli dentro il bordo, il pavimento, le pareti, il fondo o la griglia, né attraverso
##   la collisione vera, con 1 cm di tolleranza sull'asse;
## - niente scatti, tratti vicini alla lunghezza di riposo;
## - costo: 3 ms in media e 8 nel 95% dei fotogrammi (come il tuffo: la salita dura 2 s); quando compare nessun fotogramma sopra i 5 ms.
## Due volte (la seconda dopo un checkpoint: ricomincia e sbuca di nuovo).
## Uso: godot --headless --path godot --fixed-fps 30 --script res://tests/run.gd -- res://tests/test_morbidezza_sbuca.gd

const LEVEL := "res://scenes/sala_principale.tscn"
const Misura := preload("res://tests/misura_morbidezza.gd")

var _ok := 0
var _ko := 0


func _ready() -> void:
	Engine.set_meta(&"precarica_torre_spento", true)
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
	for i in 400:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and GameState.player.input_enabled:
			break
	var level := get_tree().current_scene
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	var lei := level.get_node(^"Gioco/LeiSbuca") as LeiSbuca
	for v in lei.vasche:
		var t := v as WaterTank
		t.fill = clampf((lei.livello_pieno - t.get_floor_global_y()) / t.inner_size.y, 0.0, t.max_fill)
	lei.distanza_presa = 0.0
	GameState.player.teleport(lei.punto_sbuca.global_position + lei.punto_sbuca.global_basis.z * 7.0 + Vector3(0, 0.1, 0), 0.0, 0.0)
	await get_tree().physics_frame
	for volta in 2:
		var nome := "sbuca" if volta == 0 else "sbuca di nuovo (dopo il checkpoint)"
		print("== ", nome)
		lei.call(&"_ricomincia")
		for i in 3:
			await get_tree().process_frame
		var m := MorbidezzaLei.su(lei.medusa)
		var sk := m.get_parent() as Skeleton3D
		var mis = Misura.new(sk, m)
		mis.inizia()
		lei.call(&"_sbuca")
		var durata := lei.durata_sbuca + 1.5
		var t := 0.0
		while t < durata:
			await get_tree().process_frame
			t += get_process_delta_time()
		mis.ferma()
		_check(m.quanto == 1.0 and not m.trattieni and lei.fase == LeiSbuca.Fase.GUARDA, "%s: la morbidezza accesa, e lei su, affacciata" % nome)
		var r: Dictionary = mis.risultati(nome)
		_check(r["fotogrammi"] > 40, "%s: registrati %d fotogrammi" % [nome, r["fotogrammi"]])
		_check(r["dentro"] == 0 and r["attraversa"] == 0, "%s: tentacoli fuori dal mondo, anche mentre sale (%d punti dentro, %d tratti)" % [nome, r["dentro"], r["attraversa"]])
		_check(r["salto"] < 25.0, "%s: niente scatti (%.1f m/s più della posa)" % [nome, r["salto"]])
		_check(r["scarto"] > 0.05, "%s: i tentacoli si muovono davvero (al più %.2f m dalla posa)" % [nome, r["scarto"]])
		_check(r["stira_min"] > 0.15 and r["stira_max"] < 2.0, "%s: tratti vicini alla lunghezza di riposo (%.2f-%.2f)" % [nome, r["stira_min"], r["stira_max"]])
		# (la salita dura 2 s, come il tuffo: lo stesso limite del tuffo)
		_check(r["medio"] < 3.0 and r["p95"] < 8.0, "%s: costo sotto 3 ms in media e 8 nel 95%% (%.2f e %.2f)" % [nome, r["medio"], r["p95"]])
		_check(r["primi"] < 5.0, "%s: quando compare nessun fotogramma sopra i 5 ms (%.2f)" % [nome, r["primi"]])
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	get_tree().quit(1 if _ko > 0 else 0)
