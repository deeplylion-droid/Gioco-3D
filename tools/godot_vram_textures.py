#!/usr/bin/env python3
"""Mette in compressione VRAM le texture che Godot estrae dai GLB.

Quando Godot importa un GLB senza editor (per esempio in CI con --import) salva le texture
incorporate accanto al GLB, ma con compress/mode=0 (senza perdita): la conversione in VRAM la
farebbe l'editor solo la prima volta che le vede usate in 3D. Così il gioco userebbe molta più
memoria. Questo script cambia le loro impostazioni (VRAM, e normal map per le *_nrm/normal);
poi basta rilanciare l'importazione.

Uso: python3 tools/godot_vram_textures.py godot   (poi: godot --headless --path godot --import)
"""
import os
import sys


def main(root: str) -> int:
    changed = 0
    for d, _dirs, files in os.walk(os.path.join(root, "assets")):
        glbs = [f[:-4] for f in files if f.endswith(".glb") or f.endswith(".gltf")]
        if not glbs:
            continue
        for f in files:
            if not (f.endswith(".png.import") or f.endswith(".jpg.import")):
                continue
            # Solo le texture estratte: il nome comincia con quello di un GLB della cartella.
            if not any(f.startswith(g + "_") for g in glbs):
                continue
            p = os.path.join(d, f)
            with open(p, encoding="utf-8") as fh:
                s = fh.read()
            s2 = s.replace("compress/mode=0", "compress/mode=2")
            low = f.lower()
            if "_nrm" in low or "normal" in low:
                s2 = s2.replace("compress/normal_map=0", "compress/normal_map=1")
            if s2 != s:
                with open(p, "w", encoding="utf-8") as fh:
                    fh.write(s2)
                changed += 1
    print(f"texture estratte passate in VRAM: {changed}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "godot"))
