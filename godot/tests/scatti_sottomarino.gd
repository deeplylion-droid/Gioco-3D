extends Node
## Scatti interni del tunnel del viaggio sottomarino (SalaSottomarino), dagli occhi del giocatore lungo la strada:
## per il collaudo e per i controlli della squadra (non per l'utente, che lo giudica giocando).
##
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##        --script res://tests/run.gd -- res://tests/scatti_sottomarino.gd <cartella> [scatti separati da virgole]
## Ogni scatto: [s lungo la strada, lato (-1 banchina sinistra, 1 destra, 0 asse), quota degli occhi sopra il piano,
## s guardato, lato guardato, quota guardata sopra il piano, campo visivo].

var SCATTI := {
	"01_dalla_porta": [2.0, -1.0, 1.6, -3.0, 0.0, 0.0, 75.0],
	"02_partenza": [4.0, -1.0, 1.6, 20.0, -0.3, 1.0, 75.0],
	"03_rettilineo": [30.0, -1.0, 1.6, 50.0, -0.2, 1.4, 75.0],
	"04_indietro": [40.0, 1.0, 1.6, 20.0, 0.0, 2.5, 75.0],
	"05_canale_dal_basso": [60.0, 0.0, 0.9, 75.0, 0.0, 1.0, 75.0],
	"06_curva_u": [125.0, 1.0, 1.6, 145.0, 0.0, 1.5, 75.0],
	"07_gradini": [21.0, 1.0, 1.6, 23.0, 0.6, -0.6, 75.0],
	"08_volta": [200.0, 0.0, 1.6, 206.0, 0.0, 7.0, 80.0],
	"09_fine": [540.0, -1.0, 1.6, 552.0, 0.0, 1.5, 75.0],
	"10_crollo_e_gommoni": [60.0, -1.0, 1.6, 72.0, -0.3, 0.0, 75.0],
	"11_gommoni_vicino": [65.0, -1.0, 1.6, 67.5, -0.3, -0.4, 70.0],
	"12_carico": [128.0, 1.0, 1.6, 139.5, 1.0, 0.8, 70.0],
	"13_galleria_bocca": [199.0, -1.0, 1.6, 203.8, -1.0, 0.6, 70.0],
	"14_galleria_dentro": [206.0, -1.0, 0.9, 214.0, -1.0, 0.5, 80.0],
	"15_cancello": [262.0, -1.0, 1.6, 268.0, -1.0, 1.0, 70.0],
	"16_macerie": [340.0, 1.0, 1.6, 349.5, 1.0, 0.9, 70.0],
	"16b_macerie_lontano": [330.0, 1.0, 1.6, 349.0, 1.0, 1.0, 60.0],
	"16c_macerie_vicino": [345.5, 0.9, 1.7, 348.5, 1.1, 0.9, 65.0],
	"17_vetrina": [476.0, -1.0, 1.6, 484.5, -1.0, 0.8, 70.0],
	"18_lei_dietro": [52.0, -1.0, 1.6, 40.0, 0.0, 2.8, 70.0],
	"19_lei_di_lato": [40.0, 1.0, 1.6, 40.0, 0.0, 2.8, 80.0],
	"20_approdo": [538.0, -1.0, 1.6, 552.3, -0.1, 3.4, 75.0],
	"21_ballatoio": [550.8, -0.9, 4.6, 552.3, 0.0, 4.0, 75.0],
	"22_camera_volantino": [554.6, 0.0, 4.6, 552.3, 0.1, 3.7, 75.0],
	"23_coralli": [74.0, 1.0, 1.6, 81.0, 1.0, 2.8, 70.0],
	"24_coralli_sinistra": [84.0, -1.0, 1.6, 90.0, -1.0, 2.8, 70.0],
	"25_ancora": [115.5, -1.0, 1.6, 121.6, -1.0, 3.1, 70.0],
	"26_ancora_staffa": [120.6, -0.95, 2.7, 121.6, -1.15, 2.9, 50.0],
	"27_salvagente": [135.5, -1.0, 1.6, 140.6, -1.0, 2.8, 70.0],
	"28_salvagente_vicino": [139.6, -0.95, 2.6, 140.6, -1.15, 2.7, 50.0],
	"29_forziere": [142.5, -1.0, 1.6, 147.0, -1.0, 2.5, 70.0],
	"30_palombaro": [184.0, 1.0, 1.6, 190.0, 1.0, 2.9, 70.0],
	"41_crollo_74": [70.0, -1.0, 1.6, 78.0, -0.9, -0.6, 70.0],
	"42_crollo_galleria": [199.0, 1.0, 1.6, 205.5, 0.9, -0.6, 70.0],
	"43_fascia_bocca": [202.0, -1.0, 1.4, 204.3, -1.15, 1.4, 60.0],
	"44_carico": [134.0, 1.0, 1.6, 139.8, 1.0, 0.9, 70.0],
	"48_carico_s136": [136.0, 1.0, 1.6, 141.0, 1.0, 0.9, 70.0],
	"49_carico_retro": [143.0, 1.0, 1.6, 138.0, 1.0, 0.9, 70.0],
	"50_carico_dal_canale": [136.0, 0.3, 1.6, 139.5, 1.1, 0.9, 70.0],
	"45_testa_dalla_porta": [2.0, -1.0, 1.6, -2.0, 0.0, 0.3, 75.0],
	"46_staffe_ancora": [120.4, -0.95, 2.9, 121.6, -1.15, 3.0, 50.0],
	"47_forziere_vicino": [144.8, -0.9, 2.3, 147.0, -1.15, 2.4, 55.0],
	"33_corallo_mensola": [78.2, 0.95, 2.4, 79.2, 1.15, 2.3, 50.0],
	"31_portello_cerniere": [551.4, 0.05, 4.4, 552.6, -0.2, 3.5, 55.0],
	"32_portello_oblo": [551.3, -0.1, 4.3, 552.3, 0.0, 4.3, 50.0],
}
## Dove sta lei negli scatti che la mostrano (s lungo la strada).
var LEI := {"18_lei_dietro": 40.0, "19_lei_di_lato": 40.0}

var cartella := "user://scatti_sottomarino"
var solo := PackedStringArray()


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 1:
		cartella = a[1]
	if a.size() > 2:
		solo = a[2].split(",", false)
	DirAccess.make_dir_recursive_absolute(cartella)
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	env.environment.sdfgi_enabled = true
	env.environment.sdfgi_cascades = 3
	env.environment.volumetric_fog_density = 0.009
	env.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
	add_child(env)
	var sala := SalaSottomarino.new()
	sala.name = "SalaSottomarino"
	add_child(sala)
	sala.costruisci()
	if OS.get_environment("SCATTI_DEBUG") != "":
		# debug: materiale chiaro senza ombre, con o senza le facce dal retro (SCATTI_DEBUG=retro le mostra rosse)
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.8, 0.8, 0.8)
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var mr := StandardMaterial3D.new()
		mr.albedo_color = Color(0.9, 0.1, 0.1)
		mr.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mr.cull_mode = BaseMaterial3D.CULL_FRONT
		m.next_pass = mr if OS.get_environment("SCATTI_DEBUG") == "retro" else null
		var m2 := m.duplicate() as StandardMaterial3D
		m2.next_pass = null
		m2.cull_mode = BaseMaterial3D.CULL_DISABLED
		for mi in sala.find_children("*", "MeshInstance3D", true, false):
			# (con "retro" su tutte le mesh, anche i modelli coi materiali loro: si vedono le facce rovesciate ovunque)
			if (mi as MeshInstance3D).material_override or OS.get_environment("SCATTI_DEBUG") == "retro":
				# (le mesh disegnate dalle due parti apposta non hanno un retro da mostrare)
				(mi as MeshInstance3D).material_override = m if not mi.has_meta(&"doppia_faccia") else m2
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	for i in 30:
		await get_tree().process_frame
	if solo.has("40_oblo_abisso"):
		await _oblo_abisso(sala, cam)
		get_tree().quit()
		return
	if solo.has("34_schianto"):
		await _schianto(sala, cam)
		get_tree().quit()
		return
	for nome in SCATTI:
		if not solo.is_empty() and not solo.has(nome):
			continue
		var s: Array = SCATTI[nome]
		cam.fov = s[6]
		cam.look_at_from_position(_occhio(sala, s[0], s[1], s[2]), _occhio(sala, s[3], s[4], s[5]))
		if sala.lei:
			sala.lei.visible = LEI.has(nome)
			if LEI.has(nome):
				var occhi := Node3D.new()
				add_child(occhi)
				occhi.global_position = cam.global_position
				sala.bersaglio = occhi
				sala.insegui_da(float(LEI[nome]))
				sala.velocita_lei = 0.0
				sala.velocita_rincorsa = 0.0
		for i in int(OS.get_environment("SCATTI_FOTOGRAMMI")) if OS.get_environment("SCATTI_FOTOGRAMMI") != "" else 40:
			await get_tree().process_frame
		var f := cartella.path_join(nome + ".jpg")
		get_viewport().get_texture().get_image().save_jpg(f, 0.88)
		print("scatto -> ", f)
	get_tree().quit()


## Un punto a [param s] lungo la strada, di lato (in banchine: -1 la sinistra, 1 la destra, frazioni del canale
## fra -1 e 1 se [param lato] è minore di 1 in valore), a [param su] sopra il piano delle banchine.
func _occhio(sala: SalaSottomarino, s: float, lato: float, su: float) -> Vector3:
	var di_lato := lato * sala.canale if absf(lato) < 0.99 else signf(lato) * (sala.canale + sala.banchina * 0.5)
	return sala.punto(s) + sala.destra(s) * di_lato + Vector3.UP * (sala.piano - sala.acqua + su)


## Lo schianto: si chiude il portello e lei sbatte sull'oblò; due scatti prima del nero: dalla camera stagna, dalla
## soglia guardando l'oblò (come il giocatore), e dal pontile.
func _schianto(sala: SalaSottomarino, cam: Camera3D) -> void:
	var L := sala.lunghezza()
	var p := sala.punto(L)
	var d := sala.direzione(L)
	var r := sala.destra(L)
	var sg := sala.piano + SalaSottomarino.SOGLIA
	var oblo := Vector3(p.x, sg + SalaSottomarino.OBLO_Y, p.z)
	cam.fov = 70.0
	cam.look_at_from_position(oblo + d * 0.9 + Vector3.UP * 0.3, oblo)
	var contro := [false]
	sala.lei_tunnel.schianto_contro.connect(func(): contro[0] = true)
	sala.chiudi_portello()
	for i in 2000:
		if contro[0]:
			break
		await get_tree().process_frame
	for i in 8:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_jpg(cartella.path_join("34_schianto_dalla_camera.jpg"), 0.88)
	cam.look_at_from_position(oblo - d * 1.6 - r * 2.2 + Vector3.UP * 0.2, oblo - d * 0.4)
	for i in 3:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_jpg(cartella.path_join("35_schianto_dal_pontile.jpg"), 0.88)
	print("scatti dello schianto in ", cartella)


## Gli oblò grandi dell'abisso (di ambienti-1) visti dalla banchina, con gli occhi a 1,6 m: per ognuno uno scatto
## dalla banchina dall'altra parte del canale e uno da 6 m prima sulla stessa banchina.
func _oblo_abisso(sala: SalaSottomarino, cam: Camera3D) -> void:
	cam.fov = 70.0
	var k := 0
	for n in sala.find_children("oblo_grande_*", "", true, false):
		var o := (n as Node3D).global_position
		var pr := sala.proietta_vicino(o, 430.0, 80.0)
		var s := float(pr[0])
		var lato := signf(float(pr[1]))
		for vista in [[s, -lato], [s - 6.0, lato]]:
			cam.look_at_from_position(_occhio(sala, float(vista[0]), float(vista[1]), 1.6), o)
			for i in 60:
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_jpg(cartella.path_join("40_oblo_abisso_%d.jpg" % k), 0.88)
			k += 1
	print("scatti degli oblò dell'abisso: ", k)
