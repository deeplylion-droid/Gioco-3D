extends Node
## Video della discesa completa della sala della torre in prima persona, col Player vero (movimento di
## grafica): dal portone si cammina sulla passerella fino al primo canale, si scivola; sulle pedane si
## cammina fino al canale dopo; nei due salti col getto si punta la lancia in basso e si spruzza (lo
## spruzzo si vede). La camera è quella del Player: guarda dove si va.
## Con --write-movie Godot salva i fotogrammi (AVI MJPEG); senza, stampa solo il percorso (prova veloce).
## Uso (video): xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan
##   --resolution 1280x720 --write-movie <cartella>/discesa.avi --fixed-fps 30
##   --script res://tests/run.gd -- res://proposte/torre/video_discesa.gd
## Uso (prova): godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://proposte/torre/video_discesa.gd

const TORRE := "res://scenes/sala/torre/sala_torre.tscn"
## Centri dei tralicci (coordinate di Blender, da torre_a.centro) e mezzo lato della scatola del nucleo.
const TRALICCI := [[25.34, 20.66], [36.66, 20.66], [36.66, 9.34], [25.34, 9.34]]
const NUCLEO := 1.35
## Dal portone: passerella, pianerottolo della scala, pedana della torre NO (coordinate di Blender).
const PASSERELLA := [[21.3, 16.9], [21.6, 18.25], [27.2, 18.25]]
## Inclinazione della lancia nei salti col getto (gradi, in giù).
const PITCH_GETTO := -65.0
## Tra un tratto e l'altro uno stacco in dissolvenza invece della camminata sulla pedana.
const STACCHI := true

var torre: SalaTorre
var p: Player
var finito := false
var prova := false
var ultima_dir := Vector3.ZERO
var velo: ColorRect


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	prova = DisplayServer.get_name() == "headless"
	torre = (load(TORRE) as PackedScene).instantiate()
	torre.crea_luci = not prova
	torre.margine_caduta = 1000.0     # niente ripartenze: se si cade, la prova lo dice
	torre.tempo_bloccato = 1000.0
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
	velo.color = Color(0, 0, 0, 0)
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strato.add_child(velo)
	p = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(p)
	var cp0 := torre.checkpoint[0]
	var spawn := cp0.get_node("Ripartenza") as Node3D
	p.global_position = (spawn.global_position if spawn else cp0.global_position) + Vector3(0, 0.1, 0)
	await _frames(4)
	if p.water_pack:
		p.water_pack.set_equipped(true, false)
		p.water_pack.set_tank_amount(20.0)
	var primo := SalaTorre.b([PASSERELLA[0][0], PASSERELLA[0][1], 0.0]) - p.global_position
	p.set_look(atan2(-primo.x, -primo.z), deg_to_rad(-8.0))
	await _frames(45)
	# dal portone al primo canale
	var giro: Array[Vector3] = []
	for w in PASSERELLA:
		giro.append(SalaTorre.b([w[0], w[1], 0.0]))
	for w in giro:
		await _cammina(w)
	var t0 := Time.get_ticks_msec()
	for k in range(torre.dati["tratti"].size()):
		var tr: Dictionary = torre.dati["tratti"][k]
		if k > 0 and STACCHI:
			# stacco in dissolvenza fino all'imbocco del canale dopo (la camminata sulla pedana non si vede)
			await _dissolvi(1.0)
			p.global_position = SalaTorre.b(tr["entrata"]) + Vector3(0, 0.05, 0)
			p.velocity = Vector3.ZERO
			var v := SalaTorre.b(tr["verso"])
			p.set_look(atan2(-v.x, -v.z), deg_to_rad(-12.0))
			await _frames(6)
			await _dissolvi(0.0)
		else:
			if k > 0 and ultima_dir.length() > 0.1 and p.global_position.y - torre.checkpoint[k].global_position.y > 0.08:
				# fuori dalla fine del canale d'arrivo, prima di girarsi
				await _cammina(p.global_position + ultima_dir * 1.5)
			await _verso_entrata(SalaTorre.b(tr["entrata"]))
		if prova:
			print("  all'entrata %d: %s (voluta %s)" % [k, p.global_position, SalaTorre.b(tr["entrata"])])
		var esito := await _scendi(k)
		if prova:
			print("  arrivo %d a %s (blender %.2f, %.2f, %.2f)" % [k, p.global_position, p.global_position.x, -p.global_position.z, p.global_position.y])
		print("tratto %d: %s (%.0f s di calcolo)" % [k, esito, (Time.get_ticks_msec() - t0) / 1000.0])
		if esito != "arrivato":
			break
	# in fondo: ci si gira verso il pozzo in mezzo alla sala e si guarda su, verso la torre
	var pozzo := SalaTorre.b(torre.dati["pozzo"])
	var verso_pozzo := pozzo - p.global_position
	for i in 75:
		p.set_look(lerp_angle(p.yaw, atan2(-verso_pozzo.x, -verso_pozzo.z), 0.06), lerpf(p.pitch, deg_to_rad(18.0), 0.05))
		await _frames(1)
	await _frames(45)
	print("durata della discesa: %.1f s" % (Engine.get_physics_frames() / float(Engine.physics_ticks_per_second)))
	get_tree().quit(0)


## Cammina fino a w girando attorno ai tralicci (passando per gli angoli delle pedane).
func _verso_entrata(w: Vector3) -> void:
	# se ci si blocca (un tubo, un prop), un passo indietro e si ricalcola
	for tentativo in 4:
		var ok := true
		var giro := _giro(p.global_position, w)
		if prova:
			var t := ""
			for q in giro:
				t += "(%.1f, %.1f) " % [q.x, -q.z]
			print("    giro da (%.1f, %.1f): %s" % [p.global_position.x, -p.global_position.z, t])
		for q in giro:
			if not await _cammina(q, 0.2 if q == w else 0.35):
				ok = false
				break
		if ok:
			return
		if ultima_dir.length() > 0.1:
			await _cammina(p.global_position - ultima_dir * 0.8)


## Percorso a piedi sulla pedana (A* su una griglia di 25 cm, in coordinate di Blender): si sta dentro la
## pedana e lontano dai nuclei dei tralicci, dai prop, dalle bocche chiuse dei decorativi e dalla vasca.
func _giro(a: Vector3, w: Vector3) -> Array[Vector3]:
	var quota := w.y
	var ped: Array = []
	for r in torre.dati.get("pedane", []):
		if absf(r[4] - quota) < 0.5:
			ped.append(r)
	var ostacoli := []      # [x, y, mezzo lato x, mezzo lato y] in Blender
	for t in TRALICCI:
		ostacoli.append([t[0], t[1], NUCLEO, NUCLEO])
	# (i prop bassi sulle pedane no: chi gioca li scavalca col salto, e così fa anche il video)
	for o in torre.dati.get("ostacoli", []):
		if absf(o[2] - quota) > 0.5:
			continue
		if (o as Array).size() > 5:
			ostacoli.append([o[0], o[1], o[3] if o[5] == "x" else o[4], o[4] if o[5] == "x" else o[3]])
		else:
			ostacoli.append([o[0], o[1], o[3] * 0.6, o[3] * 0.6])
	if ped.is_empty():
		return [w]
	var x0 := INF
	var y0 := INF
	var x1 := -INF
	var y1 := -INF
	for r in ped:
		x0 = minf(x0, r[0]); y0 = minf(y0, r[1]); x1 = maxf(x1, r[2]); y1 = maxf(y1, r[3])
	const PASSO := 0.25
	var nx := int((x1 - x0) / PASSO) + 1
	var ny := int((y1 - y0) / PASSO) + 1
	var su_pedana := func(x: float, y: float) -> bool:
		for r in ped:
			if r[0] - 0.03 < x and x < r[2] + 0.03 and r[1] - 0.03 < y and y < r[3] + 0.03:
				return true
		return false
	var libero := func(x: float, y: float) -> bool:
		# a 35 cm dal bordo dell'unione delle pedane (due pedane che si toccano fanno una sola superficie)
		for o in [Vector2(0, 0), Vector2(0.35, 0), Vector2(-0.35, 0), Vector2(0, 0.35), Vector2(0, -0.35),
				Vector2(0.25, 0.25), Vector2(-0.25, 0.25), Vector2(0.25, -0.25), Vector2(-0.25, -0.25)]:
			if not su_pedana.call(x + o.x, y + o.y):
				return false
		for o in ostacoli:
			if absf(x - o[0]) < o[2] + 0.3 and absf(y - o[1]) < o[3] + 0.3:
				return false
		return true
	var cella := func(x: float, y: float) -> Vector2i:
		return Vector2i(clampi(int(round((x - x0) / PASSO)), 0, nx - 1), clampi(int(round((y - y0) / PASSO)), 0, ny - 1))
	var vicina_libera := func(c: Vector2i) -> Vector2i:
		var migliore := c
		var dm := INF
		for i in range(-8, 9):
			for j in range(-8, 9):
				var q := c + Vector2i(i, j)
				if q.x < 0 or q.y < 0 or q.x >= nx or q.y >= ny:
					continue
				if libero.call(x0 + q.x * PASSO, y0 + q.y * PASSO) and Vector2(i, j).length() < dm:
					dm = Vector2(i, j).length()
					migliore = q
		return migliore
	var s0: Vector2i = vicina_libera.call(cella.call(a.x, -a.z))
	var s1: Vector2i = vicina_libera.call(cella.call(w.x, -w.z))
	var aperti := {s0: 0.0}
	var da := {}
	var costo := {s0: 0.0}
	var chiusi := {}
	while not aperti.is_empty():
		var cur: Vector2i
		var fm := INF
		for k in aperti:
			var f: float = aperti[k] + Vector2(k - s1).length()
			if f < fm:
				fm = f
				cur = k
		if cur == s1:
			break
		aperti.erase(cur)
		chiusi[cur] = true
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
			var q: Vector2i = cur + d
			if q.x < 0 or q.y < 0 or q.x >= nx or q.y >= ny or chiusi.has(q):
				continue
			if not libero.call(x0 + q.x * PASSO, y0 + q.y * PASSO):
				continue
			var g: float = costo[cur] + Vector2(d).length()
			if g < costo.get(q, INF):
				costo[q] = g
				da[q] = cur
				aperti[q] = g
	var celle: Array[Vector2i] = []
	var c := s1
	while da.has(c):
		celle.push_front(c)
		c = da[c]
	var out: Array[Vector3] = []
	# un punto ogni metro circa, poi l'entrata vera
	for i in range(0, celle.size(), 4):
		out.append(Vector3(x0 + celle[i].x * PASSO, quota, -(y0 + celle[i].y * PASSO)))
	out.append(w)
	return out


func _cammina(w: Vector3, tolleranza := 0.35) -> bool:
	var fermo := 0
	var prima := p.global_position
	for i in 60 * 20:
		var d := Vector3(w.x - p.global_position.x, 0, w.z - p.global_position.z)
		if d.length() < tolleranza:
			Input.action_release(&"move_forward")
			Input.action_release(&"jump")
			return true
		var yaw := atan2(-d.x, -d.z)
		p.set_look(lerp_angle(p.yaw, yaw, 0.12), lerpf(p.pitch, deg_to_rad(-8.0), 0.1))
		Input.action_press(&"move_forward")
		await _frames(1)
		Input.action_release(&"jump")
		if i % 30 == 29:
			fermo = fermo + 1 if p.global_position.distance_to(prima) < 0.3 else 0
			prima = p.global_position
			if fermo >= 1:
				Input.action_press(&"jump")     # come farebbe chi gioca: un salto per scavalcare
			if fermo >= 3:
				var sotto := ""
				for c in p.get_slide_collision_count():
					var cn := p.get_slide_collision(c).get_collider() as Node
					sotto += "%s/%s n%s " % [cn.get_parent().name, cn.name, p.get_slide_collision(c).get_normal()]
				print("  bloccato verso ", w, " a ", p.global_position, " tocca ", sotto)
				break
	Input.action_release(&"move_forward")
	Input.action_release(&"jump")
	return false


func _scendi(k: int) -> String:
	var tr: Dictionary = torre.dati["tratti"][k]
	var dopo := torre.checkpoint[k + 1]
	var salti: Array = tr["salti"]
	var fine_getto: bool = salti.size() > 0 and salti[-1] == "getto" and (tr["pezzi"] as Array).size() == salti.size()
	var decollo := SalaTorre.b(tr["a"])
	var avanti := SalaTorre.b(tr["verso"])
	# si gira verso il canale (e si fanno gli ultimi centimetri fino all'entrata: l'imbocco vuole la mira giusta)
	var entrata := SalaTorre.b(tr["entrata"])
	var da := p.global_position
	if Vector2(da.x - entrata.x, da.z - entrata.z).length() > 0.5:
		print("  ATTENZIONE: entrata %d lontana %.1f m" % [k, Vector2(da.x - entrata.x, da.z - entrata.z).length()])
		entrata = da
	for i in 30:
		p.set_look(lerp_angle(p.yaw, atan2(-avanti.x, -avanti.z), 0.2), lerpf(p.pitch, deg_to_rad(-12.0), 0.15))
		var f := smoothstep(0.0, 1.0, (i + 1) / 30.0)
		p.global_position = Vector3(lerpf(da.x, entrata.x, f), p.global_position.y, lerpf(da.z, entrata.z, f))
		p.velocity = Vector3.ZERO
		await _frames(1)
	p.set_look(atan2(-avanti.x, -avanti.z), p.pitch)
	Input.action_press(&"move_forward")
	var getto := false
	var in_aria := false
	var seguito := false        # la camera segue la velocità solo quando si va davvero (non all'imbocco)
	for i in 60 * 40:
		await _frames(1)
		var hv := Vector3(p.velocity.x, 0, p.velocity.z)
		# si tiene premuto avanti guardando lungo il canale finché non si va (come chi gioca), poi si molla
		if Input.is_action_pressed(&"move_forward") and (p.slide_launched or (p.is_sliding and (hv.length() > 4.0 or fine_getto))):
			Input.action_release(&"move_forward")
		if hv.length() > 1.0:
			ultima_dir = hv.normalized()
		# la camera guarda dove si va
		var pitch_voluto := deg_to_rad(PITCH_GETTO) if getto else deg_to_rad(-14.0)
		if not seguito and (p.slide_launched or (p.is_sliding and hv.length() > 4.0)):
			seguito = true
		var lungo := _lungo_il_canale(tr, p.global_position)
		var yaw_voluto := atan2(-lungo.x, -lungo.z) if lungo != Vector3.ZERO else atan2(-avanti.x, -avanti.z)
		if seguito and hv.length() > 1.0:
			yaw_voluto = atan2(-hv.x, -hv.z)
		p.set_look(lerp_angle(p.yaw, yaw_voluto, 0.08), lerpf(p.pitch, pitch_voluto, 0.25 if getto else 0.08))
		# nei salti col getto: lo spruzzo verso il basso parte negli ultimi metri del canale (la carica si fa
		# scivolando) e dura fino all'atterraggio
		if fine_getto and not getto and p.is_sliding and Vector2(p.global_position.x - decollo.x, p.global_position.z - decollo.z).length() < 3.0:
			getto = true
			p.set_look(p.yaw, deg_to_rad(PITCH_GETTO))
			Input.action_press(&"spray")
		if p.slide_launched and not in_aria and hv.length() > 1.5:
			in_aria = true
		# sopra la pedana d'arrivo si lascia lo spruzzo e si scende (chi gioca fa così: non si va oltre)
		if getto and in_aria and Input.is_action_pressed(&"spray") \
				and Vector2(p.global_position.x - dopo.global_position.x, p.global_position.z - dopo.global_position.z).length() < 2.6:
			Input.action_release(&"spray")
		elif in_aria and (p.is_sliding or p.is_on_floor()):
			in_aria = false
			if getto:
				Input.action_release(&"spray")
				getto = false
		if prova and i % 120 == 0:
			print("    %.1f s pos %s v %.1f scivola %s in aria %s" % [i / 60.0, SalaTorre.b([0, 0, 0]) + Vector3(p.global_position.x, p.global_position.y, p.global_position.z), hv.length(), p.is_sliding, p.slide_launched])
		if finito:
			Input.action_release(&"spray")
			return "arrivato"
		if p.global_position.y < dopo.global_position.y - 3.0:
			Input.action_release(&"spray")
			return "CADUTO a %s" % p.global_position
		if p.global_position.distance_to(dopo.global_position) < 4.5 and absf(p.global_position.y - dopo.global_position.y) < 0.6 \
				and not p.is_sliding and p.is_on_floor():
			Input.action_release(&"spray")
			await _frames(20)
			return "arrivato"
	Input.action_release(&"move_forward")
	Input.action_release(&"spray")
	return "tempo scaduto"


## Dissolvenza al nero (1) o dal nero (0) in mezzo secondo.
func _dissolvi(a: float) -> void:
	var da := velo.color.a
	for i in 30:
		velo.color.a = lerpf(da, a, (i + 1) / 30.0)
		await _frames(1)


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
