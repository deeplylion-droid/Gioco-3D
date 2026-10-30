extends Node
## Ricontrollo della nebbia viola sul fondo della piscina a onde vuota (lavoro/nebbia-0317): lo strato fitto che scende
## dove poggiano i piedi (NebbiaViola._fondo) col giocatore vero, nella sala vera, senza schermo. Il giocatore:
## 1. in piedi sul pavimento accanto al bordo est;
## 2. va avanti col controller finché cade nella piscina vuota e arriva sul fondo;
## 3. sul fondo salta, poi si accovaccia;
## 4. torna sul pavimento accanto alla scaletta est (a passi, vedi sotto).
## A ogni fotogramma stampa e controlla dov'è lo strato: niente salti (al più SEGUI_FONDO al secondo), fermo mentre è
## in aria o si accovaccia, sul pavimento a 0 e sul fondo ai piedi.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- \
##        res://tests/collaudo/nebbia_fondo_dinamica.gd

const LEVEL := "res://scenes/sala_principale.tscn"
## Sul pavimento accanto al bordo est della piscina, guardando a ovest (verso la piscina).
const BORDO := Vector3(8.4, 0.05, 1.0)

var p: Player
var nv: NebbiaViola
var _ok := 0
var _ko := 0


func _ready() -> void:
	_run.call_deferred()


func check(c: bool, msg: String) -> void:
	if c:
		_ok += 1
		print("  ok    ", msg)
	else:
		_ko += 1
		print("  FALLITO ", msg)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	get_tree().change_scene_to_file(LEVEL)
	for i in 600:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player):
			break
	await _frames(30)
	get_tree().paused = false
	p = GameState.player
	nv = Grafica.nebbia_viola
	var sala := get_tree().current_scene
	var pozza := sala.get_node(^"Piscina/Pozza") as WaterTank
	pozza.fill = 0.0
	var scaletta := sala.get_node(^"Piscina/ScalettaEst") as Node3D
	await _frames(10)
	# 1. sul pavimento
	p.teleport(BORDO, 0.0, 0.0)
	p.set_look(PI / 2.0, 0.0)   # (verso ovest)
	await _frames(120)
	var f0: float = nv.get(&"_fondo")
	print("pavimento: piedi a %.2f, strato a %.2f, quanto %.2f" % [p.global_position.y, f0, nv.quanto])
	check(absf(f0 - p.global_position.y) < 0.02, "sul pavimento lo strato sta ai piedi (%.2f)" % f0)
	# 2. avanti finché cade e arriva sul fondo
	var salto_max := 0.0
	var prima: float = f0
	var in_aria_cambia := 0.0
	var obiettivo_prima: float = nv.get(&"_fondo_obiettivo")
	Input.action_press(&"move_forward")
	var t := 0.0
	var caduto := false
	var a_terra_dal := -1.0
	while t < 6.0:
		p.set_look(PI / 2.0, 0.0)
		await get_tree().physics_frame
		await get_tree().process_frame
		t += 1.0 / 60.0
		var f: float = nv.get(&"_fondo")
		salto_max = maxf(salto_max, absf(f - prima))
		var obiettivo: float = nv.get(&"_fondo_obiettivo")
		if p.global_position.y < -0.3 and p.global_position.y > -1.9:
			in_aria_cambia = maxf(in_aria_cambia, absf(obiettivo - obiettivo_prima))
		obiettivo_prima = obiettivo
		prima = f
		if int(t * 60.0) % 20 == 0:
			print("  discesa %.2f s: piedi (%.2f, %.2f, %.2f) a terra %s, strato %.2f" % [t, p.global_position.x, p.global_position.y, p.global_position.z, p.is_on_floor(), f])
		if p.global_position.y < -1.0:
			caduto = true
		if caduto and p.is_on_floor():
			Input.action_release(&"move_forward")
			if a_terra_dal < 0.0:
				a_terra_dal = t
				print("sul fondo a %.2f s: piedi a %.2f, strato a %.2f" % [t, p.global_position.y, f])
			if t - a_terra_dal > 1.5:
				break
	Input.action_release(&"move_forward")
	var fondo_piedi := p.global_position.y
	var f1: float = nv.get(&"_fondo")
	print("discesa: salto più grande dello strato in un fotogramma %.3f m (al più %.3f), mentre cadeva cambiava di %.3f" % [salto_max, NebbiaViola.SEGUI_FONDO / 60.0 + 1e-3, in_aria_cambia])
	check(caduto, "è caduto nella piscina vuota")
	check(salto_max <= NebbiaViola.SEGUI_FONDO / 60.0 + 1e-3, "scendendo lo strato scende piano, senza salti (%.3f m al fotogramma)" % salto_max)
	check(in_aria_cambia < 1e-3, "mentre cade il punto che lo strato segue resta dov'era (cambiato di %.3f m)" % in_aria_cambia)
	check(absf(f1 - fondo_piedi) < 0.02, "sul fondo lo strato sta ai piedi (strato %.2f, piedi %.2f)" % [f1, fondo_piedi])
	# 3. salto e accovacciarsi
	var cambio := 0.0
	Input.action_press(&"jump")
	await _frames(2)
	Input.action_release(&"jump")
	var su := 0.0
	for i in 90:
		await get_tree().physics_frame
		su = maxf(su, p.global_position.y - fondo_piedi)
		cambio = maxf(cambio, absf(float(nv.get(&"_fondo")) - f1))
	print("salto: su di %.2f m, lo strato è cambiato di %.3f" % [su, cambio])
	check(su > 0.2, "ha saltato (%.2f m)" % su)
	check(cambio < 0.01, "saltando lo strato non cambia (%.3f m)" % cambio)
	cambio = 0.0
	Input.action_press(&"crouch")
	for i in 90:
		await get_tree().physics_frame
		cambio = maxf(cambio, absf(float(nv.get(&"_fondo")) - f1))
	var occhi_giu := p.get_eye_position().y - fondo_piedi
	Input.action_release(&"crouch")
	await _frames(60)
	print("accovacciato: occhi a %.2f m dai piedi, lo strato è cambiato di %.3f" % [occhi_giu, cambio])
	check(cambio < 0.01, "accovacciandosi lo strato non cambia (%.3f m)" % cambio)
	# 4. su dal fondo al pavimento. La scaletta est col mio controller in cima non fa scavalcare (si torna giù: da
	# guardare a parte, scaletta e non nebbia); quindi il giocatore, a fisica ferma, sale a passi di 2 cm (non contano
	# come salto della camera) dal fondo al pavimento accanto alla scaletta, poi riparte e sta 2 s sul pavimento
	var da := p.global_position
	var a := Vector3(scaletta.global_position.x + 0.9, 0.05, scaletta.global_position.z)
	p.process_mode = Node.PROCESS_MODE_DISABLED
	prima = nv.get(&"_fondo")
	salto_max = 0.0
	var passi := int(da.distance_to(a) / 0.02)
	for k in passi + 1:
		p.global_position = da.lerp(a, float(k) / passi)
		await get_tree().process_frame
		var f: float = nv.get(&"_fondo")
		salto_max = maxf(salto_max, absf(f - prima))
		prima = f
	var mentre_sale := absf(float(nv.get(&"_fondo")) - f1)
	p.process_mode = Node.PROCESS_MODE_INHERIT
	var arrivo := -1.0
	t = 0.0
	while t < 2.0:
		await get_tree().physics_frame
		await get_tree().process_frame
		t += 1.0 / 60.0
		var f: float = nv.get(&"_fondo")
		salto_max = maxf(salto_max, absf(f - prima))
		if arrivo < 0.0 and absf(f - p.global_position.y) < 0.01:
			arrivo = t
		prima = f
	var f2: float = nv.get(&"_fondo")
	print("salita: mentre sale (senza toccare terra) lo strato cambia di %.3f; sul pavimento lo raggiunge in %.2f s; salto più grande %.3f m al fotogramma" % [mentre_sale, arrivo, salto_max])
	# (a fisica ferma is_on_floor resta quello di prima, vero: lo strato segue i piedi che salgono, come su una rampa)
	check(salto_max <= NebbiaViola.SEGUI_FONDO / 60.0 + 1e-3, "risalendo lo strato sale piano, senza salti (%.3f m al fotogramma)" % salto_max)
	check(absf(f2 - p.global_position.y) < 0.02, "sul pavimento lo strato torna ai piedi (%.2f)" % f2)
	print("RISULTATO: %d ok, %d falliti" % [_ok, _ko])
	get_tree().quit()
