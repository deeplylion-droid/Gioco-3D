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
- ogni get() (Dictionary.get e gli altri) e ogni funzione del file senza tipo di ritorno o con -> Variant accanto a un
  operatore;
- un parametro o una variabile locale senza tipo (var zz = 3) accanto a un operatore;
- ogni % e ogni / fra due interi (letterali senza punto, variabili int, .size()).
E nei thread di caricamento (ResourceLoader.load_threaded_request), in tutto godot/:
- negli script di Resource salvati nei .tres e nei .tscn (si costruiscono nel thread), anche incorporati nel file
  (sub_resource type="GDScript"), e nelle loro basi (extends "res://..." o un class_name): nessuna funzione, nessun
  setter o getter, nessun operatore nei valori dei var;
- nelle classi che quei var costruiscono (Altro.new(), con un class_name o un const preload, o preload("...").new()):
  nessun _init e nessun operatore nei valori dei var;
- nelle static var di ogni script (anche incorporato) nessun operatore nel valore e nessuna chiamata a una funzione dello
  stesso script che ha operatori (gira quando la classe si carica).
Il meno di un numero (-1.0) no: lo calcola il compilatore.
Non guarda (oggi nessun caso; da guardare a mano se arrivano): le funzioni di altri script senza tipo di ritorno dentro
un operatore (Altro.f() + 1); le proprietà di un oggetto senza tipo (o.x + 1); in una static var le funzioni di altri
script o quelle chiamate a loro volta; le classi costruite con load() da un percorso non scritto; le funzioni chiamate
da _init di una classe costruita.
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


def intestazione(righe, a):
    """La riga della func, con le righe che seguono finché la firma non è chiusa (parametri su più righe)."""
    t = senza_stringhe_e_commenti(righe[a])
    i = a
    while t.count("(") > t.count(")") and i + 1 < len(righe):
        i += 1
        t += " " + senza_stringhe_e_commenti(righe[i]).strip()
    return t


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
            if re.search(r"->\s*(Array|Dictionary)\s*:", intestazione(righe, a0))}
    # le funzioni del file che restituiscono Variant (senza tipo di ritorno o con -> Variant): dentro un operatore il
    # risultato è senza tipo
    ritorno_variant = {n for n, (a0, _b) in f.items()
            if not re.search(r"->", intestazione(righe, a0)) or re.search(r"->\s*Variant\b", intestazione(righe, a0))}
    trovati = []
    for nome in sorted(viste, key=lambda n: f[n][0]):
        a, b = f[nome]
        intest = senza_stringhe_e_commenti(righe[a])
        params = intest[intest.find("(") + 1:intest.rfind(")")].split(",")
        locali = set(membri)
        nudi = set()      # parametri e variabili locali senza tipo (var zz = 3): il nome stesso è senza tipo
        for p in params:
            m = re.match(r"\s*(\w+)\s*(:\s*(Array|Dictionary)\s*(=|$)|$)", p)
            if m and m.group(1):
                locali.add(m.group(1))
            m = re.match(r"\s*(\w+)\s*(=|$)", p)
            if m and m.group(1):
                nudi.add(m.group(1))
        corpo = [senza_stringhe_e_commenti(l) for l in righe[a + 1:b + 1]]
        cicli = set()
        for l in corpo:
            m = re.match(r"\s*var (\w+)\s*(=|$)", l)
            if m:
                nudi.add(m.group(1))
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
            # Dictionary.get() (e ogni get()) restituisce Variant; e le funzioni del file che restituiscono Variant
            for m in re.finditer(r"(?<![\w.])\w+(\.\w+)*\.get\(", l):
                fine = fine_catena(l, chiudi(l, m.end() - 1))
                if vicino_a_operatore(l, m.start(), fine):
                    trovati.append((num, nome, "get() restituisce Variant: accanto a un operatore", righe[num - 1].strip()))
            for g in ritorno_variant:
                for m in re.finditer(r"(?<![\w.])" + re.escape(g) + r"\(", l):
                    if re.match(r"\s*(static\s+)?func ", l):
                        continue
                    fine = fine_catena(l, chiudi(l, m.end() - 1))
                    if vicino_a_operatore(l, m.start(), fine):
                        trovati.append((num, nome, f"{g}() senza tipo di ritorno (Variant): accanto a un operatore",
                                righe[num - 1].strip()))
            for x in cicli | nudi:
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


def senza_commento(riga):
    """La riga senza il commento, con le stringhe com'erano (per i percorsi dei preload)."""
    i = STRINGA.sub(lambda m: "0" * len(m.group(0)), riga).find("#")
    return riga if i < 0 else riga[:i]


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


def file_risorse(radice):
    import glob
    import os
    return [f for f in sorted(glob.glob(os.path.join(radice, "**", "*.tscn"), recursive=True)
            + glob.glob(os.path.join(radice, "**", "*.tres"), recursive=True)) if os.sep + ".godot" + os.sep not in f]


def attributo(intestazione, nome):
    """Il valore di nome="..." nell'intestazione di un blocco ([ext_resource type="Script" uid="uid://…" id="1_x"]:
    l'id non è la fine di uid)."""
    m = re.search(r'(?<![\w])' + nome + r'="([^"]*)"', intestazione)
    return m.group(1) if m else None


def blocchi(testo):
    """(intestazione, corpo) per ogni blocco [ ... ] di un .tscn o .tres."""
    out = []
    for m in re.finditer(r"^\[([^\n]*)\]\n(.*?)(?=^\[|\Z)", testo, re.M | re.S):
        out.append((m.group(1), m.group(2)))
    return out


def incorporati(testo):
    """id -> sorgente degli script incorporati (sub_resource type="GDScript", script/source = "...")."""
    out = {}
    for intest, corpo in blocchi(testo):
        if intest.startswith("sub_resource") and attributo(intest, "type") == "GDScript":
            m = re.search(r'script/source = "((?:[^"\\]|\\.)*)"', corpo, re.S)
            if m and attributo(intest, "id"):
                out[attributo(intest, "id")] = re.sub(r"\\(.)", r"\1", m.group(1))
    return out


def sorgenti(radice):
    """chiave -> righe di ogni script: i .gd (chiave: il percorso del file) e gli script incorporati nei .tscn e nei
    .tres (chiave: file::id)."""
    import glob
    import os
    out = {}
    for f in sorted(glob.glob(os.path.join(radice, "**", "*.gd"), recursive=True)):
        if os.sep + ".godot" + os.sep not in f:
            out[f] = open(f, encoding="utf-8", errors="ignore").read().split("\n")
    for f in file_risorse(radice):
        for ide, src in incorporati(open(f, encoding="utf-8", errors="ignore").read()).items():
            out[f + "::" + ide] = src.split("\n")
    return out


def da_res(radice, res):
    import os
    return os.path.join(radice, res.replace("res://", "", 1))


def script_di_risorse(radice):
    """chiave dello script -> il file che lo carica: gli script delle risorse salvate (sottorisorse dei .tscn e dei
    .tres, e i .tres stessi), anche quelli incorporati."""
    trovati = {}
    for f in file_risorse(radice):
        t = open(f, encoding="utf-8", errors="ignore").read()
        ext = {}
        for intest, _c in blocchi(t):
            if intest.startswith("ext_resource") and attributo(intest, "type") == "Script" \
                    and attributo(intest, "path") and attributo(intest, "id"):
                ext[attributo(intest, "id")] = da_res(radice, attributo(intest, "path"))
        dentro = incorporati(t)
        for intest, corpo in blocchi(t):
            if intest.startswith("sub_resource") or intest.startswith("resource"):
                m = re.search(r'^script = (ExtResource|SubResource)\("([^"]+)"\)', corpo, re.M)
                if m and m.group(1) == "ExtResource" and m.group(2) in ext:
                    trovati.setdefault(ext[m.group(2)], f)
                elif m and m.group(1) == "SubResource" and m.group(2) in dentro:
                    trovati.setdefault(f + "::" + m.group(2), f)
    return trovati


def nomi_di_classe(radice, sorg):
    """class_name -> chiave dello script."""
    out = {}
    for k, righe in sorg.items():
        for l in righe:
            m = re.match(r"\s*(@\w+\s+)*class_name\s+(\w+)", l)
            if m:
                out[m.group(2)] = k
                break
    return out


def classe_di(radice, nome, righe, classi):
    """Lo script di un nome usato in righe: un class_name, o un const X := preload("res://...") dello stesso file."""
    for l in righe:
        m = re.match(r"\s*const\s+" + re.escape(nome) + r"\s*(:\s*\w+\s*)?:?=\s*preload\(\s*\"([^\"]+)\"\s*\)", l)
        if m:
            return da_res(radice, m.group(2))
    return classi.get(nome)


def base_di(radice, righe, classi):
    for l in righe:
        m = re.match(r"\s*extends\s+\"([^\"]+)\"", l)
        if m:
            return da_res(radice, m.group(1))
        m = re.match(r"\s*extends\s+(\w+)", l)
        if m:
            return classi.get(m.group(1))
    return None


def costruite(radice, testo, righe, classi):
    """Gli script costruiti in un'espressione: Altro.new(), preload("res://...").new(), load("res://...").new()."""
    out = []
    for m in re.finditer(r"(?<![\w.])(\w+)\.new\(", testo):
        k = classe_di(radice, m.group(1), righe, classi)
        if k:
            out.append(k)
    for m in re.finditer(r"\b(pre)?load\(\s*\"([^\"]+\.gd)\"\s*\)\.new\(", testo):
        out.append(da_res(radice, m.group(2)))
    return out


def controlla_script_nel_thread(radice, chiave, motivo, completo, sorg, classi, visti, trovati):
    """Le regole di uno script che si costruisce nel thread di caricamento. completo: uno script di Resource salvato
    (e le sue basi): nessuna funzione, setter o getter, nessun operatore nei valori dei var. Non completo: una classe
    costruita da lì con new(): nessun _init e nessun operatore nei valori dei var (le altre funzioni non girano)."""
    if (chiave, completo) in visti or chiave not in sorg:
        return
    visti.add((chiave, completo))
    righe = sorg[chiave]
    for num, t in istruzioni(righe):
        if re.match(r"(static\s+)?func\s", t):
            if completo or re.match(r"func\s+_init\b", t):
                trovati.append((chiave, num, f"funzione in uno script {motivo}", t))
        elif re.match(r"\s*(@\w+(\([^)]*\))?\s+)*var\s", t):
            if completo and re.search(r":\s*$|\b(set|get)\s*=", t):
                trovati.append((chiave, num, f"setter o getter in uno script {motivo}", t))
            v = inizializzatore(t)
            if v is not None and ha_operatore(v):
                trovati.append((chiave, num, f"operatore nel valore di un var di uno script {motivo}", t))
            if v is not None:
                # (preload("res://...").new() dalla riga com'è, con la stringa)
                for k in costruite(radice, v + " " + senza_commento(righe[num - 1]), righe, classi):
                    controlla_script_nel_thread(radice, k, f"costruito con new() da {chiave} nel thread di caricamento",
                            False, sorg, classi, visti, trovati)
    base = base_di(radice, righe, classi)
    if base:
        controlla_script_nel_thread(radice, base, f"base di {chiave} ({motivo})", completo, sorg, classi, visti, trovati)


def controlla_caricamento(radice, righe_trovate=None):
    trovati = []
    sorg = sorgenti(radice)
    classi = nomi_di_classe(radice, sorg)
    risorse = script_di_risorse(radice)
    visti = set()
    for chiave, da in sorted(risorse.items()):
        controlla_script_nel_thread(radice, chiave, f"di Resource (lo carica {da} nel thread)", True, sorg, classi,
                visti, trovati)
    for chiave, righe in sorted(sorg.items()):
        f = funzioni(righe)
        for num, t in istruzioni(righe):
            if re.match(r"(@\w+(\([^)]*\))?\s+)*static\s+var\s", t):
                v = inizializzatore(t)
                if v is None:
                    continue
                if ha_operatore(v):
                    trovati.append((chiave, num, "operatore nel valore di una static var (gira quando la classe si carica, anche nel thread)", t))
                    continue
                # una funzione dello stesso script con un operatore dentro
                for m in re.finditer(r"(?<![\w.])(\w+)\(", v):
                    if m.group(1) in f:
                        a, b = f[m.group(1)]
                        corpo = [codice(l) for l in righe[a + 1:b + 1]]
                        if any(ha_operatore(re.sub(r"^\s*(var\s+\w+\s*(:\s*[\w\[\]]+\s*)?:?=|return\b|\w+(\.\w+)*\s*=(?!=))", " ", l)) for l in corpo):
                            trovati.append((chiave, num, f"una static var chiama {m.group(1)}(), che ha operatori (gira quando la classe si carica, anche nel thread)", t))
                            break
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
    for f, righe_f in sorgenti(PROVA_CARICAMENTO).items():
        for i, l in enumerate(righe_f):
            if l.rstrip().endswith("# A RISCHIO"):
                attese.add((f, i + 1))
    # (gli script incorporati: un .tscn o .tres con "# A RISCHIO" deve dare almeno una riga attesa, se no la lettura
    # degli script incorporati non va e la prova passerebbe da sola)
    for f in file_risorse(PROVA_CARICAMENTO):
        if "# A RISCHIO" in open(f, encoding="utf-8").read() and not any(k.startswith(f + "::") for k, _n in attese):
            print(f"PROVA del caricamento: gli script incorporati di {f} non si leggono")
            esito = 1
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
