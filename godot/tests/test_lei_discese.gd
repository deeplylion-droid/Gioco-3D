extends Node
## Lei che torna sotto (SalaInseguimento._scendi) non sale mai prima di scendere: la radice e la testa (nel mondo)
## dall'inizio della discesa, fotogramma per fotogramma (riscontro dell'utente sulla 0.3.18: a SB1 "per andarsene
## dovrebbe scendere direttamente, invece sale di scatto tutta su e poi scende"; con "scende", che parte dalla posa di
## incombe, la radice saliva di 3,1 m in 0,17 s).
## - SB1: alla fine di affacciata_sb1 se ne va con scende_sb1: radice e testa mai sopra la posa aggrappata al bordo,
##   e nessuno scatto;
## - lo stesso salto c'era dove la discesa parte più in basso della posa "su": la respinta a metà salita, la respinta
##   a SB1; e scende dalla posa di incombe e dalla grata resta com'era.
## Lei è quella di SalaInseguimento (_lei_crea, le animazioni vere), senza la sala intorno.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_lei_discese.gd

var _ok := 0
var _ko := 0
var sala: SalaInseguimento


func _ready() -> void:
	_run.call_deferred()


func _check(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  ok    ", msg)
	else:
		_ko += 1
		print("  FALLITO ", msg)


## [param da] (al tempo [param t_da]) e poi _scendi in [param dove]: [radice al più, testa al più (m sopra la posa di
## partenza), salto più grande della velocità della testa fra due fotogrammi (m/s), animazione, durata della discesa].
func _discesa(dove: String, da: String, t_da: float, respinta: bool) -> Array:
	var lei := sala.lei
	var ap := lei.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var sk := lei.find_child("Skeleton3D", true, false) as Skeleton3D
	var r := sk.find_bone("radice")
	var te := sk.find_bone("testa")
	lei.global_position = Vector3.ZERO
	lei.visible = true
	sala.set(&"_lei_dove", dove)
	sala.lei_stato = SalaInseguimento.Lei.SU
	lei.animazione = StringName("inseguimento/" + da)
	ap.play(StringName("inseguimento/" + da))
	ap.seek(t_da, true)
	for i in 3:
		await get_tree().process_frame
	var r0 := (sk.global_transform * sk.get_bone_global_pose(r).origin).y
	var t0 := (sk.global_transform * sk.get_bone_global_pose(te).origin).y
	sala.call(&"_scendi", respinta)
	var max_r := -INF
	var max_t := -INF
	var salto := 0.0
	var prima := t0
	var v_prima := 0.0
	var durata := float(sala.get_meta(&"durata_discesa", 1.0))
	var t := 0.0
	while t < durata:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		t += dt
		var ry := (sk.global_transform * sk.get_bone_global_pose(r).origin).y - r0
		var ty := (sk.global_transform * sk.get_bone_global_pose(te).origin).y
		max_r = maxf(max_r, ry)
		max_t = maxf(max_t, ty - t0)
		var v := (ty - prima) / dt
		if t > dt * 1.5:
			salto = maxf(salto, absf(v - v_prima))
		v_prima = v
		prima = ty
	return [max_r, max_t, salto, String(lei.animazione), durata]


func _run() -> void:
	Game.pause_on_focus_loss = false
	sala = SalaInseguimento.new()
	sala.costruzione_a_pezzi = true     # (niente sala: solo i dati e lei)
	add_child(sala)
	sala.set_physics_process(false)
	sala.call(&"_lei_crea")
	for i in 5:
		await get_tree().process_frame
	print("== SB1: se ne va alla fine di affacciata_sb1")
	var d := await _discesa("sb1", "affacciata_sb1", 5.4, false)
	print("  radice al più %+.3f m, testa al più %+.3f m, salto di velocità della testa %.2f m/s, %s, %.2f s" % d)
	_check(d[3] == "inseguimento/scende_sb1", "a SB1 se ne va con scende_sb1 (%s)" % d[3])
	_check(d[0] <= 0.005, "a SB1 la radice non sale mai sopra la posa aggrappata al bordo (al più %+.3f m)" % d[0])
	_check(d[1] <= 0.005, "a SB1 la testa non sale mai sopra la posa aggrappata al bordo (al più %+.3f m)" % d[1])
	_check(d[2] < 1.5, "a SB1 nessuno scatto: la velocità della testa cambia al più %.2f m/s fra due fotogrammi" % d[2])
	_check(d[4] > 0.4 and d[4] < 1.2, "a SB1 sparisce sotto dopo %.2f s" % d[4])
	print("== le altre discese, che partono da più in basso della posa \"su\" o da lei")
	for caso in [["sb1", "affacciata_sb1", 5.4, true], ["sb1", "affacciata_sb1", 0.5, true],
			["vasca_0", "sale_dall_acqua", 0.5, true], ["vasca_0", "sale_dall_acqua", 0.8, true],
			["grata", "sale_dall_acqua_veloce", 0.5, true], ["vasca_0", "incombe", 0.0, false],
			["vasca_0", "incombe", 0.0, true], ["grata", "colpo_grata_sbieco", 0.5, false]]:
		d = await _discesa(caso[0], caso[1], caso[2], caso[3])
		var nome := "%s, %s a %.1f s, %s" % [caso[0], caso[1], caso[2], "respinta" if caso[3] else "scende"]
		print("  %s: radice al più %+.3f m, testa al più %+.3f m, salto di velocità della testa %.2f m/s" % [nome, d[0], d[1], d[2]])
		# (la respinta da incombe tira su la radice di 5 cm e la testa di 12: è la testa che scatta indietro, voluta.
		# Respinta mentre sale: nei 0,15 s della fusione la salita va ancora avanti, lo slancio che si ferma, al più
		# 25 cm; prima tornava di scatto all'altezza della posa "su", fino a 4,3 m)
		var salita: bool = (caso[1] as String).begins_with("sale") or (caso[1] == "affacciata_sb1" and float(caso[2]) < 1.3)
		var lim_r := 0.30 if salita else 0.08
		var lim_t := 0.30 if salita else 0.15
		_check(d[0] <= lim_r, "%s: la radice non sale (al più %+.3f m, ammessi %.2f)" % [nome, d[0], lim_r])
		_check(d[1] <= lim_t, "%s: la testa non sale (al più %+.3f m, ammessi %.2f)" % [nome, d[1], lim_t])
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	get_tree().quit(1 if _ko > 0 else 0)
