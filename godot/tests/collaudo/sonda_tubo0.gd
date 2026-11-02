extends Node
## Collaudo: si entra a piedi nei tubi dell'inseguimento partendo da dove sta chi gioca? Per ogni tubo (argomento: lista
## separata da virgole, o "tutti"), il giocatore vero parte dal checkpoint più vicino alla bocca (o, se manca, 3 m prima
## della bocca sul fondo dell'acqua), cammina verso la bocca e poi lungo la linea del tubo col tasto avanti, saltando
## se resta fermo davanti alla bocca. Stampa fin dove arriva lungo la linea, se ha dovuto saltare e dove si è fermato.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/sonda_tubo0.gd <tubi>

const PLAYER := "res://scenes/player/player.tscn"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	var a0 := OS.get_cmdline_user_args()
	GameState.luci = GameState.Luci.BLACKOUT
	var torre := (load("res://scenes/sala/torre/sala_torre.tscn") as PackedScene).instantiate() as SalaTorre
	add_child(torre)
	for i in 20:
		await get_tree().physics_frame
	var ins := torre.inseguimento as SalaInseguimento
	ins.tempo_presa = 9999.0
	for k in (ins.dati["paratie"] as Array).size():
		ins.apri_paratia(k)
	for i in 240:
		await get_tree().physics_frame
	var p := (load(PLAYER) as PackedScene).instantiate() as Player
	add_child(p)
	for i in 5:
		await get_tree().physics_frame
	var cps := torre.find_children("*", "Checkpoint", true, false)
	var tubi: Array = ins.dati["tubi"].keys() if a0[1] == "tutti" else Array(a0[1].split(","))
	for nome: String in tubi:
		if ins.lei:
			ins.lei.visible = false
		var linea := PackedVector3Array()
		for q in ins.dati["tubi"][nome]:
			linea.append(SalaInseguimento.b(q))
		var dir := linea[3] - linea[0]
		dir.y = 0.0
		dir = dir.normalized()
		# dove sta chi arriva: il checkpoint (o la ripartenza) più vicino alla bocca, se è a meno di 8 m
		var da := linea[0] - dir * 3.0
		var nome_da := "3 m prima della bocca"
		var migliore := 8.0
		for c in cps:
			var cp := c as Checkpoint
			var sp: Node3D = cp.spawn_point if cp.spawn_point else cp
			var dd := sp.global_position.distance_to(linea[0])
			if dd < migliore and sp.global_position.y < linea[0].y + 1.0:
				migliore = dd
				da = sp.global_position
				nome_da = String(torre.get_path_to(cp))
		var h := p.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(da + Vector3.UP * 1.5, da + Vector3.DOWN * 3.0, Layers.WORLD))
		if not h.is_empty():
			da = h.position
		p.teleport(da + Vector3.UP * 0.05)
		for i in 30:
			await get_tree().physics_frame
		p.velocity = Vector3.ZERO
		var salti := 0
		var ultimo := 0
		var fermo := 0
		var prima := p.global_position
		Input.action_press(&"move_forward")
		for f in 60 * 20:
			var piedi := p.global_position
			var iv := ultimo
			for i in range(ultimo, mini(ultimo + 12, linea.size())):
				if linea[i].distance_to(piedi) < linea[iv].distance_to(piedi):
					iv = i
			ultimo = iv
			var av := mini(iv + 4, linea.size() - 1) if piedi.distance_to(linea[0]) < 1.5 or iv > 0 else 0
			var g := linea[av] - piedi
			g.y = 0.0
			if g.length() > 0.2:
				p.set_look(atan2(-g.x, -g.z), -0.2)
			fermo = fermo + 1 if piedi.distance_to(prima) < 0.004 else 0
			prima = piedi
			if fermo == 40:
				Input.action_press(&"jump")
				salti += 1
			if fermo == 44:
				Input.action_release(&"jump")
				fermo = 0
			await get_tree().physics_frame
			if iv >= linea.size() - 2:
				break
		Input.action_release(&"move_forward")
		Input.action_release(&"jump")
		print("TUBO: %s da %s (%s, %.1f m dalla bocca; bocca %s): arrivato all'indice %d/%d, salti %d, fine %s, sul pavimento %s" % [nome,
				da.snapped(Vector3.ONE * 0.01), nome_da, da.distance_to(linea[0]), linea[0].snapped(Vector3.ONE * 0.01), ultimo, linea.size(),
				salti, p.global_position.snapped(Vector3.ONE * 0.01), p.is_on_floor()])
	print("TUBO: finito")
	get_tree().quit()
