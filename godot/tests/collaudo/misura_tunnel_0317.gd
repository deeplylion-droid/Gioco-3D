extends Node
## Misura della luce nel tunnel dell'inseguimento (riscontro dell'utente sulla 0.3.16: "troppo luminoso ora"), col
## renderer vero e il giocatore vero sulla banchina sinistra, lei che insegue lontana (15 m) e vicina (5 m): lo scatto
## guardando avanti e, vicina, guardando lei. Stampa la luminosità media dello schermo ("MISURA").
## Funziona anche sulla 0.3.15 (senza effetti dell'inseguimento e senza nebbia viola): si copia lì e si lancia uguale.
## Modi: "completa" (com'è), "senza_nebbia" (nebbia viola spenta), "senza_effetti" (EffettiInseguimento spento).
## Uso (sotto il render.lock, tools/scatto_sicuro.sh): res://tests/collaudo/misura_tunnel_0317.gd <cartella> <modo> [nome]

const PLAYER := "res://scenes/player/player.tscn"
## [nome, s del giocatore, quanto dietro è lei, guarda lei]
const CASI := [
	["lontana", 100.0, 15.0, false],
	["vicina", 140.0, 5.0, false],
	["vicina_guardala", 140.0, 5.0, true],
]

var sala: SalaSottomarino
var p: Player


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var cartella := a[1]
	var modo: String = a[2] if a.size() > 2 else "completa"
	var nome: String = a[3] if a.size() > 3 else modo
	DirAccess.make_dir_recursive_absolute(cartella)
	seed(30102026)
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset("alto")
	if modo == "senza_nebbia" and "nebbia_viola" in Grafica.valori:
		Grafica.imposta("nebbia_viola", false)
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
	if modo == "senza_effetti" and effetti:
		effetti.process_mode = Node.PROCESS_MODE_DISABLED
		effetti.get(&"luce").visible = false
		effetti.get(&"bordi").visible = false
	p.set_physics_process(false)
	sala.attiva_tunnel()
	for c in CASI:
		var s: float = c[1]
		p.teleport(_banchina(s), 0.0, 0.0)
		sala.set(&"_s_bersaglio", s)
		sala.insegui_da(s - float(c[2]))
		for i in 40:
			sala.set(&"_s_bersaglio", s)
			if c[3]:
				p.look_at_point(sala.lei.get_eye_position() if sala.lei else _banchina(s - 5.0) + Vector3.UP * 1.6)
			else:
				p.look_at_point(_banchina(s + 8.0) + Vector3.UP * 1.5)
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_jpg(cartella.path_join("%s_%s.jpg" % [c[0], nome]), 0.9)
		var gap: float = float(sala.get(&"_s_bersaglio")) - float(sala.get(&"lei_s"))
		var nv: Variant = Grafica.get(&"nebbia_viola")
		print("MISURA %s %s: luminosità media %.1f, metà alta %.1f, metà bassa %.1f (lei a %.1f m; nebbia %s; luce rosa %s)" % [
				c[0], nome, _lum(img, Rect2i(Vector2i.ZERO, img.get_size())),
				_lum(img, Rect2i(0, 0, img.get_width(), img.get_height() / 2)),
				_lum(img, Rect2i(0, img.get_height() / 2, img.get_width(), img.get_height() / 2)), gap,
				"%.2f" % float(nv.get(&"quanto")) if nv else "-",
				"%.1f" % float(effetti.get(&"luce").light_energy) if effetti and effetti.get(&"luce").visible else "-"])
	get_tree().quit()


func _banchina(s: float) -> Vector3:
	var q := sala.punto(s) - sala.destra(s) * (sala.canale + sala.banchina * 0.5)
	return Vector3(q.x, sala.piano + 0.05, q.z)


static func _lum(img: Image, r: Rect2i) -> float:
	var s := 0.0
	var k := 0
	for y in range(r.position.y, r.end.y, 4):
		for x in range(r.position.x, r.end.x, 4):
			var c := img.get_pixel(x, y)
			s += 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			k += 1
	return s / maxf(k, 1) * 255.0
