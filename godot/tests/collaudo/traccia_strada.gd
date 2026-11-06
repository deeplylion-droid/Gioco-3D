extends "res://tests/test_strada.gd"
## Collaudo: la traccia della strada del capitolo col giocatore vero (test_strada.gd, senza schermo). Mentre cammina,
## ogni [constant OGNI] m scrive in <file> una riga "tratto|x|y|z|yaw" (piedi e direzione del giocatore), per fare poi
## gli scatti dagli occhi lungo la strada vera (giro.gd, per parti).
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/traccia_strada.gd <file>

const OGNI := 2.0
var _tratto := "partenza"
var _ultimo := Vector3(INF, INF, INF)
var _f: FileAccess


func _vai(nome: String, punti: Array, per_punto := 900) -> bool:
	_tratto = nome
	return await super._vai(nome, punti, per_punto)


func _physics_process(_d: float) -> void:
	if _f == null:
		var a := OS.get_cmdline_user_args()
		_f = FileAccess.open(a[1] if a.size() > 1 else "/tmp/traccia_strada.txt", FileAccess.WRITE)
	if p == null or not is_instance_valid(p) or not p.is_inside_tree():
		return
	var q := p.global_position
	if q.distance_to(_ultimo) >= OGNI and p.is_on_floor():
		_ultimo = q
		_f.store_line("%s|%.2f|%.2f|%.2f|%.1f" % [_tratto, q.x, q.y, q.z, rad_to_deg(p.yaw)])
		_f.flush()
