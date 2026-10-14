#!/usr/bin/env python3
"""Imposta le opzioni di import di Godot per le texture del laboratorio dell'acqua.
Le texture usate da ShaderMaterial creati da codice non vengono riconosciute come "3D" dall'editor,
quindi mipmap e compressione vanno impostate a mano. Uso: python3 labs/acqua/tools/imposta_import.py
poi: godot --headless --path labs/acqua --import
"""
import os, re, glob

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))

def patch(path, params, importer=None, type_=None):
    imp = path + ".import"
    if importer:
        # file nuovo: Godot completa il resto alla prossima importazione
        lines = ["[remap]", "", f'importer="{importer}"', f'type="{type_}"', "", "[params]", ""]
        lines += [f"{k}={v}" for k, v in params.items()]
        open(imp, "w").write("\n".join(lines) + "\n")
        return
    if not os.path.exists(imp):
        print("manca", imp)
        return
    s = open(imp).read()
    for k, v in params.items():
        if re.search(rf"^{re.escape(k)}=.*$", s, flags=re.M):
            s = re.sub(rf"^{re.escape(k)}=.*$", f"{k}={v}", s, flags=re.M)
        else:
            s = s.rstrip("\n") + f"\n{k}={v}\n"
    open(imp, "w").write(s)

wt = os.path.join(ROOT, "water", "textures")
for name in ("water_normal_a.png", "water_normal_b.png", "foam.png", "noise_rgba.png"):
    patch(os.path.join(wt, name), {"compress/mode": 0, "mipmaps/generate": "true", "detect_3d/compress_to": 0})
patch(os.path.join(wt, "caustics_3d.png"), {
    "compress/mode": 0, "compress/high_quality": "false", "compress/lossy_quality": 0.7,
    "compress/hdr_compression": 1, "compress/channel_pack": 1,
    "mipmaps/generate": "true", "mipmaps/limit": -1,
    "slices/horizontal": 8, "slices/vertical": 8,
}, importer="3d_texture", type_="CompressedTexture3D")

dt = os.path.join(ROOT, "demo", "textures")
for f in sorted(glob.glob(os.path.join(dt, "*.jpg"))):
    p = {"compress/mode": 2, "mipmaps/generate": "true", "detect_3d/compress_to": 0, "compress/high_quality": "false"}
    if f.endswith("_normal.jpg"):
        p["compress/normal_map"] = 1
    patch(f, p)
print("ok")
