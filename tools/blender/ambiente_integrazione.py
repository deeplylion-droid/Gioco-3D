"""Scrive assets_src/ambiente/INTEGRAZIONE.md (come montare la sala in Godot) a partire dai GLB e da
glb/sala/sala_dati.json, così i numeri restano sempre giusti. Python normale (niente Blender).

Uso (dalla radice del repository):
  /home/user/tools/blender-venv/bin/python tools/blender/ambiente_integrazione.py
"""
import json, os, struct

QUI = os.path.dirname(os.path.abspath(__file__))
RADICE = os.path.abspath(os.path.join(QUI, '..', '..'))
SALA = os.path.join(RADICE, 'assets_src', 'ambiente', 'glb', 'sala')
OUT = os.path.join(RADICE, 'assets_src', 'ambiente', 'INTEGRAZIONE.md')

CONTENUTO = {
    'sala_architettura': 'pavimento (piastrelle asciutte, umide e bagnate; pozzanghere a specchio), pareti con oblò e il **vano verso gli spogliatoi** con la porta stagna aperta, galleria con colonne e ringhiere, scala della galleria est, soffitto con travi, cartelloni (solo disegni), plafoniere al neon, luci d\'emergenza, insegna a pesce, altoparlanti',
    'sala_monumento': '**monumento della statua (vuoto)**: piedistallo a gradoni con fregio a mosaico marino, conchiglie d\'ottone, scatola del pulsante, 4 faretti dal basso; cordone di velluto su colonnine; lampione; 2 fari sulla ringhiera della galleria; offerte dei bambini (disegni, conchiglie, stelle marine, secchiello)',
    'sala_cupola': 'cupola: tamburo, costoloni, anelli, lastre di vetro (alcune rotte: lì sotto piove dentro)',
    'sala_piscina': 'piscina a onde vuota: fondo con pendenza e conca dello scarico, linea dell\'ultimo livello dell\'acqua, bordi a sfioro con griglie, bocchette della camera delle onde, rosa dei venti a mosaico, 2 scalette',
    'sala_area_bimbi': 'struttura di gioco, **secchio gigante** e **ruota a pale** (nodi a parte, con il perno giusto), vasche basse a scacchi',
    'sala_torre_scivoli': 'torre degli scivoli (piani a grigliato, scale a rampe, pozzo centrale aperto), 3 tubi colorati con sostegni e pennone della spirale, vasca d\'arrivo',
    'sala_oggetti': 'oggetti di scena Meshy (istanze condivise), comprese le offerte alla base del monumento (salvagente, orsetto, paperelle, pallone, ciambella)',
    'sala_interattivi': 'elementi degli enigmi come nodi separati con il perno giusto (vedi sotto)',
    'sala_acqua': '**segnaposto** piatti dell\'acqua (da sostituire con l\'acqua vera)',
}
ORDINE = ['sala_architettura', 'sala_monumento', 'sala_cupola', 'sala_piscina', 'sala_area_bimbi',
          'sala_torre_scivoli', 'sala_oggetti', 'sala_interattivi', 'sala_acqua']


def leggi_glb(p):
    """Triangoli visibili e numero di collisioni di un GLB (legge solo il JSON del glTF)."""
    with open(p, 'rb') as f:
        f.read(12)
        lung, tipo = struct.unpack('<II', f.read(8))
        g = json.loads(f.read(lung))
    acc = g.get('accessors', [])
    mesh_tri = []
    for m in g.get('meshes', []):
        t = 0
        for pr in m['primitives']:
            if 'indices' in pr:
                t += acc[pr['indices']]['count'] // 3
            else:
                t += acc[pr['attributes']['POSITION']]['count'] // 3
        mesh_tri.append(t)
    tri, col = 0, 0
    for n in g.get('nodes', []):
        nome = n.get('name', '')
        if '-colonly' in nome or '-convcolonly' in nome:
            col += 1
        elif 'mesh' in n:
            tri += mesh_tri[n['mesh']]
    return tri, col


def g3(v):
    return '(' + ', '.join(f'{x:g}' for x in v) + ')'


def scrivi():
    d = json.load(open(os.path.join(SALA, 'sala_dati.json')))
    pd, vano, sp = d['piedistallo'], d['vano_spogliatoi'], d['spawn_ingresso']
    righe = []
    for nome in ORDINE:
        p = os.path.join(SALA, nome + '.glb')
        if not os.path.exists(p):
            continue
        tri, col = leggi_glb(p)
        mb = os.path.getsize(p) / 1e6
        righe.append(f"| `{nome}.glb` | {CONTENUTO[nome]} | {tri // 1000 if tri >= 1000 else tri}{' mila' if tri >= 1000 else ''} | {col or '-'} | {mb:.1f} MB |")
    luci = d['luci']
    n_neon = sum(1 for L in luci if L['nome'].startswith('luce_neon'))
    n_em = sum(1 for L in luci if L['nome'].startswith('luce_emergenza'))
    tab_luci = []
    for L in luci:
        if 'godot' in L:
            dove = g3(L['godot'])
        else:
            dove = 'direzione ' + g3(L['direzione_godot'])
        extra = L.get('intensita', '')
        if 'direzione_godot' in L and 'godot' in L:
            extra = (extra + ' ' if extra else '') + 'punta verso ' + g3(L['direzione_godot'])
        tab_luci.append(f"| `{L['nome']}` | {L['tipo']} | {dove} | {g3(L['colore'])} | {extra} |")
    tab_int = [f"| `{k}` | {g3(v['perno_godot'])} |" for k, v in d['interattivi'].items()]
    acqua = []
    for a in d['acqua']:
        if 'x' in a:
            dove = f"x da {a['x'][0]:g} a {a['x'][1]:g}, z da {-a['y'][1]:g} a {-a['y'][0]:g}"
        else:
            dove = f"intorno a {g3(a['centro_godot'])}"
        acqua.append(f"| `{a['nome']}` | {a['cosa']} | {a['quota_blender']:g} | {dove} |")
    testo = f"""# Sala principale: come montarla in Godot

La sala principale dell'acquapark (capitolo 1) è pronta come **GLB a pezzi**, tutti con la stessa
origine: in Godot si istanziano tutti in **(0, 0, 0)**, scala 1, e combaciano. Misure in metri.
Le coordinate qui sotto sono già **in Godot** (Y in alto). Da Blender: `(x, y, z) -> (x, z, -y)`.
Tutti i numeri vengono da `glb/sala/sala_dati.json`, scritto dallo stesso script che fa i GLB; questo
file lo rigenera `tools/blender/ambiente_integrazione.py`.

## Novità (15 ottobre)

- **La sala è più lunga di 8 m verso sud**: il muro sud ora è a **z = 20** (prima 12). Tutto il resto
  (piscina, pozza, portello, turbina, cancello, vasche, torre, area bimbi) è **rimasto dov'era**:
  cambiano solo l'ingresso, lo spawn e la statua.
- **Vano verso gli spogliatoi** nel muro sud: luce **1,2 x 2,2 m**, x da {vano['x'][0]:g} a {vano['x'][1]:g},
  faccia verso la sala a z = {vano['faccia_sala_godot_z']:g}, retro a z = {vano['faccia_retro_godot_z']:g} (muro spesso 0,2 m). Il vano è
  libero sia nella mesh sia nelle collisioni (verificato con raggi in Godot); davanti c'è una porta
  stagna aperta verso la sala, con la sua collisione. Prima il vano non c'era: il muro era pieno.
- **Spogliatoi** (`assets_src/ambienti_interni`): {vano['nota_attacco']}.
  Così il loro muro (con la saracinesca) sta subito dietro il nostro, senza sovrapporsi.
- **Monumento della statua** (`sala_monumento.glb`): entrando dal vano la medusa si vede subito, intera
  e centrata, a 10 m, con la cupola e la tempesta sopra la testa (provato in Godot con la medusa del
  gioco portata a 4,5 m).
- **Tubo dell'inseguimento**: è lo scivolo rosso a spirale (`sala_scivolo_spirale`), ora Ø interno
  **1,6 m** (parete 6 cm), come i moduli di `assets_src/ambienti_tecnici/glb/scivoli_kit.glb`. Parte dal
  piano in cima alla torre (y 8,6), esce dalla faccia ovest, gira intorno al pennone, attraversa la sala
  sopra la piscina e sputa nella vasca d'arrivo da est (bocca 16 cm sopra l'acqua). Gli altri due tubi
  restano da 1,0 m (decorativi).
- **Revisione di qualità**: metallo grigio-verde (colonne, sostegni, galleria), piano del piedistallo
  chiaro e lucido con un velo d'acqua, due teli con la mascotte ai lati della statua (faretti
  `luce_cartellone_*`); tolti i due cartelloni del lato est.
- **Passata di qualità**: pavimento a piastrelle asciutte/umide/bagnate e pozzanghere a specchio, sporco
  nei colori dei vertici, battiscopa a sguscio e listelli, rivetti su travi e galleria, piastrelle
  mancanti, oblò con vetro scuro, cupola con costoloni a T e lastre sporche/incrinate/rotte, plafoniere
  calde (`luce_calda_*`) e insegne al neon (`luce_insegna_*`). Dettagli in `KIT.md`.

## File (cartella `assets_src/ambiente/glb/sala/`)

| File | Cosa contiene | Triangoli | Collisioni | Peso |
|---|---|---|---|---|
{chr(10).join(righe)}
| `sala_luci.glb` | {len(luci)} luci già al loro posto (Omni, Spot, una Directional) | - | - | |
| `sala_dati.json` | posizioni di luci, acqua, piedistallo, vano, spawn, camere | | | |

Texture: 2K JPG incorporate (colore, normal OpenGL, ORM = occlusione/rugosità/metallo). PNG solo dove
serve l'alfa (grigliati, rosa dei venti). Gli oggetti piccoli hanno texture 1K, i grandi 2K.
**Nuovo GLB da aggiungere alla scena: `sala_monumento.glb`** (con lo stesso import script degli altri).

## Import (una volta sola)

1. Copia la cartella `glb/sala/` nel progetto (per esempio `res://assets/ambiente/sala/`) e
   `assets_src/ambiente/godot/ambiente_post_import.gd` accanto.
2. Per ogni GLB: Import > **Import Script** = `ambiente_post_import.gd` > Reimport. Lo script:
   - accende `vertex_color_use_as_albedo` sui materiali `M_amb_*` (sporco, umidità e chiazze bagnate
     sono nei colori dei vertici, calcolati in spazio mondo: niente ripetizioni);
   - mette **alpha scissor** e doppia faccia ai grigliati e alla rosa dei venti;
   - vetri in trasparenza alpha; pozzanghere a rugosità 0,02; emissione più forte per neon e luci.
3. Le collisioni si creano da sole (nodi `-colonly`/`-convcolonly` diventano StaticBody3D +
   CollisionShape3D). I LOD li genera l'importer (`meshes/generate_lods`, attivo di serie).
   Le collisioni hanno i vertici già in coordinate della sala: lo script controlla prima dell'export
   che ognuna tocchi la geometria visibile, e lo stesso controllo è rifatto in Godot (0 fuori posto).
   **La toppa delle collisioni (`collision_fix.gd`, `BROKEN_COLLISIONS`) non serve più.**
4. Se usate LightmapGI: Import > Meshes > Light Baking = **Static Lightmaps** (genera la UV2).

## Montaggio

- Un `Node3D` "SalaPrincipale" con dentro le istanze dei GLB, tutte in (0, 0, 0).
- Le luci di `sala_luci.glb` le regola `LookSala` (addon grafica) con i valori consigliati più sotto.
  `assets_src/ambiente/godot/sala_luci_ambiente.gd` serve solo per le prove dell'ambiente.
- **Spawn del giocatore** (appena passato il vano): {g3(sp['godot'])}, guarda verso **-Z** (la statua).
- **Monumento (piedistallo vuoto, per la medusa)**: centro {g3(pd['centro_godot'])}.
  - **Piano superiore a y = {pd['quota_piano']:g} m**, diametro del piano {pd['diametro_piano']:g} m (raggio {pd['diametro_piano'] / 2:g}; con il toro del
    bordo {pd['diametro_piano'] + 0.06:g} m): i tentacoli della medusa (raggio 1,55 m) restano tutti appoggiati.
    La statua va appoggiata con l'origine in **{g3(pd['statua']['appoggio_godot'])}**, rivolta verso **+Z** (la porta).
    Con 4,5 m di statua la cima arriva a y = {pd['statua']['cima_godot']:g} (la galleria è a 4,0-4,3; il soffitto a 11,5).
  - Gradoni: il primo Ø {pd['diametro_gradino_basso']:g} m alto {pd['quote_gradini'][0]:g}, il secondo Ø {pd['diametro_gradino_alto']:g} m fino a {pd['quote_gradini'][1]:g};
    tamburo Ø {pd['diametro_tamburo']:g} m con il fregio a mosaico (onde, pesci, stella marina, medusa).
  - **Pulsante dei bambini (sigla, scena S1)**: il fungo rosso è il nodo `sala_pulsante_piedistallo`
    in {g3(pd['pulsante_bimbi']['godot'])}, sul davanti del tamburo, rivolto verso +Z; si preme verso -Z.
  - Cordone di velluto su colonnine a raggio {pd['raggio_cordone']:g} m, aperto sul davanti (varco di 3 m verso
    la porta); collisioni sulle campate.
  - Luci del monumento (in `sala_luci.glb`): `luce_faro_0/1` (fari sulla ringhiera della galleria sud,
    ombre accese), `luce_monumento_basso_0..3` (faretti nel primo gradino, dal basso), `luce_lampione`
    (lampione accanto, base {g3(d['lampione']['base_godot'])}, la lampada è sopra il davanti della statua).
  - Offerte dei bambini alla base (disegni a pastello senza scritte, conchiglie, stelle marine,
    secchiello; salvagente, orsetto, paperelle, pallone e ciambella in `sala_oggetti.glb`).
- **Secchio gigante**: nodo `sala_secchio_gigante`, perno sui suoi perni; si ribalta ruotando intorno all'asse **X**.
- **Ruota a pale**: nodo `sala_ruota_pale`, perno sull'asse, gira intorno all'asse **X**.
- La galleria si sale dalla scala sul lato est; la torre dalle rampe sul lato sud.

## Elementi interattivi (`sala_interattivi.glb`)

Ogni nodo ha l'origine sul suo perno (cerniera o asse): basta ruotarlo o spostarlo.
Non sono cambiati, tranne il pulsante del piedistallo (nuova posizione).

| Nodo | Perno in Godot |
|---|---|
{chr(10).join(tab_int)}

## Acqua (da fare con l'acqua vera; in `sala_acqua.glb` ci sono i segnaposto)

| Segnaposto | Cosa | Livello (y Godot) | Dove |
|---|---|---|---|
{chr(10).join(acqua)}

La piscina a onde resta **vuota**: sul fondo si vede la linea scura dell'ultimo livello dell'acqua e la
conca dello scarico più sporca. Sul pavimento della sala le piastrelle più bagnate sono lucide e ci
sono pozzanghere a specchio (con SSR riflettono le luci rosse).

## Luci (in `sala_luci.glb`)

Le posizioni e le direzioni sono giuste; le intensità **nel gioco le decide `LookSala` dell'addon
grafica** (con `LookSalaLunga` dell'integratore): glTF e Godot usano unità diverse. Valori consigliati
(`light_energy`, raggio): emergenza rosse 3 (raggio 8); neon 2,5 (spot, raggio 7, angolo 70); fari del
monumento `luce_faro_*` **9,5** (spot, angolo 15, raggio 16, ombre), faretti `luce_monumento_basso_*`
**0,6** (spot, angolo 24, raggio 7); lampione 10 (spot 55 gradi, ombre); plafoniere calde `luce_calda_*`
1,8 (raggio 7,5, colore 1,0/0,68/0,38); insegne `luce_insegna_*` 1,3 (raggio 5,5); subacquee 3 (raggio 5);
faretti dei teli con la mascotte `luce_cartellone_*` 2,5 (spot, angolo 30, raggio 6, caldi); luna 0,35 con ombre. `godot/sala_luci_ambiente.gd` serve solo per le prove dell'ambiente e usa gli
stessi valori. In tutto {n_neon} neon accesi, {n_em} luci d'emergenza, lampione, 2 fari e 4 faretti del monumento,
5 plafoniere calde, 3 insegne, 2 subacquee, area bimbi, luna.

| Nome | Tipo | Posizione Godot | Colore | Note |
|---|---|---|---|---|
{chr(10).join(tab_luci)}

## Ambiente consigliato (WorldEnvironment)

- Nebbia volumetrica: densità ~0,02, più fitta in basso, albedo grigio-azzurro.
- SSR acceso (pavimento bagnato e pozzanghere), SSAO, SSIL, glow per neon e luci rosse; SDFGI va bene.
- Cielo: notte di tempesta (scuro, nuvole) con qualche lampo: si vede dalla cupola.
- Tonemap AgX o Filmic: la sala deve restare buia con le pozze di luce.

## Cosa manca

Kit di dettagli della sessione ambienti-2 (detriti, cavi, tubi a muro, bocchette, corpi lampada):
quando arriva in main lo si posiziona con il suo JSON. L'interno del tubo dell'inseguimento per il
gioco è nel kit degli scivoli di ambienti_tecnici (qui il tubo ha solo le collisioni esterne).
"""
    with open(OUT, 'w') as f:
        f.write(testo)
    print('scritto', OUT)


if __name__ == '__main__':
    scrivi()
