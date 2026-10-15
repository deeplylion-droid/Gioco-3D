#!/usr/bin/env python3
"""Piedistallo della statua per la schermata del titolo.

Copia dai GLB della sala solo il piedistallo (`amb_piedistallo`, da sala_architettura.glb), il
pulsante rosso dei bambini (`sala_pulsante_piedistallo`, da sala_interattivi.glb) e le pozzanghere
vicine (`sala_pozzanghere`), e ci aggiunge un pavimento rotondo con il materiale e le texture del
pavimento della sala (stessa scala), che si scurisce verso il bordo e sparisce nel buio.
Tutto in un GLB piccolo, con le texture ridotte a 1024 px e il centro della base del piedistallo
nell'origine (piano superiore a y = 0,90 m): così il titolo non deve caricare tutta l'architettura
della sala. Le collisioni non servono e restano fuori. In Godot il GLB usa lo stesso script di
importazione dell'ambiente.

Uso, dalla radice del repository:  python3 -I assets_src/menu/estrai_piedistallo.py
"""
import io
import json
import math
import os
import struct
import sys

from PIL import Image

RADICE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ARCHITETTURA = "assets_src/ambiente/glb/sala/sala_architettura.glb"
INTERATTIVI = "assets_src/ambiente/glb/sala/sala_interattivi.glb"
CENTRO = (0.0, 0.0, 6.9)  # centro della base del piedistallo nella sala (coordinate Godot)
LATO_TEXTURE = 1024
USCITA = "godot/assets/menu/piedistallo.glb"

# Pavimento rotondo intorno al piedistallo (coordinate della sala, in metri).
PAVIMENTO_RAGGIO = 17.0
PAVIMENTO_PASSO = 0.5
PAVIMENTO_SFUMA = (8.0, 15.5)   # da qui il colore scende fino quasi al nero
PAVIMENTO_UV = 1.5              # come nella sala: una ripetizione della texture ogni 1,5 m
POZZANGHERE_RAGGIO = 9.0

GLB_MAGIC = 0x46546C67
CHUNK_JSON = 0x4E4F534A
CHUNK_BIN = 0x004E4942
FLOAT, UINT16, UINT32 = 5126, 5123, 5125
ARRAY_BUFFER, ELEMENT_ARRAY_BUFFER = 34962, 34963
TIPI = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}
FORMATI = {5126: "f", 5125: "I", 5123: "H", 5121: "B"}


def leggi_glb(percorso):
    with open(os.path.join(RADICE, percorso), "rb") as f:
        dati = f.read()
    magic, _versione, lunghezza = struct.unpack_from("<III", dati, 0)
    if magic != GLB_MAGIC:
        raise ValueError(f"{percorso} non è un GLB")
    off, js, binario = 12, None, b""
    while off < lunghezza:
        clen, ctipo = struct.unpack_from("<II", dati, off)
        off += 8
        if ctipo == CHUNK_JSON:
            js = json.loads(dati[off:off + clen])
        elif ctipo == CHUNK_BIN:
            binario = dati[off:off + clen]
        off += clen
    return js, binario


def leggi_accessore(sj, sb, i):
    a = sj["accessors"][i]
    v = sj["bufferViews"][a["bufferView"]]
    n = TIPI[a["type"]]
    fmt = FORMATI[a["componentType"]]
    passo = v.get("byteStride", struct.calcsize(fmt) * n)
    o = v.get("byteOffset", 0) + a.get("byteOffset", 0)
    return [struct.unpack_from("<" + fmt * n, sb, o + k * passo) for k in range(a["count"])]


def rumore(x, z):
    """Macchie morbide e deterministiche per lo sporco del pavimento (0..1)."""
    v = (math.sin(x * 0.73 + z * 0.21) * math.sin(z * 0.61 - x * 0.17) * 0.5
         + math.sin(x * 1.9 + 1.3) * math.sin(z * 2.3 + 0.4) * 0.3
         + math.sin((x + z) * 4.1) * 0.2)
    return 0.5 + 0.5 * max(-1.0, min(1.0, v))


class Costruttore:
    def __init__(self):
        self.js = {
            "asset": {"version": "2.0", "generator": "assets_src/menu/estrai_piedistallo.py"},
            "scene": 0,
            "scenes": [{"name": "Piedistallo", "nodes": [0]}],
            "nodes": [{"name": "Sala", "translation": [-c for c in CENTRO], "children": []}],
            "meshes": [], "materials": [], "textures": [], "images": [], "samplers": [],
            "accessors": [], "bufferViews": [], "buffers": [],
        }
        self.binario = bytearray()
        self.estensioni = set()
        self._sorgenti = {}

    # --- dati grezzi -------------------------------------------------------------------------

    def _vista(self, dati, **extra):
        while len(self.binario) % 4:
            self.binario.append(0)
        vista = {"buffer": 0, "byteOffset": len(self.binario), "byteLength": len(dati)}
        vista.update(extra)
        self.binario += dati
        self.js["bufferViews"].append(vista)
        return len(self.js["bufferViews"]) - 1

    def accessore_nuovo(self, valori, tipo, componente, indici=False):
        n = TIPI[tipo]
        fmt = FORMATI[componente]
        piatti = [c for v in valori for c in (v if n > 1 else (v,))]
        dati = struct.pack("<" + fmt * len(piatti), *piatti)
        a = {"bufferView": self._vista(dati, target=ELEMENT_ARRAY_BUFFER if indici else ARRAY_BUFFER),
             "componentType": componente, "count": len(valori), "type": tipo}
        if tipo == "VEC3" and not indici and componente == FLOAT:
            a["min"] = [min(v[k] for v in valori) for k in range(3)]
            a["max"] = [max(v[k] for v in valori) for k in range(3)]
        self.js["accessors"].append(a)
        return len(self.js["accessors"]) - 1

    def nodo(self, nome, mesh, **trasformazione):
        self.js["nodes"].append({"name": nome, "mesh": mesh, **trasformazione})
        self.js["nodes"][0]["children"].append(len(self.js["nodes"]) - 1)

    # --- copia da un GLB della sala --------------------------------------------------------------

    def sorgente(self, percorso):
        if percorso not in self._sorgenti:
            sj, sb = leggi_glb(percorso)
            mappe = {k: {} for k in ("bufferViews", "accessors", "images", "samplers", "textures", "materials")}
            self._sorgenti[percorso] = (sj, sb, mappe)
        return self._sorgenti[percorso]

    def copia_materiale(self, percorso, i):
        sj, sb, mappe = self.sorgente(percorso)

        def immagine(k):
            if k not in mappe["images"]:
                im = sj["images"][k]
                v = sj["bufferViews"][im["bufferView"]]
                o = v.get("byteOffset", 0)
                img = Image.open(io.BytesIO(sb[o:o + v["byteLength"]]))
                img.load()
                if max(img.size) > LATO_TEXTURE:
                    s = LATO_TEXTURE / max(img.size)
                    img = img.resize((round(img.width * s), round(img.height * s)), Image.LANCZOS)
                out = io.BytesIO()
                if im["mimeType"] == "image/png":
                    img.save(out, "PNG", optimize=True)
                else:
                    img.convert("RGB").save(out, "JPEG", quality=92 if "_nrm" in im["name"] else 88)
                self.js["images"].append({"name": im["name"], "mimeType": im["mimeType"],
                                          "bufferView": self._vista(out.getvalue())})
                mappe["images"][k] = len(self.js["images"]) - 1
            return mappe["images"][k]

        def texture(k):
            if k not in mappe["textures"]:
                t = dict(sj["textures"][k])
                t["source"] = immagine(t["source"])
                if "sampler" in t:
                    s = t["sampler"]
                    if s not in mappe["samplers"]:
                        self.js["samplers"].append(dict(sj["samplers"][s]))
                        mappe["samplers"][s] = len(self.js["samplers"]) - 1
                    t["sampler"] = mappe["samplers"][s]
                self.js["textures"].append(t)
                mappe["textures"][k] = len(self.js["textures"]) - 1
            return mappe["textures"][k]

        if i not in mappe["materials"]:
            m = json.loads(json.dumps(sj["materials"][i]))
            pbr = m.get("pbrMetallicRoughness", {})
            for chiave in ("baseColorTexture", "metallicRoughnessTexture"):
                if chiave in pbr:
                    pbr[chiave]["index"] = texture(pbr[chiave]["index"])
            for chiave in ("normalTexture", "occlusionTexture", "emissiveTexture"):
                if chiave in m:
                    m[chiave]["index"] = texture(m[chiave]["index"])
            self.estensioni.update(m.get("extensions", {}).keys())
            self.js["materials"].append(m)
            mappe["materials"][i] = len(self.js["materials"]) - 1
        return mappe["materials"][i]

    def copia_nodo(self, percorso, nome_nodo, tieni_triangolo=None):
        """Copia un nodo con la sua mesh (senza figli). [tieni_triangolo] filtra i triangoli
        (riceve il baricentro in coordinate della sala)."""
        sj, sb, mappe = self.sorgente(percorso)
        nodi = [n for n in sj["nodes"] if n.get("name") == nome_nodo]
        if len(nodi) != 1 or "mesh" not in nodi[0]:
            raise ValueError(f"nodo {nome_nodo} non trovato in {percorso}")

        def accessore(k):
            if k not in mappe["accessors"]:
                a = dict(sj["accessors"][k])
                if "sparse" in a:
                    raise ValueError("accessori sparse non gestiti")
                b = a["bufferView"]
                if b not in mappe["bufferViews"]:
                    v = sj["bufferViews"][b]
                    o = v.get("byteOffset", 0)
                    extra = {c: v[c] for c in ("byteStride", "target") if c in v}
                    mappe["bufferViews"][b] = self._vista(sb[o:o + v["byteLength"]], **extra)
                a["bufferView"] = mappe["bufferViews"][b]
                self.js["accessors"].append(a)
                mappe["accessors"][k] = len(self.js["accessors"]) - 1
            return mappe["accessors"][k]

        nodo = nodi[0]
        mesh = json.loads(json.dumps(sj["meshes"][nodo["mesh"]]))
        for p in mesh["primitives"]:
            indici_sorgente = p.get("indices")
            posizioni_sorgente = p["attributes"]["POSITION"]
            p["attributes"] = {k: accessore(v) for k, v in p["attributes"].items()}
            if tieni_triangolo and indici_sorgente is not None:
                pos = leggi_accessore(sj, sb, posizioni_sorgente)
                ind = [i[0] for i in leggi_accessore(sj, sb, indici_sorgente)]
                tenuti = []
                for t in range(0, len(ind), 3):
                    a, b, c = (pos[ind[t + q]] for q in range(3))
                    centro = tuple((a[q] + b[q] + c[q]) / 3.0 for q in range(3))
                    if tieni_triangolo(centro):
                        tenuti += ind[t:t + 3]
                p["indices"] = self.accessore_nuovo(tenuti, "SCALAR", UINT32 if len(pos) > 65535 else UINT16, True)
            elif indici_sorgente is not None:
                p["indices"] = accessore(indici_sorgente)
            if "material" in p:
                p["material"] = self.copia_materiale(percorso, p["material"])
            if "targets" in p:
                p["targets"] = [{k: accessore(v) for k, v in t.items()} for t in p["targets"]]
        self.js["meshes"].append(mesh)
        trasformazione = {k: nodo[k] for k in ("translation", "rotation", "scale", "matrix") if k in nodo}
        self.nodo(nome_nodo, len(self.js["meshes"]) - 1, **trasformazione)

    # --- pavimento nuovo -----------------------------------------------------------------------

    def pavimento(self):
        sj, _sb, _m = self.sorgente(ARCHITETTURA)
        nodo = next(n for n in sj["nodes"] if n.get("name") == "sala_pavimento")
        materiale = self.copia_materiale(ARCHITETTURA, sj["meshes"][nodo["mesh"]]["primitives"][0]["material"])
        n = int(round(2 * PAVIMENTO_RAGGIO / PAVIMENTO_PASSO))
        pos, nor, uv, col, mappa = [], [], [], [], {}
        for j in range(n + 1):
            for i in range(n + 1):
                dx = -PAVIMENTO_RAGGIO + i * PAVIMENTO_PASSO
                dz = -PAVIMENTO_RAGGIO + j * PAVIMENTO_PASSO
                r = math.hypot(dx, dz)
                if r > PAVIMENTO_RAGGIO + PAVIMENTO_PASSO:
                    continue
                if r > PAVIMENTO_RAGGIO:  # bordo rotondo
                    dx, dz = dx * PAVIMENTO_RAGGIO / r, dz * PAVIMENTO_RAGGIO / r
                    r = PAVIMENTO_RAGGIO
                x, z = CENTRO[0] + dx, CENTRO[2] + dz
                t = min(1.0, max(0.0, (r - PAVIMENTO_SFUMA[0]) / (PAVIMENTO_SFUMA[1] - PAVIMENTO_SFUMA[0])))
                sfuma = 1.0 - t * t * (3.0 - 2.0 * t) * 0.94
                c = (0.38 + 0.4 * rumore(x, z)) * sfuma
                mappa[(i, j)] = len(pos)
                pos.append((x, 0.0, z))
                nor.append((0.0, 1.0, 0.0))
                uv.append((x / PAVIMENTO_UV, z / PAVIMENTO_UV + 1.0))
                col.append((c, c, c))
        indici = []
        for j in range(n):
            for i in range(n):
                q = [mappa.get(k) for k in ((i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1))]
                if None in q:
                    continue
                # Faccia verso l'alto (glTF: antiorario visto da sopra).
                indici += [q[0], q[3], q[2], q[0], q[2], q[1]]
        prim = {
            "attributes": {
                "POSITION": self.accessore_nuovo(pos, "VEC3", FLOAT),
                "NORMAL": self.accessore_nuovo(nor, "VEC3", FLOAT),
                "TEXCOORD_0": self.accessore_nuovo(uv, "VEC2", FLOAT),
                "COLOR_0": self.accessore_nuovo(col, "VEC3", FLOAT),
            },
            "indices": self.accessore_nuovo(indici, "SCALAR", UINT16 if len(pos) < 65536 else UINT32, True),
            "material": materiale,
        }
        self.js["meshes"].append({"name": "pavimento_titolo", "primitives": [prim]})
        self.nodo("pavimento_titolo", len(self.js["meshes"]) - 1)

    def scrivi(self, percorso):
        while len(self.binario) % 4:
            self.binario.append(0)
        self.js["buffers"] = [{"byteLength": len(self.binario)}]
        if self.estensioni:
            self.js["extensionsUsed"] = sorted(self.estensioni)
        testo = json.dumps(self.js, separators=(",", ":")).encode("utf-8")
        while len(testo) % 4:
            testo += b" "
        totale = 12 + 8 + len(testo) + 8 + len(self.binario)
        with open(percorso, "wb") as f:
            f.write(struct.pack("<III", GLB_MAGIC, 2, totale))
            f.write(struct.pack("<II", len(testo), CHUNK_JSON))
            f.write(testo)
            f.write(struct.pack("<II", len(self.binario), CHUNK_BIN))
            f.write(self.binario)
        return totale


def main():
    c = Costruttore()
    c.copia_nodo(ARCHITETTURA, "amb_piedistallo")
    c.copia_nodo(INTERATTIVI, "sala_pulsante_piedistallo")
    c.pavimento()
    c.copia_nodo(ARCHITETTURA, "sala_pozzanghere",
                 lambda p: math.hypot(p[0] - CENTRO[0], p[2] - CENTRO[2]) < POZZANGHERE_RAGGIO)
    uscita = os.path.join(RADICE, USCITA)
    os.makedirs(os.path.dirname(uscita), exist_ok=True)
    n = c.scrivi(uscita)
    print(f"{USCITA}: {n / 1e6:.1f} MB, {len(c.js['meshes'])} mesh, {len(c.js['images'])} texture")
    return 0


if __name__ == "__main__":
    sys.exit(main())
