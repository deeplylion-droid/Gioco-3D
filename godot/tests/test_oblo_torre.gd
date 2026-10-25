extends Node
## Test dell'oblò con lei nel muro est della torre (ObloLei, accanto alla bocca del tubo), col giocatore vero:
## 1. l'oblò sta nel foro del muro (torre_gioco.json, oblo_lei), lontano dalla bocca del tubo, e dal pavimento si vede;
## 2. al buio, col giocatore al fondo che guarda altrove, lei compare (una volta); guardandola, la vede;
## 3. entrando nella bocca del tubo (parte l'inseguimento) lei se ne va col suo distacco lento e non torna più, anche
##    tornando al fondo e girandosi;
## 4. nessuna compenetrazione: la pelle di lei (tutti i vertici nella posa del momento, come in test_oblo_lei.gd di
##    enigmi) resta dentro la cisterna e dietro il vetro dalla comparsa alla fine del distacco (la posa "occhio" sta a
##    1-2 mm dal vetro).
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_oblo_torre.gd

const PLAYER := "res://scenes/player/player.tscn"

## La pelle di lei: misurata ogni [constant OGNI_PELLE] aggiornamenti dello scheletro (come test_oblo_lei.gd).
const OGNI_PELLE := 5
var _pelle_max := -INF
var _pelle_dove := ""
var _pelle_volte := 0
var _pelle_conta := 0
var _pelle_per_stato := {}
var _array_mesh := {}
var _oblo_misurato: ObloLei
var _fotogrammi_lei := 0
var _lei_vista: Node = null
var _passed := 0
var _failed := 0


func _ready() -> void:
	_run.call_deferred()
	get_tree().create_timer(600.0, true, false, true).timeout.connect(func():
		printerr("  FALLITO tempo scaduto")
		_failed += 1
		_fine())


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
		print("  ok    ", what)
	else:
		_failed += 1
		printerr("  FALLITO ", what)


func _fine() -> void:
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## Il punto di [param punti] (nel mondo) più fuori dalla vasca dell'oblò: [metri oltre l'interno (negativo: dentro),
## indice, dove nel sistema dell'oblò (testo)].
func _fuori_punti(o: ObloLei, punti: PackedVector3Array) -> Array:
	var peggio := -INF
	var i_peggio := -1
	var lq_peggio := Vector3.ZERO
	var l := o.vasca_larga * 0.5
	var h := o.piastra * 0.5
	var z1 := -o.spessore_muro - ObloLei.STACCO_VASCA - o.vasca_fonda
	for i in punti.size():
		var lq := o.to_local(punti[i])
		# davanti: il vetro (dalla parte dell'acqua) dentro la piastra, la faccia della vasca fuori
		var z0 := -o.spessore_muro if absf(lq.x) < h and absf(lq.y) < h else -o.spessore_muro - ObloLei.STACCO_VASCA
		# (dentro uno qualunque dei pezzi della vasca)
		var f := INF
		for r in o.pezzi_vasca():
			f = minf(f, maxf(maxf(maxf(float(r[0]) - lq.x, lq.x - float(r[1])), lq.z - z0), maxf(z1 - lq.z, maxf(float(r[2]) - lq.y, lq.y - float(r[3])))))
		if f > peggio:
			peggio = f
			i_peggio = i
			lq_peggio = lq
	return [peggio, i_peggio, "(%.3f, %.3f, %.3f)" % [lq_peggio.x, lq_peggio.y, lq_peggio.z]]


## La pelle di lei nella posa del momento, coi modificatori dello scheletro (i tentacoli morbidi): si misura appena lo
## scheletro si è aggiornato, con lo skinning fatto qui (senza schermo bake_mesh_from_current_skeleton_pose non va;
## come nel controllo di posizionamento).
func _pelle(sk: Skeleton3D, o: ObloLei) -> void:
	_pelle_conta += 1
	if _pelle_conta % OGNI_PELLE != 0 or _fotogrammi_lei <= 3 or o != _oblo_misurato or o.lei == null:
		return
	for n in o.lei.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or mi.skin == null or not mi.is_visible_in_tree() or mi.get_node_or_null(mi.skeleton) != sk:
			continue
		var ossa: Array[Transform3D] = []
		for b in mi.skin.get_bind_count():
			var osso := mi.skin.get_bind_bone(b)
			if osso < 0:
				osso = sk.find_bone(mi.skin.get_bind_name(b))
			ossa.append(sk.global_transform * (sk.get_bone_global_pose(osso) if osso >= 0 else Transform3D()) * mi.skin.get_bind_pose(b))
		for si in mi.mesh.get_surface_count():
			var chiave := [mi.mesh, si]
			if not _array_mesh.has(chiave):
				_array_mesh[chiave] = mi.mesh.surface_get_arrays(si)
			var arr: Array = _array_mesh[chiave]
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var ix = arr[Mesh.ARRAY_BONES]
			var w = arr[Mesh.ARRAY_WEIGHTS]
			if ix == null or w == null or (ix as PackedInt32Array).is_empty():
				continue
			var per := (ix as PackedInt32Array).size() / v.size()
			var punti := PackedVector3Array()
			punti.resize(v.size())
			for k in v.size():
				var q := Vector3.ZERO
				for j in per:
					var peso: float = w[k * per + j]
					if peso > 0.0:
						q += (ossa[ix[k * per + j]] * v[k]) * peso
				punti[k] = q
			var r := _fuori_punti(o, punti)
			_pelle_per_stato[o.stato] = maxf(_pelle_per_stato.get(o.stato, -INF), r[0])
			if r[0] > _pelle_max:
				_pelle_max = r[0]
				var ap := o.lei._ap
				_pelle_dove = "%s, vertice %d in %s, stato %d, %s a %.2f s" % [mi.name, r[1], r[2], o.stato,
						ap.current_animation if ap else "", ap.current_animation_position if ap else 0.0]
	_pelle_volte += 1


## Lei appena compare: ogni aggiornamento del suo scheletro misura la pelle (dal terzo fotogramma: nel primo
## l'animazione non ha ancora messo la posa).
func _process(_delta: float) -> void:
	if _oblo_misurato == null:
		return
	if _oblo_misurato.lei != _lei_vista:
		_lei_vista = _oblo_misurato.lei
		_fotogrammi_lei = 0
		if _lei_vista:
			for sk in _lei_vista.find_children("*", "Skeleton3D", true, false):
				(sk as Skeleton3D).skeleton_updated.connect(_pelle.bind(sk, _oblo_misurato))
	_fotogrammi_lei += 1


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.luci = GameState.Luci.PRIMA_DEL_RISVEGLIO
	var torre := (load("res://scenes/sala/torre/sala_torre.tscn") as PackedScene).instantiate() as SalaTorre
	torre.crea_luci = false
	torre.oblo_raggio_vetro = float(OS.get_environment("OBLO_RAGGIO")) if OS.get_environment("OBLO_RAGGIO") != "" else torre.oblo_raggio_vetro
	add_child(torre)
	var p := (load(PLAYER) as PackedScene).instantiate() as Player
	add_child(p)
	await _frames(20)
	var o := torre.oblo
	_oblo_misurato = o

	print("1. Il posto")
	var d: Dictionary = torre.dati["oblo_lei"]
	var centro := SalaTorre.b(d["centro"])
	check(o != null and o.global_position.distance_to(centro) < 0.001 and o.normale().distance_to(Vector3.LEFT) < 0.001,
			"l'oblò sta nel foro del muro est, col vetro verso la sala")
	var bocca := SalaTorre.b([40.0, 17.4, SalaTorre.FONDO_Z + 1.6])
	var mezzo := float(d["lato"]) * 0.5
	# il collare della bocca ha raggio 1,48: fra il bordo della piastra e il collare resta muro
	check(Vector2(bocca.z - centro.z, bocca.y - centro.y).length() - 1.48 - mezzo * sqrt(2.0) > 0.0 or absf(bocca.z - centro.z) - 1.48 - mezzo > 0.5,
			"la piastra non copre la bocca del tubo (%.2f m di muro fra i due)" % (absf(bocca.z - centro.z) - 1.48 - mezzo))
	var lontano := Vector3(35.9, SalaTorre.FONDO_Z, -13.4)
	p.teleport(lontano)
	await _frames(10)
	var spazio := p.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(p.camera.global_position, o.global_transform * Vector3(0, 0, 0.05), Layers.WORLD, [p.get_rid()])
	check(spazio.intersect_ray(q).is_empty(), "dal pavimento, a 4 m, il vetro si vede (niente davanti)")

	print("2. Lei compare")
	await _frames(30)
	check(o.stato == ObloLei.Stato.ATTESA, "prima del buio lei non c'è")
	GameState.luci = GameState.Luci.BLACKOUT
	# guardando via (verso il pozzo) lei compare dietro il vetro
	p.look_at_point(SalaTorre.b(torre.dati["pozzo"]) + Vector3.UP * 1.5)
	await _frames(10)
	check(o.stato == ObloLei.Stato.PRONTA and o.lei != null, "al buio, al fondo, guardando altrove: lei compare dietro il vetro")
	p.look_at_point(centro)
	await _frames(100)
	check(o.stato == ObloLei.Stato.VISTA, "guardandola, il giocatore la vede (lei resta)")

	print("3. L'inseguimento")
	var finita := [false]
	o.finita.connect(func(): finita[0] = true)
	p.teleport(SalaTorre.b([38.8, 17.4, SalaTorre.FONDO_Z + 1.0]))
	await _frames(5)
	check(o.stato == ObloLei.Stato.VIA and not o.attivo, "entrando nella bocca del tubo lei se ne va (distacco lento)")
	for i in 600:
		if finita[0]:
			break
		await get_tree().process_frame
	check(finita[0] and o.lei == null, "dopo il distacco l'oblò resta vuoto")
	check(_pelle_volte > 0 and _pelle_max <= 0.0, "posa %s: la pelle di lei sempre dentro la cisterna e dietro il vetro, dalla comparsa al distacco (%d misure, peggio %.3f m: %s; per stato %s)" % [o.posa, _pelle_volte, _pelle_max, _pelle_dove, _pelle_per_stato])
	p.teleport(lontano)
	await _frames(5)
	p.look_at_point(SalaTorre.b(torre.dati["pozzo"]) + Vector3.UP * 1.5)
	await _frames(30)
	p.look_at_point(centro)
	await _frames(30)
	check(o.stato == ObloLei.Stato.FINITA and o.lei == null, "tornando al fondo lei non ricompare")
	check(bool(o.save_state().get("finito", false)), "lo stato si salva coi checkpoint (finito)")
	_fine()
