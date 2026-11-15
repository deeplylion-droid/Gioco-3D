extends Node
## Sonda d'ingombro dei punti d'uscita di lei (AcquaDiLei, build 0.4.0): per ogni AcquaDiLei della scena e ogni suo
## punto d'uscita, lei girata in 8 direzioni (si gira verso il giocatore, che può arrivare da più lati) esce
## (sale_dall_acqua, dalla [member AcquaDiLei.profondita]), incombe, prende, è respinta e scende. A ogni dodicesimo di
## secondo, per ogni osso, un raggio dal padre al figlio contro le collisioni: se attraversa qualcosa sopra il pelo
## dell'acqua lì lei passa attraverso e si vede (difetto); sotto il pelo, nell'acqua torbida, si stampa a parte.
## Stampa, per punto e direzione, le ossa che attraversano e cosa. Per chi mette i punti d'uscita.
## Nel modo MANO (le pozze) lei sta col marker (una sola direzione) e si provano le animazioni pozza_*: sopra il pelo
## non deve attraversare né il grigliato né i bordini.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/sonda_ingombro_acqua_di_lei.gd \
##        <scena.tscn> [Classe.proprieta=valore ...]
## (Classe.proprieta=valore: prima di entrare nella scena, al primo nodo di quella classe, per esempio
## LeiSalaAlBuio.rientro=2.4.) Gli oggetti che galleggiano o si spostano (corpi non statici) si contano a parte.
## (con una scena che crea gli AcquaDiLei nel suo _ready, come la sala principale con LeiSalaAlBuio)

const ANIMAZIONI := ["sale_dall_acqua", "incombe", "presa", "respinta", "scende"]
## Il modo MANO (le pozze): lei sta col marker, non si gira.
const ANIMAZIONI_MANO := ["pozza_esce", "pozza_attesa", "pozza_presa", "pozza_respinta", "pozza_scende"]

var _spazio: PhysicsDirectSpaceState3D


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var scena := (load(a[1]) as PackedScene).instantiate()
	for arg in a.slice(2):
		if not arg.contains("=") or not arg.contains("."):
			continue
		var classe := arg.get_slice(".", 0)
		var prop := arg.get_slice("=", 0).get_slice(".", 1)
		var val := float(arg.get_slice("=", 1))
		var trovati: Array = scena.find_children("*", "", true, false).filter(func(n): return n.get_script() != null \
				and (n.get_script() as Script).get_global_name() == StringName(classe))
		if trovati.is_empty():
			print("INGOMBRO nessun %s" % classe)
		for n in trovati:
			n.set(prop, val)
			print("INGOMBRO imposto %s.%s = %s" % [n.name, prop, val])
			break
	get_tree().root.add_child(scena)
	get_tree().current_scene = scena
	for i in 20:
		await get_tree().physics_frame
	_spazio = get_viewport().world_3d.direct_space_state
	var difetti := 0
	for acqua in scena.find_children("*", "AcquaDiLei", true, false):
		var ad := acqua as AcquaDiLei
		ad.set_physics_process(false)
		ad.call(&"_assicura_lei")
		var lei: MedusaAffacciata = ad.get(&"_lei")
		await get_tree().process_frame
		var ap := lei.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var sk := lei.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		lei.visible = true
		for q in ad.punti_uscita:
			var pelo := ad.pelo_a(q)
			# la zona prepara l'uscita (per esempio scosta i giocattoli che galleggiano: LeiSalaAlBuio)
			if ad.get_parent().has_method(&"prepara_uscita"):
				ad.get_parent().call(&"prepara_uscita", q, 0.0)
				for i in 2:
					await get_tree().physics_frame
			var mano := ad.modo == AcquaDiLei.Modo.MANO
			for k in (1 if mano else 8):
				var ang := TAU * k / 8.0
				if mano:
					lei.global_transform = q.global_transform
				else:
					lei.global_position = q.global_position
					lei.global_rotation = Vector3(0, ang, 0)
				var visti := _incroci(ad, ap, sk, pelo)
				var nome := "%s/%s %s" % [ad.get_parent().name, q.name, "(mano)" if mano else "%3d°" % int(rad_to_deg(ang))]
				var sopra: Dictionary = visti[0]
				var sotto: Dictionary = visti[1]
				if sopra.is_empty():
					print("INGOMBRO %s: niente attraversato sopra il pelo%s" % [nome, "" if sotto.is_empty() else " (sotto il pelo %d ossa)" % sotto.size()])
				else:
					difetti += 1
					print("INGOMBRO %s: ATTRAVERSA sopra il pelo: %s" % [nome, ", ".join(sopra.keys().slice(0, 6))])
	print("INGOMBRO fine: %d posizioni con difetti" % difetti)
	get_tree().quit()


## [ossa che attraversano sopra il pelo, ossa che attraversano sotto]: {"animazione osso attraversa nodo": tempo}.
func _incroci(ad: AcquaDiLei, ap: AnimationPlayer, sk: Skeleton3D, pelo: float) -> Array:
	var sopra := {}
	var sotto := {}
	var prof := clampf(ad.profondita, 0.05, 5.0)
	for an: String in (ANIMAZIONI_MANO if ad.modo == AcquaDiLei.Modo.MANO else ANIMAZIONI):
		var n := StringName("inseguimento/" + an)
		var anim := ap.get_animation(n)
		if anim == null:
			continue
		var t0 := 0.0
		var t1 := anim.length
		if an == "sale_dall_acqua":
			t0 = ad.call(&"_quando_radice", n, prof, true)
		elif an == "respinta" or an == "scende":
			t1 = ad.call(&"_quando_radice", n, prof, false)
		var t := t0
		while t <= t1 + 0.001:
			ap.play(n)
			ap.seek(minf(t, anim.length - 0.001), true)
			ap.advance(0.0)
			var glob := {}
			for i in sk.get_bone_count():
				glob[i] = sk.global_transform * sk.get_bone_global_pose(i).origin
			for i in sk.get_bone_count():
				var pa := sk.get_bone_parent(i)
				if pa < 0 or (glob[pa] as Vector3).distance_to(glob[i]) < 0.005:
					continue
				var qr := PhysicsRayQueryParameters3D.create(glob[pa], glob[i])
				qr.hit_back_faces = true
				var hit := _spazio.intersect_ray(qr)
				if hit.is_empty():
					continue
				var bn := sk.get_bone_name(i)
				var nodo := hit["collider"] as Node
				var chi := String(nodo.get_parent().name) + "/" + String(nodo.name) if nodo.get_parent() else String(nodo.name)
				var key := "%s %s attraversa %s" % [an, bn.substr(0, 12) if bn.begins_with("tentacolo") else bn, chi]
				var statico := nodo is StaticBody3D or (nodo is CollisionObject3D and nodo.get_parent() is StaticBody3D)
				if not statico:
					key = "[oggetto mobile] " + key
				var dove: Dictionary = sopra if (hit["position"] as Vector3).y > pelo and statico else sotto
				if not dove.has(key):
					dove[key] = t
			t += 1.0 / 12.0
	return [sopra, sotto]
