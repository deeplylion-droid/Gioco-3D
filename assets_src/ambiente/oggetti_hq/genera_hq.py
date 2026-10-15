"""Oggetti di scena della sala principale in qualità alta (passata di qualità della sala, come il
pezzo campione degli interni: assets_src/ambienti_interni/meshy_hq/genera_hq.py).

Per ogni oggetto: immagine di riferimento (Meshy text-to-image nano-banana-pro, solo uso interno,
in rif/) -> image-to-3d meshy-7.1 con geometria 4k, texture PBR 4K, remesh a triangoli al numero di
poligoni dato. Il GLB scaricato (4K, ~25 MB) viene ridotto qui a texture JPG 2K e salvato come
<nome>.glb; l'originale non si tiene (si riscarica dal task in <nome>.json finché Meshy lo tiene).
Misura, perno e scala li mette ambiente_sala.py (importa_oggetto, tabella MISURE).

Uso: python3 assets_src/ambiente/oggetti_hq/genera_hq.py [--immagini] [nome ...]   (senza nomi: quelli che mancano;
     con --immagini si fermano dopo l'immagine di riferimento)
     python3 assets_src/ambiente/oggetti_hq/genera_hq.py --riduci file.glb uscita.glb [lato]
La chiave è in MESHY_API_KEY (mai nel repository)."""
import io, json, os, struct, sys, time, concurrent.futures as cf
QUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(QUI, '../../../tools'))

STILE = ('Game-ready 3D asset concept render in the clean style of Poppy Playtime chapter 1: soft rounded bevelled edges, '
         'smooth well-defined shapes, believable materials with subtle wear, light dirt in the creases and a few scratches, '
         'not grungy. Single isolated object, the whole object fully visible, neutral studio lighting, plain light grey '
         'background, no text, no letters, no numbers, no logos, no people.')
DAVANTI = 'Three-quarter front view.'
DALL_ALTO = 'Seen from above at a three-quarter angle.'

# nome: (descrizione, vista, triangoli). I nomi uguali a quelli di assets_src/ambiente/oggetti/ prendono il posto
# dei modelli vecchi (stesse misure e stesse posizioni in ambiente_sala.py).
OGGETTI = {
    # --- bordo vasche, spiaggia, ingresso
    'lettino_plastica': ('An old 1990s molded white plastic pool sun lounger: raised backrest and seat made of rounded '
                         'horizontal slats, four short rounded legs, two small wheels at the head end, slightly yellowed plastic.',
                         DAVANTI, 12000),
    'salvagente_nave': ('A ship lifebuoy ring with four red and four white segments and a grey grab rope fixed in four loops '
                        'around the outside, chunky rounded foam ring, lying flat on the ground.', DALL_ALTO, 8000),
    'sedia_bagnino': ('A tall 1990s lifeguard chair for an indoor pool: white painted round steel tube frame with a ladder '
                      'of four rounded steps at the front, a molded teal plastic seat about 1.8 m high with a backrest and '
                      'armrests, a footrest bar, rubber feet.', DAVANTI, 25000),
    'colonnina_ottone': ('A polished brass stanchion post for a velvet rope barrier: heavy round domed base, slim straight '
                         'pole, ball finial on top with a small hook ring on the side.', DAVANTI, 3000),
    'lampione': ('A vintage cast iron lamp post about three meters tall painted dark bottle green: fluted pole on a '
                 'decorative round base, a single classic lantern head on top with four frosted glass panes and a small '
                 'roof cap.', DAVANTI, 15000),
    'lampione_braccio': ('A vintage cast iron lamp post about four meters tall painted dark bottle green: fluted pole on a '
                         'decorative round base, at the top one curved shepherd crook arm reaching out to the left side, '
                         'with a single industrial conical enamelled metal lamp shade hanging from the end of the arm and a '
                         'bulb under it.', 'Side view, the whole post visible from base to top.', 12000),
    'cestino_pesce': ('A 1990s water park trash bin shaped like a cute cartoon fish standing upright on its tail fin, its '
                      'wide open round mouth is the bin opening, molded fiberglass painted faded teal with a yellow belly '
                      'and big friendly eyes.', DAVANTI, 10000),
    'cartello_pavimento_bagnato': ('A yellow plastic A-frame wet floor warning sign standing on the floor, both panels '
                                   'showing only a black pictogram of a person slipping, rounded handle on top.', DAVANTI, 4000),
    # --- giocattoli e gonfiabili
    'paperella_gigante': ('A big vintage rubber duck pool toy, faded yellow vinyl, orange beak, painted black eyes, '
                          'smooth rounded shapes.', DAVANTI, 8000),
    'pallone_spiaggia': ('A classic inflatable beach ball with six colored panels (blue, yellow, red, white, green, '
                         'orange) and a small valve, slightly soft.', DAVANTI, 3000),
    'ciambella_gonfiabile': ('An inflatable kids swim ring with faded red and white stripes, slightly deflated, soft '
                             'wrinkles in the vinyl, a small valve.', DALL_ALTO, 6000),
    'tubi_galleggianti': ('Three foam pool noodles lying on the floor crossed loosely, faded pink, green and yellow foam, '
                          'hollow round ends.', DALL_ALTO, 5000),
    'delfino_gonfiabile_sgonfio': ('A half-deflated inflatable cartoon dolphin pool toy lying collapsed on the floor, '
                                   'sagging with soft wrinkles and folds, faded blue and white vinyl, cute face.',
                                   DALL_ALTO, 15000),
    'balena_gonfiabile_sgonfia': ('A huge half-deflated inflatable cartoon whale pool float lying on the floor, collapsed '
                                  'with big soft folds, faded blue and white vinyl, cute smiling face.', DALL_ALTO, 20000),
    'orsacchiotto_grande': ('A big old plush teddy bear sitting slumped, matted grey-white fur with dirt stains, a faded '
                            'red bow at the neck, one button eye hanging loose, sad and a little creepy.', DAVANTI, 15000),
    # --- area bimbi
    'fungo_fontana': ('A kids water playground mushroom fountain about two meters tall, switched off and dry: wide glossy '
                      'red fiberglass cap with white spots, a ring of small round brass nozzles flush under the rim, thick '
                      'pale yellow stem, round base plate with bolts. No water.', DAVANTI, 12000),
    'cannoncino_acqua': ('A kids water playground water cannon: a chunky yellow and blue plastic water gun turret with a '
                         'long nozzle and two handles, on a short teal steel post with a swivel joint and a round base plate.',
                         DAVANTI, 10000),
    'secchio_gigante': ('A giant tipping water bucket for a kids water playground, standing perfectly upright and '
                        'symmetric: a big round slightly tapered plastic bucket, faded red, with a thick rounded yellow rim '
                        'and two identical round pivot hubs on opposite sides at mid height, empty inside.',
                        'Front view from slightly above.', 8000),
}


def _scarica(url, path):
    import meshy
    for k in range(4):
        try:
            return meshy.download(url, path)
        except Exception:
            time.sleep(5 + 5 * k)
    raise RuntimeError('download ' + url)


def riduci(src, dst, lato=2048, qualita=90):
    """Riscrive un GLB con le immagini ridotte a 'lato' e salvate in JPG (PNG solo se c'è un'alfa vera)."""
    from PIL import Image
    with open(src, 'rb') as f:
        dati = f.read()
    n = struct.unpack_from('<I', dati, 12)[0]
    g = json.loads(dati[20:20 + n])
    off = 20 + n
    bn = struct.unpack_from('<I', dati, off)[0]
    binario = dati[off + 8:off + 8 + bn]
    viste = g['bufferViews']
    nuovi = {}
    for im in g.get('images', []):
        v = viste[im['bufferView']]
        raw = binario[v.get('byteOffset', 0):v.get('byteOffset', 0) + v['byteLength']]
        img = Image.open(io.BytesIO(raw))
        img.load()
        alfa = img.mode in ('RGBA', 'LA') and img.getchannel('A').getextrema()[0] < 250
        if max(img.size) > lato:
            img = img.resize((lato, lato) if img.size[0] == img.size[1] else
                             (round(img.size[0] * lato / max(img.size)), round(img.size[1] * lato / max(img.size))),
                             Image.LANCZOS)
        out = io.BytesIO()
        if alfa:
            img.save(out, 'PNG', optimize=True)
            im['mimeType'] = 'image/png'
        else:
            img.convert('RGB').save(out, 'JPEG', quality=qualita, optimize=True)
            im['mimeType'] = 'image/jpeg'
        nuovi[im['bufferView']] = out.getvalue()
    pezzi, pos = [], 0
    for i, v in enumerate(viste):
        b = nuovi.get(i)
        if b is None:
            b = binario[v.get('byteOffset', 0):v.get('byteOffset', 0) + v['byteLength']]
        pad = (-pos) % 4
        pezzi.append(b'\0' * pad)
        pos += pad
        v['byteOffset'] = pos
        v['byteLength'] = len(b)
        v['buffer'] = 0
        pezzi.append(b)
        pos += len(b)
    nuovo_bin = b''.join(pezzi)
    nuovo_bin += b'\0' * ((-len(nuovo_bin)) % 4)
    g['buffers'] = [{'byteLength': len(nuovo_bin)}]
    js = json.dumps(g, separators=(',', ':')).encode()
    js += b' ' * ((-len(js)) % 4)
    with open(dst, 'wb') as f:
        f.write(struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(nuovo_bin)))
        f.write(struct.pack('<II', len(js), 0x4E4F534A)); f.write(js)
        f.write(struct.pack('<II', len(nuovo_bin), 0x004E4942)); f.write(nuovo_bin)
    return dst


def fai(nome):
    import meshy
    out = os.path.join(QUI, nome + '.glb')
    if os.path.exists(out):
        return nome, 'esiste'
    desc, vista, poly = OGGETTI[nome]
    rif = os.path.join(QUI, 'rif', nome + '.jpg')
    fjson = os.path.join(QUI, nome + '.json')
    info = json.load(open(fjson)) if os.path.exists(fjson) else {}
    prompt = desc + ' ' + vista + ' ' + STILE
    if not info.get('immagine'):
        tid = meshy.create('text-to-image', dict(ai_model='nano-banana-pro', prompt=prompt, aspect_ratio='1:1'))
        t = meshy.wait('text-to-image', tid)
        if t['status'] != 'SUCCEEDED':
            return nome, 'immagine ' + t['status']
        png = rif[:-4] + '.png'
        _scarica(t['image_urls'][0], png)
        from PIL import Image
        Image.open(png).convert('RGB').save(rif, 'JPEG', quality=90)
        os.remove(png)
        info.update(immagine=tid, prompt=prompt)
        json.dump(info, open(fjson, 'w'), indent=1)
    if SOLO_IMMAGINI:
        return nome, 'immagine pronta'
    if not info.get('task') or info.get('status') in ('FAILED', 'CANCELED'):
        corpo = dict(input_task_id=info['immagine'], ai_model='meshy-7.1', geometry_resolution='4k', should_texture=True,
                     enable_pbr=True, texture_resolution='4k', should_remesh=True, topology='triangle',
                     target_polycount=poly, remove_lighting=True)
        info.update(task=meshy.create('image-to-3d', corpo), status='IN_PROGRESS', poligoni=poly)
        json.dump(info, open(fjson, 'w'), indent=1)
    t = meshy.wait('image-to-3d', info['task'], timeout=3600)
    info['status'] = t['status']
    json.dump(info, open(fjson, 'w'), indent=1)
    if t['status'] != 'SUCCEEDED':
        return nome, '3d ' + t['status'] + ' ' + str(t.get('task_error'))
    tmp = out + '.4k.tmp'
    _scarica(t['model_urls']['glb'], tmp)
    riduci(tmp, out)
    os.remove(tmp)
    return nome, 'ok %.1f MB' % (os.path.getsize(out) / 1e6)


SOLO_IMMAGINI = False

if __name__ == '__main__':
    if '--immagini' in sys.argv:   # solo le immagini di riferimento, da guardare prima di pagare i modelli
        sys.argv.remove('--immagini')
        SOLO_IMMAGINI = True
    if sys.argv[1:2] == ['--riduci']:
        riduci(sys.argv[2], sys.argv[3], int(sys.argv[4]) if len(sys.argv) > 4 else 2048)
        sys.exit(0)
    nomi = sys.argv[1:] or [n for n in OGGETTI if not os.path.exists(os.path.join(QUI, n + '.glb'))]
    with cf.ThreadPoolExecutor(6) as ex:
        for n, s in ex.map(fai, nomi):
            print(n, s, flush=True)
