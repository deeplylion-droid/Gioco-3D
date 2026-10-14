#!/usr/bin/env bash
# Prepara una sessione cloud nuova: Vulkan software, Xvfb, Godot 4.7.2 e venv di Blender (bpy).
set -euo pipefail
GODOT_VER=4.7.2
if ! dpkg -s mesa-vulkan-drivers >/dev/null 2>&1 || ! command -v xvfb-run >/dev/null; then
  apt-get install -y -q mesa-vulkan-drivers vulkan-tools xvfb >/dev/null 2>&1 || {
    apt-get update -q >/dev/null 2>&1 && apt-get install -y -q mesa-vulkan-drivers vulkan-tools xvfb >/dev/null; }
fi
if ! command -v godot >/dev/null || ! godot --version 2>/dev/null | grep -q "^${GODOT_VER}"; then
  mkdir -p /home/user/tools/godot && cd /home/user/tools/godot
  curl -sSL -o godot.zip "https://downloads.godotengine.org/?version=${GODOT_VER}&flavor=stable&slug=linux.x86_64.zip&platform=linux.64"
  python3 -c "import zipfile; zipfile.ZipFile('godot.zip').extractall('.')" && rm godot.zip
  chmod +x "Godot_v${GODOT_VER}-stable_linux.x86_64"
  ln -sf "/home/user/tools/godot/Godot_v${GODOT_VER}-stable_linux.x86_64" /usr/local/bin/godot
fi
if [ ! -x /home/user/tools/blender-venv/bin/python ]; then
  python3 -m venv /home/user/tools/blender-venv
  /home/user/tools/blender-venv/bin/pip install -q bpy pillow opencv-python-headless scipy
fi
godot --version
/home/user/tools/blender-venv/bin/python -c "import bpy; print('Blender', bpy.app.version_string)"
