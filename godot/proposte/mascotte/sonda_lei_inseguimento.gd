extends Node
## Sonda: lei nei suoi posti dell'inseguimento (come li mette SalaInseguimento, con la salita che parte da
## PROFONDITA dove c'è poco spazio sotto) e le sue animazioni fotogramma per fotogramma. Per ogni osso un raggio dal
## padre al figlio contro le collisioni della sala: se attraversa qualcosa (pareti, fondi, grigliati, tubi), lì lei
## passa attraverso. Stampa anche i punti più alto e più basso all'inizio della salita.
## Con "cerca <posto>" prova gli spostamenti del posto (fino a 2 m, ogni 0,25 m, e fino a 0,5 m più su) e stampa i più piccoli senza
## niente attraversato. Per la squadra (proposte/ è esclusa dall'export).
## Con "prova <posto> <dx> <dy>" controlla il posto spostato di tanto (metri, assi di Blender).
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- \
##        res://proposte/mascotte/sonda_lei_inseguimento.gd [cerca <posto> | prova <posto> <dx> <dy>]

const SCENA := "res://scenes/sala/inseguimento/sala_inseguimento.tscn"
const SALE := ["sale_dall_acqua", "sale_dall_acqua_veloce", "affacciata_sb1"]
const GIU := ["respinta", "scende"]

var sala: SalaInseguimento
var lei: MedusaAffacciata
var ap: AnimationPlayer
var sk: Skeleton3D
var spazio: PhysicsDirectSpaceState3D


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	sala = (load(SCENA) as PackedScene).instantiate() as SalaInseguimento
	sala.crea_luci = false
	add_child(sala)
	for i in 10:
		await get_tree().physics_frame
	sala.set_physics_process(false)
	lei = sala.lei
	ap = lei.get_model_instance().find_child("AnimationPlayer", true, false) as AnimationPlayer
	sk = lei.get_model_instance().find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	spazio = get_viewport().world_3d.direct_space_state
	var a := OS.get_cmdline_user_args()
	var posti := _posti()
	if a.size() > 4 and a[1] == "prova":
		for posto in posti:
			if posto[0] == a[2]:
				var d := Vector3(float(a[3]), float(a[5]) if a.size() > 5 else 0.0, -float(a[4]))
				posto[1] = (posto[1] as Vector3) + d
				if posto[2] != Vector3.INF:
					posto[2] = (posto[2] as Vector3) + d
				_controlla(posto)
	elif a.size() > 2 and a[1] == "cerca":
		for posto in posti:
			if posto[0] == a[2]:
				_cerca(posto, float(a[3]) if a.size() > 3 else 2.0, float(a[4]) if a.size() > 4 else 0.25)
	else:
		for posto in posti:
			_controlla(posto)
	print("FINE")
	get_tree().quit()


## [nome, posizione, dove guarda (o INF: com'è), animazioni, quota sotto cui il giocatore non vede (il fondo
## della vasca dove sta lui, o il pelo dell'acqua scura)]
func _posti() -> Array:
	var d := sala.dati
	var out := []
	for v in 3:
		var r: Array = d["vasche"][v]["rett"]
		var centro := SalaInseguimento.b([(r[0] + r[2]) / 2.0, (r[1] + r[3]) / 2.0, float(d["vasche"][v]["fondo"]) + 1.0])
		out.append(["vasca_%d" % v, sala._posto_vasca(v), centro, ["sale_dall_acqua", "incombe", "presa", "respinta", "scende"],
			float(d["vasche"][v]["fondo"])])
	for k in d["scolo"].size():
		var r: Array = d["scolo"][k]["rett"]
		var centro := SalaInseguimento.b([(r[0] + r[2]) / 2.0, (r[1] + r[3]) / 2.0, float(d["scolo"][k]["fondo"]) + 1.0])
		out.append(["scolo_%d" % k, sala._posto_scolo(k), centro, ["sale_dall_acqua_veloce", "incombe", "presa"],
			float(d["scolo"][k]["fondo"])])
	out.append(["grata", SalaInseguimento.b(d["lei"][2]["pos"]), SalaInseguimento.b(d["grata"]["perno"]),
		["sale_dall_acqua_veloce", "colpo_grata", "scende"], float(d["allagato"]["acqua"])])
	var pos := sala._posto_sb1()
	out.append(["sb1", pos, Vector3.INF, ["affacciata_sb1"], float(d["bacino"]["acqua"])])
	return out


func _metti(pos: Vector3, guarda: Vector3, basis_sb1: Basis) -> void:
	lei.global_position = pos
	if guarda == Vector3.INF:
		lei.global_basis = basis_sb1
	else:
		var g := guarda
		g.y = pos.y
		lei.look_at(g, Vector3.UP, true)


## Le ossa che attraversano qualcosa: {"osso attraversa nodo": [tempo, punto]} e [punto più alto, più basso]
## all'inizio della salita.
func _incroci(nome: String, anims: Array, primo := false, nascosto_sotto := -INF) -> Array:
	var dentro := {}
	var estremi := [-999.0, 999.0]
	var sotto: float = sala._profondita(nome)
	for an: String in anims:
		var n := StringName("inseguimento/" + an)
		var a := ap.get_animation(n)
		var t0 := 0.0
		var t1 := a.length
		if an in SALE:
			t0 = sala._quando_radice(n, sotto, true)
		elif an in GIU:
			t1 = sala._quando_radice(n, sotto, false)
		var k := 0
		var t := t0
		while t <= t1 + 0.001:
			ap.play(n)
			ap.seek(minf(t, a.length - 0.001), true)
			ap.advance(0.0)
			var glob := {}
			for i in sk.get_bone_count():
				glob[i] = sk.global_transform * sk.get_bone_global_pose(i).origin
				if k == 0 and an in SALE:
					estremi[0] = maxf(estremi[0], (glob[i] as Vector3).y)
					estremi[1] = minf(estremi[1], (glob[i] as Vector3).y)
			for i in sk.get_bone_count():
				var pa := sk.get_bone_parent(i)
				if pa < 0 or (glob[pa] as Vector3).distance_to(glob[i]) < 0.005:
					continue
				var q := PhysicsRayQueryParameters3D.create(glob[pa], glob[i])
				q.hit_back_faces = true
				var hit := spazio.intersect_ray(q)
				if not hit.is_empty() and (hit["position"] as Vector3).y >= nascosto_sotto:
					var bn := sk.get_bone_name(i)
					var nodo := hit["collider"] as Node
					var chi := String(nodo.get_parent().name) + "/" + String(nodo.name) if nodo.get_parent() else String(nodo.name)
					var key := "%s %s attraversa %s" % [an, bn.substr(0, 12) if bn.begins_with("tentacolo") else bn, chi]
					if not dentro.has(key):
						dentro[key] = [t, hit["position"]]
					if primo:
						return [dentro, estremi]
			k += 1
			t += 1.0 / 12.0
	return [dentro, estremi]


func _controlla(posto: Array) -> void:
	var nome: String = posto[0]
	var basis := lei.global_basis
	_metti(posto[1], posto[2], basis)
	var pos: Vector3 = posto[1]
	print("== %s origine %s, salita da %.2f m" % [nome, _bl(pos), sala._profondita(nome)])
	var r := _incroci(nome, posto[3])
	var dentro: Dictionary = r[0]
	var visibili := _incroci(nome, posto[3], false, posto[4])[0] as Dictionary
	print("   inizio della salita: punto più alto %.2f, più basso %.2f (origine %.2f)" % [r[1][0], r[1][1], pos.y])
	if dentro.is_empty():
		print("   niente attraversato")
	for key in dentro:
		print("   %s (%.2f s, %s)%s" % [key, dentro[key][0], _bl(dentro[key][1]), "" if visibili.has(key) else " nascosto"])
	print("   %s: %d incroci, %d visibili (sopra quota %.2f)" % [nome, dentro.size(), visibili.size(), posto[4]])


func _cerca(posto: Array, raggio := 2.0, passo := 0.25) -> void:
	var nome: String = posto[0]
	var basis := lei.global_basis
	var base: Vector3 = posto[1]
	var buoni := []
	var prove := []
	var m := int(raggio / passo)
	for dz in [0.0, 0.3, 0.5]:
		for ix in range(-m, m + 1):
			for iy in range(-m, m + 1):
				var d := Vector3(ix * passo, dz, iy * passo)
				if Vector2(d.x, d.z).length() <= raggio:
					prove.append(d)
	# prima i più piccoli (alzarla conta il doppio)
	prove.sort_custom(func(x: Vector3, y: Vector3): return Vector2(x.x, x.z).length() + 2.0 * x.y < Vector2(y.x, y.z).length() + 2.0 * y.y)
	for d: Vector3 in prove:
		_metti(base + d, posto[2], basis)    # guarda sempre lo stesso punto (il giocatore nella vasca)
		var r := _incroci(nome, posto[3], true, posto[4])
		if (r[0] as Dictionary).is_empty():
			buoni.append(d)
			print("   senza incroci visibili spostandola di %.2f m: x %+.2f, y %+.2f, su %+.2f (Blender)" % [Vector2(d.x, d.z).length(), d.x, -d.z, d.y])
			if buoni.size() >= 8:
				break
	if buoni.is_empty():
		print("   nessuno spostamento fino a 2 m (e 0,5 m più su) toglie gli incroci visibili per ", nome)


func _bl(v: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [v.x, -v.z, v.y]
