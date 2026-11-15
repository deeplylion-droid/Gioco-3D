#!/usr/bin/env python3
"""Unione di una candidata in main, senza toccare il working tree e senza push.

Uso: unisci_main.py <sha della candidata> <file col messaggio>

- scarica main; se la candidata discende dalla punta di main, il commit di unione ha l'albero della candidata
  (differenza 0 dalla candidata provata); se main si è mosso (solo documenti), usa merge-tree e rifiuta i conflitti;
- rifiuta un messaggio con «DA COMPLETARE» o senza le righe di attribuzione;
- controlla versione e note della Release nell'albero finale;
- stampa lo SHA sull'ultima riga. Il push si fa a mano: git push origin <sha>:refs/heads/main
"""
import re
import subprocess
import sys

REPO = "/home/user/Gioco-3D"


def git(*args, stdin=None, ok=(0,)):
    r = subprocess.run(["git", "-C", REPO, *args], input=stdin, capture_output=True, text=True)
    if r.returncode not in ok:
        raise SystemExit("git %s: %s%s" % (" ".join(args), r.stdout, r.stderr))
    return r.stdout


def main():
    cand = git("rev-parse", sys.argv[1]).strip()
    msg = open(sys.argv[2], encoding="utf-8").read()
    if "DA COMPLETARE" in msg or "DA CONFERMARE" in msg:
        raise SystemExit("il messaggio ha ancora parti da completare")
    if "Co-Authored-By:" not in msg or "Claude-Session:" not in msg:
        raise SystemExit("mancano le righe di attribuzione in fondo al messaggio")
    if re.search(r"claude-[a-z]+-\d", msg):
        raise SystemExit("nel messaggio c'è un identificativo di modello")
    git("fetch", "-q", "--shallow-since=2026-11-01", "origin", "+refs/heads/main:refs/remotes/origin/main")
    main_sha = git("rev-parse", "origin/main").strip()
    base = git("merge-base", main_sha, cand).strip()
    if base == main_sha:
        albero = git("rev-parse", cand + "^{tree}").strip()
        modo = "albero della candidata (main non si è mosso)"
    else:
        r = subprocess.run(["git", "-C", REPO, "merge-tree", "--write-tree", main_sha, cand],
                           capture_output=True, text=True)
        if r.returncode != 0:
            raise SystemExit("conflitto fra main e la candidata:\n%s%s" % (r.stdout, r.stderr))
        albero = r.stdout.strip().split("\n")[0]
        mossi = [f for f in git("diff", "--name-only", base, main_sha).split("\n") if f]
        fuori = [f for f in mossi if not f.startswith("docs/")]
        if fuori:
            raise SystemExit("main si è mosso fuori da docs/: %s" % fuori)
        modo = "merge-tree (main si è mosso solo in docs/: %s)" % ", ".join(mossi)
    sha = git("commit-tree", albero, "-p", main_sha, "-p", cand, "-F", "-", stdin=msg).strip()
    diff = [f for f in git("diff", "--name-only", cand, sha).split("\n") if f]
    fuori = [f for f in diff if not f.startswith("docs/")]
    if fuori:
        raise SystemExit("l'unione differisce dalla candidata fuori da docs/: %s" % fuori)
    progetto = git("show", "%s:godot/project.godot" % sha)
    versione = [r for r in progetto.split("\n") if r.startswith("config/version")]
    v = versione[0].split('"')[1] if versione else ""
    if not v or not git("ls-tree", "--name-only", sha, "docs/release/v%s.md" % v).strip():
        raise SystemExit("versione o note della Release mancanti: %s" % versione)
    print("main:", main_sha[:8], "| candidata:", cand[:8], "| modo:", modo)
    print("differenza dalla candidata:", diff if diff else "nessuna")
    print("versione:", v, "| note: docs/release/v%s.md" % v)
    print(git("diff", "--shortstat", main_sha, sha).strip())
    print(sha)


if __name__ == "__main__":
    main()
