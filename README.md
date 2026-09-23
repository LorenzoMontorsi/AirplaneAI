# AirplaneAI

Chat offline per Android. In italiano gira [Gemma 3 1B](https://huggingface.co/unsloth/gemma-3-1b-it-GGUF), solo testo. In inglese e in cinese gira [MiniCPM-V 4.6](https://huggingface.co/openbmb/MiniCPM-V-4.6), testo e immagini. Tutto sul telefono, con llama.cpp, senza cloud.

La pagina del progetto: [lorenzomontorsi.github.io/AirplaneAI](https://lorenzomontorsi.github.io/AirplaneAI/)

## Scarica

L'APK dell'ultima versione è nella [release](https://github.com/LorenzoMontorsi/AirplaneAI/releases/latest).

| | |
| --- | --- |
| App | Android 8 o successivo, arm64-v8a o x86_64 |
| APK | circa 257 MB, non include il modello |
| Primo avvio | la lingua si sceglie prima del download. Italiano: Gemma 3 1B, circa 806 MB, solo testo. Inglese o cinese: MiniCPM-V, circa 1,6 GB, con la visione |
| Dopo | funziona senza rete |

Per installarla serve consentire le app di origine sconosciuta.

## Cosa fa

- Chat in streaming, tutta sul dispositivo.
- Foto da galleria o fotocamera, in inglese e in cinese. In italiano il modello è solo testo.
- Italiano, inglese o cinese, per il modello e per le scritte dell'app. La scelta resta salvata. Cambiare lingua scarica l'altro modello, se non c'è già.
- Il checkpoint di MiniCPM-V è Instruct: il ragionamento interno è spento, altrimenti mescola le lingue.

## Sviluppo

```bash
flutter pub get
flutter run
flutter build apk --release
```

I modelli non stanno nel repository. Al primo avvio l'app li scarica da Hugging Face: Gemma 3 in italiano, MiniCPM-V in inglese e in cinese.
