"""Il ronzio del finale dello spot (godot/assets/spot/ronzio_spot.ogg, 7,1 s: dal 37,5 al 44,6 s del montaggio di
ambienti-2). Bozza: "L'audio è un ronzio basso che sale, più la sigla al contrario", poi "taglio al nero, ronzio della TV".
- 0-5,3 s (fino al nero, 42,8 s): un ronzio di rete basso che sale (da 55 a 85 Hz, con le armoniche, un poco saturato)
  e cresce; sotto, la sigla pulita al contrario e rallentata, che cresce anche lei, con un battito che accelera
  (lo stesso dell'occhio, da 72 a 200 bpm);
- 4,98-5,3 s: lo scatto in avanti dell'occhio (progresso 0,93-1 su 4,6 s): un soffio che sale;
- 5,3 s: il colpo forte (un tonfo basso e uno schiocco) e il taglio netto;
- 5,3-7,1 s: il ronzio della TV accesa senza segnale (fruscio e il fischio del tubo), che sfuma.
Uso: /home/user/tools/tts-venv/bin/python assets_src/spot/suoni/genera_ronzio.py"""
import os
import subprocess
import numpy as np
import soundfile as sf

QUI = os.path.dirname(os.path.abspath(__file__))
RADICE = os.path.normpath(os.path.join(QUI, '..', '..', '..'))
SIGLA = os.path.join(RADICE, 'godot', 'audio', 'musica', 'sigla_pulita.ogg')
USCITA = os.path.join(RADICE, 'godot', 'assets', 'spot', 'ronzio_spot.ogg')
SR = 44100
T_NERO, T_FINE = 5.3, 7.1
rng = np.random.default_rng(20261022)

n = int(T_FINE * SR)
t = np.arange(n) / SR
su = np.clip(t / T_NERO, 0.0, 1.0)                     # quanto è salito (0-1) fino al nero

# il ronzio di rete che sale
f0 = 55.0 + 30.0 * su ** 1.5
fase = 2 * np.pi * np.cumsum(f0) / SR
ronzio = sum(a * np.sin(k * fase) for k, a in ((1, 1.0), (2, 0.5), (3, 0.35), (5, 0.18), (7, 0.1)))
ronzio = np.tanh(ronzio * (1.0 + 2.5 * su)) * (0.08 + 0.42 * su ** 1.3)

# la sigla al contrario, rallentata (0,8: più bassa), che cresce
tmp = '/tmp/sigla_spot.wav'
subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', SIGLA, '-ac', '1', '-ar', str(SR), tmp], check=True)
s, _ = sf.read(tmp, dtype='float32')
s = s[::-1]
lento = 0.8
idx = np.arange(int(T_NERO * SR)) * lento
sigla = np.interp(idx, np.arange(len(s)), s)
sigla = np.concatenate([sigla, np.zeros(n - len(sigla), np.float32)])
sigla *= (0.15 + 0.5 * su ** 2) / max(1e-6, np.abs(sigla).max())

# il battito che accelera (colpi sordi, due per battito), come nell'occhio
bpm = 72.0 + 128.0 * su ** 2
fb = np.cumsum(bpm / 60.0) / SR
f = fb % 1.0
colpo = np.exp(-f * 22.0) + 0.6 * np.exp(-np.abs(f - 0.28) * 26.0) * (f > 0.22)
battito = np.sin(2 * np.pi * 48.0 * t) * colpo * (0.15 + 0.45 * su)

prima = (ronzio + sigla + battito) * (t < T_NERO)
# lo scatto in avanti: un soffio di rumore che sale (filtrato dal basso verso l'alto) fino al colpo
T_SCATTO = T_NERO - 0.32
w = np.clip((t - T_SCATTO) / (T_NERO - T_SCATTO), 0.0, 1.0) * (t < T_NERO)
soffio = np.cumsum(rng.standard_normal(n)) * 0.002
soffio = (soffio - np.convolve(soffio, np.ones(200) / 200, mode='same')) * 6.0 * w ** 2
# il colpo forte al nero: un tonfo basso che cala e uno schiocco di rumore
dt = np.maximum(t - T_NERO, 0.0) * (t >= T_NERO)
tonfo = np.sin(2 * np.pi * (70.0 * dt - 30.0 * dt * dt)) * np.exp(-dt * 5.0) * (t >= T_NERO) * 1.4
schiocco = rng.standard_normal(n) * np.exp(-dt * 40.0) * (t >= T_NERO) * 0.9
prima = prima + soffio + np.tanh((tonfo + schiocco) * 1.5)
# dopo il nero: la TV senza segnale, fruscio e fischio del tubo, che sfuma
dopo = (t >= T_NERO)
sfuma = np.clip(1.0 - (t - T_NERO) / (T_FINE - T_NERO), 0.0, 1.0) ** 1.5
fruscio = rng.standard_normal(n) * 0.12
fischio = np.sin(2 * np.pi * 7860.0 * t) * 0.025 + np.sin(2 * np.pi * 50.0 * t) * 0.06
tv = (fruscio + fischio) * sfuma * dopo
x = prima + tv
x = 0.9 * x / np.abs(x).max()
sf.write(tmp, x.astype(np.float32), SR)
os.makedirs(os.path.dirname(USCITA), exist_ok=True)
subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', tmp, '-c:a', 'libvorbis', '-q:a', '5', USCITA], check=True)
print('scritto', USCITA, '%.2f s' % (n / SR))
