#!/usr/bin/env bash
# Prepara la prova dell'acqua nella sala vera: copia da un ramo (di serie origin/main) i GLB della
# sala principale e gli script dell'ambiente in labs/acqua/sala_main/ (cartella non versionata),
# poi importa. Uso: bash labs/acqua/tools/prepara_sala_vera.sh [ramo]
set -euo pipefail
REF="${1:-origin/main}"
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
DST="$ROOT/labs/acqua/sala_main"
mkdir -p "$DST"
for g in sala_acqua sala_architettura sala_area_bimbi sala_cupola sala_interattivi sala_luci sala_piscina sala_torre_scivoli; do
  git -C "$ROOT" show "$REF:assets_src/ambiente/glb/sala/$g.glb" > "$DST/$g.glb"
done
git -C "$ROOT" show "$REF:assets_src/ambiente/glb/sala/sala_dati.json" > "$DST/sala_dati.json"
git -C "$ROOT" show "$REF:assets_src/ambiente/godot/sala_luci_ambiente.gd" > "$DST/sala_luci_ambiente.gd"
git -C "$ROOT" show "$REF:assets_src/ambiente/godot/ambiente_post_import.gd" > "$DST/ambiente_post_import.gd"
# prima importazione (crea i .import), poi lo script di post-import sui GLB e una seconda importazione
godot --headless --path "$ROOT/labs/acqua" --import >/dev/null 2>&1 || true
for f in "$DST"/*.glb.import; do
  sed -i 's|^import_script/path=.*|import_script/path="res://sala_main/ambiente_post_import.gd"|' "$f"
done
godot --headless --path "$ROOT/labs/acqua" --import >/dev/null 2>&1 || true
echo "pronto: res://tests/sala_vera/test_sala_vera.tscn"
