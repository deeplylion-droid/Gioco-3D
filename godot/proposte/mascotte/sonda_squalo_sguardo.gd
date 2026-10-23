extends Node
## Sonda: dove guarda il muso del mostro-squalo (dall'osso testa all'osso bocca) rispetto al giocatore, nel giro C,
## sull'animazione del GLB (spazio del modello: il giocatore davanti a lui, glTF (0; 1,1; 1,55)).
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://proposte/mascotte/sonda_squalo_sguardo.gd

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var s := (load("res://assets/models/mascotte/mostro_squalo_A_rig.glb") as PackedScene).instantiate() as Node3D
	add_child(s)
	var ap := s.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var sk := s.find_child("*", true, false) as Node
	for n in s.find_children("*", "Skeleton3D", true, false):
		sk = n
	var k := sk as Skeleton3D
	var anim := ap.get_animation_list()[0]
	ap.play(anim)
	for t in [6.6, 7.6, 8.2, 8.4, 8.6, 8.8, 9.0, 9.2, 9.4]:
		ap.seek(t, true)
		await get_tree().process_frame
		var testa := (k.global_transform * k.get_bone_global_pose(k.find_bone("testa"))).origin
		var bocca := (k.global_transform * k.get_bone_global_pose(k.find_bone("bocca"))).origin
		var radice := (k.global_transform * k.get_bone_global_pose(k.find_bone("radice")))
		var muso := (bocca - testa) * Vector3(1, 0, 1)
		var verso := (Vector3(0, 1.1, 1.55) - testa) * Vector3(1, 0, 1)
		var corpo := radice.basis.z * Vector3(1, 0, 1)
		print("t %.1f  muso-giocatore %4.0f gradi  corpo %4.0f  muso %4.0f" % [t, rad_to_deg(muso.angle_to(verso)),
			rad_to_deg(atan2(corpo.x, corpo.z)), rad_to_deg(atan2(muso.x, muso.z))])
	get_tree().quit()
