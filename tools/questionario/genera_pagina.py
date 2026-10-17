# Genera una pagina di scelte per l'utente: un file HTML con immagini, audio e video incorporati.
# Ogni voce ha i suoi pulsanti: Approvo / Da cambiare, oppure una scelta tra versioni (A, B, ...).
# Le risposte si salvano nel database della pagina (capability "db", collezione "risposte",
# un documento per voce: {stato, nota, quando}); si leggono con ArtifactData list.
#
# Uso: python3 tools/questionario/genera_pagina.py <voci.py> <cartella_media> <uscita.html> "<Titolo>" <chiave>
#   <voci.py>        file con INTRO, SEZIONI (e facoltativo CORRETTI): vedi voci_esempio_zaino.py
#   <cartella_media> dove stanno le immagini (.jpg), gli audio (.mp3) e i video (.mp4 + _poster.jpg)
#   <chiave>         nome per il salvataggio locale nel browser, diverso per ogni pagina
# Poi si pubblica con lo strumento Artifact, capabilities {"db": {}}.
import base64, html, importlib.util, io, json, os, re, sys
from PIL import Image

VOCI, P, OUT, TITOLO, CHIAVE = sys.argv[1:6]

def img_uri(path, width=1000):
    im = Image.open(path).convert("RGB")
    if im.width > width:
        im = im.resize((width, round(im.height * width / im.width)), Image.LANCZOS)
    buf = io.BytesIO()
    im.save(buf, "JPEG", quality=74, optimize=True, progressive=True)
    return "data:image/jpeg;base64," + base64.b64encode(buf.getvalue()).decode()

def audio_uri(path):
    return "data:audio/mpeg;base64," + base64.b64encode(open(path, "rb").read()).decode()

_spec = importlib.util.spec_from_file_location("voci", VOCI)
voci = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(voci)
SEZIONI, INTRO = voci.SEZIONI, voci.INTRO
CORRETTI = getattr(voci, "CORRETTI", [])

def paragrafi(t):
    """Ogni opzione (A:, B:, 1:, "1, nord:") va a capo, così sul telefono si leggono una per una."""
    t = re.sub(r'(?<=[.!?)"]) (?=(?:[ABC][12]?|[1-3])(?::|, \w+:) )', "\n", t)
    return [x for x in t.split("\n") if x.strip()]

def esc(t):
    return html.escape(t, quote=True)

def media_html(v):
    out = []
    for m in v["media"]:
        tipo, f, dida = m[:3]
        larghezza = m[3] if len(m) > 3 else 1000   # i fogli con più viste li tengo più grandi
        path = f if f.startswith("/") else P + "/" + f
        if not os.path.exists(path):
            raise SystemExit("manca " + path)
        if tipo == "img":
            el = f'<img class="foto" src="{img_uri(path, larghezza)}" alt="{esc(dida or v["titolo"])}" loading="lazy">'
        elif tipo == "video":
            # Il fotogramma di copertina sta accanto al video, con lo stesso nome e _poster.jpg.
            poster = img_uri(path[:-4] + "_poster.jpg", 960)
            dati = "data:video/mp4;base64," + base64.b64encode(open(path, "rb").read()).decode()
            el = f'<video controls playsinline preload="metadata" poster="{poster}" src="{dati}"></video>'
        else:
            el = f'<audio controls preload="none" src="{audio_uri(path)}"></audio>'
        out.append(f'<figure>{el}' + (f'<figcaption>{esc(dida)}</figcaption>' if dida else '') + '</figure>')
    return "".join(out)

parti, tutte = [], []
for nome_sez, voci in SEZIONI:
    blocchi, approvabili = [], 0
    for v in voci:
        tutte.append(v)
        approva = [val for val, _ in v["scelte"]] == ["ok", "cambia"]
        approvabili += approva
        bottoni = "".join(
            f'<button type="button" class="bt{" ok" if val == "ok" else " cambia" if val == "cambia" else " opz"}" data-scelta="{esc(val)}">{esc(et)}</button>'
            for val, et in v["scelte"])
        n = len(v["scelte"])
        blocchi.append(f'''
<article class="voce" id="voce-{v["id"]}" data-id="{v["id"]}">
  <header class="voce-testa"><h3>{esc(v["titolo"])}</h3><span class="stato" data-stato=""></span></header>
  {"".join(f"<p>{esc(par)}</p>" for par in paragrafi(v["testo"]))}
  {media_html(v)}
  <div class="scelte" style="--n:{2 if n in (2, 4) else min(n, 3)}" role="group" aria-label="La tua scelta">{bottoni}</div>
  <label class="nota-etichetta" for="nota-{v["id"]}">Nota, facoltativa</label>
  <textarea class="nota" id="nota-{v["id"]}" rows="2" placeholder="Cosa cambieresti, o un commento"></textarea>
</article>''')
    bt = f'<button type="button" class="bt-sez">Approvo quelle senza risposta</button>' if approvabili else ''
    parti.append(f'''
<section class="sezione">
  <div class="sez-testa"><h2>{esc(nome_sez)}</h2>{bt}</div>
  {"".join(blocchi)}
</section>''')

ids = [v["id"] for v in tutte]
etichette = {v["id"]: {val: et for val, et in v["scelte"]} for v in tutte}

PAGINA = f'''<title>{esc(TITOLO)}</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Oswald:wght@500;600&family=IBM+Plex+Sans:wght@400;500;600&display=swap">
<style>
/* Colonna unica da telefono: intestazione fissa con il contatore, poi sezioni di proposte da approvare o scegliere. */
:root {{
  --sfondo: #eef2f3; --carta: #ffffff; --testo: #13191c; --tenue: #56636b;
  --linea: #d6dde1; --rosso: #b4271f; --ok: #276b45; --ok-fondo: #e1f1e7;
  --cambia: #9a5410; --cambia-fondo: #f8ead9; --opz: #1f4f8a; --opz-fondo: #e0eaf6;
  --display: "Oswald", "Arial Narrow", "Roboto Condensed", sans-serif;
  --corpo: "IBM Plex Sans", "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
}}
@media (prefers-color-scheme: dark) {{ :root:not([data-theme="light"]) {{
  --sfondo: #0d1214; --carta: #151c1f; --testo: #e6ecee; --tenue: #95a4ac;
  --linea: #28343a; --rosso: #e2483d; --ok: #57c287; --ok-fondo: #15301f;
  --cambia: #eaa04e; --cambia-fondo: #36250f; --opz: #7fb2f0; --opz-fondo: #142538; color-scheme: dark; }} }}
:root[data-theme="dark"] {{
  --sfondo: #0d1214; --carta: #151c1f; --testo: #e6ecee; --tenue: #95a4ac;
  --linea: #28343a; --rosso: #e2483d; --ok: #57c287; --ok-fondo: #15301f;
  --cambia: #eaa04e; --cambia-fondo: #36250f; --opz: #7fb2f0; --opz-fondo: #142538; color-scheme: dark; }}
* {{ box-sizing: border-box; }}
body {{ background: var(--sfondo); color: var(--testo); font: 16px/1.5 var(--corpo); margin: 0; }}
.guscio {{ max-width: 760px; margin: 0 auto; padding-left: max(16px, env(safe-area-inset-left, 0px)); padding-right: max(16px, env(safe-area-inset-right, 0px)); padding-block: 0 48px; }}
.barra {{ position: sticky; top: env(safe-area-inset-top, 0px); z-index: 5; background: var(--sfondo); border-bottom: 1px solid var(--linea); padding-block: 12px 10px; }}
.barra h1 {{ font: 600 22px/1.15 var(--display); letter-spacing: .02em; margin: 0; text-wrap: balance; }}
.conta {{ display: flex; justify-content: space-between; gap: 12px; color: var(--tenue); font-size: 14px; margin-top: 4px; font-variant-numeric: tabular-nums; }}
.progresso {{ height: 6px; background: var(--linea); border-radius: 3px; margin-top: 8px; overflow: hidden; }}
.progresso span {{ display: block; height: 100%; width: 0; background: var(--rosso); transition: width .3s; }}
.intro {{ color: var(--tenue); margin: 18px 0 8px; }}
.avviso {{ background: var(--cambia-fondo); color: var(--cambia); padding: 10px 12px; border-radius: 6px; margin: 12px 0; }}
.sezione {{ margin-top: 28px; display: grid; gap: 14px; }}
.sez-testa {{ display: flex; flex-wrap: wrap; align-items: baseline; justify-content: space-between; gap: 8px; border-bottom: 2px solid var(--rosso); padding-bottom: 6px; }}
.sez-testa h2 {{ font: 600 19px/1.2 var(--display); text-transform: uppercase; letter-spacing: .06em; margin: 0; text-wrap: balance; }}
.bt-sez {{ font: 500 13px var(--corpo); color: var(--ok); background: none; border: 1px solid var(--ok); border-radius: 999px; padding: 5px 12px; cursor: pointer; }}
.voce {{ background: var(--carta); border: 1px solid var(--linea); border-radius: 8px; padding: 14px; display: grid; gap: 10px; min-width: 0; }}
.voce-testa {{ display: flex; justify-content: space-between; align-items: baseline; gap: 10px; }}
.voce h3 {{ font: 600 17px/1.3 var(--corpo); margin: 0; text-wrap: balance; }}
.voce p {{ margin: 0; max-width: 65ch; }}
.stato {{ font-size: 12px; font-weight: 600; letter-spacing: .04em; text-transform: uppercase; padding: 2px 8px; border-radius: 999px; white-space: nowrap; color: var(--tenue); border: 1px solid var(--linea); }}
.stato[data-stato="ok"] {{ color: var(--ok); background: var(--ok-fondo); border-color: transparent; }}
.stato[data-stato="cambia"] {{ color: var(--cambia); background: var(--cambia-fondo); border-color: transparent; }}
.stato[data-stato="opz"] {{ color: var(--opz); background: var(--opz-fondo); border-color: transparent; }}
figure {{ margin: 0; display: grid; gap: 4px; min-width: 0; }}
figcaption {{ font-size: 13px; color: var(--tenue); }}
.foto {{ width: 100%; max-width: 100%; height: auto; border-radius: 6px; display: block; cursor: zoom-in; background: var(--linea); }}
audio {{ width: 100%; }}
video {{ width: 100%; max-width: 100%; height: auto; aspect-ratio: 16 / 9; border-radius: 6px; display: block; background: #000; }}
.scelte {{ display: grid; grid-template-columns: repeat(var(--n), minmax(0, 1fr)); gap: 8px; }}
.bt {{ font: 600 15px/1.25 var(--corpo); padding: 11px 8px; border-radius: 6px; border: 1.5px solid var(--linea); background: var(--carta); color: var(--testo); cursor: pointer; }}
.bt.ok[aria-pressed="true"] {{ background: var(--ok); border-color: var(--ok); color: var(--carta); }}
.bt.cambia[aria-pressed="true"] {{ background: var(--cambia); border-color: var(--cambia); color: var(--carta); }}
.bt.opz[aria-pressed="true"] {{ background: var(--opz); border-color: var(--opz); color: var(--carta); }}
.bt:focus-visible, .bt-sez:focus-visible, .nota:focus-visible {{ outline: 2px solid var(--rosso); outline-offset: 2px; }}
.nota-etichetta {{ font-size: 13px; color: var(--tenue); margin-bottom: -6px; }}
.nota {{ width: 100%; font: 15px/1.4 var(--corpo); color: var(--testo); background: var(--sfondo); border: 1px solid var(--linea); border-radius: 6px; padding: 8px 10px; resize: vertical; }}
.gia {{ margin-top: 32px; color: var(--tenue); }}
.gia h2 {{ font: 600 17px var(--display); text-transform: uppercase; letter-spacing: .06em; color: var(--testo); margin: 0 0 6px; }}
.gia ul {{ margin: 0; padding-left: 20px; }}
.fine {{ margin-top: 28px; padding: 14px; border: 1px dashed var(--linea); border-radius: 8px; }}
.lente {{ position: fixed; inset: 0; z-index: 20; background: rgba(0,0,0,.92); display: flex; align-items: center; justify-content: center; padding: max(12px, env(safe-area-inset-top, 0px)) max(12px, env(safe-area-inset-right, 0px)) max(12px, env(safe-area-inset-bottom, 0px)) max(12px, env(safe-area-inset-left, 0px)); cursor: zoom-out; }}
.lente img {{ max-width: 100%; max-height: 100%; object-fit: contain; }}
[hidden] {{ display: none !important; }}
@media (prefers-reduced-motion: reduce) {{ .progresso span {{ transition: none; }} }}
</style>

<div class="guscio">
  <div class="barra">
    <h1>{esc(TITOLO)}</h1>
    <div class="conta"><span id="conta">0 di {len(ids)} risposte</span><span id="salvataggio">Pronto</span></div>
    <div class="progresso"><span id="barra"></span></div>
  </div>
  <p class="intro">{INTRO}</p>
  <div class="avviso" id="avviso" hidden>In questa vista le risposte restano solo su questo dispositivo. Aprila dal link nell'app Claude per farmele arrivare.</div>
  {"".join(parti)}
  {('<section class="gia"><h2>Già corretti</h2><ul>' + "".join(f"<li>{esc(t)}</li>" for t in CORRETTI) + '</ul></section>') if CORRETTI else ''}
  <div class="fine">Quando hai finito, scrivimi "fatto" in chat. Metto nel gioco solo quello che hai approvato o scelto; quello che segni "Da cambiare" lo rifaccio e te lo rimostro.</div>
</div>
<div class="lente" id="lente" hidden><img id="lente-img" alt=""></div>

<script>
const IDS = {json.dumps(ids)};
const ETICHETTE = {json.dumps(etichette, ensure_ascii=False)};
const stato = {{}};          // id -> {{stato, nota}}
let db = null;
const coda = {{}};           // una scrittura alla volta per voce
const attese = {{}};         // nota: un salvataggio per pausa di digitazione

function leggiLocale() {{ try {{ return JSON.parse(localStorage.getItem({json.dumps(CHIAVE)}) || "{{}}"); }} catch (e) {{ return {{}}; }} }}
function scriviLocale() {{ try {{ localStorage.setItem({json.dumps(CHIAVE)}, JSON.stringify(stato)); }} catch (e) {{}} }}

function disegna(id) {{
  const v = document.getElementById("voce-" + id); if (!v) return;
  const s = stato[id] || {{}};
  v.querySelectorAll(".bt").forEach(b => b.setAttribute("aria-pressed", s.stato && s.stato === b.dataset.scelta ? "true" : "false"));
  const chip = v.querySelector(".stato");
  chip.dataset.stato = !s.stato ? "" : (s.stato === "ok" || s.stato === "cambia") ? s.stato : "opz";
  chip.textContent = !s.stato ? "Da rispondere" : s.stato === "ok" ? "Approvato" : s.stato === "cambia" ? "Da cambiare" : (ETICHETTE[id][s.stato] || s.stato);
  const nota = v.querySelector(".nota");
  if (document.activeElement !== nota && typeof s.nota === "string" && nota.value !== s.nota) nota.value = s.nota;
}}
function contatore() {{
  const n = IDS.filter(id => stato[id] && stato[id].stato).length;
  document.getElementById("conta").textContent = n + " di " + IDS.length + " risposte";
  document.getElementById("barra").style.width = (100 * n / IDS.length) + "%";
}}
function tutto() {{ IDS.forEach(disegna); contatore(); }}
function segnale(t) {{ document.getElementById("salvataggio").textContent = t; }}

async function salva(id) {{
  scriviLocale();
  if (!db) return;
  const prima = coda[id] || Promise.resolve();
  coda[id] = prima.then(async () => {{
    const s = stato[id] || {{}};
    segnale("Salvo…");
    try {{
      await db.doc("risposte/" + id).set({{ stato: s.stato || "", nota: s.nota || "", quando: new Date().toISOString() }});
      segnale("Salvato");
    }} catch (e) {{
      segnale(e && e.code === "quota_exceeded" ? "Spazio pieno: non salvato" : "Non salvato, riprova");
    }}
  }});
  return coda[id];
}}

function scegli(id, scelta) {{
  const s = stato[id] = stato[id] || {{}};
  s.stato = s.stato === scelta ? "" : scelta;
  disegna(id); contatore(); salva(id);
}}

document.addEventListener("click", ev => {{
  const b = ev.target.closest(".bt");
  if (b) {{ scegli(b.closest(".voce").dataset.id, b.dataset.scelta); return; }}
  const t = ev.target.closest(".bt-sez");
  if (t) {{
    t.closest(".sezione").querySelectorAll(".voce").forEach(v => {{
      const id = v.dataset.id;
      if (!v.querySelector('.bt[data-scelta="ok"]')) return;
      if (!(stato[id] && stato[id].stato)) {{ stato[id] = Object.assign(stato[id] || {{}}, {{ stato: "ok" }}); disegna(id); salva(id); }}
    }});
    contatore(); return;
  }}
  const f = ev.target.closest(".foto");
  if (f) {{ document.getElementById("lente-img").src = f.src; document.getElementById("lente").hidden = false; return; }}
  if (ev.target.closest("#lente")) document.getElementById("lente").hidden = true;
}});
document.addEventListener("keydown", ev => {{ if (ev.key === "Escape") document.getElementById("lente").hidden = true; }});
document.addEventListener("input", ev => {{
  const n = ev.target.closest(".nota"); if (!n) return;
  const id = n.closest(".voce").dataset.id;
  stato[id] = stato[id] || {{}}; stato[id].nota = n.value;
  clearTimeout(attese[id]); attese[id] = setTimeout(() => salva(id), 900);
}});

Object.assign(stato, leggiLocale()); tutto();

(async () => {{
  try {{ db = window.claude && window.claude.use ? await window.claude.use("db") : null; }} catch (e) {{ db = null; }}
  if (!db) {{ document.getElementById("avviso").hidden = false; return; }}
  db.collection("risposte").onSnapshot(snap => {{
    snap.docs.forEach(d => {{
      const x = d.data() || {{}};
      if (!attese[d.id] || !stato[d.id]) stato[d.id] = {{ stato: x.stato || "", nota: x.nota || "" }};
    }});
    tutto(); scriviLocale();
  }}, () => {{ document.getElementById("avviso").hidden = false; }});
}})();
</script>
'''
open(OUT, "w").write(PAGINA)
print(OUT, round(os.path.getsize(OUT) / 1e6, 2), "MB", len(ids), "voci")
