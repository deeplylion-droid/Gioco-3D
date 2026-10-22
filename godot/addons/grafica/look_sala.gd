class_name LookSala
extends Node3D
## Look della sala principale (capitolo 1): luci, illuminazione globale, sonde di
## riflessione, nebbia, lampi e particelle. Due modi d'uso:
## - scena separata (consigliato, scenes/sala/luci_sala.tscn): [member percorso_sala] punta
##   al Node3D con i GLB della sala; tutto si fa in differita, dopo il _ready della scena,
##   così chi tocca i modelli e lo script della sala non tocca le luci;
## - attaccato direttamente al Node3D con i GLB (com'era prima), AL POSTO di sala_luci_ambiente.gd.
## Le luci arrivano da sala_luci.glb e vengono riconosciute dal nome.
## L'Environment e gli attributi della camera sono risorse .tres riutilizzabili
## (grafica/sala/), ritoccabili nell'editor.

## Il Node3D con i GLB della sala. Vuoto: questo nodo stesso.
@export var percorso_sala := NodePath()
## Dati del VoxelGI già cotti (vedi [method cuoci_gi]). Se mancano e il GI è attivo,
## si calcola all'avvio (lento, solo per le prove).
@export_file("*.res") var dati_gi := ""
@export var ambiente: Environment = preload("res://addons/grafica/sala/ambiente_sala.tres")
@export var attributi_camera: CameraAttributesPractical = preload("res://addons/grafica/sala/attributi_camera_sala.tres")
@export_group("Luci")
@export var energia_emergenza := 5.5
@export var portata_emergenza := 7.0
@export var energia_neon := 3.0
@export var energia_lampione := 3.5
@export var energia_luna := 0.3
## Luci del monumento: faretti bassi (0,6) come provato dall'integratore; fari a 5,5 e lampione
## a 3,5 perché il busto in vinile lucido resti leggibile senza bruciarsi.
@export var energia_fari := 5.5
@export var energia_faretti := 0.6
@export var energia_plafoniere := 1.8
@export var energia_insegne := 1.3
@export var colore_emergenza := Color(1.0, 0.035, 0.02)
@export var colore_neon := Color(0.78, 1.0, 0.9)        # fluorescente freddo, verso il verde
@export var colore_lampione := Color(1.0, 0.66, 0.36)   # sodio caldo: il contrasto caldo della sala
@export_group("Parti da creare")
@export var crea_gi := true
@export var crea_sonde := true
@export var crea_tempesta := true
@export var crea_effetti := true
@export var crea_area_bimbi := true
## Neon che nel GLB sono "a metà": sfarfallano o sono guasti.
@export var neon_difettosi: PackedInt32Array = [1, 3, 4, 6, 7, 13, 14, 17, 24, 25]

@export_group("Volume della sala")
## Centro e dimensioni della sala in coordinate Godot (da sala_dati.json: x -20..20,
## z -24..20, pavimento 0, soffitto 11,5, cupola fino a ~17). Usati da VoxelGI,
## sonde di riflessione, nebbia bassa e pulviscolo.
@export var sala_centro := Vector3(0, 7.5, -2.0)
@export var sala_dimensioni := Vector3(41, 21, 45)
@export_group("Ritratto della medusa affacciata")
## Dove punta la lampada sul palo (luce_lampione): il viso della medusa affacciata sulla
## vasca sollevata (marker medusa_affacciata in sala_dati.json: origine (0, 0,88, 11,75)).
@export var ritratto_mira := Vector3(0, 1.75, 11.8)
@export var energia_ritratto := 6.0
## Il trigger che accende la lampada (Area3D della scena della sala) e dove metterlo:
## appena passata la porta degli spogliatoi, così la lampada si accende uscendo.
@export var percorso_trigger := NodePath()
@export var punto_accensione := Vector3(0, 1.5, 18.6)
@export_group("Area bimbi")
## Struttura di gioco (sala_area_bimbi.glb, nell'angolo nord-ovest dalla disposizione 1 del 16 ottobre:
## x -18,7..-9,8, z -22,8..-14,7, alta 8,3): un festone di lampadine da festa colorate, rotte a tratti, dal
## muro ovest alla cima del telaio del secchio e da lì al muro nord, e una plafoniera appesa al soffitto
## che illumina il fronte e il secchio gigante.
@export var festone_punti: PackedVector3Array = [Vector3(-20.0, 4.2, -13.0), Vector3(-15.9, 7.35, -19.65), Vector3(-12.9, 7.35, -19.65), Vector3(-8.0, 4.2, -24.0)]
@export var festone_cala := 0.55          # quanto scende il filo a metà campata
## Per campata (se c'è, al posto di festone_cala): quella in cima alla struttura passa sopra il secchio gigante,
## e col filo lento le lampadine ci entravano dentro (controllo di posizionamento del 22 ottobre).
@export var festone_cala_campate: PackedFloat32Array = [0.55, 0.08, 0.55]
@export var festone_passo := 0.42
@export var energia_festone := 1.1
## Lampadine spente (rotte) e lampadine che sfarfallano, contate lungo il festone.
@export var festone_rotte: PackedInt32Array = [5, 6, 7, 13, 22, 29, 30]
@export var festone_sfarfallano: PackedInt32Array = [3, 17, 26]
@export var plafoniera_bimbi := Vector3(-11.9, 9.2, -14.7)
@export var mira_plafoniera_bimbi := Vector3(-14.4, 4.4, -20.4)
@export var energia_plafoniera_bimbi := 7.0
@export_group("Statua sul monumento")
## Centro del monumento e altezza della statua (per il controluce).
@export var monumento := Vector3(0, 0, 10)
@export var altezza_statua := 4.5
@export var crea_controluce := true
## Se impostato, il vetro della cupola si accende con i lampi (es. un ShaderMaterial
## con vetro_cupola.gdshader, assegnato anche ai vetri della cupola).
@export var vetro_cupola: ShaderMaterial

var tempesta: Tempesta
var _sfarfallanti: Array = []   # [luce, energia, modalità, attesa, raffica]
var _sala: Node3D
var _emissioni: Array = []      # [materiale, emissione piena] delle lampade che il blackout spegne
var _flash_salvate: Array = []   # [luce, visibile, energia] durante il flash
var _flash_resta := 0.0


func _ready() -> void:
	add_to_group(&"look_sala")
	# La tempesta subito: altri nodi della sala la cercano nel loro _ready (es. i bambini
	# che compaiono con i lampi).
	if crea_tempesta:
		_crea_tempesta()
	if percorso_sala.is_empty():
		_sala = self
		_prepara()
	else:
		_sala = get_node(percorso_sala) as Node3D
		# Dopo il _ready della scena della sala (che regola anche lei alcune luci).
		_prepara.call_deferred()


func _prepara() -> void:
	_imposta_ambiente()
	_regola_luci(_sala)
	_prepara_ritratto()
	if crea_gi:
		_crea_voxel_gi()
	if crea_sonde:
		_crea_sonde()
	if crea_effetti:
		_crea_effetti()
	if crea_controluce:
		_crea_controluce()
	if crea_area_bimbi:
		_crea_area_bimbi()
	_collega_risveglio()


func _crea_area_bimbi() -> void:
	var radice := Node3D.new()
	radice.name = "LuciAreaBimbi"
	add_child(radice)
	# Filo nero e lampadine: colori pastello saturi anni '90.
	var colori := [Color(1.0, 0.25, 0.3), Color(1.0, 0.8, 0.2), Color(0.25, 0.6, 1.0),
			Color(0.35, 1.0, 0.45), Color(1.0, 0.45, 0.85), Color(1.0, 0.55, 0.15)]
	var filo := StandardMaterial3D.new()
	filo.albedo_color = Color(0.03, 0.03, 0.03)
	filo.roughness = 0.6
	var vetro_spento := StandardMaterial3D.new()
	vetro_spento.albedo_color = Color(0.25, 0.25, 0.25)
	vetro_spento.roughness = 0.2
	var sfera := SphereMesh.new()
	sfera.radius = 0.045
	sfera.height = 0.11
	sfera.radial_segments = 12
	sfera.rings = 6
	var tubo := CylinderMesh.new()
	tubo.top_radius = 0.006
	tubo.bottom_radius = 0.006
	tubo.height = 1.0
	tubo.radial_segments = 5
	tubo.rings = 1
	var materiali := {}
	var n := 0
	for c in festone_punti.size() - 1:
		var a := festone_punti[c]
		var b := festone_punti[c + 1]
		var passi := maxi(int(a.distance_to(b) / festone_passo), 2)
		var prec := a
		for i in passi + 1:
			var t := float(i) / passi
			var cala := festone_cala_campate[c] if c < festone_cala_campate.size() else festone_cala
			var p := a.lerp(b, t) - Vector3.UP * cala * 4.0 * t * (1.0 - t)
			if i > 0:
				var pezzo := MeshInstance3D.new()
				pezzo.mesh = tubo
				pezzo.material_override = filo
				pezzo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				radice.add_child(pezzo)
				var dir := p - prec
				pezzo.global_position = (p + prec) * 0.5
				pezzo.global_basis = Basis(Quaternion(Vector3.UP, dir.normalized())) * Basis.from_scale(Vector3(1, dir.length(), 1))
			prec = p
			if i == 0 and c > 0:
				continue   # l'angolo ha già la sua lampadina
			var colore: Color = colori[n % colori.size()]
			var rotta := n in festone_rotte
			var lamp := MeshInstance3D.new()
			lamp.mesh = sfera
			lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if rotta:
				lamp.material_override = vetro_spento
			else:
				if not materiali.has(colore):
					var m := StandardMaterial3D.new()
					m.albedo_color = colore
					m.emission_enabled = true
					m.emission = colore
					m.emission_energy_multiplier = 4.0
					materiali[colore] = m
				lamp.material_override = materiali[colore]
			radice.add_child(lamp)
			lamp.global_position = p + Vector3.DOWN * 0.06
			# Una luce vera ogni tre lampadine accese (le altre sono solo emissive).
			if not rotta and n % 3 == 1:
				var o := OmniLight3D.new()
				o.light_color = colore
				o.light_energy = energia_festone
				o.omni_range = 3.2
				o.omni_attenuation = 1.4
				o.light_volumetric_fog_energy = 1.2
				o.light_specular = 0.6
				o.shadow_enabled = false
				radice.add_child(o)
				o.global_position = p + Vector3.DOWN * 0.15
				if n in festone_sfarfallano or (n + 1) in festone_sfarfallano or (n - 1) in festone_sfarfallano:
					_sfarfallanti.append([o, o.light_energy, "guasto", randf_range(0.5, 4.0), 0.0])
			n += 1
	# Plafoniera navale appesa al soffitto con un'asta, puntata sul fronte della struttura.
	var plaf := Node3D.new()
	plaf.name = "PlafonieraBimbi"
	radice.add_child(plaf)
	plaf.global_position = plafoniera_bimbi
	plaf.look_at(mira_plafoniera_bimbi, Vector3.UP)
	var metallo := StandardMaterial3D.new()
	metallo.albedo_color = Color(0.16, 0.18, 0.17)
	metallo.metallic = 0.7
	metallo.roughness = 0.45
	var paralume := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 0.12
	cil.bottom_radius = 0.3
	cil.height = 0.32
	paralume.mesh = cil
	paralume.material_override = metallo
	paralume.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	plaf.add_child(paralume)
	paralume.rotation_degrees = Vector3(-90, 0, 0)   # l'asse del cilindro lungo -Z (la mira)
	paralume.position = Vector3(0, 0, -0.05)
	var disco := MeshInstance3D.new()
	var dm := CylinderMesh.new()
	dm.top_radius = 0.27
	dm.bottom_radius = 0.27
	dm.height = 0.02
	disco.mesh = dm
	var acceso := StandardMaterial3D.new()
	acceso.albedo_color = Color(1.0, 0.9, 0.75)
	acceso.emission_enabled = true
	acceso.emission = Color(1.0, 0.86, 0.68)
	acceso.emission_energy_multiplier = 6.0
	disco.material_override = acceso
	disco.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	plaf.add_child(disco)
	disco.rotation_degrees = Vector3(-90, 0, 0)
	disco.position = Vector3(0, 0, -0.21)
	var asta := MeshInstance3D.new()
	var am := CylinderMesh.new()
	am.top_radius = 0.02
	am.bottom_radius = 0.02
	am.height = maxf(11.5 - plafoniera_bimbi.y, 0.3)
	asta.mesh = am
	asta.material_override = metallo
	radice.add_child(asta)
	asta.global_position = plafoniera_bimbi + Vector3.UP * am.height * 0.5
	var spot := SpotLight3D.new()
	spot.light_color = Color(1.0, 0.86, 0.68)
	spot.light_energy = energia_plafoniera_bimbi
	spot.spot_range = 16.0
	spot.spot_angle = 34.0
	spot.spot_angle_attenuation = 1.1
	spot.spot_attenuation = 0.7
	spot.shadow_enabled = true
	spot.light_size = 0.15
	spot.light_specular = 0.5
	spot.light_volumetric_fog_energy = 1.5
	spot.set_meta("grafica_priorita_ombra", 1)
	plaf.add_child(spot)
	spot.position = Vector3(0, 0, -0.25)


## Segue GameState.luci (tappa 6): nel BLACKOUT si spengono anche le parti emissive (tubi
## neon, plafoniere, festone, insegne), che il ripiego LuciRisveglio non tocca perché spegne solo
## le luci; restano le lampade rosse d'emergenza. Prima del risveglio e nel FLASH sono accese.
func _collega_risveglio() -> void:
	var gs := get_node_or_null(^"/root/GameState")
	if gs == null or not &"luci" in gs:
		return
	gs.connect(&"luci_cambiate", _su_luci)
	if int(gs.get(&"luci")) != 0:
		_su_luci(gs.get(&"luci"))


func _su_luci(fase) -> void:
	if _emissioni.is_empty():
		_raccogli_emissioni()
	var acceso := int(fase) != 2   # 2 = BLACKOUT
	for e in _emissioni:
		(e[0] as BaseMaterial3D).emission_energy_multiplier = e[1] if acceso else 0.0


func _raccogli_emissioni() -> void:
	var fatti := {}
	var meshes: Array[Node] = _sala.find_children("*", "MeshInstance3D", true, false)
	if _sala != self:
		meshes.append_array(find_children("*", "MeshInstance3D", true, false))
	for n in meshes:
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		if mi.material_override is BaseMaterial3D:
			var m := mi.material_override as BaseMaterial3D
			if m.emission_enabled and not _emissione_rossa(m):
				if not fatti.has(m):
					fatti[m] = m.duplicate()
					_emissioni.append([fatti[m], m.emission_energy_multiplier])
				mi.material_override = fatti[m]
			continue
		for i in mi.mesh.get_surface_count():
			var m := mi.get_active_material(i) as BaseMaterial3D
			if m == null or not m.emission_enabled or _emissione_rossa(m):
				continue
			if not fatti.has(m):
				fatti[m] = m.duplicate()
				_emissioni.append([fatti[m], m.emission_energy_multiplier])
			mi.set_surface_override_material(i, fatti[m])


## Le lampade d'emergenza (rosse) restano accese nel blackout.
static func _emissione_rossa(m: BaseMaterial3D) -> bool:
	var c := m.emission
	return c.r > 0.6 and c.g < 0.3 and c.b < 0.3


## Per [param durata] secondi si accende tutto (lo chiama LookTecnici nel suo FLASH): tutte le
## luci della sala visibili e più forti, sfarfallii fermi. Poi torna com'era.
func flash(durata := 1.0) -> void:
	if _flash_salvate.is_empty():
		for l in _sala.find_children("*", "Light3D", true, false):
			var luce := l as Light3D
			if luce is DirectionalLight3D:
				continue
			_flash_salvate.append([luce, luce.visible, luce.light_energy])
			luce.visible = true
			luce.light_energy = maxf(luce.light_energy, 1.0) * 2.5
	_flash_resta = maxf(_flash_resta, durata)


func _crea_tempesta() -> void:
	tempesta = Tempesta.new()
	tempesta.name = "Tempesta"
	tempesta.energia_lampo = 7.0
	if vetro_cupola:
		tempesta.materiali = [vetro_cupola]
	add_child(tempesta)
	tempesta.luce.light_angular_distance = 0.2  # ombre dei costoloni nitide anche col lampo


## La lampada sul palo accanto alla vasca sollevata: luce da ritratto sul viso della medusa
## affacciata. La accende lo script della sala (FlickerLight) quando si esce dagli spogliatoi;
## qui si regolano colore, cono, ombre e l'intensità a cui arriva.
func _prepara_ritratto() -> void:
	var lamp := _sala.find_child("luce_lampione", true, false) as SpotLight3D
	if lamp:
		lamp.look_at(ritratto_mira, Vector3.UP)
		lamp.light_color = colore_lampione
		lamp.spot_angle = 26.0              # stretto: il ritratto, non la sala
		lamp.spot_angle_attenuation = 1.3   # bordo morbido
		lamp.spot_range = 8.0
		lamp.spot_attenuation = 0.9
		lamp.light_size = 0.06              # ombre morbide del viso e delle mani sul bordo
		lamp.shadow_enabled = true
		lamp.shadow_blur = 1.2
		lamp.light_specular = 0.4
		lamp.light_volumetric_fog_energy = 1.6   # il cono si vede nella nebbia
		lamp.set_meta("grafica_priorita_ombra", 0)
		# L'intensità la comanda la FlickerLight della sala (base_energy * livello).
		for n in get_tree().root.find_children("*", "Node", true, false):
			if n.get("light") == lamp and n.get("base_energy") != null:
				n.set("base_energy", energia_ritratto)
				if n.get("is_on"):
					lamp.light_energy = energia_ritratto
	var trigger := get_node_or_null(percorso_trigger) as Node3D
	if trigger:
		trigger.global_position = punto_accensione


## Controluce freddo dall'alto, dietro la statua: stacca la sagoma dal fondo buio
## quando si entra dal vano sud.
func _crea_controluce() -> void:
	var c := SpotLight3D.new()
	c.name = "ControluceStatua"
	c.light_color = Color(0.62, 0.78, 1.0)
	c.light_energy = 5.0
	c.spot_range = 14.0
	c.spot_angle = 16.0
	c.spot_angle_attenuation = 1.4
	c.light_specular = 0.6
	c.light_volumetric_fog_energy = 0.5
	c.shadow_enabled = false
	add_child(c)
	var cima := monumento + Vector3(0, 1.15 + altezza_statua * 0.7, 0)
	c.look_at_from_position(monumento + Vector3(0, 9.6, -4.2), cima)


func _imposta_ambiente() -> void:
	var we: WorldEnvironment = null
	for n in get_tree().root.find_children("*", "WorldEnvironment", true, false):
		we = n
	if we == null:
		we = WorldEnvironment.new()
		we.name = "AmbienteSala"
		add_child(we)
	we.environment = ambiente
	we.camera_attributes = attributi_camera


func _regola_luci(n: Node) -> void:
	var nome := String(n.name)
	if n is Light3D:
		var l := n as Light3D
		l.light_volumetric_fog_energy = 1.0
		if nome.begins_with("luce_emergenza"):
			var o := l as OmniLight3D
			o.light_color = colore_emergenza
			o.light_energy = energia_emergenza
			o.omni_range = portata_emergenza
			o.omni_attenuation = 1.8   # pozze raccolte: il rosso non tinge pareti intere
			o.light_volumetric_fog_energy = 2.5
			o.light_specular = 0.7
			# Ombre solo su alcune (costano: sono omnidirezionali).
			var k := nome.get_slice("_", 2).to_int()
			o.shadow_enabled = k % 3 == 0
			o.shadow_bias = 0.08
			o.set_meta("grafica_priorita_ombra", 2)
			if k % 5 == 1:
				_sfarfallanti.append([o, o.light_energy, "pulsa", 0.0, 0.0])
		elif nome.begins_with("luce_neon"):
			l.light_color = colore_neon
			l.light_energy = energia_neon
			l.light_volumetric_fog_energy = 0.6
			# Pozze di luce fredda con ombre morbide (una sì e una no: costano), il buio in mezzo.
			var kn := nome.get_slice("_", 2).to_int()
			l.shadow_enabled = kn % 2 == 0
			l.shadow_blur = 1.5
			l.set_meta("grafica_priorita_ombra", 2)
			if l is SpotLight3D:
				var s := l as SpotLight3D
				s.spot_range = 8.0
				s.spot_angle = 62.0
				s.spot_angle_attenuation = 1.2
				s.spot_attenuation = 1.3
				s.light_size = 0.15
			elif l is OmniLight3D:
				(l as OmniLight3D).omni_range = 9.0
			var k := nome.get_slice("_", 2).to_int()
			if k in neon_difettosi:
				var modo: String = ["guasto", "sfarfalla", "morente"][k % 3]
				_sfarfallanti.append([l, l.light_energy, modo, randf_range(0.5, 4.0), 0.0])
		elif nome.begins_with("luce_faro"):
			# Luce principale della statua: dall'alto e davanti (fari sulla ringhiera sud).
			var s := l as SpotLight3D
			s.light_color = Color(1.0, 0.9, 0.8)
			s.light_energy = energia_fari
			s.spot_range = 16.0
			s.spot_angle = 13.0
			s.spot_angle_attenuation = 1.6   # bordo morbido
			s.spot_attenuation = 0.6
			s.shadow_enabled = true
			s.light_size = 0.06
			s.light_specular = 0.45           # niente riflessi bruciati sul vinile lucido
			s.light_volumetric_fog_energy = 1.6
			s.set_meta("grafica_priorita_ombra", 1)
		elif nome.begins_with("luce_monumento_basso"):
			# Faretti caldi dal basso: ombre in su sul viso, effetto "monumento di notte".
			var s := l as SpotLight3D
			s.light_color = Color(1.0, 0.7, 0.42)
			s.light_energy = energia_faretti
			s.spot_range = 7.0
			s.spot_angle = 24.0
			s.spot_angle_attenuation = 1.2
			s.spot_attenuation = 1.2
			s.light_specular = 0.3
			s.light_volumetric_fog_energy = 0.6
			# Ombre solo sui due davanti (verso la porta, +Z): il viso proietta le ombre in alto.
			var k := nome.get_slice("_", 3).to_int()
			s.shadow_enabled = k >= 2
			s.shadow_bias = 0.03
			s.set_meta("grafica_priorita_ombra", 2)
		elif nome == "luce_lampione":
			var s := l as SpotLight3D
			s.light_color = colore_lampione
			s.light_energy = energia_lampione
			s.light_specular = 0.5
			s.spot_range = 11.0
			s.spot_angle = 50.0
			s.spot_angle_attenuation = 0.8
			s.shadow_enabled = true
			s.light_size = 0.12
			s.light_volumetric_fog_energy = 3.0   # il cono si vede nella nebbia
			s.set_meta("grafica_priorita_ombra", 1)
			# Accensione e sfarfallio li fa la FlickerLight della sala (vedi _prepara_ritratto).
		elif nome.begins_with("luce_vasca"):
			# Sott'acqua nella vasca sollevata: fanno brillare la campana sotto la superficie.
			# (Nel GLB nuovo possono essere anche faretti: si regola quello che c'è.)
			l.light_color = Color(0.45, 0.85, 1.0)
			l.light_energy = 2.2
			l.shadow_enabled = false
			l.light_volumetric_fog_energy = 0.4
			if l is OmniLight3D:
				(l as OmniLight3D).omni_range = 3.5
				(l as OmniLight3D).omni_attenuation = 1.6
			elif l is SpotLight3D:
				(l as SpotLight3D).spot_range = maxf((l as SpotLight3D).spot_range, 4.0)
				(l as SpotLight3D).spot_attenuation = 1.6
		elif nome.begins_with("luce_subacquea"):
			var o := l as OmniLight3D
			o.light_energy = 3.0
			o.omni_range = 6.0
			o.light_volumetric_fog_energy = 1.5
		elif nome.begins_with("luce_insegna"):
			# Insegne al neon colorate (rosa, onda, stella): pozze di colore saturo, stile B.
			var o := l as OmniLight3D
			o.light_energy = energia_insegne * (2.0 if nome == "luce_insegna_rosa" else 1.0)
			o.omni_range = 5.5 if nome != "luce_insegna_rosa" else 8.0
			o.light_volumetric_fog_energy = 2.0
		elif nome.begins_with("luce_calda"):
			# Plafoniere navali a incandescenza: le poche luci calde per il contrasto col rosso e il blu.
			var o := l as OmniLight3D
			o.light_color = Color(1.0, 0.66, 0.36)
			o.light_energy = energia_plafoniere
			o.omni_range = 7.5
			o.omni_attenuation = 1.2
			o.light_volumetric_fog_energy = 1.4
			o.shadow_enabled = false
		elif nome == "luce_area_bimbi":
			var o := l as OmniLight3D
			o.light_color = Color(1.0, 0.74, 0.42)
			o.light_energy = 4.0
			o.omni_range = 10.0
			o.shadow_enabled = true
			o.light_volumetric_fog_energy = 1.5
		elif l is DirectionalLight3D:
			var d := l as DirectionalLight3D
			d.light_color = Color(0.55, 0.66, 1.0)
			d.light_energy = energia_luna
			d.shadow_enabled = true
			# Ombre morbide: la ragnatela netta dei costoloni compare solo col lampo
			# (LuceLampo ha diametro 0,2°): la gabbia che appare col tuono fa più paura.
			d.light_angular_distance = 1.3
			d.shadow_opacity = 0.75
			d.light_volumetric_fog_energy = 0.35
			d.shadow_bias = 0.05
	for c in n.get_children():
		_regola_luci(c)


func _process(delta: float) -> void:
	if _flash_resta > 0.0:
		_flash_resta -= delta
		if _flash_resta > 0.0:
			return
		for f in _flash_salvate:
			(f[0] as Light3D).visible = f[1]
			(f[0] as Light3D).light_energy = f[2]
		_flash_salvate.clear()
	for s in _sfarfallanti:
		var l: Light3D = s[0]
		var base: float = s[1]
		match s[2]:
			"pulsa":
				var p := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.0035 + base)
				l.light_energy = base * lerpf(0.25, 1.0, p * p)
				continue
		s[3] -= delta
		if s[4] > 0.0:   # raffica in corso
			s[4] -= delta
			l.visible = randf() > 0.5
			if s[4] <= 0.0:
				l.visible = s[2] != "morente" or randf() < 0.3
			continue
		if s[3] <= 0.0:
			match s[2]:
				"guasto":
					s[4] = randf_range(0.08, 0.35)
					s[3] = randf_range(3.0, 10.0)
				"sfarfalla":
					s[4] = randf_range(0.3, 1.4)
					s[3] = randf_range(1.0, 4.0)
				"morente":
					s[4] = randf_range(0.2, 0.8)
					s[3] = randf_range(1.5, 5.0)


func _crea_voxel_gi() -> void:
	var gi := VoxelGI.new()
	gi.name = "VoxelGI_Sala"
	gi.size = sala_dimensioni
	gi.subdiv = VoxelGI.SUBDIV_256
	if dati_gi != "" and ResourceLoader.exists(dati_gi):
		gi.data = load(dati_gi)
	# Il bake generico di Grafica cercherebbe la geometria tra i figli di questo nodo.
	gi.set_meta("grafica_bake_automatico", _sala == self)
	add_child(gi)
	gi.global_position = (_sala.global_transform * sala_centro) if _sala != self else to_global(sala_centro)
	if gi.data == null and _sala != self and is_instance_valid(Grafica) and int(Grafica.valore("gi")) == 1:
		gi.bake(_sala)   # senza dati cotti: calcolo all'avvio (lento, solo per le prove)


## Cuoce il VoxelGI della sala senza le emissioni delle lampade (la loro luce la fanno le
## Light3D, che il GI segue in tempo reale) e lo salva in [member dati_gi].
func cuoci_gi() -> void:
	var gi := get_node_or_null(^"VoxelGI_Sala") as VoxelGI
	if gi == null or dati_gi == "":
		return
	var spente := LookInterni.spegni_emissioni(_sala)
	gi.bake(_sala)
	DirAccess.make_dir_recursive_absolute(dati_gi.get_base_dir())
	print("GI sala -> ", dati_gi, " ", ResourceSaver.save(gi.data, dati_gi))
	LookInterni.ripristina_emissioni(spente)


func _crea_sonde() -> void:
	var sala := ReflectionProbe.new()
	sala.name = "Sonda_Sala"
	sala.size = Vector3(sala_dimensioni.x - 1.0, 13, sala_dimensioni.z - 1.0)
	sala.position = Vector3(sala_centro.x, 4.0, sala_centro.z)
	sala.origin_offset = Vector3(0, -2.0, 0)
	sala.box_projection = true
	sala.interior = true
	sala.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
	sala.max_distance = 60.0
	sala.intensity = 0.5   # piena, il riflesso uniforme del soffitto copriva le ombre sul pavimento
	add_child(sala)
	var vasca := ReflectionProbe.new()
	vasca.name = "Sonda_Piscina"
	vasca.size = Vector3(14.5, 4.0, 18.5)
	vasca.position = Vector3(0, 0.0, 4.0)
	vasca.origin_offset = Vector3(0, -0.8, 0)
	vasca.box_projection = true
	vasca.interior = true
	vasca.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
	vasca.blend_distance = 0.5
	add_child(vasca)


func _crea_effetti() -> void:
	# Nebbia bassa sul pavimento e nella piscina vuota.
	var nebbia := FogVolume.new()
	nebbia.name = "NebbiaBassa"
	nebbia.size = Vector3(sala_dimensioni.x - 1.0, 2.6, sala_dimensioni.z - 1.0)
	nebbia.position = Vector3(sala_centro.x, -1.0, sala_centro.z)
	var fm := FogMaterial.new()
	fm.density = 0.04
	fm.height_falloff = 2.5
	fm.edge_fade = 0.15
	fm.albedo = Color(0.78, 0.84, 0.86)
	var rumore := FastNoiseLite.new()
	rumore.frequency = 0.06
	var n3 := NoiseTexture3D.new()
	n3.noise = rumore
	n3.width = 48
	n3.height = 16
	n3.depth = 48
	n3.seamless = true
	fm.density_texture = n3
	nebbia.material = fm
	add_child(nebbia)
	var polvere := Pulviscolo.new()
	polvere.volume = Vector3(sala_dimensioni.x - 3.0, 9, sala_dimensioni.z - 3.0)
	polvere.densita = 0.5
	polvere.position = Vector3(sala_centro.x, 4.5, sala_centro.z)
	add_child(polvere)
	for p in [Vector3(6.5, 11.4, -3.0), Vector3(-9.0, 11.4, 4.5), Vector3(1.2, 11.4, 6.0), Vector3(14.0, 11.4, -9.0)]:
		var g := Gocce.new()
		g.position = p
		var sopra_piscina: bool = absf(p.x) < 7.0 and p.z > -13.0 and p.z < 5.0
		g.altezza = p.y + (2.0 if sopra_piscina else 0.0)
		add_child(g)
