#!/usr/bin/env python3
"""Controllo statico della morbidezza in parallelo (MorbidezzaLei): nelle funzioni che girano sui thread del pool
(_lavora e tutto quello che chiama, nello stesso file) nessun operatore con un operando senza tipo e nessun int % int o
int / int.

Perché: in Godot 4.7.2 la prima volta che un operatore senza tipo gira (OPCODE_OPERATOR) la VM di GDScript riscrive il
bytecode (firma, tipo, poi il puntatore della funzione) sotto un lucchetto che chi legge non prende: un altro thread
che passa di lì nello stesso momento può chiamare un puntatore nullo (signal 11 in test_morbidezza_tunnel alla presa,
30 ottobre; prova in docs/tecnico/crash_operatori_thread). Nel release passano di lì anche int / int e int % int.

Cosa guarda, riga per riga (senza commenti e stringhe):
- un elemento di un contenitore senza tipo (variabili, parametri e membri Array o Dictionary senza tipo, e le variabili
  dei for su di loro) accanto a un operatore, se non è dentro (... as Tipo) o int(), float(), bool();
- una variabile di un for su un contenitore senza tipo accanto a un operatore;
- ogni % e ogni / fra due interi (letterali senza punto, variabili int, .size()).
E nei thread di caricamento (ResourceLoader.load_threaded_request), in tutto godot/:
- negli script di Resource salvati nei .tres e nei .tscn (si costruiscono nel thread): nessuna funzione, nessun setter o
  getter, nessun operatore nei valori dei var;
- nelle static var di ogni script nessun operatore nel valore (gira quando la classe si carica).
Il meno di un numero (-1.0) no: lo calcola il compilatore.
Uso: python3 tools/ci/morbidezza_operatori.py [file]   (esce con 1 se trova qualcosa; senza file anche il caricamento)
     python3 tools/ci/morbidezza_operatori.py --prova  (il controllo stesso: sul file di prova tools/ci/prove/operatori_prova.gd
     deve trovare tutte e sole le righe segnate "# A RISCHIO", e lo stesso nella cartella tools/ci/prove/caricamento)
"""
import re
import sys

FILE = sys.argv[1] if len(sys.argv) > 1 else "godot/scripts/environment/morbidezza_lei.gd"
PROVA = "tools/ci/prove/operatori_prova.gd"
PROVA_CARICAMENTO = "tools/ci/prove/caricamento"
RADICE = "_lavora"

OPERATORI = ["+=", "-=", "*=", "/=", "%=", "==", "!=", "<=", ">=", "+", "-", "*", "/", "%", "<", ">"]
PAROLE = ["and", "or", "not", "in"]


def senza_stringhe_e_commenti(riga):
    out = []
    dentro = None
    for c in riga:
        if dentro:
            out.append(" ")
            if c == dentro:
                dentro = None
            continue
        if c in "\"'":
            dentro = c
            out.append(" ")
            continue
        if c == "#":
            break
        out.append(c)
    return "".join(out)


def funzioni(righe):
    f = {}
    cur = None
    for i, l in enumerate(righe):
        m = re.match(r"^(static )?func (\w+)\((.*)", l)
        if m:
            cur = m.group(2)
            f[cur] = [i, i]
            continue
        if cur is not None:
            if l and not l[0].isspace() and not l.startswith("#"):
                cur = None
            else:
                f[cur][1] = i
    return f


def chiamate(righe, f):
    out = {}
    for nome, (a, b) in f.items():
        corpo = "\n".join(senza_stringhe_e_commenti(l) for l in righe[a:b + 1])
        out[nome] = {g for g in f if g != nome and re.search(r"(?<![\w])" + g + r"\(", corpo)}
    return out


def senza_tipo_membri(righe):
    nomi = set()
    for l in righe:
        if l.startswith("var ") or l.startswith("static var "):
            m = re.match(r"^(?:static )?var (\w+)\s*(:\s*(Array|Dictionary)\s*(=|$)|:=\s*(\[|\{))", l)
            if m:
                nomi.add(m.group(1))
    return nomi


def chiudi(s, i):
    """Indice dopo la parentesi che chiude quella aperta in s[i]."""
    apre = s[i]
    chiude = {"[": "]", "(": ")"}[apre]
    p = 0
    for j in range(i, len(s)):
        if s[j] in "[(":
            p += 1
        elif s[j] in "])":
            p -= 1
            if p == 0:
                return j + 1
    return len(s)


def fine_catena(s, i):
    """Dalla fine di un elemento senza tipo, segue altri indici, metodi e proprietà (fo[0].size(), mo[3][1].end): il
    risultato è ancora senza tipo. Restituisce dove finisce la catena."""
    while i < len(s):
        if s[i] == "[":
            i = chiudi(s, i)
            continue
        m = re.match(r"\.\w+", s[i:])
        if m:
            i += m.end()
            if i < len(s) and s[i] == "(":
                i = chiudi(s, i)
            continue
        break
    return i


# Le funzioni globali che restituiscono Variant (le versioni con la f, absf, clampf, maxf..., e quelle con la i sono
# tipizzate): dentro un operatore il risultato è senza tipo.
FUNZIONI_VARIANT = ["abs", "sign", "floor", "ceil", "round", "clamp", "lerp", "snapped", "wrap", "max", "min"]


def vicino_a_operatore(s, a, b):
    """L'espressione s[a:b] ha un operatore subito prima o subito dopo (e non è un cast o una conversione)?"""
    prima = s[:a].rstrip()
    dopo = s[b:].lstrip()
    if re.match(r"^\s*for [\w: \[\]]+ in$", prima) and dopo.startswith(":"):
        return False      # il contenitore di un for, non l'operatore in
    if dopo.startswith("as ") or re.match(r"^\)\s*as\b", dopo):
        return False
    if re.search(r"\b(int|float|bool|str)\($", prima) or re.search(r"\(\s*$", prima) and re.match(r"^\)\s*as\b", dopo):
        return False
    if re.match(r"^\[", dopo):
        return False      # un altro indice: lo guarda chi chiama, alla fine della catena
    for o in OPERATORI:
        assegna = dopo.startswith("=") and not dopo.startswith("==")
        if dopo.startswith(o) and not assegna and not (o in "<>" and dopo.startswith(o + o)):
            if o in ("-", "+") and dopo.startswith(o + ">"):
                continue
            return True
        if prima.endswith(o) and not prima.endswith(":=") and not re.search(r"(^|[^=!<>:+\-*/%])=$", prima):
            if o == ">" and prima.endswith("->"):
                continue
            return True
    for w in PAROLE:
        if re.match(r"^" + w + r"\b", dopo) or re.search(r"\b" + w + r"$", prima):
            return True
    return False


def interi(corpo_righe, params):
    nomi = set()
    for p in params:
        m = re.match(r"\s*(\w+)\s*:\s*int\b", p)
        if m:
            nomi.add(m.group(1))
    for l in corpo_righe:
        for m in re.finditer(r"\bvar (\w+)\s*(:\s*int\b|:=\s*-?\d+\s*$|:=\s*-?\d+\s*[^.\d])", l):
            nomi.add(m.group(1))
        m = re.match(r"\s*for (\w+) in (range\(|\w+\s*:|\d|n\b|[\w.]+\.size\(\)|\w+ \+ \d)", l)
        if m:
            nomi.add(m.group(1))
    return nomi


def operando_intero(t, interi_nomi):
    t = t.strip()
    if re.fullmatch(r"\d+", t):
        return True
    if t in interi_nomi:
        return True
    if re.fullmatch(r"[\w.\[\]]+\.size\(\)", t):
        return True
    return False


def controlla(percorso, righe_trovate=None):
    righe = open(percorso, encoding="utf-8").read().split("\n")
    f = funzioni(righe)
    if RADICE not in f:
        print(f"morbidezza_operatori: {RADICE} non c'è in {percorso}")
        return 1
    ch = chiamate(righe, f)
    viste = set()
    da_fare = [RADICE]
    while da_fare:
        n = da_fare.pop()
        if n in viste:
            continue
        viste.add(n)
        da_fare += list(ch.get(n, []))
    membri = senza_tipo_membri(righe)
    senza_tipo_ritorno = {n for n, (a0, _b) in f.items()
            if re.search(r"->\s*(Array|Dictionary)\s*:", righe[a0])}
    trovati = []
    for nome in sorted(viste, key=lambda n: f[n][0]):
        a, b = f[nome]
        intest = senza_stringhe_e_commenti(righe[a])
        params = intest[intest.find("(") + 1:intest.rfind(")")].split(",")
        locali = set(membri)
        for p in params:
            m = re.match(r"\s*(\w+)\s*(:\s*(Array|Dictionary)\s*(=|$)|$)", p)
            if m and m.group(1):
                locali.add(m.group(1))
        corpo = [senza_stringhe_e_commenti(l) for l in righe[a + 1:b + 1]]
        cicli = set()
        for l in corpo:
            m = re.match(r"\s*var (\w+)\s*(:\s*(Array|Dictionary)\s*=|:=\s*(\[|\{))", l)
            if m:
                locali.add(m.group(1))
            # := dal risultato di una funzione del file che restituisce un Array o un Dictionary senza tipo
            m = re.match(r"\s*var (\w+)\s*:=\s*(\w+)\(", l)
            if m and m.group(2) in senza_tipo_ritorno:
                locali.add(m.group(1))
        # le variabili dei for senza tipo su un contenitore senza tipo (o su una funzione che restituisce Array)
        for l in corpo:
            m = re.match(r"\s*for (\w+) in (.+):\s*$", l)
            if m:
                it = m.group(2)
                if re.search(r"\.size\(\)\s*$|^range\(|^\d+$", it.strip()):
                    continue      # un for sugli interi
                if any(re.search(r"\b" + re.escape(x) + r"\b", it) for x in locali) or re.search(r"_forme_in\(|\.get\(", it):
                    cicli.add(m.group(1))
        interi_nomi = interi(corpo, params)
        for k, l in enumerate(corpo):
            num = a + 2 + k
            # elementi di contenitori senza tipo accanto a un operatore
            for x in locali | cicli:
                for m in re.finditer(r"(?<![\w.])" + re.escape(x) + r"\[", l):
                    fine = fine_catena(l, chiudi(l, m.end() - 1))
                    if vicino_a_operatore(l, m.start(), fine):
                        trovati.append((num, nome, f"{x}[…] senza tipo accanto a un operatore", righe[num - 1].strip()))
            for fn in FUNZIONI_VARIANT:
                for m in re.finditer(r"(?<![\w.])" + fn + r"\(", l):
                    fine = fine_catena(l, chiudi(l, m.end() - 1))
                    if vicino_a_operatore(l, m.start(), fine):
                        trovati.append((num, nome, f"{fn}() restituisce Variant: accanto a un operatore",
                                righe[num - 1].strip()))
            for x in cicli:
                for m in re.finditer(r"(?<![\w.])" + re.escape(x) + r"(?![\w\[(])", l):
                    if re.match(r"\s*for ", l):
                        continue
                    if vicino_a_operatore(l, m.start(), m.end()):
                        trovati.append((num, nome, f"{x} (senza tipo) accanto a un operatore", righe[num - 1].strip()))
            if re.search(r"(?<![%])%(?![=%])", l):
                trovati.append((num, nome, "% (int % int passa dall'operatore a rischio nel release)", righe[num - 1].strip()))
            for m in re.finditer(r"([\w.\[\]()]+)\s*/\s*([\w.\[\]()]+)", l):
                if operando_intero(m.group(1), interi_nomi) and operando_intero(m.group(2), interi_nomi):
                    trovati.append((num, nome, "int / int (passa dall'operatore a rischio nel release)", righe[num - 1].strip()))
    print(f"morbidezza_operatori: {len(viste)} funzioni sui thread ({', '.join(sorted(viste))})")
    for t in trovati:
        print(f"  {percorso}:{t[0]} ({t[1]}): {t[2]}\n      {t[3]}")
    print(f"RISULTATO: {len(trovati)} operatori a rischio")
    if righe_trovate is not None:
        righe_trovate.update(t[0] for t in trovati)
    return 1 if trovati else 0


# --- Il codice che gira sui thread di caricamento (ResourceLoader.load_threaded_request) ---
# Caricare una scena non istanzia i nodi, ma le sottorisorse con uno script (in un .tres o in un .tscn) si costruiscono
# nel thread: il loro inizializzatore (i valori dei var), _init e i setter girano lì, anche in due thread insieme se due
# file con lo stesso script si caricano insieme. E gli inizializzatori delle static var girano quando la classe si carica,
# anche nel thread. Lì nessun operatore (e negli script di Resource nemmeno funzioni o setter): oggi non ce ne sono, se
# un giorno ne arriva uno la CI lo dice.
OPERATORI_CARICAMENTO = re.compile(r"\*\*|<<|>>|==|!=|<=|>=|[+\-*/%<>&|^~]|\b(and|or|not|in)\b")
STRINGA = re.compile(r"""[&^]?("([^"\\]|\\.)*"|'([^'\\]|\\.)*')""")


def codice(riga):
    """La riga senza commenti, con ogni stringa (anche &"..." e ^"...") al posto di un valore qualsiasi."""
    return senza_stringhe_e_commenti(STRINGA.sub("0", riga))


def ha_operatore(espr):
    """Un operatore nell'espressione, a parte il meno di un numero (-1.0, Vector3(0, -1, 0)), che il compilatore
    calcola da solo."""
    e = re.sub(r"(^|[(\[{,:=]\s*)-\s*(?=\d|\.\d)", r"\1", espr.strip())
    e = re.sub(r"\d+(\.\d*)?[eE]-\d+", "0", e)      # 1e-6
    e = e.replace("->", " ")
    return OPERATORI_CARICAMENTO.search(e) is not None


def istruzioni(righe):
    """(numero della prima riga, testo) per ogni istruzione di primo livello, unendo le righe con le parentesi aperte
    o con la barra in fondo."""
    out = []
    i = 0
    while i < len(righe):
        testo = codice(righe[i])
        num = i + 1
        while (testo.count("(") + testo.count("[") + testo.count("{") > testo.count(")") + testo.count("]")
                + testo.count("}") or testo.rstrip().endswith("\\")) and i + 1 < len(righe):
            i += 1
            testo = testo.rstrip().rstrip("\\") + " " + codice(righe[i]).strip()
        out.append((num, testo))
        i += 1
    return out


def inizializzatore(testo):
    """Il valore di un var (dopo = o :=), senza le annotazioni davanti; None se non c'è."""
    m = re.match(r"\s*(@\w+(\([^)]*\))?\s+)*(static\s+)?var\s+\w+\s*(:\s*[\w\[\]. ]*)?:?=(.*)$", testo)
    if not m:
        return None
    v = m.group(5)
    v = re.split(r":\s*$|\bset\s*=|\bget\s*=", v)[0]
    return v


def script_di_risorse(radice):
    """Gli script delle risorse salvate (sottorisorse dei .tscn e .tres, e i .tres stessi)."""
    import glob
    import os
    trovati = {}
    for f in sorted(glob.glob(os.path.join(radice, "**", "*.tscn"), recursive=True)
            + glob.glob(os.path.join(radice, "**", "*.tres"), recursive=True)):
        if os.sep + ".godot" + os.sep in f:
            continue
        t = open(f, encoding="utf-8", errors="ignore").read()
        ext = {}
        for m in re.finditer(r"\[ext_resource ([^\]]*)\]", t):
            a = m.group(1)
            tipo = re.search(r'type="(\w+)"', a)
            pth = re.search(r'path="([^"]+)"', a)
            ide = re.search(r'id="([^"]+)"', a)
            if tipo and tipo.group(1) == "Script" and pth and ide:
                ext[ide.group(1)] = pth.group(1)
        for blocco in re.split(r"\n(?=\[)", t):
            if blocco.startswith("[sub_resource") or blocco.startswith("[resource]"):
                m = re.search(r'\nscript = ExtResource\("([^"]+)"\)', blocco)
                if m and m.group(1) in ext:
                    trovati.setdefault(ext[m.group(1)], f)
    return trovati


def controlla_caricamento(radice, righe_trovate=None):
    import glob
    import os
    trovati = []
    risorse = script_di_risorse(radice)
    for res, da in sorted(risorse.items()):
        percorso = os.path.join(radice, res.replace("res://", "", 1))
        if not os.path.exists(percorso):
            continue
        righe = open(percorso, encoding="utf-8").read().split("\n")
        for num, t in istruzioni(righe):
            if re.match(r"(static\s+)?func\s", t):
                trovati.append((percorso, num, f"funzione in uno script di Resource (lo carica {da} nel thread)", t))
            elif re.match(r"\s*(@\w+(\([^)]*\))?\s+)*var\s", t):
                if re.search(r":\s*$|\b(set|get)\s*=", t):
                    trovati.append((percorso, num, f"setter o getter in uno script di Resource (lo carica {da} nel thread)", t))
                v = inizializzatore(t)
                if v is not None and ha_operatore(v):
                    trovati.append((percorso, num, f"operatore nel valore di un var di uno script di Resource (lo carica {da} nel thread)", t))
    for percorso in sorted(glob.glob(os.path.join(radice, "**", "*.gd"), recursive=True)):
        if os.sep + ".godot" + os.sep in percorso:
            continue
        righe = open(percorso, encoding="utf-8", errors="ignore").read().split("\n")
        for num, t in istruzioni(righe):
            if re.match(r"(@\w+(\([^)]*\))?\s+)*static\s+var\s", t):
                v = inizializzatore(t)
                if v is not None and ha_operatore(v):
                    trovati.append((percorso, num, "operatore nel valore di una static var (gira quando la classe si carica, anche nel thread)", t))
    print(f"caricamento: {len(risorse)} script di Resource salvati nei file, static var di tutti gli script")
    for t in trovati:
        print(f"  {t[0]}:{t[1]}: {t[2]}\n      {t[3].strip()}")
    print(f"RISULTATO: {len(trovati)} cose a rischio nei thread di caricamento")
    if righe_trovate is not None:
        righe_trovate.update((t[0], t[1]) for t in trovati)
    return 1 if trovati else 0


def prova():
    """Il controllo sul file di prova: tutte e sole le righe di codice segnate "# A RISCHIO"."""
    righe = open(PROVA, encoding="utf-8").read().split("\n")
    attese = {i + 1 for i, l in enumerate(righe) if l.rstrip().endswith("# A RISCHIO")}
    trovate = set()
    controlla(PROVA, trovate)
    mancate = sorted(attese - trovate)
    in_piu = sorted(trovate - attese)
    print(f"PROVA: {len(attese)} righe a rischio nel file di prova; mancate {mancate}, trovate in più {in_piu}")
    esito = 1 if mancate or in_piu else 0
    # e i thread di caricamento: nella cartella di prova, le righe segnate in tutti i suoi .gd
    import glob
    import os
    attese = set()
    for f in glob.glob(os.path.join(PROVA_CARICAMENTO, "**", "*.gd"), recursive=True):
        for i, l in enumerate(open(f, encoding="utf-8").read().split("\n")):
            if l.rstrip().endswith("# A RISCHIO"):
                attese.add((f, i + 1))
    trovate = set()
    controlla_caricamento(PROVA_CARICAMENTO, trovate)
    mancate = sorted(attese - trovate)
    in_piu = sorted(trovate - attese)
    print(f"PROVA del caricamento: {len(attese)} righe a rischio; mancate {mancate}, trovate in più {in_piu}")
    return esito or (1 if mancate or in_piu else 0)


if __name__ == "__main__":
    if FILE == "--prova":
        sys.exit(prova())
    sys.exit(controlla(FILE) | (controlla_caricamento("godot") if len(sys.argv) == 1 else 0))
