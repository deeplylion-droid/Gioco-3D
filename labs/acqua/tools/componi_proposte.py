#!/usr/bin/env python3
"""Compone le immagini delle proposte (screenshot di Godot) in un JPG leggibile sul telefono:
le opzioni una sotto l'altra, ognuna con una fascia e un'etichetta grande.

Uso: python3 componi_proposte.py <uscita.jpg> "<titolo>" <img1> "<etichetta1>" <img2> "<etichetta2>" ...
"""
import sys

from PIL import Image, ImageDraw, ImageFont


def font(size):
    for f in ("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
              "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"):
        try:
            return ImageFont.truetype(f, size)
        except OSError:
            pass
    return ImageFont.load_default()


def main():
    out, title = sys.argv[1], sys.argv[2]
    pairs = list(zip(sys.argv[3::2], sys.argv[4::2]))
    imgs = [Image.open(p).convert("RGB") for p, _ in pairs]
    w = 1280
    imgs = [im.resize((w, int(im.height * w / im.width)), Image.LANCZOS) for im in imgs]
    band = 92
    head = 110
    h = head + sum(im.height + band for im in imgs)
    sheet = Image.new("RGB", (w, h), (12, 12, 14))
    d = ImageDraw.Draw(sheet)
    d.text((28, 28), title, font=font(48), fill=(240, 240, 240))
    y = head
    for im, (_, label) in zip(imgs, pairs):
        d.rectangle([0, y, w, y + band], fill=(30, 30, 34))
        d.text((28, y + 18), label, font=font(52), fill=(255, 214, 90))
        y += band
        sheet.paste(im, (0, y))
        y += im.height
    sheet.save(out, quality=88)
    print("salvato", out, sheet.size)


if __name__ == "__main__":
    main()
