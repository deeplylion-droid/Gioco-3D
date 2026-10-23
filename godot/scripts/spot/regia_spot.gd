extends Node
## La regia dello spot VHS della crociera: gira un segmento di scenes/spot/spot_inquadrature.json (una scena e le sue
## inquadrature di fila) muovendo la camera, per registrarlo col Movie Maker di Godot. Il video esce pulito: il
## filtro VHS, il guasto, l'occhio e l'audio li mette dal vivo il lettore (scripts/spot/lettore_spot.gd).
## Un segmento per processo (la sala dello spot da sola prende quasi tutta la memoria): tools/spot/registra_spot.sh
## li registra uno alla volta e li monta con ffmpeg in assets/spot/spot.ogv.
## Uso (sotto il render.lock, con xvfb-run e vulkan):
##   godot --path godot --rendering-driver vulkan --resolution 1280x720 --fixed-fps 30 --write-movie <file.avi> \
##       --script res://tests/run.gd -- res://scripts/spot/regia_spot.gd <segmento> [preparazione_s]
## (con --script il gioco sa di essere in una prova: senza, al primo avvio apre la calibrazione della luminosità, che
## mette in pausa l'albero, e la regia restava ferma)
## Per [member preparazione] secondi la camera sta ferma sul primo fotogramma (GI, sonde e acqua si assestano):
## quel pezzo il montaggio lo taglia.

const INQUADRATURE := "res://scenes/spot/spot_inquadrature.json"
const SCRIPT_OCCHIO := "res://scripts/spot/occhio_ipnotico.gd"

## Secondi fermi prima di partire (tagliati al montaggio).
@export var preparazione := 4.0

var _segmento: Dictionary
var _scena: Node
var _cam: Camera3D
var _t := -1.0             ## secondi dall'inizio del segmento (negativi durante la preparazione)
var _inizio := 0.0         ## inizio del segmento nello spot
var _fine := 0.0
var _azioni_fatte := {}
var _dati: Dictionary
var _occhio: Node        ## l'OcchioIpnotico di enigmi con solo_occhio (muove l'occhio vero di Jilly), se il segmento lo vuole


func _ready() -> void:
	var args := Array(OS.get_cmdline_user_args()).filter(func(a: String): return not a.ends_with(".gd"))
	var dati: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(INQUADRATURE))
	_dati = dati
	var nome: String = String(args[0]) if args.size() > 0 else String(dati["segmenti"][0]["nome"])
	if args.size() > 1:
		preparazione = float(args[1])
	for s in dati["segmenti"]:
		if s["nome"] == nome:
			_segmento = s
	assert(not _segmento.is_empty(), "segmento dello spot sconosciuto: " + nome)
	var inq: Array = _segmento["inquadrature"]
	_inizio = float(inq[0]["inizio"])
	_fine = float(inq[-1]["inizio"]) + float(inq[-1]["durata"])
	_scena = (load(String(_segmento["scena"])) as PackedScene).instantiate()
	add_child(_scena)
	_cam = _scena.get_node_or_null(^"Camera") as Camera3D
	if _cam == null and _scena is Node3D:
		_cam = Camera3D.new()
		_scena.add_child(_cam)
	if _cam:
		_cam.current = true
	if _segmento.get("occhio_ipnotico", false) and ResourceLoader.exists(SCRIPT_OCCHIO):
		# solo l'occhio vero, niente disegnato: l'effetto sullo schermo lo mette il lettore dal vivo, con lo stesso
		# progresso (chiave "occhio" del filtro), così il battito del video e quello dell'effetto restano in passo
		_occhio = ColorRect.new()
		_occhio.name = "OcchioIpnotico"
		_occhio.set_script(load(SCRIPT_OCCHIO))
		_occhio.set(&"solo_occhio", true)
		_scena.add_child(_occhio)
	_t = -preparazione
	_muovi(0.0)


func _process(delta: float) -> void:
	_t += delta
	_muovi(maxf(_t, 0.0))
	if _t >= _fine - _inizio:
		get_tree().quit()


## Mette la camera e lancia le azioni al tempo [param t] del segmento.
func _muovi(t: float) -> void:
	var assoluto := _inizio + t
	if _occhio:
		_occhio.set(&"progresso", LettoreSpot.chiave(_dati, "occhio", assoluto) if _t >= 0.0 else 0.0)
	for inq in _segmento["inquadrature"]:
		var da := float(inq["inizio"])
		if assoluto < da or assoluto > da + float(inq["durata"]) + 0.0001:
			continue
		var tl := assoluto - da
		if inq.has("camera") and _cam:
			_camera(inq["camera"], tl)
		elif inq.has("discesa") and _cam:
			var s := _chiavi(inq["discesa"], tl, "s")
			_cam.global_transform = _scena.call(&"posa_camera", s)
			_cam.fov = float(inq.get("fov", 75.0))
			if _t >= 0.0 and _scena.has_method(&"segui_camera"):
				_scena.call(&"segui_camera", s)
		if _scena.has_method(&"a_tempo"):
			_scena.call(&"a_tempo", tl, int(inq["n"]))
		if _t >= 0.0:
			for a in inq.get("azioni", []):
				var chiave := "%d_%s_%s" % [int(inq["n"]), a["nodo"], a["metodo"]]
				if tl >= float(a["t"]) and not _azioni_fatte.has(chiave):
					_azioni_fatte[chiave] = true
					var n := _scena.find_child(String(a["nodo"]), true, false)
					if n and n.has_method(StringName(a["metodo"])):
						n.callv(StringName(a["metodo"]), a.get("argomenti", []))
					else:
						push_warning("spot: azione senza nodo o metodo: " + chiave)
		break


## La camera tra le chiavi (pos, guarda, fov), con il passo morbido (Catmull-Rom sulle posizioni).
func _camera(chiavi: Array, t: float) -> void:
	var i := 0
	while i < chiavi.size() - 2 and t > float(chiavi[i + 1]["t"]):
		i += 1
	var a: Dictionary = chiavi[i]
	var b: Dictionary = chiavi[mini(i + 1, chiavi.size() - 1)]
	var u := 0.0 if b == a else clampf((t - float(a["t"])) / maxf(float(b["t"]) - float(a["t"]), 1e-4), 0.0, 1.0)
	u = u * u * (3.0 - 2.0 * u) if chiavi.size() == 2 else u
	var p0 := _v(chiavi[maxi(i - 1, 0)]["pos"])
	var p3 := _v(chiavi[mini(i + 2, chiavi.size() - 1)]["pos"])
	var g0 := _v(chiavi[maxi(i - 1, 0)]["guarda"])
	var g3 := _v(chiavi[mini(i + 2, chiavi.size() - 1)]["guarda"])
	var pos := _v(a["pos"]).cubic_interpolate(_v(b["pos"]), p0, p3, u)
	var guarda := _v(a["guarda"]).cubic_interpolate(_v(b["guarda"]), g0, g3, u)
	_cam.global_position = pos
	_cam.look_at(guarda, Vector3.UP)
	_cam.fov = lerpf(float(a.get("fov", 60.0)), float(b.get("fov", 60.0)), u)


## Valore [param campo] tra le chiavi {t, campo}, lineare a tratti con gli estremi morbidi.
static func _chiavi(chiavi: Array, t: float, campo: String) -> float:
	if t <= float(chiavi[0]["t"]):
		return float(chiavi[0][campo])
	for i in chiavi.size() - 1:
		var a: Dictionary = chiavi[i]
		var b: Dictionary = chiavi[i + 1]
		if t <= float(b["t"]):
			var u := (t - float(a["t"])) / maxf(float(b["t"]) - float(a["t"]), 1e-4)
			# primo e ultimo tratto morbidi (si parte piano, si arriva piano), quelli in mezzo a velocità costante
			if i == 0:
				u = u * u
			elif i == chiavi.size() - 2:
				u = 1.0 - (1.0 - u) * (1.0 - u)
			return lerpf(float(a[campo]), float(b[campo]), u)
	return float(chiavi[-1][campo])


static func _v(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])
