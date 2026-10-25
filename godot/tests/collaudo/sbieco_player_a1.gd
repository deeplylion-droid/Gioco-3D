extends Node
## Collaudo di ambienti-1 (25 ottobre sera) del passo sui gradini di player.gd (lavoro/acqua-senza-salto: il passo provato
## nella direzione del comando, di sbieco): il giocatore vero contro scale e ostacoli costruiti qui, dritto e a 30, 45 e 60
## gradi, per 3 s. Per ognuno: se è salito sopra, quanto è avanzato, il salto più grande della camera in un fotogramma.
## Si lancia col player.gd nuovo e con quello di prima: le tabelle si confrontano (niente salite nuove su cose che prima
## non si salivano, niente blocchi nuovi, niente scatti).
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/sbieco_player_a1.gd

const PLAYER := "res://scenes/player/player.tscn"
## [nome, tipo, misura]: scala (alzata, pedata), gradino (altezza), rampa (gradi)
const PROVE := [
	["scala 17/28", "scala", Vector2(0.17, 0.28)],
	["scala 22/25", "scala", Vector2(0.22, 0.25)],
	["scala 30/30", "scala", Vector2(0.30, 0.30)],
	["gradino 0,30", "gradino", 0.30],
	["gradino 0,34", "gradino", 0.34],
	["gradino 0,40", "gradino", 0.40],
	["gradino 0,60", "gradino", 0.60],
	["rampa 40°", "rampa", 40.0],
	["rampa 55°", "rampa", 55.0],
]
var p: Player


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	var pavimento := _scatola(Vector3(200, 1, 200), Vector3(0, -0.5, 0))
	add_child(pavimento)
	p = (load(PLAYER) as PackedScene).instantiate() as Player
	add_child(p)
	await _frames(10)
	var k := 0
	for prova in PROVE:
		var ostacolo := _ostacolo(prova[1], prova[2])
		ostacolo.position = Vector3(k * 12.0, 0, 0)
		add_child(ostacolo)
		k += 1
		var riga := []
		for g in [0.0, 30.0, 45.0, 60.0]:
			var a := deg_to_rad(g)
			# l'ostacolo comincia a z = -1 (verso -z): il giocatore parte 1 m prima, girato di g gradi
			var da := ostacolo.position + Vector3(0, 0.05, 0)
			var verso := Vector3(sin(a), 0, -cos(a))
			p.teleport(da, atan2(-verso.x, -verso.z))
			await _frames(8)
			Input.action_press(&"move_forward")
			var y_max := 0.0
			var salto := 0.0
			var cam_prima := p.camera.global_position.y
			for i in 180:
				await get_tree().physics_frame
				y_max = maxf(y_max, p.global_position.y)
				var cy := p.camera.global_position.y
				salto = maxf(salto, absf(cy - cam_prima))
				cam_prima = cy
			Input.action_release(&"move_forward")
			var avanti := -(p.global_position.z - da.z)
			riga.append("%s: su %.2f m, avanti %.2f m, scatto camera %.3f m" % ["dritto" if g == 0.0 else "%d°" % int(g), y_max, avanti, salto])
			await _frames(5)
		print("SBIECO %s | %s" % [prova[0], " | ".join(riga)])
		ostacolo.queue_free()
		await _frames(2)
	get_tree().quit()


func _scatola(size: Vector3, pos: Vector3) -> StaticBody3D:
	var b := StaticBody3D.new()
	var f := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	f.shape = s
	f.position = pos
	b.add_child(f)
	return b


func _ostacolo(tipo: String, misura) -> Node3D:
	var n := Node3D.new()
	match tipo:
		"scala":
			var m: Vector2 = misura
			for i in 10:
				n.add_child(_scatola(Vector3(6, m.x * (i + 1), m.y), Vector3(0, m.x * (i + 1) * 0.5, -1.0 - m.y * (i + 0.5))))
			# il pianerottolo in cima
			n.add_child(_scatola(Vector3(6, m.x * 10, 4), Vector3(0, m.x * 5, -1.0 - m.y * 10 - 2.0)))
		"gradino":
			var h: float = misura
			n.add_child(_scatola(Vector3(6, h, 4), Vector3(0, h * 0.5, -3.0)))
		"rampa":
			var a := deg_to_rad(float(misura))
			var b := _scatola(Vector3(6, 0.2, 6), Vector3.ZERO)
			b.rotation.x = a
			b.position = Vector3(0, sin(a) * 3.0 - 0.1, -1.0 - cos(a) * 3.0)
			n.add_child(b)
	return n


func _frames(k: int) -> void:
	for i in k:
		await get_tree().physics_frame
