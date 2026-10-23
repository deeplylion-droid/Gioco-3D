extends Node
## Elenco per zona delle luci (e dei materiali delle lampade) che la variante delle luci bianche al 40%
## (scripts/game/luci_bianche.gd) prende come bianche e come colorate. Solo testo, per farlo controllare:
## scrive docs/tecnico/luci_bianche/elenco.md. Le zone: la sala principale (con interni, tecnici, risalita, che
## qui sono nodi di primo livello) e la torre con l'inseguimento; più il menu del titolo.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- \
##        res://proposte/mascotte/elenco_luci_bianche.gd

const SCENE := ["res://scenes/sala_principale.tscn", "res://scenes/sala/torre/sala_torre.tscn",
	"res://scenes/ui/menu_principale.tscn"]
const USCITA := "res://../docs/tecnico/luci_bianche/elenco.md"

var righe: PackedStringArray = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var lb := get_node(^"/root/LuciBianche")
	righe.append("# Luci bianche al 40%: come sono classificate, zona per zona")
	righe.append("")
	righe.append(("Scritto da `godot/proposte/mascotte/elenco_luci_bianche.gd`. Regola (`scripts/game/luci_bianche.gd`): bianca se la " +
		"saturazione è al più %.2f; bianco-calda se la tinta è fra %.3f e %.2f (arancio-giallo) e la saturazione al più %.2f. " +
		"Tutto il resto è colorato e resta com'è. Jilly, le creature, le statue e gli oggetti di gioco restano com'erano. " +
		"Materiali: solo delle lampade vere (nome da lampada, o mesh piccola vicino a una luce), emissione accesa (almeno %.1f) dello stesso colore. " +
		"Fra parentesi il colore (tinta, saturazione) e l'energia piena.") % [VarianteLuci.SAT_BIANCA, VarianteLuci.TINTA_CALDA.x,
		VarianteLuci.TINTA_CALDA.y, VarianteLuci.SAT_CALDA, VarianteLuci.EMISSIONE_MINIMA])
	for scena in SCENE:
		var level := (load(scena) as PackedScene).instantiate()
		get_tree().root.add_child(level)
		for i in 30:
			await get_tree().process_frame
		lb.imposta(0.4)
		for i in 10:
			await get_tree().process_frame
		_scrivi_scena(scena, level, lb)
		lb.imposta(1.0)
		level.queue_free()
		for i in 10:
			await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(USCITA).get_base_dir())
	var f := FileAccess.open(ProjectSettings.globalize_path(USCITA), FileAccess.WRITE)
	f.store_string("\n".join(righe) + "\n")
	f.close()
	print("scritto ", ProjectSettings.globalize_path(USCITA))
	print("FINE")
	get_tree().quit()


func _zona(level: Node, n: Node) -> String:
	var p := String(level.get_path_to(n)).split("/")
	return p[0] if p.size() < 3 else p[0] + "/" + p[1]


func _scrivi_scena(scena: String, level: Node, lb: Node) -> void:
	righe.append("")
	righe.append("## %s" % scena.get_file().get_basename())
	var per_zona := {}
	for l: Light3D in lb.luci_raccolte():
		if not level.is_ancestor_of(l):
			continue
		var z := _zona(level, l)
		if not per_zona.has(z):
			per_zona[z] = {"bianche": [], "colorate": [], "escluse": [], "materiali": []}
		var c := l.light_color
		var testo := "`%s` (%.2f, %.2f; %.2f)" % [String(level.get_path_to(l)).trim_prefix(z + "/"), c.h, c.s, l.light_energy]
		var cat := "colorate"
		if lb._esclusa(l):
			cat = "escluse"
		elif VarianteLuci.is_bianca(c) and not VarianteLuci._nome_colorato(l.name):
			cat = "bianche"
		per_zona[z][cat].append(testo)
	# i materiali: una mesh per materiale
	var mesh_di := {}
	for g in level.find_children("*", "GeometryInstance3D", true, false):
		var mats := [(g as GeometryInstance3D).material_override]
		if g is MeshInstance3D and (g as MeshInstance3D).mesh:
			for s in (g as MeshInstance3D).mesh.get_surface_count():
				mats.append((g as MeshInstance3D).get_surface_override_material(s))
				mats.append((g as MeshInstance3D).mesh.surface_get_material(s))
		for m in mats:
			if m and not mesh_di.has(m.get_instance_id()):
				mesh_di[m.get_instance_id()] = g
	# i materiali delle lampade vere (gli altri emissivi bianchi non scendono e non sono nell'elenco)
	for m: BaseMaterial3D in lb.materiali_raccolti():
		var g: Node = mesh_di.get(m.get_instance_id())
		if g == null or not level.is_ancestor_of(g):
			continue
		var z := _zona(level, g)
		if not per_zona.has(z):
			per_zona[z] = {"bianche": [], "colorate": [], "escluse": [], "materiali": []}
		var c := m.emission
		per_zona[z]["materiali"].append("%s `%s` su `%s` (%.2f, %.2f; %.1f)" % ["scende" if VarianteLuci.is_bianca(c) else "resta",
			m.resource_name if m.resource_name != "" else "senza nome", String(level.get_path_to(g)).trim_prefix(z + "/"), c.h, c.s,
			m.emission_energy_multiplier])
	var gi: int = lb.gi_raccolti().size()
	# quanto costa: applica + ripristina (le due volte per fotogramma), media di 30
	var t0 := Time.get_ticks_usec()
	for k in 30:
		lb.applica()
		lb.ripristina()
	var ms := (Time.get_ticks_usec() - t0) / 1000.0 / 30.0
	var n_luci := 0
	for l: Light3D in lb.luci_raccolte():
		if VarianteLuci.is_bianca(l.light_color):
			n_luci += 1
	righe.append("")
	righe.append(("Costo con questa scena caricata: %.2f ms per fotogramma (applica e ripristina, su questa macchina lenta), " +
		"per %d luci bianche e %d materiali delle lampade (condivisi: uno per materiale, non uno per lampada).") % [ms, n_luci,
		lb.materiali_raccolti().size()])
	print("costo %s: %.2f ms, %d luci bianche, %d materiali" % [scena, ms, n_luci, lb.materiali_raccolti().size()])
	righe.append("")
	righe.append("VoxelGI con i dati cotti raccolti finora (tutte le scene): %d, scendono tutti al 40%%." % gi)
	var zone := per_zona.keys()
	zone.sort()
	for z in zone:
		var d: Dictionary = per_zona[z]
		righe.append("")
		righe.append("### %s — %d bianche, %d colorate, %d materiali" % [z, d["bianche"].size(), d["colorate"].size(), d["materiali"].size()])
		if not d["colorate"].is_empty():
			righe.append("")
			righe.append("Colorate (restano com'erano):")
			for t in d["colorate"]:
				righe.append("- " + t)
		if not d["escluse"].is_empty():
			righe.append("")
			righe.append("Di Jilly, delle creature o degli oggetti di gioco (restano com'erano anche se bianche):")
			for t in d["escluse"]:
				righe.append("- " + t)
		if not d["bianche"].is_empty():
			righe.append("")
			righe.append("Bianche (scendono al 40%):")
			for t in d["bianche"]:
				righe.append("- " + t)
		if not d["materiali"].is_empty():
			righe.append("")
			righe.append("Materiali delle lampade:")
			for t in d["materiali"]:
				righe.append("- " + t)
