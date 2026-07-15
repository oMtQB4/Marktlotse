# Changelog

All notable changes to Marktlotse are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Create a new release with `tools/release.py <auto|major|minor|patch>` — it moves
the entries below from *Unreleased* into a dated, versioned section and bumps the
app version. `auto` infers the bump from the [Conventional
Commits](https://www.conventionalcommits.org) since the last tag. Keep the
*Unreleased* section up to date as you work (or let `auto` generate it).

## [Unreleased]

## [1.2.0] - 2026-07-15

### Added
- ConsentView, added QR-Codes and just read the content (if not an url)

## [1.1.0] - 2026-07-03

### Added
- terms of use, voice recorder improved

## [1.1.0] - 2026-07-03

### Added
- terms of use, voice recorder improved

## [1.0.0] - 2026-06-21

### Added
- Fast, reliable barcode scanning with the camera (EAN, UPC, Code 128/39/93,
  ITF, QR, PDF417); near-range autofocus keeps small barcodes sharp.
- Product lookup via Open Food Facts, with manual barcode entry as a fallback.
- Spoken product summaries and full VoiceOver support for blind and partially
  sighted users.
- Shopping lists: create lists, add and check off items, adjust quantities, and
  see the quantity for each item next to the stepper.
- Scan history of previously looked-up products, which can be cleared entirely.
- Custom ("own") article entries that supplement online lookups.
- Voice memos attached to products.
- Branded launch/splash screen shown while the app starts.
- Onboarding tutorial, settings (read-aloud, haptics) and an open-source
  licenses screen.

[Unreleased]: https://github.com/oMtQB4/Marktlotse/compare/HEAD
