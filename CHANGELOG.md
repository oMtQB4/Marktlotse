# Changelog

All notable changes to Marktlotse are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Create a new release with `tools/release.py <major|minor|patch>` — it moves the
entries below from *Unreleased* into a dated, versioned section and bumps the
app version. Keep the *Unreleased* section up to date as you work.

## [Unreleased]

### Added
- Shopping lists now show the quantity for each item next to the stepper.
- Branded launch/splash screen shown while the app starts.

### Changed
- Redesigned app icon.
- Faster and more reliable barcode scanning: near-range autofocus keeps small
  barcodes sharp, and frames are processed synchronously for quicker reads.

## [1.0.0] - 2026-06-18

### Added
- Barcode scanning with the camera (EAN, UPC, Code 128/39/93, ITF, QR, PDF417).
- Product lookup via Open Food Facts, with manual barcode entry as a fallback.
- Spoken product summaries and full VoiceOver support for blind and partially
  sighted users.
- Shopping lists: create lists, add and check off items, adjust quantities.
- Scan history of previously looked-up products.
- Custom ("own") article entries that supplement online lookups.
- Voice memos attached to products.
- Onboarding tutorial, settings (read-aloud, haptics) and an open-source
  licenses screen.

[Unreleased]: https://github.com/oMtQB4/Marktlotse/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/oMtQB4/Marktlotse/releases/tag/v1.0.0
