extends Node
## Scatti di controllo della prova della v0.3.1 (riscontri 1, 11, 13 e 14), dal motore, prima e dopo:
## - serranda_sala, serranda_magazzino: la serranda del magazzino dalla sala (prima del risveglio) e
##   dal magazzino (al buio); serranda_si_alza, serranda_aperta: ci arrivi dal magazzino e si alza;
## - scia_vasca, scia_serranda, scia_bimbi: la scia di bava dalla vasca centrale, vista uscendo dalla
##   serranda e dove gira lungo il muro ovest verso l'area bimbi (al buio); scia_centro, scia_muro_ovest,
##   scia_fossa: il resto del percorso fino alla fossa. Con SCATTI_BAVA_VECCHIA=1 la bava è com'era
##   fino alla v0.3.2 (non appoggiata al pavimento), per il confronto prima/dopo;
## - t8_arrivo: arrivi all'area bimbi seguendo la scia, un minuto dopo il risveglio;
## - t8_presa_lato: ti avvicini di lato e lei ti prende (la camera della sequenza di morte);
## - t8_scivola: lei scivola sotto (tre scatti di fila);
## - occhio_cordone: dal cordone, di lato, il getto in faccia alla medusa affacciata;
## - portellone_spiaggia (e portellone_spiaggia_spenta, senza la sua luce): piscina piena, dalla
##   spiaggia, la luce del portellone attraverso l'acqua (punto 3);
## - portellone_getto (e portellone_getto_vecchio, con la vasca che raccoglie ancora l'acqua come
##   nella v0.3.1): piscina vuota, si spara un po' d'acqua sul fondo e sul muro, si colpisce il
##   pulsante e il portellone si apre (punto 4);
## - sotto_scala: in fondo alla scala del pozzo, la canaletta di lamiera forata (punto 5);
## - cancello_10m, cancello_4m: arrivi al primo cancello stagno della camera delle onde, lo scatto
##   quando comincia ad alzarsi, con l'apertura a 10 m (v0.3.1) e a 4,5 m (punto 6).
## Uso, sotto il render.lock:
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --path godot --rendering-driver vulkan --fixed-fps 60 \
##        --resolution 1600x900 --script res://tests/run.gd -- res://tests/scatti_tappa8.gd \
##        <cartella> <prefisso> <scatti separati da virgole>
## Toglie gli interni e, degli ambienti tecnici, la camera delle onde e la sala pompe (resta il
## raccordo col magazzino): con tutto, sul renderer software, la memoria non basta.

const LEVEL := "res://scenes/sala_principale.tscn"

var out_dir := "user://scatti_tappa8"
var prefisso := "scatto"
var only := PackedStringArray()
var level: Node
var p: Player


func _ready() -> void:
	# Negli scatti la torre non si precarica (memoria: la sala da sola arriva a 12-13 GB).
	Engine.set_meta(&"precarica_torre_spento", true)
	var args := OS.get_cmdline_user_args()
	if args.size() > 1:
		out_dir = args[1]
	if args.size() > 2:
		prefisso = args[2]
	if args.size() > 3:
		only = args[3].split(",")
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset("alto")
	Grafica.imposta("antialiasing", 2)
	var wm := get_node_or_null(^"/root/WaterManager")
	if wm:
		wm.set(&"quality", 1)
	level = (load(LEVEL) as PackedScene).instantiate()
	# SCATTI_TOGLI: i nodi da togliere prima del primo frame (di serie gli interni e, degli ambienti
	# tecnici, tutto tranne il raccordo col magazzino; "Interni,Tecnici" per gli scatti nella sala).
	var togli := OS.get_environment("SCATTI_TOGLI").split(",", false)
	if togli.is_empty():
		togli = PackedStringArray(["Interni", "Tecnici/Ambienti/CameraOnde", "Tecnici/Ambienti/SalaPompe"])
	for percorso in togli:
		var n := level.get_node_or_null(NodePath(percorso))
		if n:
			n.get_parent().remove_child(n)
			n.free()
			print("tolto ", percorso)
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	await _frames(10)
	get_tree().paused = false
	p = GameState.player
	for i in 400:
		if p.input_enabled:
			break
		await get_tree().process_frame
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	for t in level.find_children("*", "Tempesta", true, false):
		(t as Tempesta).automatica = false
	p.stand_eye_height = 1.7
	# Prima del risveglio.
	if only.has("occhio_cordone"):
		await _occhio_cordone()
	if only.has("serranda_sala"):
		await _scatto("serranda_sala", Vector3(-15.0, 0.0, 15.6), Vector3(-15.0, 1.1, 20.3))
	# Tappe 5-6, prima del risveglio (la luce del portellone e i cancelli stagni sono di prima).
	for nome in ["portellone_spiaggia_spenta", "portellone_spiaggia", "portellone_getto_vecchio", "portellone_getto",
			"sotto_scala", "cancello_10m", "cancello_4m"]:
		if only.has(nome):
			await call(StringName("_" + nome))
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	await _frames(10)
	if only.has("serranda_magazzino"):
		await _scatto("serranda_magazzino", Vector3(-15.0, 0.0, 25.2), Vector3(-15.0, 1.1, 20.3))
	if only.has("serranda_si_alza"):
		await _serranda_si_alza()
	if OS.get_environment("SCATTI_BAVA_VECCHIA") == "1":
		# Com'era fino alla v0.3.2: il nastro seguiva solo i punti del percorso, senza appoggiarsi.
		for b in level.find_children("*", "BavaRosa", true, false):
			(b as BavaRosa).appoggia = false
			(b as BavaRosa).sollevamento = 0.008
			(b as BavaRosa).costruisci()
		await _frames(2)
	if only.has("scia_vasca"):
		await _scatto("scia_vasca", Vector3(-5.2, 0.0, 16.4), Vector3(-1.2, 0.2, 12.4))
	if only.has("scia_serranda"):
		await _scatto("scia_serranda", Vector3(-15.0, 0.0, 19.0), Vector3(-9.0, 0.2, 12.4))
	if only.has("scia_bimbi"):
		await _scatto("scia_bimbi", Vector3(-12.5, 0.0, 13.6), Vector3(-18.0, 0.0, 6.0))
	# Prova della v0.3.2 (punto 6): il resto del percorso, lungo il muro ovest fino alla fossa.
	if only.has("scia_centro"):
		await _scatto("scia_centro", Vector3(-7.0, 0.0, 15.0), Vector3(-10.0, 0.0, 12.5))
	if only.has("scia_muro_ovest"):
		await _scatto("scia_muro_ovest", Vector3(-16.6, 0.0, 9.5), Vector3(-18.3, 0.0, 1.5))
	if only.has("scia_fossa"):
		await _scatto("scia_fossa", Vector3(-17.2, 0.0, 0.5), Vector3(-15.0, 0.0, -6.0))
	var lei := level.get_node_or_null(^"Gioco/LeiSbuca") as LeiSbuca
	if lei and only.has("t8_arrivo"):
		# Un minuto dopo il risveglio: l'acqua delle vasche basse è salita piano (velocita_lenta).
		for v in lei.vasche:
			var t := v as WaterTank
			t.fill = minf(t.fill + lei.velocita_lenta * 60.0 / t.inner_size.y, t.max_fill)
		await _scatto("t8_arrivo", Vector3(-18.3, 0.0, -1.4), Vector3(-14.3, 0.7, -6.5))
	if lei and only.has("t8_scivola"):
		await _scivola(lei)
	if lei and only.has("t8_presa_lato"):
		await _presa_lato(lei)
	print("scatti salvati in ", ProjectSettings.globalize_path(out_dir))
	# Liberare il livello sul renderer software può restare appeso: gli scatti sono salvati.
	OS.kill(OS.get_process_id())


func _scatto(nome: String, piedi: Vector3, guarda: Vector3, attesa := 50) -> void:
	p.teleport(piedi, 0.0, 0.0)
	p.look_at_point(guarda)
	await _frames(attesa)
	p.look_at_point(guarda)
	await _frames(2)
	await _salva(nome)


func _salva(nome: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(out_dir.path_join("%s_%s.jpg" % [prefisso, nome]), 0.92)
	print("salvato ", prefisso, "_", nome)


## La luce del portellone vista dalla spiaggia, con la piscina piena (accesa e spenta).
func _portellone_spiaggia() -> void:
	await _scatto("portellone_spiaggia", Vector3(0.0, 0.0, -11.5), Vector3(0.0, -2.2, 2.0), 80)


func _portellone_spiaggia_spenta() -> void:
	var luce := level.get_node_or_null(^"Piscina/LucePortellone") as Node3D
	if luce:
		luce.visible = false
		luce.process_mode = Node.PROCESS_MODE_DISABLED
	await _scatto("portellone_spiaggia_spenta", Vector3(0.0, 0.0, -11.5), Vector3(0.0, -2.2, 2.0), 80)
	if luce:
		luce.visible = true
		luce.process_mode = Node.PROCESS_MODE_INHERIT


func _portellone_getto_vecchio() -> void:
	await _portellone_getto(true)


## Piscina vuota: dal fondo si spara un po' d'acqua sul muro sotto il pulsante (come mirandolo), poi
## lo si colpisce e il portellone si apre; lo scatto dal fondo verso il portellone aperto. Con
## [param vecchio] la vasca raccoglie ancora l'acqua sparata e la tiene, come nella v0.3.1 (lo scolo
## della piscina vuota è fermo).
func _portellone_getto(vecchio := false) -> void:
	var vasca := level.get_node(^"Piscina/Pozza") as WaterTank
	var svuota := level.get_node(^"Piscina/SvuotaPiscina")
	var pulsante := level.get_node(^"Piscina/PulsantePortello") as WaterButton
	var portello := level.get_node(^"Piscina/Portello")
	vasca.fill = 0.0
	for m in level.find_children("Medusine", "", true, false):
		m.call(&"ricomincia")
	# Subito sul fondo della piscina vuota: senza gli interni (SCATTI_TOGLI) il giocatore nasce nel
	# vuoto e, nei secondi d'attesa, cadrebbe sotto il livello (si muore e la scena si ricarica).
	p.teleport(Vector3(0.6, -1.95, 1.0), PI, 0.0)
	Engine.time_scale = 4.0
	await _frames(int(60 * 3.0 / 4.0) + 20)
	Engine.time_scale = 1.0
	if vecchio:
		svuota.set_physics_process(false)
		if not vasca.is_in_group(&"water_catchers"):
			vasca.add_to_group(&"water_catchers")
	if not p.has_item(&"zaino_pompa"):
		p.add_item(&"zaino_pompa", 1, "Zaino-pompa")
	p.water_pack.set_equipped(true, false)
	p.water_pack.set_tank_amount(20.0)
	p.teleport(Vector3(0.6, -1.95, 1.0), PI, 0.0)
	await _frames(10)
	p.look_at_point(Vector3(1.6, -1.9, 4.9))
	Input.action_press(&"spray")
	await _frames(60)
	p.look_at_point(pulsante.global_position + Vector3(0.0, 0.4, 0.0))
	await _frames(40)
	Input.action_release(&"spray")
	for i in 300:
		await get_tree().physics_frame
		if bool(portello.get(&"is_open")):
			break
	print("  portellone aperto: %s, acqua nella piscina %.4f" % [str(portello.get(&"is_open")), vasca.fill])
	p.water_pack.set_equipped(false, false)
	await _scatto("portellone_getto_vecchio" if vecchio else "portellone_getto", Vector3(2.6, -2.0, 4.4), Vector3(0.0, -2.3, 2.0), 60)
	if vecchio:
		# Di nuovo come prima del colpo: vuota, pulsante acceso e non premuto, portellone chiuso.
		vasca.remove_from_group(&"water_catchers")
		vasca.fill = 0.0
		svuota.set_physics_process(true)
		pulsante.call(&"load_state", {"powered": false})
		svuota.call(&"load_state", {"attivo": true})
		portello.set(&"is_open", false)
		portello.set(&"_t", 0.0)
		var lastra = portello.get(&"_target")
		if lastra:
			(lastra as Node3D).basis = portello.get(&"_base")


## In fondo alla scala del pozzo, guardando la canaletta di lamiera forata sotto la scala.
func _sotto_scala() -> void:
	var tec := level.get_node(^"Tecnici") as Node3D
	await _scatto("sotto_scala", tec.to_global(Vector3(2.6, 0.0, 0.9)), tec.to_global(Vector3(-0.2, 0.1, -0.2)), 60)


func _cancello_10m() -> void:
	await _cancello(10.0, "cancello_10m")


func _cancello_4m() -> void:
	await _cancello(4.5, "cancello_4m")


## Si cammina lungo la camera delle onde verso il primo cancello stagno (chiuso): lo scatto appena
## comincia ad alzarsi, con l'apertura a [param raggio] metri.
func _cancello(raggio: float, nome: String) -> void:
	var tec := level.get_node(^"Tecnici") as Node3D
	var cancelli := level.find_children("*", "Paratia", true, false)
	for c in cancelli:
		c.call(&"load_state", {"chiusa": false, "aperta": false})
		c.set(&"raggio_apertura", raggio)
	var meta := tec.to_global(Vector3(25.0, 1.3, 0.0))
	p.teleport(tec.to_global(Vector3(5.0, 0.0, 0.0)), 0.0, 0.0)
	await _frames(5)
	Input.action_press(&"move_forward")
	var partito := false
	for i in 1200:
		var d := meta - p.global_position
		p.set_look(atan2(-d.x, -d.z), 0.0)
		await get_tree().physics_frame
		for c in cancelli:
			if bool(c.get(&"in_salita")):
				partito = true
		if partito:
			break
	Input.action_release(&"move_forward")
	p.velocity = Vector3.ZERO
	# Il colpo e lo strappo: il pannello si stacca da terra circa mezzo secondo dopo.
	await _frames(70)
	await _salva(nome)


## Dal magazzino verso la serranda: entri nella zona davanti e si alza (a metà corsa e alla fine).
func _serranda_si_alza() -> void:
	var s := level.find_child("SerrandaMagazzino", true, false) as PoweredDoor
	p.teleport(Vector3(-15.0, 0.0, 25.2), 0.0, 0.0)
	p.look_at_point(Vector3(-15.0, 1.1, 20.3))
	await _frames(30)
	var lettore := level.get_node_or_null(^"Tecnici/Logica/LettoreTessera") as LettoreTessera
	if lettore:
		p.add_item(&"keycard", 1, "Keycard")
		lettore.interact(p)
	if s:
		s.call(&"apri")
	await _frames(70)
	await _salva("serranda_si_alza")
	await _frames(240)
	await _salva("serranda_aperta")


## Dal cordone, 40 gradi di lato, il getto in faccia alla medusa affacciata: lo scatto mentre l'occhio è chiuso.
func _occhio_cordone() -> void:
	var medusa := level.get_node(^"Vasca/Medusa") as MedusaAffacciata
	if not p.has_item(&"zaino_pompa"):
		p.add_item(&"zaino_pompa", 1, "Zaino-pompa")
	p.water_pack.set_equipped(true, false)
	p.water_pack.set_tank_amount(20.0)
	var lamp := level.get_node_or_null(^"Vasca/Sfarfallio")
	if lamp and lamp.has_method(&"turn_on"):
		lamp.call(&"turn_on")
	var occhio := medusa.get_eye_position()
	var d := medusa.global_basis.z
	d.y = 0.0
	d = d.normalized().rotated(Vector3.UP, deg_to_rad(-40.0))
	var da := Vector3(occhio.x, 1.0, occhio.z)
	var r := p.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(da, da + d * 12.0, Layers.BARRIERS))
	var piedi: Vector3 = (Vector3(r.position.x, 0.0, r.position.z) + d * 0.5) if not r.is_empty() else Vector3(-1.6, 0.0, 14.2)
	p.teleport(piedi, 0.0, 0.0)
	p.look_at_point(medusa.get_eye_position())
	await _frames(40)
	p.look_at_point(medusa.get_eye_position())
	Input.action_press(&"spray")
	await _frames(40)
	await _salva("occhio_cordone")
	Input.action_release(&"spray")
	p.water_pack.set_equipped(false, false)


## Lei affacciata che scivola sotto, vista da 3,5 m davanti e un po' di lato (tre scatti di fila).
func _scivola(lei: LeiSbuca) -> void:
	await _affacciata(lei)
	var testa: Vector3 = lei.punto_sbuca.global_transform * Vector3(0.0, 1.63, 1.8)
	var avanti := lei.punto_sbuca.global_basis.z
	var piedi := testa + avanti.rotated(Vector3.UP, deg_to_rad(25.0)) * 3.6
	piedi.y = 0.0
	p.teleport(piedi, 0.0, 0.0)
	p.look_at_point(testa + Vector3(0.0, -0.9, 0.0))
	await _frames(60)
	await _salva("t8_scivola_0")
	# Così lei non aspetta di essere vista e non ti prende: si fa scivolare subito.
	lei.distanza_presa = 0.0
	lei.call(&"_scivola")
	for k in 3:
		await _frames(21)
		await _salva("t8_scivola_%d" % (k + 1))
	lei.distanza_presa = 2.4


## Ti avvicini di lato (90 gradi da dove guarda) e ti prende: la camera della sequenza di morte.
func _presa_lato(lei: LeiSbuca) -> void:
	await _affacciata(lei)
	var testa: Vector3 = lei.punto_sbuca.global_transform * Vector3(0.0, 1.63, 1.8)
	var avanti := lei.punto_sbuca.global_basis.z
	var piedi := testa + avanti.rotated(Vector3.UP, deg_to_rad(-90.0)) * 2.6
	piedi.y = 0.0
	p.teleport(piedi, 0.0, 0.0)
	p.look_at_point(testa)
	await _frames(40)
	await _salva("t8_presa_lato_0")
	lei.call(&"_prendi")
	# La camera arriva sul viso in circa 0,9 s; il lampo rosso del morso è a 1 s.
	await _frames(40)
	await _salva("t8_presa_lato")


## Lei sul bordo della fossa, affacciata, con l'acqua alta: come la trova chi arriva.
func _affacciata(lei: LeiSbuca) -> void:
	for v in lei.vasche:
		var t := v as WaterTank
		t.fill = clampf((lei.livello_pieno - t.get_floor_global_y()) / t.inner_size.y, 0.0, t.max_fill)
	lei.medusa.visible = true
	lei.medusa.process_mode = Node.PROCESS_MODE_INHERIT
	lei.call(&"_metti_a", 0.0)
	lei.fase = LeiSbuca.Fase.GUARDA
	lei.vista_bene = false
	await _frames(5)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
