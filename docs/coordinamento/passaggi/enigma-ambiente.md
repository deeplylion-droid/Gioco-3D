# Passaggio: enigma-ambiente (21 ottobre)

**Branch** `lavoro/enigma-ambiente`, worktree `/home/user/wt/enigma-ambiente`, ultimo lavoro 295e9c6 (più questo file). Gli acquari sono già in `main` (v0.3.6); fiume, infermeria, lettore e keycard sono solo proposte.

**Scelte dell'utente (21 ottobre):** fiume **A** (giungla finta; la B resta da parte per riproporla), infermeria **B** (per bambini), **lettore 1** (strisciata anni '90, beige, spia tonda), **keycard 1** (tesserino bianco con foto, onde e banda magnetica).

## Cosa c'è e dove
- **Acquari e gorgo (in main):** `godot/scenes/sala/enigma_acquari.tscn`, `godot/assets/enigma_acquari/` (`acquario_vetro.gd`, `acquari_gorgo.gd`, `gorgo.gdshader`, `acqua_acquario.gdshader`, `vetro_acquario.gdshader`), colori in `godot/scripts/water/water_mix.gd` (COLORI). Generatori in `assets_src/enigma_acquari/` (`meshy_acquari.py`, `prepara_modelli.py`, `genera_scena.py`).
- **Fiume lento:** diorama `godot/proposte/fiume_aspetto/fiume_aspetto.gd` (`aspetto` "A"/"B": canale da Curve3D, conca, paratia, disco a strisce `disco_strisce.gdshader`, cartelli d'uscita, approdo, rocce, soffitto del capannone, arredo comune). Modelli in `godot/assets/fiume_lento/` (texture a 1024). Generatori in `assets_src/fiume_lento/`: `meshy_fiume.py`, `prepara_fiume.py` e `texture/genera_texture.py` (disco, uscita, pittogrammi, riga di calcare). Scartati e non usati: `ponte_corda`, `rete_stelle`.
- **Infermeria:** `godot/proposte/infermeria_aspetto/infermeria_aspetto.gd` (`aspetto`, `cassaforte_aperta`, `tessera`). Ogni modello ha `_A`, `_B` o `_N` (uguale nei due aspetti), in `godot/assets/infermeria/`. Il pulsante del parco viene da `assets/ambiente/sala/sala_interattivi.glb`. Il muro est ha il vano della cassaforte. Generatori in `assets_src/infermeria/`: `meshy_infermeria.py` (una preview e due refine), `prepara_infermeria.py` e `texture/` (radiografia 4-1-7, simboli, cifre delle rotelle, Polaroid A e B, adesivi).
- **Lettore e keycard:** `godot/proposte/tessera_aspetto/lettore_aspetto.gd` (`variante`, `sbloccato`, metodo `colora()`). Va sotto `LettoreTessera` con `mostra_segnaposto` falso. I modelli sono in `godot/assets/tessera/` (`lettore_1/2.glb`, `texture/tessera_1/2.png`); la keycard è disegnata in `infermeria_aspetto.gd` (`_tessera_a`). Generatori in `assets_src/tessera/`.
- **Logica (di enigma-logica):** `scripts/mechanisms/` (FiumeLento, TrattoFiume, ParatiaFiume, CartelloUscita, Negatoscopio, CassettoSchedario, CassaforteRotelle, LettoreTessera), nota `docs/proposte/fiume_infermeria/nota_logica.md`. I diorami sono solo aspetto: vanno portati nelle scene vere con queste classi.

## Strumenti e scatti
- `tests/scatti_fiume.gd <cartella> <A|B> [camere]` e `tests/scatti_infermeria.gd ...` (camera `tessera` da sola, con `TESSERA=1|2`): diorami leggeri, più scatti per processo.
- `tests/scatti_lettore.gd <cartella> "1:rosso:lontano,..."` nella sala vera, sempre con `tools/scatto_sicuro.sh` (memoria, lock), `SCATTI_TOGLI=Sala,Piscina,Vasche,Vasca,BambiniBalconata,Polaroid` e `ATTESA_FERMO=400`.
- Scatti per l'utente in `docs/proposte/{fiume_aspetto,infermeria_aspetto,tessera_lettore,acquari}/`.

## Trappole note
- **Memoria:** la sala intera supera 12,5 GB; togliendo le parti sopra si sta sotto i 10 GB. Tutto va sotto `flock render.lock`.
- **Import:** `bash tools/godot_importa.sh` senza argomenti, oppure con `godot`. Il `.` è la radice del repo e non importa niente. Senza import le scene caricano null.
- **Riflessi:** le macchie bianche seghettate sull'acqua erano i fari subacquei bruciati dalla loro luce. Ora sono unshaded e scuri, e l'acqua del fiume ha roughness 0,16. Non dipende dall'SSR.
- **CylinderMesh** usa solo metà della V sul lato: le rotelle hanno `uv1_scale.y = 2`. Il fronte dei modelli Meshy è +Z. Le texture nuove vanno importate prima dell'uso.
- Removing `Sala` nella scena dà errori di script innocui (LeiSbuca, LuciSala).

## Lavori aperti
1. Portare nelle scene vere fiume A, infermeria B, lettore 1 e keycard 1, con la logica di enigma-logica.
2. Infermeria: la Polaroid della pecora nella cassaforte è un segnaposto.
3. Spia del lettore: al buio rosso si distingue meno del verde.
4. Fiume: resta un piccolo riflesso dei fari in basso nel ramo.
5. Il fiume è un diorama di un pezzo del percorso: va fatto l'anello intero con i 3 bivi.
