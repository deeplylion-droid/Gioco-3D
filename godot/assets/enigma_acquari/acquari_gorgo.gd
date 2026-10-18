class_name AcquariGorgo
extends Node
## Il gorgo dell'enigma degli acquari: quando la valvola rossa gira (EnigmaAcquari.gorgo_iniziato)
## nel cilindro basso del miscuglio l'acqua gira e scende formando un imbuto, con la schiuma che
## vortica, per [code]durata_gorgo[/code] secondi; intanto suona il risucchio che gorgoglia (lo stesso
## gorgo della piscina a onde scelto dall'utente il 16 ottobre, più acuto: la vasca è piccola). Il
## colpo finale ("vasca svuotata") lo suona già l'addon audio quando l'acquario si svuota.
## Prepara anche, appena entra il livello, i materiali degli acquari (vetro, acqua vista dai vetri,
## disegno): compaiono di colpo rientrando dal magazzino e la prima compilazione bloccherebbe il gioco.
## È un Node (non Node3D): EnigmaAcquari non lo nasconde con gli acquari. Usa lo slot 1 dei gorghi
## della WaterBody: lo 0 lo riscrive a ogni fotogramma il WaterTankLink (lo scarico della vasca).

## L'enigma (EnigmaAcquari).
@export var enigma: Node
## L'acqua dell'addon dell'acquario del miscuglio (WaterTankLink).
@export var acqua_misto: Node3D
## Rotazione del gorgo (+1 o -1) e profondità massima dell'imbuto (m).
@export var verso := 1.0
@export var imbuto := 0.22

var _t := -1.0
var _durata := 4.0
var _suono: Node
var _prepara: Array[MeshInstance3D] = []
var _prepara_f := 0


func _ready() -> void:
	if enigma and enigma.has_signal(&"gorgo_iniziato"):
		enigma.connect(&"gorgo_iniziato", inizia)
	_prepara_materiali.call_deferred()


func inizia() -> void:
	_durata = float(enigma.get(&"durata_gorgo")) if enigma and &"durata_gorgo" in enigma else 4.0
	_t = 0.0
	var audio := get_node_or_null(^"/root/Audio")
	if audio and acqua_misto and _suono == null:
		_suono = audio.call(&"crea_loop", &"piscina_svuota_loop", acqua_misto)
	if _suono:
		_suono.set(&"tono", 1.25)


## Vero mentre il gorgo gira (per i test e gli scatti).
func in_corso() -> bool:
	return _t >= 0.0


func _process(delta: float) -> void:
	_prepara_passo()
	if _t < 0.0 or acqua_misto == null:
		return
	_t += delta
	var k := clampf(_t / _durata, 0.0, 1.0)
	# parte in fretta, gira forte, e alla fine (poca acqua) l'imbuto si chiude
	var forza := smoothstep(0.0, 0.15, k) * (1.0 - smoothstep(0.85, 1.0, k))
	var c := acqua_misto.global_position
	var lv: float = acqua_misto.get(&"level")
	var fondo: float = acqua_misto.get(&"bottom")
	var profondo := clampf((lv - fondo) / 0.12, 0.0, 1.0)
	var r: float = minf((acqua_misto.get(&"size") as Vector2).x * 0.45, 0.75)
	acqua_misto.call(&"set_flow", 1, c, r, forza, verso * (1.2 + k), imbuto * profondo, 0.55, 1.0)
	if randf() < 0.3 * forza:
		var a := randf() * TAU
		acqua_misto.call(&"add_impulse", c + Vector3(cos(a), 0, sin(a)) * r * 0.6, r * 0.2, -0.006 * forza, 0.25)
	if _suono:
		_suono.set(&"volume", forza * (0.5 + 0.5 * profondo))
	if _t >= _durata + 0.5:
		acqua_misto.call(&"clear_flow", 1)
		_t = -1.0
		if _suono:
			_suono.set(&"volume", 0.0)


# --- Preparazione dei materiali ---------------------------------------------------------------

## Una copia piccola di ogni mesh degli acquari, davanti alla camera per qualche fotogramma.
func _prepara_materiali() -> void:
	if enigma == null:
		return
	for n in (enigma as Node).find_children("*", "GeometryInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var m := mi.material_override
		if m == null and mi.mesh.get_surface_count() > 0:
			m = mi.get_active_material(0)
		if m == null:
			continue
		var p := MeshInstance3D.new()
		p.mesh = mi.mesh
		p.material_override = mi.material_override
		p.scale = Vector3.ONE * 0.01
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(p)
		p.top_level = true
		_prepara.append(p)
	for n in (enigma as Node).find_children("*", "AcquarioVetro", true, false):
		for c in (n as Node).get_children(true):
			var mi := c as MeshInstance3D
			if mi:
				var p := MeshInstance3D.new()
				p.mesh = mi.mesh
				p.material_override = mi.material_override
				p.scale = Vector3.ONE * 0.01
				add_child(p)
				p.top_level = true
				_prepara.append(p)


func _prepara_passo() -> void:
	if _prepara.is_empty():
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	_prepara_f += 1
	var davanti := cam.global_transform * Vector3(0.0, 0.0, -1.5)
	for i in _prepara.size():
		_prepara[i].global_position = davanti + Vector3(0.002 * i, 0.0, 0.0)
	if _prepara_f > 6:
		for p in _prepara:
			p.queue_free()
		_prepara.clear()
