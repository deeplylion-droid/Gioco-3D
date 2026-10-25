extends Node
## Collaudo di ambienti-1 (25 ottobre sera): il giocatore fermo dove gira l'anta della porta nord dell'infermeria mentre si
## apre (dopo il colpo al pulsantone): l'anta non lo deve spingere, stringere contro il muro, far passare attraverso il
## muro o l'anta (il difetto P1 del portello). Per ogni punto: la scena di prova da capo, il giocatore fermo lì, il
## pulsantone acceso e premuto, 3,2 s; poi quanto e verso dove si è mosso, quanto è entrato nell'anta (la sua forma
## contro la scatola dell'anta), se è finito fra l'anta e il muro o fuori dalla stanza, e se poi si muove liberamente.
## COLLAUDO_SENZA_COLPO=1: la prova di controllo, senza aprire. SCATTO_PEGGIORE=<cartella> (con lo schermo): lo scatto
## dalla camera del giocatore nel fotogramma in cui entra di più nell'anta, per ogni punto.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo_arco_anta_a1.gd

const SCENA := "res://tests/scene/infermeria_gioco_prova.tscn"
## Punti dell'infermeria (x, z): l'asse dei cardini è a (-1,762, -3,122), l'anta è larga 0,876 e gira verso la stanza
## (z più grande) fino a stendersi lungo il muro nord (z -3,122/-3,072) fra x -1,762 e -0,886.
const PUNTI := {
	"cardini": Vector2(-1.65, -2.8),
	"meta": Vector2(-1.76, -2.55),
	"punta": Vector2(-2.45, -2.6),
	"davanti_al_vano": Vector2(-2.2, -2.75),
	"angolo_porta_muro": Vector2(-1.1, -2.85),
	"angolo_porta_muro_2": Vector2(-1.3, -2.75),
}
const MURO_NORD := -3.2
const L := 3.2

var _ok := 0
var _ko := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var cartella := OS.get_environment("SCATTO_PEGGIORE")
	if cartella != "":
		DirAccess.make_dir_recursive_absolute(cartella)
	var solo := OS.get_environment("PUNTI_SOLO").split(",", false)
	for nome: String in PUNTI:
		if not solo.is_empty() and not solo.has(nome):
			continue
		var punto: Vector2 = PUNTI[nome]
		get_tree().change_scene_to_file(SCENA)
		var p: Node3D = await _aspetta()
		var inf := get_tree().current_scene.get_node(^"Infermeria") as Node3D
		var inter := inf.get_node(^"Interruttore") as WaterButton
		var anta := inf.get(&"_anta_nord") as Node3D
		var forma := p.get(&"collision_shape") as CollisionShape3D
		var raggio := _raggio(forma)
		p.call(&"teleport", inf.to_global(Vector3(punto.x, 0.0, punto.y)), 0.0, 0.0)
		# guarda il pulsantone, come quando lo colpisce da lì
		var verso := inter.global_position - p.global_position
		p.call(&"set_look", atan2(-verso.x, -verso.z), -0.2)
		await _secondi(0.4)
		var prima := inf.to_local(p.global_position)
		if OS.get_environment("COLLAUDO_SENZA_COLPO") != "1":
			inter.powered = true
			inter.pressed.emit()
		var max_spinta := 0.0
		var max_dentro := 0.0
		var dentro_fot := 0
		var t_peggio := -1.0
		var min_z := prima.z
		var fra_anta_e_muro := false
		var fuori := false
		var immagine: Image = null
		var pause := 0
		var riprese := 0
		var era_in_pausa := false
		var suoni_prima := int(Audio.conteggio.get(&"porta_ponte_apre", 0))
		for i in int(3.2 * 60):
			await get_tree().physics_frame
			var sn = inf.get(&"_suono_nord")
			if sn is AudioStreamPlayer3D:
				var pa: bool = (sn as AudioStreamPlayer3D).stream_paused
				if pa and not era_in_pausa:
					pause += 1
				if not pa and era_in_pausa:
					riprese += 1
				era_in_pausa = pa
			var ora := inf.to_local(p.global_position)
			max_spinta = maxf(max_spinta, Vector2(ora.x - prima.x, ora.z - prima.z).length())
			min_z = minf(min_z, ora.z)
			var d := _entra(p, anta, raggio)
			if d > 0.005:
				dentro_fot += 1
			if d > max_dentro:
				max_dentro = d
				t_peggio = (i + 1) / 60.0
				if cartella != "":
					await RenderingServer.frame_post_draw
					immagine = get_viewport().get_texture().get_image()
			# fra l'anta (quando è quasi aperta) e il muro, o oltre il muro e fuori dalla stanza
			if anta.rotation_degrees.y > 150.0 and ora.z < -3.072 and ora.x > -1.8 and ora.x < -0.85:
				fra_anta_e_muro = true
			if ora.z < MURO_NORD - 0.01 or absf(ora.x) > L or ora.z > L:
				fuori = true
		var dopo := inf.to_local(p.global_position)
		var spinta := Vector2(dopo.x - prima.x, dopo.z - prima.z)
		var angolo_fermo := anta.rotation_degrees.y
		if immagine:
			immagine.save_jpg(cartella.path_join("arco_%s_peggio.jpg" % nome), 0.9)
		# si muove liberamente: verso il centro della stanza, poi di lato
		var da := p.global_position
		await _cammina(p, inf.to_global(Vector3(0.0, 0.0, -1.0)), 1.5)
		var via1 := p.global_position.distance_to(da)
		var da2 := p.global_position
		await _cammina(p, inf.to_global(Vector3(-2.5, 0.0, -1.0)), 1.5)
		var via2 := p.global_position.distance_to(da2)
		# andato via: l'anta finisce di aprirsi (e il suono riprende)
		for i in int(3.5 * 60):
			await get_tree().physics_frame
			var sn = inf.get(&"_suono_nord")
			if sn is AudioStreamPlayer3D:
				var pa: bool = (sn as AudioStreamPlayer3D).stream_paused
				if not pa and era_in_pausa:
					riprese += 1
				era_in_pausa = pa
		var angolo := anta.rotation_degrees.y
		var suoni := int(Audio.conteggio.get(&"porta_ponte_apre", 0)) - suoni_prima
		print("   anta col giocatore fermo a %.1f gradi; suono: %d pause, %d riprese, %d suoni in tutto" % [angolo_fermo, pause, riprese, suoni])
		_check(absf(angolo - 180.0) < 0.5, "%s: andato via il giocatore, l'anta arriva a 180 gradi (%.1f)" % [nome, angolo])
		_check(suoni == 1 and riprese == pause, "%s: un solo suono, che si ferma e riparte con l'anta (%d suoni, %d pause, %d riprese)" % [nome, suoni, pause, riprese])
		print("raggio del giocatore %.2f m" % raggio)
		print("%s (%.2f, %.2f): spinto al massimo %.3f m, alla fine %.3f m verso (%.2f, %.2f) [x+ est, z+ verso la stanza], fino a (%.2f, %.2f); z minima %.3f; entra nell'anta al massimo %.3f m (a %.2f s), per %d fotogrammi; fra anta e muro: %s; fuori dalla stanza: %s; anta a %.1f gradi alla fine; poi cammina %.2f e %.2f m in 1,5 s" % [
			nome, punto.x, punto.y, max_spinta, spinta.length(), spinta.x, spinta.y, dopo.x, dopo.z, min_z, max_dentro, t_peggio, dentro_fot,
			fra_anta_e_muro, fuori, angolo, via1, via2])
		_check(max_spinta < 0.02, "%s: l'anta non spinge il giocatore (%.3f m)" % [nome, max_spinta])
		_check(max_dentro < 0.01, "%s: non gli passa attraverso (entra %.3f m)" % [nome, max_dentro])
		_check(not fra_anta_e_muro, "%s: non lo stringe fra l'anta e il muro" % nome)
		_check(not fuori, "%s: non lo spinge attraverso il muro, resta nella stanza" % nome)
		_check(via1 > 0.8 and via2 > 0.8, "%s: aperta, si muove liberamente (%.2f e %.2f m)" % [nome, via1, via2])
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	get_tree().quit(1 if _ko > 0 else 0)


## Il raggio della forma del giocatore (capsula o cilindro).
func _raggio(forma: CollisionShape3D) -> float:
	if forma and forma.shape is CapsuleShape3D:
		return (forma.shape as CapsuleShape3D).radius
	if forma and forma.shape is CylinderShape3D:
		return (forma.shape as CylinderShape3D).radius
	return 0.3


## Quanto il giocatore (un cilindro col suo raggio, in pianta) entra nella scatola dell'anta (0 se non la tocca).
func _entra(p: Node3D, anta: Node3D, raggio: float) -> float:
	var corpo := anta.find_child("AntaNord", true, false) as Node3D
	var f := corpo.get_child(0) as CollisionShape3D
	var b := f.shape as BoxShape3D
	var loc := f.global_transform.affine_inverse() * p.global_position
	var mezzo := b.size * 0.5
	var dx := maxf(absf(loc.x) - mezzo.x, 0.0)
	var dz := maxf(absf(loc.z) - mezzo.z, 0.0)
	var fuori := Vector2(dx, dz).length()
	if fuori > 0.0:
		return maxf(raggio - fuori, 0.0)
	# il centro dentro la scatola
	return raggio + minf(mezzo.x - absf(loc.x), mezzo.z - absf(loc.z))


func _cammina(p: Node3D, t: Vector3, secondi: float) -> void:
	Input.action_press(&"move_forward")
	for i in int(secondi * 60.0):
		var d := t - p.global_position
		if Vector2(d.x, d.z).length() < 0.35:
			break
		p.call(&"set_look", atan2(-d.x, -d.z), 0.0)
		await get_tree().physics_frame
	Input.action_release(&"move_forward")


func _aspetta() -> Node3D:
	for i in 400:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and not GameState.is_dying:
			break
	await _secondi(0.1)
	var p := GameState.player
	for i in 400:
		if p.input_enabled:
			break
		await get_tree().process_frame
	return p


func _secondi(t: float) -> void:
	for i in int(round(t * 60.0)):
		await get_tree().physics_frame


func _check(c: bool, m: String) -> void:
	if c:
		_ok += 1
		print("  ok  ", m)
	else:
		_ko += 1
		print("  KO  ", m)
