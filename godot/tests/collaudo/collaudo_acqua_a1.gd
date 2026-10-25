extends Node
## (copia di ambienti-1, 25 ottobre sera: uscita dritta e a 30, 45 e 60 gradi, fuori entro 4 s) Collaudo (grafica-2) di "niente salto nell'acqua del tunnel": dall'acqua si esce camminando dove capita di cadere.
## 14 punti a caso (seme fisso) lungo il canale, a una distanza a caso dall'asse, più 4 punti accanto agli ostacoli; da
## ognuno si prova il salto (non deve partire) e poi si cammina verso la banchina più vicina, di sbieco (45° avanti):
## fuori se in 8 s si sta in piedi sulla banchina. Uso: godot --headless --path godot --fixed-fps 60 --script
## res://tests/run.gd -- res://tests/collaudo/collaudo_acqua_g2.gd

const PLAYER := "res://scenes/player/player.tscn"
var sala: SalaSottomarino
var p: Player
var righe := []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	sala = SalaSottomarino.new()
	get_tree().root.add_child(sala)
	sala.costruisci()
	p = (load(PLAYER) as PackedScene).instantiate() as Player
	get_tree().root.add_child(p)
	await _frames(10)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2525
	var punti := []
	while punti.size() < 14:
		var s := rng.randf_range(8.0, sala.lunghezza() - 12.0)
		if sala._lato(s, -1.0)["crollo"] and sala._lato(s, 1.0)["crollo"]:
			continue
		punti.append([s, rng.randf_range(-1.0, 1.0) * (sala.canale - SalaSottomarino.GRADINO_LARGO - 0.4), "a caso"])
	for o in sala.ostacoli.slice(0, 4):
		var s := float(o["s"]) + float(o["lungo"]) * 0.5
		punti.append([s, -float(o["lato"]) * 0.3 + float(o["lato"]) * (sala.canale - SalaSottomarino.GRADINO_LARGO - 0.4), "accanto a " + str(o.get("tipo", "ostacolo"))])
	var usciti := 0
	var salti := 0
	for pt in punti:
		var s: float = pt[0]
		var dl: float = pt[1]
		var q := sala.punto(s) + sala.destra(s) * dl
		var da := Vector3(q.x, sala.fondo + 0.02, q.z)
		# la banchina più vicina; se lì è crollata, l'altra
		var lato := signf(dl) if dl != 0.0 else 1.0
		if sala._lato(s, lato)["crollo"]:
			lato = -lato
		p.teleport(da)
		await _frames(30)
		var y0 := p.global_position.y
		var su := 0.0
		Input.action_press(&"jump")
		for i in 40:
			await get_tree().physics_frame
			su = maxf(su, p.global_position.y - y0)
		Input.action_release(&"jump")
		await _frames(10)
		var esiti := []
		var tutti := true
		for g in [0.0, 30.0, 45.0, 60.0]:
			var a := deg_to_rad(g)
			var r: Array = await _cammina(da, (sala.destra(s) * lato * cos(a) + sala.direzione(s) * sin(a)).normalized())
			esiti.append("%s: %s" % ["dritto" if g == 0.0 else "%d°" % int(g), _esito(r)])
			if r[0] < 0.0 or r[0] > 4.0:
				tutti = false
		var dove := "; ".join(esiti)
		if tutti:
			usciti += 1
		if su < 0.05:
			salti += 1
		righe.append("s %.1f, dall'asse %+.2f, verso il lato %+d (%s): salto %.2f m; %s" % [s, dl, int(lato), pt[2], su, dove])
	for r in righe:
		print("ACQUA ", r)
	print("ACQUA RISULTATO: usciti entro 4 s in tutte e quattro le direzioni %d su %d, salto non partito %d su %d" % [usciti, punti.size(), salti, punti.size()])
	get_tree().quit()


## Cammina avanti verso [param verso] per 8 s: [tempo per essere in piedi sulla banchina o -1, dove si è fermato rispetto
## all'asse e all'altezza].
func _cammina(da: Vector3, verso: Vector3) -> Array:
	p.teleport(da, atan2(-verso.x, -verso.z))
	await _frames(6)
	Input.action_press(&"move_forward")
	var t := 0.0
	var fuori := -1.0
	while t < 8.0:
		await get_tree().physics_frame
		t += 1.0 / 60.0
		if p.is_on_floor() and p.global_position.y > sala.piano - 0.05:
			fuori = t
			break
	Input.action_release(&"move_forward")
	var fine := p.global_position
	await _frames(10)
	return [fuori, fine]


func _esito(r: Array) -> String:
	if r[0] > 0.0:
		return "fuori in %.1f s" % r[0]
	var fine: Vector3 = r[1]
	return "NON ESCE (fermo a y %.2f, %.2f sopra il fondo, in %s)" % [fine.y, fine.y - sala.fondo, str(fine.snapped(Vector3.ONE * 0.01))]


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
