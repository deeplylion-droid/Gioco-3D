extends Node
## Test dei tentacoli morbidi di lei nel tunnel del viaggio sottomarino (SalaSottomarino, con le forme di FormeTunnel):
## la pelle vera dei tentacoli (i vertici deformati come nella scheda) fuori dalla collisione vera del tunnel, bloccante,
## in ogni tratto:
## - la partenza dopo SB1: lei sale dalla presa d'acqua profonda in testa al tunnel (sale_dall_acqua) e incombe;
## - lungo tutta la strada, veloce (la corsa), e lenta nelle tre curve a U e nelle S;
## - (da fare, quando ci sono: il getto che la rallenta e lo schianto sul portello: il portello arriva col finale, il
##   modo in cui lei reagisce al getto nel tunnel lo decide la mascotte; per ora si stampa che mancano).
## Finché la mascotte non dà lo script che la muove nel tunnel, qui lei fluttua sull'asse del canale con l'animazione
## insegue, girata lungo la strada, col punto più basso dei tentacoli alla quota_bassa del JSON della strada.
## Poi: niente scatti, tratti vicini alla lunghezza di riposo, costo (in CI solo stampato).
## Uso: godot --headless --path godot --fixed-fps 30 --script res://tests/run.gd -- res://tests/test_morbidezza_tunnel.gd
## (SOLO=presa,strada,curve: solo quei tratti)

const Misura := preload("res://tests/misura_morbidezza.gd")
## Le velocità (m/s): la corsa lungo tutta la strada, e piano nelle curve.
const VELOCE := 7.0
const PIANO := 2.5

var _ok := 0
var _ko := 0
var sala: SalaSottomarino
var lei: MedusaAffacciata
var m: MorbidezzaLei
var mis
var _sotto := 0.0     # di quanto il punto più basso dei tentacoli sta sotto l'origine di lei (con insegue)


func _ready() -> void:
	_run.call_deferred()


func _check(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  ok  ", msg)
	else:
		_ko += 1
		print("  KO  ", msg)


func _check_costo(cond: bool, msg: String) -> void:
	if OS.has_environment("CI"):
		print("  (CI: solo stampato) %s  %s" % ["ok" if cond else "oltre", msg])
	else:
		_check(cond, msg)


func _vuoi(nome: String) -> bool:
	return not OS.has_environment("SOLO") or nome in OS.get_environment("SOLO").split(",")


func _run() -> void:
	Game.pause_on_focus_loss = false
	sala = SalaSottomarino.new()
	sala.name = "SalaSottomarino"
	get_tree().root.add_child(sala)
	get_tree().current_scene = sala
	sala.costruisci()
	var t0 := Time.get_ticks_msec()
	# (come nel gioco: a pezzi, pochi ms per fotogramma)
	var f0 := Engine.get_process_frames()
	var nf: int = await FormeTunnel.prepara_a_pezzi(sala, 4.0)
	print("forme del tunnel: %d in %d ms, %d fotogrammi" % [nf, Time.get_ticks_msec() - t0, Engine.get_process_frames() - f0])
	lei = MedusaAffacciata.new()
	lei.name = "Lei"
	lei.model = load("res://assets/models/medusa/medusa.glb")
	lei.animazioni_inseguimento = true
	lei.animazione = &"insegue"
	sala.add_child(lei)
	m = MorbidezzaLei.su(lei)
	t0 = Time.get_ticks_msec()
	print("forme date alla morbidezza: %d in %d ms" % [FormeTunnel.aggiungi(m, sala), Time.get_ticks_msec() - t0])
	# (da statua la medusa la mette a 0: chi la fa muovere la alza, come l'inseguimento)
	m.quanto = 1.0
	m.accendi(true)
	mis = Misura.new(m.get_parent() as Skeleton3D, m)
	# quanto scendono i tentacoli sotto l'origine con insegue (in alto nel tunnel, lontano da tutto)
	_metti(30.0, 0.0)
	lei.global_position.y = sala.acqua + 3.0
	_posa(&"insegue")
	var basso := INF
	for i in 60:
		await get_tree().process_frame
		for q in m.punti():
			basso = minf(basso, (q as Vector3).y - lei.global_position.y)
	_sotto = -basso
	print("i tentacoli scendono %.2f m sotto l'origine di lei (insegue)" % _sotto)
	var lung := sala.lunghezza()

	# com'è la presa: i muri a destra e a sinistra dell'asse, a varie quote (per le forme)
	for _i in 2:
		await get_tree().physics_frame
	var spazio := sala.get_world_3d().direct_space_state
	for y in [-35.0, -33.0, -31.0, -29.0]:
		var riga := "presa a s 3, quota %.0f:" % y
		for lato in [-1.0, 1.0]:
			var p0 := sala.punto(3.0)
			p0.y = y
			var hit := spazio.intersect_ray(PhysicsRayQueryParameters3D.create(p0, p0 + sala.destra(3.0) * lato * 8.0, Layers.WORLD))
			riga += "  %s" % ("-" if hit.is_empty() else "%.2f" % (hit["position"] as Vector3).distance_to(p0))
		print(riga)
	if _vuoi("presa"):
		print("== presa: lei sale dalla presa dopo SB1")
		m.azzera()
		m.accendi(true)
		# (dove dice ambienti-2: in testa, s = 0, dove la presa è più profonda)
		_metti(0.0, 0.0)
		_posa(&"inseguimento/sale_dall_acqua", false)
		var ap := _ap()
		ap.queue(&"inseguimento/incombe")
		await _registra("presa", 1.6 + 2.0, 0.0, 0.0, 1)

	if _vuoi("strada"):
		print("== strada: tutta, a %.0f m/s" % VELOCE)
		m.azzera()
		m.accendi(true)
		_metti(SalaSottomarino.PRESA_FINO + 1.0, 0.0)
		_posa(&"insegue")
		var da := SalaSottomarino.PRESA_FINO + 1.0
		var fino := lung - 2.0
		await _registra("strada", (fino - da) / VELOCE, da, VELOCE, 3)

	if _vuoi("curve"):
		# le curve a U (raggio 15 m) e le S: dove la direzione gira di più, piano
		for tratto in _curve():
			var nome := "curva %.0f-%.0f m" % [tratto[0], tratto[1]]
			print("== %s, a %.1f m/s" % [nome, PIANO])
			m.azzera()
			m.accendi(true)
			_metti(tratto[0], 0.0)
			_posa(&"insegue")
			await _registra(nome, (tratto[1] - tratto[0]) / PIANO, tratto[0], PIANO, 2)

	print("  (da fare) il getto nel tunnel: aspetta come reagisce lei (mascotte)")
	print("  (da fare) lo schianto sul portello: il portello arriva col finale (ambienti-2)")
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	get_tree().quit(1 if _ko > 0 else 0)


func _ap() -> AnimationPlayer:
	return lei.find_child("AnimationPlayer", true, false) as AnimationPlayer


func _posa(nome: StringName, ciclo := true) -> void:
	lei.animazione = nome
	var ap := _ap()
	if ap and ap.has_animation(nome):
		if ciclo:
			ap.get_animation(nome).loop_mode = Animation.LOOP_LINEAR
		ap.play(nome)


## Lei sull'asse a [param s] (girata verso l'approdo), coi tentacoli alla quota bassa (più [param su]).
func _metti(s: float, su: float) -> void:
	var p := sala.punto(s)
	var d := sala.direzione(s)
	var y := float(sala.dati["lei"]["quota_bassa"]) + _sotto + 0.02 + su
	lei.global_transform = Transform3D(Basis.looking_at(-d, Vector3.UP), Vector3(p.x, y, p.z))


## Registra [param secondi] di lei che va da [param da] a [param v] m/s lungo la strada (v = 0: ferma), poi i controlli;
## la pelle si guarda un fotogramma ogni [param ogni].
func _registra(nome: String, secondi: float, da: float, v: float, ogni: int) -> void:
	mis.inizia()
	var t := 0.0
	var s := da
	while t < secondi:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		t += dt
		if v > 0.0:
			s += v * dt
			_metti(s, 0.0)
	mis.ferma()
	var r: Dictionary = mis.risultati(nome)
	_check(r["fotogrammi"] > 20, "%s: registrati %d fotogrammi" % [nome, r["fotogrammi"]])
	var pe: Dictionary = mis.pelle(nome, 0, ogni, 0.01, [] as Array[RID], [], Layers.WORLD)
	_check(pe["pelle_dentro"] == 0, "%s: la pelle vera dei tentacoli fuori dal tunnel (%d vertici dentro, al più %.1f cm)" % [nome, pe["pelle_dentro"], pe["pelle_massimo"] * 100.0])
	_check(r["attraversa"] == 0, "%s: nessun tratto dei tentacoli attraversa il tunnel (%d)" % [nome, r["attraversa"]])
	_check(r["scarto"] > 0.05, "%s: i tentacoli si muovono davvero (al più %.2f m dalla posa)" % [nome, r["scarto"]])
	_check(r["salto"] < 25.0, "%s: niente scatti (%.1f m/s più della posa)" % [nome, r["salto"]])
	_check(r["stira_min"] > 0.15 and r["stira_max"] < 2.0, "%s: tratti vicini alla lunghezza di riposo (%.2f-%.2f)" % [nome, r["stira_min"], r["stira_max"]])
	_check_costo(r["medio"] < 4.0 and r["p95"] < 8.0, "%s: costo sotto 4 ms in media e 8 nel 95%% (%.2f e %.2f)" % [nome, r["medio"], r["p95"]])


## I tratti dove la strada gira (la direzione cambia più di 20 gradi in 10 m), allargati di 5 m e uniti: [da, a].
func _curve() -> Array:
	var out: Array = []
	var lung := sala.lunghezza()
	var s := SalaSottomarino.PRESA_FINO + 1.0
	while s < lung - 12.0:
		if sala.direzione(s).angle_to(sala.direzione(s + 10.0)) > deg_to_rad(20.0):
			var a := s - 5.0
			var b := s + 15.0
			if not out.is_empty() and a <= float(out[-1][1]):
				out[-1][1] = b
			else:
				out.append([a, b])
		s += 2.0
	return out
