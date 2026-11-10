extends Node
## Per sonda_tunnel_entrata: un segno alla fine dei _process e uno nelle chiamate differite del fotogramma.


func _process(_d: float) -> void:
	RiscaldamentoShader.segno("fine _process")
	(func(): RiscaldamentoShader.segno("differite")).call_deferred()
