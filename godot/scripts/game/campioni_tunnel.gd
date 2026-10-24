class_name CampioniTunnel
extends RefCounted
## I materiali campione del tunnel del viaggio sottomarino: un materiale senza texture per ogni shader del tunnel
## (SalaSottomarino), come quelli della Risalita (risalita_gioco.gd, CAMPIONI). Chi li tiene da prima (dall'ingresso
## nella sala dell'inseguimento, a schermo nero) fa sì che quegli shader non si compilino mentre il tunnel si
## costruisce o la prima volta che si vede: niente scatti. Lo rifà tests/aggiorna_campioni_tunnel.gd (e lo controlla,
## in CI: ogni shader del tunnel deve avere il suo campione).

const FILE := "res://assets/ambiente/sottomarino/materiali_campione.tres"


## Carica i campioni e crea subito i loro shader. Chi li chiama deve tenere l'array (gli shader vivono finché c'è un
## materiale che li usa).
static func carica() -> Array:
	if not ResourceLoader.exists(FILE):
		return []
	var out: Array = load(FILE).get_meta(&"materiali", [])
	for m in out:
		(m as Material).get_rid()   # lo shader si crea adesso, non al primo uso
	return out
