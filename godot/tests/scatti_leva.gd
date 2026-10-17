extends Node
## Scatti della leva grande della sala pompe a riposo, a metà corsa e in fondo (prima/dopo della correzione).
## Carica la scena dei tecnici, ci mette la logica della leva (LevaGrande) dove sta nel livello
## (Tecnici/Logica/SalaPompe/Leva) e la ferma nei tre punti della corsa. Stampa anche di quanto
## si sposta l'occhio del braccio rispetto al perno della base (deve restare ~0).
## Uso: xvfb-run -a -s "-screen 0 1600x900x24" godot --path godot --rendering-driver vulkan --fixed-fps 60 \
##        --resolution 1600x900 --script res://tests/run.gd -- res://tests/scatti_leva.gd <cartella> <prefisso>

const SCENA := "res://scenes/tecnici/tecnici.tscn"
const POS_LOGICA := Vector3(46.114, 3.716, -4.954)   # come Tecnici/Logica/SalaPompe/Leva in sala_principale.tscn
## Punto di vista: sollevato quasi all'altezza della leva, davanti alla gabbia (grata e gabbia nascoste negli scatti).
const OCCHI := Vector3(44.2, 2.4, -5.0)
const MIRA := Vector3(46.1, 3.9, -5.2)

var out_dir := "user://scatti"
var prefisso := ""


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	out_dir = a[1]
	prefisso = a[2] if a.size() > 2 else ""
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset("alto")
	get_tree().change_scene_to_file(SCENA)
	for i in 300:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player):
			break
	get_tree().paused = false
	var level := get_tree().current_scene
	var lg := LevaGrande.new()
	lg.name = "LevaProva"
	lg.position = POS_LOGICA
	lg.durata = 1.0e9   # la corsa si ferma dove la mettiamo noi
	level.add_child(lg)
	lg.leva_path = lg.get_path_to(level.get_node("Ambienti/SalaPompe/LEVA"))
	lg._ready()
	var leva: Node3D = level.get_node("Ambienti/SalaPompe/LEVA")
	for n in ["Ambienti/SalaPompe/GRATA_leva", "Ambienti/SalaPompe/gabbia_leva"]:
		var g := level.get_node_or_null(n) as Node3D
		if g:
			g.visible = false
	var p: Player = GameState.player
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	p.teleport(OCCHI, 0.0, 0.0)
	p.set_physics_process(false)
	p.look_at_point(MIRA)
	var perno := leva.global_position
	var base: Node3D = level.get_node("Ambienti/SalaPompe/LEVA_base")
	var vs: Array[Vector3] = []
	for mi in base.find_children("*", "MeshInstance3D", true, false) + ([base] if base is MeshInstance3D else []):
		for v in (mi as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			vs.append((mi as Node3D).global_transform * v)
	var xmin := INF
	for v in vs:
		xmin = minf(xmin, v.x)
	var mozzo := Vector3.ZERO
	var n := 0
	for v in vs:
		if v.x < xmin + 0.02:
			mozzo += v
			n += 1
	mozzo /= maxf(n, 1)
	var h := _lontano(leva, leva.global_position)
	var e := _lontano(leva, h)   # l'estremità opposta all'impugnatura: l'occhio
	print("occhio: estremità %s, centro circa %s" % [str(e), str(e + (h - e).normalized() * 0.035)])
	print("origine del braccio %s, nodo della logica %s, mozzo della base %s" % [str(leva.global_position), str(lg.global_position), str(mozzo)])
	for passo in [["riposo", 0.0], ["meta", 0.5], ["fine", 0.999]]:
		if passo[1] > 0.0:
			lg.abbassata = true
			lg._t = passo[1]
		for i in 40:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_jpg(out_dir.path_join(prefisso + "leva_" + passo[0] + ".jpg"), 0.9)
		print("passo %s: origine spostata di %.3f m, impugnatura (punto più lontano dal perno) %s" % [passo[0], leva.global_position.distance_to(perno), str(_lontano(leva, perno))])
	get_tree().quit()


## Il punto della mesh del braccio più lontano dal perno: l'impugnatura.
func _lontano(leva: Node3D, perno: Vector3) -> Vector3:
	var best := perno
	for mi in leva.find_children("*", "MeshInstance3D", true, false) + ([leva] if leva is MeshInstance3D else []):
		var m := (mi as MeshInstance3D).mesh
		if m == null:
			continue
		for v in m.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			var g: Vector3 = (mi as Node3D).global_transform * v
			if g.distance_to(perno) > best.distance_to(perno):
				best = g
	return best
