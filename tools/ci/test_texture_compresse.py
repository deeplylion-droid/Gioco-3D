#!/usr/bin/env python3
"""Test di tools/ci/texture_compresse.py: in un progetto finto, una texture nuova Lossless o senza mipmap fa fallire il
controllo; una VRAM con le mipmap, una nell'elenco delle eccezioni (col motivo) e una tolta dal pacchetto no; una riga
dell'elenco senza motivo lo fa fallire.

Uso: python3 tools/ci/test_texture_compresse.py
"""
import contextlib
import io
import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import texture_compresse  # noqa: E402

PRESETS = '[preset.0]\nexclude_filter="tests/*, proposte/*"\n[preset.1]\nexclude_filter="tests/*, proposte/*"\n'


def _import(modo: int, mip: bool, importer: str = "texture") -> str:
    return (f'[remap]\n\nimporter="{importer}"\ntype="CompressedTexture2D"\n\n[params]\n\n'
            f"compress/mode={modo}\nmipmaps/generate={'true' if mip else 'false'}\n")


def _prova(file: dict, elenco: str = "") -> int:
    with tempfile.TemporaryDirectory() as d:
        with open(os.path.join(d, "export_presets.cfg"), "w") as f:
            f.write(PRESETS)
        for nome, testo in file.items():
            p = os.path.join(d, nome)
            os.makedirs(os.path.dirname(p), exist_ok=True)
            with open(p, "w") as f:
                f.write(testo)
        e = os.path.join(d, "eccezioni.txt")
        with open(e, "w") as f:
            f.write(elenco)
        with contextlib.redirect_stdout(io.StringIO()):
            return texture_compresse.controlla(d, e)


ok = 0
falliti = 0


def controlla(cond: bool, cosa: str) -> None:
    global ok, falliti
    if cond:
        ok += 1
        print("  ok      " + cosa)
    else:
        falliti += 1
        print("  FALLITO " + cosa)


buona = {"assets/muro.png.import": _import(2, True)}
controlla(_prova(buona) == 0, "una texture VRAM con le mipmap passa")
controlla(_prova({**buona, "assets/nuova.png.import": _import(0, False)}) == 1, "una texture nuova Lossless senza mipmap fa fallire")
controlla(_prova({**buona, "assets/nuova.png.import": _import(1, True)}) == 1, "una Lossy fa fallire")
controlla(_prova({**buona, "assets/nuova.png.import": _import(4, True)}) == 1, "una Basis fa fallire")
controlla(_prova({**buona, "assets/nuova.png.import": _import(2, False)}) == 1, "una VRAM senza mipmap fa fallire")
controlla(_prova({**buona, "proposte/prova.png.import": _import(0, False)}) == 0, "una tolta dal pacchetto (exclude_filter) non conta")
controlla(_prova({**buona, "assets/scritta.png.import": _import(0, False)},
                 "res://assets/scritta.png | scritta a schermo\n") == 0, "una nell'elenco delle eccezioni col motivo passa")
controlla(_prova({**buona, "assets/scritta.png.import": _import(0, False)}, "res://assets/scritta.png\n") == 1,
          "una riga dell'elenco senza motivo fa fallire")
controlla(_prova({**buona, "assets/suono.wav.import": _import(0, False, "wav")}) == 0, "gli altri import non contano")
print("RISULTATO: %d controlli ok, %d falliti" % (ok, falliti))
sys.exit(1 if falliti else 0)
