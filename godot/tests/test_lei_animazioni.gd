extends Node
## Test delle animazioni di lei per l'inseguimento (tools/blender/medusa_inseguimento.py, libreria
## assets/models/medusa/medusa_inseguimento.res), sul modello vero dentro una MedusaAffacciata:
## 1. la libreria c'è, con le 8 animazioni, le durate e i cicli giusti;
## 2. la salita parte 5 m sotto e finisce nella posa iniziale di incombe; respinta e scende finiscono 5 m
##    sotto; incombe e colpo_grata girano in tondo senza scatti;
## 3. la presa chiude le mani davanti, dove c'è chi è nella vasca, e apre la fauce;
## 4. colpo_grata batte i palmi sul piano della grata senza attraversarlo;
## 5. in SB1 le mani restano sul bordo del pozzo e l'occhio sopra;
## 6. le zampe incrociate sul petto restano sul petto in tutte (regola del GDD: il seno resta coperto).
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_lei_animazioni.gd

const DURATE := {
	&"sale_dall_acqua": 1.6, &"sale_dall_acqua_veloce": 1.0, &"incombe": 2.4, &"presa": 1.2,
	&"respinta": 1.2, &"scende": 1.0, &"colpo_grata": 0.5, &"affacciata_sb1": 5.4,
}
const IN_CICLO := [&"incombe", &"colpo_grata"]
## Gli stessi valori di tools/blender/medusa_inseguimento.py (lei guarda verso +Z).
const GRAB := Vector3(0.0, 3.85, 2.4)
const GRATA := 2.3
const BORDO_SB1 := Vector2(1.0, 0.8)    # davanti, in alto

var lei: MedusaAffacciata
var ap: AnimationPlayer
var sk: Skeleton3D
var _passed := 0
var _failed := 0


func _ready() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
		print("  ok    ", what)
	else:
		_failed += 1
		printerr("  FALLITO ", what)


func _run() -> void:
	lei = MedusaAffacciata.new()
	lei.model = load("res://assets/models/medusa/medusa.glb")
	lei.animazioni_inseguimento = true
	lei.animazione = &"inseguimento/incombe"
	add_child(lei)
	await get_tree().process_frame
	ap = lei.get_model_instance().find_child("AnimationPlayer", true, false) as AnimationPlayer
	sk = lei.get_model_instance().find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D

	print("La libreria")
	check(ap.has_animation_library(&"inseguimento"), "le animazioni dell'inseguimento sono nell'AnimationPlayer di lei")
	for nome: StringName in DURATE:
		var a := ap.get_animation(StringName("inseguimento/" + nome))
		check(a != null and absf(a.length - float(DURATE[nome])) < 0.01
				and (a.loop_mode == Animation.LOOP_LINEAR) == IN_CICLO.has(nome),
			"%s: %.1f s%s" % [nome, float(DURATE[nome]), ", in ciclo" if IN_CICLO.has(nome) else ""])

	print("Su e giù, raccordi e cicli")
	var su := _ossa(&"incombe", 0.0)
	var fine_sale := _ossa(&"sale_dall_acqua", 1.6)
	var fine_veloce := _ossa(&"sale_dall_acqua_veloce", 1.0)
	var sc1 := _scarto(fine_sale, su)
	var p1 := peggiore
	check(sc1 < 0.03 and _scarto(fine_veloce, su) < 0.03,
		"la salita finisce nella posa iniziale di incombe (scarto %.3f m, %s)" % [maxf(sc1, _scarto(fine_veloce, su)), p1])
	check(_ossa(&"sale_dall_acqua", 0.0)["radice"].y < su["radice"].y - 4.5, "e parte 5 m più sotto, sott'acqua")
	check(_ossa(&"respinta", 1.2)["radice"].y < su["radice"].y - 4.5 and _ossa(&"scende", 1.0)["radice"].y < su["radice"].y - 4.5,
		"respinta e scende finiscono 5 m sotto")
	for nome in [&"presa", &"respinta", &"scende"]:
		var sc := _scarto(_ossa(nome, 0.0), su)
		check(sc < 0.03, "%s parte dalla posa di incombe (scarto %.3f m, %s)" % [nome, sc, peggiore])
	check(_scarto(_ossa(&"incombe", 2.4 - 0.001), su) < 0.02 and _scarto(_ossa(&"colpo_grata", 0.5 - 0.001), _ossa(&"colpo_grata", 0.0)) < 0.02,
		"incombe e colpo_grata finiscono come cominciano (ciclo senza scatti)")
	check(su["occhio"].y > 3.38 + 0.8, "da su l'occhio è ben sopra l'acqua della vasca (%.2f m)" % su["occhio"].y)
	var salto := 0.0
	var dove := ""
	for nome: StringName in DURATE:
		if nome == &"colpo_grata":
			continue    # lo schiaffo è veloce di proposito: sotto
		var v := _salto_massimo(nome)
		if v > salto:
			salto = v
			dove = "%s, %s" % [nome, peggiore]
	check(salto < 0.35, "nessun osso salta di colpo tra un fotogramma e l'altro (al massimo %.2f m: %s)" % [salto, dove])
	var schiaffo := _salto_massimo(&"colpo_grata")
	check(schiaffo < 0.5, "lo schiaffo alla grata è secco ma senza scatti (al massimo %.2f m in un fotogramma: %s)" % [schiaffo, peggiore])

	print("La presa")
	var presa := _ossa(&"presa", 0.6)
	var dl: float = presa["mano.L"].distance_to(GRAB)
	var dr: float = presa["mano.R"].distance_to(GRAB)
	check(dl < 0.45 and dr < 0.45, "le mani si chiudono davanti a lei, intorno a chi è nella vasca (%.2f e %.2f m)" % [dl, dr])
	var fauce := false
	var a := ap.get_animation(&"inseguimento/presa")
	for i in a.get_track_count():
		fauce = fauce or a.track_get_type(i) == Animation.TYPE_BLEND_SHAPE
	check(fauce, "e la fauce si apre (blend shape di fauce_apre)")

	print("La grata")
	var oltre := -99.0
	var contatto := -99.0
	for k in 16:
		var o := _ossa(&"colpo_grata", 0.5 * k / 16.0, true)
		for n in o:
			oltre = maxf(oltre, (o[n] as Vector3).z)
		contatto = maxf(contatto, minf((o["mano.L"] as Vector3).z, (o["mano.R"] as Vector3).z))
	check(contatto > GRATA - 0.35, "i palmi arrivano alla grata (polsi a %.2f m, grata a %.1f m)" % [contatto, GRATA])
	check(oltre < GRATA + 0.03, "e niente la attraversa (al massimo a %.2f m)" % oltre)

	print("SB1")
	var peggio := 0.0
	var occhio_basso := 99.0
	for t in [1.4, 2.0, 3.0, 4.5, 5.4]:
		var o := _ossa(&"affacciata_sb1", t)
		for s in [1, -1]:
			var mano: Vector3 = o["mano.L" if s > 0 else "mano.R"]
			peggio = maxf(peggio, mano.distance_to(Vector3(s * 0.58, BORDO_SB1.y + 0.04, BORDO_SB1.x + 0.12)))
		occhio_basso = minf(occhio_basso, (o["occhio"] as Vector3).y)
	check(peggio < 0.12, "le mani restano sul bordo del pozzo (al massimo a %.2f m)" % peggio)
	check(occhio_basso > BORDO_SB1.y + 0.3, "e l'occhio sta sopra il bordo (%.2f m)" % occhio_basso)

	print("Le zampe sul petto")
	# come stanno nella posa approvata insegue, rispetto al petto
	ap.play(&"insegue")
	ap.seek(0.0, true)
	ap.advance(0.0)
	_rif_zampe = _zampe_nel_petto()
	var lontano := 0.0
	var dove_z := ""
	for nome: StringName in DURATE:
		for k in 9:
			_ossa(nome, float(DURATE[nome]) * k / 8.0)
			var v := _zampe_dal_petto()
			if v > lontano:
				lontano = v
				dove_z = "%s a %.2f s" % [nome, float(DURATE[nome]) * k / 8.0]
	check(lontano < 0.10, "le due zampe incrociate restano sul petto come nella posa insegue, in tutte le animazioni (al massimo %.2f m di scarto: %s)" % [lontano, dove_z])

	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


## Posizioni (spazio di lei) delle ossa all'istante t dell'animazione.
func _ossa(nome: StringName, t: float, tutte := false) -> Dictionary:
	ap.play(StringName("inseguimento/" + nome))
	ap.seek(t, true)
	ap.advance(0.0)
	var out := {}
	var tr := lei.global_transform.affine_inverse() * sk.global_transform
	for i in sk.get_bone_count():
		var n := sk.get_bone_name(i)
		if tutte or not n.begins_with("tentacolo") or n.begins_with("tentacolo_01_") or n.begins_with("tentacolo_06_"):
			out[n] = tr * sk.get_bone_global_pose(i).origin
	return out


var peggiore := ""   # l'osso che sbaglia di più nell'ultimo controllo (per i messaggi)


func _scarto(a: Dictionary, b: Dictionary) -> float:
	var m := 0.0
	for n in a:
		if b.has(n) and (a[n] as Vector3).distance_to(b[n]) > m:
			m = (a[n] as Vector3).distance_to(b[n])
			peggiore = n
	return m


func _salto_massimo(nome: StringName) -> float:
	var a := ap.get_animation(StringName("inseguimento/" + nome))
	var m := 0.0
	var prima := _ossa(nome, 0.0)
	var n := int(round(a.length * 30.0))
	for k in range(1, n + 1):
		var ora := _ossa(nome, minf(k / 30.0, a.length - 0.0001))
		for b in ora:
			if b != "radice":   # la radice sale e scende in fretta di proposito
				var v: float = (ora[b] as Vector3).distance_to(prima[b]) - (ora["radice"] as Vector3).distance_to(prima["radice"])
				if v > m:
					m = v
					peggiore = "%s a %.2f s" % [b, k / 30.0]
		prima = ora
	return m


## Le ossa delle zampe che passano sul busto e sulla spalla: ognuna nel riferimento dell'osso del busto su
## cui è appoggiata (il più vicino nella posa insegue), come in tools/blender/medusa_inseguimento.py.
const OSSA_ZAMPE := ["tentacolo_01_02", "tentacolo_01_03", "tentacolo_01_04", "tentacolo_01_05",
	"tentacolo_06_02", "tentacolo_06_03", "tentacolo_06_04", "tentacolo_06_05"]
const BUSTO := ["colonna_1", "colonna_2", "petto", "collo", "clavicola.L", "clavicola.R", "campana"]
var _rif_zampe := {}
var _appoggio := {}


func _zampe_nel_petto() -> Dictionary:
	if _appoggio.is_empty():
		for n in OSSA_ZAMPE:
			var p := sk.get_bone_global_pose(sk.find_bone(n)).origin
			var meglio := ""
			var dmin := 99.0
			for b in BUSTO:
				var i := sk.find_bone(b)
				var h := sk.get_bone_global_pose(i).origin
				var figli := sk.get_bone_children(i)
				var c := sk.get_bone_global_pose(figli[0]).origin if figli.size() > 0 else h
				var d := Geometry3D.get_closest_point_to_segment(p, h, c).distance_to(p)
				if d < dmin:
					dmin = d
					meglio = b
			_appoggio[n] = meglio
	var out := {}
	for n in OSSA_ZAMPE:
		var rif := sk.get_bone_global_pose(sk.find_bone(_appoggio[n])).affine_inverse()
		out[n] = rif * sk.get_bone_global_pose(sk.find_bone(n)).origin
	return out


## Quanto si spostano le zampe sul petto rispetto alla posa insegue (dopo _ossa()).
func _zampe_dal_petto() -> float:
	var ora := _zampe_nel_petto()
	var m := 0.0
	for n in ora:
		m = maxf(m, (ora[n] as Vector3).distance_to(_rif_zampe[n]))
	return m
