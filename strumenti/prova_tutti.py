#!/usr/bin/env python3
"""Sopra un commit (unione o candidata) mette un commit SOLO DI PROVA che cambia .github/workflows/build.yml cosi':
i passi di controllo e di test non fermano il job (continue-on-error), ogni comando fallito viene scritto in un
file (trap ERR via BASH_ENV) e alla fine un passo stampa l'elenco e fallisce se non e' vuoto. Niente esportazione,
niente artefatti, niente Release. Il branch di prova NON si unisce mai. Non spinge niente.

Uso: prova_tutti.py <sha>     (stampa lo SHA sull'ultima riga)
"""
import os, re, subprocess, sys, tempfile
REPO = "/home/user/Gioco-3D"
CODA = ("Co-Authored-By: Claude Fable 5.2 <noreply@anthropic.com>\n"
        "Claude-Session: https://claude.ai/code/session_01Ub9Z8mJaiFbdfRfYi8QhGz\n")
YML = ".github/workflows/build.yml"
PRIMO = "      - name: Texture del pacchetto compresse"
ESPORTA = "      - name: Esporta Windows e Linux"

def git(*args, stdin=None, env=None):
    r = subprocess.run(["git", "-C", REPO, *args], input=stdin, capture_output=True, text=True, env=env)
    if r.returncode != 0:
        raise SystemExit("git %s: %s%s" % (" ".join(args), r.stdout, r.stderr))
    return r.stdout

TRAPPOLA = """      - name: (branch di prova) i comandi falliti si scrivono in un file e il job va avanti
        run: |
          cat > "$RUNNER_TEMP/trappola.sh" <<'FINE'
          trap 'echo "FALLITO ($0): $BASH_COMMAND" >> "$RUNNER_TEMP/falliti.txt"' ERR
          FINE
          echo "BASH_ENV=$RUNNER_TEMP/trappola.sh" >> "$GITHUB_ENV"

"""
RIEPILOGO = """      - name: (branch di prova) riepilogo dei comandi falliti
        if: always()
        run: |
          echo "=== RIEPILOGO DEL BRANCH DI PROVA ==="
          if [ -s "$RUNNER_TEMP/falliti.txt" ]; then cat "$RUNNER_TEMP/falliti.txt"; echo "=== FINE RIEPILOGO: CI SONO COMANDI FALLITI ==="; exit 1; fi
          echo "=== FINE RIEPILOGO: NESSUN COMANDO FALLITO ==="
"""

def main():
    unione = sys.argv[1]
    righe = git("show", "%s:%s" % (unione, YML)).split("\n")
    if "continue-on-error" in "\n".join(righe):
        raise SystemExit("il workflow ha gia' dei continue-on-error: guardalo a mano")
    i_checkout = [i for i, r in enumerate(righe) if r == "      - uses: actions/checkout@v4"]
    i_primo = [i for i, r in enumerate(righe) if r.startswith(PRIMO)]
    i_esporta = [i for i, r in enumerate(righe) if r.startswith(ESPORTA)]
    if not (len(i_checkout) == len(i_primo) == len(i_esporta) == 1):
        raise SystemExit("struttura del workflow diversa da quella attesa: %s %s %s" % (i_checkout, i_primo, i_esporta))
    fuori = []
    n = 0
    for i, r in enumerate(righe[:i_esporta[0]]):
        fuori.append(r)
        if i == i_checkout[0]:
            fuori.append("")
            fuori.extend(TRAPPOLA.rstrip("\n").split("\n"))
        if i >= i_primo[0] and r.startswith("      - name: "):
            fuori.append("        continue-on-error: true")
            n += 1
    while fuori and fuori[-1] == "":
        fuori.pop()
    fuori.append("")
    fuori.extend(RIEPILOGO.rstrip("\n").split("\n"))
    nuovo = "\n".join(fuori) + "\n"
    blob = git("hash-object", "-w", "--stdin", stdin=nuovo).strip()
    with tempfile.TemporaryDirectory() as d:
        env = dict(os.environ, GIT_INDEX_FILE=os.path.join(d, "indice"))
        git("read-tree", unione, env=env)
        git("update-index", "--cacheinfo", "100644,%s,%s" % (blob, YML), env=env)
        albero = git("write-tree", env=env).strip()
    msg = ("SOLO PROVA, non unire: la CI gira tutti i test senza fermarsi al primo rosso\n\n"
           "Sopra %s. Cambia solo il workflow di questo branch: i %d passi di controllo e di test hanno\n"
           "continue-on-error, ogni comando fallito finisce in un elenco stampato dall'ultimo passo, niente\n"
           "esportazione, artefatti o Release. Serve a vedere in un giro solo tutti i test da sistemare prima\n"
           "della candidata vera.\n\n" % (unione[:8], n))
    sha = git("commit-tree", albero, "-p", unione, "-F", "-", stdin=msg + CODA).strip()
    print(git("diff", "--stat", unione, sha).strip())
    print("passi con continue-on-error:", n)
    print(sha)

if __name__ == "__main__":
    main()
