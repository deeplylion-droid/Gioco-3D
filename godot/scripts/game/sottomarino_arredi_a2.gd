class_name SottomarinoArrediA2
## Gli arredi dei primi quattro ambienti del tunnel del viaggio sottomarino (ambienti-2): la presa, il giardino dei
## coralli, il relitto e la sala del palombaro (gli altri quattro sono di ambienti-1, sottomarino_arredi_a1.gd).
## Sono i pezzi approvati del fiume B (assets/fiume_lento: corallo, ancora, forziere, salvagente, palombaro).
## Le banchine sono tutta strada (regola dell'utente, ripetuta dal coordinatore il 24 ottobre): fino a 2 m d'altezza
## sopra le banchine non c'è niente, a parte gli ostacoli voluti. Quindi le cose stanno sui muri, col bordo basso sopra
## i 2 m: i coralli, il forziere e il palombaro su mensole di graniglia a sbalzo dal muro (murate, come il muro: senza
## sostegni sotto, che toglierebbero larghezza), l'ancora e il salvagente fissati al muro. Lontano dalle lampade (sul
## muro ogni 9 m, a 3 m) e dagli oblò (il centro a 2,55 m). Si mettono con lo strumento comune (Posa): la mensola contro il muro,
## poi la cosa contro il muro e giù sulla mensola. Le cose appoggiate restano a [constant DAL_MURO] dal muro, come
## un soprammobile; quelle fissate al muro (l'ancora, il salvagente) lo toccano.
const DAL_MURO := 0.04
## Il sotto delle mensole sopra il piano delle banchine (sopra i 2 m) e il loro spessore.
const MENSOLA_SU := 2.05
const MENSOLA_SPESSA := 0.15
## Quanto la mensola entra nel muro (è murata: 2 mm, così in curva i suoi angoli non si staccano, e la distanza vera
## dal mosaico resta sotto 1 cm anche misurata senza segno, come nel collaudo).
const MENSOLA_DENTRO := 0.002

## I coralli: [s, lato, scala, giro in gradi] (fra 1,2 e 1,55 m d'altezza), ognuno sulla sua mensola.
const CORALLI := [
	[66.4, 1.0, 1.15, 10.0], [67.7, 1.0, 1.0, -35.0],
	[79.2, 1.0, 1.25, 0.0], [81.8, 1.0, 1.3, -20.0],
	[88.2, -1.0, 1.3, 15.0], [89.5, -1.0, 1.05, -40.0], [90.9, -1.0, 1.2, 70.0],
	[97.4, 1.0, 1.1, -10.0], [98.8, 1.0, 1.3, 30.0], [100.6, 1.0, 1.0, -60.0], [101.9, 1.0, 1.2, 5.0],
	[106.0, -1.0, 1.15, 40.0], [107.4, -1.0, 1.3, -15.0], [109.0, -1.0, 1.0, 60.0],
]
## Il relitto (la prima curva a U): l'ancora ritta sul muro esterno, accanto a una lampada del tunnel, tenuta da due
## staffe; il salvagente sul suo asse di legno; il forziere su una mensola dello stesso muro (che lì è concavo: la
## mensola dritta ci sta a filo). (La rete con le stelle
## di Meshy è venuta male, quattro bastoni senza rete né stelle: non si usa.)
const ANCORA := [121.6, -1.0, 1.4]
const SALVAGENTE := [140.6, -1.0, 1.0]
const FORZIERE := [147.0, -1.0, 1.1]
## Il palombaro su una mensola larga, girato verso il canale.
const PALOMBARO := [190.0, 1.0, 1.0]


## (i coralli uno per passo: tutti in un passo erano 1,4 s di gioco fermo nella costruzione a pezzi)
static func passi(sala: SalaSottomarino) -> Array:
	var out: Array = [_coralli.bind(sala)]
	for c in CORALLI:
		out.append(_corallo.bind(sala, c))
	out.append_array([_relitto.bind(sala), _palombaro.bind(sala)])
	return out


static func _coralli(sala: SalaSottomarino) -> void:
	var nodo := Node3D.new()
	nodo.name = "Coralli"
	sala.add_child(nodo)


static func _corallo(sala: SalaSottomarino, c: Array) -> void:
	var nodo := sala.get_node(^"Coralli") as Node3D
	var scala: float = c[2]
	_mensola(sala, nodo, float(c[0]), float(c[1]), 0.75, 0.54 * scala + DAL_MURO + 0.06)
	var n := _contro_il_muro(sala, nodo, "corallo", float(c[0]), float(c[1]), scala, float(c[3]), true)
	n.name = "Corallo_%d" % int(c[0] * 10.0)


static func _relitto(sala: SalaSottomarino) -> void:
	var nodo := Node3D.new()
	nodo.name = "Relitto"
	sala.add_child(nodo)
	var ancora := _contro_il_muro(sala, nodo, "ancora", ANCORA[0], ANCORA[1], ANCORA[2], 0.0, false)
	ancora.name = "Ancora"
	# due staffe d'acciaio sul fusto nudo (fra le marre, che arrivano al 40% dell'altezza, e il ceppo, all'80%): due
	# piastre murate ai lati del fusto coi bulloni, due bracci che vengono avanti lungo i fianchi del fusto e il collare
	# davanti (misurati sulla mesh vera del fusto)
	var alta: float = 1.5 * float(ANCORA[2])
	for f: float in [0.62, 0.7]:
		_staffa(sala, ancora, alta * f)
	# il salvagente del relitto, col suo asse di legno (gancio e cima compresi nel modello) fissato al muro
	var salv := _contro_il_muro(sala, nodo, "salvagente", SALVAGENTE[0], SALVAGENTE[1], SALVAGENTE[2], 0.0, false)
	salv.name = "Salvagente"
	var men_f := _mensola(sala, nodo, FORZIERE[0], FORZIERE[1], 0.9, 0.454 * float(FORZIERE[2]) + DAL_MURO + 0.08)
	var forziere := _contro_il_muro(sala, nodo, "forziere", FORZIERE[0], FORZIERE[1], FORZIERE[2], 0.0, true)
	forziere.name = "Forziere"
	_doppia_faccia(forziere)
	_faretto(sala, nodo, men_f, forziere, 0.15)


static func _palombaro(sala: SalaSottomarino) -> void:
	var nodo := Node3D.new()
	nodo.name = "SalaPalombaro"
	sala.add_child(nodo)
	var men_p := _mensola(sala, nodo, PALOMBARO[0], PALOMBARO[1], 1.1, 0.945 * float(PALOMBARO[2]) + DAL_MURO + 0.08)
	var pal := _contro_il_muro(sala, nodo, "palombaro", PALOMBARO[0], PALOMBARO[1], PALOMBARO[2], 0.0, true)
	pal.name = "Palombaro"
	_faretto(sala, nodo, men_p, pal, 0.75)


## Una mensola di graniglia murata nel muro dal lato [param lato] a [param s], larga [param largo] lungo il muro e
## profonda [param profondo], col sotto a [constant MENSOLA_SU] sopra il piano. Il nome della mesh dice che è
## architettura (fa parte del muro) per il controllo di posizionamento.
static func _mensola(sala: SalaSottomarino, nodo: Node3D, s: float, lato: float, largo: float, profondo: float) -> Node3D:
	var r := sala.destra(s) * lato
	var corpo := StaticBody3D.new()
	corpo.name = "Mensola"
	corpo.collision_layer = Layers.WORLD
	nodo.add_child(corpo)
	var mi := MeshInstance3D.new()
	mi.name = "struttura_mensola"
	var bm := BoxMesh.new()
	bm.size = Vector3(largo, MENSOLA_SPESSA, profondo)
	mi.mesh = bm
	mi.material_override = sala.mat_graniglia
	corpo.add_child(mi)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = bm.size
	cs.shape = box
	corpo.add_child(cs)
	var p := sala.punto(s)
	# (la z della scatola lungo la normale del muro: il retro, mezza profondità dietro il centro, sul muro)
	corpo.global_transform = Transform3D(Basis.looking_at(-r, Vector3.UP),
			sala._al(p, sala.destra(s), Vector2(lato * (sala.muro - profondo * 0.5 - 0.2), sala.piano + MENSOLA_SU + MENSOLA_SPESSA * 0.5)))
	if not Posa.fissa_al_muro(corpo, -r, profondo * 0.5):
		push_warning("arredi sottomarino: mensola a %.1f senza muro" % s)
	# in curva il muro non è un piano: si misura quanto restano staccati gli angoli del retro (raggi sul muro vero) e
	# la mensola entra quanto basta perché tocchino, almeno MENSOLA_DENTRO
	var dentro := MENSOLA_DENTRO
	var sp := corpo.get_world_3d().direct_space_state
	for fx: float in [-0.5, 0.5]:
		var angolo := corpo.global_transform * Vector3(fx * largo, 0.0, profondo * 0.5)
		var q := PhysicsRayQueryParameters3D.create(angolo - r * 0.1, angolo + r * 0.2, Layers.WORLD, [corpo.get_rid()])
		var h := sp.intersect_ray(q)
		if not h.is_empty():
			dentro = maxf(dentro, ((h.position as Vector3) - angolo).dot(r) + 0.003)
	corpo.global_position += r * minf(dentro, 0.03)
	return corpo


## Un modello del fiume B contro il muro dal lato [param lato] a [param s], girato verso il canale (più [param giro]
## gradi attorno alla verticale). [param sulla_mensola]: si appoggia sulla mensola sotto (a [constant DAL_MURO] dal
## muro); se no è fissato al muro col bordo basso a [constant MENSOLA_SU] sopra il piano.
static func _contro_il_muro(sala: SalaSottomarino, nodo: Node3D, nome: String, s: float, lato: float, scala: float,
		giro: float, sulla_mensola: bool) -> Node3D:
	var p := sala.punto(s)
	var r := sala.destra(s) * lato
	var verso := (-r).rotated(Vector3.UP, deg_to_rad(giro))
	var quota := sala.piano + MENSOLA_SU + (MENSOLA_SPESSA + 0.3 if sulla_mensola else 0.0)
	var t0 := Time.get_ticks_usec()
	var n := sala._modello(nodo, nome, sala._al(p, sala.destra(s), Vector2(lato * (sala.muro - 0.8), quota)), verso, scala)
	var t1 := Time.get_ticks_usec()
	# quanto sporge il retro del modello dietro l'origine, lungo la normale del muro
	var dietro := 0.0
	# (il punto più sporgente è sempre un vertice dell'involucro convesso: si cerca lì, poche centinaia di punti calcolati
	# dal motore, invece che su tutte le facce in GDScript, che costava fino a 1,6 s per i coralli)
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mm := m as MeshInstance3D
		var xf := mm.global_transform
		for v in _involucro(mm.mesh):
			dietro = maxf(dietro, ((xf * v) - n.global_position).dot(r))
	var t2 := Time.get_ticks_usec()
	if not Posa.fissa_al_muro(n, -r, dietro + DAL_MURO if sulla_mensola else dietro, false):
		push_warning("arredi sottomarino: %s a %.1f senza muro" % [nome, s])
	if sulla_mensola and not Posa.appoggia_a_terra(n, 0.0, false):
		push_warning("arredi sottomarino: %s a %.1f senza mensola" % [nome, s])
	var t3 := Time.get_ticks_usec()
	sala._collisione_modello(n)
	if OS.has_environment("TORRE_TEMPI"):
		print("  %s: modello %.0f, sporgenza %.0f, posa %.0f, collisione %.0f ms" % [nome, (t1 - t0) / 1000.0, (t2 - t1) / 1000.0, (t3 - t2) / 1000.0, (Time.get_ticks_usec() - t3) / 1000.0])
	return n


## Il forziere è aperto, e dentro il modello ha solo le facce di fuori: guardandoci dentro dalla banchina si vedevano
## triangoli dal retro (collaudo di enigmi, vista dal retro a 136). Le sue mesh si disegnano dalle due parti.
static func _doppia_faccia(n: Node3D) -> void:
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mm := m as MeshInstance3D
		mm.set_meta(&"doppia_faccia", true)
		for i in mm.mesh.get_surface_count():
			var mat := mm.get_active_material(i)
			if mat is BaseMaterial3D:
				var d := mat.duplicate() as BaseMaterial3D
				d.cull_mode = BaseMaterial3D.CULL_DISABLED
				mm.set_surface_override_material(i, d)


## Una staffa attorno al fusto di [param ancora] a [param h] sopra la sua base: misura il fusto lì (i vertici della
## mesh entro 4 cm di quota e 15 cm dall'asse), poi piastre, bulloni, bracci e collare, a 3 mm dal fusto.
static func _staffa(sala: SalaSottomarino, ancora: Node3D, h: float) -> void:
	var b := ancora.global_basis.orthonormalized()
	var o := ancora.global_position
	# la sezione vera a quota h: i triangoli della mesh tagliati dal piano (il modello ha pochi vertici: i vertici soli
	# non dicono dov'è il fusto fra un anello e l'altro)
	var sezione := PackedVector3Array()
	var zm := -INF           # il retro dell'ancora (sul muro: +z)
	for m in ancora.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.name == "Staffa":
			continue
		var xf := mi.global_transform
		var fv := mi.mesh.get_faces()
		for k in range(0, fv.size(), 3):
			var tri := [b.inverse() * ((xf * fv[k]) - o), b.inverse() * ((xf * fv[k + 1]) - o), b.inverse() * ((xf * fv[k + 2]) - o)]
			for i in 3:
				var p1: Vector3 = tri[i]
				var p2: Vector3 = tri[(i + 1) % 3]
				zm = maxf(zm, p1.z)
				if (p1.y - h) * (p2.y - h) < 0.0:
					sezione.append(p1.lerp(p2, (h - p1.y) / (p2.y - p1.y)))
	# il fusto è il pezzo della sezione contro il muro (la catena gli passa davanti)
	var x0 := INF
	var x1 := -INF
	var zf := INF            # il davanti del fusto (verso il canale: -z)
	var zs := -INF
	for q in sezione:
		zs = maxf(zs, q.z)
	for q in sezione:
		if q.z >= zs - 0.08:
			x0 = minf(x0, q.x)
			x1 = maxf(x1, q.x)
			zf = minf(zf, q.z)
	if x0 == INF:
		return
	var nodo := Node3D.new()
	nodo.name = "Staffa"
	ancora.add_child(nodo)
	nodo.global_transform = Transform3D(b, o)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var facce := PackedVector3Array()
	var gioco := 0.003
	var sp := 0.012
	var xa := x0 - gioco - sp * 0.5        # i bracci
	var xb := x1 + gioco + sp * 0.5
	var prof := zm - (zf - gioco - sp)       # dal muro al davanti del collare
	for xc: float in [xa, xb]:
		# il braccio, dal muro al collare
		sala._scatola(st, facce, Vector3(xc, h, zm - prof * 0.5), Vector3.RIGHT, Vector3.BACK, Vector3(sp, 0.06, prof))
		# la piastra murata di fianco, coi due bulloni
		var xp := xc + signf(xc) * (sp * 0.5 + 0.04)
		sala._scatola(st, facce, Vector3(xp, h, zm - sp * 0.5), Vector3.RIGHT, Vector3.BACK, Vector3(0.08, 0.12, sp))
		for yb: float in [-0.035, 0.035]:
			sala._scatola(st, facce, Vector3(xp, h + yb, zm - sp - 0.004), Vector3.RIGHT, Vector3.BACK, Vector3(0.018, 0.018, 0.008))
	# il collare davanti al fusto
	sala._scatola(st, facce, Vector3((xa + xb) * 0.5, h, zf - gioco - sp * 0.5), Vector3.RIGHT, Vector3.BACK, Vector3(xb - xa + sp, 0.06, sp))
	var mi_s := MeshInstance3D.new()
	mi_s.name = "Staffa"
	mi_s.mesh = st.commit()
	mi_s.material_override = sala._mat_ferro()
	nodo.add_child(mi_s)


## Un faretto piccolo sul bordo davanti della [param mensola], puntato in su su [param cosa] (a [param su] sopra la sua
## base): al buio, fra una lampada e l'altra, il palombaro e il forziere si leggevano poco (collaudo di enigmi).
static func _faretto(sala: SalaSottomarino, nodo: Node3D, mensola: Node3D, cosa: Node3D, su: float) -> void:
	var box := ((mensola.get_child(0) as MeshInstance3D).mesh as BoxMesh).size
	var b := mensola.global_basis.orthonormalized()
	# (la z della mensola va verso il muro: il bordo davanti è a -z)
	var base := mensola.global_position + b.y * box.y * 0.5 - b.z * (box.z * 0.5 - 0.05)
	var corpo := MeshInstance3D.new()
	corpo.name = "Faretto"
	var cm := CylinderMesh.new()
	cm.top_radius = 0.035
	cm.bottom_radius = 0.045
	cm.height = 0.07
	corpo.mesh = cm
	corpo.material_override = sala._mat_ferro()
	nodo.add_child(corpo)
	corpo.global_position = base + Vector3.UP * 0.035
	var sl := SpotLight3D.new()
	sl.name = "LuceFaretto"
	sl.light_color = Color(1.0, 0.86, 0.66)
	sl.light_energy = 2.6
	sl.spot_range = 3.0
	sl.spot_angle = 38.0
	sl.shadow_enabled = false
	nodo.add_child(sl)
	sl.global_position = base + Vector3.UP * 0.075
	sl.look_at(cosa.global_position + Vector3.UP * su, b.z if absf(b.z.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT)


## I vertici dell'involucro convesso di [param mesh] (calcolati una volta per mesh).
static var _involucri := {}


static func _involucro(mesh: Mesh) -> PackedVector3Array:
	if not _involucri.has(mesh):
		var forma := mesh.create_convex_shape(true, false)
		_involucri[mesh] = forma.points if forma else mesh.get_faces()
	return _involucri[mesh]
