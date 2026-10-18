extends Node
## Video dal motore della scena di prova degli scivoli (Movie Maker): dalla piattaforma in alto si
## entra nel giallo, si scivola, salto sul rosso, a fine rosso lo sguardo in basso e il getto tenuto
## che allunga il salto fino al blu, poi giù fino alla piattaforma del fondo.
## Uso (sotto flock /home/user/tools/render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##     --fixed-fps 30 --write-movie /tmp/scivoli.avi --script res://tests/run.gd -- res://tests/video_scivoli.gd

const LEVEL := "res://scenes/test/scivoli_prova.tscn"

var p: Player


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	Grafica.applica_preset("alto")
	get_tree().change_scene_to_file(LEVEL)
	await _frames(10)
	p = GameState.player
	for i in 400:
		if p.input_enabled:
			break
		await get_tree().process_frame
	var hud := p.get_node_or_null(^"HUD")
	if hud:
		hud.visible = false
	p.set_look(0.0, deg_to_rad(-12.0))
	await _frames(20)
	print("INIZIO")
	Input.action_press(&"move_forward")
	for i in 240:
		await get_tree().physics_frame
		if p.is_sliding:
			break
	Input.action_release(&"move_forward")
	var lanci := 0
	var era := true
	var spruzzo := false
	var guarda := deg_to_rad(-12.0)
	for i in 30 * 16:
		await get_tree().physics_frame
		if p.is_sliding != era:
			era = p.is_sliding
			if not era:
				lanci += 1
				if lanci == 2:
					Input.action_press(&"spray")
					spruzzo = true
			elif spruzzo:
				Input.action_release(&"spray")
				spruzzo = false
		# Lo sguardo segue la discesa (un poco avanti); col getto si guarda giù, come serve.
		var v := p.velocity
		if Vector2(v.x, v.z).length() > 1.0:
			var dir := atan2(-v.x, -v.z)
			p.set_look(lerp_angle(p.yaw, dir, 0.08), p.pitch)
		var voluto := deg_to_rad(-48.0) if spruzzo else deg_to_rad(-14.0)
		guarda = lerpf(guarda, voluto, 0.15)
		p.set_look(p.yaw, guarda)
		if p.is_on_floor() and not p.is_sliding and lanci >= 2:
			break
	Input.action_release(&"spray")
	await _frames(45)
	print("FINE")
	get_tree().quit()
