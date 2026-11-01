#!/usr/bin/env python3
"""Controllo statico degli strati e delle maschere delle luci: in godot/ nessuno cambia layers o light_cull_mask
direttamente, solo con Strati.metti e Strati.maschera_luce (godot/addons/grafica/strati.gd).

Perché: Godot 4.7.2 (renderer_scene_cull.cpp) stacca una mesh da una luce solo se ADESSO light_cull_mask & layers
combaciano, e in Forward+ cambiare i layers di una mesh già nella scena non la stacca prima dalle luci. Se dopo il cambio
non combaciano più, la mesh resta nella lista della luce anche liberata: in debug "BUG, indexing did not unpair
geometries from light" quando si libera la luce, in release un puntatore pendente (il segfault delle ripartenze della
0.3.17 su Vulkan: il riscaldamento delle pipeline metteva layers = 0 e la morte liberava la sala a metà; pila di debug
del 31 ottobre). Strati nasconde il nodo al motore, cambia e lo rimostra: stacca e riaccoppia con le maschere giuste.

Cosa blocca, riga per riga (senza commenti e stringhe), negli script .gd e in quelli incorporati nei .tscn e .tres:
- un assegnamento a layers o a light_cull_mask (=, |=, &=, ^=, +=, -=), anche su self o dopo un cast;
- set("layers", ...), set_deferred("layers", ...) e lo stesso con light_cull_mask;
- set_layer_mask_value(...) e, sul RenderingServer, instance_set_layer_mask(...) e light_set_cull_mask(...).
Le eccezioni sono scritte sulla riga, con il perché:
- "# strati: fuori scena": un nodo nuovo prima di add_child (il motore non l'ha ancora accoppiato a niente);
- "# strati: voluto": un test che il BUG lo deve dare.
Non guarda: godot/addons/grafica/strati.gd (è lui), godot/proposte/ (prove per gli scatti, non il gioco), .godot/.
Non vede (oggi nessun caso): un nome di proprietà costruito a runtime (set(nome, ...)) e le proprietà animate da un
AnimationPlayer (tracce su layers o light_cull_mask: da guardare a mano se arrivano).
Uso: python3 tools/ci/strati_luci.py [godot]; --prova controlla il controllo su casi finti.
"""
import os
import re
import sys

PROPRIETA = r"(?:layers|light_cull_mask)"
ASSEGNA = re.compile(r"(?<![\w$])(?:[\w\]\)]\s*\.\s*)?" + PROPRIETA + r"\s*(?:[|&^+\-]?=)(?!=)")
DICHIARA = re.compile(r"\b(?:var|const)\s+" + PROPRIETA + r"\b")
PER_NOME = re.compile(r"\b(?:set|set_deferred)\s*\(\s*&?\"" + PROPRIETA + r"\"")
CHIAMATE = re.compile(r"\b(?:set_layer_mask_value|instance_set_layer_mask|light_set_cull_mask)\s*\(")
ECCEZIONE = re.compile(r"#\s*strati:\s*(?:fuori scena|voluto)\b")
SALTA_DIR = {".godot", "proposte"}
HELPER = os.path.join("addons", "grafica", "strati.gd")


def senza_stringhe_e_commenti(riga: str) -> str:
    """La riga con le stringhe vuote ("" e '') e senza il commento."""
    out = []
    i = 0
    while i < len(riga):
        c = riga[i]
        if c == "#":
            break
        if c in "\"'":
            q = c
            j = i + 1
            while j < len(riga) and riga[j] != q:
                j += 2 if riga[j] == "\\" else 1
            # set("layers" deve restare visibile: la stringa si tiene se è solo un nome di proprietà
            parola = riga[i + 1:j]
            out.append(q + (parola if re.fullmatch(PROPRIETA, parola) else "") + q)
            i = j + 1
            continue
        out.append(c)
        i += 1
    return "".join(out)


def controlla_testo(testo: str, nome: str) -> list:
    errori = []
    for n, riga in enumerate(testo.splitlines(), 1):
        if ECCEZIONE.search(riga):
            continue
        codice = senza_stringhe_e_commenti(riga)
        if DICHIARA.search(codice):
            continue
        if ASSEGNA.search(codice) or PER_NOME.search(codice) or CHIAMATE.search(codice):
            errori.append(f"{nome}:{n}: {riga.strip()}")
    return errori


def sorgenti_incorporati(testo: str) -> list:
    """Gli script incorporati di un .tscn o .tres (script/source = "..."), già senza le sequenze di escape."""
    out = []
    for m in re.finditer(r'script/source\s*=\s*"((?:[^"\\]|\\.)*)"', testo, re.S):
        out.append(m.group(1).encode().decode("unicode_escape"))
    return out


def controlla(radice: str) -> list:
    errori = []
    for cartella, dirs, files in os.walk(radice):
        rel = os.path.relpath(cartella, radice)
        dirs[:] = [d for d in dirs if d not in SALTA_DIR or rel != "."]
        for f in sorted(files):
            p = os.path.join(cartella, f)
            r = os.path.relpath(p, radice)
            if r == HELPER:
                continue
            if f.endswith(".gd"):
                errori += controlla_testo(open(p, encoding="utf-8").read(), r)
            elif f.endswith((".tscn", ".tres")):
                testo = open(p, encoding="utf-8", errors="replace").read()
                for k, s in enumerate(sorgenti_incorporati(testo)):
                    errori += controlla_testo(s, f"{r} (script incorporato {k + 1})")
    return errori


def prova() -> int:
    blocca = [
        "\tmi.layers = 0",
        "\tlayers = Tempesta.STRATO_NO_LAMPO",
        "\tself.layers |= 4",
        "\t(vi as VisualInstance3D).layers = STRATO",
        "\tnodi[0].layers &= ~2",
        "\tluce.light_cull_mask = 1 << 3",
        "\tluce3.light_cull_mask &= ~RisveglioSqualo.STRATO_SQUALO",
        "\tn.set(\"layers\", 2)",
        "\tn.set_deferred(&\"light_cull_mask\", 2)",
        "\tmi.set_layer_mask_value(3, true)",
        "\tRenderingServer.instance_set_layer_mask(rid, 0)",
        "\tRenderingServer.light_set_cull_mask(rid, 0)",
        "\tif true: mi.layers = 1  # un commento qualsiasi",
    ]
    passa = [
        "\tStrati.metti(mi, 0)",
        "\tStrati.maschera_luce(luce, luce.light_cull_mask & ~2)",
        "\tif mi.layers == 0:",
        "\tvar l := mi.layers | 2",
        "\tvar layers := 3",
        "\t# mi.layers = 0 (in un commento)",
        "\tprint(\"mi.layers = 0\")",
        "\t_mesh.layers = WATER_LAYER  # strati: fuori scena (prima di add_child)",
        "\t(m as MeshInstance3D).layers = 0  # strati: voluto (il caso che il BUG lo deve dare)",
        "\tcam.cull_mask = 1",
        "\tluce.shadow_caster_mask = 0xFFFFF & ~STRATO",
        "\tif luce.light_cull_mask != 3:",
    ]
    sbagli = 0
    for r in blocca:
        if not controlla_testo(r, "prova"):
            print("PROVA SBAGLIATA: non blocca", repr(r))
            sbagli += 1
    for r in passa:
        if controlla_testo(r, "prova"):
            print("PROVA SBAGLIATA: blocca", repr(r))
            sbagli += 1
    tscn = '[sub_resource type="GDScript" id="x"]\nscript/source = "extends MeshInstance3D\\nfunc _ready():\\n\\tlayers = 2\\n"\n'
    if not any(controlla_testo(s, "prova") for s in sorgenti_incorporati(tscn)):
        print("PROVA SBAGLIATA: non blocca lo script incorporato")
        sbagli += 1
    if sorgenti_incorporati('[node name="M" type="MeshInstance3D"]\nlayers = 2\n'):
        print("PROVA SBAGLIATA: una proprietà salvata nel .tscn presa per codice")
        sbagli += 1
    print("prova del controllo degli strati:", "ok" if sbagli == 0 else f"{sbagli} sbagli")
    return 1 if sbagli else 0


def main() -> int:
    if "--prova" in sys.argv:
        return prova()
    radice = next((a for a in sys.argv[1:] if not a.startswith("--")), "godot")
    errori = controlla(radice)
    for e in errori:
        print("STRATO CAMBIATO DIRETTAMENTE:", e)
    if errori:
        print(f"\n{len(errori)} cambi diretti di layers o light_cull_mask: usare Strati.metti o Strati.maschera_luce "
              "(godot/addons/grafica/strati.gd), o scrivere sulla riga \"# strati: fuori scena\" per un nodo prima di "
              "add_child")
        return 1
    print("strati e maschere delle luci: nessun cambio diretto")
    return 0


if __name__ == "__main__":
    sys.exit(main())
