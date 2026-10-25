class_name RiscaldamentoShader
extends Node
## Il riscaldamento degli shader dietro la schermata di caricamento dell'avvio (blocchi al primo avvio, v0.3.14: su un
## PC nuovo, con la cache degli shader vuota, ogni shader nuovo si compila al primo uso sul thread principale; i
## materiali campione delle zone (torre, oblò, Risalita, tunnel) si creavano tutti insieme entrando nella sala o a
## gioco avviato, 100-150 ms l'uno sulla CPU della CI). Qui, mentre la barra della schermata si muove:
## 1. gli shader dei materiali campione si creano uno alla volta, al più [constant MS_PER_FOTOGRAMMA] ms per
##    fotogramma (sempre almeno uno);
## 2. poi gli stessi materiali si disegnano su una sfera in un SubViewport fuori vista, con luci con le ombre e
##    l'ambiente della sala, qualcuno per fotogramma, così anche le loro pipeline finiscono nella cache.
## I materiali restano tenuti per tutta la partita ([member _tenuti]): i loro shader non si ricompilano più quando le
## zone li creano di nuovo. Con la cache già piena tutto dura pochi fotogrammi.

signal finito

## Quanto lavoro per fotogramma (la schermata non deve mai fermarsi più di 100 ms).
const MS_PER_FOTOGRAMMA := 30.0
const RISALITA := "res://scenes/risalita/materiali_campione.tres"
const AMBIENTE := "res://addons/grafica/sala/ambiente_sala.tres"

## I materiali già passati di qui: tenuti per tutta la partita (gli shader vivono finché c'è un materiale).
static var _tenuti: Array[Material] = []

## Quanti materiali in tutto e quanti fatti (shader creati e disegnati).
var totale := 0
var fatti := 0
var concluso := false
var _materiali: Array[Material] = []


func _ready() -> void:
	_materiali = materiali()
	totale = _materiali.size() * 2
	_run.call_deferred()


## Tutti i materiali campione delle zone che si caricano a gioco avviato.
static func materiali() -> Array[Material]:
	var out: Array[Material] = []
	out.append_array(SalaTorre.materiali_campione(false))
	if ResourceLoader.exists(RISALITA):
		for m in load(RISALITA).get_meta(&"materiali", []):
			out.append(m as Material)
	for m in CampioniTunnel.carica(false):
		out.append(m as Material)
	return out


## Avanzamento 0..1.
func avanzamento() -> float:
	return 1.0 if totale == 0 else clampf(float(fatti) / totale, 0.0, 1.0)


func _run() -> void:
	# 1. gli shader, uno alla volta
	var i := 0
	while i < _materiali.size():
		var t0 := Time.get_ticks_usec()
		while i < _materiali.size():
			_materiali[i].get_rid()
			_tenuti.append(_materiali[i])
			i += 1
			fatti += 1
			if (Time.get_ticks_usec() - t0) / 1000.0 >= MS_PER_FOTOGRAMMA:
				break
		await get_tree().process_frame
		if not is_inside_tree():
			return
	# 2. le pipeline: i materiali disegnati fuori vista (solo col renderer vero)
	if DisplayServer.get_name() != "headless" and RenderingServer.get_rendering_device() != null:
		await _disegna()
	fatti = totale
	concluso = true
	finito.emit()


func _disegna() -> void:
	var sv := SubViewport.new()
	sv.name = "RiscaldamentoShader"
	sv.size = Vector2i(64, 64)
	sv.own_world_3d = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var principale := get_viewport()
	sv.msaa_3d = principale.msaa_3d
	sv.screen_space_aa = principale.screen_space_aa
	sv.use_taa = principale.use_taa
	sv.use_hdr_2d = principale.use_hdr_2d
	add_child(sv)
	if ResourceLoader.exists(AMBIENTE):
		var env := WorldEnvironment.new()
		env.environment = load(AMBIENTE) as Environment
		sv.add_child(env)
	# le luci come nel gioco: col sole, i punti e i faretti con le ombre (le varianti degli shader con le ombre)
	var sole := DirectionalLight3D.new()
	sole.shadow_enabled = true
	sole.rotation_degrees = Vector3(-50, 30, 0)
	sv.add_child(sole)
	var punto := OmniLight3D.new()
	punto.shadow_enabled = true
	punto.position = Vector3(0, 1.5, 1.5)
	sv.add_child(punto)
	var faro := SpotLight3D.new()
	faro.shadow_enabled = true
	faro.position = Vector3(1.5, 1.5, 1.5)
	sv.add_child(faro)
	faro.look_at(Vector3.ZERO)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0, 3)
	sv.add_child(cam)
	cam.current = true
	var sfera := SphereMesh.new()
	sfera.radial_segments = 8
	sfera.rings = 4
	var i := 0
	var mostrati: Array[MeshInstance3D] = []
	while i < _materiali.size():
		var t0 := Time.get_ticks_usec()
		# qualche materiale nuovo per fotogramma; dopo un fotogramma lungo, uno solo
		var quanti := 4 if _ultimo_ms() < MS_PER_FOTOGRAMMA else 1
		for k in quanti:
			if i >= _materiali.size():
				break
			var mi := MeshInstance3D.new()
			mi.mesh = sfera
			mi.material_override = _materiali[i]
			mi.position = Vector3((k - 1.5) * 0.4, 0, 0)
			mi.scale = Vector3.ONE * 0.3
			sv.add_child(mi)
			mostrati.append(mi)
			i += 1
			fatti += 1
		_t_fotogramma = Time.get_ticks_usec()
		await get_tree().process_frame
		if not is_inside_tree():
			return
		# disegnati: via, il prossimo gruppo da solo
		for mi in mostrati:
			mi.queue_free()
		mostrati.clear()
		if (Time.get_ticks_usec() - t0) / 1000.0 > 100.0:
			print("RiscaldamentoShader: un fotogramma di %.0f ms (materiale %d)" % [(Time.get_ticks_usec() - t0) / 1000.0, i])
	await get_tree().process_frame
	sv.queue_free()


var _t_fotogramma := 0


## Quanto è durato l'ultimo fotogramma (ms).
func _ultimo_ms() -> float:
	return 0.0 if _t_fotogramma == 0 else (Time.get_ticks_usec() - _t_fotogramma) / 1000.0
