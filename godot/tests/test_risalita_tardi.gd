extends Node
## Le stanze della Risalita (fiume e infermeria) caricate più tardi, per la memoria (risalita_gioco.gd, 23 ottobre):
## 1. all'avvio della sala non ci sono, ma la Polaroid della pecora conta già nel totale;
## 2. dalla sala pompe in poi (checkpoint 6) si caricano nel thread, col giocatore ancora lontano;
## 3. caricate dopo il risveglio sono uguali a quelle che c'erano da sempre (prima del 23 ottobre): luci (accese,
##    forza, colore, ombre), mesh e materiali, dopo il flash e il blackout come nel gioco;
## 4. oltre il magazzino, col giocatore lontano, si scaricano: lo stato dei loro oggetti resta nelle istantanee e
##    torna quando si ricaricano;
## 5. ripartendo da un checkpoint della strada nuova ci sono subito, con lo stato del checkpoint;
## e l'elenco dei file che il thread carica per le stanze (scenes/risalita/risorse_stanze.json) è completo, e ogni shader
## delle stanze la sala lo ha già all'avvio (materiali_campione.tres).
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_risalita_tardi.gd

const SCENA := "res://scenes/sala_principale.tscn"
const AGGIORNA := preload("res://tests/aggiorna_risorse_risalita.gd")

var level: Node
var p: Player
var _passed := 0
var _failed := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	Engine.set_meta(&"precarica_torre_spento", true)

	print("Prima: le stanze caricate subito, come prima del 23 ottobre")
	Engine.set_meta(&"risalita_subito", true)
	get_tree().change_scene_to_file(SCENA)
	await _aspetta_livello()
	var ris := level.get_node(^"Risalita")
	check(ris.get(&"fiume") != null, "con risalita_subito le stanze ci sono dall'inizio")
	await _risveglio()
	await _dentro(ris)
	var prima := _impronta(ris)
	var elenco := AGGIORNA.elenco(ris)
	var nel_file: Array = JSON.parse_string(FileAccess.get_file_as_string(AGGIORNA.ELENCO))
	var mancano := Array(elenco).filter(func(x): return not x in nel_file)
	check(mancano.is_empty(), "l'elenco dei file delle stanze è completo (mancano %d: %s; rifallo con tests/aggiorna_risorse_risalita.gd)" % [mancano.size(), str(mancano.slice(0, 5))])
	Engine.remove_meta(&"risalita_subito")

	print("1. All'avvio non ci sono")
	GameState.reset_progress()
	get_tree().change_scene_to_file(SCENA)
	await _aspetta_livello()
	ris = level.get_node(^"Risalita")
	await _secondi(0.5)
	check(ris.get(&"fiume") == null and not ris.has_node(^"Fiume") and not ris.has_node(^"Infermeria"),
		"all'avvio della sala il fiume e l'infermeria non sono caricati")
	# (9 della sala e la P14 degli acquari, la pecora e la P16 del fiume, la P13 e la P15 dei corridoi della risalita)
	check(GameState.get_total(&"polaroid") == 14, "la Polaroid della pecora e la P16 del fiume contano già: %d in tutto" % GameState.get_total(&"polaroid"))
	var shader_sala := {}
	RisorseNodi.materiali_per_shader(level, shader_sala)
	for m in ris.get(&"_campioni"):
		shader_sala[RisorseNodi.chiave_shader(m)] = m

	print("2. Dalla sala pompe, nel thread")
	await _risveglio()
	check(ris.get(&"fiume") == null, "dopo il risveglio, senza checkpoint della sala pompe, ancora no")
	GameState.capture_snapshot("prova_sala_pompe", 6, p.global_transform)
	var f := 0
	while ris.get(&"fiume") == null and f < 60 * 60:
		await get_tree().process_frame
		f += 1
	check(ris.get(&"fiume") != null, "dal checkpoint della sala pompe le stanze arrivano (%.1f s, giocatore a %.1f m)" % [f / 60.0, ris.call(&"_distanza", p.global_position)])

	var nuovi: Array = AGGIORNA.shader_nuovi(ris, shader_sala)
	check(nuovi.is_empty(), "gli shader delle stanze ci sono già dall'avvio (nuovi %d: %s; rifai i campioni con tests/aggiorna_risorse_risalita.gd)" % [nuovi.size(), str(nuovi.map(func(x): return x[1].resource_path))])

	print("3. Uguali a quelle di prima")
	await _dentro(ris)
	var dopo := _impronta(ris)
	var diversi := PackedStringArray()
	for k in prima:
		if dopo.get(k) != prima[k]:
			diversi.append("%s\n      prima %s\n      dopo  %s" % [k, prima[k], dopo.get(k, "(manca)")])
	for k in dopo:
		if not prima.has(k):
			diversi.append("%s: in più (%s)" % [k, dopo[k]])
	check(diversi.is_empty() and prima.size() > 500, "%d nodi, %d diversi%s" % [prima.size(), diversi.size(),
		"" if diversi.is_empty() else ":\n    " + "\n    ".join(diversi.slice(0, 15))])

	print("4. Scaricate oltre il magazzino, con lo stato da parte")
	var par := ris.get_node(^"Fiume/FiumeLento/Paratia1") if ris.has_node(^"Fiume/FiumeLento/Paratia1") else ris.find_children("Paratia1", "ParatiaFiume", true, false)[0]
	var chiave := GameState.persist_key(par)
	par.call(&"gira")
	await _secondi(0.2)
	var girata: Dictionary = par.call(&"save_state")
	GameState.capture_snapshot("prova_serranda", 16, p.global_transform)
	p.teleport(Vector3(0, 0, 0), 0.0, 0.0)
	await _secondi(0.5)
	check(ris.get(&"fiume") == null and not ris.has_node(^"Fiume"), "lontano, oltre il magazzino, le stanze si scaricano")
	GameState.capture_snapshot("prova_area_bimbi", 17, p.global_transform)
	var oggetti: Dictionary = GameState.snapshot.get("objects", {})
	check(oggetti.get(chiave) == girata, "l'istantanea senza le stanze ha lo stato della paratia (%s)" % str(oggetti.get(chiave)))
	p.teleport((ris.get_node(^"Marker/PortaFiume") as Node3D).global_position, 0.0, 0.0)
	await _secondi(0.3)
	par = level.get_node_or_null(NodePath(chiave))
	check(par != null and par.call(&"save_state") == girata, "tornando, le stanze ci sono di nuovo con la paratia girata (%s)" % (str(par.call(&"save_state")) if par else "manca"))

	print("5. Ripartendo da un checkpoint della strada nuova")
	var cp := level.get_node(^"Risalita/Fiume/Checkpoint/CheckpointIngresso") as Checkpoint
	GameState.capture_snapshot(GameState.persist_key(cp), cp.order, cp.get_spawn_transform())
	(level.get_node(NodePath(chiave))).call(&"gira")
	GameState.respawn()
	await _aspetta_livello()
	ris = level.get_node(^"Risalita")
	par = level.get_node_or_null(NodePath(chiave))
	check(par != null and par.call(&"save_state") == girata, "dopo la ripartenza le stanze ci sono, con lo stato del checkpoint (%s)" % (str(par.call(&"save_state")) if par else "manca"))
	_fine()


## Come nel gioco: il flash del risveglio e poi il blackout.
func _risveglio() -> void:
	GameState.imposta_luci(GameState.Luci.FLASH)
	await _secondi(1.2)
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	await _secondi(1.0)


## Il giocatore all'ingresso del capannone (le stanze si disegnano), qualche secondo.
func _dentro(ris: Node) -> void:
	p.teleport((ris.get_node(^"Fiume/Marker/Ingresso") as Node3D).global_position, 0.0, 0.0)
	await _secondi(1.5)


## Quello che si vede delle stanze: luci, geometrie e materiali, nodo per nodo.
func _impronta(ris: Node) -> Dictionary:
	var out := {}
	for radice in [ris.get_node(^"Fiume"), ris.get_node(^"Infermeria")]:
		for n in [radice] + radice.find_children("*", "Node3D", true, false):
			var k := _percorso(ris, n)
			var t := (n as Node3D).global_transform
			var v := "vis=%s pos=%s rot=%s scala=%s" % [(n as Node3D).is_visible_in_tree(), t.origin.snapped(Vector3.ONE * 0.001),
				t.basis.get_euler().snapped(Vector3.ONE * 0.001), t.basis.get_scale().snapped(Vector3.ONE * 0.001)]
			if n is Light3D:
				var l := n as Light3D
				# (le luci che sfarfallano cambiano forza da sole: conta che siano accese)
				var forza := "sfarfalla" if l.get_parent() is FlickerLight or n.get_script() else "%.3f" % l.light_energy
				v += " luce %s col=%s ombre=%s nebbia=%.2f ign=%s" % [forza, l.light_color, l.shadow_enabled, l.light_volumetric_fog_energy, l.has_meta(&"risveglio_ignora")]
			if n is GeometryInstance3D:
				var g := n as GeometryInstance3D
				v += " geo ombra=%d gi=%d ovr=%s" % [g.cast_shadow, g.gi_mode, _mat(g.material_override)]
				if n is MeshInstance3D and (n as MeshInstance3D).mesh:
					var mi := n as MeshInstance3D
					for i in mi.mesh.get_surface_count():
						v += " s%d=%s" % [i, _mat(mi.get_active_material(i))]
			out[k] = v
	return out


func _percorso(ris: Node, n: Node) -> String:
	var parti := PackedStringArray()
	for nome in String(ris.get_path_to(n)).split("/"):
		parti.append("@" if nome.contains("@") else nome)
	return "/".join(parti)


func _mat(m: Material) -> String:
	if m == null:
		return "-"
	if m is BaseMaterial3D:
		var b := m as BaseMaterial3D
		return "B(%s %s em=%s %s x%.2f tr=%d)" % [b.albedo_color, b.albedo_texture.resource_path.get_file() if b.albedo_texture else "",
			b.emission_enabled, b.emission, b.emission_energy_multiplier, b.transparency]
	if m is ShaderMaterial:
		var s := m as ShaderMaterial
		return "S(%d)" % (s.shader.code.hash() if s.shader else 0)
	return m.get_class()


func _aspetta_livello() -> void:
	for i in 600:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and not GameState.is_dying and get_tree().current_scene:
			break
	await _secondi(0.2)
	level = get_tree().current_scene
	p = GameState.player


func _secondi(s: float) -> void:
	for i in int(s * 60.0):
		await get_tree().physics_frame


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
		print("  ok   ", what)
	else:
		_failed += 1
		printerr("  FAIL ", what)


func _fine() -> void:
	print("")
	print("RISULTATO: %d controlli ok, %d falliti" % [_passed, _failed])
	Game.esci(1 if _failed > 0 else 0)
