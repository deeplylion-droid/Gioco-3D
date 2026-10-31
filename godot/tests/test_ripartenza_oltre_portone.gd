extends Node
## Le ripartenze oltre il portone (crash della 0.3.17 su Windows, sempre in una ripartenza dopo la torre): con un
## checkpoint della torre, delle condotte o del tunnel, e con le partenze del menu di prova che ci arrivano, interni e
## tecnici non stanno in memoria insieme alla torre e al tunnel (SalaPrincipale._libera_ambienti_subito). Per le
## partenze torre, inseguimento e tunnel, e per la morte subito dopo:
## - quando la torre (o il tunnel) entra nella sala, Interni e Tecnici non ci sono già più;
## - il tunnel comincia a caricarsi nel thread solo dopo, non prima che la torre sia entrata;
## - ripartendo nel tunnel non si prepara la torre nascosta (gli acquari risolti la chiedevano);
## - dopo qualche secondo nella sala restano solo le zone di quel punto, senza errori di script.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_ripartenza_oltre_portone.gd [id,id]

const PARTENZE := ["torre", "inseguimento", "tunnel"]

var _ok := 0
var _ko := 0
## Cosa si è visto entrare, nell'ordine (per la partenza in corso).
var _visti: Array[String] = []
## Lo stato della sala nel momento in cui la torre o il tunnel ci entrano.
var _all_ingresso := {}


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
	GameState.save_to_disk = false
	var solo := PackedStringArray()
	var args := OS.get_cmdline_user_args()
	if args.size() > 1:
		solo = args[1].split(",")
	get_tree().node_added.connect(_su_nodo)
	for id in PARTENZE:
		if not solo.is_empty() and not id in solo:
			continue
		if MenuProva.istantanea(id).is_empty():
			_check(false, "%s: la partenza c'è" % id)
			continue
		print("== ", id)
		_azzera()
		_check(MenuProva.parti(get_tree(), id), "%s: parte" % id)
		await _aspetta_ripresa()
		await _controlla(id, "partenza")
		print("== %s, dopo una morte" % id)
		_azzera()
		GameState.respawn()
		await _aspetta_ripresa()
		await _controlla(id, "morte")
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	get_tree().quit(1 if _ko > 0 else 0)


func _azzera() -> void:
	_visti.clear()
	_all_ingresso.clear()


## Ogni nodo che entra: Interni, Tecnici, la torre e il tunnel della sala.
func _su_nodo(n: Node) -> void:
	var sala := n.get_parent()
	if sala == null or not &"sala_torre_scena" in sala:
		return
	var nome := str(n.name)
	var torre_scena := str(sala.get(&"sala_torre_scena"))
	var e_torre := torre_scena != "" and n.scene_file_path == torre_scena
	var e_tunnel := nome == "SalaSottomarino"
	if nome in ["Interni", "Tecnici"]:
		_visti.append(nome)
	elif e_torre or e_tunnel:
		var zona := "torre" if e_torre else "tunnel"
		_visti.append(zona)
		# (nascosta: la torre che si prepara dietro il portone, giocando di fila)
		if e_torre and n.process_mode == Node.PROCESS_MODE_DISABLED:
			_visti.append("torre_nascosta")
		_all_ingresso[zona] = {
			"interni": sala.get_node_or_null(^"Interni") != null,
			"tecnici": sala.get_node_or_null(^"Tecnici") != null or sala.get(&"tecnici") != null,
			"tunnel_nel_thread": bool(sala.get(&"_sottomarino_in_caricamento")),
			"tunnel_in_sala": sala.get(&"sala_sottomarino") != null,
		}


func _controlla(id: String, quando: String) -> void:
	var tag := "%s (%s)" % [id, quando]
	var sala := get_tree().current_scene
	var cp := String(GameState.snapshot.get("checkpoint", ""))
	_check(sala != null and sala.has_method(&"lavori_in_corso") and GameState.player != null, "%s: la sala è aperta, col giocatore" % tag)
	if sala == null or not sala.has_method(&"lavori_in_corso"):
		return
	print("  entrati: ", _visti)
	if cp.begins_with("SalaTorre"):
		var t: Dictionary = _all_ingresso.get("torre", {})
		_check(not t.is_empty(), "%s: la torre è entrata" % tag)
		_check(not t.is_empty() and not t["interni"] and not t["tecnici"], "%s: quando entra la torre, interni e tecnici sono già via (%s)" % [tag, t])
		_check(not t.is_empty() and not t["tunnel_nel_thread"] and not t["tunnel_in_sala"], "%s: il tunnel non era ancora partito" % tag)
		_check(bool(sala.get(&"_sottomarino_in_caricamento")) or sala.get(&"sala_sottomarino") != null, "%s: il tunnel parte dopo la torre" % tag)
	elif cp.begins_with("SalaSottomarino"):
		var t: Dictionary = _all_ingresso.get("tunnel", {})
		_check(not t.is_empty(), "%s: il tunnel è entrato" % tag)
		_check(not t.is_empty() and not t["interni"] and not t["tecnici"], "%s: quando entra il tunnel, interni e tecnici sono già via (%s)" % [tag, t])
	else:
		_check(false, "%s: checkpoint oltre il portone (%s)" % [tag, cp])
	_check(not GameState.is_dying, "%s: vivo all'arrivo" % tag)
	# 4 s di gioco: niente torna, e nel tunnel niente torre. In fotogrammi, non in tempo vero: con --fixed-fps 60 su una
	# macchina veloce 4 s veri erano molti più secondi di gioco, e nel tunnel lei raggiunge il giocatore fermo e lo prende
	# dopo circa 400 fotogrammi (6,8 s), come nel gioco (CI di main 41225795359, "KO tunnel: vivo")
	for i in 240:
		await get_tree().physics_frame
	if not is_instance_valid(sala):
		_check(false, "%s: la sala c'è ancora dopo 4 s (una morte l'ha ricaricata?)" % tag)
		return
	_check(sala.get_node_or_null(^"Interni") == null and sala.get_node_or_null(^"Tecnici") == null, "%s: interni e tecnici non ci sono" % tag)
	if cp.begins_with("SalaSottomarino"):
		_check(not "torre" in _visti and not "torre_nascosta" in _visti and sala.get(&"sala_torre") == null \
				and sala.get(&"_torre_nascosta") == null and not bool(sala.get(&"_torre_in_caricamento")),
				"%s: nel tunnel la torre non si prepara" % tag)
	else:
		_check(sala.get(&"sala_torre") is Node and not "torre_nascosta" in _visti, "%s: la torre c'è, una sola" % tag)
	_check(not GameState.is_dying, "%s: vivo dopo 4 s di gioco (causa %s)" % [tag, GameState.last_death_cause])


func _aspetta_ripresa() -> void:
	# (in tempo vero: la sala si carica in un thread, e nel sandbox la prima volta ci mette minuti)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 900000:
		await get_tree().process_frame
		var s := get_tree().current_scene
		if s and s.scene_file_path != "res://scenes/ui/caricamento.tscn" and GameState.player \
				and is_instance_valid(GameState.player) and not GameState.is_restoring():
			break
	for i in 30:
		await get_tree().process_frame
