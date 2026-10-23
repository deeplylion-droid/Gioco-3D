extends Node
## Test dei tentacoli morbidi di lei che sbuca dalla fossa (tappa 8, LeiSbuca._sbuca):
## - mentre sale la morbidezza è spenta (la posa scende tutta di 2,3 m e i tentacoli stesi sul pavimento salgono
##   attraverso il pavimento: com'era; si misura e si stampa);
## - su, si accende piano (0,4 s) senza scatti; poi, affacciata:
## - nessun punto o tratto dei tentacoli dentro il bordo, il pavimento, le pareti, il fondo o la griglia, né attraverso
##   la collisione vera, con 1 cm di tolleranza sull'asse;
## - niente scatti, tratti vicini alla lunghezza di riposo;
## - costo: 2 ms in media e 4 nel 95% dei fotogrammi; quando si accende nessun fotogramma sopra i 5 ms.
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
		# la salita: la morbidezza spenta (la posa com'era: si misura e basta)
		mis.inizia()
		lei.call(&"_sbuca")
		while lei.fase == LeiSbuca.Fase.SBUCA:
			await get_tree().process_frame
		mis.ferma()
		var rs: Dictionary = mis.risultati("%s, la salita (morbidezza spenta, la posa com'era)" % nome)
		_check(rs["scarto"] < 1e-4, "%s: mentre sale la posa resta quella di prima (%.5f m)" % [nome, rs["scarto"]])
		# su: si accende piano (0,4 s), poi affacciata
		mis.inizia()
		var t := 0.0
		while t < 1.5:
			await get_tree().process_frame
			t += get_process_delta_time()
		mis.ferma()
		_check(m.quanto == 1.0 and lei.fase == LeiSbuca.Fase.GUARDA, "%s: la morbidezza accesa, e lei affacciata" % nome)
		var r: Dictionary = mis.risultati("%s, su (dalla dissolvenza)" % nome)
		_check(r["salto"] < 25.0, "%s: niente scatti quando si accende (%.1f m/s più della posa)" % [nome, r["salto"]])
		_check(r["primi"] < 5.0, "%s: quando si accende nessun fotogramma sopra i 5 ms (%.2f)" % [nome, r["primi"]])
		var dopo := int(round(0.45 / maxf(get_process_delta_time(), 1.0 / 240.0)))
		var r2: Dictionary = mis.risultati("%s, affacciata (dopo la dissolvenza)" % nome, dopo)
		_check(r2["dentro"] == 0 and r2["attraversa"] == 0, "%s: affacciata, tentacoli fuori dal mondo (%d punti dentro, %d tratti)" % [nome, r2["dentro"], r2["attraversa"]])
		_check(r2["scarto"] > 0.05, "%s: i tentacoli si muovono davvero (al più %.2f m dalla posa)" % [nome, r2["scarto"]])
		_check(r2["stira_min"] > 0.15 and r2["stira_max"] < 2.0, "%s: tratti vicini alla lunghezza di riposo (%.2f-%.2f)" % [nome, r2["stira_min"], r2["stira_max"]])
		_check(r["medio"] < 2.0 and r["p95"] < 4.0, "%s: costo sotto 2 ms in media e 4 nel 95%% (%.2f e %.2f)" % [nome, r["medio"], r["p95"]])
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	get_tree().quit(1 if _ko > 0 else 0)
