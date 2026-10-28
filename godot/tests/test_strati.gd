extends Node
## Test: gli strati di disegno (VisualInstance3D.layers, cull_mask) non si pestano i piedi senza volerlo (richiesta del
## coordinatore, 25 ottobre: lo strato fuori vista della preparazione era 1 << 19, lo stesso dell'acqua, e la camera
## del giocatore lo disegnava; poi 1 << 17, già delle lampade dell'infermeria).
## 1. le costanti di strato degli script (const NOME := 1 << n, fuori dagli strati della fisica in layers.gd) hanno
##    valori diversi, tranne i gruppi voluti in [constant VOLUTI];
## 2. lo strato della preparazione (SalaTorre.STRATO_PREPARA) non lo disegnano la camera del giocatore e le camere dei
##    riflessi dell'acqua, e ha il suo nome nel progetto.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/test_strati.gd

## Strati condivisi apposta: l'acqua, quello che il lampo della tempesta esclude (l'acqua) e il geyser (è acqua).
const VOLUTI := [["WATER_LAYER", "STRATO_NO_LAMPO", "LIVELLO_ACQUA"]]
const CARTELLE := ["res://scripts", "res://addons"]
const FISICA := ["res://scripts/game/layers.gd"]

var _ok := 0
var _ko := 0


func _ready() -> void:
	_run.call_deferred()


func check(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  ok  ", msg)
	else:
		_ko += 1
		print("  KO  ", msg)


func _file(dir: String, out: Array[String]) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_file(dir.path_join(d), out)


func _voluto(a: String, b: String) -> bool:
	for g in VOLUTI:
		if a in g and b in g:
			return true
	return false


func _run() -> void:
	var file: Array[String] = []
	for c in CARTELLE:
		_file(c, file)
	var re := RegEx.create_from_string("(?m)^const\\s+(\\w+)\\s*:?=\\s*1\\s*<<\\s*(\\d+)")
	var per_valore := {}
	for f in file:
		if f in FISICA:
			continue
		var testo := FileAccess.get_file_as_string(f)
		for m in re.search_all(testo):
			var n := int(m.get_string(2))
			if not per_valore.has(n):
				per_valore[n] = []
			(per_valore[n] as Array).append([m.get_string(1), f.get_file()])
	var doppi: Array[String] = []
	for n in per_valore:
		var l: Array = per_valore[n]
		for i in l.size():
			for j in range(i + 1, l.size()):
				if l[i][0] != l[j][0] and not _voluto(l[i][0], l[j][0]):
					doppi.append("1 << %d: %s (%s) e %s (%s)" % [n, l[i][0], l[i][1], l[j][0], l[j][1]])
	check(doppi.is_empty(), "nessuno strato di disegno condiviso senza volerlo (%d costanti)%s" % [
		per_valore.values().reduce(func(a, l): return a + (l as Array).size(), 0), "" if doppi.is_empty() else ": " + "; ".join(doppi)])

	var p := SalaTorre.STRATO_PREPARA
	var giocatore := (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child(giocatore)
	var cam := (giocatore as Node).find_children("*", "Camera3D", true, false)[0] as Camera3D
	check(cam.cull_mask & p == 0, "la camera del giocatore non disegna lo strato della preparazione")
	giocatore.free()
	var n := 0
	while (1 << n) != p:
		n += 1
	for f in ["res://addons/acqua/scripts/water_env_capture.gd", "res://addons/acqua/scripts/water_planar_reflection.gd"]:
		check(FileAccess.get_file_as_string(f).contains("(1 << %d))" % n),
			"%s esclude lo strato della preparazione (1 << %d)" % [f.get_file(), n])
	check(String(ProjectSettings.get_setting("layer_names/3d_render/layer_%d" % (n + 1), "")) == "preparazione",
		"lo strato %d ha il suo nome nel progetto (preparazione)" % (n + 1))
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	Game.esci(1 if _ko > 0 else 0)
