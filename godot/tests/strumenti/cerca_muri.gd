extends Node
## Strumento (non in CI): i muri più vuoti lungo la strada del giocatore, per gli scarabocchi a pastelli a cera
## (richiesta dell'utente del 28 ottobre: "nei muri più vuoti, di aggiungermi degli scarabocchi a pastelli a cera,
## tratto grosso"). Per ogni scena:
## 1. collisioni temporanee di tutte le mesh visibili (anche i poster e i dettagli senza collisione, come nel controllo di
##    posizionamento);
## 2. dove si cammina: dai checkpoint (e dall'inizio) si allarga una griglia di 0,5 m sul pavimento, con gradini fino a
##    35 cm, 2 m d'aria sopra e niente muri in mezzo;
## 3. dai punti raggiungibili, raggi orizzontali all'altezza degli occhi: i muri colpiti fra 1,5 e 10 m;
## 4. su ogni muro un rettangolo libero (prima 2,4 × 1,4 m, poi 1,6 × 1,0): tutti i raggi di una griglia lo trovano piatto
##    (entro 2 cm), architettura e non oggetti, e nessuna mesh di oggetto, decal, porta, Polaroid, pulsante, poster o
##    indizio entro 0,5 m (1 m per porte, Polaroid, interattivi e indizi);
## 5. il punteggio: da quanti punti della strada si vede di fronte, per la sua area.
## Scrive res://../docs/proposte/scarabocchi/muri.json (zona, centro, normale, misure, mesh, da dove si vede meglio).
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/strumenti/cerca_muri.gd [scena]

const SCENE := ["res://scenes/sala_principale.tscn", "res://scenes/sala/torre/sala_torre.tscn",
		"res://scenes/sala/sottomarino/sala_sottomarino.tscn"]
const USCITA := "res://../docs/proposte/scarabocchi/muri.json"
const STRATO := 1 << 20
const PASSO := 0.5
const OCCHI := 1.6
const ARCHITETTURA := ["architettura", "struttura", "pavimento", "muro", "muri", "parete", "pareti", "soffitto", "cupola"]
## Nomi (nel percorso) di quello che non si copre e da cui si sta lontani: porte, interattivi, poster, indizi.
const NON_TOCCARE := ["porta", "door", "portone", "portello", "saracinesca", "serranda", "tornello", "paratia",
		"polaroid", "pulsante", "button", "leva", "valvola", "poster", "cartellone", "manifesto", "bagnino", "targa",
		"insegna", "disegno", "schema", "tacche", "cassaforte", "cerchi", "lavagna", "negatoscopio", "lettore", "oblo",
		"cartello", "freccia", "monitor", "quadro", "orologio"]
## I materiali (dipinti sul muro o di cose sul muro) da cui si sta lontani 0,6 m: cartelli, indizi, porte, quadri.
const MATERIALI_VIETATI := ["schema", "disegno", "tacche", "poster", "cartell", "manifesto", "cassaforte", "cerchi",
		"quadro", "monitor", "insegna", "targa", "freccia", "lavagna", "porta", "paratia", "tornello", "valvola", "leva",
		"pulsante"]
## I rettangoli che si provano: [larghezza, altezza, altezza del centro sul pavimento].
## (anche bassi, all'altezza dei bambini, dentro la fascia di piastrelle dove sopra c'è l'intonaco)
## La luce minima sul muro (vedi _luce): sotto, al buio, gli scarabocchi non si vedrebbero.
const LUCE_MIN := 0.04
const RETTANGOLI := [[2.4, 1.4, 1.35], [2.4, 1.0, 0.85], [1.6, 1.0, 1.25], [1.6, 0.8, 0.75], [1.2, 0.7, 0.7]]

var _radice: Node
var _corpi := {}           # rid -> MeshInstance3D
var _superfici := {}       # MeshInstance3D -> [triangoli alla fine di ogni superficie]
var _luci: Array = []      # [posizione, energia, portata, Light3D]
var _oggetti_box: Array = []   # [AABB, percorso] delle mesh non architettura
var _vietati: Array = []       # [AABB allargato, motivo]
var _risultati := []
var _diag := {}


func _conta(chiave: String) -> void:
	_diag[chiave] = int(_diag.get(chiave, 0)) + 1


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Engine.set_meta(&"risalita_subito", true)
	var solo := OS.get_cmdline_user_args().slice(1)
	for s in SCENE:
		if not solo.is_empty() and not solo.has(String(s).get_file().get_basename()):
			continue
		await _scena(s)
	var f := FileAccess.open(USCITA, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_risultati, "\t"))
	print("SCRITTO ", ProjectSettings.globalize_path(USCITA), " (", _risultati.size(), " muri)")
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _scena(percorso: String) -> void:
	var t0 := Time.get_ticks_msec()
	GameState.imposta_luci(GameState.Luci.PRIMA_DEL_RISVEGLIO if percorso.ends_with("sala_principale.tscn") else GameState.Luci.BLACKOUT)
	_radice = (load(percorso) as PackedScene).instantiate()
	add_child(_radice)
	await _frames(30)
	if _radice.has_method(&"costruisci"):
		_radice.call(&"costruisci")
		await _frames(10)
	var r := _radice.get_node_or_null(^"Risalita")
	if r:
		r.call(&"carica_subito")
		r.process_mode = Node.PROCESS_MODE_DISABLED
		for nome in ["fiume", "infermeria"]:
			var n = r.get(nome)
			if n is Node3D:
				(n as Node3D).visible = true
		await _frames(10)
	_espandi_multimesh()
	_corpi.clear()
	_oggetti_box.clear()
	_vietati.clear()
	_crea_corpi()
	_segna_vietati()
	_luci.clear()
	for l in _radice.find_children("*", "Light3D", true, false):
		var lu := l as Light3D
		if not lu.is_visible_in_tree() or lu.light_energy <= 0.01 or lu is DirectionalLight3D:
			continue
		var portata: float = (lu as OmniLight3D).omni_range if lu is OmniLight3D else (lu as SpotLight3D).spot_range
		_luci.append([lu.global_position, lu.light_energy, portata, lu])
	await _frames(3)
	var spazio := get_viewport().world_3d.direct_space_state
	var punti := _cammino(spazio)
	print("%s: %d punti dove si cammina (%d ms)" % [percorso.get_file(), punti.size(), Time.get_ticks_msec() - t0])
	for p in punti:
		var hp := _raggio(spazio, (p as Vector3) + Vector3.UP * 0.2, (p as Vector3) + Vector3.DOWN * 0.3)
		if not hp.is_empty() and _corpi.has(hp.rid):
			_conta("punti " + _zona(_corpi[hp.rid]))
	var muri := _candidati(spazio, punti)
	var chiavi := _diag.keys()
	chiavi.sort()
	for k in chiavi:
		print("    DIAG ", k, ": ", _diag[k])
	_diag.clear()
	print("  %d muri vuoti trovati (%d ms)" % [muri.size(), Time.get_ticks_msec() - t0])
	_risultati.append_array(muri)
	_radice.queue_free()
	await _frames(5)


# --- le mesh -------------------------------------------------------------------------------------------------------

func _visibile(n: Node) -> bool:
	while n and n != _radice.get_parent():
		if n is Node3D and not (n as Node3D).visible and not n is Light3D:
			return false
		n = n.get_parent()
	return true


func _espandi_multimesh() -> void:
	for n in _radice.find_children("*", "MultiMeshInstance3D", true, false):
		var mmi := n as MultiMeshInstance3D
		var mm := mmi.multimesh
		if mm == null or mm.mesh == null or not _visibile(mmi):
			continue
		var fonte: Object = mmi if mmi.has_meta(&"trasformazioni") else mm
		if not fonte.has_meta(&"trasformazioni"):
			continue
		var tr: Array = fonte.get_meta(&"trasformazioni")
		for i in tr.size():
			var copia := MeshInstance3D.new()
			copia.name = "%s_%d" % [mmi.name, i]
			copia.mesh = mm.mesh
			copia.transform = mmi.transform * (tr[i] as Transform3D)
			mmi.get_parent().add_child(copia)
		mmi.visible = false


func _architettura(mi: MeshInstance3D) -> bool:
	var p := String(_radice.get_path_to(mi)).to_lower()
	if ARCHITETTURA.any(func(a): return p.contains(a)):
		return true
	var b := mi.global_transform * mi.get_aabb()
	# (i pezzi grandi della sala, dei GLB delle stanze: più di 6 m su due lati; o una lastra di muro: sottile, alta
	# almeno 2 m e larga almeno 2,5)
	var lati := [b.size.x, b.size.y, b.size.z]
	lati.sort()
	# (anche a fasce, come nella Risalita e nell'infermeria: lastre sottili alte almeno 1 m e larghe almeno 1,5; non le
	# tende né i vetri)
	if p.contains("tenda") or p.contains("vetro"):
		return false
	return lati[1] > 6.0 or (lati[0] < 0.35 and b.size.y >= 1.0 and maxf(b.size.x, b.size.z) >= 1.5)


func _crea_corpi() -> void:
	var cont := Node3D.new()
	cont.name = "CorpiMuri"
	_radice.add_child(cont)
	for n in _radice.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or not _visibile(mi) or mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			continue
		var p := String(_radice.get_path_to(mi)).to_lower()
		if p.contains("acqua") or p.contains("water") or p.contains("superficie") or p.contains("lei") or p.contains("medusa"):
			continue
		var facce: PackedVector3Array = mi.mesh.get_faces()
		if facce.is_empty():
			continue
		var fine := []
		var conta := 0
		for si in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(si)
			var idx = arr[Mesh.ARRAY_INDEX]
			conta += ((idx as PackedInt32Array).size() if idx != null and (idx as PackedInt32Array).size() > 0 else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
			fine.append(conta)
		_superfici[mi] = fine
		var forma := ConcavePolygonShape3D.new()
		forma.set_faces(mi.global_transform * facce)
		forma.backface_collision = true
		var c := StaticBody3D.new()
		c.collision_layer = STRATO
		c.collision_mask = 0
		var cs := CollisionShape3D.new()
		cs.shape = forma
		c.add_child(cs)
		cont.add_child(c)
		_corpi[c.get_rid()] = mi
		if not _architettura(mi):
			_oggetti_box.append([mi.global_transform * mi.get_aabb(), String(_radice.get_path_to(mi))])


## Porte, Polaroid, interattivi, poster e indizi: un box allargato di 1 m. Anche le decal (non hanno mesh).
func _segna_vietati() -> void:
	for n in _radice.find_children("*", "Node3D", true, false):
		var p := String(_radice.get_path_to(n)).to_lower()
		var classe := String(n.get_script().get_global_name()) if n.get_script() else n.get_class()
		var vietato := n is Decal or n is Interactable or NON_TOCCARE.any(func(w): return p.get_file().contains(w)) \
				or classe in ["PolaroidPhoto", "Collectible", "Pickup", "WaterButton", "PoweredDoor", "HingedHatch", "Checkpoint"]
		if not vietato or not _visibile(n):
			continue
		var box := AABB((n as Node3D).global_position, Vector3.ZERO)
		for m in [n] + n.find_children("*", "VisualInstance3D", true, false):
			if m is VisualInstance3D:
				box = box.merge((m as VisualInstance3D).global_transform * (m as VisualInstance3D).get_aabb())
		if box.size.length() > 30.0:
			continue   # (un gruppo grande col nome giusto per caso)
		_vietati.append([box.grow(1.0), String(_radice.get_path_to(n))])


## Il nome del materiale colpito da [param h] (un raggio sulle collisioni delle mesh).
func _materiale(h: Dictionary) -> String:
	var mi: MeshInstance3D = _corpi.get(h.rid)
	if mi == null or not _superfici.has(mi):
		return ""
	var f := int(h.get("face_index", -1))
	var fine: Array = _superfici[mi]
	for si in fine.size():
		if f < int(fine[si]):
			var m := mi.get_active_material(si)
			return String(m.resource_name).to_lower() if m else ""
	return ""


## La luce che arriva su [param p] (normale [param n]) dalle lampade accese che lo vedono: la somma di energia per
## attenuazione per coseno (1 è una lampada da 1 a 1-2 m).
func _luce(spazio: PhysicsDirectSpaceState3D, p: Vector3, n: Vector3) -> float:
	var tot := 0.0
	for l in _luci:
		var lp: Vector3 = l[0]
		var d := p.distance_to(lp)
		if d > float(l[2]) or d < 0.01:
			continue
		var cosn := n.dot((lp - p) / d)
		if cosn <= 0.0:
			continue
		var att := pow(1.0 - d / float(l[2]), 2.0)
		if l[3] is SpotLight3D:
			var sp := l[3] as SpotLight3D
			var dir := -sp.global_basis.z
			if rad_to_deg(dir.angle_to((p - lp) / d)) > sp.spot_angle:
				continue
		# coperta? (il colpo vicino alla lampada è la sua lampada)
		var h := _raggio(spazio, p + n * 0.05, lp)
		if not h.is_empty() and (h.position as Vector3).distance_to(lp) > 0.5:
			continue
		tot += float(l[1]) * att * cosn
	return tot


# --- dove si cammina -----------------------------------------------------------------------------------------------

func _raggio(spazio: PhysicsDirectSpaceState3D, da: Vector3, a: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(da, a, STRATO)
	q.hit_back_faces = true
	return spazio.intersect_ray(q)


func _a_terra(spazio: PhysicsDirectSpaceState3D, p: Vector3) -> Variant:
	var h := _raggio(spazio, p + Vector3.UP * 0.6, p + Vector3.DOWN * 1.2)
	if h.is_empty() or (h.normal as Vector3).y < 0.8:
		return null
	var q: Vector3 = h.position
	# 2 m d'aria sopra
	if not _raggio(spazio, q + Vector3.UP * 0.05, q + Vector3.UP * 2.0).is_empty():
		return null
	return q


func _cammino(spazio: PhysicsDirectSpaceState3D) -> Array:
	var semi := []
	for n in _radice.find_children("*", "Checkpoint", true, false) + _radice.find_children("*", "Marker3D", true, false):
		semi.append((n as Node3D).global_position)
	if _radice.has_method(&"punto"):
		var lung: float = _radice.call(&"lunghezza")
		var s := 0.0
		while s < lung:
			var p: Vector3 = _radice.call(&"punto", s) + (_radice.call(&"destra", s) as Vector3) * (float(_radice.get(&"canale")) + 1.0)
			semi.append(Vector3(p.x, float(_radice.get(&"piano")) + 0.1, p.z))
			s += 20.0
	var visti := {}
	var coda := []
	var out := []
	for s in semi:
		var q = _a_terra(spazio, s as Vector3)
		if q == null:
			continue
		var k := Vector3i(roundi((q as Vector3).x / PASSO), roundi((q as Vector3).y / 0.35), roundi((q as Vector3).z / PASSO))
		if not visti.has(k):
			visti[k] = true
			coda.append(q)
	var i := 0
	while i < coda.size() and out.size() < 60000:
		var p: Vector3 = coda[i]
		i += 1
		out.append(p)
		for d in [Vector3(PASSO, 0, 0), Vector3(-PASSO, 0, 0), Vector3(0, 0, PASSO), Vector3(0, 0, -PASSO)]:
			# niente muri in mezzo (alle ginocchia e alla testa)
			if not _raggio(spazio, p + Vector3.UP * 0.5, p + Vector3.UP * 0.5 + d).is_empty() \
					or not _raggio(spazio, p + Vector3.UP * 1.6, p + Vector3.UP * 1.6 + d).is_empty():
				continue
			var q = _a_terra(spazio, p + d + Vector3.UP * 0.35)
			if q == null or absf((q as Vector3).y - p.y) > 0.36:
				continue
			var k := Vector3i(roundi((q as Vector3).x / PASSO), roundi((q as Vector3).y / 0.35), roundi((q as Vector3).z / PASSO))
			if visti.has(k):
				continue
			visti[k] = true
			coda.append(q)
	return out


# --- i muri --------------------------------------------------------------------------------------------------------

func _zona(mi: Node) -> String:
	var p := String(_radice.get_path_to(mi))
	var scena := String(_radice.scene_file_path).get_file().get_basename()
	if scena == "sala_torre":
		return "inseguimento" if p.begins_with("SalaInseguimento") else "torre"
	if scena == "sala_sottomarino":
		return "tunnel"
	var primo := p.get_slice("/", 0)
	if primo == "Risalita":
		var pl := p.to_lower()
		if pl.contains("fiume"):
			return "fiume"
		if pl.contains("infermeria"):
			return "infermeria"
		return "risalita"
	return {"Interni": "interni", "Tecnici": "tecnici"}.get(primo, "sala")


func _candidati(spazio: PhysicsDirectSpaceState3D, punti: Array) -> Array:
	# i colpi sui muri dai punti della strada (uno ogni 4)
	var colpi := []
	var rng := RandomNumberGenerator.new()
	rng.seed = 2810
	for j in range(0, punti.size(), 4):
		var p: Vector3 = punti[j] + Vector3.UP * OCCHI
		for k in 12:
			var ang := TAU * (float(k) + rng.randf()) / 12.0
			var d := Vector3(cos(ang), 0, sin(ang))
			var h := _raggio(spazio, p + d * 0.3, p + d * 10.0)
			if h.is_empty():
				continue
			var n: Vector3 = h.normal
			if absf(n.y) > 0.12 or p.distance_to(h.position) < 1.5 or n.dot(-d) < 0.5:
				continue
			var mi: MeshInstance3D = _corpi.get(h.rid)
			if mi == null or not _architettura(mi):
				continue
			colpi.append([h.position, n.normalized(), mi])
			_conta("colpi " + _zona(mi))
	# un rettangolo libero intorno a ogni colpo (i colpi vicini sullo stesso muro una volta sola)
	var muri := []
	for c in colpi:
		var pos: Vector3 = c[0]
		var n: Vector3 = c[1]
		if muri.any(func(m): return (m["_pos"] as Vector3).distance_to(pos) < 2.5 and (m["_n"] as Vector3).dot(n) > 0.9):
			continue
			continue
		var m := _rettangolo(spazio, pos, n, c[2])
		if not m.is_empty():
			muri.append(m)
	# il punteggio: da quanti punti della strada si vede di fronte (fra 2 e 10 m, a meno di 50 gradi), per l'area
	for m in muri:
		var centro: Vector3 = m["_pos"]
		var n: Vector3 = m["_n"]
		var vista := 0
		var meglio := [INF, Vector3.ZERO]
		for j in range(0, punti.size(), 2):
			var occhi: Vector3 = punti[j] + Vector3.UP * OCCHI
			var verso := occhi - centro
			var dist := verso.length()
			if dist < 2.0 or dist > 10.0 or n.dot(verso / dist) < 0.64:
				continue
			if not _raggio(spazio, occhi, centro + n * 0.05).is_empty():
				continue
			vista += 1
			# da dove si vede meglio: di fronte, a 4-5 m
			var voto := absf(dist - 4.5) + (1.0 - n.dot(verso / dist)) * 4.0
			if voto < float(meglio[0]):
				meglio = [voto, occhi]
		m["vista"] = vista
		m["punteggio"] = snappedf(float(vista) * float(m["largo"]) * float(m["alto"]) * minf(float(m["luce"]), 1.0), 0.1)
		m["occhi"] = _v(meglio[1])
	muri = muri.filter(func(m): return int(m["vista"]) > 0)
	muri.sort_custom(func(a, b): return float(a["punteggio"]) > float(b["punteggio"]))
	# uno per muro: sullo stesso piano, entro 6 m, resta il più visto
	var uno := []
	for m in muri:
		var nn: Vector3 = m["_n"]
		if not uno.any(func(u): return (u["_n"] as Vector3).dot(nn) > 0.95 and absf(nn.dot(u["_pos"] - m["_pos"])) < 0.1 \
				and (u["_pos"] as Vector3).distance_to(m["_pos"]) < 6.0):
			uno.append(m)
	muri = uno
	# i migliori 6 per zona
	var per_zona := {}
	var out := []
	for m in muri:
		var z: String = m["zona"]
		if int(per_zona.get(z, 0)) >= 8:
			continue
		per_zona[z] = int(per_zona.get(z, 0)) + 1
		m.erase("_pos")
		m.erase("_n")
		m["nome"] = "%s_%d" % [z, per_zona[z]]
		out.append(m)
		print("  %s: %s, %.1f × %.1f m, vista da %d punti, %s" % [m["nome"], str(m["centro"]), m["largo"], m["alto"], m["vista"], m["mesh"]])
	return out


static func _v(v: Vector3) -> Array:
	return [snappedf(v.x, 0.01), snappedf(v.y, 0.01), snappedf(v.z, 0.01)]


## Il rettangolo libero più grande (di RETTANGOLI) sul muro di [param pos] (normale [param n]), o vuoto.
func _rettangolo(spazio: PhysicsDirectSpaceState3D, pos: Vector3, n: Vector3, mi: MeshInstance3D) -> Dictionary:
	var tang := Vector3.UP.cross(n).normalized()
	# il pavimento sotto il muro (davanti)
	var giu := _raggio(spazio, pos + n * 0.4, pos + n * 0.4 + Vector3.DOWN * 6.0)
	if giu.is_empty():
		_conta("senza pavimento " + _zona(mi))
		return {}
	var terra: float = (giu.position as Vector3).y
	var piano := n.dot(pos)
	for r in RETTANGOLI:
		var w: float = r[0]
		var h: float = r[1]
		var centro := Vector3(pos.x, terra + float(r[2]), pos.z)
		centro -= n * (n.dot(centro) - piano)
		var buono := true
		for iu in 7:
			for iv in 5:
				var q := centro + tang * (w * (float(iu) / 6.0 - 0.5)) + Vector3.UP * (h * (float(iv) / 4.0 - 0.5))
				var hh := _raggio(spazio, q + n * 0.6, q - n * 0.2)
				if hh.is_empty() or absf(n.dot(hh.position as Vector3) - piano) > 0.035 or (hh.normal as Vector3).dot(n) < 0.95:
					buono = false
					_conta("no piatto %s %.1f" % [_zona(mi), w])
					break
				var m2: MeshInstance3D = _corpi.get(hh.rid)
				if m2 == null or not _architettura(m2):
					buono = false
					_conta("no architettura %s %.1f" % [_zona(mi), w])
					break
			if not buono:
				break
		if not buono:
			continue
		# niente cartelli o indizi dipinti sul muro (lo schema delle pompe è un materiale del muro): una griglia più larga
		# di 0,6 m intorno
		for iu in 9:
			for iv in 6:
				var q := centro + tang * ((w + 1.2) * (float(iu) / 8.0 - 0.5)) + Vector3.UP * ((h + 1.2) * (float(iv) / 5.0 - 0.5))
				var hh := _raggio(spazio, q + n * 0.6, q - n * 0.2)
				if not hh.is_empty():
					var mat := _materiale(hh)
					if MATERIALI_VIETATI.any(func(x): return mat.contains(x)):
						buono = false
						_conta("indizio dipinto %s %s" % [_zona(mi), mat])
						break
			if not buono:
				break
		if not buono:
			continue
		# niente oggetti davanti (0,5 m) né vicino, niente porte, Polaroid, interattivi o indizi entro 1 m
		var lastra := AABB(centro, Vector3.ZERO)
		for su in [-0.5, 0.5]:
			for la in [-0.5, 0.5]:
				lastra = lastra.expand(centro + tang * w * la + Vector3.UP * h * su + n * 0.5)
				lastra = lastra.expand(centro + tang * w * la + Vector3.UP * h * su - n * 0.05)
		var vicino := lastra.grow(0.3)
		if _oggetti_box.any(func(o): return (o[0] as AABB).intersects(vicino)):
			_conta("oggetti %s %.1f" % [_zona(mi), w])
			continue
		if _vietati.any(func(o): return (o[0] as AABB).intersects(lastra)):
			_conta("vietati %s %.1f" % [_zona(mi), w])
			continue
		var luce := 0.0
		for su in [-0.3, 0.0, 0.3]:
			for la in [-0.3, 0.0, 0.3]:
				luce += _luce(spazio, centro + tang * w * la + Vector3.UP * h * su, n) / 9.0
		if luce < LUCE_MIN:
			_conta("buio %s %.1f" % [_zona(mi), w])
			continue
		return {"zona": _zona(mi), "centro": _v(centro), "normale": _v(n), "largo": w, "alto": h, "luce": snappedf(luce, 0.01),
				"mesh": String(_radice.get_path_to(mi)), "scena": _radice.scene_file_path, "_pos": centro, "_n": n}
	return {}
