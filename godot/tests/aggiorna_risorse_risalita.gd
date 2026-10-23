extends Node
## Rifà i due file che servono a caricare le stanze della Risalita (fiume e infermeria) a gioco avviato senza fermi
## (risalita_gioco.gd):
## - scenes/risalita/risorse_stanze.json: i file che le stanze caricano mentre si costruiscono, che il thread carica prima;
## - scenes/risalita/materiali_campione.tres: un materiale (senza texture) per ogni shader delle stanze che la sala
##   all'avvio non ha; la sala li tiene da subito, così quegli shader non si compilano a gioco avviato.
## Da rilanciare quando le stanze cambiano modelli, texture o materiali (test_risalita_tardi lo segnala).
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/aggiorna_risorse_risalita.gd

const ELENCO := "res://scenes/risalita/risorse_stanze.json"
const CAMPIONI := "res://scenes/risalita/materiali_campione.tres"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	Engine.set_meta(&"precarica_torre_spento", true)
	get_tree().change_scene_to_file("res://scenes/sala_principale.tscn")
	for i in 600:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and get_tree().current_scene:
			break
	await get_tree().process_frame
	var level := get_tree().current_scene
	var ris := level.get_node(^"Risalita")
	# gli shader della sala all'avvio, senza le stanze e senza i campioni di adesso
	ris.set(&"_campioni", [])
	var sala := {}
	RisorseNodi.materiali_per_shader(level, sala)
	ris.call(&"carica_subito")
	await get_tree().process_frame
	var l := elenco(ris)
	var f := FileAccess.open(ELENCO, FileAccess.WRITE)
	f.store_string(JSON.stringify(Array(l), "\t") + "\n")
	f.close()
	print("%s: %d file" % [ELENCO, l.size()])
	var campioni: Array[Material] = []
	for k in shader_nuovi(ris, sala):
		campioni.append(campione(k[1]))
	var r := Resource.new()
	r.set_meta(&"materiali", campioni)
	ResourceSaver.save(r, CAMPIONI)
	print("%s: %d materiali" % [CAMPIONI, campioni.size()])
	Game.esci(0)


## I file usati dalle stanze costruite, in ordine (senza le due scene, che si chiedono a parte).
static func elenco(ris: Node) -> PackedStringArray:
	var percorsi := {}
	for r in [ris.get(&"fiume"), ris.get(&"infermeria")]:
		RisorseNodi.raccogli(r, percorsi)
	percorsi.erase(ris.get(&"SCENA_FIUME"))
	percorsi.erase(ris.get(&"SCENA_INFERMERIA"))
	var l := PackedStringArray(percorsi.keys())
	l.sort()
	return l


## Gli shader delle stanze che non sono fra quelli di [param sala] (chiave -> materiale): [chiave, materiale].
static func shader_nuovi(ris: Node, sala: Dictionary) -> Array:
	var stanze := {}
	for r in [ris.get(&"fiume"), ris.get(&"infermeria")]:
		RisorseNodi.materiali_per_shader(r, stanze)
	var out := []
	for k in stanze:
		if not sala.has(k):
			out.append([k, stanze[k]])
	return out


## Una copia del materiale senza texture e senza passi dopo: lo stesso shader, quasi niente memoria.
static func campione(m: Material) -> Material:
	var c := m.duplicate() as Material
	c.next_pass = null
	c.resource_name = "campione"
	if c is ShaderMaterial:
		for u in (c as ShaderMaterial).shader.get_shader_uniform_list():
			if (c as ShaderMaterial).get_shader_parameter(u.name) is Texture:
				(c as ShaderMaterial).set_shader_parameter(u.name, null)
	else:
		for pr in c.get_property_list():
			if pr.type == TYPE_OBJECT and c.get(pr.name) is Texture:
				c.set(pr.name, null)
	return c
