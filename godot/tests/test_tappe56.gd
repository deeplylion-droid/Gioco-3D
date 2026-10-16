extends Node
## Test automatico delle tappe 5 e 6 (docs/livello/capitolo1.md), tutto il percorso dalla pozza
## della piscina a onde fino al raccordo, simulando gli input:
## - tappa 5 (rifatta il 15 ottobre): la piscina a onde si svuota con lo zaino, aspirando
##   l'acqua dal bordo e sparandola fuori dalla vasca (taratura di serie, circa 30 secondi e 4
##   zainate: si contano i pieni di zaino e il tempo); le micro medusine luminose nuotano
##   nell'acqua, si aspirano con lei, escono col getto e finiscono a terra fuori dalla vasca, e a
##   piscina vuota non ne resta nessuna; il pulsante della botola si attiva col lampeggiante
##   giallo, il getto lo fa diventare verde e apre il portello, e si scende dalla scala del pozzo;
## - camera delle onde e tunnel fino alla sala pompe;
## - tappa 6: acqua dalla vasca di raccolta, turbine nell'ordine sbagliato (si ricomincia) e in
##   quello dello schema (blu, giallo, rosso), la leva bloccata e poi tirata col getto, il
##   risveglio (flash, blackout con le sole luci rosse, neve sul monitor, paratie giù), la porta
##   col maniglione e il raccordo fino al pianerottolo davanti alla grata (la tappa 7 è in test_tappa7.gd);
## - i checkpoint lungo la strada e una ripartenza dopo il risveglio.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_tappe56.gd

const LEVEL := "res://scenes/sala_principale.tscn"

var level: Node
var tec: Node3D
var p: Player
var _passed := 0
var _failed := 0
## E1: mentre è vero, a ogni frame si guarda se la vista è finita sott'acqua.
var _controlla_sott_acqua := false
var _sott_acqua_visto := false
## Le micro medusine seguite a ogni passo della fisica mentre si svuota la piscina.
var _med: Medusine
var _med_vasca: WaterTank
var _med_fuori_acqua := 0
var _med_zaino_max := 0
var _med_sparate := {}
var _med_atterrate := {}
## Quante volte sono arrivati i segnali per l'audio della tappa 5.
var _segnali := {}
## Quando la piscina è rimasta vuota e quando si è attivato il pulsante (fotogrammi della fisica).
var _f := 0
var _f_vuota := -1
var _f_attivo := -1
var _svuota: PiscinaOnde


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	get_tree().change_scene_to_file(LEVEL)
	for i in 300:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player):
			break
	await _frames(5)
	level = get_tree().current_scene
	p = GameState.player
	for i in 400:
		if p.input_enabled:
			break
		await get_tree().process_frame
	tec = level.get_node_or_null("Tecnici") as Node3D
	check(tec != null, "gli ambienti tecnici sono montati sotto la sala")
	if tec == null:
		_fine()
		return
	var porta_sala: Node3D = level.get_node("Sala/Interattivi/sala_portello_scarico")
	var centro_pozzo := tec.to_global(_m("marker_portello"))
	check(Vector2(centro_pozzo.x, centro_pozzo.z).distance_to(Vector2(0.0, 2.0)) < 0.05 and absf(centro_pozzo.y + 2.25) < 0.1,
		"il pozzo è sotto il centro del portello (%s)" % centro_pozzo)
	var doppione := tec.get_node_or_null("Ambienti/CameraOnde/PORTELLO") as Node3D
	check(doppione == null or not doppione.visible, "il coperchio doppione in cima al pozzo è nascosto")
	check(porta_sala != null, "c'è il portello della sala")

	# Lo zaino: quello dello stanzino (con gli interni) o della rastrelliera.
	var picks := level.find_children("*", "PackPickup", true, false)
	if picks.size() > 0:
		(picks[0] as PackPickup).interact(p)
	await _frames(3)
	check(p.water_pack.equipped, "lo zaino è in spalla")

	print("Tappa 5: la piscina a onde si svuota con lo zaino")
	var puddle: WaterTank = level.get_node("Piscina/Pozza")
	var svuota: PiscinaOnde = level.get_node("Piscina/SvuotaPiscina")
	var hatch_button: WaterButton = level.get_node("Piscina/PulsantePortello")
	var hatch: Node = level.get_node("Piscina/Portello")
	check(svuota.taratura == PiscinaOnde.Taratura.TRENTA_SECONDI and svuota.pieni_da_togliere() == 4
			and is_equal_approx(puddle.get_liters(), svuota.litri_da_togliere()),
		"di serie la taratura da circa 30 secondi, 4 zainate (%.0f litri)" % puddle.get_liters())
	check(not hatch_button.enabled, "finché c'è acqua il pulsante della botola è spento")
	# Le micro medusine luminose (scelta dell'utente del 16 ottobre).
	var med := svuota.get_node_or_null("Medusine") as Medusine
	check(med != null, "nella piscina ci sono le micro medusine luminose")
	if med:
		await _frames(10)
		check(med.numero >= 12 and med.numero <= 18 and med.in_acqua() == med.numero,
			"una quindicina, tutte nell'acqua (%d su %d)" % [med.in_acqua(), med.numero])
		var livello := puddle.get_surface_global_y()
		var pos0 := med.posizioni()
		var sotto := 0
		var profonde := 0
		for q in pos0:
			if q.y < livello and q.y > med.fondo(q.x, q.z):
				sotto += 1
			if q.z > -2.0 and absf(q.x) < 7.0:
				profonde += 1
		check(sotto == pos0.size(), "nuotano sotto il pelo e sopra il fondo (%d su %d)" % [sotto, pos0.size()])
		check(profonde == pos0.size(), "nella parte profonda (%d su %d)" % [profonde, pos0.size()])
		var colori := {}
		for c in med.colori:
			colori[c.to_html()] = true
		check(colori.size() >= 4, "di vari colori (%d)" % colori.size())
		var r_min := 1.0
		var r_max := 0.0
		for r in med.raggi():
			r_min = minf(r_min, r)
			r_max = maxf(r_max, r)
		check(r_min > 0.02 and r_max < 0.08, "piccole: campane da %.0f a %.0f cm" % [r_min * 200.0, r_max * 200.0])
		var c_min := 1.0
		var c_max := 0.0
		for i in 120:
			await get_tree().physics_frame
			var cc := med.contrazioni()
			c_min = minf(c_min, cc[0])
			c_max = maxf(c_max, cc[0])
		check(c_min < 0.1 and c_max > 0.9, "la campana pulsa: si chiude e si riapre (%.2f-%.2f)" % [c_min, c_max])
		var mosse := 0
		var pos1 := med.posizioni()
		for i in pos0.size():
			if pos0[i].distance_to(pos1[i]) > 0.01:
				mosse += 1
		check(mosse >= pos0.size() - 1, "nuotano (%d su %d si sono spostate)" % [mosse, pos0.size()])
		_med = med
		_med_vasca = puddle
		med.aspirata.connect(func(_q): _segnali["aspirata"] = int(_segnali.get("aspirata", 0)) + 1)
		med.sparata.connect(func(_q): _segnali["sparata"] = int(_segnali.get("sparata", 0)) + 1)
	svuota.svuotamento.connect(func(on: bool): _segnali["svuotamento_" + str(on)] = int(_segnali.get("svuotamento_" + str(on), 0)) + 1)
	svuota.lampeggio.connect(func(): _segnali["lampeggio"] = int(_segnali.get("lampeggio", 0)) + 1)
	svuota.pulsante_premuto.connect(func(): _segnali["premuto"] = int(_segnali.get("premuto", 0)) + 1)
	_svuota = svuota
	p.water_pack.set_tank_amount(0.0)
	var esito: Array = await _svuota_piscina(puddle, Vector3(7.35, 0.0, 2.0), Vector3(6.5, -1.5, 2.0), Vector3(13.0, 0.5, 2.0))
	print("  (taratura da 30 secondi: %d pieni di zaino, %.0f secondi)" % [esito[0], esito[1]])
	check(puddle.fill <= 0.001, "aspirando dal bordo e sparando fuori la piscina si svuota (fill %.3f)" % puddle.fill)
	check(int(esito[0]) == svuota.pieni_da_togliere(), "servono %d pieni di zaino (%d)" % [svuota.pieni_da_togliere(), int(esito[0])])
	check(float(esito[1]) > 18.0 and float(esito[1]) < 42.0, "circa 30 secondi di lavoro (%.0f s)" % float(esito[1]))
	check(int(_segnali.get("svuotamento_true", 0)) == int(esito[0]) and int(_segnali.get("svuotamento_false", 0)) == int(esito[0]),
		"per l'audio: svuotamento(true/false) a ogni zainata (%s)" % str(_segnali))
	if med:
		await _frames(90)
		_med = null
		check(med.in_acqua() == 0, "a piscina vuota non resta nessuna medusina nell'acqua")
		check(_med_fuori_acqua == 0, "mentre nuotano restano nell'acqua (%d volte fuori)" % _med_fuori_acqua)
		check(_med_zaino_max >= 1, "si aspirano con l'acqua: entrano nello zaino (fino a %d insieme)" % _med_zaino_max)
		check(_med_sparate.size() >= med.numero - 1, "ed escono col getto (%d su %d)" % [_med_sparate.size(), med.numero])
		var fuori := 0
		for k in _med_atterrate:
			if (_med_atterrate[k] as Vector3).x > 7.2:
				fuori += 1
		check(_med_atterrate.size() >= med.numero - 2 and fuori == _med_atterrate.size(),
			"volano via e finiscono a terra fuori dalla vasca (%d a terra, %d fuori)" % [_med_atterrate.size(), fuori])
		check(med.quante(Medusine.Stato.NELLO_ZAINO) == 0 and med.quante(Medusine.Stato.IN_VOLO) == 0,
			"nello zaino e in volo non ne resta nessuna")
		check(int(_segnali.get("aspirata", 0)) >= med.numero - 1 and int(_segnali.get("sparata", 0)) == _med_sparate.size(),
			"per l'audio: un segnale quando entrano nell'ugello e uno quando escono col getto")
		await _frames(int(med.durata_a_terra * 60.0) + 30)
		check(med.quante(Medusine.Stato.A_TERRA) == 0, "a terra si spengono e spariscono")
	for i in 200:
		if svuota.attivo:
			break
		await get_tree().physics_frame
	check(hatch_button.enabled and svuota.attivo, "a piscina vuota il pulsante si attiva")
	var ritardo := (_f_attivo - _f_vuota) / 60.0
	check(absf(ritardo - svuota.ritardo_pulsante) < 0.1,
		"ma solo %.1f s dopo che l'acqua è finita, dopo il sorso finale della piscina vuota (%.2f s)" % [svuota.ritardo_pulsante, ritardo])
	var lampeggiante := svuota.get_node_or_null("SegnalePulsante") as OmniLight3D
	var giallo := lampeggiante != null and lampeggiante.visible and lampeggiante.light_color.r > 0.9 \
		and lampeggiante.light_color.g < 0.85 and lampeggiante.light_color.b < 0.3
	var e_min := 100.0
	var e_max := 0.0
	var lampi := int(_segnali.get("lampeggio", 0))
	for i in 200:
		await get_tree().physics_frame
		if lampeggiante:
			e_min = minf(e_min, lampeggiante.light_energy)
			e_max = maxf(e_max, lampeggiante.light_energy)
	lampi = int(_segnali.get("lampeggio", 0)) - lampi
	check(giallo and e_max > 3.0 * e_min, "e il suo lampeggiante giallo lampeggia (%.2f-%.2f)" % [e_min, e_max])
	check(lampi >= 2 and lampi <= 3, "un lampo ogni 1,6 s, col segnale per il richiamo dell'audio (%d in 3,3 s)" % lampi)
	check(_checkpoint() == "Piscina/CheckpointPozzaVuota", "checkpoint: piscina vuota (%s)" % _checkpoint())
	p.water_pack.set_tank_amount(20.0)
	p.teleport(Vector3(0.6, -1.95, 1.0), PI, 0.0)
	await _frames(10)
	p.look_at_point(hatch_button.global_position + Vector3(0, 0.4, 0))
	await _frames(3)
	await _hold(&"spray", 60)
	for i in 300:
		await get_tree().physics_frame
		if bool(hatch.get(&"is_open")):
			break
	check(bool(hatch.get(&"is_open")), "il pulsante apre il portello")
	check(svuota.premuto() and lampeggiante != null and lampeggiante.light_color.g > 0.9 and lampeggiante.light_color.r < 0.5,
		"e la luce diventa verde")
	var lampi_dopo := int(_segnali.get("lampeggio", 0))
	await _frames(120)
	check(int(_segnali.get("premuto", 0)) == 1 and int(_segnali.get("lampeggio", 0)) == lampi_dopo,
		"col segnale pulsante_premuto, e il lampeggiante (e il richiamo) si ferma")
	check(not bool(level.get(&"demo_finished")), "la demo non finisce più al portello")

	print("Giù dalla scala del pozzo")
	# Sul fondo, a sud del buco, si cammina verso la scala (nord) e ci si aggrappa.
	p.teleport(Vector3(0.0, -2.2, 3.25), 0.0, 0.0)
	await _frames(10)
	check(p.is_on_floor() and p.global_position.y > -2.4, "si sta sul fondo della piscina accanto al buco (y %.2f)" % p.global_position.y)
	Input.action_press(&"move_forward")
	for i in 240:
		await get_tree().physics_frame
		if p.is_on_ladder():
			break
	Input.action_release(&"move_forward")
	check(p.is_on_ladder(), "si prende la scala del pozzo (%s)" % p.global_position)
	Input.action_press(&"move_back")
	for i in 600:
		await get_tree().physics_frame
		if not p.is_on_ladder() and p.is_on_floor() and p.global_position.y < -8.5:
			break
	Input.action_release(&"move_back")
	await _frames(10)
	var giu := p.global_position
	check(absf(giu.y - (-9.05)) < 0.15, "si scende fino in fondo al pozzo (y %.2f)" % giu.y)
	check(not p.is_on_ladder(), "e si lascia la scala sul pavimento della camera delle onde")
	await _frames(5)
	check(_checkpoint() == "Tecnici/Logica/Checkpoint/CheckpointPozzo", "checkpoint: in fondo al pozzo (%s)" % _checkpoint())
	# E si risale fino al fondo della piscina: avanti verso la scala, su, e in cima si scavalca il
	# bordo dalla parte della cerniera, sopra il portello aperto.
	p.teleport(p.global_position + Vector3(0.0, 0.0, 0.3), 0.0, 0.0)
	await _frames(30)
	Input.action_press(&"move_forward")
	var su := false
	for i in 900:
		await get_tree().physics_frame
		if p.is_on_ladder():
			su = true
		if su and not p.is_on_ladder() and p.is_on_floor() and p.global_position.y > -2.5:
			break
	await _frames(30)
	Input.action_release(&"move_forward")
	await _frames(10)
	check(su and p.is_on_floor() and p.global_position.y > -2.3 and p.global_position.z < 1.2,
		"risalendo si esce dal pozzo sul fondo della piscina, sopra il portello aperto (%s)" % p.global_position)
	# E di nuovo giù, per andare avanti (guardando in basso e camminando nel buco).
	p.teleport(Vector3(0.0, -2.2, 3.25), 0.0, 0.0)
	await _frames(5)
	p.set_look(0.0, deg_to_rad(-60.0))
	Input.action_press(&"move_forward")
	for i in 900:
		await get_tree().physics_frame
		if not p.is_on_ladder() and p.is_on_floor() and p.global_position.y < -8.5:
			break
	Input.action_release(&"move_forward")
	await _frames(5)
	check(p.global_position.y < -8.5, "guardando in basso e camminando nel buco si scende (y %.2f)" % p.global_position.y)

	print("La camera delle onde e il tunnel fino alla sala pompe")
	# E1: la camera delle onde e il tunnel passano sotto la vasca della medusa e sotto la vasca
	# lava-piedi degli spogliatoi: lì la vista non deve mai diventare quella sott'acqua.
	var effetto := _effetto_sott_acqua()
	check(effetto != null, "la camera del giocatore ha l'effetto sott'acqua")
	# Riscontro v0.3.1, punto 6: i due cancelli stagni sono chiusi e si aprono da soli al passaggio.
	var cancelli: Array[Paratia] = []
	for n in ["Tecnici/Logica/SalaPompe/Paratia1", "Tecnici/Logica/SalaPompe/Paratia2"]:
		cancelli.append(level.get_node(n) as Paratia)
	check(cancelli.all(func(c): return not c.is_aperta and not c.is_chiusa), "scesi dalla scala, i due cancelli stagni sono chiusi")
	var space0 := p.get_world_3d().direct_space_state
	var q0 := PhysicsRayQueryParameters3D.create(tec.to_global(Vector3(14.0, 1.0, 0.0)), tec.to_global(Vector3(23.0, 1.0, 0.0)))
	check(not space0.intersect_ray(q0).is_empty(), "e chiudono davvero il passaggio")
	var audio := get_node_or_null(^"/root/Audio")
	var suoni_prima := int(audio.get(&"conteggio").get(&"cancello_stagno_apre", 0)) if audio else 0
	_sott_acqua_visto = false
	_controlla_sott_acqua = true
	var ok := true
	for loc in [Vector3(4.0, 0, 0.3), Vector3(16.0, 0, 0.3), Vector3(23.0, 0, 0.0), Vector3(27.0, 0, 0.0), Vector3(31.0, 0, 0.0)]:
		ok = ok and await _cammina_verso(tec.to_global(loc), 900)
	_controlla_sott_acqua = false
	check(ok, "si cammina dalla scala, sotto le paratie e nel tunnel fino alla sala pompe")
	check(cancelli.all(func(c): return c.is_aperta), "al passaggio i cancelli stagni si sono aperti da soli")
	if audio:
		var suoni := int(audio.get(&"conteggio").get(&"cancello_stagno_apre", 0)) - suoni_prima
		check(suoni == 2, "ognuno col suo colpo metallico (cancello_stagno_apre: %d)" % suoni)
	check(audio == null or audio.call(&"stream_di", &"cancello_stagno_apre") != null, "il suono cancello_stagno_apre è nel catalogo")
	check(space0.intersect_ray(q0).is_empty(), "e passato il giocatore restano aperti")
	check(not _sott_acqua_visto, "E1: camminando nella camera delle onde e nel tunnel la vista non va mai sott'acqua")
	print("E1: la vista sott'acqua solo nell'acqua profonda")
	var vasca_medusa: WaterTank = level.get_node("Vasca/VascaCentrale")
	var lavapiedi := level.find_children("VascaLavapiedi", "WaterTank", true, false)
	var sotto_medusa := Vector3(0.0, vasca_medusa.get_floor_global_y() - 7.5, vasca_medusa.global_position.z)
	check(not await _sott_acqua_in(sotto_medusa), "nel tunnel sotto la vasca della medusa non si è sott'acqua")
	if lavapiedi.size() > 0:
		var lp := lavapiedi[0] as WaterTank
		check(not await _sott_acqua_in(Vector3(lp.global_position.x, -7.4, lp.global_position.z)), "nel tunnel sotto la vasca lava-piedi non si è sott'acqua")
		check(not await _sott_acqua_in(lp.global_position + Vector3(0.0, lp.get_level() * 0.5, 0.0)), "e nemmeno dentro il velo d'acqua della lava-piedi (%.2f m)" % lp.get_level())
	check(await _sott_acqua_in(vasca_medusa.global_position + Vector3(0.0, vasca_medusa.get_level() * 0.5, 0.0)), "dentro la vasca della medusa (acqua profonda) invece sì")
	var arrivo: WaterTank = level.get_node("Vasche/VascaArrivo")
	check(await _sott_acqua_in(Vector3(arrivo.global_position.x, arrivo.get_surface_global_y() - 0.3, arrivo.global_position.z)), "e anche sotto il pelo della vasca d'arrivo")
	check(not await _sott_acqua_in(Vector3(arrivo.global_position.x, arrivo.get_floor_global_y() - 3.0, arrivo.global_position.z)), "ma non tre metri sotto il suo fondo")
	await _frames(5)
	check(_checkpoint() == "Tecnici/Logica/Checkpoint/CheckpointSalaPompe", "checkpoint: ingresso della sala pompe (%s)" % _checkpoint())

	print("Tappa 6: acqua dalla vasca di raccolta")
	var raccolta: WaterTank = tec.get_node("Acqua/VascaRaccolta")
	p.water_pack.set_tank_amount(0.0)
	_metti(Vector3(36.5, 0.0, 3.1), Vector3(36.5, -0.15, 1.2))
	await _frames(8)
	_guarda(Vector3(36.5, -0.15, 1.2))
	var prima := raccolta.get_liters()
	await _hold(&"suck", 90)
	check(p.water_pack.tank_amount > 8.0, "lo zaino si riempie dalla vasca di raccolta (%.1f l)" % p.water_pack.tank_amount)
	check(raccolta.get_liters() < prima - 5.0, "e la vasca di raccolta scende")

	var ris: RisveglioSalaPompe = level.get(&"risveglio")
	var leva: LevaGrande = ris.leva
	print("Il monitor della telecamera")
	var mon: MonitorCrt = ris.monitor
	check(mon.immagine != null and not mon.mostra_neve_attiva() and mon.sovrimpressione().begins_with(mon.data),
		"il monitor mostra la sala dalla telecamera, con data e ora (%s)" % mon.sovrimpressione())
	var schermo := tec.find_child("SCHERMO_CRT", true, false) as MeshInstance3D
	check(schermo != null and schermo.material_override is ShaderMaterial
			and (schermo.material_override as ShaderMaterial).shader.resource_path.ends_with("crt.gdshader"),
		"E5: sullo schermo c'è l'immagine del tubo (non il materiale del modello)")
	check(mon.schermo_sul_vetro != null and schermo.mesh == mon.schermo_sul_vetro and mon.vertici_sul_vetro >= 200,
		"E5: lo schermo è appoggiato sul vetro bombato, non un foglio piatto davanti (%d vertici)" % mon.vertici_sul_vetro)
	var ora := mon.sovrimpressione()
	await _frames(70)
	check(mon.sovrimpressione() != ora, "e l'ora corre (%s)" % mon.sovrimpressione())
	print("La leva bloccata")
	p.water_pack.set_tank_amount(20.0)
	_metti(Vector3(43.6, 0.0, -4.4), _m("marker_leva") + Vector3(0, 0.25, 0))
	await _frames(8)
	_guarda(_m("marker_leva") + Vector3(0, 0.45, 0))
	var bloccate := [0]
	leva.colpita_bloccata.connect(func(): bloccate[0] += 1)
	await _hold(&"spray", 60)
	check(bloccate[0] > 0 and not leva.abbassata, "prima delle pompe il getto arriva alla leva oltre la grata, ma è bloccata")

	print("Le turbine nell'ordine sbagliato")
	var sbagliate := [0]
	ris.sequenza_sbagliata.connect(func(): sbagliate[0] += 1)
	await _gira_turbina(ris.turbine[0])     # blu: giusta
	check(ris.avviate == 1 and ris.pompe[0].stato == Pompa.Stato.AVVIATA, "la turbina blu avvia la sua pompa")
	await _gira_turbina(ris.turbine[2])     # rossa: tocca alla gialla
	check(sbagliate[0] == 1 and ris.avviate == 0 and ris.pompe[0].stato == Pompa.Stato.FERMA, "la rossa prima della gialla: le pompe si fermano, si ricomincia")
	await _ferme(ris.turbine)

	print("Le turbine nell'ordine dello schema: blu, giallo, rosso")
	for i in 3:
		await _gira_turbina(ris.turbine[i])
		check(ris.avviate == i + 1 and ris.pompe[i].stato == Pompa.Stato.AVVIATA, "pompa %d avviata (%s)" % [i + 1, ris.turbine[i].name])
	check(leva.sbloccata, "con le tre pompe la leva si sblocca")

	print("La leva e il risveglio")
	var fasi := []
	GameState.luci_cambiate.connect(func(f): fasi.append(f))
	p.water_pack.set_tank_amount(20.0)
	_metti(Vector3(43.6, 0.0, -4.4), _m("marker_leva") + Vector3(0, 0.25, 0))
	await _frames(8)
	_guarda(_m("marker_leva") + Vector3(0, 0.45, 0))
	await _hold(&"spray", 60)
	check(leva.abbassata, "il getto tira giù la leva")
	check(GameState.luci == GameState.Luci.FLASH, "tutte le luci si accendono (flash)")
	for pm in ris.pompe:
		check(pm.stato == Pompa.Stato.RUGGISCE, "la pompa %s ruggisce" % pm.name)
	await _frames(int(ris.durata_flash * 60) + 10)
	check(GameState.luci == GameState.Luci.BLACKOUT and fasi == [GameState.Luci.FLASH, GameState.Luci.BLACKOUT], "poi salta la corrente (blackout)")
	check(ris.monitor.mostra_neve_attiva(), "il monitor mostra solo neve")
	# (I neon si spengono con una scintilla di un terzo di secondo.)
	await _frames(30)
	var accese := 0
	var rosse := 0
	var altre := []
	for l in tec.find_children("*", "Light3D", true, false):
		if (l as Light3D).visible and (l as Light3D).is_visible_in_tree() and (l as Light3D).light_energy > 0.01:
			accese += 1
			if LuciRisveglio._di_emergenza(l) or (l as Light3D).has_meta(&"risveglio_ignora"):
				rosse += 1
			else:
				altre.append(String(tec.get_path_to(l)))
	check(accese > 0 and accese == rosse, "restano solo le luci rosse d'emergenza (e il monitor): %d su %d %s" % [rosse, accese, altre])
	var porta: PortaManiglione = ris.porta
	porta.interact(p)
	await _frames(3)
	check(not porta.is_open, "durante il risveglio la porta è ancora bloccata")
	for i in 60 * 20:
		if ris.finito:
			break
		await get_tree().physics_frame
	check(ris.finito, "il risveglio arriva alla fine")
	for pa in ris.paratie:
		check(pa.is_chiusa, "la paratia %s è scesa" % pa.name)
	var space := p.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(tec.to_global(Vector3(15.0, 1.0, 0.0)), tec.to_global(Vector3(23.0, 1.0, 0.0)))
	check(not space.intersect_ray(q).is_empty(), "le paratie chiudono la camera delle onde")
	await _frames(3)
	check(_checkpoint() == "Tecnici/Logica/Checkpoint/CheckpointRisveglio", "checkpoint: dopo il risveglio (%s)" % _checkpoint())
	check(int(GameState.snapshot.get("luci", -1)) == GameState.Luci.BLACKOUT, "il checkpoint ricorda il blackout")

	print("La porta del ponte inferiore e il raccordo")
	_metti(_m("marker_porta_ponte"), _m("marker_porta_ponte") + Vector3(1.0, 1.0, 0.0))
	await _frames(5)
	porta.interact(p)
	for i in 120:
		await get_tree().physics_frame
	check(porta.is_open, "col maniglione la porta si apre")
	ok = true
	for loc in [Vector3(47.4, 0, 1.4), Vector3(51.6, 0, 1.4), Vector3(51.6, 0, 0.6), Vector3(51.6, 3.625, -6.2),
			Vector3(50.0, 3.625, -7.8), Vector3(44.6, 7.25, -7.8)]:
		ok = ok and await _cammina_verso(tec.to_global(loc), 900)
	check(ok, "dalla porta su per le due rampe del raccordo")
	await _frames(10)
	check(_checkpoint() == "Tecnici/Logica/Checkpoint/CheckpointRaccordo", "checkpoint: in cima al raccordo (%s)" % _checkpoint())
	ok = await _cammina_verso(tec.to_global(Vector3(44.55, 7.25, -4.0)), 600)
	await _frames(10)
	check(ok and not bool(level.get(&"demo_finished")), "la demo va avanti per il corridoio verso il magazzino dei gonfiabili (tappa 7, test_tappa7.gd)")

	print("Si riparte dal checkpoint del risveglio")
	GameState.snapshot["checkpoint"] = "Tecnici/Logica/Checkpoint/CheckpointRisveglio"
	GameState.imposta_luci(GameState.Luci.PRIMA_DEL_RISVEGLIO)
	GameState._restore_pending = true
	GameState._on_level_ready()
	await _frames(5)
	check(GameState.luci == GameState.Luci.BLACKOUT, "ripartendo, le luci sono di nuovo al blackout")

	_fine()


## Svuota la piscina come farebbe un giocatore dal bordo: si gira verso l'acqua (mezzo secondo),
## aspira finché lo zaino è pieno, si gira (mezzo secondo) e spara fuori dalla vasca finché lo zaino
## è vuoto. Ritorna [pieni di zaino, secondi].
func _svuota_piscina(vasca: WaterTank, dove: Vector3, acqua: Vector3, fuori: Vector3, max_pieni := 40) -> Array:
	p.teleport(dove, 0.0, 0.0)
	await _frames(10)
	var fotogrammi := 0
	var pieni := 0
	while vasca.fill > 0.001 and pieni < max_pieni:
		p.look_at_point(acqua)
		await _frames(30)
		fotogrammi += 30
		Input.action_press(&"suck")
		var k := 0
		while p.water_pack.tank_amount < p.water_pack.tank_capacity - 0.01 and vasca.fill > 0.001 and k < 600:
			await get_tree().physics_frame
			k += 1
		Input.action_release(&"suck")
		fotogrammi += k
		pieni += 1
		p.look_at_point(fuori)
		await _frames(30)
		fotogrammi += 30
		Input.action_press(&"spray")
		k = 0
		while p.water_pack.tank_amount > 0.01 and k < 900:
			await get_tree().physics_frame
			k += 1
		Input.action_release(&"spray")
		fotogrammi += k
	return [pieni, fotogrammi / 60.0]


func _physics_process(_delta: float) -> void:
	_f += 1
	if _svuota and is_instance_valid(_svuota) and _svuota.vasca:
		if _f_vuota < 0 and _svuota.vasca.fill <= 0.001:
			_f_vuota = _f
		if _f_attivo < 0 and _svuota.attivo:
			_f_attivo = _f
	if _med and is_instance_valid(_med):
		_segui_medusine()
	if _controlla_sott_acqua:
		var e := _effetto_sott_acqua()
		if e and e.is_underwater:
			if not _sott_acqua_visto:
				printerr("  vista sott'acqua in ", p.camera.global_position)
			_sott_acqua_visto = true


## Le micro medusine mentre si svuota la piscina: quelle che nuotano stanno nell'acqua, quante
## sono nello zaino, quali escono col getto e dove cadono.
func _segui_medusine() -> void:
	var livello := _med_vasca.get_surface_global_y()
	var st := _med.stati()
	var pos := _med.posizioni()
	var r := _med.raggi()
	var nello_zaino := 0
	for i in st.size():
		match st[i]:
			Medusine.Stato.NUOTA:
				if pos[i].y > livello - r[i] * 0.5 + 0.002 and _med_vasca.fill > 0.02 and pos[i].y > _med.fondo(pos[i].x, pos[i].z) + r[i]:
					if _med_fuori_acqua == 0:
						printerr("  medusina %d fuori dall'acqua in %s (pelo a %.3f)" % [i, pos[i], livello])
					_med_fuori_acqua += 1
			Medusine.Stato.NELLO_ZAINO:
				nello_zaino += 1
			Medusine.Stato.IN_VOLO:
				_med_sparate[i] = true
			Medusine.Stato.A_TERRA:
				if not _med_atterrate.has(i):
					_med_atterrate[i] = pos[i]
	_med_zaino_max = maxi(_med_zaino_max, nello_zaino)


func _effetto_sott_acqua() -> UnderwaterEffect:
	var e := p.find_children("*", "UnderwaterEffect", true, false)
	return e[0] as UnderwaterEffect if e.size() > 0 else null


## E1: una camera libera in [param dove]: la vista è quella sott'acqua? (Poi torna la camera del giocatore.)
func _sott_acqua_in(dove: Vector3) -> bool:
	var cam := Camera3D.new()
	level.add_child(cam)
	cam.global_position = dove
	cam.current = true
	await _frames(3)
	var e := _effetto_sott_acqua()
	var sotto := e != null and e.is_underwater
	cam.queue_free()
	p.camera.current = true
	await _frames(3)
	return sotto


func _fine() -> void:
	print("")
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


## La turbina gira col getto finché non dà energia (il giocatore davanti, a 2 m).
func _gira_turbina(t: Turbine) -> void:
	p.water_pack.set_tank_amount(20.0)
	var centro := tec.to_local(t.global_position)
	_metti(Vector3(centro.x, 0.0, centro.z + 2.4), centro + Vector3(0, 0.2, 0))
	await _frames(8)
	_guarda(centro + Vector3(0, 0.35, 0))
	for i in 6:
		if t.powered:
			break
		await _hold(&"spray", 40)
	await _frames(2)


## Aspetta che le turbine si fermino (senza energia).
func _ferme(ts: Array) -> void:
	for i in 60 * 30:
		var tutte := true
		for t in ts:
			if (t as Turbine).powered:
				tutte = false
		if tutte:
			return
		await get_tree().physics_frame


## Mette il giocatore in [param dove] (coordinate degli ambienti tecnici) e lo gira verso [param verso].
func _metti(dove: Vector3, verso: Vector3) -> void:
	var g := tec.to_global(dove)
	p.teleport(g + Vector3(0, 0.05, 0), p.yaw, 0.0)
	_guarda(verso)


func _guarda(verso_locale: Vector3) -> void:
	p.look_at_point(tec.to_global(verso_locale))


func _m(nome: String) -> Vector3:
	return (tec.get_node("Marker/" + nome) as Node3D).position


func _checkpoint() -> String:
	return String(GameState.snapshot.get("checkpoint", ""))


## Cammina in avanti verso t finché non ci arriva (in pianta). Falso se si blocca.
func _cammina_verso(t: Vector3, max_frames: int) -> bool:
	Input.action_press(&"move_forward")
	var arrivato := false
	for i in max_frames:
		var d := t - p.global_position
		if Vector2(d.x, d.z).length() < 0.35:
			arrivato = true
			break
		p.set_look(atan2(-d.x, -d.z), 0.0)
		await get_tree().physics_frame
	Input.action_release(&"move_forward")
	if not arrivato:
		printerr("  bloccato in ", p.global_position, " andando verso ", t)
	return arrivato


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


func _hold(action: StringName, frames: int) -> void:
	Input.action_press(action)
	await _frames(frames)
	Input.action_release(action)
