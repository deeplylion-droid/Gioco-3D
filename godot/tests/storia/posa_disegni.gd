extends Node
## Calcola dove va un disegno del bambino (DisegnoBambino) con lo strumento comune (Posa): carica la scena della zona,
## mette il foglio nel punto indicato, lo porta a contatto col muro (Posa.fissa_al_muro, la superficie che si vede) e
## controlla che il muro sia piano sotto tutto il foglio (25 raggi: nessuno più di 3 mm fuori, niente davanti); trova il
## pavimento sotto e l'altezza del centro; appoggia il pastello (Posa.appoggia_a_terra). Stampa i valori da scrivere
## nella scena (nel sistema della scena caricata). Un oggetto che sta fermo si posa una volta così e il posto si scrive
## nel codice (regola di docs/tecnico/posizionamento/LEGGIMI.md).
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/storia/posa_disegni.gd <scena> \
##      "x,y,z" "verso x,y,z" [A3|A4|A3_ORIZZONTALE] [pastello x,z]

func _ready() -> void:
	_run.call_deferred()


func _v(s: String) -> Vector3:
	var c := s.split(",")
	return Vector3(float(c[0]), float(c[1]), float(c[2]))


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var scena := (load(args[1]) as PackedScene).instantiate() as Node3D
	add_child(scena)
	for i in 10:
		await get_tree().physics_frame
	var verso := _v(args[3]).normalized()
	var d := DisegnoBambino.new()
	d.name = "DisegnoProva"
	d.formato = DisegnoBambino.Formato.A3
	if args.size() > 4 and args[4] in DisegnoBambino.Formato:
		d.formato = DisegnoBambino.Formato[args[4]]
	scena.add_child(d)
	d.global_position = _v(args[2])
	d.global_basis = Basis.looking_at(-verso, Vector3.UP)     # il foglio guarda verso +Z del nodo = verso
	var ok := Posa.fissa_al_muro(d, verso)
	await get_tree().physics_frame
	var m := d.misura()
	var space := scena.get_world_3d().direct_space_state
	# il muro sotto tutto il foglio: 25 punti, ognuno messo a contatto da Posa (col foglio nascosto, che non si colpisca
	# da solo); il foglio va sul muro che si vede (la mediana) e lo scarto massimo dice se è piano
	d.visible = false
	var scarti: Array[float] = []
	var davanti := []
	for i in 5:
		for j in 5:
			var loc := Vector3((i / 4.0 - 0.5) * m.x, (j / 4.0 - 0.5) * m.y, 0.0)
			var q := Node3D.new()
			scena.add_child(q)
			q.global_position = d.to_global(loc)
			Posa.fissa_al_muro(q, verso)
			scarti.append(d.to_local(q.global_position).z)
			# qualcosa davanti al foglio (fino a 40 cm)?
			var h := space.intersect_ray(PhysicsRayQueryParameters3D.create(d.to_global(loc) + verso * 0.4, d.to_global(loc) + verso * 0.03))
			if h:
				davanti.append([loc, (h.collider as Node).name])
			q.queue_free()
	var ordinati := scarti.duplicate()
	ordinati.sort()
	var mediana: float = ordinati[ordinati.size() / 2]
	d.global_position += verso * mediana
	var peggio := 0.0
	for k in scarti.size():
		peggio = maxf(peggio, absf(scarti[k] - mediana))
		if absf(scarti[k] - mediana) > 0.003:
			print("POSA   fuori di %.4f m nel punto %d del foglio" % [scarti[k] - mediana, k])
	d.visible = true
	if OS.has_environment("PROFILO"):
		# il profilo del muro in verticale, al centro del foglio, da 60 cm sotto a 60 cm sopra
		d.visible = false
		for k in 61:
			var q := Node3D.new()
			scena.add_child(q)
			q.global_position = d.to_global(Vector3(0, -0.6 + 0.02 * k, 0))
			Posa.fissa_al_muro(q, verso)
			print("POSA profilo y %.2f: %.4f" % [q.global_position.y, d.to_local(q.global_position).z])
			q.queue_free()
		d.visible = true
	var giu := space.intersect_ray(PhysicsRayQueryParameters3D.create(d.global_position + verso * 0.25, d.global_position + verso * 0.25 + Vector3.DOWN * 3.0))
	var pavimento: float = (giu.position as Vector3).y if giu else NAN
	print("POSA ok %s" % ok)
	print("POSA origine (nella scena) %s" % scena.to_local(d.global_position))
	print("POSA basis %s" % (scena.global_basis.inverse() * d.global_basis))
	print("POSA muro piano: scarto massimo %.4f m; davanti: %s" % [peggio, davanti])
	print("POSA pavimento y %.4f, altezza del centro %.4f" % [pavimento, d.global_position.y - pavimento])
	if args.size() > 5:
		var c := args[5].split(",")
		var p := (load(DisegnoBambino.PASTELLO) as PackedScene).instantiate() as Node3D
		scena.add_child(p)
		p.global_position = d.to_global(Vector3(float(c[0]), 0.0, float(c[1]))) + Vector3.UP * 0.2
		var okp := Posa.appoggia_a_terra(p)
		print("POSA pastello ok %s, y %.4f (pavimento %.4f)" % [okp, p.global_position.y, pavimento])
	get_tree().quit()
