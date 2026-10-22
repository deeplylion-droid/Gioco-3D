extends Node
## Test automatico della sala della torre (scenes/sala/torre/sala_torre.tscn, versione A scelta dall'utente il
## 18 ottobre): la struttura di torri e scivoli che si SCENDE, dal portone alla vasca del fondo.
## 1. Da sola: i canali della discesa sono solidi e nel gruppo "scivolo" (l'accordo con grafica per il
##    movimento dello scivolare), lungo tutta la discesa c'è il canale sotto e 2 m liberi sopra, i
##    checkpoint sono sulle pedane d'arrivo, la Polaroid 10 è sul lettino; niente zone che uccidono, le cinque
##    vasche di raccolta sotto i salti con l'acqua e la scaletta, un portale su ogni imbocco (21 ottobre).
## 2. La discesa col movimento vero sugli scivoli (Player di grafica): ogni tratto si scende dalla sua pedana
##    alla pedana dopo (sulla pedana, non sul pianerottolo della scala), anche entrando spostati di 45 cm o
##    storti di 22 gradi; nei due tratti che finiscono col getto, senza getto si cade. Dall'arrivo si cammina
##    fino all'imbocco dopo con un passaggio libero di 1 m, senza scavalcare niente. Chi sbaglia un salto cade
##    nella vasca di raccolta sotto, senza morire, e risale dalla scaletta fino alla pedana da cui era partito.
## 3. Nella sala grande: il portone (aperto qui senza la tappa 8) fa caricare la torre in un thread, il guscio
##    vecchio sparisce, sulla passerella si entra (il portone si richiude, interni e tecnici si scaricano);
##    cadendo nel vuoto per 12 m si muore, ma solo toccando il fondo (caduta vera), e si riparte dall'ultimo
##    checkpoint, con la torre di nuovo lì; le pedane
##    d'arrivo sono checkpoint in ordine; nella vasca del fondo la demo finisce.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_torre.gd

const LEVEL := "res://scenes/sala_principale.tscn"
const TORRE := "res://scenes/sala/torre/sala_torre.tscn"
const Camminatore := preload("res://tests/camminatore.gd")
const POLAROID_LIBERE := preload("res://tests/polaroid_libere.gd")
## Ingressi nel canale spostati (m, di lato) e storti (gradi).
const INGRESSI := [[0.45, 0.0], [-0.45, 0.0], [0.0, 22.0], [0.0, -22.0]]
var _passed := 0
var _failed := 0
var _errori := RaccoltaErrori.new()


## Gli errori degli script (un Logger li raccoglie tutti).
class RaccoltaErrori extends Logger:
	var errori: Array = []
	var _mutex := Mutex.new()

	func _log_error(_function: String, file: String, line: int, _code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != Logger.ERROR_TYPE_SCRIPT:
			return
		_mutex.lock()
		errori.append("%s:%d %s" % [file, line, rationale])
		_mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass

	func copia() -> Array:
		_mutex.lock()
		var c := errori.duplicate()
		_mutex.unlock()
		return c


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	OS.add_logger(_errori)
	print("0. Costruita a pezzi e tolta a metà (una morte ricarica la sala mentre la torre si prepara)")
	for quando in ["costruzione", "preparazione"]:
		var genitore := Node3D.new()
		get_tree().root.add_child(genitore)
		var tp: SalaTorre = (load(TORRE) as PackedScene).instantiate()
		tp.costruzione_a_pezzi = true
		tp.visible = false
		genitore.add_child(tp)
		var prima := _errori.copia().size()
		var finita := [false]
		var prepara := func():
			await tp.costruisci_a_pezzi(1.0)
			if quando == "preparazione" and tp.is_inside_tree():
				await tp.prepara_materiali(get_viewport(), 30)
			finita[0] = true
		prepara.call()
		if quando == "costruzione":
			await _frames(3)
		else:
			while not tp.costruita and Time.get_ticks_msec() < 600000:
				await _frames(1)
			await _frames(2)
		var a_meta: bool = not finita[0]
		get_tree().root.remove_child(genitore)
		await _frames(10)
		var errori := _errori.copia().slice(prima)
		check(a_meta and errori.is_empty(), "tolta a metà della %s: nessun errore (%s)" % [quando, "; ".join(errori)])
		check(quando == "costruzione" or tp.find_children("*", "VisualInstance3D", true, false).all(
				func(v): return (v as VisualInstance3D).layers != SalaTorre.STRATO_PREPARA),
			"   e la torre torna sui suoi strati")
		genitore.free()

	print("1. La sala da sola")
	var torre: SalaTorre = (load(TORRE) as PackedScene).instantiate()
	torre.crea_luci = false
	get_tree().root.add_child(torre)
	await _frames(3)
	var dati: Dictionary = torre.dati
	var n_pezzi := 0
	for t in dati["tratti"]:
		n_pezzi += (t["pezzi"] as Array).size()
	var scivoli := torre.corpi_scivolo().filter(func(c): return torre.inseguimento == null or not torre.inseguimento.is_ancestor_of(c))
	var rampe := scivoli.filter(func(c): return String(c.name).ends_with("_rampa"))
	check(n_pezzi >= 8 and scivoli.size() - rampe.size() == n_pezzi and rampe.size() == (dati["tratti"] as Array).size(),
			"%d pezzi di discesa e %d rampe d'imbocco: %d corpi nel gruppo \"scivolo\"" % [n_pezzi, rampe.size(), scivoli.size()])
	check(torre.checkpoint.size() == 7, "7 checkpoint: il portone, le 5 pedane d'arrivo, il fondo (%d)" % torre.checkpoint.size())
	var ordini_ok := true
	for i in range(1, torre.checkpoint.size()):
		ordini_ok = ordini_ok and torre.checkpoint[i].order > torre.checkpoint[i - 1].order \
			and torre.checkpoint[i].global_position.y < torre.checkpoint[i - 1].global_position.y + 0.1
	check(ordini_ok, "i checkpoint vanno in ordine e sempre più in basso")
	check(torre.get_node_or_null("Polaroid10") != null, "c'è la Polaroid 10")
	var p10 := torre.get_node_or_null("Polaroid10") as Node3D
	if p10:
		for i in 4:
			await get_tree().physics_frame
		var coperte: PackedStringArray = POLAROID_LIBERE.coperte(torre)
		check(coperte.is_empty(), "la Polaroid 10 non è coperta né compenetrata %s" % str(coperte))
		var h: float = POLAROID_LIBERE.appoggio(torre, p10)
		check(h > -0.002 and h < 0.012, "la Polaroid 10 è appoggiata sul lettino (%.1f cm sopra)" % (h * 100.0))
	check(torre.find_children("*", "KillZone", true, false).is_empty(), "niente zone che uccidono senza una caduta vera (V1)")
	var raccolta: Array = dati.get("raccolta", [])
	check(raccolta.size() == 5 and torre.find_children("Raccolta*", "WaterVolume", false, false).size() == 5 \
			and torre.find_children("ScalaRaccolta*", "Ladder", false, false).size() == 5,
		"sotto i cinque salti le vasche di raccolta, con l'acqua e la scaletta di servizio")
	check((dati.get("imbocchi", []) as Array).size() == (dati["tratti"] as Array).size(), "un portale su ogni imbocco della discesa")
	var solidi := torre.find_children("*", "StaticBody3D", true, false).size()
	check(solidi > n_pezzi + 20, "la struttura, i tubi e i prop sono solidi (%d corpi statici)" % solidi)
	var spazio := torre.get_world_3d().direct_space_state

	# la parete ovest non sta nel piano del retro della parete est della sala grande (x 20,2), né dietro le
	# cornici degli oblò che ne sporgono (fino a 20,225): due facce nello stesso piano lampeggiano (prova
	# del 19 ottobre). Si guardano i triangoli grandi (le celle della parete, non i pezzi piccoli appoggiati al
	# muro), verticali e rivolti verso ovest/est, delle collisioni della struttura.
	var x_ovest := INF
	var nel_piano := 0
	for cs in torre.get_node("TorreStruttura").find_children("*", "CollisionShape3D", true, false):
		var forma := (cs as CollisionShape3D).shape as ConcavePolygonShape3D
		if forma == null:
			continue
		var xf := (cs as CollisionShape3D).global_transform
		var f := forma.get_faces()
		for i in range(0, f.size(), 3):
			var a := xf * f[i]
			var b_ := xf * f[i + 1]
			var c := xf * f[i + 2]
			var nrm := (b_ - a).cross(c - a)
			if nrm.length() < 3.0 or absf(nrm.normalized().x) < 0.999 or maxf(a.x, maxf(b_.x, c.x)) > 20.6:
				continue
			x_ovest = minf(x_ovest, a.x)
			if absf(a.x - 20.2) < 0.03:
				nel_piano += 1
	check(nel_piano == 0 and x_ovest > 20.23 and x_ovest < 20.3,
		"la parete ovest sta in x %.3f, davanti al retro della sala grande (%d facce nel suo piano)" % [x_ovest, nel_piano])

	# i checkpoint stanno sopra qualcosa di solido
	var appoggiati := 0
	for cp in torre.checkpoint:
		var hit := spazio.intersect_ray(PhysicsRayQueryParameters3D.create(cp.global_position + Vector3(0, 1.0, 0), cp.global_position - Vector3(0, 1.5, 0), Layers.WORLD))
		if not hit.is_empty():
			appoggiati += 1
		else:
			print("    sotto il checkpoint %s non c'è niente" % cp.name)
	check(appoggiati == torre.checkpoint.size(), "ogni checkpoint ha il pavimento sotto (%d/%d)" % [appoggiati, torre.checkpoint.size()])

	# lungo la discesa: il canale sotto, e lo spazio sopra per chi scivola
	var punti: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ambiente/torre/torre_percorso.json"))
	var sotto_ok := 0
	var sopra_ok := 0
	var n := 0
	var capi: Array[Vector3] = []
	for x in dati["salti"]:
		capi.append(SalaTorre.b(x["da"]))
		capi.append(SalaTorre.b(x["a"]))
	for q in punti:
		if q["cosa"] != "scivolo":
			continue
		# (i capi dei pezzi accanto ai buchi non contano: lì il canale finisce)
		if capi.any(func(c): return c.distance_to(SalaTorre.b([q["x"], q["y"], q["z"]])) < 0.8):
			continue
		n += 1
		var pos := SalaTorre.b([q["x"], q["y"], q["z"]])
		var hit := spazio.intersect_ray(PhysicsRayQueryParameters3D.create(pos + Vector3(0, 0.6, 0), pos - Vector3(0, 1.2, 0), Layers.WORLD))
		if hit.is_empty() or not (hit.collider as Node).is_in_group(&"scivolo"):
			print("    sotto %s: %s" % [pos, "niente" if hit.is_empty() else String((hit.collider as Node).get_parent().name)])
		if not hit.is_empty() and (hit.collider as Node).is_in_group(&"scivolo"):
			sotto_ok += 1
			var fondo := (hit.position as Vector3) + Vector3(0, 0.15, 0)
			var su := spazio.intersect_ray(PhysicsRayQueryParameters3D.create(fondo, fondo + Vector3(0, 2.0, 0), Layers.WORLD))
			if su.is_empty():
				sopra_ok += 1
			elif sopra_ok + 3 > n:
				print("    poco spazio sopra il canale a ", pos, " (", (su.collider as Node).name, ")")
	check(sotto_ok == n, "sotto ogni punto della discesa c'è un canale del gruppo \"scivolo\" (%d/%d)" % [sotto_ok, n])
	check(sopra_ok >= n - 2, "sopra il canale ci sono 2 m liberi (%d/%d punti)" % [sopra_ok, n])

	print("2. La discesa col movimento vero sugli scivoli (Player, di grafica)")
	var salti: Array = dati["salti"]
	var n_getto := salti.filter(func(x): return x["tipo"] == "getto").size()
	check(n_getto == 2 and salti.size() - n_getto >= 4, "%d salti normali e %d col getto" % [salti.size() - n_getto, n_getto])
	var l_prec := 0.0
	var crescono := true
	for x in salti:
		if x["tipo"] == "salto":
			crescono = crescono and float(x["larghezza"]) >= l_prec
			l_prec = float(x["larghezza"])
	check(crescono and float(salti[0]["larghezza"]) <= 1.0, "i salti normali sono sempre più lunghi e il primo è corto")
	torre.caduta_mortale = 1000.0
	var pl: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(pl)
	await _frames(5)
	pl.water_pack.set_equipped(true, false)
	for k in range(torre.checkpoint.size() - 1):
		var tr: Dictionary = dati["tratti"][k]
		var col_getto: bool = (tr["salti"] as Array).has("getto")
		var esito := await _scendi(torre, pl, k, true)
		check(esito == "arrivato", "tratto %d (%s -> %s, salti %s): %s" % [k, torre.checkpoint[k].name, torre.checkpoint[k + 1].name, tr["salti"], esito])
		if esito == "arrivato" and k + 1 < (dati["tratti"] as Array).size():
			# dall'arrivo all'imbocco dopo, a piedi: passaggio di 1 m, senza saltare
			var cam = Camminatore.new(torre, pl, self)
			cam.margine = 0.5
			var ok: bool = await cam.verso(SalaTorre.b(dati["tratti"][k + 1]["entrata"]), 0.3)
			check(ok, "   sulla pedana %s si arriva all'imbocco dopo camminando (1 m libero, senza salti)" % torre.checkpoint[k + 1].name)
		for ing in INGRESSI:
			var e2 := await _scendi(torre, pl, k, true, ing[0], ing[1])
			check(e2 == "arrivato", "   entrando spostati di %.2f m e storti di %d gradi: %s" % [ing[0], int(ing[1]), e2])
		if col_getto:
			var senza := await _scendi(torre, pl, k, false)
			check(senza.begins_with("caduto"), "   senza il getto non si arriva (%s)" % senza)
	print("   Chi sbaglia il salto cade nella vasca di raccolta e la scaletta lo riporta alla pedana di partenza")
	for k in raccolta.size():
		var v: Dictionary = raccolta[k]
		var s_: Dictionary = salti[k]
		var da := SalaTorre.b(s_["da"])
		var a := SalaTorre.b(s_["a"])
		var r: Array = v["rett"]
		# cade dal salto: fermo a metà del salto, appena sopra
		pl.teleport((da + a) / 2.0 + Vector3.UP * 0.4)
		var in_vasca := false
		for i in 300:
			await _frames(1)
			var q := pl.global_position
			if pl.is_in_water() and pl.is_on_floor():
				in_vasca = r[0] < q.x and q.x < r[2] and r[1] < -q.z and -q.z < r[3]
				break
		check(in_vasca, "salto %d sbagliato: si cade nella vasca di raccolta (%s)" % [k, str(pl.global_position)])
		var sc: Dictionary = v["scala"]
		var piede := SalaTorre.b([sc["x"], sc["y"], sc["z0"]])
		var davanti := piede + Vector3(float(sc["verso"][0]), 0.0, -float(sc["verso"][1])) * 1.0
		var su := false
		var di_fronte := false
		for i in 60 * 20:
			# prima davanti alla scaletta, poi dritti verso di lei (come chi gioca)
			var meta := piede if di_fronte else davanti
			var dir := meta - pl.global_position
			if not di_fronte and Vector2(dir.x, dir.z).length() < 0.3:
				di_fronte = true
			if not pl.is_on_ladder():
				pl.set_look(atan2(-dir.x, -dir.z), 0.0)
			Input.action_press(&"move_forward")
			await _frames(1)
			if not pl.is_on_ladder() and pl.is_on_floor() and pl.global_position.y > float(v["livello"]) - 0.2:
				su = true
				break
		Input.action_release(&"move_forward")
		await _frames(10)
		check(su and _su_pedana(torre, pl.global_position) == "pedana" and absf(pl.global_position.y - float(v["livello"])) < 0.3,
			"   e la scaletta lo riporta sulla pedana di partenza (%s %.0f, %s)" % [v["torre"], float(v["livello"]), str(pl.global_position)])
	pl.queue_free()
	torre.queue_free()
	await _frames(2)

	print("3. Nella sala grande")
	get_tree().change_scene_to_file(LEVEL)
	await _aspetta_livello()
	var level := get_tree().current_scene
	var p := GameState.player
	var portone := level.get(&"portone") as PortoneTorre
	check(level.get(&"sala_torre") == null, "prima che il portone si apra la torre non è caricata")
	var campioni: Array = level.get(&"_materiali_torre")
	check(campioni.size() == SalaTorre.materiali_campione().size() and campioni.all(func(m): return m is Material),
		"la sala tiene pronti gli shader dei materiali che la torre crea da codice (%d)" % campioni.size())
	# come nel gioco: alla torre si arriva dopo il risveglio (tappa 6), col blackout
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	portone.apri()
	var t0 := Time.get_ticks_msec()
	# a tempo, non a fotogrammi: su una macchina lenta (renderer finto, CPU) il thread ci mette più di
	# 3000 fotogrammi senza disegno
	while level.get(&"sala_torre") == null and Time.get_ticks_msec() - t0 < 90000:
		await get_tree().process_frame
	var sala: SalaTorre = level.get(&"sala_torre")
	check(sala != null, "il portone fa caricare la torre in un thread (%.1f s)" % ((Time.get_ticks_msec() - t0) / 1000.0))
	if sala == null:
		_fine()
		return
	await _frames(5)
	check(level.find_child("sala_torre_guscio", true, false) == null, "il guscio vecchio dietro il portone non c'è più")
	# La riserva: se il thread fallisse la torre si caricherebbe subito (mai bloccati davanti al portone).
	# Qui lo stato del thread è INVALID_RESOURCE perché il risultato è già stato preso.
	var vecchia := sala
	level.remove_child(vecchia)
	level.set(&"sala_torre", null)
	level.set(&"_torre_in_caricamento", true)
	await _frames(3)
	var riserva: Node = level.get(&"sala_torre")
	check(riserva != null and riserva != vecchia and riserva.is_inside_tree(),
		"se il caricamento nel thread fallisce la torre si carica subito lo stesso")
	if riserva:
		level.remove_child(riserva)
		riserva.free()
	level.add_child(vecchia)
	level.set(&"sala_torre", vecchia)
	await _frames(5)
	for i in 900:
		if portone.is_aperto():
			break
		await _frames(1)
	_metti(p, Vector3(21.3, 0.1, -15.0), Vector3(30.0, 0.1, -15.0))
	await _frames(60)
	check(portone.chiuso_dietro, "entrando sulla passerella il portone si richiude alle spalle")
	check(level.get_node_or_null(^"Tecnici") == null and level.get_node_or_null(^"Interni") == null,
		"interni e tecnici si scaricano")
	check(String(GameState.snapshot.get("checkpoint", "")).contains("SalaTorre/Checkpoint_portone"),
		"checkpoint all'ingresso (%s)" % GameState.snapshot.get("checkpoint", ""))

	# le pedane d'arrivo, in ordine (qui ci si arriva teletrasportati)
	for i in range(1, sala.checkpoint.size() - 1):
		var cp := sala.checkpoint[i]
		_metti(p, cp.global_position + Vector3(0, 0.1, 0), cp.global_position - cp.global_basis.z)
		await _frames(20)
		check(String(GameState.snapshot.get("checkpoint", "")).ends_with(cp.name) and not GameState.is_dying,
			"pedana %s: checkpoint" % cp.name)

	var accese_prima := _luci_accese(sala)
	check(accese_prima.size() > 20, "col blackout le luci della torre sono accese (%d)" % accese_prima.size())

	print("   Una caduta")
	var ultimo := sala.checkpoint[sala.checkpoint.size() - 2]
	var ultimo_pos := ultimo.get_spawn_transform().origin
	var ultimo_nome := String(ultimo.name)
	_metti(p, Vector3(31.0, -8.0, -15.0), Vector3(31.0, 0, -10.0))   # nel vuoto sopra il pozzo, 12 m sopra il fondo
	var y_morte := 0.0
	for i in 400:
		await _frames(1)
		if GameState.is_dying:
			y_morte = p.global_position.y
			break
	check(GameState.is_dying, "cadendo nel vuoto fino in fondo si muore (caduta vera)")
	check(y_morte < -19.5, "   ma solo toccando il fondo, dopo una caduta lunga (a %.1f m)" % y_morte)
	await _salta_morte()
	await _aspetta_livello()
	await _frames(10)
	level = get_tree().current_scene
	p = GameState.player
	sala = level.get(&"sala_torre")
	check(sala != null and is_instance_valid(sala), "si riparte con la torre già lì")
	if sala:
		check(p.global_position.distance_to(ultimo_pos) < 2.0, "dall'ultimo checkpoint (%s)" % ultimo_nome)
		check((level.get(&"portone") as PortoneTorre).chiuso_dietro, "col portone chiuso alle spalle")
		# riscontro del 19 ottobre: "dopo che sono morto una volta, è diventata tutta buia"
		await _frames(30)
		var accese_dopo := _luci_accese(sala)
		check(GameState.luci == GameState.Luci.BLACKOUT and accese_dopo.size() == accese_prima.size(),
			"dopo la morte le luci della torre sono ancora accese (%d su %d%s)" % [accese_dopo.size(), accese_prima.size(),
				"" if accese_dopo.size() == accese_prima.size() else "; spente: " + str(accese_prima.filter(func(n): return n not in accese_dopo))])
		print("   La vasca del fondo e la bocca dell'inseguimento")
		var fondo := sala.get_node("VascaFondo") as Area3D
		_metti(p, fondo.global_position + Vector3(0, 0.6, 0), fondo.global_position + Vector3(0, 0.6, 1))
		await _frames(30)
		check(not bool(level.get(&"demo_finished")), "nella vasca del fondo la discesa non finisce più: c'è l'inseguimento")
		var ins := sala.inseguimento as SalaInseguimento
		check(ins != null and ins.costruita, "l'inseguimento è già nella sala, dietro il muro est")
		if ins:
			# nella vasca del fondo, dall'acqua ai gradini sotto la bocca: dal lato sud si sale sul primo
			p.rotation = Vector3.ZERO      # cammina dove guarda la testa (con il corpo girato, i versi si sommano)
			p.teleport(SalaTorre.b([37.0, 13.8, -19.9]))
			p.look_at_point(SalaTorre.b([37.0, 18.0, -18.4]))
			Input.action_press(&"move_forward")
			var su_gradino := false
			for i in 300:
				await _frames(1)
				if p.global_position.y > -20.0 + 1.0 and -p.global_position.z > 16.7:
					su_gradino = true
					break
			Input.action_release(&"move_forward")
			check(su_gradino, "dall'acqua della vasca del fondo si salgono i gradini fino alla bocca (%s)" % str(p.global_position))
			# dall'ultimo gradino nella bocca: si scivola fino alla vasca 1 dell'inseguimento
			# (a mezzo metro dal labbro del tubo: più vicino il corpo lo compenetra e ne viene spinto fuori)
			p.rotation = Vector3.ZERO      # cammina dove guarda la testa (con il corpo girato, i versi si sommano)
			p.teleport(SalaTorre.b([37.0, 17.4, -18.88]) + Vector3(0, 0.05, 0))
			p.look_at_point(SalaTorre.b([45.0, 17.4, -18.9]))
			Input.action_press(&"move_forward")
			var arrivato := false
			for i in 900:
				await _frames(1)
				if p.is_sliding:
					Input.action_release(&"move_forward")
				if String(GameState.snapshot.get("checkpoint", "")).ends_with("Checkpoint_vasca_1"):
					arrivato = true
					break
			Input.action_release(&"move_forward")
			check(arrivato and not GameState.is_dying, "dalla bocca il tubo porta alla vasca 1 dell'inseguimento (checkpoint%s)"
				% ("" if arrivato else "; fermo in %s, scivola %s" % [str(p.global_position), str(p.is_sliding)]))
			# alla fine dell'inseguimento (SB1) finisce il capitolo: la scritta di fine della demo
			ins.capitolo_finito.emit()
			await _frames(5)
			check(bool(level.get(&"demo_finished")), "alla fine dell'inseguimento finisce il capitolo (la demo)")
	var errori_script := _errori.copia()
	check(errori_script.is_empty(), "nessun errore degli script (%s)" % "; ".join(errori_script))
	_fine()


## Scende il tratto k col movimento vero: dall'ingresso del tratto (un metro dietro l'inizio) si cammina
## avanti finché si scivola, poi si lascia fare; nei tratti che finiscono col getto, con [param getto], negli
## ultimi metri si tiene premuto lo spruzzo verso il basso (la carica si fa scivolando, in aria la spinta parte
## subito). "arrivato" se ci si ferma sulla pedana del checkpoint dopo, "caduto ..." se si va giù.
func _scendi(torre: SalaTorre, p: Player, k: int, getto: bool, spostato := 0.0, storto := 0.0) -> String:
	var tr: Dictionary = torre.dati["tratti"][k]
	var dopo := torre.checkpoint[k + 1]
	var avanti := SalaTorre.b(tr["verso"])
	var decollo := SalaTorre.b(tr["a"])
	var fine_getto: bool = (tr["salti"] as Array).size() > 0 and tr["salti"][-1] == "getto"
	var lato := Vector3(-avanti.z, 0, avanti.x)
	p.global_position = SalaTorre.b(tr["entrata"]) + lato * spostato + Vector3(0, 0.2, 0)
	p.velocity = Vector3.ZERO
	p.set_look(atan2(-avanti.x, -avanti.z) + deg_to_rad(storto), 0.0)
	p.water_pack.set_tank_amount(20.0)
	await _frames(10)
	Input.action_press(&"move_forward")
	var premuto := false
	var fermo := 0
	var esito := "tempo scaduto"
	for i in 60 * 20:
		await _frames(1)
		# avanti si tiene premuto finché non si scivola davvero (come chi gioca), poi si lascia fare
		if p.is_sliding and Vector2(p.velocity.x, p.velocity.z).length() > 2.5 and Input.is_action_pressed(&"move_forward") \
				and _dentro_canale(torre, k, p.global_position) > 0.5:
			Input.action_release(&"move_forward")
		if getto and fine_getto and not premuto and p.is_sliding \
				and Vector2(p.global_position.x - decollo.x, p.global_position.z - decollo.z).length() < 3.0:
			premuto = true
			p.set_look(p.yaw, deg_to_rad(-80.0))
			Input.action_press(&"spray")
		var pos := p.global_position
		if pos.y < dopo.global_position.y - 3.0:
			esito = "caduto a %.1f m" % pos.y
			break
		if p.is_on_floor() and not p.is_sliding:
			# nell'acqua della vasca di raccolta, o in piedi sul suo bordo
			for v in torre.dati.get("raccolta", []):
				var r: Array = v["rett"]
				if r[0] < pos.x and pos.x < r[2] and r[1] < -pos.z and -pos.z < r[3] and pos.y < float(v["acqua"]) + 0.4 and pos.y > float(v["fondo"]) - 0.3:
					esito = "caduto nella vasca di raccolta"
			if esito.begins_with("caduto"):
				break
		# fermi su qualcosa nel vuoto, lontano dalla pedana dopo (SalaTorre la conta come caduta)
		if p.is_on_floor() and not p.is_sliding and pos.y < torre.checkpoint[k].global_position.y - 1.0 \
				and pos.distance_to(dopo.global_position) > 4.0:
			fermo += 1
			if fermo > 90:
				esito = "caduto (fermo nel vuoto a %.1f m)" % pos.y
				break
		else:
			fermo = 0
		if absf(pos.y - dopo.global_position.y) < 0.6 and not p.is_sliding and p.is_on_floor():
			var ultimo := k + 2 == torre.checkpoint.size()
			var dove := _su_pedana(torre, pos)
			if ultimo and Vector2(pos.x - dopo.global_position.x, pos.z - dopo.global_position.z).length() < 4.5:
				esito = "arrivato"
				break
			if not ultimo and dove == "pedana":
				esito = "arrivato"
				break
			if not ultimo and dove == "scala":
				esito = "arrivato sul pianerottolo della scala, non sulla pedana"
				break
	Input.action_release(&"move_forward")
	Input.action_release(&"spray")
	p.set_look(p.yaw, 0.0)
	if esito == "tempo scaduto":
		esito += " (a %s)" % str(p.global_position)
	return esito


## "pedana" se pos (Godot) è su una pedana della torre, "scala" se è su un pianerottolo, "" altrimenti.
func _su_pedana(torre: SalaTorre, pos: Vector3) -> String:
	for r in torre.dati.get("pedane", []):
		if absf(pos.y - float(r[4])) < 0.6 and r[0] - 0.1 < pos.x and pos.x < r[2] + 0.1 and r[1] - 0.1 < -pos.z and -pos.z < r[3] + 0.1:
			return "scala" if (r as Array).size() > 5 else "pedana"
	return ""


func _metti(p: Player, pos: Vector3, guarda: Vector3) -> void:
	p.global_position = pos
	p.velocity = Vector3.ZERO
	var g := Vector3(guarda.x, pos.y, guarda.z)
	if g.distance_to(pos) > 0.01:
		p.look_at(g, Vector3.UP)


## I nomi (col percorso nella torre) delle luci della torre accese, cioè visibili: il blackout le spegne
## nascondendole. L'energia non conta: le lampade guaste (_sfarfalla) vanno a 0 e tornano su in ogni momento.
func _luci_accese(sala: Node) -> Array:
	var out := []
	for n in sala.find_children("*", "Light3D", true, false):
		var l := n as Light3D
		if l.is_visible_in_tree():
			# (le luci senza nome hanno nomi automatici diversi dopo la ricarica della sala: il posto le distingue)
			var nome := String(l.name)
			out.append(nome if not nome.begins_with("@") else "%s %s" % [l.get_class(), str(l.global_position.snapped(Vector3.ONE * 0.01))])
	return out


func _aspetta_livello() -> void:
	var vecchio := GameState.player
	for i in 900:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and GameState.player != vecchio and not GameState.is_dying:
			break
	await _frames(5)
	var p := GameState.player
	for i in 400:
		if p.input_enabled:
			break
		await get_tree().process_frame


func _salta_morte() -> void:
	await _frames(10)
	var seq := GameState.get_children().filter(func(n): return n is DeathSequence)
	if seq.size() > 0:
		(seq[0] as DeathSequence).skip()


func _fine() -> void:
	print("")
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
		print("  ok    ", what)
	else:
		_failed += 1
		printerr("  FALLITO ", what)


func _frames(k: int) -> void:
	for i in k:
		await get_tree().physics_frame


## Quanti metri si è già dentro il canale del tratto k (negativo prima dell'imbocco), lungo la sua direzione.
func _dentro_canale(torre: SalaTorre, k: int, pos: Vector3) -> float:
	var linea: Array = torre.dati["tratti"][k]["linee"][0]
	var a := SalaTorre.b(linea[0])
	var c := SalaTorre.b(linea[1])
	var t := Vector3(c.x - a.x, 0, c.z - a.z).normalized()
	return Vector3(pos.x - a.x, 0, pos.z - a.z).dot(t)
