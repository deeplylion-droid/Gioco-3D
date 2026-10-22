extends Node
## Video della discesa completa della sala della torre in prima persona, col Player vero (movimento di
## grafica): dal portone si cammina sulla passerella e sulla pedana fino al primo canale e si scivola; tra un
## tratto e l'altro uno stacco in dissolvenza porta all'imbocco dopo; nei due salti col getto si punta la
## lancia in basso e si spruzza (lo spruzzo si vede); in fondo, nella vasca, si guarda il pozzo.
## La camera è quella del Player e guarda dove si va. Un controllo segnala i momenti in cui quasi tutto quello
## che si vede (4 raggi su 5) è a meno di 1,2 m (travi, tubi, muri): nel video non ce ne devono essere.
## Con --write-movie Godot salva i fotogrammi (AVI MJPEG); senza schermo è una prova veloce del percorso.
## Uso (video): xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan
##   --resolution 1280x720 --write-movie <cartella>/discesa.avi --fixed-fps 24
##   --script res://tests/run.gd -- res://proposte/torre/video_discesa.gd
## Uso (prova): godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://proposte/torre/video_discesa.gd

const TORRE := "res://scenes/sala/torre/sala_torre.tscn"
const Camminatore := preload("res://tests/camminatore.gd")
## Dal portone: passerella e pianerottolo della scala fino alla pedana della torre NO (coordinate di Blender).
const PASSERELLA := [[21.3, 16.9], [21.6, 18.25], [23.0, 18.4]]
## Inclinazione della lancia nei salti col getto (gradi, in giù).
const PITCH_GETTO := -65.0
## Se quasi tutto quello che si vede è più vicino di così, la camera è "contro" qualcosa (m).
const VICINO := 1.2

var torre: SalaTorre
var p: Player
var cam
var finito := false
var prova := false
var velo: ColorRect
var _t := 0.0
var _vicino_da := -1.0
var vicini: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	prova = DisplayServer.get_name() == "headless"
	torre = (load(TORRE) as PackedScene).instantiate()
	torre.crea_luci = not prova
	torre.caduta_mortale = 1000.0     # niente ripartenze: se si cade, la prova lo dice
	get_tree().root.add_child(torre)
	for z in torre.find_children("CadutaFondo*", "KillZone", false, false):
		z.queue_free()
	torre.discesa_finita.connect(func(): finito = true)
	if not prova:
		var env := WorldEnvironment.new()
		env.environment = (load("res://addons/grafica/sala/ambiente_sala.tres") as Environment).duplicate()
		env.environment.sdfgi_enabled = true
		env.environment.sdfgi_cascades = 3
		env.environment.volumetric_fog_density = 0.012
		env.environment.ambient_light_energy = 1.0
		env.camera_attributes = load("res://addons/grafica/sala/attributi_camera_sala.tres")
		get_tree().root.add_child(env)
	var strato := CanvasLayer.new()
	strato.layer = 50
	get_tree().root.add_child(strato)
	velo = ColorRect.new()
	velo.color = Color(0, 0, 0, 1)
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strato.add_child(velo)
	p = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(p)
	cam = Camminatore.new(torre, p, self)
	cam.salta = true
	cam.stampa = prova
	var cp0 := torre.checkpoint[0]
	var spawn := cp0.get_node("Ripartenza") as Node3D
	p.global_position = (spawn.global_position if spawn else cp0.global_position) + Vector3(0, 0.1, 0)
	await _frames(4)
	if p.water_pack:
		p.water_pack.set_equipped(true, false)
		p.water_pack.set_tank_amount(20.0)
	var primo := SalaTorre.b([PASSERELLA[0][0], PASSERELLA[0][1], 0.0]) - p.global_position
	p.set_look(atan2(-primo.x, -primo.z), deg_to_rad(-6.0))
	await _frames(10)
	await _dissolvi(0.0)
	await _frames(20)
	# dal portone al primo canale
	for w in PASSERELLA:
		await cam.cammina(SalaTorre.b([w[0], w[1], 0.0]))
	await cam.verso(SalaTorre.b(torre.dati["tratti"][0]["entrata"]), 0.25)
	var t0 := Time.get_ticks_msec()
	for k in range(torre.dati["tratti"].size()):
		var tr: Dictionary = torre.dati["tratti"][k]
		if k > 0:
			# stacco in dissolvenza fino all'imbocco del canale dopo (la camminata sulla pedana non si vede)
			await _dissolvi(1.0)
			p.global_position = SalaTorre.b(tr["entrata"]) + Vector3(0, 0.05, 0)
			p.velocity = Vector3.ZERO
			var v := SalaTorre.b(tr["verso"])
			p.set_look(atan2(-v.x, -v.z), deg_to_rad(-12.0))
			await _frames(6)
			await _dissolvi(0.0)
		var esito := await _scendi(k)
		print("tratto %d: %s (%.0f s di calcolo)" % [k, esito, (Time.get_ticks_msec() - t0) / 1000.0])
		if esito != "arrivato":
			break
	await _guarda_il_pozzo()
	await _dissolvi(1.0)
	print("durata del video: %.1f s" % _t)
	print("camera troppo vicina a qualcosa: %s" % ("mai" if vicini.is_empty() else ", ".join(vicini)))
	get_tree().quit(0)


func _physics_process(delta: float) -> void:
	if p == null or not is_instance_valid(p):
		return
	_t += delta
	# la camera non deve stare contro travi, tubi o muri (solo quando si vede, senza il velo nero)
	var c := get_viewport().get_camera_3d()
	if c == null or velo.color.a > 0.5:
		return
	var colpiti := 0
	var nomi := ""
	for d in [Vector2(0, 0), Vector2(15, 0), Vector2(-15, 0), Vector2(0, 12), Vector2(0, -12)]:
		var dir := c.global_basis * (Basis.from_euler(Vector3(deg_to_rad(d.y), deg_to_rad(d.x), 0)) * Vector3.FORWARD)
		var q := PhysicsRayQueryParameters3D.create(c.global_position, c.global_position + dir * VICINO)
		q.exclude = [p.get_rid()]
		var h := get_viewport().world_3d.direct_space_state.intersect_ray(q)
		if not h.is_empty():
			colpiti += 1
			nomi = "%s/%s a %.2f m" % [(h["collider"] as Node).get_parent().name, (h["collider"] as Node).name, c.global_position.distance_to(h["position"])]
	var hit := colpiti >= 4
	if hit and _vicino_da < 0.0:
		_vicino_da = _t
		if prova:
			print("    camera contro %s a %.1f s (pos %s)" % [nomi, _t, p.global_position])
	elif not hit and _vicino_da >= 0.0:
		if _t - _vicino_da > 0.15:
			vicini.append("%.1f-%.1f s" % [_vicino_da, _t])
		_vicino_da = -1.0


## Scende il tratto k: avanti finché si è dentro il canale e si scivola, poi si lascia fare; la camera guarda
## lungo il canale e poi dove si va; nei tratti che finiscono col getto si spruzza in basso dagli ultimi metri
## del canale e si smette sopra la pedana d'arrivo.
func _scendi(k: int) -> String:
	var tr: Dictionary = torre.dati["tratti"][k]
	var dopo := torre.checkpoint[k + 1]
	var salti: Array = tr["salti"]
	var fine_getto: bool = salti.size() > 0 and salti[-1] == "getto" and (tr["pezzi"] as Array).size() == salti.size()
	var decollo := SalaTorre.b(tr["a"])
	var avanti := SalaTorre.b(tr["verso"])
	for i in 20:
		p.set_look(lerp_angle(p.yaw, atan2(-avanti.x, -avanti.z), 0.2), lerpf(p.pitch, deg_to_rad(-12.0), 0.15))
		await _frames(1)
	Input.action_press(&"move_forward")
	var getto := false
	var in_aria := false
	var seguito := false        # la camera segue la velocità solo quando si va davvero (non all'imbocco)
	for i in 60 * 40:
		await _frames(1)
		var hv := Vector3(p.velocity.x, 0, p.velocity.z)
		if Input.is_action_pressed(&"move_forward") and (p.slide_launched or (p.is_sliding and hv.length() > 2.5 and _dentro(tr, p.global_position) > 0.5)):
			Input.action_release(&"move_forward")
		var pitch_voluto := deg_to_rad(PITCH_GETTO) if getto else deg_to_rad(-14.0)
		if not seguito and (p.slide_launched or (p.is_sliding and hv.length() > 4.0)):
			seguito = true
		var lungo := _lungo_il_canale(tr, p.global_position)
		var yaw_voluto := atan2(-lungo.x, -lungo.z) if lungo != Vector3.ZERO else atan2(-avanti.x, -avanti.z)
		if seguito and hv.length() > 1.0:
			yaw_voluto = atan2(-hv.x, -hv.z)
		if k + 1 == torre.dati["tratti"].size() and in_aria:
			# l'ultimo volo va verso il muro est (e la bocca del tubo dell'inseguimento): si guarda il pozzo
			var pz := SalaTorre.b(torre.dati["pozzo"]) - p.global_position
			yaw_voluto = atan2(-pz.x, -pz.z)
			pitch_voluto = deg_to_rad(-20.0)
		p.set_look(lerp_angle(p.yaw, yaw_voluto, 0.08), lerpf(p.pitch, pitch_voluto, 0.25 if getto else 0.08))
		# lo spruzzo verso il basso parte negli ultimi metri del canale (la carica si fa scivolando)
		if fine_getto and not getto and p.is_sliding and Vector2(p.global_position.x - decollo.x, p.global_position.z - decollo.z).length() < 3.0:
			getto = true
			p.set_look(p.yaw, deg_to_rad(PITCH_GETTO))
			Input.action_press(&"spray")
		if p.slide_launched and not in_aria and hv.length() > 1.5:
			in_aria = true
		if getto and in_aria and Input.is_action_pressed(&"spray") \
				and Vector2(p.global_position.x - dopo.global_position.x, p.global_position.z - dopo.global_position.z).length() < 2.6:
			Input.action_release(&"spray")
		elif in_aria and (p.is_sliding or p.is_on_floor()):
			in_aria = false
			if getto:
				Input.action_release(&"spray")
				getto = false
		if finito:
			Input.action_release(&"spray")
			Input.action_release(&"move_forward")
			return "arrivato"
		if p.global_position.y < dopo.global_position.y - 3.0:
			Input.action_release(&"spray")
			return "CADUTO a %s" % p.global_position
		if p.global_position.distance_to(dopo.global_position) < 4.5 and absf(p.global_position.y - dopo.global_position.y) < 0.6 \
				and not p.is_sliding and p.is_on_floor():
			Input.action_release(&"spray")
			Input.action_release(&"move_forward")
			# arrivati: ci si gira verso l'imbocco del tratto dopo (non contro la ringhiera o il traliccio)
			var prossimo: Vector3 = SalaTorre.b(torre.dati["tratti"][k + 1]["entrata"]) if k + 1 < torre.dati["tratti"].size() else dopo.global_position
			var d := prossimo - p.global_position
			for j in 24:
				p.set_look(lerp_angle(p.yaw, atan2(-d.x, -d.z), 0.15), lerpf(p.pitch, deg_to_rad(-10.0), 0.15))
				await _frames(1)
			return "arrivato"
	Input.action_release(&"move_forward")
	Input.action_release(&"spray")
	return "tempo scaduto"


## In fondo, nella vasca: ci si gira verso il pozzo, scegliendo la direzione libera più vicina a quella
## del pozzo (niente tubi a un palmo dalla camera), e si guarda un po' in su, verso la torre.
func _guarda_il_pozzo() -> void:
	var pozzo := SalaTorre.b(torre.dati["pozzo"])
	# qualche passo nella vasca verso il pozzo, lontano dalla bocca del tubo sul muro est
	var r: Array = torre.dati["vasca_fondo"]["rett"]
	var dentro := SalaTorre.b([float(r[0]) + 0.7, clampf(-p.global_position.z, float(r[1]) + 0.7, float(r[3]) - 0.7), 0.0])
	dentro.y = p.global_position.y
	await cam.cammina(dentro, 0.3)
	var occhio := p.global_position + Vector3(0, 1.6, 0)
	var verso := atan2(-(pozzo.x - occhio.x), -(pozzo.z - occhio.z))
	var migliore := verso
	for scarto in [0.0, 10.0, -10.0, 20.0, -20.0, 30.0, -30.0, 45.0, -45.0]:
		var y := verso + deg_to_rad(scarto)
		var dir := Vector3(-sin(y), 0.15, -cos(y)).normalized()
		var q := PhysicsRayQueryParameters3D.create(occhio, occhio + dir * 6.0)
		q.exclude = [p.get_rid()]
		if get_viewport().world_3d.direct_space_state.intersect_ray(q).is_empty():
			migliore = y
			break
	for i in 90:
		p.set_look(lerp_angle(p.yaw, migliore, 0.06), lerpf(p.pitch, deg_to_rad(0.0), 0.05))
		await _frames(1)
	await _frames(50)


## Dissolvenza al nero (1) o dal nero (0) in mezzo secondo.
func _dissolvi(a: float) -> void:
	var da := velo.color.a
	for i in 30:
		velo.color.a = lerpf(da, a, (i + 1) / 30.0)
		await _frames(1)


## Quanti metri si è già dentro il canale del tratto (negativo prima dell'imbocco).
func _dentro(tr: Dictionary, pos: Vector3) -> float:
	var a := SalaTorre.b(tr["linee"][0][0])
	var c := SalaTorre.b(tr["linee"][0][1])
	var t := Vector3(c.x - a.x, 0, c.z - a.z).normalized()
	return Vector3(pos.x - a.x, 0, pos.z - a.z).dot(t)


## La direzione del canale del tratto nel punto più vicino (zero se si è lontani dal canale).
func _lungo_il_canale(tr: Dictionary, pos: Vector3) -> Vector3:
	var migliore := Vector3.ZERO
	var dm := 2.5
	for ln in tr["linee"]:
		for i in (ln as Array).size() - 1:
			var a := SalaTorre.b(ln[i])
			var c := SalaTorre.b(ln[i + 1])
			var d := Vector2(pos.x - a.x, pos.z - a.z).length()
			if d < dm:
				dm = d
				migliore = Vector3(c.x - a.x, 0, c.z - a.z).normalized()
	return migliore


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
