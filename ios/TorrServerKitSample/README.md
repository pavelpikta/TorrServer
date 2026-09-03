# TorrServerKit sample (iOS Simulator)

SwiftUI host for the in-process `TorrServerKit.xcframework`. On launch it starts TorrServer and loads the **same web UI** as desktop in a `WKWebView` (`http://127.0.0.1:8090`).

## Prerequisite

```bash
./ios/build.sh
```

That builds `dist/TorrServerKit.xcframework` when missing, then compiles this sample. The app links `../../dist/TorrServerKit.xcframework` (not copied into git).

Lint:

```bash
./ios/lint.sh
```

## Run in Xcode

1. Open `ios/TorrServerKitSample/TorrServerKitSample.xcodeproj`
2. Destination: any **iOS Simulator** (arm64)
3. Run — the server starts and the TorrServer web UI appears
4. Use the toolbar to **Reload** or **Stop** / **Start**

In-app `GET http://127.0.0.1:8090/echo` is the health check before the web view loads.

## From the command line

```bash
./ios/build.sh
# or, with a named simulator:
DESTINATION='platform=iOS Simulator,name=iPhone 17' ./ios/build.sh
```
