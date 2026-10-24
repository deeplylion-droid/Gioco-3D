# Voci dello speaker: licenza

Le tre voci candidate (`voce_A_uomo_caldo`, `voce_B_uomo_squillante`, `voce_C_donna_sorridente`) sono fatte con **Kokoro-82M** (hexgrad, https://huggingface.co/hexgrad/Kokoro-82M), nella versione ONNX di onnx-community (https://huggingface.co/onnx-community/Kokoro-82M-v1.0-ONNX). Le voci del modello sono `am_michael`, `am_puck` e `af_heart`.

- **Licenza del modello: Apache 2.0**, controllata il 22 ottobre 2026 sulla scheda del modello (`license: apache-2.0`). La scheda dice: "This is an Apache-licensed model, and Kokoro has been deployed in numerous projects and commercial APIs. We welcome the deployment of the model in real use cases." **L'uso in un gioco commerciale è permesso.** L'audio generato non ha vincoli. La licenza Apache 2.0 chiede di citare l'autore nei crediti, se si distribuisce il modello; noi distribuiamo solo l'audio. Metterlo nei crediti è comunque corretto: "Voice: Kokoro-82M by hexgrad (Apache 2.0)".
- **Dati di addestramento** (dalla scheda): solo audio permissivo o senza diritti d'autore (pubblico dominio, audio Apache/MIT e audio sintetico di modelli chiusi). Dentro ci sono anche due raccolte CC BY, Koniwa (giapponese) e SIWIS (francese), elencate dall'autore nella scheda. Riguardano l'addestramento, non le voci inglesi che usiamo.
- **Programmi** usati per generare l'audio: kokoro-onnx (MIT), onnxruntime (MIT), espeak-ng attraverso phonemizer e espeakng-loader (GPL-3.0). espeak-ng serve solo a trasformare il testo in fonemi qui da noi, e nel gioco non entra. L'audio che esce non è coperto dalla GPL.
- La verifica che le frasi si capiscano è fatta con Whisper base.en (MIT), solo come controllo: nel gioco non entra.

Come si rigenera: `assets_src/spot/voce/genera_voci.py`. Il filtro "da TV" è a parte, in `assets_src/spot/voce/filtro_tv.sh`, e si può togliere: le frasi pulite sono in `assets_src/spot/voce/<voce>/frase_N.wav`.
