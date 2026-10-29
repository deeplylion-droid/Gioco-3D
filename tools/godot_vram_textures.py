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

# Cartelle di texture dei modelli 3D (anche non estratte, per esempio quelle condivise dei .gltf)
# con il loro lato massimo: i dettagli piccoli non servono a 2K.
# 0 = nessun limite.
TEXTURE_3D = {
    os.path.join("assets", "ambiente", "dettagli"): 1024,
    os.path.join("assets", "models", "medusa"): 0,
}


# Texture estratte dai GLB con un lato massimo per tipo (parte del nome): nella sala i materiali sono
# ripetuti su superfici grandi e ogni GLB ne estrae la sua copia; a 1024 le normal map e le ORM non si
# distinguono da quelle a 2048 (il colore resta a 2048) e il pacchetto del gioco scende di circa 180 MB.
LIMITI_ESTRATTE = {
    os.path.join("assets", "ambiente", "sala"): {"_nrm.": 1024, "_orm.": 1024},
}


def _limite_estratta(root: str, d: str, nome: str):
    regole = LIMITI_ESTRATTE.get(os.path.relpath(d, root))
    if not regole:
        return None
    for parte, lato in regole.items():
        if parte in nome.lower():
            return lato
    return None


def _in_3d_folder(root: str, d: str):
    rel = os.path.relpath(d, root)
    for folder, limit in TEXTURE_3D.items():
        if rel == folder or rel.startswith(folder + os.sep):
            return limit
    return None


def main(root: str) -> int:
    changed = 0
    for d, _dirs, files in os.walk(os.path.join(root, "assets")):
        glbs = [f.rsplit(".", 1)[0] for f in files if f.endswith(".glb") or f.endswith(".gltf")]
        limit = _in_3d_folder(root, d)
        if not glbs and limit is None:
            continue
        for f in files:
            if not (f.endswith(".png.import") or f.endswith(".jpg.import")):
                continue
            # Le texture estratte (il nome comincia con quello di un GLB della cartella) e tutte
            # quelle delle cartelle di texture 3D.
            if limit is None and not any(f.startswith(g + "_") for g in glbs):
                continue
            p = os.path.join(d, f)
            with open(p, encoding="utf-8") as fh:
                s = fh.read()
            s2 = s.replace("compress/mode=0", "compress/mode=2")
            low = f.lower()
            if "_nrm" in low or "normal" in low:
                s2 = s2.replace("compress/normal_map=0", "compress/normal_map=1")
            lato = _limite_estratta(root, d, f)
            if lato:
                s2 = s2.replace("process/size_limit=0", f"process/size_limit={lato}")
            if limit is not None and limit > 0:
                s2 = s2.replace("process/size_limit=0", f"process/size_limit={limit}")
            # (anche le estratte: una restava senza, sala_vasca_centrale_acciaio_inox_orm, e il controllo della CI
            # tools/ci/texture_compresse.py le vuole tutte con le mipmap)
            s2 = s2.replace("mipmaps/generate=false", "mipmaps/generate=true")
            if s2 != s:
                with open(p, "w", encoding="utf-8") as fh:
                    fh.write(s2)
                changed += 1
    print(f"texture estratte passate in VRAM: {changed}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "godot"))
