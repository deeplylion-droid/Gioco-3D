extends Node
## Collaudo della morbidezza leggera: confronta due file di punti (MORB_DUMP di misura_morbidezza.gd): per ogni
## registrazione, il primo fotogramma diverso e lo scarto massimo.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/collaudo/confronta_dump_morbidezza.gd a b

func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var fa := FileAccess.open(a[1], FileAccess.READ)
	var fb := FileAccess.open(a[2], FileAccess.READ)
	var r := 0
	while fa.get_position() < fa.get_length() and fb.get_position() < fb.get_length():
		var ua: Array = fa.get_var()
		var ub: Array = fb.get_var()
		var primo := -1
		var mx := 0.0
		var dove := ""
		var diversi := 0
		for f in mini(ua.size(), ub.size()):
			var pa: Array = ua[f]
			var pb: Array = ub[f]
			var df := 0.0
			for k in mini(pa.size(), pb.size()):
				var xa: PackedVector3Array = pa[k]
				var xb: PackedVector3Array = pb[k]
				for i in mini(xa.size(), xb.size()):
					var d := xa[i].distance_to(xb[i])
					if d > df:
						df = d
					if d > mx:
						mx = d
						dove = "f%d k%d i%d" % [f, k, i]
			if df > 0.0:
				diversi += 1
				if primo < 0:
					primo = f
		print("registrazione %d: %d fotogrammi (%d), diversi %d, primo %d, scarto massimo %.6f m (%s)" % [r, ua.size(), ub.size(), diversi, primo, mx, dove])
		r += 1
	get_tree().quit(0)
