extends Node
## Le impostazioni e i progressi di chi ha giocato quando il gioco si chiamava "Splash Lagoon".
## La cartella user:// prende il nome da application/config/name: col nome nuovo (Jilly Jubilee, 22
## ottobre) Godot ne usa una nuova e vuota. Al primo avvio, se nella cartella nuova non ci sono né le
## impostazioni né il salvataggio e c'è la cartella vecchia accanto, copia da lì quei due file (il
## resto, cioè log e cache degli shader, si rifà da sé).
## È il primo autoload: copia in _init, prima che Grafica, Audio e GameState leggano i loro file.

const NOME_VECCHIO := "Splash Lagoon"
## I file del gioco in user://: si copiano questi, e se nella cartella nuova ce n'è già uno non si
## copia niente.
const FILE_DEL_GIOCO := ["settings.cfg", "salvataggio.json"]

## Quanti file ha copiato all'avvio (per i test e il log).
var copiati := 0


func _init() -> void:
	var nuova := OS.get_user_data_dir()
	var vecchia := nuova.get_base_dir().path_join(NOME_VECCHIO)
	if nuova.get_file() == NOME_VECCHIO or not DirAccess.dir_exists_absolute(vecchia):
		return
	copiati = eredita(vecchia, nuova)
	if copiati > 0:
		print("Impostazioni e progressi di %s copiati da %s (%d file)" % [NOME_VECCHIO, vecchia, copiati])


## Copia in [param nuova] i FILE_DEL_GIOCO che ci sono in [param vecchia], se [param nuova] non ne ha
## ancora nessuno. Restituisce quanti file ha copiato.
static func eredita(vecchia: String, nuova: String) -> int:
	for f in FILE_DEL_GIOCO:
		if FileAccess.file_exists(nuova.path_join(f)):
			return 0
	var n := 0
	for f in FILE_DEL_GIOCO:
		var da := vecchia.path_join(f)
		if not FileAccess.file_exists(da):
			continue
		var a := nuova.path_join(f)
		DirAccess.make_dir_recursive_absolute(nuova)
		if DirAccess.copy_absolute(da, a) == OK:
			n += 1
		else:
			push_warning("Non riesco a copiare %s in %s" % [da, a])
	return n
