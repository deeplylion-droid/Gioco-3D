@tool
class_name DisegnoBambino
extends Node3D
## Un disegno del bambino con la scatola (build 0.5.0, «La storia», GDD del 15 novembre, Build 2): un foglio A3
## verticale (A4 per il foglio del finale) attaccato al muro con quattro pezzi di nastro di carta, coi pastelli che si
## vedono appena anche al buio (emissione leggera, come il disegno dei giocattoli). Due aggiunte facoltative, ognuna con
## un perché da trovare dove lo si mette: [member pastello], un pastello a cera turchese lasciato per terra sotto il
## foglio, e [member impronte], una fila di impronte bagnate piccole che arriva al foglio da dove lui può essere passato
## (una porta, un buco, l'acqua).
##
## Come si mette (guida: docs/tecnico/storia_disegni/LEGGIMI.md):
## - l'origine del nodo è il centro del foglio, sulla superficie del muro; il foglio guarda verso +Z del nodo (il muro è
##   dietro, a z = 0); il nodo si gira solo attorno all'asse verticale;
## - [member altezza] è quanto il centro del foglio sta sopra il pavimento (1,0-1,2 m: l'ha attaccato un bambino);
## - il punto sul muro e il pavimento si trovano con lo strumento comune (Posa, tests/posa_disegni.gd), poi si scrivono
##   nella scena: niente a mezz'aria, nemmeno di 1 cm (test_disegni_bambino.gd controlla).

## A3 verticale (29,7 × 42 cm), A4 verticale (21 × 29,7, il foglio del finale), A3 orizzontale (42 × 29,7, D4).
enum Formato { A3, A4, A3_ORIZZONTALE }

## Il disegno (una texture di godot/assets/storia_disegni/).
@export var disegno: Texture2D:
	set(v):
		disegno = v
		_rifai()
@export var formato := Formato.A3:
	set(v):
		formato = v
		_rifai()
## Il centro del foglio sopra il pavimento (m).
@export var altezza := 1.1:
	set(v):
		altezza = v
		_rifai()
## Quanto si vedono i pastelli al buio (come il disegno dei giocattoli, enigma_giocattoli.gd).
@export var emissione := 0.12:
	set(v):
		emissione = v
		_rifai()
## I quattro pezzi di nastro di carta sugli angoli (i fogli attaccati al muro). Spento solo per il foglio tenuto in mano
## (DZ, quello che porge il bambino col cubo nel finale del tunnel).
@export var nastri := true:
	set(v):
		nastri = v
		_rifai()
@export_group("Pastello")
## Un pastello a cera lasciato per terra sotto il foglio.
@export var pastello := false:
	set(v):
		pastello = v
		_rifai()
## Dove sta il pastello (nel sistema del nodo: x lungo il muro, z fuori dal muro; la quota è quella del pavimento).
@export var pastello_dove := Vector2(0.12, 0.09):
	set(v):
		pastello_dove = v
		_rifai()
## Di quanto è girato il pastello per terra (gradi, attorno alla verticale).
@export var pastello_giro := 25.0:
	set(v):
		pastello_giro = v
		_rifai()
@export_group("Impronte")
## Una fila di impronte bagnate dei suoi piedi nudi, da [member impronte_da] fin sotto il foglio.
@export var impronte := false:
	set(v):
		impronte = v
		_rifai()
## Da dove arrivano le impronte (nel sistema del nodo, sul pavimento: x lungo il muro, y fuori dal muro).
@export var impronte_da := Vector2(-1.6, 1.4):
	set(v):
		impronte_da = v
		_rifai()
## La lunghezza di un passo di bambino (m).
@export var passo := 0.3
## Le prime impronte (le più vecchie) sono quasi asciutte: l'opacità va da questa a 1.
@export var asciutte := 0.6

const MISURE := {Formato.A3: Vector2(0.297, 0.42), Formato.A4: Vector2(0.21, 0.297), Formato.A3_ORIZZONTALE: Vector2(0.42, 0.297)}
## Lo spessore del foglio (m): il retro tocca il muro, a z = 0.
const SPESSORE := 0.0004
const NASTRO := Vector3(0.055, 0.019, 0.0002)
const COLORE_NASTRO := Color(0.86, 0.80, 0.62)
const PASTELLO := "res://assets/storia_disegni/pastello.glb"
const IMPRONTE := ["res://assets/storia_disegni/impronta_sx.png", "res://assets/storia_disegni/impronta_dx.png"]
## Bagnate: lucide (ruvidezza bassa), così riflettono le luci anche su un pavimento scuro.
const IMPRONTE_ORM := ["res://assets/storia_disegni/impronta_sx_orm.png", "res://assets/storia_disegni/impronta_dx_orm.png"]
## Una impronta: larga, alta (quanto proietta sopra e sotto il pavimento), lunga (m).
const IMPRONTA := Vector3(0.085, 0.06, 0.19)
## Le impronte si fermano a tanto dal muro, sotto il foglio (lì lui si è fermato a disegnare).
const IMPRONTE_FINE := 0.32

var _fatto := false


func _ready() -> void:
	_fatto = true
	_costruisci()


func _rifai() -> void:
	if _fatto and is_inside_tree():
		_costruisci()


func misura() -> Vector2:
	return MISURE[formato]


func _costruisci() -> void:
	for c in get_children():
		if c.has_meta(&"disegno_bambino"):
			remove_child(c)
			c.queue_free()
	var m := misura()
	# il foglio: una lastra sottile (la carta, il retro sul muro) e davanti il disegno
	var carta := MeshInstance3D.new()
	carta.name = "Foglio"
	var b := BoxMesh.new()
	b.size = Vector3(m.x, m.y, SPESSORE)
	carta.mesh = b
	carta.position = Vector3(0, 0, SPESSORE * 0.5)
	var mc := StandardMaterial3D.new()
	mc.albedo_color = Color(0.93, 0.90, 0.82)
	mc.roughness = 0.9
	carta.material_override = mc
	carta.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_aggiungi(carta)
	var foglio := MeshInstance3D.new()
	foglio.name = "Pastelli"
	var q := QuadMesh.new()
	q.size = m
	foglio.mesh = q
	foglio.position = Vector3(0, 0, SPESSORE + 0.0001)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = disegno
	mat.roughness = 0.9
	mat.emission_enabled = emissione > 0.0
	mat.emission_texture = disegno
	mat.emission_energy_multiplier = emissione
	foglio.material_override = mat
	foglio.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_aggiungi(foglio)
	if nastri:
		# i quattro pezzi di nastro, di sbieco sugli angoli, a cavallo fra il foglio e il muro
		var mn := StandardMaterial3D.new()
		mn.albedo_color = COLORE_NASTRO
		mn.roughness = 0.85
		var i := 0
		for sx in [-1.0, 1.0]:
			for sy in [1.0, -1.0]:
				var n := MeshInstance3D.new()
				n.name = "Nastro%d" % i
				var nb := BoxMesh.new()
				nb.size = NASTRO
				n.mesh = nb
				n.material_override = mn
				n.position = Vector3(sx * (m.x * 0.5 - 0.004), sy * (m.y * 0.5 - 0.004), SPESSORE + NASTRO.z * 0.5)
				n.rotation.z = deg_to_rad(38.0 + 9.0 * i) * sx * sy
				n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				_aggiungi(n)
				i += 1
	if pastello and ResourceLoader.exists(PASTELLO):
		var p := (load(PASTELLO) as PackedScene).instantiate() as Node3D
		p.name = "Pastello"
		p.position = Vector3(pastello_dove.x, -altezza, pastello_dove.y)
		p.rotation.y = deg_to_rad(pastello_giro)
		# la cera si vede appena al buio, come i pastelli del foglio (stessa emissione)
		for mi: MeshInstance3D in p.find_children("*", "MeshInstance3D", true, false):
			for k in mi.mesh.get_surface_count():
				var cera := mi.mesh.surface_get_material(k) as StandardMaterial3D
				if cera and cera.resource_name.contains("cera"):
					var mm := cera.duplicate() as StandardMaterial3D
					mm.emission_enabled = emissione > 0.0
					mm.emission = cera.albedo_color
					mm.emission_energy_multiplier = emissione * 2.0
					mi.set_surface_override_material(k, mm)
		_aggiungi(p)
	if impronte:
		_impronte()


## La fila di impronte: da [member impronte_da] fin sotto il foglio, a passi alternati (sinistro, destro), girate
## verso dove va; le prime più asciutte.
func _impronte() -> void:
	var da := Vector3(impronte_da.x, -altezza, impronte_da.y)
	var a := Vector3(0.0, -altezza, IMPRONTE_FINE)
	var via := a - da
	var lungo := via.length()
	if lungo < passo:
		return
	var dir := via / lungo
	var lato := dir.cross(Vector3.UP).normalized()
	var quante := int(lungo / passo) + 1
	var tex: Array[Texture2D] = []
	for t in IMPRONTE:
		tex.append(load(t) as Texture2D if ResourceLoader.exists(t) else null)
	var orm: Array[Texture2D] = []
	for t in IMPRONTE_ORM:
		orm.append(load(t) as Texture2D if ResourceLoader.exists(t) else null)
	for k in quante:
		var dec := Decal.new()
		dec.name = "Impronta%d" % k
		var sinistro := k % 2 == 0
		dec.texture_albedo = tex[0 if sinistro else 1]
		dec.texture_orm = orm[0 if sinistro else 1]
		dec.size = IMPRONTA
		dec.modulate = Color(0.03, 0.033, 0.036, lerpf(asciutte, 1.0, float(k) / maxf(quante - 1, 1)))
		dec.albedo_mix = 1.0
		var c := da + dir * (passo * k) + lato * (0.055 if not sinistro else -0.055)
		dec.position = c
		# la punta del piede (in alto nella texture, -Z del decal) verso dove va
		dec.basis = Basis.looking_at(dir, Vector3.UP)
		_aggiungi(dec)


func _aggiungi(n: Node) -> void:
	n.set_meta(&"disegno_bambino", true)
	add_child(n)
