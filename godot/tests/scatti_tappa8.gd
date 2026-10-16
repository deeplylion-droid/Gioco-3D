extends Node
## Scatti di controllo della prova della v0.3.1 (riscontri 1, 11, 13 e 14), dal motore, prima e dopo:
## - serranda_sala, serranda_magazzino: la serranda del magazzino dalla sala (prima del risveglio) e
##   dal magazzino (al buio); serranda_si_alza, serranda_aperta: ci arrivi dal magazzino e si alza;
## - scia_vasca, scia_serranda, scia_bimbi: la scia di bava dalla vasca centrale, vista uscendo dalla
##   serranda e dove gira lungo il muro ovest verso l'area bimbi (al buio);
## - t8_arrivo: arrivi all'area bimbi seguendo la scia, un minuto dopo il risveglio;
## - t8_presa_lato: ti avvicini di lato e lei ti prende (la camera della sequenza di morte);
## - t8_scivola: lei scivola sotto (tre scatti di fila);
## - occhio_cordone: dal cordone, di lato, il getto in faccia alla medusa affacciata.
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
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	await _frames(10)
	if only.has("serranda_magazzino"):
		await _scatto("serranda_magazzino", Vector3(-15.0, 0.0, 25.2), Vector3(-15.0, 1.1, 20.3))
	if only.has("serranda_si_alza"):
		await _serranda_si_alza()
	if only.has("scia_vasca"):
		await _scatto("scia_vasca", Vector3(-5.2, 0.0, 16.4), Vector3(-1.2, 0.2, 12.4))
	if only.has("scia_serranda"):
		await _scatto("scia_serranda", Vector3(-15.0, 0.0, 19.0), Vector3(-9.0, 0.2, 12.4))
	if only.has("scia_bimbi"):
		await _scatto("scia_bimbi", Vector3(-12.5, 0.0, 13.6), Vector3(-18.0, 0.0, 6.0))
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
	get_tree().quit()


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


## Dal magazzino verso la serranda: entri nella zona davanti e si alza (a metà corsa e alla fine).
func _serranda_si_alza() -> void:
	var s := level.find_child("SerrandaMagazzino", true, false) as PoweredDoor
	p.teleport(Vector3(-15.0, 0.0, 25.2), 0.0, 0.0)
	p.look_at_point(Vector3(-15.0, 1.1, 20.3))
	await _frames(30)
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
