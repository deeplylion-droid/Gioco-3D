extends Node
## Scrive le partenze del menu di prova nascosto (MenuProva, F9 nel titolo) in res://assets/prova/<id>.json: per ogni
## partenza apre la sala, porta il mondo come se il giocatore avesse fatto tutto quello che viene prima (gli oggetti
## "persist" fatti, aperti o risolti; gli oggetti raccolti tolti; lo zaino e le Polaroid fino a lì; le luci del
## blackout), poi mette il giocatore dentro l'area del checkpoint della partenza: l'istantanea la salva il gioco, come
## quando ci si arriva giocando, e si scrive com'è.
## Da rilanciare quando cambia lo stato di un oggetto persist, o un checkpoint, di quelle parti.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/genera_partenze_prova.gd [id,id]

const SCENA := "res://scenes/sala_principale.tscn"
const CARTELLA := "res://assets/prova/"

## Gli oggetti persist fatti, per parte del capitolo: chiave (o inizio della chiave) -> stato. In ordine: ogni
## partenza ha fatto le parti fino alla sua.
const FATTI := {
	"interni": {
		"Interni": {"armadietto": true, "docce": true, "tornello": true},
		"Interni/Meccanismi/PulsanteTornello": {"powered": true},
		"Interni/Meccanismi/Saracinesca": {"latched": true, "open": 1.0},
	},
	"piscina": {
		"Piscina/Pozza": {"fill": 0.0, "mix": {}},
		"Piscina/PulsantePortello": {"powered": true},
		"Piscina/SvuotaPiscina": {"attivo": true},
		"Piscina/Portello": {"open": true},
		"Piscina/EnigmaGiocattoli": {"risolto": true},
	},
	"tecnici": {
		"Tecnici/AgnellinoScala": {"fatto": true},
		"Tecnici/Logica/SalaPompe/Pompa1": {"stato": 99},
		"Tecnici/Logica/SalaPompe/Pompa2": {"stato": 99},
		"Tecnici/Logica/SalaPompe/Pompa3": {"stato": 99},
		"Tecnici/Logica/SalaPompe/Leva": {"abbassata": true},
		"Tecnici/Logica/SalaPompe/Paratia1": {"aperta": true, "chiusa": false},
		"Tecnici/Logica/SalaPompe/Paratia2": {"aperta": true, "chiusa": false},
		"Tecnici/Logica/SalaPompe/Maniglione": {"aperta": true, "bloccata": false},
		"Tecnici/Logica/SalaPompe/Risveglio": {"avviate": 3, "finito": true},
		"Gioco/PortaSalaPompeInterni": {"aperta": true, "bloccata": false},
	},
	"risalita": {
		"Risalita/Fiume/FiumeLento": {"arrivato": true},
		"Risalita/Infermeria/Negatoscopio": {"con_radiografia": true},
		"Risalita/Infermeria/Interruttore": {"powered": true},
		"Risalita/Infermeria/Cassetto14": {"aperto": true},
		"Risalita/Infermeria/Cassaforte": {"aperta": true},
		"Tecnici/Logica/LettoreTessera": {"aperto": true},
		"Tecnici/Logica/SerrandaMagazzino": {"aperta": true, "latched": true, "open": 1.0},
	},
	"sala_buio": {
		"Gioco/LeiSbuca": {"finita": true},
		"Gioco/EnigmaAcquari": {"stato": 99},
		"Gioco/PortoneTorre": {"aperto": true, "chiuso_dietro": false},
	},
}
## Gli oggetti raccolti, per parte (chiavi persist): tolti dal livello.
const RACCOLTI := {
	"interni": ["Interni/Zaino/Prendi"],
	"risalita": ["Risalita/Infermeria/Cassetto14/Frontale/Radiografia", "Risalita/Infermeria/Keycard"],
}
## Le Polaroid raccolte, per parte (P12-P16 le nuove del 28 ottobre: P13 sotto l'oblò, P15 nella zona del personale e
## P16 all'approdo nella risalita, P14 agli acquari, P12 in cima alla torre).
const POLAROID := {
	"interni": ["p01", "p02", "p03"],
	"piscina": ["p04", "p05", "p08", "p09"],
	"tecnici": ["p06", "p07"],
	"risalita": ["PolaroidPecora", "p13", "p15", "p16"],
	"sala_buio": ["p14"],
	"torre": ["Polaroid10", "p12"],
}
const PARTI := ["interni", "piscina", "tecnici", "risalita", "sala_buio", "torre"]

## Le partenze: le parti fatte prima, il checkpoint (percorso dalla scena del livello), se serve la torre, le Polaroid
## raccolte in più (quelle della parte della partenza che stanno prima del suo checkpoint).
const PARTENZE := {
	"risalita": {"fatte": 3, "checkpoint": "Tecnici/Logica/Checkpoint/CheckpointT7Inizio"},
	# (la P13 sta nel corridoio della scala verso il fiume, prima del capannone: chi parte dal fiume ci è già passato)
	"fiume": {"fatte": 3, "checkpoint": "Risalita/Fiume/Checkpoint/CheckpointIngresso", "polaroid": ["p13"]},
	"torre": {"fatte": 5, "checkpoint": "SalaTorre/Checkpoint_portone", "torre": true},
	"inseguimento": {"fatte": 6, "checkpoint": "SalaTorre/Checkpoint_fondo", "torre": true},
	"tunnel": {"fatte": 6, "checkpoint": "SalaSottomarino/Checkpoint_6", "torre": true, "tunnel": true},
}

var level: Node
var _ok := 0
var _ko := 0


func _ready() -> void:
	_run.call_deferred()


func _check(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  ok  ", msg)
	else:
		_ko += 1
		print("  KO  ", msg)


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	var solo := PackedStringArray()
	var args := OS.get_cmdline_user_args()
	if args.size() > 1:
		solo = args[1].split(",")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CARTELLA))
	for id: String in PARTENZE:
		if not solo.is_empty() and not id in solo:
			continue
		print("== ", id)
		await _partenza(id, PARTENZE[id])
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	get_tree().quit(1 if _ko > 0 else 0)


func _partenza(id: String, p: Dictionary) -> void:
	if p.get("tunnel", false) and not ResourceLoader.exists("res://scripts/game/sala_sottomarino.gd"):
		print("  (niente tunnel in questo ramo: salto)")
		return
	GameState.reset_progress()
	# le stanze della Risalita subito (se no si caricano solo vicino) e niente precarica a parte della torre
	Engine.set_meta(&"risalita_subito", true)
	get_tree().change_scene_to_file(SCENA)
	await _aspetta_livello()
	var fatte: int = p["fatte"]
	# le parti fatte: gli oggetti persist, i raccolti, le Polaroid
	var stati := {}
	var raccolti: Array = []
	for k in fatte:
		var parte: String = PARTI[k]
		stati.merge(FATTI.get(parte, {}), true)
		raccolti.append_array(RACCOLTI.get(parte, []))
		for e in POLAROID.get(parte, []):
			GameState.collect(&"polaroid", StringName(e))
	for e in p.get("polaroid", []):
		GameState.collect(&"polaroid", StringName(e))
	var applicati := 0
	for n in get_tree().get_nodes_in_group(&"persist"):
		var key := GameState.persist_key(n)
		if key in raccolti:
			GameState.mark_removed(n)
			n.queue_free()
			continue
		if stati.has(key) and n.has_method(&"load_state"):
			var d: Dictionary = n.call(&"save_state") if n.has_method(&"save_state") else {}
			d.merge(stati[key], true)
			n.call(&"load_state", d)
			applicati += 1
	_check(applicati == stati.size(), "%s: %d oggetti persist fatti su %d" % [id, applicati, stati.size()])
	var pl := GameState.player
	pl.inventory[&"zaino_pompa"] = 1
	if pl.water_pack:
		pl.water_pack.set_equipped(true, false)
		pl.water_pack.set_tank_amount(pl.water_pack.tank_capacity)
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	for i in 10:
		await get_tree().physics_frame
	if p.get("torre", false):
		await _aspetta_torre(p.get("tunnel", false))
	var cp := level.get_node_or_null(NodePath(String(p["checkpoint"]))) as Checkpoint
	_check(cp != null, "%s: il checkpoint %s c'è" % [id, p["checkpoint"]])
	if cp == null:
		return
	# il giocatore dentro l'area del checkpoint: l'istantanea la salva il gioco
	var f := -cp.get_spawn_transform().basis.z
	pl.teleport(cp.global_position, atan2(-f.x, -f.z), 0.0)
	var key := GameState.persist_key(cp)
	for i in 120:
		await get_tree().physics_frame
		if String(GameState.snapshot.get("checkpoint", "")) == key:
			break
	_check(String(GameState.snapshot.get("checkpoint", "")) == key, "%s: istantanea al checkpoint (%s)" % [id, GameState.snapshot.get("checkpoint", "")])
	var s := GameState.snapshot.duplicate(true)
	s["partenza_prova"] = id
	var file := FileAccess.open(CARTELLA + id + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(s, " ", false))
	file.close()
	print("  scritto %s%s.json (%d oggetti, %d raccolti, Polaroid %d)" % [CARTELLA, id, (s["objects"] as Dictionary).size(),
		(s["removed"] as Array).size(), GameState.get_collected_count(&"polaroid")])


func _aspetta_livello() -> void:
	for i in 1800:
		await get_tree().process_frame
		level = get_tree().current_scene
		if level and GameState.player and is_instance_valid(GameState.player) and GameState.player.is_inside_tree():
			break
	for i in 30:
		await get_tree().process_frame


## La torre (e con lei le condotte) dentro la sala, costruita: come quando si apre il portone.
func _aspetta_torre(tunnel: bool) -> void:
	if level.has_method(&"_carica_torre"):
		level.call(&"_carica_torre")
	for i in 60 * 120:
		await get_tree().process_frame
		var t = level.get(&"sala_torre")
		if t is Node and bool((t as Node).get(&"costruita")) \
				and (not tunnel or (level.get(&"sala_sottomarino") is Node and bool((level.get(&"sala_sottomarino") as Node).get(&"costruita")))):
			break
	_check(level.get(&"sala_torre") is Node, "la torre è nella sala")
