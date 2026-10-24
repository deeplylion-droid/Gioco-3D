extends Node
## Test dei tentacoli morbidi di lei nell'inseguimento (scena di prova scenes/test/inseguimento_prova.tscn): in ogni
## posto dove sale (le tre vasche, le tre vasche di scolo, la grata, SB1 dal pozzo) dalla salita a 2 s dopo:
## - nessun tratto dei tentacoli attraverso la collisione vera della sala (raggi: muri, pavimenti, vasche, gambe, tubi;
##   la sala è una mesh sola e la morbidezza qui non ha forme: le animazioni tengono già i tentacoli fuori);
## - niente scatti, tratti vicini alla lunghezza di riposo;
## - costo: 4 ms in media e 8 nel 95% dei fotogrammi; quando compare nessun fotogramma sopra i 10 ms (CPU del sandbox,
##   non del gioco vero; in CI solo stampato);
## - i casi noti ([constant NOTI]): si stampano, e lì quel controllo dell'asse ammette al più quei tratti.
## Uso: godot --headless --path godot --fixed-fps 30 --script res://tests/run.gd -- res://tests/test_morbidezza_inseguimento.gd

const LEVEL := "res://scenes/test/inseguimento_prova.tscn"
const Misura := preload("res://tests/misura_morbidezza.gd")
## I casi noti, come i "voluto" del controllo di posizionamento: posto -> [tratti dell'asse ammessi, motivo, data].
## Solo il controllo dell'asse: la pelle vera resta bloccante anche lì.
const NOTI := {
	"vasca_2": [2, "la posa dell'animazione mette la punta di un tentacolo dentro un muro sottile nel primo fotogramma: va corretta nell'animazione, non nella morbidezza", "24 ottobre"],
}

var _ok := 0
var _ko := 0
var sala: SalaInseguimento


func _ready() -> void:
	_run.call_deferred()


## Il costo dipende dalla macchina: in CI (variabile CI) si stampa e basta, le collisioni invece bloccano.
func _check_costo(cond: bool, msg: String) -> void:
	if OS.has_environment("CI"):
		print("  (CI: solo stampato) %s  %s" % ["ok" if cond else "oltre", msg])
	else:
		_check(cond, msg)


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
	for i in 600:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and GameState.player.input_enabled:
			break
	sala = get_tree().current_scene.get_node("SalaInseguimento") as SalaInseguimento
	sala.tempo_presa = 1e6
	for i in 5:
		await get_tree().process_frame
	var m := MorbidezzaLei.su(sala.lei)
	var sk := m.get_parent() as Skeleton3D
	var mis = Misura.new(sk, m)
	print("catene ", mis.catene.size())
	for dove in ["vasca_0", "vasca_1", "vasca_2", "scolo_0", "scolo_1", "scolo_2", "grata", "sb1"]:
		# (SOLO=sb1,grata: solo quei posti, per provare)
		if OS.has_environment("SOLO") and not dove in OS.get_environment("SOLO").split(","):
			continue
		print("== ", dove)
		mis.inizia()
		match dove:
			"grata":
				sala.call(&"_lei_alla_grata")
			"sb1":
				sala.call(&"_lei_sale", "sb1", sala.call(&"_posto_sb1"), 1.3)
			_:
				var su: Vector3 = sala.call(&"_posto_vasca", int(dove[-1])) if dove.begins_with("vasca") else sala.call(&"_posto_scolo", int(dove[-1]))
				sala.call(&"_lei_sale", dove, su, 1.2 if dove.begins_with("scolo") else 1.6)
		var durata := float(sala.get_meta(&"durata_salita", 1.6)) + 2.0
		var t := 0.0
		while t < durata:
			await get_tree().process_frame
			t += get_process_delta_time()
		mis.ferma()
		var r: Dictionary = mis.risultati(dove)
		_check(r["fotogrammi"] > 20, "%s: registrati %d fotogrammi" % [dove, r["fotogrammi"]])
		if OS.has_environment("PARTI"):
			print("PARTI ", m.parti_usec, " forme ", (m.get(&"_forme") as Array).size())
			m.parti_usec = {"bersagli": 0, "passi": 0, "ossa": 0, "giri": 0, "conta_passi": 0, "conta_giri": 0}
		# (dove lei sale attraverso il pavimento allagato, il foro dove passa col corpo: a parte, come la radice)
		var foro := []
		var fori: Dictionary = sala.get(&"_forme_lei_fori")
		if fori.has(dove):
			var fo: Array = fori[dove]
			foro = [sala.global_transform * Vector3(float(fo[0]), float(fo[1]), float(fo[2])), float(fo[3])]
		var pe: Dictionary = mis.pelle(dove, 0, 2, 0.01, [] as Array[RID], foro)
		_check(pe["pelle_dentro"] == 0, "%s: la pelle vera dei tentacoli fuori dalla sala (%d vertici dentro, al più %.1f cm)" % [dove, pe["pelle_dentro"], pe["pelle_massimo"] * 100.0])
		# (i casi noti: l'asse che attraversa un muro per un motivo che non è della morbidezza; la pelle resta bloccante)
		var noto: Array = NOTI.get(dove, [])
		if not noto.is_empty() and r["attraversa"] > 0:
			print("  noto  %s: %d tratti attraversano la sala (al più %d): %s (%s)" % [dove, r["attraversa"], noto[0], noto[1], noto[2]])
		_check(r["attraversa"] <= (int(noto[0]) if not noto.is_empty() else 0), "%s: nessun tratto dei tentacoli attraversa la sala (%d)" % [dove, r["attraversa"]])
		_check(r["scarto"] > 0.05, "%s: i tentacoli si muovono davvero (al più %.2f m dalla posa)" % [dove, r["scarto"]])
		_check(r["salto"] < 25.0, "%s: niente scatti (%.1f m/s più della posa)" % [dove, r["salto"]])
		_check(r["stira_min"] > 0.15 and r["stira_max"] < 2.0, "%s: tratti vicini alla lunghezza di riposo (%.2f-%.2f)" % [dove, r["stira_min"], r["stira_max"]])
		_check_costo(r["medio"] < 4.0 and r["p95"] < 8.0, "%s: costo sotto 4 ms in media e 8 nel 95%% (%.2f e %.2f)" % [dove, r["medio"], r["p95"]])
		_check_costo(r["primi"] < 10.0, "%s: quando compare nessun fotogramma sopra i 10 ms (%.2f)" % [dove, r["primi"]])
		# giù e via, per il posto dopo
		if sala.lei_stato != SalaInseguimento.Lei.VIA:
			sala.call(&"_scendi")
		for i in 120:
			await get_tree().process_frame
			if sala.lei_stato == SalaInseguimento.Lei.VIA:
				break
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	get_tree().quit(1 if _ko > 0 else 0)
