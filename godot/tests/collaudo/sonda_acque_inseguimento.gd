extends Node
## Sonda (non in CI): le acque dell'inseguimento e del fondo della torre (le mesh acqua*), e per ogni tubo e scolo il
## giocatore vero che parte dalla vasca da cui il tubo esce (fermo nell'acqua 2 m prima della bocca, cammina dentro) e
## scivola fino in fondo. A ogni fotogramma, per ogni acqua sotto cui sta l'occhio (dentro la sua pianta), quanto
## l'occhio è sopra il pelo: sotto zero da lì si vede l'acqua da sotto. Stampa il minimo per tubo e per acqua.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/sonda_acque_inseguimento.gd [tubi]

const PLAYER := "res://scenes/player/player.tscn"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.luci = GameState.Luci.BLACKOUT
	var torre := (load("res://scenes/sala/torre/sala_torre.tscn") as PackedScene).instantiate() as SalaTorre
	torre.crea_luci = false
	add_child(torre)
	for i in 20:
		await get_tree().physics_frame
	var ins := torre.inseguimento as SalaInseguimento
	# le paratie aperte (i bersagli verdi colpiti) e lei che non prende
	ins.tempo_presa = 9999.0
	for k in (ins.dati["paratie"] as Array).size():
		ins.apri_paratia(k)
	for i in 240:
		await get_tree().physics_frame
	var acque := _acque(torre)
	for a in acque:
		print("ACQUA %s pelo %.3f pianta x %.2f..%.2f z %.2f..%.2f" % [a["nome"], a["pelo"], a["x0"], a["x1"], a["z0"], a["z1"]])
	var solo := OS.get_cmdline_user_args().slice(1)
	var p := (load(PLAYER) as PackedScene).instantiate() as Player
	add_child(p)
	for i in 5:
		await get_tree().physics_frame
	for nome: String in ins.dati["tubi"]:
		if not solo.is_empty() and not solo.has(nome):
			continue
		if ins.lei:
			ins.lei.visible = false
		var linea := PackedVector3Array()
		for q in ins.dati["tubi"][nome]:
			linea.append(SalaInseguimento.b(q))
		var dir := linea[3] - linea[0]
		dir.y = 0.0
		dir = dir.normalized()
		# 2 m prima della bocca, coi piedi sul fondo dell'acqua di partenza (o sul fondo del tubo se non c'è acqua)
		var da := linea[0] - dir * 2.0 + Vector3.DOWN * (SalaInseguimento.R_TUBO - 0.1)
		p.teleport(da + Vector3.UP * 0.5)
		for i in 20:
			await get_tree().physics_frame
		p.velocity = Vector3.ZERO
		print("PARTE %s da %s (bocca %s)" % [nome, p.global_position, linea[0]])
		Input.action_press(&"move_forward")
		var minimi := {}
		var ultimo := 0
		var arrivato := 0
		for f in 60 * 14:
			await get_tree().physics_frame
			var piedi := p.global_position
			var iv := ultimo
			for i in range(ultimo, mini(ultimo + 12, linea.size())):
				if linea[i].distance_to(piedi) < linea[iv].distance_to(piedi):
					iv = i
			ultimo = iv
			var av := mini(iv + 4, linea.size() - 1)
			var g := linea[av] - piedi
			g.y = 0.0
			if g.length() > 0.2:
				p.set_look(atan2(-g.x, -g.z), -0.2)
			var occhi := p.get_viewport().get_camera_3d().global_position
			for a in acque:
				if occhi.x > a["x0"] and occhi.x < a["x1"] and occhi.z > a["z0"] and occhi.z < a["z1"] and occhi.y > a["pelo"] - 3.0:
					var h: float = occhi.y - a["pelo"]
					if not minimi.has(a["nome"]) or h < minimi[a["nome"]][0]:
						minimi[a["nome"]] = [h, occhi, iv]
			if iv >= linea.size() - 2:
				arrivato += 1
				if arrivato > 90:
					break
		Input.action_release(&"move_forward")
		for k in minimi:
			var m: Array = minimi[k]
			print("OCCHI %s in %s: minimo %.3f m sopra il pelo, a %s (indice %d/%d)%s" % [nome, k, m[0], m[1], m[2], linea.size(),
					"  <-- SOTTO" if m[0] < 0.0 else ""])
		if minimi.is_empty():
			print("OCCHI %s: mai sopra un'acqua" % nome)
	get_tree().quit()


## Le mesh d'acqua (acqua*), con il pelo (il punto più alto) e la pianta (globali).
func _acque(radice: Node) -> Array:
	var out := []
	for m in radice.find_children("acqua*", "MeshInstance3D", true, false):
		if String(m.name).begins_with(SalaInseguimento.NOME_VELO):
			continue
		var mi := m as MeshInstance3D
		var box := mi.global_transform * mi.get_aabb()
		out.append({"nome": String(mi.name), "pelo": box.end.y, "x0": box.position.x, "x1": box.end.x,
			"z0": box.position.z, "z1": box.end.z})
	return out
