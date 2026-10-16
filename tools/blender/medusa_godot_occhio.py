"""Scatti in Godot 4.7.2 della medusa affacciata nella vasca, per l'easter egg dell'occhio che si chiude.

Prepara un progetto di prova (build/godot_vasca) con quello che serve e niente di piu': il GLB della medusa e la
cartella godot/ dei suoi materiali, gli script veri della medusa (godot/scripts/environment/medusa_statue.gd e
medusa_affacciata.gd, con chiudi_occhio), la vasca della sala (build/rif/sala_vasca_centrale.glb, dal progetto
del gioco) e due finti pezzi del gioco (GameState con un giocatore e WaterDripEmitter). La medusa e' messa come
nella sala (Vasca/Medusa: posizione (0, 0, 10,15), materiali bagnati per nome), l'occhio segue la camera come
segue il giocatore. Luce di notte semplice: ambiente scuro, la torcia del giocatore dalla camera, il bagliore della
campana e una luce rossa d'emergenza. La sala vera non entra: con gli interni supera la memoria della macchina.

Scatti (1600x900, camera del giocatore a 1,7 m come lo scatto b_vasca_3m di godot/tests/scatti_sala.gd):
  vasca_aperto, vasca_chiuso   occhio aperto e chiuso con chiudi_occhio()
  vicino_aperto, vicino_chiuso lo stesso dal cordone intorno alla vasca
  occhio_<c>                   primo piano dell'occhio con la palpebra a varie chiusure (controllo: cornea, frangia)
  basso_<c>                    lo stesso da piu' in basso (sotto la frangia)
Con --prima usa il GLB di prima (MEDUSA_GLB_PRIMA, per esempio estratto da git) e fa solo gli scatti aperti: il
confronto prima/dopo a occhio aperto si fa sui pixel.

Ogni processo di Godot passa dal render.lock e parte solo con almeno 13,5 GB di memoria libera (CLAUDE.md).
Con --tavole (dopo gli scatti) compone i JPG per l'utente in docs/proposte/medusa/occhio_chiuso/:
  godot_vasca_aperto.jpg, godot_vasca_chiuso.jpg, godot_vasca.jpg (con il cordone) e godot_controllo_palpebra.jpg.
Uso: /home/user/tools/blender-venv/bin/python tools/blender/medusa_godot_occhio.py [--prima] [--uscita DIR] [--tavole]
"""
import fcntl
import os
import shutil
import subprocess
import sys
import time

QUI = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(QUI, '..', '..'))
ASSET = os.path.join(REPO, 'assets_src', 'medusa')
BUILD = os.path.join(ASSET, 'build')
PRJ = os.path.join(BUILD, 'godot_vasca')
LOCK = '/home/user/tools/render.lock'
MEMORIA_MIN_KB = int(13.5 * 1024 * 1024)
RIS = '1600x900'

GAME_STATE = '''extends Node
## Finto GameState del gioco: basta il giocatore (l'occhio della medusa segue la sua camera).
var player: Player = null
'''
GIOCATORE = '''class_name Player
extends Node3D
## Finto giocatore: la medusa legge solo player.camera.
var camera: Camera3D
'''
GOCCE = '''class_name WaterDripEmitter
extends Node3D
## Finto WaterDripEmitter (addon acqua del gioco): nel progetto di prova niente gocce.
@export var interval_min := 0.7
@export var interval_max := 2.6
@export var jitter := 0.03
'''

SCATTA = r'''extends SceneTree
# Scatti della medusa affacciata nella vasca: occhio aperto e chiuso, primi piani della palpebra.
var medusa
var cam: Camera3D
var torcia: SpotLight3D
var passi := []
var i := -1
var attesa := 0
var uscita := ""

const M := "res://assets/models/medusa/"

func _initialize() -> void:
	uscita = OS.get_environment("SCATTI")
	var prima := OS.get_environment("PRIMA") == "1"
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.01, 0.012, 0.02)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.38, 0.4, 0.48)
	e.ambient_light_energy = 0.45
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.glow_enabled = true
	e.fog_enabled = true
	e.fog_light_color = Color(0.1, 0.11, 0.15)
	e.fog_density = 0.015
	env.environment = e
	root.add_child(env)
	# luce rossa d'emergenza alta, dietro a destra, e un riempimento freddo dall'alto
	var rossa := OmniLight3D.new()
	rossa.position = Vector3(3.5, 4.5, 7.0)
	rossa.light_color = Color(1.0, 0.12, 0.08)
	rossa.light_energy = 3.0
	rossa.omni_range = 14.0
	root.add_child(rossa)
	var fredda := DirectionalLight3D.new()
	fredda.rotation_degrees = Vector3(-55, 20, 0)
	fredda.light_color = Color(0.55, 0.62, 0.85)
	fredda.light_energy = 0.3
	root.add_child(fredda)
	# la lampada della sala, dall'alto davanti, bianca calda
	var lampada := SpotLight3D.new()
	lampada.position = Vector3(1.0, 5.5, 13.5)
	lampada.light_color = Color(1.0, 0.92, 0.82)
	lampada.light_energy = 2.5
	lampada.spot_range = 10.0
	lampada.spot_angle = 28.0
	lampada.shadow_enabled = true
	root.add_child(lampada)
	lampada.look_at(Vector3(0.0, 1.5, 11.6), Vector3.UP)
	var v := (load("res://vasca.glb") as PackedScene).instantiate() as Node3D
	root.add_child(v)
	for n in v.find_children("*", "", true, false):
		if "colonly" in String(n.name) or "convcol" in String(n.name):
			(n as Node3D).visible = false
	# acqua della vasca: dal fondo al pelo (0,88), trasparente verde-azzurra
	var acqua := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(5.38, 0.875, 3.88)
	acqua.mesh = bm
	acqua.position = Vector3(0, 0.4425, 10.0)
	var am := StandardMaterial3D.new()
	am.albedo_color = Color(0.32, 0.55, 0.58, 0.55)
	am.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	am.roughness = 0.05
	am.metallic_specular = 0.6
	acqua.material_override = am
	acqua.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(acqua)
	# la medusa come nella sala (Vasca/Medusa)
	medusa = Node3D.new()
	medusa.set_script(load("res://scripts/environment/medusa_affacciata.gd"))
	medusa.position = Vector3(0, 0, 10.15)
	medusa.model = load(OS.get_environment("MODELLO"))
	medusa.bell_material = load(M + "medusa_campana.tres")
	medusa.material_map = {
		"M_capelli": load(M + "medusa_capelli_bagnata.tres"),
		"M_ciocche": load(M + "medusa_ciocche_bagnata.tres"),
		"M_mani": load(M + "medusa_mani_bagnata.tres"),
		"M_occhio_bulbo": load(M + "medusa_occhio.tres"),
		"M_orbita": load(M + "medusa_orbita_bagnata.tres"),
		"M_pelle": load(M + "medusa_pelle_bagnata.tres"),
		"M_tentacoli": load(M + "medusa_tentacoli_bagnata.tres"),
	}
	root.add_child(medusa)
	# il bagliore della campana sotto il pelo dell'acqua sale sul viso e sul petto
	var bagliore := OmniLight3D.new()
	bagliore.position = Vector3(0, 0.95, 11.6)
	bagliore.light_color = Color(1.0, 0.45, 0.72)
	bagliore.light_energy = 0.35
	bagliore.omni_range = 2.5
	root.add_child(bagliore)
	cam = Camera3D.new()
	cam.fov = 62.0
	cam.near = 0.02
	root.add_child(cam)
	cam.current = true
	# la torcia del giocatore
	torcia = SpotLight3D.new()
	torcia.light_energy = 3.5
	torcia.spot_range = 18.0
	torcia.spot_angle = 26.0
	torcia.shadow_enabled = true
	cam.add_child(torcia)
	torcia.position = Vector3(0.12, -0.12, 0.0)
	var gs = root.get_node("GameState")
	var g = Node3D.new()
	g.set_script(load("res://giocatore.gd"))
	g.camera = cam
	root.add_child(g)
	gs.player = g
	# [nome, piedi o posizione della camera, punto guardato, cosa fare con l'occhio, fov]
	var b3 := [Vector3(1.6, 1.7, 15.4), Vector3(0.0, 1.0, 10.8)]
	# dal cordone intorno alla vasca (il giocatore non si avvicina di piu')
	var vic := [Vector3(0.9, 1.7, 14.2), Vector3(0.0, 1.45, 11.9)]
	passi.append(["vasca_aperto", b3[0], b3[1], "aperto", 62.0])
	passi.append(["vicino_aperto", vic[0], vic[1], "aperto", 62.0])
	if not prima:
		passi.append(["vasca_chiuso", b3[0], b3[1], "chiudi", 62.0])
		passi.append(["vicino_chiuso", vic[0], vic[1], "aperto", 62.0])
		var occhio := Vector3(0.0, 1.62, 11.95)
		for c in [0.15, 0.3, 0.5, 0.7, 0.85, 1.0]:
			passi.append(["occhio_%03d" % int(c * 100), Vector3(0.35, 1.72, 13.2), occhio, c, 30.0])
		for c in [0.3, 0.6, 1.0]:
			passi.append(["basso_%03d" % int(c * 100), Vector3(0.25, 1.0, 13.0), occhio, c, 30.0])

func _process(_delta: float) -> bool:
	if attesa > 0:
		attesa -= 1
		if attesa == 0 and i >= 0:
			var img := root.get_viewport().get_texture().get_image()
			img.save_png(uscita + "/" + passi[i][0] + ".png")
			print("SCATTO ", passi[i][0])
		return false
	i += 1
	if i >= passi.size():
		return true
	var p = passi[i]
	cam.global_position = p[1]
	cam.look_at(p[2], Vector3.UP)
	cam.fov = p[4]
	torcia.visible = p[4] > 40.0
	if p[3] is String and p[3] == "chiudi":
		medusa.chiudi_occhio(1000.0)
		attesa = 50
	elif p[3] is float:
		if medusa._tw_occhio and medusa._tw_occhio.is_valid():
			medusa._tw_occhio.kill()
		medusa._occhio_dritto(1.0, 0.01)
		medusa._imposta_chiusura(p[3])
		attesa = 12
	else:
		attesa = 120 if i == 0 else 60      # lo sguardo segue la camera nuova (0,35 s)
	return false
'''


def memoria_libera_kb():
    with open('/proc/meminfo') as f:
        for r in f:
            if r.startswith('MemAvailable'):
                return int(r.split()[1])
    return 0


def con_lock(cmd, env=None, timeout=1800):
    """Un processo pesante alla volta: render.lock e almeno 13,5 GB di memoria libera, poi il comando."""
    with open(LOCK, 'a') as lf:
        fcntl.flock(lf, fcntl.LOCK_EX)
        while memoria_libera_kb() < MEMORIA_MIN_KB:
            time.sleep(5)
        print('godot:', ' '.join(cmd[-4:]), f'({memoria_libera_kb() // 1024} MB liberi)', flush=True)
        try:
            return subprocess.run(['nice', '-n', '10'] + cmd, capture_output=True, text=True, timeout=timeout,
                                  env=env)
        finally:
            fcntl.flock(lf, fcntl.LOCK_UN)


def prepara(glb):
    os.makedirs(PRJ, exist_ok=True)
    with open(os.path.join(PRJ, 'project.godot'), 'w') as f:
        f.write('config_version=5\n\n[application]\nconfig/name="medusa nella vasca"\n\n'
                '[autoload]\nGameState="*res://game_state.gd"\n')
    for nome, testo in (('game_state.gd', GAME_STATE), ('giocatore.gd', GIOCATORE),
                        ('water_drip_emitter.gd', GOCCE), ('scatta.gd', SCATTA)):
        with open(os.path.join(PRJ, nome), 'w') as f:
            f.write(testo)
    dest = os.path.join(PRJ, 'assets', 'models', 'medusa')
    os.makedirs(dest, exist_ok=True)
    gd = os.path.join(ASSET, 'godot')
    for f in os.listdir(gd):
        if not f.endswith('.md'):
            shutil.copy(os.path.join(gd, f), os.path.join(dest, f))
    shutil.copy(glb, os.path.join(dest, 'medusa.glb'))
    sc = os.path.join(PRJ, 'scripts', 'environment')
    os.makedirs(sc, exist_ok=True)
    for f in ('medusa_statue.gd', 'medusa_affacciata.gd'):
        shutil.copy(os.path.join(REPO, 'godot', 'scripts', 'environment', f), os.path.join(sc, f))
    shutil.copy(os.path.join(BUILD, 'rif', 'sala_vasca_centrale.glb'), os.path.join(PRJ, 'vasca.glb'))


FONT_BOLD = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'


def tavola(celle, path, colonne, titolo=None, larghezza=2400):
    """Griglia di immagini con un'etichetta sopra ognuna (come medusa_comune.tavola, senza bpy)."""
    from PIL import Image, ImageDraw, ImageFont
    ims = [(Image.open(p).convert('RGB'), t) for p, t in celle]
    w0, h0 = ims[0][0].size
    eh, gap = max(56, int(w0 * 0.05)), max(6, w0 // 120)
    righe = (len(ims) + colonne - 1) // colonne
    th = int(eh * 1.25) if titolo else 0
    out = Image.new('RGB', (colonne * w0 + (colonne + 1) * gap, th + righe * (h0 + eh) + (righe + 1) * gap),
                    (58, 58, 62))
    d = ImageDraw.Draw(out)
    f = ImageFont.truetype(FONT_BOLD, int(eh * 0.58))
    if titolo:
        d.text((out.size[0] // 2, gap + int(eh * 0.55)), titolo, fill=(255, 255, 255),
               font=ImageFont.truetype(FONT_BOLD, int(eh * 0.7)), anchor='mm')
    for i, (im, t) in enumerate(ims):
        r, c = divmod(i, colonne)
        x0, y0 = gap + c * (w0 + gap), gap + th + r * (h0 + eh + gap)
        out.paste(im.resize((w0, h0)), (x0, y0 + eh))
        d.rectangle((x0, y0, x0 + w0, y0 + eh - 2), fill=(250, 250, 250))
        d.text((x0 + w0 // 2, y0 + eh // 2), t, fill=(15, 15, 20), font=f, anchor='mm')
    if out.size[0] > larghezza:
        out = out.resize((larghezza, int(out.size[1] * larghezza / out.size[0])), Image.LANCZOS)
    out.save(path, quality=90)
    print('tavola', os.path.relpath(path, REPO), out.size)


def tavole(scatti):
    from PIL import Image
    out = os.path.join(REPO, 'docs', 'proposte', 'medusa', 'occhio_chiuso')
    os.makedirs(out, exist_ok=True)
    for n in ('vasca_aperto', 'vasca_chiuso'):
        Image.open(os.path.join(scatti, n + '.png')).convert('RGB').save(os.path.join(out, f'godot_{n}.jpg'), quality=90)
        print('immagine', f'godot_{n}.jpg')
    p = lambda n: os.path.join(scatti, n + '.png')  # noqa: E731
    tavola([(p('vasca_aperto'), 'Godot: occhio aperto'), (p('vasca_chiuso'), 'Godot: occhio chiuso'),
            (p('vicino_aperto'), 'dal cordone: aperto'), (p('vicino_chiuso'), 'dal cordone: chiuso')],
           os.path.join(out, 'godot_vasca.jpg'), 2, 'Medusa nella vasca, in Godot: chiudi_occhio()')
    celle = [(p(f'occhio_{c:03d}'), f'chiusura {c}%') for c in (15, 30, 50, 70, 85, 100)]
    celle += [(p(f'basso_{c:03d}'), f'da sotto, {c}%') for c in (30, 60, 100)]
    tavola(celle, os.path.join(out, 'godot_controllo_palpebra.jpg'), 3, 'Palpebra in Godot: cornea e frangia',
           larghezza=2700)


def main():
    if '--tavole' in sys.argv:
        tavole(sys.argv[sys.argv.index('--uscita') + 1] if '--uscita' in sys.argv else
               os.path.join(BUILD, 'render', 'godot_occhio'))
        return
    prima = '--prima' in sys.argv
    uscita = sys.argv[sys.argv.index('--uscita') + 1] if '--uscita' in sys.argv else \
        os.path.join(BUILD, 'render', 'godot_occhio')
    os.makedirs(uscita, exist_ok=True)
    glb = os.environ.get('MEDUSA_GLB_PRIMA') if prima else os.path.join(ASSET, 'medusa.glb')
    prepara(glb)
    r = con_lock(['godot', '--headless', '--path', PRJ, '--import'], timeout=1800)
    print('import:', r.returncode)
    env = dict(os.environ, SCATTI=uscita, MODELLO='res://assets/models/medusa/medusa.glb', PRIMA='1' if prima else '0')
    r = con_lock(['xvfb-run', '-a', '-s', f'-screen 0 {RIS}x24', 'godot', '--path', PRJ, '--rendering-driver', 'vulkan',
                  '--fixed-fps', '60', '--resolution', RIS, '--script', 'res://scatta.gd'], env=env, timeout=1800)
    for x in (r.stdout + r.stderr).splitlines():
        if x.startswith(('SCATTO', 'SCRIPT ERROR', 'ERROR', 'Parse Error')) or 'error' in x.lower()[:40]:
            if 'leaked' not in x and 'resources still' not in x and 'ALSA' not in x:
                print('   ', x)


if __name__ == '__main__':
    main()
