extends Node
## Ricontrollo del tunnel dell'inseguimento per la 0.3.17 (lavoro/nebbia-0317): buio, ma la strada si legge (banchine,
## gommoni, gallerie basse), e la luce rosa si nota quando lei si avvicina. Come misura_tunnel_0317.gd: il giocatore vero
## sulla banchina sinistra e lei che insegue. Due modi:
## - "0317": com'è;
## - "0316": come la 0.3.16 (lo shader della nebbia di 446069c3 dato col percorso, 20 passi, aria e alone pieni nel
##   tunnel, la luce rosa da lontano a 0,55).
## Punti: la banchina, i gommoni (dove il crollo chiude la banchina), la bocca della galleria bassa e dentro (accucciati),
## e lei che si avvicina a 15, 10, 7, 5 e 3 m. Stampa "MISURA" con la luminosità e quanto è rosa lo schermo.
## Uso: xvfb-run -a -s "-screen 0 960x540x24" godot --path godot --rendering-driver vulkan --resolution 960x540 \
##        --script res://tests/run.gd -- res://tests/collaudo/collaudo_tunnel_0317.gd <cartella> <0317|0316> [shader 0.3.16]

const PLAYER := "res://scenes/player/player.tscn"
## [nome, s del giocatore, quanto dietro è lei, s guardato, lato guardato (u; 0 la banchina), altezza guardata, accucciato]
const PUNTI := [
	["banchina", 100.0, 15.0, 110.0, 0.0, 1.2, false],
	["gommoni", 64.0, 15.0, 76.0, -99.0, -0.3, false],
	["galleria_bocca", 196.5, 15.0, 203.6, 99.0, 0.6, false],
	["galleria_dentro", 209.0, 15.0, 216.5, 98.0, 0.6, true],
	["avvicina_15", 140.0, 15.0, 150.0, 0.0, 1.2, false],
	["avvicina_10", 140.0, 10.0, 150.0, 0.0, 1.2, false],
	["avvicina_7", 140.0, 7.0, 150.0, 0.0, 1.2, false],
	["avvicina_5", 140.0, 5.0, 150.0, 0.0, 1.2, false],
	["avvicina_3", 140.0, 3.0, 150.0, 0.0, 1.2, false],
]

var sala: SalaSottomarino
var p: Player


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var cartella := a[1]
	var modo: String = a[2]
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
	var effetti: Node = sala.get(&"effetti")
	var n: NebbiaViola = Grafica.nebbia_viola
	if modo == "0316":
		var z := sala.find_child("NebbiaViola", false, false)
		z.set(&"aria", 1.0)
		z.set(&"alone", 1.0)
		effetti.set(&"luce_lontana", 0.55)
		var sh := Shader.new()
		sh.code = FileAccess.get_file_as_string(a[3])
		var mat := n.get(&"_mat") as ShaderMaterial
		mat.shader = sh
		mat.set_shader_parameter(&"passi", 20)
	p.set_physics_process(false)
	sala.attiva_tunnel()
	var z2 := sala.find_child("NebbiaViola", false, false)
	if z2:
		n.zona(z2, true, true)
		n.call(&"_valori_zona", z2)
	if modo == "0316":
		(n.get(&"_mat") as ShaderMaterial).set_shader_parameter(&"passi", 20)
	for c in PUNTI:
		var s: float = c[1]
		p.teleport(_banchina(s), 0.0, 0.0)
		var occhi := 0.92 if c[6] else 1.6
		if c[6]:
			p.teleport(_dentro_galleria(s), 0.0, 0.0)
		p.set(&"_eye_height", occhi)
		p.set(&"_eye_prev", occhi)
		sala.set(&"_s_bersaglio", s)
		sala.insegui_da(s - float(c[2]))
		var guarda := _punto(float(c[3]), float(c[4]), float(c[5]))
		for i in 40:
			sala.set(&"_s_bersaglio", s)
			p.look_at_point(guarda)
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_jpg(cartella.path_join("%s_%s.jpg" % [c[0], modo]), 0.9)
		var gap: float = float(sala.get(&"_s_bersaglio")) - float(sala.get(&"lei_s"))
		var tutto := Rect2i(Vector2i.ZERO, img.get_size())
		print("MISURA %s %s: luminosità media %.1f, mediana %.1f, 10° percentile %.1f; rosa (R-G medio) %.1f (lei a %.1f m; luce rosa %s)" % [
				c[0], modo, _lum(img, tutto), _percentile(img, 0.5), _percentile(img, 0.1), _rosa(img), gap,
				"%.1f" % float(effetti.get(&"luce").light_energy) if effetti and effetti.get(&"luce").visible else "spenta"])
	get_tree().quit()


func _banchina(s: float) -> Vector3:
	var q := sala.punto(s) - sala.destra(s) * (sala.canale + sala.banchina * 0.5)
	return Vector3(q.x, sala.piano + 0.05, q.z)


## Il centro della galleria bassa di sinistra, alla [param s].
func _dentro_galleria(s: float) -> Vector3:
	var u := sala.muro + sala.spessore + SalaSottomarino.GALLERIA_LARGA * 0.5
	var q := sala._al(sala.punto(s), sala.destra(s) * -1.0, Vector2(u, sala.piano))
	return q + Vector3.UP * 0.05


## Il punto guardato: [param u] 0 la banchina sinistra, -99 il canale, 99 il muro sinistro (la bocca), 98 la galleria.
func _punto(s: float, u: float, h: float) -> Vector3:
	if u == -99.0:
		var c := sala.punto(s)
		return Vector3(c.x, sala.piano + h, c.z)
	if u == 99.0:
		return sala._al(sala.punto(s), sala.destra(s) * -1.0, Vector2(sala.muro, sala.piano + h))
	if u == 98.0:
		return _dentro_galleria(s) + Vector3.UP * h
	return _banchina(s) + Vector3.UP * h


static func _lum(img: Image, r: Rect2i) -> float:
	var s := 0.0
	var k := 0
	for y in range(r.position.y, r.end.y, 4):
		for x in range(r.position.x, r.end.x, 4):
			var c := img.get_pixel(x, y)
			s += 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			k += 1
	return s / maxf(k, 1) * 255.0


static func _percentile(img: Image, q: float) -> float:
	var v := PackedFloat32Array()
	for y in range(0, img.get_height(), 4):
		for x in range(0, img.get_width(), 4):
			var c := img.get_pixel(x, y)
			v.append(0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b)
	v.sort()
	return v[int(q * (v.size() - 1))] * 255.0


static func _rosa(img: Image) -> float:
	var s := 0.0
	var k := 0
	for y in range(0, img.get_height(), 4):
		for x in range(0, img.get_width(), 4):
			var c := img.get_pixel(x, y)
			s += c.r - c.g
			k += 1
	return s / maxf(k, 1) * 255.0
