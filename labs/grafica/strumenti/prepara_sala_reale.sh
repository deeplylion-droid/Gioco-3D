#!/usr/bin/env bash
# Copia i GLB veri della sala (assets_src/ambiente/glb/sala) in labs/grafica/sala_reale/glb/
# (copie locali, non versionate) e li importa con lo script di post-import dell'ambiente.
# Rilanciare quando cambiano i GLB in main.
set -euo pipefail
cd "$(dirname "$0")/.."
SRC=../../assets_src/ambiente
mkdir -p sala_reale/glb
cp -u "$SRC"/glb/sala/*.glb "$SRC"/glb/sala/sala_dati.json sala_reale/glb/
cp -u "$SRC"/godot/ambiente_post_import.gd "$SRC"/godot/sala_luci_ambiente.gd sala_reale/glb/
# La medusa del gioco (statua sul monumento), con i materiali di campana e tentacoli.
mkdir -p sala_reale/glb/medusa
cp -u ../../assets_src/medusa/medusa.glb ../../assets_src/medusa/godot/* sala_reale/glb/medusa/
# Primo import per creare i file .import, poi imposta lo script di post-import e la UV2 per i lightmap.
godot --headless --path . --import >/dev/null 2>&1 || true
for f in sala_reale/glb/sala_*.glb.import; do
  grep -q 'import_script/path="res://sala_reale' "$f" && continue   # già impostato
  touch "${f%.import}"
  sed -i 's#^import_script/path=.*#import_script/path="res://sala_reale/glb/ambiente_post_import.gd"#' "$f"
  sed -i 's#^meshes/light_baking=.*#meshes/light_baking=2#' "$f"
  sed -i 's#^meshes/lightmap_texel_size=.*#meshes/lightmap_texel_size=0.25#' "$f"
done
# Le texture usate dai .tres della medusa: l'import senza editor non le riconosce come 3D
# (niente mipmap) e le vene dei tentacoli escono bianche.
for f in sala_reale/glb/medusa/*.png.import sala_reale/glb/medusa/*.jpg.import; do
  sed -i 's#^mipmaps/generate=false#mipmaps/generate=true#; s#^compress/mode=0#compress/mode=2#' "$f"
done
godot --headless --path . --import >/dev/null 2>&1 || true
echo "sala reale importata in sala_reale/glb/"
