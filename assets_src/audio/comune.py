"""Parti comuni ai generatori: percorsi, salvataggio con normalizzazione e registro dei file
(che alla fine diventa il catalogo per Godot e l'elenco delle licenze)."""
from __future__ import annotations

import json
import os
import sys

import numpy as np

QUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, QUI)
from lib_audio import (SR, f32, limiter, lufs, lufs_max, make_ir, mono, normalize_lufs,  # noqa: E402,F401
                       read_audio, write_ogg)

RADICE = os.path.abspath(os.path.join(QUI, '..', '..'))
AUDIO = os.path.join(RADICE, 'godot', 'audio')
KENNEY = os.path.join(QUI, 'sorgenti', 'kenney')
REGISTRO = os.path.join(QUI, 'registro.json')

_IR_CACHE: dict = {}


def ir_sala(seed: int = 7):
    """Riverbero della sala principale: enorme, piastrellata, con l'acqua (circa 3,8 s)."""
    k = ('sala', seed)
    if k not in _IR_CACHE:
        _IR_CACHE[k] = make_ir(rt60=3.8, predelay=0.035, hf_damp=0.55, early=18, early_span=0.12,
                               brightness=7000, seed=seed)
    return _IR_CACHE[k]


def ir_nave(seed: int = 11):
    """Corridoi e scafo di metallo lontani: coda lunga e scura."""
    k = ('nave', seed)
    if k not in _IR_CACHE:
        _IR_CACHE[k] = make_ir(rt60=5.0, predelay=0.06, hf_damp=0.8, early=10, early_span=0.2,
                               brightness=3500, lf_rt_mul=1.3, seed=seed)
    return _IR_CACHE[k]


def ir_piccola(seed: int = 5):
    """Stanza piccola (per i suoni dell'interfaccia e della musica pulita)."""
    k = ('piccola', seed)
    if k not in _IR_CACHE:
        _IR_CACHE[k] = make_ir(rt60=0.9, predelay=0.012, hf_damp=0.4, early=10, early_span=0.04,
                               brightness=9000, seed=seed)
    return _IR_CACHE[k]


def kenney(nome: str, canali: int = 1) -> np.ndarray:
    """Legge un file dei pacchetti Kenney (CC0) copiati in sorgenti/kenney/."""
    return read_audio(os.path.join(KENNEY, nome), canali)


def _carica_registro() -> dict:
    if os.path.exists(REGISTRO):
        with open(REGISTRO, encoding='utf-8') as f:
            return json.load(f)
    return {}


def salva(cartella: str, nome: str, x: np.ndarray, *, loudness: float | None = None, corto: bool = False,
          picco: float = -1.0, qualita: float = 4.0, fonte: str = 'sintesi', nota: str = '') -> str:
    """Normalizza (loudness integrata, o massima su 100 ms se corto=True), limita il picco
    e scrive godot/audio/<cartella>/<nome>.ogg. Registra il file per catalogo e licenze."""
    x = f32(x)
    if loudness is not None:
        x = normalize_lufs(x, loudness, picco, short=corto)
    else:
        p = float(np.abs(x).max())
        if p > 0:
            x = x * (10 ** (picco / 20) / p)
    if float(np.abs(x).max()) > 10 ** (picco / 20) + 1e-4:
        x = limiter(x, picco)
    path = os.path.join(AUDIO, cartella, nome + '.ogg')
    write_ogg(path, x, qualita)
    reg = _carica_registro()
    reg[f'{cartella}/{nome}'] = {
        'file': f'res://audio/{cartella}/{nome}.ogg',
        'canali': 2 if x.ndim == 2 else 1,
        'durata': round(len(x) / SR, 3),
        'loop': nome.endswith('_loop'),
        'fonte': fonte,
        'nota': nota,
        'lufs': round(lufs(x), 1) if len(x) > SR * 0.5 else None,
        'lufs_max': round(lufs_max(x), 1),
    }
    with open(REGISTRO, 'w', encoding='utf-8') as f:
        json.dump(dict(sorted(reg.items())), f, indent=1, ensure_ascii=False)
    print(f'  {cartella}/{nome}.ogg  {len(x) / SR:5.2f}s  {"stereo" if x.ndim == 2 else "mono  "}  '
          f'maxM {lufs_max(x):6.1f}')
    return path
