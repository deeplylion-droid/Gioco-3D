class_name SottomarinoArrediA2
## Gli arredi dei primi quattro ambienti del tunnel del viaggio sottomarino (ambienti-2): la presa, il giardino dei
## coralli, il relitto e la sala del palombaro (gli altri quattro sono di ambienti-1, sottomarino_arredi_a1.gd).
## Sono i pezzi approvati del fiume B (assets/fiume_lento: corallo, ancora, forziere, salvagente, palombaro),
## tutti contro il muro sulle banchine: il passaggio resta largo almeno 1,4 m, lontano dalle lampade (sul muro ogni
## 9 m, a 3 m), dagli oblò (a 1,9 m) e dagli ostacoli. Si mettono con lo strumento comune (Posa): prima contro il
## muro, poi giù sul pavimento o sul basamento. Le cose che stanno solo per terra (coralli, forziere) restano a
## [constant DAL_MURO] dal muro, come un mobile; quelle fissate al muro (l'ancora, il salvagente) lo toccano.
const DAL_MURO := 0.04

## I coralli: [s, lato, scala, giro in gradi] (fra 1,6 e 2,2 m d'altezza).
const CORALLI := [
	[66.4, 1.0, 1.5, 10.0], [67.6, 1.0, 1.25, -35.0],
	[79.2, 1.0, 1.6, 0.0], [80.5, 1.0, 1.3, 50.0], [81.8, 1.0, 1.75, -20.0],
	[88.2, -1.0, 1.7, 15.0], [89.5, -1.0, 1.35, -40.0], [90.9, -1.0, 1.55, 70.0],
	[97.4, 1.0, 1.4, -10.0], [98.8, 1.0, 1.8, 30.0], [100.6, 1.0, 1.3, -60.0], [101.9, 1.0, 1.6, 5.0],
	[106.0, -1.0, 1.5, 40.0], [107.4, -1.0, 1.75, -15.0], [109.0, -1.0, 1.3, 60.0],
]
## Il relitto (la prima curva a U): l'ancora gigante ritta contro il muro esterno, tenuta da due staffe e illuminata
## da una lampada; il salvagente sul suo asse di legno; il forziere sulla banchina interna. (La rete con le stelle di
## Meshy è venuta male, quattro bastoni senza rete né stelle: non si usa.)
const ANCORA := [127.0, -1.0, 2.0]
const SALVAGENTE := [140.6, -1.0, 1.0, 1.1]  # s, lato, scala, quota del bordo basso sopra il piano
const FORZIERE := [152.5, 1.0, 1.6]
## Il palombaro su un basamento contro il muro, girato verso il canale.
const PALOMBARO := [190.0, 1.0, 1.2]
const BASAMENTO := Vector3(1.25, 0.35, 1.25)


static func passi(sala: SalaSottomarino) -> Array:
	return [_coralli.bind(sala), _relitto.bind(sala), _palombaro.bind(sala)]


static func _coralli(sala: SalaSottomarino) -> void:
	var nodo := Node3D.new()
	nodo.name = "Coralli"
	sala.add_child(nodo)
	for c in CORALLI:
		var n := _contro_il_muro(sala, nodo, "corallo", float(c[0]), float(c[1]), float(c[2]), float(c[3]))
		n.name = "Corallo_%d" % int(c[0] * 10.0)


static func _relitto(sala: SalaSottomarino) -> void:
	var nodo := Node3D.new()
	nodo.name = "Relitto"
	sala.add_child(nodo)
	var ancora := _contro_il_muro(sala, nodo, "ancora", ANCORA[0], ANCORA[1], ANCORA[2], 0.0)
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
	# la lampada a gabbia sopra l'ancora: fra una lampada del tunnel e l'altra qui era buio
	sala._lampada(nodo, ANCORA[0], ANCORA[1], sala.piano + 1.5 * float(ANCORA[2]) + 0.45, 3.0)
	# il salvagente del relitto, col suo asse di legno (gancio e cima compresi nel modello) fissato al muro, vicino
	# alla lampada
	var salv := _contro_il_muro(sala, nodo, "salvagente", SALVAGENTE[0], SALVAGENTE[1], SALVAGENTE[2], 0.0, float(SALVAGENTE[3]))
	salv.name = "Salvagente"
	var forziere := _contro_il_muro(sala, nodo, "forziere", FORZIERE[0], FORZIERE[1], FORZIERE[2], 0.0)
	forziere.name = "Forziere"


static func _palombaro(sala: SalaSottomarino) -> void:
	var nodo := Node3D.new()
	nodo.name = "SalaPalombaro"
	sala.add_child(nodo)
	var s: float = PALOMBARO[0]
	var lato: float = PALOMBARO[1]
	var r := sala.destra(s) * lato
	# il basamento di graniglia contro il muro
	var base := StaticBody3D.new()
	base.name = "Basamento"
	base.collision_layer = Layers.WORLD
	nodo.add_child(base)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = BASAMENTO
	mi.mesh = bm
	mi.material_override = sala.mat_graniglia
	base.add_child(mi)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = BASAMENTO
	cs.shape = box
	base.add_child(cs)
	var p := sala.punto(s)
	base.global_transform = Transform3D(Basis.looking_at(-r, Vector3.UP),
			sala._al(p, sala.destra(s), Vector2(lato * (sala.muro - BASAMENTO.z * 0.5), sala.piano + BASAMENTO.y * 0.5)))
	var pal := sala._modello(nodo, "palombaro", base.global_position + Vector3.UP * 1.0, -r, float(PALOMBARO[2]))
	pal.name = "Palombaro"
	Posa.appoggia_a_terra(pal, 0.0, true)
	sala._collisione_modello(pal)


## Un modello del fiume B contro il muro dal lato [param lato] a [param s], girato verso il canale (più [param giro]
## gradi attorno alla verticale): il retro a contatto col muro, poi giù sul pavimento della banchina, oppure fermo a
## [param su] metri sopra il piano (le cose appese).
static func _contro_il_muro(sala: SalaSottomarino, nodo: Node3D, nome: String, s: float, lato: float, scala: float,
		giro: float, su := -1.0) -> Node3D:
	var p := sala.punto(s)
	var r := sala.destra(s) * lato
	var verso := (-r).rotated(Vector3.UP, deg_to_rad(giro))
	var quota := sala.piano + (su if su >= 0.0 else 1.0)
	var n := sala._modello(nodo, nome, sala._al(p, sala.destra(s), Vector2(lato * (sala.muro - 0.8), quota)), verso, scala)
	# quanto sporge il retro del modello dietro l'origine, lungo la normale del muro
	var dietro := 0.0
	var inv := n.global_transform.affine_inverse()
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mm := m as MeshInstance3D
		var xf := mm.global_transform
		for v in mm.mesh.get_faces():
			dietro = maxf(dietro, ((xf * v) - n.global_position).dot(r))
	var appeso := nome in ["ancora", "salvagente"]
	if not Posa.fissa_al_muro(n, -r, dietro if appeso else dietro + DAL_MURO, false):
		push_warning("arredi sottomarino: %s a %.1f senza muro" % [nome, s])
	if su < 0.0:
		Posa.appoggia_a_terra(n, 0.0, false)
	n.set_meta(&"giro", giro)
	sala._collisione_modello(n)
	return n

