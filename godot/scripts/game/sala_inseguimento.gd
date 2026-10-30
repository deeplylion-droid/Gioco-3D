class_name SalaInseguimento
extends Node3D
## L'inseguimento I1 e il finale SB1 (scelta dell'utente del 19 ottobre: la versione A, "Le condotte"):
## la sala macchine allagata dietro il muro est della torre. Si scivola in tubi chiusi tra tre vasche
## sospese; a ogni vasca due paratie col bersaglio (la giusta con la lampada e l'anello di led verdi, la
## sbagliata con la lampada rossa guasta), lei ti raggiunge nelle vasche e un getto in faccia la respinge;
## la spirale scende al bacino, la grata cala davanti a lei e, verso la scaletta, lei sbuca dal pozzo di
## scarico e ti guarda (SB1): nero, fine del capitolo ([signal capitolo_finito]).
##
## La geometria viene da tools/blender/inseguimento_proposte.py A --gioco (assets/ambiente/inseguimento/):
## - inseguimento_struttura.glb (con le collisioni), _tubi.glb (solo da vedere: la collisione dei tubi la fa
##   questo script lungo le loro linee), _prop.glb, _mobili.glb (i pannelli delle paratie e la grata);
## - inseguimento_gioco.json: linee dei tubi, paratie, grata, vasche, checkpoint, pozzo, scala, porta;
## - inseguimento_luci.json: le luci e gli arredi (oggetti veri della sala pompe e del kit di dettagli).
## Le coordinate dei JSON sono di Blender: (x, y, z) diventa (x, z, -y).
##
## Le regole (docs/proposte/inseguimento/inseguimento.md):
## - nei tubi (Ø 1,6 m) si scivola accovacciati: lei, alta 4,5 m, lì non entra;
## - le paratie si aprono tenendo il getto sul bersaglio per [member getto_per_aprire] secondi;
## - nelle vasche lei sale dall'acqua del fondo: da quando compare hai [member tempo_presa] secondi, un getto
##   in faccia la ricaccia sotto e torna dopo [member ritorno_dopo] secondi se sei ancora lì;
## - la paratia sbagliata porta a una vasca di scolo senza uscita: lì lei ti prende;
## - checkpoint in ogni vasca e nel bacino, dopo la grata.

signal capitolo_finito
## Una paratia ha cominciato ad aprirsi ([param giusta]: la strada vera).
signal paratia_aperta(indice: int, giusta: bool)
signal lei_compare(dove: String)
signal lei_respinta
signal grata_calata
signal sb1_iniziato
## Dopo SB1 il capitolo continua nel tunnel del viaggio sottomarino ([member dopo_sb1_continua]): lei si è tuffata,
## i comandi sono tornati, la scaletta e la porta sono accese.
signal sb1_finito
## SB1 aspetta il tunnel non ancora pronto (AttesaZone): chi lo costruisce faccia più svelto.
signal sb1_in_attesa

const DIR := "res://assets/ambiente/inseguimento/"
const ROSSO := Color(1.0, 0.035, 0.02)
const CALDO := Color(1.0, 0.66, 0.36)
const ROSA := Color(1.0, 0.32, 0.62)
const VERDE := Color(0.25, 1.0, 0.45)
const R_TUBO := 0.78

## Ordine del primo checkpoint (dopo quelli della torre, che partono da 20).
@export var ordine_base := 40
## Secondi di getto sul bersaglio per aprire una paratia.
@export var getto_per_aprire := 1.5
## Secondi per alzarsi: di solito, e la giusta della vasca 2 (sale piano: lì lei arriva subito).
@export var apertura := 1.0
@export var apertura_lenta := 3.0
## Lei: da quando è su, quanto ci mette a prenderti; dopo un getto in faccia, fra quanto torna.
@export var tempo_presa := 6.0
@export var ritorno_dopo := 9.0
## Litri di getto in faccia (circa mezzo secondo) per ricacciarla sotto.
@export var getto_in_faccia := 0.6
## Dopo quanti secondi nella vasca compare la prima volta (vasca 1, 2, 3).
@export var comparsa := PackedFloat32Array([20.0, 1.5, 4.0])
## Le luci (le macchine lente nei test le possono spegnere).
@export var crea_luci := true
## Vero: dopo SB1 il capitolo continua oltre la porta in cima alla scaletta, nel tunnel del viaggio sottomarino
## (scelte dell'utente del 24 ottobre): lei ti fissa, poi si tuffa e ti ridà i comandi, e la scaletta e la porta si
## accendono. Falso: nero e fine del capitolo, come prima.
@export var dopo_sb1_continua := false
## I quattro GLB (struttura, tubi, prop, mobili): nella scena, così si caricano col thread insieme a lei.
## Vuoto: si caricano da DIR.
@export var modelli: Array[PackedScene] = []

var dati := {}
var luci_dati := {}
var checkpoint: Array[Checkpoint] = []
## Le paratie: dizionari con i dati del JSON più i nodi (pannello, bersaglio) e lo stato.
var paratie: Array[Dictionary] = []
var grata: Node3D
var grata_giu := false
## Lei: la medusa vera, una sola, che compare dove serve.
var lei: MedusaAffacciata
var finito := false

enum Lei { VIA, SALE, SU, SCENDE, PRESA }
var lei_stato := Lei.VIA
var _lei_t := 0.0
var _lei_dove := ""
var _lei_su := Vector3.ZERO
var _lei_giu := Vector3.ZERO
var _lei_luce: OmniLight3D
var _lei_testa: WaterHitbox
## Il movimento secondario di tentacoli e campana di lei (MorbidezzaLei).
var _morbidezza: MorbidezzaLei
const FORME_LEI := "res://assets/ambiente/inseguimento/inseguimento_forme_lei.json"
var _forme_lei_cache := {}
var _forme_lei_fori := {}
var _forme_lei_convessi := {}
var _getto_preso := 0.0
var _vasca := -1                       ## la vasca dove sei (-1 fuori)
var _in_vasca_t := 0.0
var _ritorno := -1.0
var _scolo := false
var _linee_tubi: Array[PackedVector3Array] = []
var _sb1 := false
var _fade: ColorRect


static func b(v: Array) -> Vector3:
	return Vector3(float(v[0]), float(v[2]), -float(v[1]))


## Vero quando la sala è costruita del tutto.
var costruita := false
## Se vero, _ready non costruisce niente: la costruisce chi la aggiunge con [method costruisci_a_pezzi]
## (la sala della torre, mentre la torre si prepara nascosta: senza fotogrammi lunghi).
var costruzione_a_pezzi := false
var _a_pezzi := false
var _coda: Array = []


func _ready() -> void:
	dati = JSON.parse_string(FileAccess.get_file_as_string(DIR + "inseguimento_gioco.json"))
	luci_dati = JSON.parse_string(FileAccess.get_file_as_string(DIR + "inseguimento_luci.json"))
	if not costruzione_a_pezzi:
		for passo in _passi():
			(passo as Callable).call()
		costruita = true


## I passi della costruzione a pezzi che sono durati più di 50 ms: [nome, ms] (per i test dei blocchi).
var passi_lunghi: Array = []
var _nome_passo := ""


## La costruzione divisa in passi brevi, uno per fotogramma (al più [param ms_per_fotogramma] ms di fila).
func costruisci_a_pezzi(ms_per_fotogramma := 8.0) -> void:
	_a_pezzi = true
	var t0 := Time.get_ticks_usec()
	_coda = _passi()
	var k := 0
	while not _coda.is_empty():
		var tp := Time.get_ticks_usec()
		var passo: Callable = _coda.pop_front()
		_nome_passo = ""
		passo.call()
		var ms := (Time.get_ticks_usec() - tp) / 1000.0
		var nome := _nome_passo if _nome_passo != "" else String(passo.get_method())
		if ms > 50.0:
			passi_lunghi.append([nome, ms])
		if OS.has_environment("TORRE_TEMPI"):
			print("inseguimento passo %d (%s): %.1f ms" % [k, nome, ms])
		k += 1
		if (Time.get_ticks_usec() - t0) / 1000.0 >= ms_per_fotogramma:
			await get_tree().process_frame
			# tolta dall'albero mentre si costruiva (una morte ricarica la sala): non serve più, come nella torre
			if not is_inside_tree():
				return
			t0 = Time.get_ticks_usec()
	costruita = true


func _passi() -> Array:
	var out: Array = []
	for i in 4:
		out.append(func(): _modello(i))
	out.append(_tubi)
	out.append_array([_acque, _paratie, _grata, _scala, _checkpoint, _scolo_zone, _bacino, _lei_crea, _lei_parti, _lei_morbida])
	if crea_luci:
		out.append_array(_passi_luci())
	return out


## Mette nella sala il GLB [param i] (struttura, tubi, prop, mobili). A pezzi entra vuoto e i suoi nodi lo
## raggiungono uno per passo (come nella torre).
func _modello(i: int) -> void:
	var nome: String = ["struttura", "tubi", "prop", "mobili"][i]
	_nome_passo = "_modello(%s)" % nome
	var scena: PackedScene = modelli[i] if i < modelli.size() and modelli[i] else load(DIR + "inseguimento_%s.glb" % nome)
	var glb: Node3D = scena.instantiate()
	glb.name = "Inseguimento" + nome.capitalize()
	# nelle vasche (e negli scoli e nel bacino) l'acqua meno torbida, verde-azzurra, col fondo che si
	# intravede (scelta dell'utente del 22 ottobre); il fondo allagato della sala resta torbido: da lì sale lei
	var acqua: Material = load("res://assets/materials/inseguimento/acqua_inseguimento.tres")
	var torbida: Material = load("res://assets/materials/sala/acqua_torbida.tres")
	for m in glb.find_children("acqua*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).material_override = torbida if String(m.name).begins_with("acqua_allagata") else acqua
	if nome == "struttura":
		_varco_scalette(glb)
	if _a_pezzi:
		var figli := glb.get_children()
		var proprietari := {}
		for c in figli:
			# (l'owner si toglie prima e si rimette dopo: rimesso dentro con l'owner di prima, Godot avvisava "owner
			# inconsistent" per ogni pezzo)
			proprietari[c] = c.owner
			c.owner = null
			glb.remove_child(c)
		var passi: Array = []
		for c in figli:
			passi.append(func():
				glb.add_child(c)
				if is_instance_valid(proprietari[c]) and (proprietari[c] as Node).is_ancestor_of(c):
					c.owner = proprietari[c])
		_coda = passi + _coda
	add_child(glb)


## Toglie dalla collisione della struttura i montanti e i pioli delle scalette (restano da vedere): in cima i
## montanti salgono 1 m sopra la passerella a 0,5 m l'uno dall'altro, e il giocatore, largo 0,7 m, scavalcando il
## bordo restava incastrato fra i due (collaudo T1). Sulla scala lo tiene già l'area della scala (Ladder).
func _varco_scalette(glb: Node3D) -> void:
	for sb in glb.find_children("*", "StaticBody3D", true, false):
		for cs in sb.get_children():
			if not cs is CollisionShape3D or not (cs as CollisionShape3D).shape is ConcavePolygonShape3D:
				continue
			# la forma nelle coordinate della sala (il GLB entra nella sala senza spostamenti)
			var t := Transform3D.IDENTITY
			var n: Node = cs
			while n != glb:
				t = (n as Node3D).transform * t
				n = n.get_parent()
			t = glb.transform * t
			var facce := ((cs as CollisionShape3D).shape as ConcavePolygonShape3D).get_faces()
			var tenute := PackedVector3Array()
			for i in range(0, facce.size(), 3):
				if not (_nella_scaletta(t * facce[i]) and _nella_scaletta(t * facce[i + 1]) and _nella_scaletta(t * facce[i + 2])):
					tenute.append_array([facce[i], facce[i + 1], facce[i + 2]])
			if tenute.size() < facce.size():
				var forma := ConcavePolygonShape3D.new()
				forma.backface_collision = ((cs as CollisionShape3D).shape as ConcavePolygonShape3D).backface_collision
				forma.set_faces(tenute)
				(cs as CollisionShape3D).shape = forma


## Vero se [param q] (coordinate della sala) sta sul modello di una scaletta: fino a 30 cm dietro il suo piede,
## largo 0,8 m, dal piede a 1,5 m sopra la cima.
func _nella_scaletta(q: Vector3) -> bool:
	for s in dati["scale"]:
		var piede := b([s["x"], s["y"], s["z0"]])
		var verso := b(s["verso"])
		var d := q - piede
		var lungo := d.dot(verso)
		if lungo > -0.3 and lungo < 0.02 and absf(d.dot(verso.cross(Vector3.UP))) < 0.4 \
				and q.y > piede.y - 0.5 and q.y < float(s["z1"]) + 1.5:
			return true
	return false


# --- tubi -------------------------------------------------------------------------------------------

## Un corpo "scivolo" per ogni tubo: l'anello intero lungo la linea del centro. Si scivola sul fondo; i
## fianchi ripidi sono sponde e la parte alta fa da soffitto (accovacciati non ci si alza).
func _tubi() -> void:
	for nome in dati["tubi"]:
		var pts := PackedVector3Array()
		for q in dati["tubi"][nome]:
			pts.append(b(q))
		_linee_tubi.append(pts)
		add_child(corpo_tubo(String(nome), pts, R_TUBO))


static func corpo_tubo(nome: String, linea: PackedVector3Array, r: float) -> StaticBody3D:
	var colonne := 20
	var facce := PackedVector3Array()
	var anelli: Array[PackedVector3Array] = []
	for i in linea.size():
		var t := (linea[mini(i + 1, linea.size() - 1)] - linea[maxi(i - 1, 0)]).normalized()
		var lato := t.cross(Vector3.UP).normalized()
		var su := lato.cross(t).normalized()
		var anello := PackedVector3Array()
		for k in colonne + 1:
			var a := TAU * k / colonne
			anello.append(linea[i] + lato * sin(a) * r - su * cos(a) * r)
		anelli.append(anello)
	for i in anelli.size() - 1:
		for k in colonne:
			facce.append_array([anelli[i][k], anelli[i + 1][k], anelli[i][k + 1],
					anelli[i][k + 1], anelli[i + 1][k], anelli[i + 1][k + 1]])
	var corpo := StaticBody3D.new()
	corpo.name = nome
	corpo.add_to_group(&"scivolo")
	corpo.set_meta(&"superficie", &"scivolo")
	corpo.set_meta(&"bagnato", true)
	var cs := CollisionShape3D.new()
	var forma := ConcavePolygonShape3D.new()
	forma.set_faces(facce)
	forma.backface_collision = true
	cs.shape = forma
	corpo.add_child(cs)
	return corpo


## Vero se [param pos] (i piedi) è dentro un tubo, o a meno di 60 cm davanti al suo imbocco: lì si sta
## accovacciati. Oltre la fine del tubo no (si esce nella vasca e ci si rialza).
func in_tubo(pos: Vector3) -> bool:
	var centro := pos + Vector3.UP * 0.5
	for linea in _linee_tubi:
		var i_min := -1
		var d_min := INF
		for i in linea.size():
			var d := centro.distance_squared_to(linea[i])
			if d < d_min:
				d_min = d
				i_min = i
		if d_min > 1.15 * 1.15:
			continue
		var ultimo := linea.size() - 1
		if i_min == ultimo and (centro - linea[ultimo]).dot((linea[ultimo] - linea[ultimo - 1]).normalized()) > 0.0:
			continue
		if i_min == 0 and (centro - linea[0]).dot((linea[0] - linea[1]).normalized()) > 0.6:
			continue
		return true
	return false


# --- acqua ------------------------------------------------------------------------------------------

func _acque() -> void:
	var volumi := []
	for v in dati["vasche"]:
		volumi.append([v["rett"], float(v["fondo"]), float(v["acqua"]), 0.18])
	for v in dati["scolo"]:
		volumi.append([v["rett"], float(v["fondo"]), float(v["acqua"]), 0.18])
	var bc: Dictionary = dati["bacino"]
	volumi.append([bc["rett"], float(bc["fondo"]), float(bc["acqua"]), 0.3])
	var lim: Array = dati["limiti"]
	var al: Dictionary = dati["allagato"]
	volumi.append([[lim[0], lim[1], lim[2], lim[3]], float(al["fondo"]), float(al["acqua"]), 0.0])
	var i := 0
	for v in volumi:
		var r: Array = v[0]
		var bordo: float = v[3]
		var w := WaterVolume.new()
		w.name = "Acqua%d" % i
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		var alto: float = v[2] - v[1]
		box.size = Vector3(r[2] - r[0] - 2.0 * bordo, alto, r[3] - r[1] - 2.0 * bordo)
		cs.shape = box
		w.add_child(cs)
		add_child(w)
		w.global_position = b([(r[0] + r[2]) / 2.0, (r[1] + r[3]) / 2.0, v[1] + alto / 2.0])
		i += 1


# --- paratie ----------------------------------------------------------------------------------------

func _paratie() -> void:
	var mobili := get_node("InseguimentoMobili")
	for k in dati["paratie"].size():
		var d: Dictionary = (dati["paratie"][k] as Dictionary).duplicate()
		var pannello := mobili.find_child(String(d["nodo"]), true, false) as Node3D
		d["indice"] = k
		d["pannello_nodo"] = pannello
		d["chiuso"] = pannello.global_position if pannello else Vector3.ZERO
		d["getto"] = 0.0
		d["aperta"] = 0.0          # 0 chiusa, 1 alzata del tutto
		d["apre"] = false
		var hb := WaterHitbox.new()
		hb.name = "Bersaglio%d" % k
		var cs := CollisionShape3D.new()
		var sf := SphereShape3D.new()
		sf.radius = 0.5
		cs.shape = sf
		hb.add_child(cs)
		add_child(hb)
		hb.global_position = b(d["bersaglio"])
		hb.water_hit.connect(func(litri: float, _p: Vector3, _dir: Vector3): _colpita(k, litri))
		d["bersaglio_nodo"] = hb
		paratie.append(d)


func _colpita(k: int, _litri: float) -> void:
	var d := paratie[k]
	if d["apre"]:
		return
	d["getto"] = float(d["getto"]) + get_physics_process_delta_time()
	if float(d["getto"]) >= getto_per_aprire:
		apri_paratia(k)


## Comincia ad alzare la paratia [param k] (il getto l'ha tenuta abbastanza, o un test).
func apri_paratia(k: int) -> void:
	var d := paratie[k]
	if d["apre"]:
		return
	d["apre"] = true
	paratia_aperta.emit(k, bool(d["giusta"]))


func _muovi_paratie(delta: float) -> void:
	for d in paratie:
		if not d["apre"] or float(d["aperta"]) >= 1.0:
			continue
		var lenta := bool(d["giusta"]) and int(d["vasca"]) == 1
		d["aperta"] = minf(float(d["aperta"]) + delta / (apertura_lenta if lenta else apertura), 1.0)
		var pn := d["pannello_nodo"] as Node3D
		if pn:
			pn.global_position = (d["chiuso"] as Vector3) + Vector3.UP * float(d["corsa"]) * smoothstep(0.0, 1.0, float(d["aperta"]))


# --- grata, scala, bacino ---------------------------------------------------------------------------

func _grata() -> void:
	var g: Dictionary = dati["grata"]
	grata = get_node("InseguimentoMobili").find_child(String(g["nodo"]), true, false) as Node3D


## La grata cala davanti alla bocca della spirale (dietro di te): lei ci sbatte contro.
func cala_grata() -> void:
	if grata_giu:
		return
	grata_giu = true
	grata_calata.emit()
	if grata:
		var tw := create_tween()
		tw.tween_property(grata, "global_position", grata.global_position + Vector3.DOWN * float(dati["grata"]["corsa"]), 0.6) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _scala() -> void:
	for s in dati["scale"]:
		var l := Ladder.new()
		l.name = "Scala"
		l.show_model = false
		l.height = float(s["z1"]) - float(s["z0"])
		add_child(l)
		l.global_position = b([s["x"], s["y"], s["z0"]])
		# la scala sta dal lato -Z del nodo: il +Z (verso chi sale) va lungo il verso della scala
		var verso := b(s["verso"])
		l.look_at(l.global_position - verso, Vector3.UP)


func _bacino() -> void:
	# entrando nel bacino la grata cala; vicino alla scaletta lei sbuca dal pozzo (SB1)
	var bc: Array = dati["bacino"]["rett"]
	var dentro := _area("Bacino", [bc[0] + 0.4, bc[1] + 0.4, bc[2] - 0.6, bc[3] - 0.4], float(dati["bacino"]["fondo"]), 3.0)
	dentro.body_entered.connect(func(corpo):
		if corpo is Player:
			cala_grata()
			_lei_alla_grata())
	var s: Dictionary = dati["scale"][0]
	var sb1 := _area("SB1", [float(s["x"]), float(s["y"]) - 1.2, float(s["x"]) + 2.0, float(s["y"]) + 1.2], float(s["z0"]), 3.0)
	sb1.body_entered.connect(func(corpo):
		if corpo is Player:
			inizia_sb1())


func _area(nome: String, r: Array, z0: float, alto: float) -> Area3D:
	var a := Area3D.new()
	a.name = nome
	a.collision_layer = 0
	a.collision_mask = Layers.PLAYER
	a.monitorable = false
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(r[2] - r[0], alto, r[3] - r[1])
	cs.shape = box
	a.add_child(cs)
	add_child(a)
	a.global_position = b([(r[0] + r[2]) / 2.0, (r[1] + r[3]) / 2.0, z0 + alto / 2.0])
	return a


# --- checkpoint -------------------------------------------------------------------------------------

func _checkpoint() -> void:
	var i := 0
	for cp in dati["checkpoint"]:
		var a := Checkpoint.new()
		a.name = "Checkpoint_%s" % String(cp["nome"])
		a.order = ordine_base + i
		var forma := CollisionShape3D.new()
		var box := BoxShape3D.new()
		var r: Array = cp["rett"]       # tutta la vasca (o il bacino)
		box.size = Vector3(r[2] - r[0], 2.4, r[3] - r[1])
		forma.shape = box
		a.add_child(forma)
		add_child(a)
		var pos := b(cp["pos"])
		a.global_position = pos
		forma.global_position = b([(r[0] + r[2]) / 2.0, (r[1] + r[3]) / 2.0, cp["pos"][2]]) + Vector3.UP * 1.2
		var rip := Marker3D.new()
		rip.name = "Ripartenza"
		a.add_child(rip)
		var guarda := b(cp["guarda"])
		guarda.y = pos.y
		if guarda.distance_to(pos) > 0.1:
			rip.look_at(guarda, Vector3.UP)
		a.spawn_point = rip
		checkpoint.append(a)
		i += 1


## Le vasche di scolo: entrandoci (dalla paratia sbagliata) lei arriva e ti prende.
func _scolo_zone() -> void:
	var k := 0
	for v in dati["scolo"]:
		var r: Array = v["rett"]
		var a := _area("Scolo%d" % k, r, float(v["fondo"]) - 0.2, 2.0)
		var kk := k
		a.body_entered.connect(func(corpo):
			if corpo is Player and not _scolo:
				_scolo = true
				_lei_sale("scolo_%d" % kk, _posto_scolo(kk), 1.2))
		k += 1


# --- lei --------------------------------------------------------------------------------------------

## I file di lei che [method _lei_crea] carica: la sala li chiede al thread insieme alla torre (SalaPrincipale), così
## qui load() li trova già pronti (caricati qui erano 230 ms di fotogramma fermo).
const RISORSE_LEI := ["res://assets/models/medusa/medusa.glb", "res://assets/models/medusa/medusa_campana.tres",
	"res://assets/models/medusa/medusa_capelli_bagnata.tres", "res://assets/models/medusa/medusa_ciocche_bagnata.tres",
	"res://assets/models/medusa/medusa_mani_bagnata.tres", "res://assets/models/medusa/medusa_occhio.tres",
	"res://assets/models/medusa/medusa_orbita_bagnata.tres", "res://assets/models/medusa/medusa_pelle_bagnata.tres",
	"res://assets/models/medusa/medusa_tentacoli_bagnata.tres"]


## Lei in tre passi della costruzione (il modello; la luce e il viso; il movimento secondario), così nessun fotogramma
## li paga tutti insieme. Il modello e i materiali sono quelli di LeiOblo, caricati col thread della zona (preload).
func _lei_crea() -> void:
	lei = MedusaAffacciata.new()
	lei.name = "Lei"
	lei.model = LeiOblo.MODELLO
	lei.bell_material = LeiOblo.CAMPANA
	lei.material_map = LeiOblo.MATERIALI.duplicate()
	# le animazioni dell'inseguimento (tools/blender/medusa_inseguimento.py): portano anche il su e giù
	lei.animazioni_inseguimento = true
	lei.animazione = &"inseguimento/incombe"
	lei.visible = false
	add_child(lei)


func _lei_parti() -> void:
	_lei_luce = OmniLight3D.new()
	_lei_luce.light_color = ROSA
	_lei_luce.light_energy = 6.0
	_lei_luce.omni_range = 9.0
	_lei_luce.light_volumetric_fog_energy = 3.0
	_lei_luce.shadow_enabled = true
	_lei_luce.position = Vector3(0, 2.4, 0.9)
	_lei_luce.set_meta(&"risveglio_ignora", true)
	lei.add_child(_lei_luce)
	# il viso: un getto lì la ricaccia sotto
	_lei_testa = WaterHitbox.new()
	_lei_testa.name = "Viso"
	var cs := CollisionShape3D.new()
	var sf := SphereShape3D.new()
	sf.radius = 0.9
	cs.shape = sf
	_lei_testa.add_child(cs)
	_lei_testa.position = Vector3(0, 3.4, 0.6)
	lei.add_child(_lei_testa)
	_lei_testa.water_hit.connect(func(litri: float, _p: Vector3, _d: Vector3):
		if lei_stato == Lei.SU or lei_stato == Lei.SALE:
			_getto_preso += litri
			if _getto_preso >= getto_in_faccia and not _dove_scolo():
				respingi())


func _lei_morbida() -> void:
	if not Engine.has_meta(&"morbidezza_spenta"):
		_morbidezza = MorbidezzaLei.su(lei)
		_forme_lei()   # (qui, con la sala: non quando lei sale, sarebbe un fotogramma lungo)


## Cambia la posa di lei (le animazioni del modello: "insegue", "affacciata").
func _posa(nome: StringName) -> void:
	lei.animazione = nome
	var ap := lei.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap and ap.has_animation(nome):
		ap.get_animation(nome).loop_mode = Animation.LOOP_LINEAR
		ap.play(nome)


## Fa partire un'animazione dell'inseguimento ("inseguimento/<nome>"), con una fusione di [param fondi]
## secondi da quella di prima. Ritorna la durata.
func _anima(nome: String, fondi := 0.0) -> float:
	var n := StringName("inseguimento/" + nome)
	lei.animazione = n
	var ap := lei.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap == null or not ap.has_animation(n):
		return 1.0
	ap.play(n, fondi)
	return ap.get_animation(n).length


func _dove_scolo() -> bool:
	return _lei_dove.begins_with("scolo")


## Dove sale lei per la vasca [param v]: le pose della proposta per la 1 e la 2, la 3 dal lato sud.
func _posto_vasca(v: int) -> Vector3:
	var L: Array = dati["lei"]
	match v:
		0:
			return b(L[0]["pos"])
		1:
			return b(L[1]["pos"])
		_:
			var r: Array = dati["vasche"][2]["rett"]
			return b([(r[0] + r[2]) / 2.0, r[1] - 2.3, float(dati["vasche"][2]["fondo"]) - 2.4])


func _posto_scolo(k: int) -> Vector3:
	var v: Dictionary = dati["scolo"][k]
	var r: Array = v["rett"]
	# accanto alla vasca, dalla parte del centro della sala
	var c := Vector2((r[0] + r[2]) / 2.0, (r[1] + r[3]) / 2.0)
	var verso := (Vector2(60.0, 15.0) - c).normalized()
	var mezzo := maxf(r[2] - r[0], r[3] - r[1]) / 2.0 + 1.6
	var rit: Array = RITOCCHI.get("scolo_%d" % k, [0.0, 0.0])
	return b([c.x + verso.x * mezzo + rit[0], c.y + verso.y * mezzo + rit[1], float(v["fondo"]) - 2.4])


## Piccoli spostamenti (metri, assi di Blender) perché mentre incombe e prende non entri nella vasca di scolo e
## nel tubo accanto (sonda: proposte/mascotte/sonda_lei_inseguimento.gd).
const RITOCCHI := {"scolo_0": [0.0, 0.25], "scolo_1": [-1.0, -1.25]}


## Quando lei sale: l'acqua (la sala allagata, o il bacino per la grata e SB1) e la morbidezza accesa tutta e subito.
## Senza forme di collisione: la sala è una mesh sola, e le animazioni dell'inseguimento tengono già i tentacoli fuori
## dai muri; la morbidezza non li porta dentro (tests/test_morbidezza_inseguimento.gd lo controlla coi raggi sulla
## collisione vera, in ogni posto dove sale).
## Le scatole del mondo per la morbidezza di lei, per posto (assets/ambiente/inseguimento/inseguimento_forme_lei.json,
## nelle coordinate della sala; lette una volta).
func _forme_lei() -> Dictionary:
	if _forme_lei_cache.is_empty() and FileAccess.file_exists(FORME_LEI):
		var d = JSON.parse_string(FileAccess.get_file_as_string(FORME_LEI))
		if d is Dictionary and d.has("posti"):
			_forme_lei_cache = d["posti"]
			_forme_lei_fori = d.get("fori", {})
			_forme_lei_convessi = d.get("convessi", {})
	return _forme_lei_cache


func _morbidezza_qui(dove: String) -> void:
	if _morbidezza == null or not is_instance_valid(_morbidezza):
		return
	_morbidezza.pavimento_y = -INF
	_morbidezza.partenza_sul_tratto = true
	# il mondo intorno a questo posto: scatole convesse prese dalla collisione vera (tests/genera_forme_inseguimento.gd)
	_morbidezza.togli_forme_mondo()
	var forme := _forme_lei()
	for sc in forme.get(dove, []):
		var lo := Vector3(float(sc[0]), float(sc[1]), float(sc[2]))
		var hi := Vector3(float(sc[3]), float(sc[4]), float(sc[5]))
		_morbidezza.aggiungi_scatola(global_transform * Transform3D(Basis.IDENTITY, (lo + hi) * 0.5), (hi - lo) * 0.5 * global_basis.get_scale())
	# dai pozzi (sb1, grata) lei sale da 5 m sotto, e la posa allarga i tentacoli più del pozzo: finché sale, sotto il
	# bordo restano dentro la pianta del pozzo (come nella fossa, LeiSbuca)
	_morbidezza.trattieni = false
	_morbidezza.trattieni_y = -INF
	_morbidezza.fossa_pianta = PackedVector2Array()
	_morbidezza.fossa_foro = false
	if dove == "sb1" or dove == "grata":
		var pz: Dictionary = dati["pozzo"] if dove == "sb1" else dati["pozzetto_grata"]
		var r: Array = pz["rett"]
		var pianta := PackedVector2Array()
		for v in [[r[0], r[1]], [r[2], r[1]], [r[2], r[3]], [r[0], r[3]]]:
			var g := global_transform * b([v[0], v[1], float(pz["bordo"])])
			pianta.append(Vector2(g.x, g.z))
		_morbidezza.fossa_pianta = pianta
		_morbidezza.trattieni_y = (global_transform * b([r[0], r[1], float(pz["bordo"])])).y
		_morbidezza.trattieni = true
	# dove sale attraverso il pavimento allagato: i tentacoli sotto il pavimento restano nel foro intorno a lei
	var fori: Dictionary = _forme_lei_fori
	if fori.has(dove):
		var fo: Array = fori[dove]
		var centro := global_transform * Vector3(float(fo[0]), float(fo[1]), float(fo[2]))
		var cerchio := PackedVector2Array()
		for k in 12:
			cerchio.append(Vector2(centro.x, centro.z) + Vector2.from_angle(TAU * k / 12.0) * float(fo[3]))
		_morbidezza.fossa_pianta = cerchio
		_morbidezza.fossa_foro = true
		# (la quota del trattenere mezzo metro sopra il pavimento: sotto il pavimento restano tutti nel foro, e si lasciano
		# mentre escono)
		_morbidezza.trattieni_y = centro.y + 0.5
		_morbidezza.trattieni = true
	# gli oggetti tondi (le pompe, i tubi): pezzi convessi coi piani già fatti
	for cv in _forme_lei_convessi.get(dove, []):
		var pl: Array = cv["piani"]
		var piani: Array[Plane] = []
		for k in range(0, pl.size(), 4):
			piani.append(global_transform * Plane(Vector3(float(pl[k]), float(pl[k + 1]), float(pl[k + 2])), float(pl[k + 3])))
		var lo := global_transform * Vector3(float(cv["lo"][0]), float(cv["lo"][1]), float(cv["lo"][2]))
		var hi := global_transform * Vector3(float(cv["hi"][0]), float(cv["hi"][1]), float(cv["hi"][2]))
		_morbidezza.aggiungi_piani(piani, AABB(lo, Vector3.ZERO).expand(hi))
	_morbidezza.acqua_pianta = Rect2(-1e4, -1e4, 2e4, 2e4)
	var acqua: Dictionary = dati["bacino"] if dove == "sb1" or dove == "grata" else dati["allagato"]
	_morbidezza.acqua_pelo = float(acqua["acqua"])
	_morbidezza.quanto = 1.0
	_morbidezza.azzera()
	_morbidezza.accendi(true)


## Lei sale dall'acqua del fondo fino a [param su]: in 1,6 s, o in 1 s ([param durata] sotto 1,3).
## Il nodo sta già lassù: la salita (da 5 m sotto) è nell'animazione.
func _lei_sale(dove: String, su: Vector3, durata := 1.6) -> void:
	_lei_dove = dove
	_lei_su = su
	_lei_giu = su + Vector3.DOWN * 5.0
	lei.global_position = su
	lei.visible = true
	_morbidezza_qui(dove)
	_getto_preso = 0.0
	lei_stato = Lei.SALE
	_lei_t = 0.0
	lei.segui_con_la_testa(0.0, 0.01)
	# le animazioni salgono da 5 m sotto; dove sotto di lei c'è meno spazio partono più su, già a metà
	# salita (sempre con l'inizio nascosto: sott'acqua o dietro la vasca)
	var sotto := _profondita(dove)
	if dove == "sb1":
		_anima("affacciata_sb1")     # sbuca in 1,3 s, si aggrappa, gira la testa e ti fissa
		var t0 := _quando_radice(&"inseguimento/affacciata_sb1", sotto, true)
		_salta_a(t0)
		set_meta(&"durata_salita", 1.3 - t0)
	else:
		var nome := "sale_dall_acqua" if durata >= 1.3 else "sale_dall_acqua_veloce"
		var dur := _anima(nome)
		var t0 := _quando_radice(StringName("inseguimento/" + nome), sotto, true)
		_salta_a(t0)
		set_meta(&"durata_salita", dur - t0)
	if dove != "sb1":
		_girala_verso_giocatore()
	# l'acqua che si apre quando sbuca (verso metà della salita)
	get_tree().create_timer(float(get_meta(&"durata_salita")) * 0.45, false).timeout.connect(func():
		if lei_stato == Lei.SALE and _lei_dove == dove:
			Audio.suona(&"tuffo", lei.global_position + Vector3.UP * 3.0, 0.0, 0.7))
	lei_compare.emit(dove)


## Quanto può scendere sotto il suo posto "su" senza toccare niente (le animazioni scendono di 5 m): SB1 nel
## pozzo pieno d'acqua, la vasca 3 accanto alla vasca, sopra il pavimento della sala (sonda:
## proposte/mascotte/sonda_lei_inseguimento.gd).
const PROFONDITA := {"sb1": 1.25, "vasca_2": 2.9, "scolo_1": 2.7}


func _profondita(dove: String) -> float:
	return float(PROFONDITA.get(dove, 5.0))


## Il tempo dell'animazione in cui la radice è [param sotto] metri sotto la sua quota alla fine (salita, il primo
## istante sopra) o all'inizio (discesa, il primo istante sotto). Con 5 m: l'inizio o la fine.
func _quando_radice(anim: StringName, sotto: float, salita: bool) -> float:
	var ap := lei.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var a := ap.get_animation(anim) if ap else null
	if a == null:
		return 0.0
	var tr := -1
	for i in a.get_track_count():
		if a.track_get_type(i) == Animation.TYPE_POSITION_3D and String(a.track_get_path(i)).ends_with(":radice"):
			tr = i
	if tr < 0 or sotto >= 4.99:
		return 0.0 if salita else a.length
	var n := a.track_get_key_count(tr)
	var rif: float = (a.track_get_key_value(tr, n - 1 if salita else 0) as Vector3).y
	for k in n:
		var y: float = (a.track_get_key_value(tr, k) as Vector3).y
		if salita and y >= rif - sotto:
			return a.track_get_key_time(tr, k)
		if not salita and y <= rif - sotto:
			return a.track_get_key_time(tr, k)
	return 0.0 if salita else a.length


func _salta_a(t: float) -> void:
	if t <= 0.0:
		return
	var ap := lei.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap:
		ap.seek(t, true)


## Un getto in faccia: si copre il viso, si ritrae sotto e tornerà.
func respingi() -> void:
	if lei_stato != Lei.SU and lei_stato != Lei.SALE:
		return
	_scendi(true)
	_ritorno = ritorno_dopo
	lei_respinta.emit()


## Torna sotto: respinta (il getto in faccia, 1,2 s) o da sola (1 s).
func _scendi(respinta := false) -> void:
	lei_stato = Lei.SCENDE
	_lei_t = 0.0
	lei.segui_con_la_testa(0.0, 0.15)
	var nome := "respinta" if respinta else "scende"
	_anima(nome, 0.15)
	# sparisce quando è scesa di quanto c'è spazio sotto di lei (vedi _lei_sale)
	set_meta(&"durata_discesa", _quando_radice(StringName("inseguimento/" + nome), _profondita(_lei_dove), false))
	get_tree().create_timer(float(get_meta(&"durata_discesa")) * 0.6, false).timeout.connect(func():
		if lei_stato == Lei.SCENDE:
			Audio.suona(&"atterraggio_acqua", lei.global_position + Vector3.UP * 3.0, 2.0, 0.6))


func _girala_verso_giocatore() -> void:
	var p := GameState.player
	if p == null or not is_instance_valid(p):
		return
	var guarda := p.global_position
	guarda.y = lei.global_position.y
	if guarda.distance_to(lei.global_position) > 0.1:
		lei.look_at(guarda, Vector3.UP, true)


func _prendi() -> void:
	if lei_stato == Lei.PRESA:
		return
	lei_stato = Lei.PRESA
	_girala_verso_giocatore()
	lei.segui_con_la_testa(0.0, 0.1)
	# la presa (si tira indietro, scatta e afferra, la fauce si apre) e le vene nell'occhio
	_anima("presa", 0.15)
	lei.attacca(0.7, &"")
	lei.add_to_group(&"medusa_che_prende")
	GameState.kill_player(&"medusa")


func _lei_aggiorna(delta: float, p: Player) -> void:
	_lei_t += delta
	var occhio := lei.get_eye_position()
	if occhio != Vector3.ZERO:
		_lei_testa.global_position = occhio
	match lei_stato:
		Lei.SALE:
			var dur := float(get_meta(&"durata_salita", 1.6))
			if _lei_dove != "sb1" and _lei_dove != "grata":
				_girala_verso_giocatore()
			if _lei_t >= dur:
				lei_stato = Lei.SU
				_lei_t = 0.0
				# (nei pozzi, sb1 e grata, quello che sta sotto il bordo resta nel pozzo anche dopo; dove sale attraverso il
				# pavimento i tentacoli si lasciano)
				if _morbidezza and is_instance_valid(_morbidezza) and _lei_dove != "sb1" and _lei_dove != "grata":
					_morbidezza.trattieni = false
				if _lei_dove != "sb1" and _lei_dove != "grata":
					# su: incombe (la salita finisce nella sua posa) e la testa ti segue
					_anima("incombe")
					lei.segui_con_la_testa(1.0, 0.5)
		Lei.SU:
			if _lei_dove == "sb1" or _lei_dove == "grata":
				return      # la sua scena: non ti prende
			_girala_verso_giocatore()
			var limite := 2.5 if _dove_scolo() else tempo_presa
			var scappato := p != null and in_tubo(p.global_position) and _vasca_di(p.global_position) < 0
			if _lei_t >= limite and p and not scappato:
				_prendi()
			elif scappato and not _dove_scolo():
				# sei scappato nel tubo: lei non ci entra, torna sotto
				_scendi()
				_ritorno = -1.0
		Lei.SCENDE:
			if _lei_t >= float(get_meta(&"durata_discesa", 1.0)):
				lei_stato = Lei.VIA
				lei.visible = false


## La grata è calata: lei sale di colpo (1 s) dal pozzetto dietro la grata, a nord della bocca della spirale,
## ci sbatte contro tre volte, poi se ne va (lei C).
func _lei_alla_grata() -> void:
	var L: Array = dati["lei"]
	_lei_sale("grata", b(L[2]["pos"]), 1.0)
	_ritorno = -1.0
	var verso := mira_grata(lei.global_position)
	lei.look_at(verso, Vector3.UP, true)
	var tw := create_tween()
	tw.tween_interval(1.0)
	tw.tween_callback(func():
		if _lei_dove == "grata" and lei_stato != Lei.PRESA:
			_anima("colpo_grata_sbieco"))
	for i in 3:   # il metallo, quando i palmi la colpiscono (0,27 s di ogni colpo da 0,5 s)
		tw.tween_interval(0.27 if i == 0 else 0.5)
		tw.tween_callback(func():
			if _lei_dove == "grata" and lei_stato != Lei.PRESA:
				Audio.suona(&"cancello_fine", verso + Vector3.UP * 2.0, 2.0, 0.85 + 0.08 * i))
	tw.tween_interval(0.23)
	tw.tween_callback(func():
		if lei_stato != Lei.PRESA and _lei_dove == "grata":
			_scendi())


## Il punto della grata (alla quota di [param da]) dove lei guarda: a 2,3 m davanti a lei, il più vicino alla bocca
## della spirale. Dal pozzetto (1,5 m dalla grata) la colpisce di sbieco: colpo_grata_sbieco.
func mira_grata(da: Vector3) -> Vector3:
	var g: Dictionary = dati["grata"]
	var perno := b(g["perno"])
	var n := b(g["verso"])                  # la normale della grata (verso lei)
	var lat := Vector3(-n.z, 0.0, n.x).normalized()
	var d := da - perno
	var dist := absf(d.dot(n))
	var lungo := d.dot(lat)
	var resto := sqrt(maxf(2.3 * 2.3 - dist * dist, 0.0))
	# di sbieco: colpo_grata_sbieco porta i palmi lungo il piano girato (dal pozzetto, circa 51 gradi)
	var s := lungo - signf(lungo) * resto
	var p := perno + lat * s
	p.y = da.y
	return p


# --- SB1 --------------------------------------------------------------------------------------------

## Vicino alla scaletta lei sbuca dal bordo del pozzo di scarico e ti guarda: l'ultima immagine del
## capitolo, poi nero.
func inizia_sb1() -> void:
	if _sb1 or GameState.is_dying:
		return
	_sb1 = true
	sb1_iniziato.emit()
	_lei_sale("sb1", _posto_sb1(), 1.3)
	var p := GameState.player
	if p and is_instance_valid(p):
		p.input_enabled = false
	var tw := create_tween()
	tw.tween_interval(1.3)
	tw.tween_method(func(k: float):
		var pl := GameState.player
		if pl and is_instance_valid(pl) and lei:
			var occhio: Vector3 = lei.get_eye_position()
			if occhio == Vector3.ZERO:
				occhio = lei.global_position + Vector3.UP * 1.6
			var da := pl.camera.global_position
			var dir := (occhio - da).normalized()
			var yaw := atan2(-dir.x, -dir.z)
			var pitch := asin(clampf(dir.y, -1.0, 1.0))
			pl.set_look(lerp_angle(pl.yaw, yaw, k), lerpf(pl.pitch, pitch, k)), 0.0, 1.0, 1.4)
	tw.tween_interval(2.6)
	tw.tween_callback(_dopo_sb1 if dopo_sb1_continua else _nero)


## Dopo SB1, col tunnel: lei si tuffa nel pozzo, i comandi tornano, e la strada si vede subito (l'utente: "dopo che
## jilly mi guarda... che dovrebbe succedere?"): un faro caldo sulla scaletta e la luce sopra la porta in cima.
func _dopo_sb1() -> void:
	# il tunnel non è ancora pronto (un PC lento, AttesaZone; scelta dell'utente del 25 ottobre): SB1 aspetta a finire,
	# lei ancora affacciata e il giocatore fermo che la guarda, la scaletta ancora al buio
	if not AttesaZone.passaggio_aperto(&"tunnel"):
		AttesaZone.attendi(&"tunnel")
		sb1_in_attesa.emit()
		var t := 0.0
		while not AttesaZone.passaggio_aperto(&"tunnel") and t < 90.0:
			await get_tree().process_frame
			if not is_inside_tree():
				return
			t += get_process_delta_time()
	_scendi(false)
	var p := GameState.player
	if p and is_instance_valid(p):
		p.input_enabled = true
	var sc: Dictionary = dati["scale"][dati["scale"].size() - 1]
	var piede := b([sc["x"], sc["y"], sc["z0"]])
	var cima := b([sc["x"], sc["y"], sc["z1"]])
	var faro := SpotLight3D.new()
	faro.name = "FaroScaletta"
	faro.light_color = Color(1.0, 0.82, 0.55)
	faro.light_energy = 0.0
	faro.spot_range = 9.0
	faro.spot_angle = 24.0
	faro.shadow_enabled = true
	faro.set_meta(&"risveglio_ignora", true)
	add_child(faro)
	faro.global_position = cima + Vector3(1.6, 3.2, 0.0)
	faro.look_at((piede + cima) * 0.5, Vector3.UP)
	var porta := b(dati["porta"]["pos"])
	var sopra := OmniLight3D.new()
	sopra.name = "LucePorta"
	sopra.light_color = Color(1.0, 0.85, 0.6)
	sopra.light_energy = 0.0
	sopra.omni_range = 5.0
	sopra.set_meta(&"risveglio_ignora", true)
	add_child(sopra)
	sopra.global_position = porta + Vector3(0.6, 2.5, 0.0)
	var tw := create_tween().set_parallel()
	tw.tween_property(faro, "light_energy", 10.0, 1.2)
	tw.tween_property(sopra, "light_energy", 2.5, 1.2)
	sb1_finito.emit()


## SB1: lo spigolo del pozzo dalla parte del giocatore; lei 1 m dietro lo spigolo e 0,8 m sotto il bordo,
## girata verso il giocatore (le misure di affacciata_sb1: le mani sul bordo, la testa sopra).
func _posto_sb1() -> Vector3:
	var pz: Dictionary = dati["pozzo"]
	var r: Array = pz["rett"]
	var c := Vector2((r[0] + r[2]) / 2.0, (r[1] + r[3]) / 2.0)
	var mezzo := Vector2((r[2] - r[0]) / 2.0, (r[3] - r[1]) / 2.0)
	var p := GameState.player
	var da := Vector2(c.x, c.y - 5.0)
	if p and is_instance_valid(p):
		da = Vector2(p.global_position.x, -p.global_position.z)
	var d := da - c
	# il lato del pozzo verso il giocatore
	var fuori := Vector2(signf(d.x), 0.0) if absf(d.x) / mezzo.x > absf(d.y) / mezzo.y else Vector2(0.0, signf(d.y))
	var spigolo := c + fuori * (mezzo.x if fuori.x != 0.0 else mezzo.y)
	var o := spigolo - fuori * 1.0
	var pos := b([o.x, o.y, float(pz["bordo"]) - 0.8])
	lei.global_position = pos
	lei.look_at(b([o.x + fuori.x, o.y + fuori.y, float(pz["bordo"]) - 0.8]), Vector3.UP, true)
	return pos


func _nero() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 80
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(_fade)
	add_child(cl)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 1.5)
	tw.tween_callback(func():
		finito = true
		capitolo_finito.emit())


# --- ogni passo ---------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_muovi_paratie(delta)
	var p := GameState.player
	if p == null or not is_instance_valid(p):
		return
	if lei_stato != Lei.VIA:
		_lei_aggiorna(delta, p)
	if GameState.is_dying or _sb1:
		return
	p.accovacciato_forzato = in_tubo(p.global_position)
	# in quale vasca sei: lei compare dopo un po', e torna dopo un getto in faccia
	var v := _vasca_di(p.global_position)
	if v != _vasca:
		_vasca = v
		_in_vasca_t = 0.0
		_ritorno = -1.0
	if _vasca < 0:
		return
	_in_vasca_t += delta
	if lei_stato == Lei.VIA:
		if _ritorno > 0.0:
			_ritorno -= delta
			if _ritorno <= 0.0:
				_lei_sale("vasca_%d" % _vasca, _posto_vasca(_vasca))
		elif _ritorno < 0.0 and _in_vasca_t >= comparsa[_vasca] and not get_meta(&"comparsa_%d" % _vasca, false):
			set_meta(&"comparsa_%d" % _vasca, true)
			_lei_sale("vasca_%d" % _vasca, _posto_vasca(_vasca))


func _vasca_di(pos: Vector3) -> int:
	for i in dati["vasche"].size():
		var v: Dictionary = dati["vasche"][i]
		var r: Array = v["rett"]
		var bx := Vector2(pos.x, -pos.z)
		if bx.x > r[0] and bx.x < r[2] and bx.y > r[1] and bx.y < r[3] and absf(pos.y - float(v["fondo"])) < 1.5:
			return i
	return -1


# --- luci ---------------------------------------------------------------------------------------------

## Le luci della proposta (niente torcia): rosse d'emergenza, lampade da lavoro calde sulle vasche (più
## forti che negli scatti: le vasche erano scure), le lampade delle paratie, la verde dell'uscita, i fari
## da cantiere sulle ringhiere puntati sulle vasche, le lampade appese e i neon, e gli arredi veri.
func _passi_luci() -> Array:
	var out: Array = [_luci]
	for a in luci_dati.get("arredi", []):
		out.append(func(): _arredo(get_node("Luci"), a))
	return out


func _luci() -> void:
	var radice := Node3D.new()
	radice.name = "Luci"
	add_child(radice)
	for e in luci_dati["emergenza"]:
		_omni(radice, b(e), ROSSO, 3.5, 8.0, 0.14, 6.0, true)
	for q in luci_dati["lavoro"]:
		_omni(radice, b(q), CALDO, 6.5, 10.0, 0.09, 8.0, true)
	for i in luci_dati["paratie"].size():
		var pa: Array = luci_dati["paratie"][i]
		_lampada_paratia(radice, b(pa[0]), pa[1] == "verde", b(luci_dati["bersagli"][i]), b(pa[2]), _pannello(i))
	for u in luci_dati["uscita"]:
		_omni(radice, b(u), VERDE, 3.0, 7.0, 0.12, 8.0, false)
	var soffitto: float = luci_dati["info"]["limiti"][5]
	for ap in luci_dati.get("appese", []):
		_appesa(radice, b(ap), bool(ap[3]), soffitto)
	for ne in luci_dati.get("neon", []):
		_omni(radice, b(ne) + Vector3.DOWN * 0.1, Color(0.85, 0.95, 1.0), 3.0, 9.0, 0.05, 6.0, true)
	# i fari da cantiere sulle ringhiere delle passerelle, puntati sulle vasche e sul bacino
	for f in [[[48.0, 0.7, -18.8], [50.5, 15.0, -22.6]], [[60.0, 29.9, -22.8], [65.5, 27.7, -25.6]],
			[[76.5, 0.7, -18.8], [69.5, 5.0, -28.6]], [[43.0, 0.7, -18.8], [46.5, 6.0, -33.4]]]:
		var s := SpotLight3D.new()
		s.light_color = Color(1.0, 0.88, 0.72)
		s.light_energy = 18.0
		s.spot_range = 22.0
		s.spot_angle = 20.0
		s.shadow_enabled = true
		s.set_meta(&"risveglio_ignora", true)
		radice.add_child(s)
		s.global_position = b(f[0])
		s.look_at(b(f[1]), Vector3.UP)
	# la scia rosa sul bordo della vasca 1, dalla parte da cui lei arriva: stretta come il bordo (18 cm, smussato) e
	# appoggiata sopra, così non pende nel vuoto ai lati (collaudo del 22 sera); finisce 15 cm prima della bocca del
	# tubo, che dalla 0.3.17 arriva più su e col bordo passa sopra il muro fino a y 15,9
	var bava := BavaRosa.new()
	bava.punti = PackedVector3Array([b([53.5, 17.91, -21.49]), b([50.09, 17.91, -21.49]), b([50.09, 16.05, -21.49])])
	bava.larghezza = 0.08
	bava.variazione = 0.25
	bava.emissione = 2.5
	bava.opacita = 0.9
	bava.sollevamento = 0.003
	bava.ricerca_su = 0.1
	bava.ricerca_giu = 0.03
	bava.appoggia = true
	radice.add_child(bava)


func _bulbo(radice: Node3D, p: Vector3, col: Color, r: float, forza: float) -> void:
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	m.mesh = sm
	var mt := StandardMaterial3D.new()
	mt.albedo_color = col
	mt.emission_enabled = true
	mt.emission = col
	mt.emission_energy_multiplier = forza
	m.material_override = mt
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	radice.add_child(m)
	m.global_position = p


func _omni(radice: Node3D, p: Vector3, col: Color, energia: float, raggio: float, r_bulbo: float, forza: float, ombre: bool) -> OmniLight3D:
	_bulbo(radice, p, col, r_bulbo, forza)
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energia
	l.omni_range = raggio
	l.shadow_enabled = ombre
	l.light_volumetric_fog_energy = 1.5
	l.set_meta(&"risveglio_ignora", true)
	radice.add_child(l)
	l.global_position = p + Vector3.DOWN * 0.15
	return l


## La lampada sopra la paratia: verde sulla giusta (fascio pieno sul bersaglio, anello di led), rossa
## guasta che sfarfalla sulla sbagliata.
## Il pannello della paratia [param k] (InseguimentoMobili), o null.
func _pannello(k: int) -> Node3D:
	var mobili := get_node_or_null("InseguimentoMobili")
	if mobili == null or k >= (dati.get("paratie", []) as Array).size():
		return null
	return mobili.find_child(String(dati["paratie"][k]["nodo"]), true, false) as Node3D


func _lampada_paratia(radice: Node3D, p: Vector3, giusta: bool, bersaglio: Vector3, verso: Vector3, pannello: Node3D = null) -> void:
	var col := VERDE if giusta else ROSSO
	var o := _omni(radice, p, col, 2.0 if giusta else 1.0, 4.5, 0.1, 9.0 if giusta else 4.0, false)
	var s := SpotLight3D.new()
	s.light_color = col
	s.light_energy = 14.0 if giusta else 2.5
	s.spot_range = 6.0
	s.spot_angle = 22.0
	s.shadow_enabled = true
	s.light_volumetric_fog_energy = 2.0
	s.set_meta(&"risveglio_ignora", true)
	radice.add_child(s)
	s.global_position = p
	s.look_at(bersaglio, Vector3.UP)
	if giusta:
		var anello := MeshInstance3D.new()
		var t := TorusMesh.new()
		t.inner_radius = 0.47
		t.outer_radius = 0.55
		t.rings = 48
		anello.mesh = t
		var m := StandardMaterial3D.new()
		m.albedo_color = VERDE
		m.emission_enabled = true
		m.emission = VERDE
		m.emission_energy_multiplier = 6.0
		anello.material_override = m
		radice.add_child(anello)
		# appoggiato al piano del pannello sotto l'anello, non al bersaglio rialzato del centro (1-2 cm più avanti):
		# la faccia si cerca lungo il cerchio dell'anello e conta la più avanti (sotto ci sono due piani: sul più
		# arretrato l'anello passava dentro l'altro); 1 mm dentro
		var v := verso.normalized()
		var faccia := bersaglio
		if pannello:
			var l1 := v.cross(Vector3.UP if absf(v.y) < 0.9 else Vector3.RIGHT).normalized()
			var l2 := v.cross(l1)
			var fondo := -INF
			for r in [t.inner_radius, (t.inner_radius + t.outer_radius) * 0.5, t.outer_radius]:
				for k in 32:
					var a := TAU * k / 32.0
					var q := bersaglio + (l1 * cos(a) + l2 * sin(a)) * float(r)
					var su: Variant = _faccia_mesh(pannello, q + v * 0.5, -v)
					if su != null:
						fondo = maxf(fondo, ((su as Vector3) - bersaglio).dot(v))
			if fondo > -INF:
				faccia = bersaglio + v * fondo
		anello.global_position = faccia + v * ((t.outer_radius - t.inner_radius) * 0.5 - 0.001)
		anello.global_basis = Basis(Quaternion(Vector3.UP, verso.normalized()))
		var o2 := OmniLight3D.new()
		o2.light_color = VERDE
		o2.light_energy = 1.5
		o2.omni_range = 3.0
		o2.set_meta(&"risveglio_ignora", true)
		radice.add_child(o2)
		o2.global_position = bersaglio + verso * 0.6
		# l'anello è sul bersaglio del pannello: sale con lui quando la paratia si apre (restava a mezz'aria)
		if pannello:
			anello.reparent(pannello)
			o2.reparent(pannello)
	else:
		_sfarfalla(o, s)


## Il primo punto delle mesh di [param radice] colpito dal raggio da [param da] verso [param dir] (null: niente).
static func _faccia_mesh(radice: Node3D, da: Vector3, dir: Vector3) -> Variant:
	var migliore: Variant = null
	var d_min := INF
	for n in radice.find_children("*", "MeshInstance3D", true, false) + ([radice] if radice is MeshInstance3D else []):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		var f := mi.mesh.get_faces()
		for i in range(0, f.size(), 3):
			var c: Variant = Geometry3D.ray_intersects_triangle(da, dir, mi.global_transform * f[i],
					mi.global_transform * f[i + 1], mi.global_transform * f[i + 2])
			if c != null and da.distance_to(c) < d_min:
				d_min = da.distance_to(c)
				migliore = c
	return migliore


## La lampada rossa guasta: si spegne e riaccende a scatti.
func _sfarfalla(o: OmniLight3D, s: SpotLight3D) -> void:
	# l'energia, non visible: accendere e spegnere la luce rifà gli abbinamenti luce-geometria del renderer
	# (con visible Godot andava in crash all'uscita, come nella torre)
	var e_o := o.light_energy
	var e_s := s.light_energy
	o.set_meta(&"sfarfalla", true)
	s.set_meta(&"sfarfalla", true)
	var tw := create_tween().set_loops()
	for d in [0.9, 0.06, 0.12, 0.05, 1.6, 0.08, 0.4]:
		tw.tween_callback(func():
			var acceso := o.light_energy < 0.01
			o.light_energy = e_o if acceso else 0.0
			s.light_energy = e_s if acceso else 0.0)
		tw.tween_interval(d)


func _appesa(radice: Node3D, p: Vector3, calda: bool, soffitto: float) -> void:
	var col := CALDO if calda else Color(0.8, 1.0, 0.92)
	# il cavo dal soffitto alla cima del paralume (fino al centro restava dentro il paralume, senza toccarlo)
	var cima := p.y + 0.11
	var cavo := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.012
	cm.bottom_radius = 0.012
	cm.height = soffitto - cima
	cavo.mesh = cm
	radice.add_child(cavo)
	cavo.global_position = Vector3(p.x, (soffitto + cima) / 2.0, p.z)
	var paralume := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.08
	pm.bottom_radius = 0.32
	pm.height = 0.22
	paralume.mesh = pm
	var mt := StandardMaterial3D.new()
	mt.albedo_color = Color(0.2, 0.32, 0.26)
	mt.metallic = 0.6
	mt.roughness = 0.45
	paralume.material_override = mt
	radice.add_child(paralume)
	paralume.global_position = p
	var l := _omni(radice, p + Vector3.DOWN * 0.1, col, 4.0, 11.0, 0.07, 8.0, true)
	l.global_position = p + Vector3.DOWN * 0.3


var _fonti := {}


## Un oggetto vero del gioco (vedi arredo() in tools/blender/inseguimento_proposte.py): un nodo della sala
## pompe o del kit di dettagli, copiato e messo al suo posto (come negli scatti della proposta).
## Il file di una fonte degli arredi ("pompe" o "dettagli/<nome>").
static func _percorso_fonte(fonte: String) -> String:
	return "res://assets/ambienti_tecnici/sala_pompe.gltf" if fonte == "pompe" \
			else "res://assets/ambiente/dettagli/gltf/%s.gltf" % fonte.get_slice("/", 1)


## I file che la costruzione carica (lei e le fonti degli arredi): la sala li chiede al thread insieme alla torre.
static func risorse() -> Array:
	var out: Array = RISORSE_LEI.duplicate()
	var dati_luci = JSON.parse_string(FileAccess.get_file_as_string(DIR + "inseguimento_luci.json"))
	if dati_luci is Dictionary:
		for a in dati_luci.get("arredi", []):
			var p := _percorso_fonte(String(a["f"]))
			if not out.has(p):
				out.append(p)
	return out


func _arredo(radice: Node3D, a: Dictionary) -> void:
	var fonte: String = a["f"]
	if not _fonti.has(fonte):
		_fonti[fonte] = (load(_percorso_fonte(fonte)) as PackedScene).instantiate()
	var src: Node3D = _fonti[fonte]
	var nomi: Array = a["n"] if a["n"] is Array else [a["n"]]
	var gruppo := Node3D.new()
	radice.add_child(gruppo)
	var scatola := AABB()
	var prima := true
	for nome in nomi:
		var n := src.find_child(nome, true, false) as Node3D
		if n == null:
			push_warning("arredo mancante: %s" % nome)
			continue
		var copia := n.duplicate() as Node3D
		gruppo.add_child(copia)
		copia.transform = _rispetto_a(src, n)
		if String(a["a"]) == "origine":
			copia.transform.origin = Vector3.ZERO
		# la collisione: nel glTF della sala pompe sta nei pezzi accanto (POMPA_1_corpo-convcolonly...), che la copia
		# della sola mesh lasciava indietro (grafica, 24 ottobre: i raggi attraversavano le pompe); dove non ci sono, una
		# scatola sull'ingombro della mesh
		var corpi := 0
		for c in src.find_children(String(nome) + "_*", "StaticBody3D", true, false):
			var cc := (c as Node3D).duplicate() as Node3D
			gruppo.add_child(cc)
			cc.transform = copia.transform * _rispetto_a(src, n).affine_inverse() * _rispetto_a(src, c as Node3D)
			corpi += 1
		if corpi == 0 and copia.find_children("*", "CollisionObject3D", true, false).is_empty() and not copia is CollisionObject3D:
			_scatola_di(copia)
		for m in [copia] + copia.find_children("*", "MeshInstance3D", true, false):
			if m is MeshInstance3D:
				var ab: AABB = copia.transform * ((m as MeshInstance3D).get_aabb()) if m == copia \
						else copia.transform * ((m as MeshInstance3D).transform * (m as MeshInstance3D).get_aabb())
				scatola = ab if prima else scatola.merge(ab)
				prima = false
	# rx: prima attorno all'asse X del pezzo (un pezzo steso a terra), poi ry attorno alla verticale
	var giro := (Basis(Vector3.UP, deg_to_rad(float(a["ry"]))) * Basis(Vector3.RIGHT, deg_to_rad(float(a.get("rx", 0.0))))) \
			.scaled(Vector3.ONE * float(a.get("s", 1.0)))
	var p := b(a["p"])
	match String(a["a"]):
		"origine":
			gruppo.transform = Transform3D(giro, p)
		_:
			var sg := Transform3D(giro, Vector3.ZERO) * scatola
			var fondo := Vector3(sg.get_center().x, sg.position.y, sg.get_center().z)
			var t := p - fondo
			if String(a["a"]) == "muro" and a["nrm"] != null:
				var nrm := Vector3(a["nrm"][0], 0.0, -float(a["nrm"][1])).normalized()
				t += nrm * (absf(nrm.x) * sg.size.x + absf(nrm.z) * sg.size.z) * 0.5
			gruppo.transform = Transform3D(giro, t)


## Una scatola di collisione sull'ingombro delle mesh di [param copia] (gli arredi senza la loro nel glTF).
static func _scatola_di(copia: Node3D) -> void:
	var box := AABB()
	var prima := true
	for m in [copia] + copia.find_children("*", "MeshInstance3D", true, false):
		if m is MeshInstance3D:
			var ab: AABB = (m as MeshInstance3D).get_aabb() if m == copia else _rispetto_a(copia, m as Node3D) * (m as MeshInstance3D).get_aabb()
			box = ab if prima else box.merge(ab)
			prima = false
	if prima or box.size.length() < 0.05:
		return
	var corpo := StaticBody3D.new()
	corpo.name = "Collisione"
	var forma := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = box.size
	forma.shape = bs
	forma.position = box.get_center()
	corpo.add_child(forma)
	copia.add_child(corpo)


## La trasformazione di [param n] rispetto a [param src] (anche fuori dall'albero).
static func _rispetto_a(src: Node3D, n: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var c: Node = n
	while c and c != src:
		if c is Node3D:
			t = (c as Node3D).transform * t
		c = c.get_parent()
	return t


func _exit_tree() -> void:
	for f in _fonti.values():
		if is_instance_valid(f):
			(f as Node).free()
	_fonti.clear()
