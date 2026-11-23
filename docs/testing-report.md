# Verification and release

Use the GitHub Actions commit SHA to match quality results, screenshots and
device archives. A Flutter web build is served via HTTP with the same SQLite
worker generated during the build.

## Commands

```sh
cd packages/zeus_glass
flutter pub get
flutter analyze
flutter test
cd ../../apps/zeus_flutter
flutter pub get
flutter analyze
flutter test
```

Run the checked-in simulator workflow on macOS to install and launch the
simulator app before its integration test. The unsigned iOS device archive is
produced by the separate device workflow. Verify its contents and checksum
after downloading the workflow artifact.

For live provider checks, enter a key locally from the Providers screen. CI
uses contract fixtures and loopback servers for protocol behavior. The
test suite exercises incremental UTF-8 streaming, cancellation, provider error
metadata, scoped memory, attachment ownership, migrations, and MCP handshakes.
