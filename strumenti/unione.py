#!/usr/bin/env python3
"""Unisce in memoria (merge-tree + commit-tree, senza worktree) i branch lavoro/<nome> e poi dei commit singoli
sopra origin/main. Risolve da solo solo il conflitto noto di game_state.gd. Non spinge niente.

Uso: unione.py "<titolo>" branch1,branch2,... [commit1,commit2,...]     (stampa lo SHA finale sull'ultima riga)
"""
import os, re, subprocess, sys, tempfile
REPO = "/home/user/Gioco-3D"
CODA = ("Co-Authored-By: Claude Fable 5.2 <noreply@anthropic.com>\n"
        "Claude-Session: https://claude.ai/code/session_01Ub9Z8mJaiFbdfRfYi8QhGz\n")
NOTO = "godot/scripts/game/game_state.gd"

def git(*args, stdin=None, env=None, check=True):
    r = subprocess.run(["git", "-C", REPO, *args], input=stdin, capture_output=True, text=True, env=env)
    if check and r.returncode != 0:
        raise SystemExit("git %s: %s%s" % (" ".join(args), r.stdout, r.stderr))
    return r

def risolvi_game_state(albero):
    testo = git("show", "%s:%s" % (albero, NOTO)).stdout
    m = re.search(r"<<<<<<< [^\n]*\n(.*?)=======\n(.*?)>>>>>>> [^\n]*\n", testo, re.S)
    if not m or testo.count("<<<<<<< ") != 1:
        raise SystemExit("conflitto in game_state.gd diverso da quello noto")
    a, b = m.group(1), m.group(2)
    righe = (a + b).strip("\n").split("\n")
    if not (any("stato_lei.gd" in r for r in righe) and any("stato_tunnel.gd" in r for r in righe)):
        raise SystemExit("conflitto in game_state.gd: non sono le due righe note:\n" + a + "---\n" + b)
    tunnel = [r for r in righe if "stato_tunnel.gd" in r]
    resto = [r for r in righe if "stato_tunnel.gd" not in r]
    nuovo = testo[:m.start()] + "\n".join(tunnel + resto) + "\n" + testo[m.end():]
    blob = git("hash-object", "-w", "--stdin", stdin=nuovo).stdout.strip()
    with tempfile.TemporaryDirectory() as d:
        env = dict(os.environ, GIT_INDEX_FILE=os.path.join(d, "indice"))
        git("read-tree", albero, env=env)
        git("update-index", "--cacheinfo", "100644,%s,%s" % (blob, NOTO), env=env)
        return git("write-tree", env=env).stdout.strip()

def unisci(cima, altro, base=None):
    args = ["merge-tree", "--write-tree", "--name-only"]
    if base:
        args.append("--merge-base=" + base)
    r = git(*args, cima, altro, check=False)
    righe = r.stdout.split("\n")
    albero = righe[0].strip()
    if r.returncode == 0:
        return albero, False
    fine = righe.index("") if "" in righe else len(righe)
    file_conflitto = sorted(set(x for x in righe[1:fine] if x))
    if file_conflitto != [NOTO]:
        raise SystemExit("CONFLITTO non previsto unendo %s: %s\n%s" % (altro, file_conflitto, r.stdout[-1500:]))
    return risolvi_game_state(albero), True

def main():
    titolo = sys.argv[1]
    branch = [b for b in sys.argv[2].split(",") if b]
    commit = [c for c in (sys.argv[3].split(",") if len(sys.argv) > 3 else []) if c]
    cima = git("rev-parse", "origin/main").stdout.strip()
    print("base: main", cima[:8])
    for b in branch:
        ref = "origin/lavoro/" + b
        sha = git("rev-parse", "--short=8", ref).stdout.strip()
        albero, risolto = unisci(cima, ref)
        msg = "%s: unione di lavoro/%s (%s)\n\n" % (titolo, b, sha)
        if risolto:
            msg += ("Conflitto in game_state.gd (reset_progress): tenute tutte e due le righe, stato_tunnel.gd e\n"
                    "stato_lei.gd azzerati con la partita nuova.\n\n")
        cima = git("commit-tree", albero, "-p", cima, "-p", ref, "-F", "-", stdin=msg + CODA).stdout.strip()
        print("OK", b, sha, "(conflitto noto risolto)" if risolto else "")
    for c in commit:
        padre = git("rev-parse", c + "^1").stdout.strip()
        albero, risolto = unisci(cima, c, base=padre)
        oggetto = git("log", "-1", "--format=%s", c).stdout.strip()
        msg = "%s: %s\n\nPortato il solo commit %s.\n\n" % (titolo, oggetto, c)
        cima = git("commit-tree", albero, "-p", cima, "-F", "-", stdin=msg + CODA).stdout.strip()
        print("OK commit", c, "|", oggetto[:70])
    marcatori = git("grep", "-l", "-E", "^(<<<<<<<|>>>>>>>) ", cima, "--", "godot", ".github", check=False).stdout.strip()
    if marcatori:
        raise SystemExit("marcatori di conflitto rimasti:\n" + marcatori)
    print(cima)

if __name__ == "__main__":
    main()
