# Sala principale in .gltf con texture condivise (per la 0.2.1)

Copia dei GLB di `../glb/sala/` (non toccati), convertiti senza Blender con `tools/blender/glb_in_gltf.py` e poi `tools/blender/gltf_condividi.py`. Stessi nodi, collisioni, luci ed extras: verificato in Godot 4.7.2, con conteggi di mesh, corpi statici, luci e nodi identici file per file. Le 176 immagini diventano 101 file unici in `texture/`: 68 MB invece di 141 (i PNG senza alfa sono diventati JPG). Si usa lo stesso import script (`../godot/ambiente_post_import.gd`). `sala_dati.json` resta in `../glb/sala/`.
