"""Fogli del collaudo del menu F9 col mouse. Uso: fogli_menu_f9.py <cartella menuf9>"""
import glob, os, sys
from PIL import Image, ImageDraw, ImageFont
M = sys.argv[1]
F, B = os.path.join(M, 'scatti_fix'), os.path.join(M, 'scatti_base')
O = os.path.join(M, 'fogli'); os.makedirs(O, exist_ok=True)
FONT = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 15)
TW, BAR = 426, 22
def casella(p, t):
    im = Image.open(p).convert('RGB'); h = round(im.height * TW / im.width)
    o = Image.new('RGB', (TW, h + BAR), (20, 20, 20)); o.paste(im.resize((TW, h), Image.LANCZOS), (0, BAR))
    ImageDraw.Draw(o).text((5, 3), t, font=FONT, fill=(235, 235, 235)); return o
def griglia(c, col, nome):
    c = [x for x in c if x]
    r = [c[i:i + col] for i in range(0, len(c), col)]
    W = max(sum(x.width for x in rr) for rr in r); H = sum(max(x.height for x in rr) for rr in r)
    o = Image.new('RGB', (W, H), (20, 20, 20)); y = 0
    for rr in r:
        x = 0
        for cc in rr:
            o.paste(cc, (x, y)); x += cc.width
        y += max(cc.height for cc in rr)
    o.save(os.path.join(O, nome), quality=88); print('foglio', nome, o.size)
def c(d, n, t):
    p = os.path.join(d, n + '.jpg')
    return casella(p, t) if os.path.exists(p) else None
# 1: le partenze col clic del mouse
g = [c(F, 'parti_fiume_titolo', 'il titolo, cartella utente vuota'), c(F, 'parti_fiume_f9_aperto', 'F9: il menu di prova sopra il titolo')]
for caso, id, t in [('pannelli', 'inizio', 'Inizio: lo spot VHS'), ('parti_risalita', 'risalita', 'Risalita: caricamento'),
                    ('parti_fiume', 'fiume', 'Fiume lento: caricamento'), ('parti_torre', 'torre', 'Torre: caricamento'),
                    ('parti_inseguimento', 'inseguimento', 'Inseguimento: caricamento'), ('parti_tunnel', 'tunnel', 'Tunnel: caricamento')]:
    g.append(c(F, f'{caso}_clic_{id}_dopo', 'clic su ' + t))
griglia(g, 4, '1_partenze_col_mouse.jpg')
# 2: la dissolvenza dopo il clic su Tunnel, fotogramma per fotogramma
fs = sorted(glob.glob(os.path.join(F, 'parti_tunnel_clic_tunnel_dissolvenza_*.jpg')), key=lambda f: int(os.path.basename(f).split('_')[5]))
g = []
for f in fs:
    b = os.path.basename(f)[:-4].split('_')
    ms, op = b[-2] if b[-1].startswith('op') else b[-3], [x for x in b if x.startswith('op')]
    menu = 'con il menu' if b[-1] == 'menu' else 'senza menu'
    g.append(casella(f, '%s ms dopo il clic, nero %s%%, %s' % (int(b[b.index('ms') - 1]), op[0][2:] if op else '?', menu)))
g.append(c(F, 'parti_tunnel_clic_tunnel_dopo', 'poi: la schermata di caricamento'))
griglia(g, 3, '2_dissolvenza_dopo_il_clic.jpg')
# 3: gli altri pannelli del titolo
g = [c(F, 'pannelli_opzioni_scheda_%d' % i, 'Opzioni, scheda %d (clic)' % (i + 1)) for i in range(7)]
g += [c(F, 'pannelli_calibrazione', 'calibrazione della luminosità'), c(F, 'pannelli_comandi', 'Comandi (clic)'),
      c(F, 'salvataggio_titolo', 'col salvataggio: c\'è Continua'), c(F, 'salvataggio_domanda_nuova_partita', 'Nuova partita: la domanda'),
      c(F, 'salvataggio_domanda_da_f9', 'Inizio dal menu F9: la stessa domanda'), c(F, 'continua_continua_caricamento', 'Continua: caricamento')]
griglia(g, 4, '3_altri_pannelli.jpg')
# 4: tastiera, joypad, inglese
g = [c(F, 'tastiera_f9_aperto', 'tastiera: F9, fuoco sulla prima voce'), c(F, 'tastiera_tastiera_su_fiume', 'frecce fino a Fiume lento'),
     c(F, 'tastiera_invio_fiume_dopo', 'Invio: caricamento del fiume'), c(F, 'joypad_joypad_su_torre', 'joypad: croce fino a Torre'),
     c(F, 'joypad_a_torre_dopo', 'A: caricamento della torre'), c(F, 'inglese_menu_f9_mouse_sopra', 'in inglese: il menu F9'),
     c(F, 'inglese_opzioni_scheda_0', 'in inglese: Opzioni'), c(F, 'inglese_calibrazione', 'in inglese: la calibrazione'),
     c(F, 'inglese_clic_tunnel_dopo', 'in inglese: clic su Tunnel, caricamento')]
griglia(g, 3, '4_tastiera_joypad_inglese.jpg')
# 5: la base senza correzione
g = [c(B, 'parti_risalita_f9_aperto', 'senza correzione (main): F9'), c(B, 'controllo_controllo_dopo_clic', 'senza correzione: dopo il clic su Risalita (non parte)')]
griglia(g, 2, '5_senza_correzione.jpg')
