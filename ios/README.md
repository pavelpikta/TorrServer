# iOS

In-process TorrServer (`TorrServerKit.xcframework`) and a sample host that shows the same web UI as desktop (`http://127.0.0.1:8090`).

## Scripts

```bash
./ios/build.sh    # XCFramework if missing, then sample app
./ios/lint.sh     # Info.plist + xcodebuild analyze
```

Rebuild the kit first with `FORCE_KIT=1 ./ios/build.sh`. The XCFramework itself is produced by [`../build-ios.sh`](../build-ios.sh).

## Sample

See [TorrServerKitSample/README.md](TorrServerKitSample/README.md).
