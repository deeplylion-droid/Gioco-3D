extends Node
## Collaudo del ritmo dei passi (0.3.17: un passo ogni 1,0 m camminando, 1,3 correndo, 0,7 accovacciati): il giocatore
## vero su un pavimento piatto, coi tasti veri, cammina, corre e va accovacciato per 6 s ciascuno. Conta i segnali
## footstep (passi al secondo, metri per passo, quanto sono regolari) e misura il dondolio della camera (alto-basso e
## di lato) rispetto agli occhi senza dondolio.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/sonda_passi.gd

const PLAYER := "res://scenes/player/player.tscn"
var p: Player
var _tempi: Array[float] = []
var _t := 0.0


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _passo(_s: StringName, _w: bool, _i: float) -> void:
	_tempi.append(_t)


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	var corpo := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(400, 1, 400)
	cs.shape = b
	corpo.add_child(cs)
	add_child(corpo)
	corpo.position = Vector3(0, -0.5, 0)
	p = (load(PLAYER) as PackedScene).instantiate() as Player
	add_child(p)
	await _frames(10)
	p.teleport(Vector3(0, 0.05, 150))
	await _frames(30)
	p.footstep.connect(_passo)
	for modo in ["cammina", "corre", "accovacciato"]:
		p.teleport(Vector3(0, 0.05, 150))
		p.look_at_point(Vector3(0, 1.5, -100))
		await _frames(20)
		if modo == "corre":
			Input.action_press(&"sprint")
		if modo == "accovacciato":
			Input.action_press(&"crouch")
			await _frames(30)
		Input.action_press(&"move_forward")
		await _frames(90)   # partenza
		_tempi.clear()
		var da := p.global_position
		var ymin := INF
		var ymax := -INF
		var xmin := INF
		var xmax := -INF
		var cam := p.get_viewport().get_camera_3d()
		for f in 360:
			_t = f / 60.0
			await get_tree().physics_frame
			var occhi := p.get_eye_position()
			var d := cam.global_position - occhi
			ymin = minf(ymin, d.y)
			ymax = maxf(ymax, d.y)
			xmin = minf(xmin, d.x)
			xmax = maxf(xmax, d.x)
		var strada := Vector2(p.global_position.x - da.x, p.global_position.z - da.z).length()
		Input.action_release(&"move_forward")
		Input.action_release(&"sprint")
		Input.action_release(&"crouch")
		var intervalli: Array[float] = []
		for i in range(1, _tempi.size()):
			intervalli.append(_tempi[i] - _tempi[i - 1])
		var media := 0.0
		for x in intervalli:
			media += x
		media /= maxf(intervalli.size(), 1)
		var scarto := 0.0
		for x in intervalli:
			scarto = maxf(scarto, absf(x - media))
		print("PASSI: %s: %.2f m/s, %d passi in 6 s (%.2f al secondo), %.2f m per passo, intervallo %.3f s (scarto massimo %.3f s); dondolio alto-basso %.1f cm, di lato %.1f cm" % [
				modo, strada / 6.0, _tempi.size(), _tempi.size() / 6.0, strada / maxf(_tempi.size(), 1), media, scarto,
				(ymax - ymin) * 100.0, (xmax - xmin) * 100.0])
		await _frames(60)
	print("PASSI: finito")
	get_tree().quit()
