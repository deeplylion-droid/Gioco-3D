class_name WaterMix
extends RefCounted
## Il colore dell'acqua: quanta parte di ogni pigmento c'è in un'acqua (enigma degli acquari, GDD,
## 18 ottobre). Un miscuglio è un Dictionary {pigmento: frazione}, con le frazioni che sommano al
## massimo 1; il resto è acqua chiara (il dizionario vuoto è acqua tutta chiara). Le vasche
## (WaterTank) e il serbatoio dello zaino (WaterPack) ne tengono uno e lo mescolano per litri.
## Le chiavi sono String: così si salva con i checkpoint, anche su disco in JSON.

const GIALLO := "giallo"
const BLU := "blu"
## Il verde dell'enigma riuscito e l'acqua torbida di quando lo sbagli.
const VERDE := "verde"
const TORBIDA := "torbida"

## I colori, provvisori: l'aspetto dell'acqua colorata lo propone enigma-ambiente all'utente.
const COLORI := {
	GIALLO: Color(1.0, 0.82, 0.08),
	BLU: Color(0.08, 0.3, 0.95),
	VERDE: Color(0.25, 0.78, 0.12),
	TORBIDA: Color(0.36, 0.3, 0.18),
}
## Le tinte tra blu (0) e giallo (1), in base alla parte di giallo sul totale di giallo e blu: con
## 2 di giallo e 1 di blu viene il verde.
const SFUMATURA := [
	[0.0, Color(0.08, 0.3, 0.95)],
	[0.5, Color(0.05, 0.55, 0.55)],
	[0.667, Color(0.25, 0.78, 0.12)],
	[1.0, Color(1.0, 0.82, 0.08)],
]


## Il miscuglio di [param la] litri di [param a] e [param lb] litri di [param b].
static func mescola(a: Dictionary, la: float, b: Dictionary, lb: float) -> Dictionary:
	var tot := maxf(la, 0.0) + maxf(lb, 0.0)
	if tot <= 0.000001:
		return a.duplicate()
	var r := {}
	for k in a:
		r[k] = float(a[k]) * maxf(la, 0.0) / tot
	for k in b:
		r[k] = float(r.get(k, 0.0)) + float(b[k]) * maxf(lb, 0.0) / tot
	for k in r.keys():
		if float(r[k]) < 0.0001:
			r.erase(k)
	return r


## Acqua tutta di un pigmento ([code]""[/code] = chiara).
static func pura(pigmento: String) -> Dictionary:
	return {} if pigmento == "" else {pigmento: 1.0}


static func frazione(m: Dictionary, pigmento: String) -> float:
	return float(m.get(pigmento, 0.0))


## Quanta parte non è acqua chiara (0 = chiara, 1 = tutta colorata).
static func intensita(m: Dictionary) -> float:
	var s := 0.0
	for k in m:
		s += float(m[k])
	return clampf(s, 0.0, 1.0)


## Il colore della parte colorata (senza l'acqua chiara). Va usato insieme a [method intensita].
static func tinta(m: Dictionary) -> Color:
	var g := frazione(m, GIALLO)
	var b := frazione(m, BLU)
	var somma := 0.0
	var c := Color(0, 0, 0)
	if g + b > 0.0:
		c += sfumatura(g / (g + b)) * (g + b)
		somma += g + b
	for k in m:
		if k == GIALLO or k == BLU:
			continue
		var w := float(m[k])
		c += (COLORI.get(k, Color(0.5, 0.5, 0.5)) as Color) * w
		somma += w
	if somma <= 0.0:
		return Color(1, 1, 1)
	c = c / somma
	c.a = 1.0
	return c


## La tinta dei miscugli di giallo e blu: [param giallo] è la parte di giallo (0..1).
static func sfumatura(giallo: float) -> Color:
	var x := clampf(giallo, 0.0, 1.0)
	for i in range(1, SFUMATURA.size()):
		var a: Array = SFUMATURA[i - 1]
		var b: Array = SFUMATURA[i]
		if x <= float(b[0]):
			return (a[1] as Color).lerp(b[1] as Color, (x - float(a[0])) / (float(b[0]) - float(a[0])))
	return SFUMATURA[-1][1]


## Il colore da mostrare per un'acqua che, chiara, sarebbe [param base].
static func colore(m: Dictionary, base: Color) -> Color:
	var k := intensita(m)
	if k <= 0.0:
		return base
	var c := base.lerp(tinta(m), k)
	c.a = base.a
	return c
