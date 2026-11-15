#!/usr/bin/env python3
"""Sopra un commit d'unione mette il commit della candidata: versione nuova in godot/project.godot e note della
Release in docs/release/v<versione>.md. Tutto in memoria (indice temporaneo), senza worktree. Non spinge niente.

Uso: candidata.py <sha dell'unione> <versione> <file delle note> "<riassunto per il messaggio di commit>"
Stampa lo SHA del commit sull'ultima riga.
"""
import os, re, subprocess, sys, tempfile
REPO = "/home/user/Gioco-3D"
CODA = ("Co-Authored-By: Claude Fable 5.2 <noreply@anthropic.com>\n"
        "Claude-Session: https://claude.ai/code/session_01Ub9Z8mJaiFbdfRfYi8QhGz\n")
PROGETTO = "godot/project.godot"

def git(*args, stdin=None, env=None):
    r = subprocess.run(["git", "-C", REPO, *args], input=stdin, capture_output=True, text=True, env=env)
    if r.returncode != 0:
        raise SystemExit("git %s: %s%s" % (" ".join(args), r.stdout, r.stderr))
    return r.stdout

def main():
    unione, versione, file_note, riassunto = sys.argv[1:5]
    if not re.fullmatch(r"\d+\.\d+\.\d+", versione):
        raise SystemExit("versione non valida: " + versione)
    note = open(file_note, encoding="utf-8").read()
    if "DA CONFERMARE" in note or "SOLO SE" in note:
        raise SystemExit("le note hanno ancora dei segnaposto")
    if ("versione %s" % versione) not in note.split("\n", 1)[0]:
        raise SystemExit("il titolo delle note non nomina la versione " + versione)
    if ("-v%s.exe" % versione) not in note:
        raise SystemExit("le note non nominano l'exe della versione " + versione)
    progetto = git("show", "%s:%s" % (unione, PROGETTO))
    nuovo, n = re.subn(r'^config/version="[^"]*"$', 'config/version="%s"' % versione, progetto, flags=re.M)
    if n != 1:
        raise SystemExit("config/version non trovata una volta sola in project.godot (%d)" % n)
    blob_progetto = git("hash-object", "-w", "--stdin", stdin=nuovo).strip()
    blob_note = git("hash-object", "-w", "--stdin", stdin=note).strip()
    with tempfile.TemporaryDirectory() as d:
        env = dict(os.environ, GIT_INDEX_FILE=os.path.join(d, "indice"))
        git("read-tree", unione, env=env)
        git("update-index", "--cacheinfo", "100644,%s,%s" % (blob_progetto, PROGETTO), env=env)
        git("update-index", "--add", "--cacheinfo", "100644,%s,docs/release/v%s.md" % (blob_note, versione), env=env)
        albero = git("write-tree", env=env).strip()
    msg = "Candidata %s: versione %s e note della Release (%s)\n\n" % (versione, versione, riassunto)
    sha = git("commit-tree", albero, "-p", unione, "-F", "-", stdin=msg + CODA).strip()
    print(git("diff", "--stat", unione, sha).strip())
    print(sha)

if __name__ == "__main__":
    main()
