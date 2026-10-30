extends Node
## Collaudo della nebbia 0.3.17 nel tunnel dell'inseguimento (riscontro dell'utente sulla 0.3.16, "troppo luminoso ora"):
## dagli occhi del giocatore lungo la strada, con lei che insegue lontana, se la strada si legge al buio (banchine,
## gommoni degli attraversamenti, bocche delle gallerie basse, ostacoli); poi lei che si avvicina (15, 10, 6, 3 m) per
## vedere se la luce rosa si nota. Tunnel costruito come in misura_tunnel_0317.gd, preset alto.
## Uso (sotto il render.lock, tools/scatto_sicuro.sh): res://tests/collaudo/giro_tunnel_0317.gd <cartella> [nome]

const PLAYER := "res://scenes/player/player.tscn"
## [nome, s del giocatore, lato (-1 sinistra), s guardato, lato guardato, quota guardata, lei dietro (m)]
const STRADA := [
	["01_partenza", 20.0, -1.0, 32.0, -1.0, 0.8, 15.0],
	["02_gommoni_74", 66.0, -1.0, 74.0, 0.0, 0.2, 15.0],
	["03_gommoni_138", 129.0, 1.0, 138.0, 0.0, 0.2, 15.0],
	["04_galleria_205", 197.0, -1.0, 206.0, -1.0, 0.8, 15.0],
	["05_cancello_268", 259.0, -1.0, 268.0, 0.0, 0.2, 15.0],
	["06_macerie_348", 339.0, 1.0, 348.0, 0.0, 0.2, 15.0],
	["07_galleria_425", 417.0, -1.0, 426.0, -1.0, 0.8, 15.0],
	["08_vetrina_484", 475.0, -1.0, 484.0, 0.0, 0.2, 15.0],
]
## Lei che si avvicina: la distanza dietro il giocatore (s 300, banchina sinistra), guardando avanti.
const AVVICINA := [15.0, 10.0, 6.0, 3.0]

var sala: SalaSottomarino
var p: Player
var effetti: Node


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var cartella := a[1]
	var nome: String = a[2] if a.size() > 2 else "0317"
	DirAccess.make_dir_recursive_absolute(cartella)
	seed(30102026)
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset("alto")
	var env := WorldEnvironment.new()
	env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
	add_child(env)
	p = (load(PLAYER) as PackedScene).instantiate()
	add_child(p)
	GameState.player = p
	p.teleport(Vector3(0, 50, 0), 0.0, 1.2)
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	sala = SalaSottomarino.new()
	sala.name = "SalaSottomarino"
	add_child(sala)
	await sala.costruisci_a_pezzi()
	for i in 60:
		await get_tree().process_frame
	effetti = sala.get(&"effetti")
	p.set_physics_process(false)
	sala.attiva_tunnel()
	# [param solo_lei] (terzo argomento "lei"): solo lei che si avvicina, nel tratto dritto da s 100
	var solo_lei := a.size() > 3 and a[3] == "lei"
	if not solo_lei:
		for c in STRADA:
			var s: float = c[1]
			var mira := _lato(float(c[3]), float(c[4])) + Vector3.UP * float(c[5])
			await _scatta(cartella, "%s_%s" % [c[0], nome], _lato(s, float(c[2])), s, float(c[6]), mira)
	var s_lei := 100.0
	for d in AVVICINA:
		await _scatta(cartella, "10_lei_a_%02dm_avanti_%s" % [int(d), nome], _lato(s_lei, -1.0), s_lei, d,
				_lato(s_lei + 10.0, -1.0) + Vector3.UP * 1.2)
	for d in AVVICINA:
		await _scatta(cartella, "11_lei_a_%02dm_dietro_%s" % [int(d), nome], _lato(s_lei, -1.0), s_lei, d, Vector3.INF)
	get_tree().quit()


func _scatta(cartella: String, nome: String, piedi: Vector3, s: float, dietro: float, mira: Vector3) -> void:
	p.teleport(piedi, 0.0, 0.0)
	sala.set(&"_s_bersaglio", s)
	sala.insegui_da(s - dietro)
	for i in 50:
		sala.set(&"_s_bersaglio", s)
		# (Vector3.INF: si guarda lei)
		p.look_at_point(mira if mira != Vector3.INF else (sala.lei.get_eye_position() if sala.lei else _lato(s - dietro, -1.0) + Vector3.UP * 1.6))
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_jpg(cartella.path_join(nome + ".jpg"), 0.9)
	var gap: float = float(sala.get(&"_s_bersaglio")) - float(sala.get(&"lei_s"))
	var luce: Node = effetti.get(&"luce") if effetti else null
	print("GIRO %s: media %.1f, 10%% %.1f, rosa (R-G) %.1f (lei a %.1f m; luce rosa %s)" % [nome, _lum(img), _perc(img, 0.1), _rosa(img), gap,
			"%.1f" % float(luce.light_energy) if luce and luce.visible else "-"])


## Il punto in mezzo alla banchina del [param lato] (-1 sinistra, 1 destra) o sull'asse del canale (0).
func _lato(s: float, lato: float) -> Vector3:
	var q := sala.punto(s)
	if lato != 0.0:
		q += sala.destra(s) * lato * (sala.canale + sala.banchina * 0.5)
	return Vector3(q.x, sala.piano + 0.05 if lato != 0.0 else sala.piano - 0.3, q.z)


static func _lum(img: Image) -> float:
	var s := 0.0
	var k := 0
	for y in range(0, img.get_height(), 4):
		for x in range(0, img.get_width(), 4):
			var c := img.get_pixel(x, y)
			s += 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			k += 1
	return s / maxf(k, 1) * 255.0


## Quanto è rosa lo schermo: la media di rosso meno verde (0..255).
static func _rosa(img: Image) -> float:
	var s := 0.0
	var k := 0
	for y in range(0, img.get_height(), 4):
		for x in range(0, img.get_width(), 4):
			var c := img.get_pixel(x, y)
			s += maxf(c.r - c.g, 0.0)
			k += 1
	return s / maxf(k, 1) * 255.0


static func _perc(img: Image, f: float) -> float:
	var v := PackedFloat32Array()
	for y in range(0, img.get_height(), 6):
		for x in range(0, img.get_width(), 6):
			var c := img.get_pixel(x, y)
			v.append(0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b)
	v.sort()
	return v[int(v.size() * f)] * 255.0
