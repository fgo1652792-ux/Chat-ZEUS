# Zeus Chat

Zeus Chat is a local-first Flutter chat workspace for Arabic and English. It
uses the vendored Liquid Glass renderer and connects directly to the provider
or local model server you choose.

## Run the app

Install Flutter 3.47.2, then run these commands from the repository root.

```sh
cd apps/zeus_flutter
flutter pub get
flutter run
```

For the browser, generate the SQLite worker and WASM files before starting
Flutter. The release build caches the app shell and local SQLite resources
after the first successful load.

```sh
dart run sqflite_common_ffi_web:setup
flutter run -d chrome
```

Linux builds require Clang, a standard Flutter GTK toolchain, and libsecret.
Add a provider from **Providers**, enter its API key when required, and test
the connection. Pick a discovered model or enter its model ID. An Ollama
connection can use a local endpoint with no key. On the web, keys are held for
the current page session and direct API calls require provider CORS support.

Create a conversation to use the selected provider. The first-run welcome
screen can start a local workspace with no Zeus account. Use **Settings** to
find projects, image tools, search, MCP and the optional Hub.

## Build and verify

The [progress report](docs/IMPLEMENTATION_PROGRESS.md) links working builds,
simulator captures, and test results. GitHub Actions packages the iOS device
build as an unsigned IPA and includes its SHA-256. For ordinary device
installation, sign it for your device first.

- [Feature matrix and limits](docs/feature-matrix.md)
- [Liquid Glass integration and provenance](docs/design-provenance.md)
- [Self-host Zeus Hub](docs/self-host.md)

## License

Zeus Chat application code is licensed under GPL-3.0. The source distribution
includes the original license and third-party notices for the bundled
Liquid Glass UI components.
