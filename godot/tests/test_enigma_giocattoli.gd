extends Node
## L'enigma dei giocattoli nella piscina a onde (EnigmaGiocattoli, scelte del 28 ottobre: idea A con la nota
## dell'utente, i giocattoli si spingono anche a piscina vuota). Col giocatore e il getto veri, nei due ordini:
## A. prima i giocattoli sull'acqua, poi lo svuotamento: calando l'acqua si posano e i piatti scendono;
## B. prima lo svuotamento, poi i giocattoli spinti sul fondo: ogni piatto scende quando il suo arriva.
## In tutti e due: finché i piatti non sono scesi il pulsante della botola non si preme e il lampeggiante è giallo;
## scesi tutti e tre, verde, e colpito col getto la botola si apre. E i cerchi sul fondo (Posa), i giocattoli che
## galleggiano, i posti liberi (P5, scalette), il salvataggio coi checkpoint. E i posti dove un giocattolo restava
## incastrato (collaudo di ambienti-2, 29 ottobre): dagli angoli dell'area e da sotto le scalette si riporta al suo
## cerchio col getto; spinto a lungo contro un gonfiabile non ci entra e non ci sale, e ci scivola attorno; posato
## dall'acqua sopra un gonfiabile ne scivola giù. E ogni fotogramma (ricontrollo di ambienti-2): chi si muove sul fondo
## non sta mai più di 1 cm sopra il fondo che ha sotto, anche sulle pendenze e sulla conca della botola; e nessun
## giocattolo sta mai sotto il fondo. Infine (secondo ricontrollo di ambienti-2) il pallone spinto contro il portellone
## da otto lati e lungo la giunzione del fondo a x = 0, dove un raggio dall'alto può non trovare il fondo e il giocattolo
## cadeva sul soffitto della camera delle onde; la rete di sicurezza; la ripartenza da un checkpoint con un giocattolo
## sotto il fondo o sulla giunzione.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_enigma_giocattoli.gd

const LEVEL := "res://scenes/sala_principale.tscn"
## Dove si svuota la piscina (come test_tappe56): sul bordo est, si aspira lì sotto e si spara fuori.
const BORDO := Vector3(7.35, 0.0, 2.0)
const ACQUA := Vector3(6.5, -1.5, 2.0)
const FUORI := Vector3(13.0, 0.5, 2.0)

var level: Node
var p: Player
var enigma: EnigmaGiocattoli
var vasca: WaterTank
var piscina: PiscinaOnde
var pulsante: WaterButton
var portello: Node
var _passed := 0
var _failed := 0
var _scesi: Array = []
var _risolto := 0
var _colpi := {}
## La quota di chi si muove sul fondo, misurata ogni fotogramma ([method _misura_staccato]): il peggio e dove.
var _misura_quota := false
var _staccato := 0.0
var _staccato_dove := ""
var _xz_prima: Array[Vector2] = [Vector2.INF, Vector2.INF, Vector2.INF]
## Quanto è stato sotto il fondo (il peggio, ogni fotogramma, tutti i giocattoli) e dove.
var _sotto := 0.0
var _sotto_dove := ""


func _ready() -> void:
	get_tree().physics_frame.connect(_misura_staccato)
	get_tree().physics_frame.connect(_misura_sotto)
	_run.call_deferred()


func _run() -> void:
	print("1. Com'è all'inizio")
	await _carica()
	if enigma == null:
		_fine()
		return
	for i in 3:
		var c := enigma.cerchio(i)
		var piatto := c.get_node(^"Piatto") as CollisionObject3D
		var f := _fondo_sotto(c.global_position, [piatto.get_rid()])
		check(absf(c.global_position.y - f) < 0.02, "il cerchio %d è appoggiato sul fondo (%.3f, fondo %.3f)" % [i, c.global_position.y, f])
		var d_botola := Vector2(c.global_position.x, c.global_position.z).distance_to(Vector2(0.0, 2.0))
		var p5 := level.get_node_or_null(^"Polaroid/Polaroid05") as Node3D
		var d_p5 := Vector2(c.global_position.x, c.global_position.z).distance_to(Vector2(p5.global_position.x, p5.global_position.z)) if p5 else 99.0
		check(d_botola > 1.3 and d_p5 > 0.8, "il cerchio %d non copre la botola né la P5 (%.1f m, %.1f m)" % [i, d_botola, d_p5])
		var g := enigma.giocattolo(i)
		var a_galla := absf(g.global_position.y - (vasca.get_surface_global_y() - EnigmaGiocattoli.PESCAGGI[i])) < 0.04
		check(a_galla, "il giocattolo %d galleggia (%.3f, pelo %.3f)" % [i, g.global_position.y, vasca.get_surface_global_y()])
		check(Vector2(g.position.x, g.position.z).distance_to(Vector2(c.position.x, c.position.z)) > 2.0,
			"il giocattolo %d parte lontano dal suo cerchio" % i)
	check(enigma.get_node_or_null(^"Disegno") is Decal, "c'è il disegno dei bambini sul muro")
	check(not pulsante.enabled, "con l'acqua il pulsante della botola è spento")

	print("2. Ordine A: prima i giocattoli sull'acqua, poi lo svuotamento")
	var t0 := Time.get_ticks_msec()
	for i in 3:
		var ok := await _spingi(i)
		check(ok, "col getto il giocattolo %d arriva sul suo cerchio galleggiando (%s)" % [i, str(_dove(i))])
	await _frames(60)
	var accesi := 0
	for i in 3:
		if enigma.cerchio_acceso_quanto(i) > 0.1:
			accesi += 1
	check(accesi == 3 and _scesi.is_empty(), "galleggiando sopra il suo cerchio lo accende appena, i piatti non scendono (%d accesi)" % accesi)
	var stato: Dictionary = enigma.save_state()
	await _svuota()
	check(vasca.fill <= 0.001, "la piscina si svuota con lo zaino")
	for k in 600:
		if enigma.risolto_ok and pulsante.enabled:
			break
		await get_tree().physics_frame
	check(_scesi.size() == 3, "calando l'acqua i giocattoli si posano e i tre piatti scendono (%s)" % str(_scesi))
	for i in 3:
		check(enigma.piatto_giu(i) and _sul_piatto(i), "il giocattolo %d è appoggiato sul suo piatto sceso (%s)" % [i, str(_dove(i))])
	check(enigma.risolto_ok and _risolto == 1 and pulsante.enabled, "scesi tutti e tre, il pulsante della botola funziona")
	await _frames(100)
	var luce := piscina.get_node_or_null(^"SegnalePulsante") as OmniLight3D
	check(luce != null and luce.visible and luce.light_color.g > 0.9 and luce.light_color.r < 0.5, "e il lampeggiante è verde")
	await _colpisci_pulsante()
	check(bool(portello.get(&"is_open")), "colpito col getto, la botola si apre")
	print("  (ordine A in %.0f s di prova)" % ((Time.get_ticks_msec() - t0) / 1000.0))
	check((stato.get("giu", []) as Array).count(true) == 0, "lo stato preso galleggiando non ha piatti scesi")

	print("3. Ordine B: prima lo svuotamento, poi i giocattoli sul fondo")
	await _carica()
	await _svuota()
	_misura_quota = true
	for k in 300:
		if piscina.attivo:
			break
		await get_tree().physics_frame
	await _frames(60)
	check(piscina.attivo and not pulsante.enabled and not enigma.risolto_ok, "a piscina vuota coi giocattoli fuori posto il pulsante non si preme")
	luce = piscina.get_node_or_null(^"SegnalePulsante") as OmniLight3D
	var gialla := luce != null and luce.visible and luce.light_color.r > 0.9 and luce.light_color.b < 0.3
	check(gialla, "e il lampeggiante resta giallo")
	await _colpisci_pulsante()
	check(not bool(portello.get(&"is_open")), "colpito, la botola resta chiusa")
	for i in 3:
		var g := enigma.giocattolo(i)
		check(absf(g.global_position.y - _fondo_sotto(g.global_position, [g.get_rid()])) < 0.03,
			"il giocattolo %d è appoggiato sul fondo (%s)" % [i, str(_dove(i))])
	var salvato_fondo: Dictionary = enigma.save_state()
	for i in 3:
		var prima := _scesi.size()
		var ok := await _spingi(i)
		for k in 120:
			if _scesi.size() > prima:
				break
			await get_tree().physics_frame
		check(ok and _scesi.size() == prima + 1 and enigma.piatto_giu(i),
			"spinto sul fondo, il giocattolo %d arriva sul cerchio e il suo piatto scende subito (%s)" % [i, str(_dove(i))])
		if i < 2:
			check(not pulsante.enabled, "con %d piatti su 3 il pulsante non si preme ancora" % (i + 1))
	for k in 120:
		if pulsante.enabled:
			break
		await get_tree().physics_frame
	check(enigma.risolto_ok and pulsante.enabled, "scesi tutti e tre, il pulsante funziona")
	await _colpisci_pulsante()
	check(bool(portello.get(&"is_open")), "colpito col getto, la botola si apre")
	_controlla_staccato("spinti sul fondo vuoto")
	_misura_quota = false
	_controlla_sotto("nei due ordini")

	print("4. Il salvataggio coi checkpoint")
	var tutto: Dictionary = enigma.save_state()
	check((tutto.get("giu", []) as Array).count(true) == 3 and bool(tutto.get("risolto", false)), "lo stato salva i piatti scesi (%s)" % str(tutto))
	await _carica()
	enigma.load_state(salvato_fondo)
	await _frames(10)
	var uguali := true
	for i in 3:
		var pos: Array = salvato_fondo["pos"][i]
		uguali = uguali and Vector2(enigma.giocattolo(i).position.x, enigma.giocattolo(i).position.z).distance_to(Vector2(pos[0], pos[1])) < 0.02
	check(uguali and not enigma.risolto_ok, "ricaricato, i giocattoli tornano dov'erano")
	enigma.load_state({"risolto": true})
	await _frames(10)
	var tutti_giu := true
	for i in 3:
		tutti_giu = tutti_giu and enigma.piatto_giu(i) and _sul_piatto(i)
	check(tutti_giu and enigma.risolto_ok, "con lo stato \"risolto\" (le partenze di prova) i giocattoli sono sui piatti scesi")

	# collaudo di ambienti-2 del 29 ottobre: tre posti dove un giocattolo restava incastrato e l'enigma si bloccava
	print("5. Dagli angoli e da sotto le scalette si riporta il giocattolo al suo cerchio col getto")
	await _carica()
	# (giocattolo, da dove in pianta, a piscina vuota, il posto). Prima quelli a piscina piena: svuotata, la piscina scola
	# l'acqua che le si rimette
	var a := enigma.area
	var casi := [[1, Vector2(a.position.x, 1.3), false, "sotto la scaletta ovest"], [2, Vector2(a.end.x, a.position.y), false, "nell'angolo nord-est"],
		[1, Vector2(a.position.x, 1.3), true, "sotto la scaletta ovest"],
		[0, Vector2(a.end.x, 3.2), true, "sotto la scaletta est"],
		[0, a.position, true, "nell'angolo nord-ovest"], [1, Vector2(a.end.x, a.position.y), true, "nell'angolo nord-est"],
		[2, Vector2(a.position.x, a.end.y), true, "nell'angolo sud-ovest"], [2, a.end, true, "nell'angolo sud-est"]]
	_misura_quota = true
	for caso in casi:
		var i: int = caso[0]
		if caso[2]:
			vasca.fill = 0.0
		await _metti(i, caso[1])
		# (sulla pendenza a nord, a piscina piena, l'acqua è più bassa di quanto pescano: lì toccano il fondo)
		if not caso[2]:
			check(vasca.fill > 0.9 and (enigma.galleggia(i) or caso[1].y < 0.0), "a piscina piena (fill %.2f) il giocattolo %d %s %s" % [
				vasca.fill, i, "galleggia" if enigma.galleggia(i) else "tocca la pendenza", caso[3]])
		var staccato := await _libera(i)
		var ok := staccato and await _spingi(i, 50)
		check(ok, "%s, %s: il giocattolo %d si stacca dal bordo e col getto torna al suo cerchio (%s)" % [
			"a piscina vuota" if caso[2] else "a piscina piena", caso[3], i, _dove(i)])
	_controlla_staccato("dagli angoli e dalle scalette")
	_controlla_sotto("dagli angoli e dalle scalette")

	print("6. Spinto a lungo contro un gonfiabile, non ci entra, non ci sale sopra e ci scivola attorno")
	vasca.fill = 0.0
	_misura_quota = true
	var ostacoli: Array = enigma.get(&"_ostacoli")
	var rids: Array = enigma.get(&"_rid_gonfiabili")
	check(ostacoli.size() >= 4 and rids.size() >= 4, "i gonfiabili sul fondo con la loro forma (%d cerchi, %d collisioni)" % [ostacoli.size(), rids.size()])
	var dentro_max := 0.0
	var su_max := 0.0
	var di_lato_min := INF
	var g1 := enigma.giocattolo(1)
	for o: Vector3 in ostacoli:
		var c2 := Vector2(o.x, o.y)
		var r: float = o.z + EnigmaGiocattoli.RAGGI[1]
		# il pallone dalla parte del centro dell'area (dietro di lui c'è posto per chi spruzza), spinto contro il gonfiabile
		var u := (Vector2(0.0, -1.5) - c2).normalized()
		await _metti(1, c2 + u * (r + 0.15))
		var partenza := Vector2(g1.position.x, g1.position.z)
		var di_lato := 0.0
		var stand2 := c2 + u * (r + 1.9)
		var stand := Vector3(stand2.x, _fondo_sotto(Vector3(stand2.x, 0.0, stand2.y), [g1.get_rid()]) + 0.05, stand2.y)
		p.teleport(stand, atan2(-(g1.global_position.x - stand.x), -(g1.global_position.z - stand.z)), 0.0)
		await _frames(4)
		Input.action_press(&"spray")
		for f in 240:
			if f % 60 == 0:
				p.water_pack.set_tank_amount(20.0)
			p.look_at_point(g1.global_position + Vector3(0, 0.35, 0))
			await get_tree().physics_frame
			dentro_max = maxf(dentro_max, r - Vector2(g1.position.x, g1.position.z).distance_to(c2))
			di_lato = maxf(di_lato, absf((Vector2(g1.position.x, g1.position.z) - partenza).dot(Vector2(-u.y, u.x))))
			var esclusi := rids.duplicate()
			esclusi.append(g1.get_rid())
			su_max = maxf(su_max, g1.global_position.y - _fondo_sotto(g1.global_position, esclusi))
		Input.action_release(&"spray")
		di_lato_min = minf(di_lato_min, di_lato)
		print("    contro %s: di lato %.2f m, il pallone in %s" % [o.snapped(Vector3.ONE * 0.01), di_lato,
			Vector2(g1.position.x, g1.position.z).snapped(Vector2.ONE * 0.01)])
		await _frames(90)
		var esclusi := rids.duplicate()
		esclusi.append(g1.get_rid())
		su_max = maxf(su_max, g1.global_position.y - _fondo_sotto(g1.global_position, esclusi))
	# il gonfiabile vicino alla conca della botola, spinto 8 s da tre lati come nel ricontrollo di ambienti-2: il pallone
	# lo aggira e attraversa la conca (lì stava 2,5 cm sopra il fondo: la quota lo seguiva in ritardo)
	var vicina: Vector3 = ostacoli[0]
	for o: Vector3 in ostacoli:
		if Vector2(o.x, o.y).distance_to(Vector2(-1.0, 0.4)) < Vector2(vicina.x, vicina.y).distance_to(Vector2(-1.0, 0.4)):
			vicina = o
	var spostato_min := INF
	for ang: float in [PI, PI * 0.75, PI * 1.25]:
		var via := Vector2(cos(ang), sin(ang))
		var c2 := Vector2(vicina.x, vicina.y)
		var r: float = vicina.z + EnigmaGiocattoli.RAGGI[1]
		await _metti(1, c2 + via * (r + 0.05))
		await _frames(120)
		var partenza := Vector2(g1.position.x, g1.position.z)
		var stand2 := partenza + via * 2.0
		var stand := Vector3(stand2.x, _fondo_sotto(Vector3(stand2.x, 0.0, stand2.y), [g1.get_rid()]) + 0.05, stand2.y)
		p.teleport(stand, 0.0, 0.0)
		await _frames(4)
		p.water_pack.set_tank_amount(30.0)
		Input.action_press(&"spray")
		for f in 480:
			p.look_at_point(g1.global_position + Vector3(0, EnigmaGiocattoli.ALTEZZE[1] * 0.6, 0))
			await get_tree().physics_frame
			dentro_max = maxf(dentro_max, r - Vector2(g1.position.x, g1.position.z).distance_to(c2))
		Input.action_release(&"spray")
		await _frames(60)
		var fine := Vector2(g1.position.x, g1.position.z)
		spostato_min = minf(spostato_min, fine.distance_to(partenza))
		print("    da %.0f gradi contro %s: il pallone da %s a %s" % [rad_to_deg(ang), vicina.snapped(Vector3.ONE * 0.01),
			partenza.snapped(Vector2.ONE * 0.01), fine.snapped(Vector2.ONE * 0.01)])
	check(spostato_min > 0.5, "spinto 8 s da tre lati contro il gonfiabile vicino alla botola, ci scivola attorno (si sposta almeno %.2f m)" % spostato_min)
	_controlla_staccato("contro i gonfiabili")
	_misura_quota = false
	_controlla_sotto("contro i gonfiabili")
	check(dentro_max < 0.02, "il pallone spinto 4 s contro ognuno non ci entra (al più %.1f cm)" % (dentro_max * 100.0))
	check(su_max < 0.03, "e resta sul fondo, non ci sale sopra (al più %.1f cm sopra il fondo)" % (su_max * 100.0))
	check(di_lato_min > 0.3, "spinto dritto contro, ci scivola attorno invece di fermarsi (di lato almeno %.2f m)" % di_lato_min)

	print("7. Calando l'acqua sopra un gonfiabile, il giocattolo ne scivola giù")
	# (sala ricaricata: svuotata, la piscina scolerebbe l'acqua rimessa)
	await _carica()
	await _metti(0, Vector2(vicina.x, vicina.y))
	await _frames(30)
	check(vasca.fill > 0.9 and enigma.galleggia(0), "la paperella galleggia sopra la ciambella (fill %.2f)" % vasca.fill)
	for k in 180:
		vasca.fill = 1.0 - float(k + 1) / 180.0
		await get_tree().physics_frame
	await _frames(180)
	var g0 := enigma.giocattolo(0)
	var esclusi0 := rids.duplicate()
	esclusi0.append(g0.get_rid())
	var d0 := Vector2(g0.position.x, g0.position.z).distance_to(Vector2(vicina.x, vicina.y))
	var su0 := g0.global_position.y - _fondo_sotto(g0.global_position, esclusi0)
	check(d0 >= vicina.z + EnigmaGiocattoli.RAGGI[0] - 0.02 and su0 < 0.02,
		"la paperella posata dall'acqua sopra la ciambella ne scivola giù sul fondo (a %.2f m dal centro, %.1f cm sopra il fondo)" % [d0, su0 * 100.0])
	_controlla_sotto("calando l'acqua sopra un gonfiabile")

	print("8. Contro il portellone e sulla giunzione del fondo il giocattolo resta sul fondo; la rete; il checkpoint")
	await _carica()
	vasca.fill = 0.0
	await _frames(30)
	var botola := Vector2(0.0, 2.0)
	var g := enigma.giocattolo(1)
	var vel: Array = enigma.get(&"_vel")
	_misura_quota = true
	# spinto dritto verso il portellone da otto lati, come nel ricontrollo di ambienti-2 (da 90 e 270 gradi lungo x = 0)
	var lontano_min := INF
	for k in 8:
		var via := Vector2(cos(k * PI / 4.0), sin(k * PI / 4.0))
		await _metti(1, botola + via * 1.6)
		await _frames(60)
		for f in 240:
			vel[1] += -via * 4.0 / 60.0
			await get_tree().physics_frame
			lontano_min = minf(lontano_min, Vector2(g.position.x, g.position.z).distance_to(botola))
		await _frames(120)
		print("    da %d gradi: il pallone in %s, %.3f sopra il fondo" % [k * 45, g.global_position.snapped(Vector3.ONE * 0.001),
			g.global_position.y - _fondo_dall_alto(g.global_position)])
	check(lontano_min > 1.2, "spinto dritto contro il portellone da otto lati non ci sale (al più vicino %.2f m dal centro)" % lontano_min)
	# lungo la giunzione, a x = 0 esatto, avanti e indietro
	for caso in [[Vector2(0.0, 3.4), Vector2(0.0, 1.0)], [Vector2(0.0, 3.9), Vector2(0.0, -1.0)], [Vector2(0.0, -0.4), Vector2(0.0, -1.0)]]:
		await _metti(1, caso[0])
		await _frames(30)
		for f in 180:
			vel[1] += (caso[1] as Vector2) * 3.0 / 60.0
			await get_tree().physics_frame
		await _frames(90)
	_controlla_staccato("contro il portellone e sulla giunzione")
	_misura_quota = false
	var fermo := g.global_position
	check(absf(fermo.y - _fondo_dall_alto(fermo)) < 0.02, "dopo, il pallone è sul fondo (%s, fondo %.3f)" % [fermo.snapped(Vector3.ONE * 0.001), _fondo_dall_alto(fermo)])
	_controlla_sotto("contro il portellone e sulla giunzione")
	# la rete: messo apposta sotto il fondo o fuori dall'area, guardando altrove, torna su
	var ys: Array = enigma.get(&"_y")
	await _metti(1, Vector2(2.5, -1.0))
	p.teleport(Vector3(-5.0, _fondo_sotto(Vector3(-5.0, 0.0, 3.0), []) + 0.05, 3.0), 0.0, 0.0)
	p.set_look(PI, 1.4)
	await _frames(5)
	g.global_position.y = -4.6
	ys[1] = -4.6
	await _frames(5)
	var qui := g.global_position
	check(qui.y > _fondo_dall_alto(qui) - 0.01 and qui.y < _fondo_dall_alto(qui) + 0.02, "messo sotto il fondo, torna sul fondo (%s, fondo %.3f)" % [qui.snapped(Vector3.ONE * 0.001), _fondo_dall_alto(qui)])
	g.position = Vector3(0.0, g.position.y, 9.0)
	await _frames(5)
	var partenza: Vector3 = enigma.partenze[1]
	check(Vector2(g.position.x, g.position.z).distance_to(Vector2(partenza.x, partenza.z)) < 0.05 and absf(g.global_position.y - _fondo_dall_alto(g.global_position)) < 0.02,
		"messo fuori dall'area, guardando altrove torna alla sua partenza (%s)" % g.global_position.snapped(Vector3.ONE * 0.001))
	# (sotto o fuori apposta: non conta per il controllo di ogni fotogramma)
	_sotto = 0.0
	_sotto_dove = ""
	# la ripartenza da un checkpoint: sotto il fondo apposta, e salvato sulla giunzione e riaperto in una sala nuova
	await _metti(1, Vector2(2.5, -1.0))
	g.global_position.y = -4.6
	ys[1] = -4.6
	enigma.load_state(enigma.save_state())
	await _frames(2)
	_sotto = 0.0
	_sotto_dove = ""
	check(absf(g.global_position.y - _fondo_dall_alto(g.global_position)) < 0.02, "ripartendo dal checkpoint con il pallone sotto il fondo, torna sul fondo (%s)" % g.global_position.snapped(Vector3.ONE * 0.001))
	await _metti(1, Vector2(0.0, 3.6))
	var salvato: Dictionary = enigma.save_state()
	await _carica()
	vasca.fill = 0.0
	enigma.load_state(salvato)
	await _frames(60)
	g = enigma.giocattolo(1)
	check(Vector2(g.position.x, g.position.z).distance_to(Vector2(0.0, 3.6)) < 0.3 and absf(g.global_position.y - _fondo_dall_alto(g.global_position)) < 0.02,
		"salvato sulla giunzione (0, 3,6) e riaperto in una sala nuova, il pallone è lì sul fondo (%s)" % g.global_position.snapped(Vector3.ONE * 0.001))
	_controlla_sotto("ripartendo dal checkpoint")
	_fine()


func _carica() -> void:
	GameState.reset_progress()
	get_tree().change_scene_to_file(LEVEL)
	for i in 300:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and get_tree().current_scene != null \
				and get_tree().current_scene != self:
			break
	await _frames(5)
	level = get_tree().current_scene
	p = GameState.player
	for i in 400:
		if p.input_enabled:
			break
		await get_tree().process_frame
	enigma = level.get_node_or_null(^"Piscina/EnigmaGiocattoli") as EnigmaGiocattoli
	check(enigma != null, "c'è l'enigma dei giocattoli nella piscina")
	if enigma == null:
		return
	vasca = level.get_node(^"Piscina/Pozza") as WaterTank
	piscina = level.get_node(^"Piscina/SvuotaPiscina") as PiscinaOnde
	pulsante = level.get_node(^"Piscina/PulsantePortello") as WaterButton
	portello = level.get_node(^"Piscina/Portello")
	_scesi = []
	_risolto = 0
	enigma.piatto_sceso.connect(func(i: int): _scesi.append(i))
	enigma.risolto.connect(func(): _risolto += 1)
	var picks := level.find_children("*", "PackPickup", true, false)
	if picks.size() > 0:
		(picks[0] as PackPickup).interact(p)
	await _frames(30)
	p.water_pack.jet_hit.connect(func(col: Object, _pt: Vector3, _n: Vector3):
		var k := "giocattolo" if col is AnimatableBody3D else ("acqua" if col is WaterTank else "altro")
		_colpi[k] = int(_colpi.get(k, 0)) + 1
		if k == "altro" and not _colpi.has("primo"):
			_colpi["primo"] = "%s %s" % [(col as Node).get_path() if col is Node else str(col), _pt.snapped(Vector3.ONE * 0.01)])


## Spinge col getto il giocattolo [param i] verso il suo cerchio: il giocatore dietro di lui (sul fondo o nell'acqua),
## mira al giocattolo e spruzza a colpi, finché ci arriva (o il piatto scende).
func _spingi(i: int, max_colpi := 40) -> bool:
	var g := enigma.giocattolo(i)
	var c := enigma.cerchio(i).global_position
	for colpo in max_colpi:
		var gp := g.global_position
		var d := Vector2(c.x - gp.x, c.z - gp.z)
		if enigma.piatto_giu(i) or (d.length() < 0.1 and enigma.velocita(i) < 0.05):
			return true
		var dir := d.normalized()
		var dietro := clampf(1.6 + d.length() * 0.3, 1.8, 3.0)
		var voluto := Vector2(gp.x - dir.x * dietro, gp.z - dir.y * dietro)
		# dove si sta: nella parte profonda, fra i muri (x ±7, z 5), non davanti alla cassetta del pulsante (prenderebbe
		# il getto). Se a quella distanza dietro di lui non ci si sta, ci si avvicina (fino a 70 cm, come chi gioca);
		# se neanche così, lo si spinge di sponda: davanti a lui, colpendo il muro o l'acqua alle sue spalle
		var dove_si_sta := Rect2(-6.6, -4.5, 13.2, 9.1)
		var si_sta := func(q: Vector2) -> bool:
			return dove_si_sta.has_point(q) and not (q.y > 3.9 and q.x > 1.0 and q.x < 3.5)
		while not si_sta.call(voluto) and dietro > 0.75:
			dietro -= 0.1
			voluto = Vector2(gp.x - dir.x * dietro, gp.z - dir.y * dietro)
		var sponda: bool = not si_sta.call(voluto)
		var stand := Vector3(voluto.x, 0.0, voluto.y)
		var lato := Vector2(-dir.y, dir.x)
		if sponda:
			# di fianco, colpendo l'acqua (o il muro) dietro di lui ma accanto, così il getto non prende lui
			if not si_sta.call(Vector2(gp.x, gp.z) + lato * 2.2):
				lato = -lato
			stand = Vector3(gp.x + lato.x * 2.2, 0.0, gp.z + lato.y * 2.2)
		stand.y = _fondo_sotto(Vector3(stand.x, 0.0, stand.z), []) + 0.05
		p.teleport(stand, atan2(-(gp.x - stand.x), -(gp.z - stand.z)), 0.0)
		await _frames(4)
		p.water_pack.set_tank_amount(20.0)
		# si spruzza finché va alla velocità giusta per arrivarci scivolando (non oltre)
		var v_obiettivo := clampf(d.length() * 0.8, 0.3, 1.8)
		Input.action_press(&"spray")
		for f in 70:
			# (un po' più in alto: il getto scende)
			var mira := g.global_position + Vector3(0, EnigmaGiocattoli.ALTEZZE[i] * 0.75 + 0.1 * Vector2(gp.x - stand.x, gp.z - stand.z).length(), 0)
			if sponda:
				mira = g.global_position - Vector3(dir.x, 0.0, dir.y) * (EnigmaGiocattoli.RAGGI[i] + 0.3) \
					+ Vector3(lato.x, 0.0, lato.y) * (EnigmaGiocattoli.RAGGI[i] + 0.1)
			p.look_at_point(mira)
			await get_tree().physics_frame
			if f > 8 and enigma.velocita(i) >= v_obiettivo:
				break
		Input.action_release(&"spray")
		for f in 90:
			await get_tree().physics_frame
			if enigma.velocita(i) < 0.05:
				break
		print("    colpo %d: giocattolo %d a %.2f m dal cerchio, colpito %d volte, acqua %d, altro %d" % [colpo, i,
			Vector2(c.x - g.global_position.x, c.z - g.global_position.z).length(), _colpi.get("giocattolo", 0),
			_colpi.get("acqua", 0), _colpi.get("altro", 0)], " ", _colpi.get("primo", ""), " giocatore ", p.global_position.snapped(Vector3.ONE * 0.01))
		_colpi.clear()
	var fine := enigma.giocattolo(i).global_position
	return enigma.piatto_giu(i) or Vector2(fine.x, fine.z).distance_to(Vector2(c.x, c.z)) < 0.15


## Mette il giocattolo [param i] in [param dove] (in pianta) e gli altri due fuori dai piedi, sulla pendenza a nord; i
## piatti tornano su.
func _metti(i: int, dove: Vector2) -> void:
	enigma.risolto_ok = false
	var pos := [[-1.5, -3.0, 0.0], [1.5, -3.0, 0.0], [0.0, -2.2, 0.0]]
	pos[i] = [dove.x, dove.y, 0.0]
	enigma.load_state({"pos": pos})
	await _frames(30)


## Se il giocattolo [param i] è vicino al bordo dell'area (un muro, la pendenza), il giocatore si mette fra lui e il muro
## e lo spinge verso il centro, come farebbe chi gioca, finché è ad almeno 80 cm dal bordo.
func _libera(i: int) -> bool:
	var g := enigma.giocattolo(i)
	var a := enigma.area
	for colpo in 8:
		var pos := Vector2(g.position.x, g.position.z)
		var fuori := Vector2.ZERO
		if pos.x < a.position.x + 0.8:
			fuori.x = -1.0
		elif pos.x > a.end.x - 0.8:
			fuori.x = 1.0
		if pos.y < a.position.y + 0.8:
			fuori.y = -1.0
		elif pos.y > a.end.y - 0.8:
			fuori.y = 1.0
		if fuori == Vector2.ZERO:
			return true
		var s2 := pos + fuori.normalized() * 0.75
		s2 = Vector2(clampf(s2.x, -6.6, 6.6), clampf(s2.y, -4.5, 4.6))
		var stand := Vector3(s2.x, _fondo_sotto(Vector3(s2.x, 0.0, s2.y), [g.get_rid()]) + 0.05, s2.y)
		p.teleport(stand, atan2(-(g.global_position.x - stand.x), -(g.global_position.z - stand.z)), 0.0)
		await _frames(4)
		p.water_pack.set_tank_amount(20.0)
		Input.action_press(&"spray")
		for f in 50:
			p.look_at_point(g.global_position + Vector3(0, EnigmaGiocattoli.ALTEZZE[i] * 0.6, 0))
			await get_tree().physics_frame
		Input.action_release(&"spray")
		for f in 150:
			await get_tree().physics_frame
			if enigma.velocita(i) < 0.05:
				break
		print("    dal bordo: giocattolo %d in %s" % [i, Vector2(g.position.x, g.position.z).snapped(Vector2.ONE * 0.01)])
	return false


func _svuota(max_pieni := 30) -> void:
	p.teleport(BORDO, 0.0, 0.0)
	await _frames(10)
	var pieni := 0
	while vasca.fill > 0.001 and pieni < max_pieni:
		p.water_pack.set_tank_amount(0.0)
		p.look_at_point(ACQUA)
		await _frames(20)
		Input.action_press(&"suck")
		var k := 0
		while p.water_pack.tank_amount < p.water_pack.tank_capacity - 0.01 and vasca.fill > 0.001 and k < 600 \
				and not bool(piscina.get(&"scola")):
			await get_tree().physics_frame
			k += 1
		Input.action_release(&"suck")
		pieni += 1
		p.look_at_point(FUORI)
		await _frames(20)
		Input.action_press(&"spray")
		k = 0
		while p.water_pack.tank_amount > 0.01 and k < 900:
			await get_tree().physics_frame
			k += 1
		Input.action_release(&"spray")
	for k in 200:
		if vasca.fill <= 0.0:
			break
		await get_tree().physics_frame


## Colpisce il pulsante della botola col getto dal fondo, davanti a lui (come test_tappe56).
func _colpisci_pulsante() -> void:
	p.teleport(Vector3(0.6, _fondo_sotto(Vector3(0.6, 0, 1.0), []) + 0.05, 1.0), PI, 0.0)
	await _frames(10)
	p.water_pack.set_tank_amount(20.0)
	p.look_at_point(pulsante.global_position + Vector3(0, 0.4, 0))
	await _frames(3)
	Input.action_press(&"spray")
	await _frames(60)
	Input.action_release(&"spray")
	for i in 240:
		await get_tree().physics_frame
		if bool(portello.get(&"is_open")):
			break


## Ogni fotogramma, se [member _misura_quota]: chi si muove sul fondo (non galleggia e non è sul suo piatto sceso) quanto
## sta sopra il fondo che ha sotto (i gonfiabili contano, gli altri giocattoli no). Gli spostamenti di più di 10 cm in un
## fotogramma sono i giocattoli rimessi a posto dal test, non si contano. Il fondo è cercato dall'alto ([method _fondo_dall_alto]).
func _misura_staccato() -> void:
	if not _misura_quota or not is_instance_valid(enigma) or not enigma.is_inside_tree() or not is_instance_valid(level) \
			or not level.is_inside_tree():
		return
	for k in 3:
		var g := enigma.giocattolo(k)
		var ora := Vector2(g.position.x, g.position.z)
		var mosso := ora.distance_to(_xz_prima[k])
		_xz_prima[k] = ora
		# (fermi e appoggiati con Posa sulla superficie che si vede, anche se urtati di qualche millimetro, non contano: sulla
		# rosa dei venti a mosaico, 6 mm sopra le collisioni, stanno 9 mm sopra il fondo che trova il raggio)
		if mosso < 0.0005 or mosso > 0.1 or enigma.piatto_giu(k) or enigma.galleggia(k) or bool((enigma.get(&"_assestato") as Array)[k]):
			continue
		var f := _fondo_dall_alto(g.global_position)
		if f < -50.0:
			continue
		var su := g.global_position.y - f
		if su > _staccato:
			_staccato = su
			_staccato_dove = "il giocattolo %d in %s, fondo %.3f, acqua %.2f" % [k, ora.snapped(Vector2.ONE * 0.01), f, vasca.fill]


## Ogni fotogramma: nessun giocattolo sotto il fondo della piscina (il fondo cercato dall'alto, [method _fondo_dall_alto]).
func _misura_sotto() -> void:
	if not is_instance_valid(enigma) or not enigma.is_inside_tree() or not is_instance_valid(level) or not level.is_inside_tree():
		return
	for k in 3:
		var g := enigma.giocattolo(k)
		var f := _fondo_dall_alto(g.global_position)
		if f > -50.0 and f - g.global_position.y > _sotto:
			_sotto = f - g.global_position.y
			_sotto_dove = "il giocattolo %d in %s, fondo %.3f" % [k, g.global_position.snapped(Vector3.ONE * 0.001), f]


func _controlla_sotto(quando: String) -> void:
	check(_sotto <= 0.01, "%s nessun giocattolo è mai sotto il fondo (al più %.1f cm%s)" % [quando, _sotto * 100.0,
		", " + _sotto_dove if not _sotto_dove.is_empty() else ""])
	_sotto = 0.0
	_sotto_dove = ""


## Il fondo della piscina sotto [param punto], cercato dall'alto (da sopra il bordo fino a -3, senza i giocattoli): un
## raggio al centro e due spostati di pochi millimetri, per la giunzione dei triangoli a x = 0. -99 se non lo trova.
func _fondo_dall_alto(punto: Vector3) -> float:
	var space := (level as Node3D).get_world_3d().direct_space_state
	var ex: Array[RID] = []
	for k in 3:
		ex.append(enigma.giocattolo(k).get_rid())
	for o in [Vector2.ZERO, Vector2(0.004, 0.003), Vector2(-0.003, -0.004)]:
		var q := PhysicsRayQueryParameters3D.create(Vector3(punto.x + o.x, 0.6, punto.z + o.y), Vector3(punto.x + o.x, -3.0, punto.z + o.y),
			Layers.WORLD, ex)
		var h := space.intersect_ray(q)
		if not h.is_empty():
			return (h.position as Vector3).y
	return -99.0


func _controlla_staccato(quando: String) -> void:
	check(_staccato <= 0.01, "%s, in movimento sul fondo i giocattoli non stanno mai più di 1 cm sopra il fondo che hanno sotto (al più %.1f cm%s)" % [
		quando, _staccato * 100.0, ", " + _staccato_dove if not _staccato_dove.is_empty() else ""])
	_staccato = 0.0
	_staccato_dove = ""


## Il fondo sotto [param punto]: il più alto di tre raggi a pochi millimetri l'uno dall'altro. Uno solo, proprio sulla
## giunzione fra due triangoli del fondo (x = 0), passa attraverso e trova il soffitto della camera delle onde, 2,4 m
## sotto, o niente (ricontrollo di ambienti-2). -99 se nessuno trova niente.
func _fondo_sotto(punto: Vector3, escludi: Array) -> float:
	var space := (level as Node3D).get_world_3d().direct_space_state
	var ex: Array[RID] = []
	for r in escludi:
		ex.append(r)
	var meglio := -99.0
	for o in [Vector2.ZERO, Vector2(0.004, 0.003), Vector2(-0.003, -0.004)]:
		var q := PhysicsRayQueryParameters3D.create(Vector3(punto.x + o.x, punto.y + 1.0, punto.z + o.y),
			Vector3(punto.x + o.x, punto.y - 4.0, punto.z + o.y), Layers.WORLD, ex)
		var h := space.intersect_ray(q)
		if not h.is_empty():
			meglio = maxf(meglio, (h.position as Vector3).y)
	return meglio


## Il giocattolo [param i] è appoggiato sul suo piatto: al centro del cerchio, alla quota del piatto sceso.
func _sul_piatto(i: int) -> bool:
	var g := enigma.giocattolo(i)
	var c := enigma.cerchio(i).global_position
	return Vector2(g.global_position.x, g.global_position.z).distance_to(Vector2(c.x, c.z)) < 0.05 \
		and absf(g.global_position.y - (c.y + enigma.sporgenza - enigma.corsa)) < 0.01


func _dove(i: int) -> String:
	var g := enigma.giocattolo(i).global_position
	var c := enigma.cerchio(i).global_position
	return "giocattolo %s, cerchio %s" % [g.snapped(Vector3.ONE * 0.01), c.snapped(Vector3.ONE * 0.01)]


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
		print("  ok    ", what)
	else:
		_failed += 1
		printerr("  FALLITO ", what)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _fine() -> void:
	print("\nRISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)
