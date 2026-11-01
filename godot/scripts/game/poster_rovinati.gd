class_name PosterRovinati
## I poster bruciati e scarabocchiati (assets_src/ambienti_interni/poster/rovina.py) al posto di quelli puliti dei GLB, che
## restano com'erano (quello della sala lo usa anche lo spot VHS, dove il parco è ancora nuovo). Per ogni mesh una copia
## del suo materiale importato (stessi colori dei vertici e ruvidezza) con la texture rovinata e l'alpha scissor come i
## M_amb_alfa_*, solo su quella mesh: la carta è incollata sulla lamiera della cornice, e dove manca si vede la lamiera.
## Lo usano la sala principale (i teli e i cartelloni del muro nord) e la torre degli scivoli (gli stessi cartelloni).

const DIR := "res://assets/ambiente/sala/cartelloni_rovinati/"
## I due disegni dei cartelloni del muro nord della sala, che ci sono anche nella torre.
const DELFINO := DIR + "cartellone_delfino_rovinato.png"
const BALENA := DIR + "cartellone_balena_rovinato.png"


## Per ogni mesh di [param voci] (nome: [materiale importato, texture rovinata]) cercata sotto [param radice]. Torna quante
## superfici ha cambiato.
static func metti(radice: Node, voci: Dictionary) -> int:
	var fatti := 0
	for nome: String in voci:
		var mi := radice.find_child(nome, true, false) as MeshInstance3D
		if mi == null or mi.mesh == null:
			push_warning("%s: niente %s per il poster rovinato" % [radice.name, nome])
			continue
		var voce: Array = voci[nome]
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i) as StandardMaterial3D
			if m == null or m.resource_name != voce[0]:
				continue
			mi.set_surface_override_material(i, _rovinato(m.duplicate() as StandardMaterial3D, load(voce[1]) as Texture2D))
			fatti += 1
	return fatti


## Un materiale come quelli che [method metti] mette sui cartelloni della torre degli scivoli (il materiale importato da
## torre_prop.glb ha le due facce e la texture del disegno, senza i colori dei vertici che hanno quelli della sala), per
## SalaTorre.materiali_campione: lo shader di quel tipo Godot lo crea la prima volta sul thread principale (400 ms col
## renderer software in locale, 128 nella CI), e così succede entrando nella sala e non in un passo della costruzione
## a pezzi.
static func campione_torre() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.55
	return _rovinato(m, load(DELFINO) as Texture2D)


## [param m] con la texture rovinata [param tex] e l'alpha scissor.
static func _rovinato(m: StandardMaterial3D, tex: Texture2D) -> StandardMaterial3D:
	m.albedo_texture = tex
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
	return m
