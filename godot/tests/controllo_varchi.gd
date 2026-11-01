extends Node
## Controllo dei varchi (richiesta del coordinatore del 23 ottobre: nella build non si entrava più nello stanzino
## degli interni, la porta aperta aveva una collisione a scatola che chiudeva il vano). Lungo la strada del capitolo,
## porta per porta, il corpo vero del giocatore (la forma di player.gd, Player._body_points, da sopra l'altezza dei
## gradini che sale da solo fino alla testa) passa da un lato all'altro di ogni varco a passi di 5 cm; se tocca qualcosa che ferma il giocatore è un
## caso "da correggere", col nome di quello che chiude il passaggio.
## Due giri: la sala com'è all'inizio (i varchi sempre aperti) e con le porte che si aprono durante il gioco aperte
## (tappa 7 col maniglione, saracinesca, serranda, portone della torre, portello della piscina, paratie della camera
## delle onde).
## I varchi sono in [constant VARCHI]: punti in fila sul pavimento, da un lato all'altro della porta.
## Con "margini" non controlla: per ogni varco dice il punto più stretto, dove il corpo passa con meno di
## [constant MARGINE] per lato (e cosa tocca), per le squadre delle zone.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/controllo_varchi.gd [margini]

const SCENA := "res://scenes/sala_principale.tscn"
## Passo della capsula lungo il tratto (m).
const PASSO := 0.05
## Nel modo "margini": lo spazio per lato sotto cui un punto è stretto (m).
const MARGINE := 0.10
## [nome, giro ("inizio": sempre aperto; "aperte": aperto quando le porte del gioco sono aperte), punti]
const VARCHI := [
	["interni: dal corridoio del risveglio agli spogliatoi", "inizio",
		[Vector3(4.3, 0, 39.6), Vector3(-2.9, 0, 39.6), Vector3(-2.9, 0, 37.45)]],
	["interni: dagli spogliatoi allo stanzino del bagnino", "inizio",
		# (arrivando un po' da nord: l'anta aperta, a 165 gradi, sta di sbieco davanti alla metà sud del vano)
		[Vector3(-1.0, 0, 32.85), Vector3(0.6, 0, 32.85), Vector3(1.1, 0, 32.53), Vector3(1.6, 0, 32.5), Vector3(2.5, 0, 32.45)]],
	["interni: dagli spogliatoi al lavapiedi, fino al tornello", "inizio",
		[Vector3(-1.0, 0, 32.45), Vector3(-0.45, 0, 31.2), Vector3(-0.45, 0, 28.5), Vector3(0, 0, 26.6)]],
	["interni: il tornello (sbloccato col getto)", "aperte",
		[Vector3(0, 0, 26.6), Vector3(0, 0, 22.7)]],
	["interni: la saracinesca verso la sala", "aperte",
		[Vector3(0, 0, 22.7), Vector3(0, 0, 18.8)]],
	["sala: dalla saracinesca alla statua", "inizio",
		[Vector3(0, 0, 19.2), Vector3(0, 0, 14.4)]],
	# le paratie si aprono da sole al passaggio del giocatore (Paratia.apri_al_passaggio)
	["tecnici: la camera delle onde, dal pozzo alla sala pompe (i due portali e il vano est)", "aperte",
		[Vector3(0, -9.05, 3.5), Vector3(0, -9.05, 30.5)]],
	["interni: la porta della sala pompe (corridoio)", "aperte",
		[Vector3(7.8, 0, 39.9), Vector3(7.8, 0, 41.9)]],
	["tecnici: la porta del ponte inferiore (sala pompe)", "aperte",
		[Vector3(-1.4, -9.05, 45.6), Vector3(-1.4, -9.05, 49.3)]],
	["risalita: la porta di servizio di C2", "inizio",
		[Vector3(5.1, -1.8, 45.9), Vector3(5.1, -1.8, 49.2)]],
	["risalita: il corridoio fino alla porta del capannone", "inizio",
		[Vector3(-4.9, -5.4, 49.2), Vector3(-4.9, -5.4, 66.0), Vector3(-7.6, -5.4, 66.0)]],
	["risalita: dall'approdo all'infermeria (porta di servizio, porta sud)", "inizio",
		[Vector3(-35.0, -5.4, 54.0), Vector3(-35.0, -5.4, 46.6)]],   # (1 m dentro l'infermeria, prima del carrello)
	["risalita: dalla porta nord dell'infermeria nella stanza delle pozze (si apre col pulsantone)", "aperte",
		[Vector3(-38.8, -5.4, 43.0), Vector3(-38.8, -5.4, 40.9)]],
	# (sulla passerella intorno alle pozze, fino alla porta stagna nel muro nord e sul pianerottolo della scala)
	["risalita: la stanza delle pozze, dalla passerella alla porta stagna (si apre a enigma risolto)", "aperte",
		[Vector3(-38.8, -5.4, 40.9), Vector3(-42.2, -5.4, 40.9), Vector3(-42.2, -5.4, 34.1), Vector3(-40.5, -5.4, 34.1),
		Vector3(-40.5, -5.4, 32.1)]],
	["risalita: dalla cima della scala di servizio alla porta di C3", "inizio",
		[Vector3(-28.6, 0, 32.1), Vector3(-28.6, 0, 38.45), Vector3(-15.4, 0, 38.45)]],
	["raccordo: da C3 al magazzino dei gonfiabili", "inizio",
		[Vector3(-15.4, 0, 38.45), Vector3(-15.3, 0, 37.3), Vector3(-15.0, 0, 36.5), Vector3(-15.0, 0, 29.0)]],
	["raccordo: la serranda del magazzino", "aperte",
		[Vector3(-15.0, 0, 21.8), Vector3(-15.0, 0, 18.8)]],
	["sala: il portone della torre", "aperte",
		[Vector3(18.0, 0, -15.0), Vector3(21.8, 0, -15.0)]],
]

var _passed := 0
var _failed := 0
var _casi: Array = []
var _forma: ConvexPolygonShape3D
var _alto := 1.75
var _alzata := 0.32
var _maschera := 1
var _escludi: Array[RID] = []
var _margini := false
var _stretti: Array = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	Engine.set_meta(&"precarica_torre_spento", true)
	Engine.set_meta(&"risalita_subito", true)
	_margini = OS.get_cmdline_user_args().has("margini")
	for giro in ["inizio", "aperte"]:
		get_tree().change_scene_to_file(SCENA)
		for i in 600:
			await get_tree().process_frame
			if GameState.player and is_instance_valid(GameState.player) and get_tree().current_scene:
				break
		var level := get_tree().current_scene
		_capsula(GameState.player)
		if giro == "aperte":
			_apri_tutto(level)
		for i in 60:
			await get_tree().physics_frame
		# ferma (niente animazioni e niente creature che camminano durante il controllo)
		# (i corpi restano come li ha lasciati il gioco: quelli che ha spento, come il blocco del tornello, spenti)
		var attivi := level.find_children("*", "CollisionObject3D", true, false).filter(func(c): return (c as Node).can_process())
		level.process_mode = Node.PROCESS_MODE_DISABLED
		for c in attivi:
			(c as Node).process_mode = Node.PROCESS_MODE_ALWAYS
		for i in 3:
			await get_tree().physics_frame
		var spazio := (level as Node3D).get_world_3d().direct_space_state
		print("Giro: %s" % giro)
		for v in VARCHI:
			if giro == "inizio" and v[1] != "inizio":
				continue
			_varco(spazio, level, v[0], v[2], giro)
	print("")
	if _margini:
		print("Punti stretti (meno di %d cm per lato):" % roundi(MARGINE * 100.0))
		for st in _stretti:
			print("  STRETTO " + st)
		Game.esci(0)
		return
	if _forma == null:
		_casi.append("la forma del giocatore non si trova")
	if _casi.is_empty():
		_passed += 1
		print("  ok    tutti i varchi si passano con la capsula del giocatore")
	else:
		_failed += 1
		printerr("  FALLITO varchi chiusi: %d (da correggere)" % _casi.size())
		for c in _casi:
			printerr("    " + c)
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	Game.esci(1 if _failed > 0 else 0)


## Il corpo del giocatore in piedi sopra l'altezza dei gradini che sale da solo (le soglie e i gradini bassi non
## contano): la stessa forma, la stessa cima.
func _capsula(p: Player) -> void:
	_escludi = [p.get_rid()]
	_maschera = p.collision_mask
	_alzata = float(p.get(&"step_height"))
	var in_piedi := float(p.get(&"stand_height"))
	_alto = in_piedi - _alzata
	_forma = ConvexPolygonShape3D.new()
	_forma.points = Player._body_points(_alto)


func _apri_tutto(level: Node) -> void:
	for porta in level.find_children("*", "PortaManiglione", true, false):
		porta.call(&"load_state", {"aperta": true, "bloccata": false})
	for portello in level.find_children("*", "HingedHatch", true, false):
		portello.call(&"load_state", {"open": true})
	for porta in level.find_children("*", "PoweredDoor", true, false):
		porta.call(&"load_state", {"latched": true, "open": 1.0, "aperta": true})
	var interni := level.get_node_or_null(^"Interni")
	if interni and interni.has_method(&"load_state"):
		interni.call(&"load_state", {"tornello": true})
	for paratia in level.find_children("*", "Paratia", true, false):
		paratia.call(&"load_state", {"chiusa": false, "aperta": true})
	for portone in level.find_children("*", "PortoneTorre", true, false):
		portone.call(&"load_state", {"aperto": true, "chiuso_dietro": false})
	# la porta stagna della stanza delle pozze si apre a enigma risolto
	var stagna := level.get_node_or_null(^"Risalita/StanzaPozze/PortaStagna")
	if stagna:
		stagna.call(&"apri", true)
	# la porta nord dell'infermeria si apre col pulsantone (25 ottobre)
	var inter := level.get_node_or_null(^"Risalita/Infermeria/Interruttore")
	if inter:
		inter.set(&"powered", true)
	else:
		push_warning("controllo dei varchi: l'interruttore dell'infermeria non c'è ancora")


## Il punto sul pavimento vero sotto (o poco sopra) [param p]: il corpo segue rampe e gradini come il giocatore.
func _a_terra(spazio: PhysicsDirectSpaceState3D, p: Vector3) -> Vector3:
	var r := PhysicsRayQueryParameters3D.create(p + Vector3(0, _alzata + 0.05, 0), p + Vector3(0, -0.6, 0), _maschera, _escludi)
	var h := spazio.intersect_ray(r)
	return Vector3(p.x, (h["position"] as Vector3).y, p.z) if not h.is_empty() else p


## Il punto del varco col margine più piccolo per lato (il corpo allargato di 1 cm alla volta, fino a MARGINE).
func _misura_margini(spazio: PhysicsDirectSpaceState3D, level: Node, nome: String, punti: Array, giro: String,
		q: PhysicsShapeQueryParameters3D, su: Vector3) -> void:
	var forme: Array[ConvexPolygonShape3D] = []
	var passi := roundi(MARGINE * 100.0)
	for cm in passi + 1:
		var f := ConvexPolygonShape3D.new()
		var k := (0.35 + cm * 0.01) / 0.35
		var pts := Player._body_points(_alto)
		for i in pts.size():
			pts[i] = Vector3(pts[i].x * k, pts[i].y, pts[i].z * k)
		f.points = pts
		forme.append(f)
	var peggio := passi + 1
	var dove := Vector3.ZERO
	var verso := Vector3.FORWARD
	var cosa := ""
	for i in punti.size() - 1:
		var a: Vector3 = punti[i]
		var b: Vector3 = punti[i + 1]
		var n := maxi(1, ceili(a.distance_to(b) / PASSO))
		for k in n + 1:
			var p := _a_terra(spazio, a.lerp(b, float(k) / n))
			q.transform = Transform3D(Basis(), p + su)
			for cm in passi + 1:
				q.shape = forme[cm]
				var r := spazio.intersect_shape(q, 1)
				if not r.is_empty():
					if cm < peggio:
						peggio = cm
						dove = p
						verso = (b - a).normalized()
						var chi: Object = r[0]["collider"]
						cosa = String(level.get_path_to(chi)) if chi is Node and level.is_ancestor_of(chi) else str(chi)
						cosa += _dove(spazio, q, p + su)
					break
	q.shape = _forma
	if peggio <= passi:
		var riga := "%s (%s): %d cm per lato a %s, tocca %s; %s" % [nome, giro, maxi(peggio - 1, 0), dove.snapped(Vector3.ONE * 0.01), cosa,
			_larghezza(spazio, dove, verso)]
		_stretti.append(riga)
		print("  stretto %s" % riga)
	else:
		print("  largo   %s" % nome)


## La larghezza libera di traverso al passaggio in [param p] (raggi ai due lati, dai gradini alla testa): la più
## stretta, e quanto il corpo (70 cm) ci sta largo.
func _larghezza(spazio: PhysicsDirectSpaceState3D, p: Vector3, verso: Vector3) -> String:
	var lato := verso.cross(Vector3.UP).normalized()
	var minima := INF
	var quota := 0.0
	for h in [_alzata + 0.05, 0.6, 0.9, 1.2, 1.5, _alzata + _alto - 0.05]:
		var o := p + Vector3(0, h, 0)
		var d := 0.0
		for s in [1.0, -1.0]:
			var r := spazio.intersect_ray(PhysicsRayQueryParameters3D.create(o, o + lato * s * 2.0, _maschera, _escludi))
			d += o.distance_to(r["position"]) if not r.is_empty() else 2.0
		if d < minima:
			minima = d
			quota = h
	return "larghezza libera %.2f m (a %.1f m d'altezza): %d cm per lato se si passa nel mezzo" % [minima, quota, roundi((minima - 0.7) * 50.0)]


## Dove il corpo tocca: il punto di contatto (rest_info), per trovare il pezzo nella collisione unita della stanza.
func _dove(spazio: PhysicsDirectSpaceState3D, q: PhysicsShapeQueryParameters3D, centro: Vector3) -> String:
	var info := spazio.get_rest_info(q)
	if info.is_empty():
		return ""
	return " (contatto in %s)" % (info["point"] as Vector3).snapped(Vector3.ONE * 0.01)


## La capsula lungo i punti, a passi: il primo ostacolo che ferma il giocatore.
func _varco(spazio: PhysicsDirectSpaceState3D, level: Node, nome: String, punti: Array, giro: String) -> void:
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _forma
	q.collision_mask = _maschera
	q.exclude = _escludi
	q.collide_with_areas = false
	var su := Vector3(0, _alzata + _alto * 0.5 + 0.01, 0)
	if _margini:
		_misura_margini(spazio, level, nome, punti, giro, q, su)
		return
	for i in punti.size() - 1:
		var a: Vector3 = punti[i]
		var b: Vector3 = punti[i + 1]
		var n := maxi(1, ceili(a.distance_to(b) / PASSO))
		for k in n + 1:
			var p := _a_terra(spazio, a.lerp(b, float(k) / n))
			q.transform = Transform3D(Basis(), p + su)
			var r := spazio.intersect_shape(q, 4)
			if not r.is_empty():
				var chi: Object = r[0]["collider"]
				var cosa := String(level.get_path_to(chi)) if chi is Node and level.is_ancestor_of(chi) else str(chi)
				var dove := _dove(spazio, q, p + su)
				cosa += dove
				_casi.append("%s (%s): chiuso a %s da %s" % [nome, giro, p.snapped(Vector3.ONE * 0.01), cosa])
				print("  CHIUSO %s: a %s, %s" % [nome, p.snapped(Vector3.ONE * 0.01), cosa])
				return
	print("  ok    %s" % nome)
