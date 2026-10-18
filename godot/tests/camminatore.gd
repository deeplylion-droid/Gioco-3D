extends RefCounted
## Chi cammina sulle pedane della sala della torre (per test_torre e per il video della discesa): trova la
## strada con un A* su una griglia di 25 cm dentro le pedane (torre_gioco.json: "pedane"), lontano dai nuclei
## dei tralicci, dai prop, dagli imbuti degli imbocchi e dagli altri ostacoli ("ostacoli"), e ci porta il
## Player premendo avanti. Con `salta` scavalca col salto quello che lo blocca (come chi gioca); senza, se si
## blocca la camminata fallisce. Coordinate di Godot fuori, di Blender dentro.

## Centri dei tralicci (coordinate di Blender, da torre_a.centro) e mezzo lato della scatola del nucleo.
const TRALICCI := [[25.34, 20.66], [36.66, 20.66], [36.66, 9.34], [25.34, 9.34]]
const NUCLEO := 1.15
const PASSO := 0.25

var torre: SalaTorre
var p: Player
var nodo: Node                 ## per aspettare i passi della fisica
## Mezza larghezza libera richiesta (0,5 = un passaggio di 1 m).
var margine := 0.3
## I prop contano come ostacoli (senza, si scavalcano col salto).
var con_prop := true
var salta := false
var stampa := false
var ultima_dir := Vector3.ZERO


func _init(t: SalaTorre, pl: Player, n: Node) -> void:
	torre = t
	p = pl
	nodo = n


## Cammina fino a w (Godot). Vero se ci arriva.
func verso(w: Vector3, tolleranza := 0.2) -> bool:
	for tentativo in 4:
		var giro := percorso(p.global_position, w)
		if giro.is_empty():
			if stampa:
				print("    nessuna strada da %s a %s" % [p.global_position, w])
			return false
		var ok := true
		for q in giro:
			if not await cammina(q, tolleranza if q == w else 0.35):
				ok = false
				break
		if ok:
			return true
		if not salta:
			return false
		if ultima_dir.length() > 0.1:
			await cammina(p.global_position - ultima_dir * 0.8)
	return false


## La strada da a a w (Godot) sulle pedane alla quota di w: punti ogni metro circa, poi w. Vuota se non c'è.
func percorso(a: Vector3, w: Vector3) -> Array[Vector3]:
	var quota := w.y
	var ped: Array = []
	for r in torre.dati.get("pedane", []):
		if absf(r[4] - quota) < 0.5:
			ped.append(r)
	if ped.is_empty():
		return [w]
	var ostacoli := []      # [x, y, mezzo lato x, mezzo lato y] in Blender
	for t in TRALICCI:
		ostacoli.append([t[0], t[1], NUCLEO, NUCLEO])
	if con_prop:
		for n in torre.find_children("prop_*", "Node3D", true, false):
			var q := (n as Node3D).global_position
			if absf(q.y - quota) < 1.0 and not String(n.name).contains("conv"):
				ostacoli.append([q.x, -q.z, 0.4, 0.4])
	for o in torre.dati.get("ostacoli", []):
		if absf(o[2] - quota) < 0.5:
			ostacoli.append([o[0], o[1], o[3] * 0.6, o[3] * 0.6])
	var x0 := INF
	var y0 := INF
	var x1 := -INF
	var y1 := -INF
	for r in ped:
		x0 = minf(x0, r[0]); y0 = minf(y0, r[1]); x1 = maxf(x1, r[2]); y1 = maxf(y1, r[3])
	var nx := int((x1 - x0) / PASSO) + 1
	var ny := int((y1 - y0) / PASSO) + 1
	var m := margine
	var su_pedana := func(x: float, y: float) -> bool:
		for r in ped:
			if r[0] - 0.03 < x and x < r[2] + 0.03 and r[1] - 0.03 < y and y < r[3] + 0.03:
				return true
		return false
	var libero := func(x: float, y: float) -> bool:
		# a `margine` dal bordo dell'unione delle pedane (due pedane che si toccano fanno una sola superficie)
		for o in [Vector2(0, 0), Vector2(m, 0), Vector2(-m, 0), Vector2(0, m), Vector2(0, -m),
				Vector2(m, m) * 0.7, Vector2(-m, m) * 0.7, Vector2(m, -m) * 0.7, Vector2(-m, -m) * 0.7]:
			if not su_pedana.call(x + o.x, y + o.y):
				return false
		for o in ostacoli:
			if absf(x - o[0]) < o[2] + m and absf(y - o[1]) < o[3] + m:
				return false
		return true
	var cella := func(x: float, y: float) -> Vector2i:
		return Vector2i(clampi(int(round((x - x0) / PASSO)), 0, nx - 1), clampi(int(round((y - y0) / PASSO)), 0, ny - 1))
	var vicina_libera := func(c: Vector2i) -> Vector2i:
		var migliore := Vector2i(-1, -1)
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
	if s0.x < 0 or s1.x < 0:
		return []
	var aperti := {s0: 0.0}
	var da := {}
	var costo := {s0: 0.0}
	var chiusi := {}
	var trovato := false
	while not aperti.is_empty():
		var cur: Vector2i
		var fm := INF
		for k in aperti:
			var f: float = aperti[k] + Vector2(k - s1).length()
			if f < fm:
				fm = f
				cur = k
		if cur == s1:
			trovato = true
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
	if not trovato:
		if stampa:
			for j in range(ny - 1, -1, -1):
				var riga := ""
				for i in nx:
					var q := Vector2i(i, j)
					riga += "S" if q == s0 else ("W" if q == s1 else ("." if libero.call(x0 + i * PASSO, y0 + j * PASSO) else ("#" if su_pedana.call(x0 + i * PASSO, y0 + j * PASSO) else " ")))
				print("      ", riga)
		return []
	var celle: Array[Vector2i] = []
	var c := s1
	while da.has(c):
		celle.push_front(c)
		c = da[c]
	var out: Array[Vector3] = []
	for i in range(0, celle.size(), 4):
		out.append(Vector3(x0 + celle[i].x * PASSO, quota, -(y0 + celle[i].y * PASSO)))
	out.append(w)
	return out


## Cammina dritto fino a w (Godot). Falso se si blocca (con `salta`, prima prova a scavalcare).
func cammina(w: Vector3, tolleranza := 0.35) -> bool:
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
		await nodo.get_tree().physics_frame
		Input.action_release(&"jump")
		var hv := Vector3(p.velocity.x, 0, p.velocity.z)
		if hv.length() > 1.0:
			ultima_dir = hv.normalized()
		if i % 30 == 29:
			fermo = fermo + 1 if p.global_position.distance_to(prima) < 0.3 else 0
			prima = p.global_position
			if fermo >= 1 and salta:
				Input.action_press(&"jump")
			if fermo >= (3 if salta else 2):
				if stampa:
					var tocca := ""
					for c in p.get_slide_collision_count():
						var cn := p.get_slide_collision(c).get_collider() as Node
						tocca += "%s/%s " % [cn.get_parent().name, cn.name]
					print("    bloccato verso %s a %s (tocca %s)" % [w, p.global_position, tocca])
				break
	Input.action_release(&"move_forward")
	Input.action_release(&"jump")
	return false
