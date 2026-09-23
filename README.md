# AirplaneAI

Chat multimodale offline per Android. [MiniCPM-V 4.6](https://huggingface.co/openbmb/MiniCPM-V-4.6) gira sul telefono con llama.cpp: testo e immagini, senza cloud. L'interfaccia e le risposte possono essere in italiano, inglese o cinese.

La pagina del progetto: [lorenzomontorsi.github.io/AirplaneAI](https://lorenzomontorsi.github.io/AirplaneAI/)

## Scarica

L'APK dell'ultima versione è nella [release](https://github.com/LorenzoMontorsi/AirplaneAI/releases/latest).

| | |
| --- | --- |
| App | Android 8 o successivo, arm64-v8a o x86_64 |
| APK | circa 257 MB, non include il modello |
| Primo avvio | scarica circa 1,6 GB (pesi Q4_0 + visione), una volta sola |
| Dopo | funziona senza rete |

Per installarla serve consentire le app di origine sconosciuta.

## Cosa fa

- Chat in streaming, tutta sul dispositivo.
- Foto da galleria o fotocamera, descritte nella lingua scelta.
- Italiano, inglese o cinese, per il modello e per le scritte dell'app. La scelta resta salvata.
- Il checkpoint è Instruct: il ragionamento interno è spento, altrimenti mescola le lingue.

## Sviluppo

```bash
flutter pub get
flutter run
flutter build apk --release
```

Il modello non sta nel repository. L'app lo scarica da Hugging Face al primo avvio.
