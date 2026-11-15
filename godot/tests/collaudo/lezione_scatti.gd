extends Node
## Collaudo 0.4.0, zona A: la lezione nella sala pompe col renderer vero. La sala ridotta (senza la sala grande e gli
## interni, coi tecnici), il giocatore vicino alla porta del ponte che guarda la leva (come quando la colpisce), le
## tre pompe e la leva da codice. Scatti da 5 camere: prima della lezione (blackout, la base) e ogni 0,6 s durante la
## lezione, finché la luce non si spegne. Con --fixed-fps 60 il tempo del gioco va a fotogrammi. LS:.
## Uso: xvfb-run ... --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/lezione_scatti.gd <cartella>

const LEVEL := "res://scenes/sala_principale.tscn"
const TOGLI := ["Interni", "Risalita", "Sala/AngoloPalloni", "Sala/AngoloScatoloni", "BambiniBalconata", "Mascotte",
		"Sala/Dettagli", "Sala/TorreScivoli", "Gioco/EnigmaAcquari", "Atmosfera", "SalaSottomarino", "SalaTorre",
		"Sala/Piscina", "Sala/VascaCentrale", "Piscina", "Vasca", "Sala/Architettura", "Sala/Cupola", "Sala/AreaBimbi",
		"Sala/Oggetti", "Polaroid", "Vasche", "Gioco/LeiSbuca", "Gioco/LeiSalaAlBuio"]
const CENTRO := Vector3(-0.9, -10.0, 37.86)
var CAMERE := {
	"occhi_porta": [Vector3(-1.4, -7.45, 44.0), CENTRO],
	"occhi_ingresso": [Vector3(0.0, -7.45, 31.8), CENTRO],
	"lato_est": [Vector3(2.4, -7.9, 37.86), Vector3(-1.8, -10.2, 37.86)],
	"capo_nord": [Vector3(-0.9, -8.0, 42.3), Vector3(-0.9, -10.6, 37.0)],
	"capo_sud": [Vector3(-0.9, -8.0, 33.4), Vector3(-0.9, -10.6, 38.7)],
}
var cart := ""
var cam: Camera3D


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _scatti(tag: String) -> void:
	for nome in CAMERE:
		var c: Array = CAMERE[nome]
		cam.global_position = c[0]
		cam.look_at(c[1], Vector3.UP)
		await _frames(2)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_jpg(cart.path_join("%s_%s.jpg" % [nome, tag]), 0.9)


func _luce() -> OmniLight3D:
	for n in get_tree().get_nodes_in_group(&"lei_nell_acqua"):
		return n.get(&"_luce") as OmniLight3D
	return null


var _ult_cond := ""


func _condizioni(acq: Node) -> String:
	if acq == null:
		return "-"
	var altrove := []
	var prop: Node = acq.get(&"_proprietaria")
	if prop and is_instance_valid(prop) and prop != acq:
		altrove.append("proprietaria " + str(prop.get_path()))
	for n in get_tree().get_nodes_in_group(AcquaDiLei.LEI_IN_SCENA):
		if n != acq.get(&"_lei") and n is Node3D and (n as Node3D).is_visible_in_tree():
			altrove.append("in scena " + str(n.get_path()))
	var p := GameState.player as Node3D
	for n in get_tree().get_nodes_in_group(MedusaAffacciata.GRUPPO_LEI):
		var l := n as Node3D
		if l and l != acq.get(&"_lei") and l.is_visible_in_tree():
			altrove.append("affacciata visibile %s a %.1f m" % [l.get_path(), (l.global_position + Vector3.UP * 1.5).distance_to(p.global_position)])
	var cam := get_viewport().get_camera_3d()
	var lista: Array = get_tree().get_nodes_in_group(&"bambini")
	for n in get_tree().get_nodes_in_group(&"persist"):
		if n is BambinoSfuggita:
			lista.append(n)
	for n in lista:
		var b := n as Node3D
		if b and b.is_visible_in_tree() and cam and cam.is_position_in_frustum(b.global_position + Vector3.UP * 0.8):
			altrove.append("bambino in vista %s in %s a %.1f m" % [b.get_path(), b.global_position.snappedf(0.1), b.global_position.distance_to(cam.global_position)])
	return "luci %s, morendo %s, zona %s, puo %s, altrove %s, in vista %s, bambino %s %s" % [GameState.luci, GameState.is_dying,
			acq.call(&"giocatore_nella_zona"), acq.call(&"puo_venire"), acq.call(&"lei_altrove"), acq.call(&"lei_in_vista_altrove"),
			acq.call(&"bambino_in_vista"), altrove]


func _run() -> void:
	cart = OS.get_cmdline_user_args()[1]
	DirAccess.make_dir_recursive_absolute(cart)
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset(OS.get_environment("PRESET") if OS.get_environment("PRESET") != "" else "medio")
	get_tree().change_scene_to_file(load("res://tests/scena_ridotta.gd").riduci(LEVEL, TOGLI))
	for i in 600:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and get_tree().current_scene:
			break
	await _frames(60)
	var level := get_tree().current_scene
	var risv := level.get_node(^"Tecnici/Logica/SalaPompe/Risveglio")
	var leva: Node3D = risv.get(&"leva")
	var p := GameState.player as Player
	p.teleport(Vector3(-1.4, -9.05, 44.0))
	var d := leva.global_position - (p.global_position + Vector3.UP * 1.6)
	p.set_look(atan2(-d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()))
	cam = Camera3D.new()
	cam.fov = 75.0
	cam.near = 0.05
	add_child(cam)
	await _frames(30)
	print("LS: giocatore %s, vasca pelo %.3f" % [p.global_position.snappedf(0.01), (risv.get(&"vasca") as WaterTank).get_surface_global_y()])
	await _scatti("00_prima_delle_pompe")
	for i in 3:
		risv.call(&"_turbina_accesa", i)
		await _frames(20)
	leva.call(&"tira")
	# la camera del giocatore resta quella corrente fino agli scatti (bambino_in_vista guarda la camera corrente)
	var f0 := Engine.get_process_frames()
	while Engine.get_process_frames() - f0 < 240:
		await get_tree().process_frame
	cam.make_current()
	await _scatti("01_blackout_base")
	p.get_viewport().get_camera_3d()
	var visto := false
	var k := 2
	var t_lez := -1
	while Engine.get_process_frames() - f0 < 60 * 16:
		await get_tree().process_frame
		var cnd := _condizioni(risv.get(&"acqua_lezione"))
		if cnd != _ult_cond:
			_ult_cond = cnd
			print("LS: %.2f s condizioni: %s" % [(Engine.get_process_frames() - f0) / 60.0, cnd])
		var l := _luce()
		var accesa := l != null and l.is_visible_in_tree() and l.light_energy > 0.01
		if accesa and t_lez < 0:
			t_lez = Engine.get_process_frames()
			print("LS: la luce si accende a %.2f s dalla leva" % ((t_lez - f0) / 60.0))
		if accesa:
			visto = true
			if (Engine.get_process_frames() - t_lez) % 36 == 0:
				print("LS: scatto %02d: luce in %s energia %.2f" % [k, l.global_position.snappedf(0.01), l.light_energy])
				await _scatti("%02d_luce" % k)
				k += 1
		elif visto:
			await _scatti("%02d_spenta" % k)
			break
	print("LS: luce vista %s, scatti %d" % [visto, k])
	print("LS: finito")
	get_tree().quit()
