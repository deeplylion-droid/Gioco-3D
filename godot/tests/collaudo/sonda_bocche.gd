extends Node
## Collaudo dei ritocchi di ambienti-2 (dopo la 0.3.20): gli occhi sopra l'acqua entrando nelle 6 bocche dei tubi e degli
## scoli che partono dalle vasche dei bivi (Player.occhi_minimo, messo da SalaInseguimento). La torre da sola, le
## paratie tutte aperte (giuste e sbagliate), lei che non prende. Per ogni bocca, col giocatore vero accovacciato:
##  - "entra": 2 m prima della bocca nell'acqua della vasca, avanti fino a 3,5 m dentro il tubo;
##  - "torna": 1,2 m dentro, poi indietro verso la vasca per 3 s (tasto indietro), guardando la vasca.
## A ogni fotogramma: dove sta l'occhio lungo il tubo (dalla parete d'acqua della bocca, m), la camera sopra il pelo,
## il limite (occhi_minimo) e se sta tenendo su la camera; il salto della camera (la differenza seconda della quota,
## per fotogramma) dove il limite entra o smette, contro quello del resto della strada. Stampa BOCCA:.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/sonda_bocche.gd

const PLAYER := "res://scenes/player/player.tscn"


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	GameState.luci = GameState.Luci.BLACKOUT
	var torre := (load("res://scenes/sala/torre/sala_torre.tscn") as PackedScene).instantiate() as SalaTorre
	add_child(torre)
	await _frames(20)
	var ins := torre.inseguimento as SalaInseguimento
	ins.tempo_presa = 9999.0
	for k in (ins.dati["paratie"] as Array).size():
		ins.apri_paratia(k)
	await _frames(240)
	var veli := ins.find_children(SalaInseguimento.NOME_VELO + "*", "MeshInstance3D", true, false)
	print("BOCCA: %d pareti d'acqua nelle bocche" % veli.size())
	var p := (load(PLAYER) as PackedScene).instantiate() as Player
	add_child(p)
	await _frames(5)
	for nome: String in ["ins_A_tubo_1", "ins_A_scolo_0", "ins_A_tubo_2", "ins_A_scolo_1", "ins_A_tubo_3", "ins_A_scolo_2"]:
		if ins.lei:
			ins.lei.visible = false
		var linea := PackedVector3Array()
		for q in ins.dati["tubi"][nome]:
			linea.append(SalaInseguimento.b(q))
		# la parete d'acqua di questa bocca: la più vicina all'inizio della linea
		var velo: MeshInstance3D = null
		for v in veli:
			if velo == null or (v as Node3D).global_position.distance_to(linea[0]) < velo.global_position.distance_to(linea[0]):
				velo = v
		var pelo := float(velo.get_meta(&"pelo"))
		for modo in ["entra", "torna"]:
			var dir := linea[3] - linea[0]
			dir.y = 0.0
			dir = dir.normalized()
			var da := linea[0] - dir * 2.0 + Vector3.DOWN * (SalaInseguimento.R_TUBO - 0.1)
			p.teleport(da + Vector3.UP * 0.5)
			await _frames(20)
			p.velocity = Vector3.ZERO
			Input.action_press(&"crouch")
			await _frames(20)
			Input.action_press(&"move_forward")
			var ys := []
			var min_sopra := INF
			var min_dove := 0.0
			var limite_attivo := 0
			var salti := []   # [|d2|, l.z]
			var ultimo := 0
			var indietro := false
			var t_indietro := 0
			for f in 60 * 14:
				var piedi := p.global_position
				var iv := ultimo
				for i in range(ultimo, mini(ultimo + 12, linea.size())):
					if linea[i].distance_to(piedi) < linea[iv].distance_to(piedi):
						iv = i
				ultimo = iv
				var lz := (velo.global_transform.affine_inverse() * p.camera.global_position).z
				if not indietro:
					var av := mini(iv + 4, linea.size() - 1)
					var g := linea[av] - piedi
					g.y = 0.0
					if g.length() > 0.2:
						p.set_look(atan2(-g.x, -g.z), -0.15)
				else:
					p.set_look(atan2(dir.x, dir.z), -0.25)
				await get_tree().process_frame
				var cy := p.camera.global_position.y
				ys.append(cy)
				var sopra := cy - pelo
				if lz > -0.6 and lz < 3.0 and sopra < min_sopra:
					min_sopra = sopra
					min_dove = lz
				if p.occhi_minimo > -1e9 and absf(cy - p.occhi_minimo) < 0.002:
					limite_attivo += 1
				if ys.size() >= 3:
					var d2: float = absf(ys[-1] - 2.0 * ys[-2] + ys[-3])
					salti.append([d2, lz])
				if modo == "entra" and lz > 3.5:
					break
				if modo == "torna" and not indietro and lz > 1.2:
					indietro = true
					Input.action_release(&"move_forward")
					Input.action_press(&"move_back")
				if indietro:
					t_indietro += 1
					if t_indietro > 180:
						break
			Input.action_release(&"move_forward")
			Input.action_release(&"move_back")
			Input.action_release(&"crouch")
			var max_lim := 0.0
			var dove_lim := 0.0
			var max_resto := 0.0
			for s in salti:
				var in_zona: bool = (s[1] > 0.2 and s[1] < 0.7) or (s[1] > 1.8 and s[1] < 2.9) or (s[1] > -0.7 and s[1] < -0.3)
				if in_zona and s[0] > max_lim:
					max_lim = s[0]
					dove_lim = s[1]
				elif not in_zona:
					max_resto = maxf(max_resto, s[0])
			print("BOCCA: %s, %s: camera sopra il pelo al minimo %.3f m (a %.2f m dalla bocca), limite che la tiene su in %d fotogrammi; salto della camera dove il limite entra o smette %.1f mm (a %.2f m), nel resto %.1f mm; fine a %.2f m dalla bocca%s" % [
					nome, modo, min_sopra, min_dove, limite_attivo, max_lim * 1000.0, dove_lim, max_resto * 1000.0,
					(velo.global_transform.affine_inverse() * p.camera.global_position).z, "  <-- SOTTO" if min_sopra < 0.03 else ""])
			await _frames(20)
	print("BOCCA: finito")
	get_tree().quit()
