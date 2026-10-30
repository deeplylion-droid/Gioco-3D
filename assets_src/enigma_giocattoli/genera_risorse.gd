extends SceneTree
## I materiali dei cerchi a mosaico dell'enigma "I giocattoli al loro posto" (accordo con enigmi del 28 ottobre), in
## godot/assets/models/enigma_giocattoli/: cerchio_giallo.tres, cerchio_rosso.tres, cerchio_blu.tres, sullo shader
## cerchio_mosaico.gdshader (disco di 1 m, UV 0..1 sul quadrato del disco; il disco lo fa enigmi).
## Uso: godot --headless --path godot --script res://../assets_src/enigma_giocattoli/genera_risorse.gd
## (oppure copiato in godot/ e lanciato da lì).

const DIR := "res://assets/models/enigma_giocattoli/"
## I colori del mosaico (vetro colorato un po' scolorito, come i giocattoli).
const COLORI := {"giallo": Color(0.86, 0.68, 0.12), "rosso": Color(0.72, 0.13, 0.1), "blu": Color(0.13, 0.32, 0.7)}


func _initialize() -> void:
	var shader := load(DIR + "cerchio_mosaico.gdshader") as Shader
	for c in COLORI:
		var m := ShaderMaterial.new()
		m.resource_name = "cerchio_" + c
		m.shader = shader
		m.set_shader_parameter(&"colore", COLORI[c])
		ResourceSaver.save(m, DIR + "cerchio_" + c + ".tres")
	print("materiali salvati in ", DIR)
	quit()
