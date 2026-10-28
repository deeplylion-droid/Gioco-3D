class_name Scarabocchi
extends Node3D
## Gli scarabocchi a pastelli a cera sui muri più vuoti (richiesta dell'utente del 28 ottobre: "nei muri più vuoti, di
## aggiungermi degli scarabocchi a pastelli a cera, tratto grosso"). Ogni scarabocchio è una Decal proiettata sul muro:
## segue le piastrelle e il loro rilievo, non sta sospesa e non tocca niente fuori dal muro (la scatola della decal è
## sottile, [constant SPESSORE]); le texture le mette Godot nel suo atlante delle decal. Le decal nel Forward+ sono già
## nello shader di ogni superficie: niente pipeline nuove.
## I muri e i disegni stanno in [member dati] (assets_src/scarabocchi/genera.py li scrive): per ognuno la zona, il
## centro sul muro, la normale verso la stanza, le misure, la texture e quanto è sbiadito.
## Uso: un nodo Scarabocchi nella scena, con [member zone] le zone da mettere (vuoto: tutte quelle di questa scena).

const DATI := "res://assets/ambiente/scarabocchi/scarabocchi.json"
## Quanto la scatola della decal sta davanti e dietro la faccia del muro (m).
const SPESSORE := 0.12

@export_file("*.json") var dati := DATI
## Le zone da mettere (sala, interni, tecnici, risalita, fiume, infermeria, torre, inseguimento, tunnel); vuoto: tutte.
@export var zone: PackedStringArray = []


func _ready() -> void:
	if not FileAccess.file_exists(dati):
		return
	var elenco: Array = JSON.parse_string(FileAccess.get_file_as_string(dati))
	for s in elenco:
		if not zone.is_empty() and not zone.has(String(s["zona"])):
			continue
		add_child(crea(s))


## La decal di uno scarabocchio [param s] (vedi [member dati]), nelle coordinate del mondo.
static func crea(s: Dictionary) -> Decal:
	var d := Decal.new()
	d.name = String(s["nome"])
	var n := _vec(s["normale"]).normalized()
	var c := _vec(s["centro"])
	# la decal proietta lungo il suo -Y: Y verso la stanza, X lungo il muro (orizzontale), Z in giù
	var x := Vector3.UP.cross(n).normalized()
	var z := x.cross(n).normalized()
	d.transform = Transform3D(Basis(x, n, z), c)
	d.size = Vector3(float(s["largo"]), SPESSORE * 2.0, float(s["alto"]))
	d.texture_albedo = load(String(s["texture"])) as Texture2D
	d.modulate = Color(1, 1, 1, 1.0 - float(s.get("sbiadito", 0.0)))
	d.albedo_mix = 1.0
	# niente sfumature in alto e in basso: il disegno si ferma dove finisce la sua scatola
	d.upper_fade = 0.0
	d.lower_fade = 0.0
	d.distance_fade_enabled = true
	d.distance_fade_begin = 30.0
	d.distance_fade_length = 6.0
	d.set_meta(&"scarabocchio", true)
	return d


static func _vec(v: Array) -> Vector3:
	return Vector3(float(v[0]), float(v[1]), float(v[2]))
