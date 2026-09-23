# AirplaneAI

Chat offline per Android. In italiano gira [Dante 2B](https://www.dropbox.com/scl/fi/pvda2zh4831rwlavs6mhy/dante-2b-ita-instruct-Q4_K_M.gguf?rlkey=t1dij8u00r33pzd3gur0s9moq&st=av5hzlnq&dl=0), solo testo. In inglese e in cinese gira [MiniCPM-V 4.6](https://huggingface.co/openbmb/MiniCPM-V-4.6), testo e immagini. Tutto sul telefono, con llama.cpp, senza cloud.

La pagina del progetto: [lorenzomontorsi.github.io/AirplaneAI](https://lorenzomontorsi.github.io/AirplaneAI/)

## Scarica

L'APK dell'ultima versione è nella [release](https://github.com/LorenzoMontorsi/AirplaneAI/releases/latest).

| | |
| --- | --- |
| App | Android 8 o successivo, arm64-v8a o x86_64 |
| APK | circa 257 MB, non include il modello |
| Primo avvio | la lingua si sceglie prima del download. Italiano: Dante 2B, circa 1,2 GB, solo testo. Inglese o cinese: MiniCPM-V, circa 1,6 GB, con la visione |
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

I modelli non stanno nel repository. Al primo avvio l'app scarica Dante da Dropbox oppure MiniCPM-V da Hugging Face, a seconda della lingua.
