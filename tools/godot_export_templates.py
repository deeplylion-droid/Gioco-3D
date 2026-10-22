#!/usr/bin/env python3
"""Installa solo i template di export di Godot che servono (Windows x86_64 e Linux x86_64).

Il file ufficiale export_templates.tpz pesa più di 1 GB: è uno zip, e il server accetta le
richieste HTTP "Range", quindi qui si legge solo l'indice dello zip e i file necessari
(circa un decimo dei dati). Funziona sia nel sandbox sia nei runner di GitHub Actions.

Uso:
  python3 tools/godot_export_templates.py [versione] [cartella]
  (default: 4.7.2, ~/.local/share/godot/export_templates/<versione>.stable)
"""
import io
import os
import sys
import urllib.request
import zipfile

VERSION = sys.argv[1] if len(sys.argv) > 1 else '4.7.2'
DEST = sys.argv[2] if len(sys.argv) > 2 else os.path.expanduser(
    f'~/.local/share/godot/export_templates/{VERSION}.stable')
URL = (f'https://downloads.godotengine.org/?version={VERSION}&flavor=stable'
       '&slug=export_templates.tpz&platform=templates')
WANTED = ['version.txt', 'windows_release_x86_64.exe', 'linux_release.x86_64']
BLOCK = 8 * 1024 * 1024
# Il server rifiuta lo User-Agent predefinito di Python.
UA = {'User-Agent': 'jilly-jubilee-build/1.0'}


class HttpRangeFile(io.RawIOBase):
    """File remoto in sola lettura, letto a blocchi con richieste Range."""

    def __init__(self, url):
        req = urllib.request.Request(url, method='HEAD', headers=UA)
        with urllib.request.urlopen(req, timeout=60) as r:
            self.url = r.geturl()  # dopo i redirect
            self.size = int(r.headers['Content-Length'])
            if r.headers.get('Accept-Ranges', '') != 'bytes':
                raise RuntimeError('il server non accetta richieste Range')
        self.pos = 0
        self.cache = {}
        self.fetched = 0

    def readable(self):
        return True

    def seekable(self):
        return True

    def tell(self):
        return self.pos

    def seek(self, offset, whence=io.SEEK_SET):
        if whence == io.SEEK_SET:
            self.pos = offset
        elif whence == io.SEEK_CUR:
            self.pos += offset
        else:
            self.pos = self.size + offset
        return self.pos

    def _block(self, index):
        if index not in self.cache:
            start = index * BLOCK
            end = min(self.size, start + BLOCK) - 1
            req = urllib.request.Request(self.url, headers={**UA, 'Range': f'bytes={start}-{end}'})
            with urllib.request.urlopen(req, timeout=300) as r:
                data = r.read()
            if len(data) != end - start + 1:
                raise RuntimeError('risposta Range incompleta')
            self.fetched += len(data)
            if len(self.cache) > 6:
                self.cache.pop(next(iter(self.cache)))
            self.cache[index] = data
        return self.cache[index]

    def read(self, n=-1):
        if n is None or n < 0:
            n = self.size - self.pos
        n = max(0, min(n, self.size - self.pos))
        out = bytearray()
        while n > 0:
            index, offset = divmod(self.pos, BLOCK)
            chunk = self._block(index)[offset:offset + n]
            out += chunk
            self.pos += len(chunk)
            n -= len(chunk)
        return bytes(out)

    def readinto(self, b):
        data = self.read(len(b))
        b[:len(data)] = data
        return len(data)


def main():
    if all(os.path.exists(os.path.join(DEST, w)) for w in WANTED):
        print('Template già installati in', DEST)
        return
    os.makedirs(DEST, exist_ok=True)
    remote = HttpRangeFile(URL)
    print(f'Archivio remoto: {remote.size / 1e9:.2f} GB')
    with zipfile.ZipFile(remote) as z:
        names = {os.path.basename(n): n for n in z.namelist()}
        for w in WANTED:
            if w not in names:
                raise SystemExit(f'{w} non trovato nell\'archivio')
            target = os.path.join(DEST, w)
            with z.open(names[w]) as src, open(target + '.part', 'wb') as dst:
                while True:
                    buf = src.read(BLOCK)
                    if not buf:
                        break
                    dst.write(buf)
            os.replace(target + '.part', target)
            if not w.endswith('.txt'):
                os.chmod(target, 0o755)
            print(f'  {w}: {os.path.getsize(target) / 1e6:.1f} MB')
    print(f'Scaricati {remote.fetched / 1e6:.0f} MB invece di {remote.size / 1e6:.0f} MB -> {DEST}')


if __name__ == '__main__':
    main()
