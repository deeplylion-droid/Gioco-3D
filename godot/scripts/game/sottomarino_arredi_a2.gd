class_name SottomarinoArrediA2
## Gli arredi dei primi quattro ambienti del tunnel del viaggio sottomarino (ambienti-2): la presa, il giardino dei
## coralli, il relitto e la sala del palombaro (gli altri quattro sono di ambienti-1, sottomarino_arredi_a1.gd).
## Sono i pezzi approvati del fiume B (assets/fiume_lento: corallo, ancora, forziere, salvagente, palombaro).
## Le banchine sono tutta strada (regola dell'utente, ripetuta dal coordinatore il 24 ottobre): fino a 2 m d'altezza
## sopra le banchine non c'è niente, a parte gli ostacoli voluti. Quindi le cose stanno sui muri, col bordo basso sopra
## i 2 m: i coralli, il forziere e il palombaro su mensole di graniglia a sbalzo dal muro (murate, come il muro: senza
## sostegni sotto, che toglierebbero larghezza), l'ancora e il salvagente fissati al muro. Lontano dalle lampade (sul
## muro ogni 9 m, a 3 m) e dagli oblò (a 1,9 m). Si mettono con lo strumento comune (Posa): la mensola contro il muro,
## poi la cosa contro il muro e giù sulla mensola. Le cose appoggiate restano a [constant DAL_MURO] dal muro, come
## un soprammobile; quelle fissate al muro (l'ancora, il salvagente) lo toccano.
const DAL_MURO := 0.04
## Il sotto delle mensole sopra il piano delle banchine (sopra i 2 m) e il loro spessore.
const MENSOLA_SU := 2.05
const MENSOLA_SPESSA := 0.15
## Quanto la mensola entra nel muro (è murata: in curva il muro non è un piano, e così i suoi angoli non si staccano).
const MENSOLA_DENTRO := 0.015

## I coralli: [s, lato, scala, giro in gradi] (fra 1,2 e 1,55 m d'altezza), ognuno sulla sua mensola.
const CORALLI := [
	[66.4, 1.0, 1.15, 10.0], [67.7, 1.0, 1.0, -35.0],
	[79.2, 1.0, 1.25, 0.0], [80.5, 1.0, 1.0, 50.0], [81.8, 1.0, 1.3, -20.0],
	[88.2, -1.0, 1.3, 15.0], [89.5, -1.0, 1.05, -40.0], [90.9, -1.0, 1.2, 70.0],
	[97.4, 1.0, 1.1, -10.0], [98.8, 1.0, 1.3, 30.0], [100.6, 1.0, 1.0, -60.0], [101.9, 1.0, 1.2, 5.0],
	[106.0, -1.0, 1.15, 40.0], [107.4, -1.0, 1.3, -15.0], [109.0, -1.0, 1.0, 60.0],
]
## Il relitto (la prima curva a U): l'ancora ritta sul muro esterno, accanto a una lampada del tunnel, tenuta da due
## staffe; il salvagente sul suo asse di legno; il forziere su una mensola del muro interno. (La rete con le stelle
## di Meshy è venuta male, quattro bastoni senza rete né stelle: non si usa.)
const ANCORA := [121.6, -1.0, 1.4]
const SALVAGENTE := [140.6, -1.0, 1.0]
const FORZIERE := [152.5, 1.0, 1.2]
## Il palombaro su una mensola larga, girato verso il canale.
const PALOMBARO := [190.0, 1.0, 1.0]


static func passi(sala: SalaSottomarino) -> Array:
	return [_coralli.bind(sala), _relitto.bind(sala), _palombaro.bind(sala)]


static func _coralli(sala: SalaSottomarino) -> void:
	var nodo := Node3D.new()
	nodo.name = "Coralli"
	sala.add_child(nodo)
	for c in CORALLI:
		var scala: float = c[2]
		_mensola(sala, nodo, float(c[0]), float(c[1]), 0.9, 0.54 * scala + DAL_MURO + 0.06)
		var n := _contro_il_muro(sala, nodo, "corallo", float(c[0]), float(c[1]), scala, float(c[3]), true)
		n.name = "Corallo_%d" % int(c[0] * 10.0)


static func _relitto(sala: SalaSottomarino) -> void:
	var nodo := Node3D.new()
	nodo.name = "Relitto"
	sala.add_child(nodo)
	var ancora := _contro_il_muro(sala, nodo, "ancora", ANCORA[0], ANCORA[1], ANCORA[2], 0.0, false)
	ancora.name = "Ancora"
	# due staffe d'acciaio attorno al fusto, murate: una a un terzo e una a due terzi dell'altezza
	var alta: float = 1.5 * float(ANCORA[2])
	var spessa: float = 0.233 * float(ANCORA[2])
	for f: float in [0.4, 0.75]:
		var st := MeshInstance3D.new()
		st.name = "Staffa"
		var bm := BoxMesh.new()
		bm.size = Vector3(0.22, 0.07, spessa + 0.006)
		st.mesh = bm
		st.material_override = sala._mat_ferro()
		ancora.add_child(st)
		# (attorno al fusto, a metà del suo spessore: tocca il muro, 3 mm dentro, e copre il davanti del fusto)
		st.global_transform = Transform3D(ancora.global_basis.orthonormalized(),
				ancora.global_position + Vector3.UP * alta * f)
	# il salvagente del relitto, col suo asse di legno (gancio e cima compresi nel modello) fissato al muro
	var salv := _contro_il_muro(sala, nodo, "salvagente", SALVAGENTE[0], SALVAGENTE[1], SALVAGENTE[2], 0.0, false)
	salv.name = "Salvagente"
	_mensola(sala, nodo, FORZIERE[0], FORZIERE[1], 1.05, 0.454 * float(FORZIERE[2]) + DAL_MURO + 0.08)
	var forziere := _contro_il_muro(sala, nodo, "forziere", FORZIERE[0], FORZIERE[1], FORZIERE[2], 0.0, true)
	forziere.name = "Forziere"


static func _palombaro(sala: SalaSottomarino) -> void:
	var nodo := Node3D.new()
	nodo.name = "SalaPalombaro"
	sala.add_child(nodo)
	_mensola(sala, nodo, PALOMBARO[0], PALOMBARO[1], 1.1, 0.945 * float(PALOMBARO[2]) + DAL_MURO + 0.08)
	var pal := _contro_il_muro(sala, nodo, "palombaro", PALOMBARO[0], PALOMBARO[1], PALOMBARO[2], 0.0, true)
	pal.name = "Palombaro"


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
	corpo.global_position += r * MENSOLA_DENTRO
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
	var n := sala._modello(nodo, nome, sala._al(p, sala.destra(s), Vector2(lato * (sala.muro - 0.8), quota)), verso, scala)
	# quanto sporge il retro del modello dietro l'origine, lungo la normale del muro
	var dietro := 0.0
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mm := m as MeshInstance3D
		var xf := mm.global_transform
		for v in mm.mesh.get_faces():
			dietro = maxf(dietro, ((xf * v) - n.global_position).dot(r))
	if not Posa.fissa_al_muro(n, -r, dietro + DAL_MURO if sulla_mensola else dietro, false):
		push_warning("arredi sottomarino: %s a %.1f senza muro" % [nome, s])
	if sulla_mensola and not Posa.appoggia_a_terra(n, 0.0, false):
		push_warning("arredi sottomarino: %s a %.1f senza mensola" % [nome, s])
	sala._collisione_modello(n)
	return n
