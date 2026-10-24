extends Node
## Test di lei nel tunnel del viaggio sottomarino (LeiTunnel), in un tunnel finto con le misure del piano di
## ambienti-2 (sottomarino_strada.json: canale largo 7,4 m, banchine di 2,6 m alte SPONDA sopra l'acqua, volta a VOLTA m sopra l'acqua), con un
## rettilineo, una curva a sinistra e una a destra più strette di quelle vere (9 m invece di 12) e un portello in fondo:
## - riemerge, insegue lungo la strada a 4 m/s, si gira e si inclina in curva;
## - vicina al giocatore morde (insegue_morde), lontana no;
## - il getto in faccia dà il segnale, respinta() la fa ritrarre e dopo 2 s torna a inseguire;
## - lo schianto sul portello dà schianto_contro e schianto_finito;
## - la pelle vera dei tentacoli e del corpo non entra mai nel tunnel (banchine, muri, volta, portello) e nessun tratto
##   dei tentacoli lo attraversa (tests/misura_morbidezza.gd), con le forme del tunnel date alla morbidezza.
## Quando il tunnel vero di ambienti-2 c'è, lo stesso controllo va fatto lì (tests/test_lei_tunnel_strada.gd).
## Uso: godot --headless --path godot --fixed-fps 30 --script res://tests/run.gd -- res://tests/test_lei_tunnel.gd

const Misura := preload("res://tests/misura_morbidezza.gd")
const VOLTA := 6.5       # la volta più bassa sopra l'acqua (sottomarino_strada.json: volta_minima)
const SPONDA := 0.42
const CANALE := 3.7      # mezza larghezza del canale
const BANCHINA := 2.6
const VELOCITA := 4.0
const DIETRO := 12.0     # lei a tanti metri dietro il giocatore

var _ok := 0
var _ko := 0
var strada: Curve3D
var radice: Node3D


func _ready() -> void:
	_run.call_deferred()


func _check(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  ok  ", msg)
	else:
		_ko += 1
		print("  KO  ", msg)


## La strada: 20 m dritti verso -Z, curva a sinistra di 90 gradi con raggio 9 m, 12 m dritti, curva a destra di 90
## gradi con raggio 9 m, 16 m dritti; poi il portello.
func _strada() -> Curve3D:
	var c := Curve3D.new()
	c.bake_interval = 0.25
	var p := Vector3.ZERO
	var d := Vector3.FORWARD
	c.add_point(p)
	var pezzi := [[20.0, 0.0], [0.0, 90.0], [12.0, 0.0], [0.0, -90.0], [16.0, 0.0]]
	for pz in pezzi:
		if pz[0] > 0.0:
			for i in int(pz[0]):
				p += d
				c.add_point(p)
		else:
			var r := 9.0
			var passi := 18
			var a := deg_to_rad(float(pz[1])) / passi
			for i in passi:
				# (positivo: a sinistra, intorno all'asse Y)
				var nd := d.rotated(Vector3.UP, a)
				p += (d + nd).normalized() * 2.0 * r * sin(absf(a) / 2.0)
				d = nd
				c.add_point(p)
	return c


func _scatola(centro: Vector3, base: Basis, mezzo: Vector3, m: MorbidezzaLei) -> void:
	var sb := StaticBody3D.new()
	sb.collision_layer = Layers.WORLD
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = mezzo * 2.0
	cs.shape = bx
	sb.add_child(cs)
	radice.add_child(sb)
	sb.global_transform = Transform3D(base, centro)
	if m:
		m.aggiungi_scatola(sb.global_transform, mezzo)


## Il tunnel lungo la strada: a ogni mezzo metro le banchine, i muri e la volta (pezzi lunghi 0,7 m: si sovrappongono).
func _tunnel(m: MorbidezzaLei) -> void:
	var l := strada.get_baked_length()
	var s := 0.0
	while s <= l:
		var p := strada.sample_baked(s)
		var q := strada.sample_baked(minf(s + 0.5, l))
		var d := (q - p).normalized() if s + 0.5 <= l else -strada.sample_baked(l - 0.5).direction_to(p) * -1.0
		var b := Basis.looking_at(d, Vector3.UP)
		var x := b.x
		for lato in [-1.0, 1.0]:
			_scatola(p + x * lato * (CANALE + BANCHINA / 2.0) + Vector3.UP * (SPONDA - 1.0), b, Vector3(BANCHINA / 2.0, 1.0, 0.35), m)
			_scatola(p + x * lato * (CANALE + BANCHINA + 0.5) + Vector3.UP * (VOLTA / 2.0), b, Vector3(0.5, VOLTA / 2.0 + 0.5, 0.35), m)
		_scatola(p + Vector3.UP * (VOLTA + 0.5), b, Vector3(CANALE + BANCHINA + 1.0, 0.5, 0.35), m)
		s += 0.5


func _run() -> void:
	Game.pause_on_focus_loss = false
	radice = Node3D.new()
	add_child(radice)
	strada = _strada()
	var giocatore: Node3D = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	radice.add_child(giocatore)
	if giocatore.get(&"input_enabled") != null:
		giocatore.set(&"input_enabled", false)
	giocatore.process_mode = Node.PROCESS_MODE_DISABLED     # fermo dove lo mettiamo
	GameState.player = giocatore as Player
	var lt := LeiTunnel.new()
	radice.add_child(lt)
	for i in 3:
		await get_tree().process_frame
	_tunnel(lt.morbidezza)
	# il portello in fondo: un muro di traverso alla strada
	var l := strada.get_baked_length()
	var fine := strada.sample_baked(l)
	var dir_fine := strada.sample_baked(l - 1.0).direction_to(fine)
	_scatola(fine + Vector3.UP * (VOLTA / 2.0) + dir_fine * 0.15, Basis.looking_at(dir_fine, Vector3.UP),
		Vector3(CANALE + BANCHINA + 1.0, VOLTA / 2.0, 0.15), lt.morbidezza)
	var segnali := {"getto": 0, "contro": 0, "finito": 0}
	lt.getto_in_faccia.connect(func(): segnali["getto"] += 1)
	lt.schianto_contro.connect(func(): segnali["contro"] += 1)
	lt.schianto_finito.connect(func(): segnali["finito"] += 1)
	var sk := lt.lei.get_model_instance().find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var mis = Misura.new(sk, lt.morbidezza) if lt.morbidezza else null
	if mis:
		mis.inizia()

	# 1. riemerge all'inizio e insegue: il giocatore DIETRO metri avanti, tutti e due a VELOCITA
	var s_lei := 0.5
	lt.riemergi(strada.sample_baked(s_lei), strada.sample_baked(s_lei + 1.0) - strada.sample_baked(s_lei))
	_check(lt.stato == LeiTunnel.Stato.RIEMERGE, "riemerge")
	var t := 0.0
	var max_virata := 0.0
	var anim_viste := {}
	var ap := lt.lei.get_model_instance().find_child("AnimationPlayer", true, false) as AnimationPlayer
	var vicino_fatto := false
	var getto_fatto := false
	var ritrae_visto := false
	var tornata := false
	while s_lei < l - 2.5:
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		t += dt
		if lt.stato != LeiTunnel.Stato.RIEMERGE:
			s_lei += VELOCITA * dt * (0.25 if lt.in_ritrae() else 1.0)
		var p := strada.sample_baked(s_lei)
		var d := strada.sample_baked(minf(s_lei + 1.0, l)) - p
		lt.vai(p, d, dt)
		# il giocatore: lontano, poi per un tratto vicino (morde), poi di nuovo lontano
		var dietro := DIETRO
		if t > 6.0 and t < 9.0:
			dietro = 5.0
			vicino_fatto = true
		giocatore.global_position = strada.sample_baked(minf(s_lei + dietro, l)) + Vector3.RIGHT.rotated(Vector3.UP, 0) * 0.0 + Vector3.UP * SPONDA
		max_virata = maxf(max_virata, absf(lt.get(&"_virata")))
		if ap and ap.is_playing():
			anim_viste[ap.current_animation] = true
		# 2. il getto in faccia a 11 s
		if t > 11.0 and not getto_fatto and lt.stato == LeiTunnel.Stato.INSEGUE:
			getto_fatto = true
			var viso := lt.lei.find_child("Viso", true, false) as WaterHitbox
			for k in 4:
				viso.receive_water(0.2, viso.global_position, Vector3.FORWARD)
			lt.respinta()
		if lt.in_ritrae():
			ritrae_visto = true
		elif ritrae_visto and lt.stato == LeiTunnel.Stato.INSEGUE:
			tornata = true
	_check(anim_viste.has(&"inseguimento/insegue_aperta"), "insegue a bocca aperta (%s)" % [anim_viste.keys()])
	_check(vicino_fatto and anim_viste.has(&"inseguimento/insegue_morde"), "vicina morde (insegue_morde)")
	_check(segnali["getto"] == 1, "il getto in faccia dà il segnale (%d)" % segnali["getto"])
	_check(ritrae_visto and tornata, "si ritrae e poi torna a inseguire")
	_check(max_virata > 3.0 and max_virata <= lt.virata_max + 0.01, "in curva si inclina (al più %.1f gradi)" % max_virata)

	# 3. lo schianto sul portello
	var centro := fine + Vector3.UP * 4.72      # come l'oblò di ambienti-2, 4,72 m sopra l'acqua
	lt.schianto(centro, -dir_fine)
	var t2 := 0.0
	while t2 < 3.0:
		await get_tree().physics_frame
		t2 += get_physics_process_delta_time()
	_check(segnali["contro"] == 1 and segnali["finito"] == 1, "lo schianto: contro %d, finito %d" % [segnali["contro"], segnali["finito"]])
	if mis:
		mis.ferma()
		var r: Dictionary = mis.risultati("tunnel")
		_check(r["attraversa"] == 0, "nessun tratto dei tentacoli attraversa il tunnel (%d)" % r["attraversa"])
		var pe: Dictionary = mis.pelle("tunnel", 0, 2, 0.01)
		_check(pe["pelle_dentro"] == 0, "la pelle vera dei tentacoli fuori dal tunnel (%d vertici, al più %.1f cm)" % [pe["pelle_dentro"], pe["pelle_massimo"] * 100.0])
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	get_tree().quit(1 if _ko > 0 else 0)
