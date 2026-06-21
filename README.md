# Marktlotse

Modern SwiftUI iOS app. It helps blind and
visually impaired people shop independently: scan a product barcode with the
phone camera, hear the product read aloud, manage shopping lists, keep a scan
history, record voice memos, and add your own product entries.

## Requirements
- Xcode 16 or newer
- iOS 17.0+ deployment target
- [CocoaPods](https://cocoapods.org) (for the Google ML Kit dependency)

## Dependencies (CocoaPods)
The camera scanner uses **Google ML Kit Barcode Scanning**, installed via
CocoaPods (`pod 'GoogleMLKit/BarcodeScanning'`, see `Podfile`).

Before the first build, install the pods:

```sh
pod install
```

## Opening / building
After `pod install`, open **`Marktlotse.xcworkspace`** (not the
`.xcodeproj`) in Xcode, select the **Marktlotse** scheme and an iOS 17+
device or simulator, then Run.

> ML Kit ships binary frameworks; the first `pod install` downloads a few
> hundred MB and the first build is slower.

> **Apple Silicon simulator:** ML Kit does **not** provide an `arm64` iOS
> Simulator slice (the pods set `EXCLUDED_ARCHS[sdk=iphonesimulator*] = arm64`).
> On an Apple Silicon Mac, run on a **real device**, or run the simulator under
> **Rosetta** (Product › Destination › *… (Rosetta)*). Device builds (`arm64`)
> work normally.

> The CocoaPods `Podfile` contains a small monkey-patch that adds the missing
> `objectVersion 70` mapping to the bundled `Xcodeproj 1.27.0`; without it
> `pod install` aborts on this Xcode 16 project. Remove it once a fixed
> `Xcodeproj` ships.

> Note: building from the command line requires a simulator runtime that
> matches the installed simulator SDK. If `actool` complains about a missing
> simulator runtime, install the matching iOS Simulator runtime via
> *Xcode › Settings › Components*.

## Versioning & releases
The app follows [Semantic Versioning](https://semver.org) (`MAJOR.MINOR.PATCH`,
e.g. `1.0.0`). User-facing changes are tracked in [`CHANGELOG.md`](CHANGELOG.md)
([Keep a Changelog](https://keepachangelog.com) format): add notes under
**Unreleased** as you work.

To cut a new version, run the release tool with the part to bump (or an explicit
version):

```sh
tools/release.py minor          # 1.0.0 -> 1.1.0
tools/release.py patch          # 1.1.0 -> 1.1.1
tools/release.py 2.0.0          # explicit version
tools/release.py minor --dry-run    # preview without writing
```

It bumps `MARKETING_VERSION` (the App Store version) across all build
configurations, increments `CURRENT_PROJECT_VERSION` (the build number), moves
the *Unreleased* notes into a dated `[X.Y.Z]` changelog section, and prints those
notes ready to paste into App Store Connect's *What's New*. Add `--tag` to also
commit the change and create a `vX.Y.Z` git tag.

## Architecture
- `Models/` – SwiftData models (`ShoppingList`, `ShoppingListItem`,
  `HistoryEntry`, `CustomArticle`), the `Article` value type and `Barcode`
  validation helpers.
- `Services/`
  - `BarcodeScanner` – source abstraction (camera today; BLE/HID can be added
    later without touching the UI).
  - `CameraScannerView` – camera capture wrapper that runs **Google ML Kit**
    barcode detection on the live video frames.
  - `OpenFoodFactsService` – product lookup via the Open Food Facts JSON API.
  - `OpenGTINService` – product lookup via OpenGTINDB (plain-text API).
  - `CompositeProductLookupService` – queries configured databases in order and
    returns the first match (currently Open Food Facts only).
  - `ProductRepository` – lookup orchestration (custom entry → online →
    fallback) and history recording.
  - `VoiceMemoStore` – record/play per-barcode audio notes.
  - `SpeechAnnouncer` – VoiceOver announcements + optional spoken results.
  - `AppSettings` – preferences (OpenGTINDB query id, speak results, haptics).
- `Views/` – SwiftUI screens: scanning, article detail, shopping lists,
  history, settings/about and the onboarding tutorial.

## Product database
Product info is looked up from [Open Food Facts](https://world.openfoodfacts.org)
via its key-free JSON API. Besides the name and brand, the app shows nutrition
values (per 100 g), ingredients, allergens, common labels (vegan, organic, …),
the Nutri-Score and the NOVA processing group when available. German product
names and ingredients are preferred. Data is under the Open Database License
(ODbL).

`OpenGTINDB` support is implemented (`OpenGTINService`) but currently **disabled**.
To re-enable it as a fallback, add it to the services array in
`AppServices.init()`.

## Accessibility
- German labels/hints throughout; combined accessibility elements for list rows.
- Scan results are announced via VoiceOver and can also be spoken aloud when
  VoiceOver is off.
- Haptic feedback on a successful scan; manual barcode entry as a non-visual
  fallback.
