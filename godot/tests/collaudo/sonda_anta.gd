extends Node
## Collaudo (squadra collaudo): l'anta che sbatte degli spogliatoi e il pallone, col renderer vero e le luci degli
## interni, nella scena degli interni da sola. L'anta si muove con la funzione vera del gioco (Interni._sbatti_anta,
## animata): scatti chiusa, durante il colpo (ogni 3 fotogrammi) e aperta, da tre punti di vista; poi ravvicinati del
## salvagente-papera dentro, del pallone e dell'anta aperta est2_02.
## Uso: xvfb-run ... godot --path godot --rendering-driver vulkan --resolution 960x540 --fixed-fps 60 \
##        --script res://tests/run.gd -- res://tests/collaudo/sonda_anta.gd <cartella>

const INTERNI := "res://scenes/interni/interni.tscn"

var cart := ""
var cam: Camera3D
var _n := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	cart = OS.get_cmdline_user_args()[1]
	DirAccess.make_dir_recursive_absolute(cart)
	Game.pause_on_focus_loss = false
	var interni := (load(INTERNI) as PackedScene).instantiate()
	add_child(interni)
	for i in 30:
		await get_tree().process_frame
	for p in interni.find_children("*", "Player", true, false):
		(p as Node3D).visible = false
		p.process_mode = Node.PROCESS_MODE_DISABLED
	var spog := interni.get_node("Ambienti/Spogliatoi") as Node3D
	var anta := spog.find_child("armadietto_sbatte_anta", true, false) as Node3D
	var cardine := spog.find_child("cardine_armadietto_sbatte", true, false) as Node3D
	var papera: Node3D = null
	for n in spog.find_children("*", "Node3D", true, false):
		var nm := String(n.name).to_lower()
		if (nm.contains("papera") or nm.contains("salvagente")) and (n as Node3D).global_position.distance_to(anta.global_position) < 1.2:
			papera = n
	var pallone := spog.find_child("pallone_spogliatoi", true, false) as Node3D
	var ab := (anta as MeshInstance3D).get_aabb() if anta is MeshInstance3D else AABB()
	var centro: Vector3 = anta.global_transform * ab.get_center()
	print("ANTA: anta ", anta.global_position, " centro ", centro, " cardine ", cardine.global_position if cardine else "-", " papera ", papera.get_path() if papera else "-", " pallone ", pallone.global_position if pallone else "-")
	cam = Camera3D.new()
	cam.fov = 70.0
	cam.near = 0.02
	add_child(cam)
	cam.current = true
	var chiusa := anta.transform
	# i punti di vista: dove passa il giocatore (davanti, di lato e da vicino)
	var fuori := (centro - cardine.global_position) if cardine else Vector3.RIGHT
	fuori.y = 0.0
	var davanti := anta.global_transform.basis.z.normalized()
	if davanti.dot(Vector3(8.9, 0, -4.1) - Vector3(centro.x, 0, centro.z)) < 0.0:
		davanti = -davanti
	var viste := {
		"occhi": centro + davanti * 2.2 + Vector3.UP * (1.6 - centro.y) + fuori.normalized() * 0.4,
		"lato": centro + davanti * 1.4 - fuori.normalized() * 1.3 + Vector3.UP * (1.5 - centro.y),
		"vicino": centro + davanti * 0.9 + fuori.normalized() * 0.5 + Vector3.UP * 0.35,
	}
	for v in viste:
		anta.transform = chiusa
		cam.look_at_from_position(viste[v], centro)
		for i in 20:
			await get_tree().process_frame
		await _foto("%s_0_chiusa" % v)
		interni.call(&"_sbatti_anta", anta, true)
		for k in 18:
			for i in 3:
				await get_tree().physics_frame
			await _foto("%s_1_colpo_%02d" % [v, k])
		for i in 30:
			await get_tree().physics_frame
		await _foto("%s_2_aperta" % v)
	# dentro l'armadietto: il salvagente-papera con l'anta aperta, da vicino e da sopra
	if papera:
		var pc := papera.global_position
		cam.look_at_from_position(pc + davanti * 0.8 + Vector3.UP * 0.4, pc)
		await _passa(10)
		await _foto("papera_vicino")
		cam.look_at_from_position(pc + davanti * 0.5 + Vector3.UP * 0.9 + fuori.normalized() * 0.3, pc)
		await _passa(10)
		await _foto("papera_sopra")
	if pallone:
		var pp := pallone.global_position
		for k in 4:
			var a := TAU * float(k) / 4.0
			cam.look_at_from_position(pp + Vector3(cos(a), 0.0, sin(a)) * 1.0 + Vector3.UP * 0.6, pp)
			await _passa(10)
			await _foto("pallone_%d" % k)
	print("ANTA: finito, %d scatti" % _n)
	get_tree().quit()


func _passa(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _foto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(cart.path_join(nome + ".jpg"), 0.85)
	_n += 1
