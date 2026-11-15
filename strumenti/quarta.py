#!/usr/bin/env python3
"""Quarta candidata della 0.4.0 = terza candidata + un commit che tocca SOLO i test.

Uso: quarta.py <sha della terza candidata> <sha del commit dei test> [prefisso ammesso, default godot/tests/]

Controlla che il commit dei test, rispetto alla sua base comune con la candidata, tocchi solo file sotto il
prefisso ammesso; unisce con merge-tree (nessun conflitto ammesso); crea il commit con due genitori (candidata e
commit dei test); ricontrolla che la differenza fra la terza e la quarta siano solo quei file e che versione e note
della Release siano rimaste. Stampa lo SHA sull'ultima riga. Non fa il push.
"""
import subprocess
import sys

REPO = "/home/user/Gioco-3D"
CODA = ("Co-Authored-By: Claude Fable 5.2 <noreply@anthropic.com>\n"
        "Claude-Session: https://claude.ai/code/session_01Ub9Z8mJaiFbdfRfYi8QhGz\n")


def git(*args, stdin=None, ok=(0,)):
    r = subprocess.run(["git", "-C", REPO, *args], input=stdin, capture_output=True, text=True)
    if r.returncode not in ok:
        raise SystemExit("git %s: %s%s" % (" ".join(args), r.stdout, r.stderr))
    return r.stdout


def main():
    terza, test = sys.argv[1], sys.argv[2]
    prefisso = sys.argv[3] if len(sys.argv) > 3 else "godot/tests/"
    terza = git("rev-parse", terza).strip()
    test = git("rev-parse", test).strip()
    base = git("merge-base", terza, test).strip()
    toccati = [f for f in git("diff", "--name-only", base, test).split("\n") if f]
    fuori = [f for f in toccati if not f.startswith(prefisso)]
    if not toccati:
        raise SystemExit("il commit dei test non cambia niente rispetto alla base %s" % base[:8])
    if fuori:
        raise SystemExit("il commit dei test tocca file fuori da %s: %s" % (prefisso, fuori))
    r = subprocess.run(["git", "-C", REPO, "merge-tree", "--write-tree", terza, test],
                       capture_output=True, text=True)
    if r.returncode != 0:
        raise SystemExit("conflitto nell'unione:\n%s%s" % (r.stdout, r.stderr))
    albero = r.stdout.strip().split("\n")[0]
    msg = ("Candidata 0.4.0, quarta: la terza (%s) più i controlli dei tempi della torre resi robusti al rumore\n\n"
           "Stessi file di gioco della terza candidata: cambiano solo %s\n"
           "(commit %s). I controlli «lei compare in X ms» e «la torre si costruisce a pezzi» misuravano una volta\n"
           "sola il tempo d'orologio, e sui runner lenti cadevano a caso (2 volte su 4 il 15 novembre, con\n"
           "87 e 174 ms contro 3-6 ms a runner tranquillo). La Prova su Vulkan della terza vale anche per questa.\n\n"
           % (terza[:8], ", ".join(toccati), test[:8]))
    sha = git("commit-tree", albero, "-p", terza, "-p", test, "-F", "-", stdin=msg + CODA).strip()
    diff = [f for f in git("diff", "--name-only", terza, sha).split("\n") if f]
    if sorted(diff) != sorted(toccati):
        raise SystemExit("la differenza fra terza e quarta non sono solo i file dei test: %s" % diff)
    versione = [r for r in git("show", "%s:godot/project.godot" % sha).split("\n") if r.startswith("config/version")]
    note = git("ls-tree", "--name-only", sha, "docs/release/v0.4.0.md").strip()
    if versione != ['config/version="0.4.0"'] or not note:
        raise SystemExit("versione o note mancanti: %s %s" % (versione, note))
    print("file cambiati rispetto alla terza:", diff)
    print(git("diff", "--stat", terza, sha).strip())
    print(sha)


if __name__ == "__main__":
    main()
