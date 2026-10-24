extends Node
## Test dei tentacoli morbidi di lei nel tunnel del viaggio sottomarino, coi pezzi veri: la logica della sala
## (SalaSottomarino: riemergi, insegui_da, respingi, chiudi_portello) e lei (LeiTunnel di mascotte, con la sua
## morbidezza), con le forme del tunnel (FormeTunnel) e un bersaglio finto al posto del giocatore lungo la banchina.
## La pelle vera dei tentacoli (i vertici deformati come nella scheda) fuori dalla collisione vera del tunnel e dei
## gommoni, bloccante, in ogni tratto:
## - presa: dopo SB1 lei riemerge dalla presa (s = -1) e parte;
## - strada: tu corri (5,8 m/s) fino all'approdo e lei insegue, con un getto in faccia ogni 120 m (ritrae);
## - curve: nelle tre curve a U a guado (2 m/s): lei ti raggiunge, morde e ti prende (presa);
## - schianto: all'approdo il portello si chiude e lei sbatte la faccia sull'oblò.
## Poi: niente scatti, tratti vicini alla lunghezza di riposo, costo (in CI solo stampato).
## Uso: godot --headless --path godot --fixed-fps 30 --script res://tests/run.gd -- res://tests/test_morbidezza_tunnel.gd
## (SOLO=presa,strada,curve,schianto: solo quei tratti)

const Misura := preload("res://tests/misura_morbidezza.gd")
const CORSA := 5.8
const GUADO := 2.0
## Ogni quanti metri un getto in faccia, nella corsa.
const GETTO_OGNI := 120.0
## I casi noti, come i "voluto" del controllo di posizionamento: tratto -> [motivo, data]. Lì la pelle e il costo si
## stampano e basta (gli altri controlli restano bloccanti). Da togliere appena è corretto: nessuna build esce così.
const NOTI := {
	# (schianto tolto il 24 ottobre: con la scelta B di ambienti-2 e mascotte, niente ballatoio davanti al portello)
}

var _ok := 0
var _ko := 0
var sala: SalaSottomarino
var b: Node3D
var m: MorbidezzaLei
var mis


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
	b = Node3D.new()
	add_child(b)
	sala.bersaglio = b
	# (come nel gioco: a pezzi, pochi ms per fotogramma, mentre il tunnel si costruisce)
	var t0 := Time.get_ticks_msec()
	var f0 := Engine.get_process_frames()
	var nf: int = await FormeTunnel.prepara_a_pezzi(sala, 4.0)
	print("forme del tunnel: %d in %d ms, %d fotogrammi" % [nf, Time.get_ticks_msec() - t0, Engine.get_process_frames() - f0])
	m = sala.lei_tunnel.morbidezza
	t0 = Time.get_ticks_msec()
	print("forme date alla morbidezza: %d in %d ms" % [FormeTunnel.aggiungi(m, sala), Time.get_ticks_msec() - t0])
	mis = Misura.new(m.get_parent() as Skeleton3D, m)
	var lung := sala.lunghezza()

	if _vuoi("presa"):
		print("== presa: lei riemerge dalla presa dopo SB1 e parte")
		_bersaglio(25.0)
		sala._s_bersaglio = 25.0
		mis.inizia()
		sala.riemergi()
		await _corri(25.0, 0.0, 5.0)
		await _controlli("presa")

	if _vuoi("strada"):
		print("== strada: corri a %.1f m/s fino all'approdo, un getto in faccia ogni %.0f m" % [CORSA, GETTO_OGNI])
		var s0 := 20.0
		_ripartenza(s0, 12.0)
		mis.inizia()
		var getti := 0
		var prossimo := s0 + GETTO_OGNI
		var s := s0
		while s < lung - 25.0:
			s = await _corri(s, CORSA, 1.0)
			if s >= prossimo:
				prossimo += GETTO_OGNI
				getti += 1
				sala.respingi()
			if sala.lei_stato == SalaSottomarino.Lei.PRESA:
				break
		_check(getti >= 3, "strada: %d getti in faccia (ritrae)" % getti)
		await _controlli("strada", 3)

	if _vuoi("curve"):
		for sc: float in _curve_u():
			var nome := "curva a U a %.0f m, a guado" % sc
			print("== %s (%.1f m/s): ti raggiunge, morde e ti prende" % [nome, GUADO])
			_ripartenza(sc - 15.0, 12.0)
			mis.inizia()
			var s := sc - 15.0
			var t := 0.0
			while t < 16.0 and sala.lei_stato != SalaSottomarino.Lei.PRESA:
				s = await _corri(s, GUADO, 0.5)
				t += 0.5
			# (la presa intera)
			await _corri(s, 0.0, 1.6)
			_check(sala.lei_stato == SalaSottomarino.Lei.PRESA, "%s: ti prende" % nome)
			await _controlli(nome, 2)

	if _vuoi("schianto"):
		print("== schianto: il portello si chiude e lei sbatte sull'oblò")
		var sf := lung - 3.0
		_ripartenza(sf - 6.0, 14.0)
		mis.inizia()
		var s := sf - 6.0
		s = await _corri(s, CORSA, 1.0)
		sala.chiudi_portello()
		await _corri(s, 0.0, 2.0 + 2.6 + 0.5)
		await _controlli("schianto", 1)

	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	get_tree().quit(1 if _ko > 0 else 0)


## Ricomincia: lei ferma sotto, poi insegue da [param dietro] metri dietro [param s] (come dai checkpoint).
func _ripartenza(s: float, dietro: float) -> void:
	sala.lei_stato = SalaSottomarino.Lei.VIA
	sala.lei_tunnel.stato = LeiTunnel.Stato.VIA
	m.azzera()
	_bersaglio(s)
	sala._s_bersaglio = s
	sala.insegui_da(s - dietro)


func _bersaglio(s: float) -> void:
	var p := sala.punto(s) - sala.destra(s) * (sala.canale + sala.banchina * 0.5)
	b.global_position = Vector3(p.x, sala.piano, p.z)


## Il bersaglio va da [param s] a [param v] m/s per [param secondi]; ritorna dove è arrivato.
func _corri(s: float, v: float, secondi: float) -> float:
	var t := 0.0
	while t < secondi:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		t += dt
		s = minf(s + v * dt, sala.lunghezza() - 3.0)
		_bersaglio(s)
	return s


## I controlli del tratto registrato (la pelle un fotogramma ogni [param ogni]).
func _controlli(nome: String, ogni := 1) -> void:
	mis.ferma()
	var r: Dictionary = mis.risultati(nome)
	_check(r["fotogrammi"] > 20, "%s: registrati %d fotogrammi" % [nome, r["fotogrammi"]])
	var pe: Dictionary = mis.pelle(nome, 0, ogni, 0.01, [] as Array[RID], [], Layers.WORLD)
	if NOTI.has(nome):
		print("  noto  %s: %s (%s): pelle %d vertici dentro (al più %.1f cm), costo medio %.2f ms" % [nome, NOTI[nome][0],
				NOTI[nome][1], pe["pelle_dentro"], pe["pelle_massimo"] * 100.0, r["medio"]])
		_check(r["salto"] < 25.0, "%s: niente scatti (%.1f m/s più della posa)" % [nome, r["salto"]])
		return
	_check(pe["pelle_dentro"] == 0, "%s: la pelle vera dei tentacoli fuori dal tunnel (%d vertici dentro, al più %.1f cm)" % [nome, pe["pelle_dentro"], pe["pelle_massimo"] * 100.0])
	_check(r["attraversa"] == 0, "%s: nessun tratto dei tentacoli attraversa il tunnel (%d)" % [nome, r["attraversa"]])
	_check(r["scarto"] > 0.05, "%s: i tentacoli si muovono davvero (al più %.2f m dalla posa)" % [nome, r["scarto"]])
	_check(r["salto"] < 25.0, "%s: niente scatti (%.1f m/s più della posa)" % [nome, r["salto"]])
	_check(r["stira_min"] > 0.15 and r["stira_max"] < 2.0, "%s: tratti vicini alla lunghezza di riposo (%.2f-%.2f)" % [nome, r["stira_min"], r["stira_max"]])
	_check_costo(r["medio"] < 4.0 and r["p95"] < 8.0, "%s: costo sotto 4 ms in media e 8 nel 95%% (%.2f e %.2f)" % [nome, r["medio"], r["p95"]])


## Il mezzo delle curve a U (dove la direzione della strada si gira del tutto): s.
func _curve_u() -> Array:
	var out: Array = []
	var lung := sala.lunghezza()
	var s := 10.0
	while s < lung - 30.0:
		if sala.direzione(s - 25.0).dot(sala.direzione(s + 25.0)) < -0.8:
			var a := s
			while sala.direzione(s - 25.0).dot(sala.direzione(s + 25.0)) < -0.8:
				s += 1.0
			out.append((a + s) * 0.5)
		s += 1.0
	return out
