extends Node
## Controllo del cielo (segnalazione dell'utente sulla 0.3.21: "che è quella texture grigia sulla parete? sembra un
## glitch", il cielo della scena di prova visto dalla porta di C3). Nel gioco vero, con tutte le porte aperte, lungo la
## strada del capitolo (i tratti di controllo_varchi.gd e quelli in [constant STRADE_IN_PIU]) a ogni [constant PASSO] m
## gli occhi a 1,6 m tirano [constant RAGGI] raggi in tutte le direzioni: uno che non incontra niente entro
## [constant DISTANZA] m (né le collisioni né le mesh vere, CorpiMesh) vede il cielo dell'ambiente, cioè un buco nel
## mondo. Ogni posto da dove si vede il cielo è un caso "da correggere", con dove e verso dove. Non conta il cielo della
## tempesta visto dalla cupola di vetro della sala (i raggi che escono da Sala/Cupola), che è voluto.
## Le fessure sottili (un raggio che esce, ma dei suoi otto vicini a mezzo grado ne escono meno di [constant VICINI],
## cioè una crepa fra due pezzi di un modello che sullo schermo non si vede) si contano a parte, senza fallire.
## Dopo la strada, con la torre caricata come nel gioco (SalaPrincipale._aggiungi_torre, il guscio dietro il portone
## tolto) e costruita del tutto, gli occhi di ogni checkpoint della torre: lì il cielo è un errore dappertutto, tetto
## compreso (i triangoli che mancavano in torre_A li rimette SalaTorre._toppe_torre_A).
## Senza rendering (headless): solo fisica.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/controllo_cielo.gd [solo=<parola>]
##   (solo=: solo i tratti col nome che contiene la parola)

const SCENA := "res://scenes/sala_principale.tscn"
const VARCHI := preload("res://tests/controllo_varchi.gd")
const CorpiMesh := preload("res://tests/corpi_dalle_mesh.gd")
const PASSO := 1.0
const RAGGI := 240
const DISTANZA := 150.0
const OCCHI := 1.6
## Per una fessura vera, quanti degli otto raggi vicini (a mezzo grado) devono uscire anche loro.
const VICINI := 3
## Tratti della strada che non passano da un varco: [nome, punti sul pavimento].
const STRADE_IN_PIU := [
	["risalita: il capannone del fiume, dalla porta all'approdo", [Vector3(-7.6, -5.4, 66.0), Vector3(-20.0, -5.4, 62.0),
			Vector3(-35.0, -5.4, 56.0), Vector3(-35.0, -5.4, 54.0)]],
	["risalita: l'infermeria, dalla porta sud a quella nord", [Vector3(-35.0, -5.4, 46.6), Vector3(-38.8, -5.4, 43.0)]],
]

var _casi: Array = []
var _direzioni: Array[Vector3] = []
var _cupola := 0
var _sottili: Array = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	Engine.set_meta(&"precarica_torre_spento", true)
	Engine.set_meta(&"risalita_subito", true)
	var solo := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("solo="):
			solo = a.substr(5)
	get_tree().change_scene_to_file(SCENA)
	for i in 600:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and get_tree().current_scene:
			break
	var level := get_tree().current_scene as Node3D
	var p := GameState.player
	var cv: Node = VARCHI.new()
	cv.call(&"_apri_tutto", level)
	# la Risalita tutta caricata (fiume, infermeria, stanza delle pozze), come quando ci si arriva
	var ris := level.get_node_or_null(^"Risalita")
	if ris:
		ris.call(&"carica_subito")
		for i in 3000:
			await get_tree().process_frame
			if not bool(ris.call(&"lavori_in_corso")) and ris.get(&"fiume") != null and i > 120:
				break
		print("CIELO: Risalita caricata, fiume %s" % [ris.get(&"fiume")])
	for i in 120:
		await get_tree().physics_frame
	# (la sala resta attiva: un corpo sotto un nodo disattivato esce dalla fisica; il giocatore si sposta su ogni tratto,
	# perché le zone si mostrano col giocatore vicino)
	cv.free()
	# le direzioni: una spirale di Fibonacci sulla sfera
	for i in RAGGI:
		var y := 1.0 - 2.0 * (i + 0.5) / RAGGI
		var r := sqrt(1.0 - y * y)
		var t := PI * (3.0 - sqrt(5.0)) * i
		_direzioni.append(Vector3(cos(t) * r, y, sin(t) * r))
	var strade := []
	for v in VARCHI.VARCHI:
		strade.append([v[0], v[2]])
	strade.append_array(STRADE_IN_PIU)
	var spazio := level.get_world_3d().direct_space_state
	var posti := 0
	var scatole := _scatole(level)
	for s in strade:
		if solo != "" and not String(s[0]).contains(solo):
			continue
		var punti: Array = s[1]
		(p as Player).teleport((punti[0] as Vector3) + Vector3.UP * 0.1)
		for i in 40:
			await get_tree().physics_frame
		var zona := AABB(punti[0], Vector3.ZERO)
		for q in punti:
			zona = zona.expand(q)
		print("CIELO: %s (corpi dalle mesh nuovi %d)" % [s[0], CorpiMesh.crea(level, zona.grow(40.0), p)])
		for i in 3:
			await get_tree().physics_frame
		var cielo_qui := 0
		for k in punti.size() - 1:
			var a: Vector3 = punti[k]
			var b: Vector3 = punti[k + 1]
			var n := maxi(1, int(ceil(a.distance_to(b) / PASSO)))
			for j in n + (1 if k == punti.size() - 2 else 0):
				var occhio := _a_terra(spazio, a.lerp(b, float(j) / n), p) + Vector3.UP * OCCHI
				posti += 1
				if not _posto(s[0], occhio, spazio, scatole, p):
					cielo_qui += 1
		print("CIELO:   posti da dove si vede il cielo: %d" % cielo_qui)
		await get_tree().process_frame
	# la torre, caricata come nel gioco, e gli occhi dei suoi checkpoint
	if solo == "" or "torre".contains(solo):
		var torre: Node3D = null
		if level.has_method(&"_aggiungi_torre"):
			level.call(&"_aggiungi_torre", load(String(level.get(&"sala_torre_scena"))))
			torre = level.get(&"sala_torre") as Node3D
		if torre == null:
			_casi.append("torre: non si carica (da correggere)")
		else:
			# la torre si costruisce a pezzi, un po' per fotogramma: si aspetta che sia finita
			for i in 6000:
				await get_tree().process_frame
				if bool(torre.get(&"costruita")):
					break
			for i in 60:
				await get_tree().physics_frame
			var cps := torre.find_children("*", "Checkpoint", true, false)
			print("CIELO: torre caricata, costruita %s, checkpoint %d, guscio %s" % [torre.get(&"costruita"), cps.size(),
					level.find_child("sala_torre_guscio", true, false) != null])
			for c in cps:
				var occhio: Vector3 = (c as Checkpoint).get_spawn_transform().origin + Vector3.UP * OCCHI
				(p as Player).teleport(occhio + Vector3.DOWN * 1.5)
				for i in 30:
					await get_tree().physics_frame
				CorpiMesh.crea(level, AABB(occhio, Vector3.ZERO).grow(40.0), p)
				for i in 3:
					await get_tree().physics_frame
				scatole = _scatole(level)
				posti += 1
				print("CIELO: torre %s: %s" % [c.name, "ok" if _posto("torre: " + String(c.name), occhio, spazio, scatole, p) else "CIELO"])
			await _porta_bacino(level, torre, spazio, p)
	print("")
	for f in _sottili:
		print("CIELO: fessura sottile (non conta): " + f)
	print("CIELO: posti controllati %d, con il cielo %d; quelli che vedono il cielo dalla cupola di vetro della sala (voluto): %d; fessure sottili %d" % [posti, _casi.size(), _cupola, _sottili.size()])
	for c in _casi:
		printerr("    " + c)
	print("RISULTATO: %s" % ("ok, il cielo non si vede da nessuna parte" if _casi.is_empty() else "FALLITO, %d posti da correggere" % _casi.size()))
	Game.esci(1 if not _casi.is_empty() else 0)


## La porta di servizio in cima alla scaletta del bacino delle condotte (6 novembre, cubo magenta di varchi-cielo): dagli
## occhi di Checkpoint_bacino si vede il vano della porta, e dietro c'è il tunnel del viaggio sottomarino, che la sala
## mette nel livello mentre si è nella torre (SalaPrincipale._precarica_sottomarino). Si aspetta che sia costruito e
## un ventaglio di raggi verso il vano (±8 gradi) non deve uscire: senza il tunnel si vedrebbe il cielo.
func _porta_bacino(level: Node3D, torre: Node3D, spazio: PhysicsDirectSpaceState3D, p: Node) -> void:
	var c := torre.find_child("Checkpoint_bacino", true, false) as Checkpoint
	if c == null:
		_casi.append("condotte: Checkpoint_bacino non c'è (da correggere)")
		return
	var tunnel: Node3D = null
	for i in 9000:
		tunnel = level.get(&"sala_sottomarino") as Node3D
		if tunnel and bool(tunnel.get(&"costruita")):
			break
		await get_tree().process_frame
	if tunnel == null or not bool(tunnel.get(&"costruita")):
		_casi.append("condotte: il tunnel del viaggio sottomarino non è nel livello dopo la torre (da correggere)")
		return
	var occhio: Vector3 = c.get_spawn_transform().origin + Vector3.UP * OCCHI
	(p as Player).teleport(occhio + Vector3.DOWN * 1.5)
	for i in 30:
		await get_tree().physics_frame
	CorpiMesh.crea(level, AABB(occhio, Vector3.ZERO).grow(60.0), p)
	for i in 3:
		await get_tree().physics_frame
	var verso := Vector3(-1.0, 0.35, 0.15).normalized()
	var a := verso.cross(Vector3.UP).normalized()
	var b := a.cross(verso).normalized()
	var fuori := 0
	var n := 0
	for i in range(-4, 5):
		for j in range(-4, 5):
			var d := (verso + a * tan(deg_to_rad(2.0 * i)) + b * tan(deg_to_rad(2.0 * j))).normalized()
			n += 1
			if _esce(spazio, occhio, d, p):
				fuori += 1
	print("CIELO: condotte, dal bacino verso la porta di servizio (tunnel costruito): raggi %d, escono %d" % [n, fuori])
	if fuori > 0:
		_casi.append("condotte: dagli occhi di Checkpoint_bacino in %s si vede il cielo dal vano della porta di servizio con %d raggi su %d (da correggere)" % [
				occhio.snapped(Vector3.ONE * 0.01), fuori, n])



## I raggi da [param occhio]: falso se vede il cielo da un buco (il caso va in _casi). Il cielo dalla cupola di vetro
## e le fessure sottili non contano.
func _posto(nome: String, occhio: Vector3, spazio: PhysicsDirectSpaceState3D, scatole: Array, p: Node) -> bool:
	var fuori: Array[Vector3] = []
	for d in _direzioni:
		if _esce(spazio, occhio, d, p):
			fuori.append(d)
	if fuori.is_empty():
		return true
	# dalla cupola di vetro della sala il cielo della tempesta si vede apposta
	if fuori.any(func(d): return _uscita(scatole, occhio, d).begins_with("Sala/Cupola/")):
		_cupola += 1
	var resto: Array = fuori.filter(func(d): return not _uscita(scatole, occhio, d).begins_with("Sala/Cupola/"))
	# le fessure sottili: pochi vicini escono anche loro
	var veri: Array[Vector3] = []
	for d: Vector3 in resto:
		var a := d.cross(Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT).normalized()
		var b := d.cross(a).normalized()
		var vicini := 0
		for k in 8:
			var ang := TAU * k / 8.0
			var dd := (d + (a * cos(ang) + b * sin(ang)) * tan(deg_to_rad(0.5))).normalized()
			if _esce(spazio, occhio, dd, p):
				vicini += 1
		if vicini >= VICINI:
			veri.append(d)
		else:
			_sottili.append("%s: da %s verso %s (%d vicini su 8), uscendo da %s" % [nome, occhio.snapped(Vector3.ONE * 0.01),
					d.snapped(Vector3.ONE * 0.01), vicini, _uscita(scatole, occhio, d)])
	if veri.is_empty():
		return true
	var media := Vector3.ZERO
	for d in veri:
		media += d
	media = media.normalized()
	var d0: Vector3 = veri[0]
	for d in veri:
		if d.dot(media) > d0.dot(media):
			d0 = d
	_casi.append("%s: dagli occhi in %s si vede il cielo con %d raggi su %d, verso %s, uscendo da %s (da correggere)" % [nome,
			occhio.snapped(Vector3.ONE * 0.01), veri.size(), RAGGI, media.snapped(Vector3.ONE * 0.01), _uscita(scatole, occhio, d0)])
	return false


func _esce(spazio: PhysicsDirectSpaceState3D, occhio: Vector3, d: Vector3, p: Node) -> bool:
	var q := PhysicsRayQueryParameters3D.create(occhio, occhio + d * DISTANZA, 0xFFFFFFFF, [(p as CollisionObject3D).get_rid()])
	q.hit_back_faces = true
	return spazio.intersect_ray(q).is_empty()


func _scatole(level: Node) -> Array:
	var out := []
	for mi in level.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh and m.is_visible_in_tree():
			out.append([m.global_transform * m.get_aabb(), _nome(level, m)])
	return out


## L'ultima scatola di mesh che il raggio attraversa prima di uscire (la più lontana da dove esce), e dove esce.
func _uscita(scatole: Array, da: Vector3, d: Vector3) -> String:
	var fine := da + d * DISTANZA
	var meglio := ""
	var lontano := -1.0
	for sc in scatole:
		var b: AABB = sc[0]
		if b.size.length() > 300.0 or not b.intersects_segment(da, fine):
			continue
		var u: Variant = b.intersects_segment(fine, da)
		var t := da.distance_to(u as Vector3) if u != null else 0.0
		if t > lontano:
			lontano = t
			meglio = "%s (a %.1f m, in %s)" % [sc[1], t, (da + d * t).snapped(Vector3.ONE * 0.1)]
	return meglio if meglio != "" else "niente"


func _nome(radice: Node, n: Node) -> String:
	var pezzi := String(radice.get_path_to(n)).split("/")
	return "/".join(pezzi.slice(0, 4)) + ("/…/" + pezzi[-1] if pezzi.size() > 4 else "")


func _a_terra(spazio: PhysicsDirectSpaceState3D, v: Vector3, p: Node) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(v + Vector3.UP * 0.4, v + Vector3.DOWN * 0.8, 1, [(p as CollisionObject3D).get_rid()])
	var h := spazio.intersect_ray(q)
	return Vector3(v.x, (h.position as Vector3).y, v.z) if not h.is_empty() else v
