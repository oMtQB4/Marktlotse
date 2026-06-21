# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Marktlotse is a SwiftUI + SwiftData iOS app (iOS 17+) that helps blind and
visually impaired people shop independently: scan a product barcode, hear the
product read aloud, manage shopping lists, keep a scan history, record voice
memos, and add custom product entries. The UI strings are **German**;
accessibility (VoiceOver, spoken results, haptics, non-visual fallbacks) is a
first-class concern, not an afterthought.

## Build & run

Dependencies come from CocoaPods (Google ML Kit). Always work through the
**workspace**, never the `.xcodeproj`.

```sh
pod install                       # required before the first build / after Podfile changes
```

```sh
# Command-line build (CI / verification)
xcodebuild -workspace Marktlotse.xcworkspace -scheme Marktlotse \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug build CODE_SIGNING_ALLOWED=NO
```

In Xcode: open `Marktlotse.xcworkspace`, select the `Marktlotse` scheme, Run.

There is **no test target / no automated tests** in this project.

### Simulator architecture caveat (important)

Google ML Kit ships **no `arm64` iOS Simulator slice** (the pods set
`EXCLUDED_ARCHS[sdk=iphonesimulator*] = arm64`), so the app builds **x86_64-only**
for the simulator. On an Apple Silicon Mac:
- Run on a **real device** (`arm64` device builds work normally), or
- Use a simulator on an **iOS 18.x runtime** (which still supports x86_64) — a
  freshly created simulator on the newest runtime is arm64-only and will reject
  the x86_64 build with "no matching arch".

The **camera/barcode scanner only works on a physical device** — the simulator
has no camera and shows the camera-permission screen instead.

## Architecture (the big picture)

### Startup & dependency injection
`MarktlotseApp` builds the SwiftData `ModelContainer` (schema: `ShoppingList`,
`ShoppingListItem`, `HistoryEntry`, `CustomArticle`) and a single `AppServices`
instance injected via `.environment`. `AppServices` is the lightweight DI
container (settings, voice-memo store, speech announcer, product lookup) read
throughout the view tree with `@Environment(AppServices.self)`. `RootView` shows
the splash, then the 4-tab interface, and the onboarding tutorial on first launch.

### Product lookup pipeline
Resolving a barcode flows through `ProductRepository.resolve(barcode:)`:
custom entry (`CustomArticle`) → online lookup → fallback, recording a
`HistoryEntry`. Online lookup goes through `CompositeProductLookupService`, which
queries its configured `ProductLookupService`s in order and returns the first
match. **Currently only `OpenFoodFactsService` is active**; `OpenGTINService` is
fully implemented but disabled — re-enable it by adding it to the services array
in `AppServices.init()`. `Article` is the value type passed to the UI; its
`source` enum (`.openFoodFacts`, `.openGTIN`, `.customEntry`) drives attribution.

### Barcode scanning
`CameraScannerView` (a `UIViewControllerRepresentable` over an
`AVCaptureSession`) feeds live frames to ML Kit. Detection runs **synchronously**
via `barcodeScanner.results(in:)` on the video queue (no main-thread hop;
`alwaysDiscardsLateVideoFrames` self-throttles). Focus tuning lives in
`configureFocus`/`applyMinimumFocusZoom`: continuous autofocus plus a zoom factor
that compensates for the lens' minimum focus distance so small/close barcodes
stay decodable (see the `minimumFocusDistance` handling — this is the fix for
"won't focus on close codes"). `BarcodeScannerSource` is an abstraction so a
BLE/HID scanner could be added without touching the UI.

### Persistence
SwiftData `@Model` types in `Models/PersistentModels.swift`. Views use `@Query`
and the `\.modelContext` environment directly; there is no repository layer over
SwiftData for lists/history (only product lookup is abstracted).

## Project conventions & gotchas

- **Generated Info.plist**: there is no `Info.plist` file. Bundle keys
  (display name, camera/mic usage, launch screen, orientations) are
  `INFOPLIST_KEY_*` build settings in `project.pbxproj`.
- **Synchronized file groups**: the project uses
  `PBXFileSystemSynchronizedRootGroup`, so new files added under `Marktlotse/`
  are picked up automatically — no `project.pbxproj` editing needed.
- **Screenshot harness** (`Marktlotse/ScreenshotSupport.swift`, `#if DEBUG`
  only): App Store screenshots are generated deterministically by launching with
  arguments, e.g. `-ScreenshotMode 1 -ScreenshotTab 1 -ScreenshotOpenList 1
  -hasSeenTutorial YES -ScreenshotHoldSplash 1`. These seed demo data, pick the
  tab, deep-link a list, and skip/hold the splash. Never compiled into release.

## Versioning & releases

Semantic Versioning; user-facing notes live in `CHANGELOG.md` (Keep a Changelog).
`tools/release.py <auto|major|minor|patch|X.Y.Z>` bumps `MARKETING_VERSION` (all
configs) + `CURRENT_PROJECT_VERSION`, rolls the `Unreleased` changelog section
into a dated one, and prints notes for App Store "What's New". `auto` derives the
bump from Conventional Commits since the **last `vX.Y.Z` git tag**; with no tags
yet the first release ships the current version as-is. Add `--tag` to commit and
tag, `--dry-run` to preview.

Icon/launch art is regenerated from code: `swift tools/make_icon.swift` and
`swift tools/make_launch_logo.swift`.
