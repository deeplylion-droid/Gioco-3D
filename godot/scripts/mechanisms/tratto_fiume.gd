class_name TrattoFiume
extends Path3D
## Un tratto del fiume lento (FiumeLento): la ciambella lo percorre dall'inizio alla fine della curva.
## Alla fine passa al tratto [member prossimo], oppure a quello che sceglie la [member paratia] del
## bivio. Un tratto con [member uscita] finisce all'approdo: lì la ciambella si ferma e si scende.
## Prototipo (enigma-logica, docs/proposte/fiume_infermeria/nota_logica.md): niente grafica vera.

## Il tratto dopo (se non c'è una paratia).
@export var prossimo: TrattoFiume
## La paratia del bivio alla fine del tratto: sceglie lei il tratto dopo.
@export var paratia: ParatiaFiume
## Velocità fissa della corrente qui (m/s); 0 = quella del fiume (si cambia col getto).
@export var velocita := 0.0
## Ramo sbagliato: alla fine si torna all'imbarco.
@export var ramo_sbagliato := false
## Fine del fiume: l'approdo.
@export var uscita := false


func lunghezza() -> float:
	return curve.get_baked_length() if curve else 0.0


## Il punto globale a [param s] metri dall'inizio.
func punto(s: float) -> Vector3:
	return global_transform * curve.sample_baked(clampf(s, 0.0, lunghezza()))


## La direzione della corrente (globale, orizzontale) a [param s] metri dall'inizio.
func direzione(s: float) -> Vector3:
	var a := punto(s - 0.25)
	var b := punto(s + 0.25)
	var d := b - a
	d.y = 0.0
	return d.normalized() if d.length_squared() > 0.000001 else -global_basis.z


## Il tratto che viene dopo questo.
func seguente() -> TrattoFiume:
	if paratia:
		return paratia.uscita_attuale()
	return prossimo
