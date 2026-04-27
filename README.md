# TinySigner

![TinySigner editor overview](docs/images/editor-hero.svg)

TinySigner is a local-first macOS PDF e-signing app for quickly opening a PDF, placing visual signature/form fields, and exporting a new flattened signed copy. It is designed for practical day-to-day signing without sending documents through a cloud signing service.

TinySigner v1 creates visual electronic signatures. It does not create cryptographic certificate signatures, remote recipient envelopes, audit trails, or DocuSign API envelopes.

## What It Does

![TinySigner workflow](docs/images/workflow.svg)

- Opens local PDFs with PDFKit.
- Lets you place signatures, initials, text, dates, and checkboxes on any page.
- Supports typed signatures, drawn signatures, imported signature images, and initials.
- Stores signer profile and reusable signature assets locally with SwiftData.
- Provides page thumbnails, zoom controls, selection outlines, drag/resize handles, undo/redo, and keyboard delete.
- Exports a new flattened `*-signed.pdf` while leaving the original PDF untouched.

## Screens And Source Picker

![Signature source picker](docs/images/signature-source.svg)

When a signature or initials field is selected, use **Signature Source** in the inspector to switch that placed field between:

- Typed name or initials from the field value.
- Saved drawn signature.
- Imported image signature.

## App Icon

<img src="docs/images/app-icon-preview.png" alt="TinySigner app icon" width="160">

The macOS app icon is committed in `TinySigner/Assets.xcassets/AppIcon.appiconset`. To regenerate the PNG renditions after changing the icon design:

```bash
# Pillow is only needed for regeneration; the generated PNGs are committed.
python3 -m pip install Pillow
python3 script/generate_app_icon.py
```

## Requirements

- macOS 26.2 or newer deployment target.
- Xcode 26.3 or newer.
- SwiftUI, PDFKit, SwiftData, and AppKit interop.

## Quick Start

```bash
open TinySigner.xcodeproj
```

Or build and launch from the terminal:

```bash
./script/build_and_run.sh --verify
```

Run unit tests:

```bash
xcodebuild test \
  -project TinySigner.xcodeproj \
  -scheme TinySigner \
  -destination 'platform=macOS' \
  -only-testing:TinySignerTests \
  CODE_SIGNING_ALLOWED=NO
```

Run UI smoke tests:

```bash
xcodebuild test \
  -project TinySigner.xcodeproj \
  -scheme TinySigner \
  -destination 'platform=macOS' \
  -only-testing:TinySignerUITests \
  CODE_SIGNING_ALLOWED=NO
```

## User Flow

1. Open TinySigner.
2. Click **Open PDF** and choose a local PDF.
3. Choose a tool in the inspector: Signature, Initials, Text, Date, or Checkbox.
4. Click the PDF where the field should go. Signature placement is line-aware, so clicking a signature line places the writing on that line.
5. Drag, resize, or delete the selected field as needed.
6. Pick a signature source for signature/initial fields.
7. Export a flattened signed PDF. The original file is not modified.

See [User Guide](docs/USER_GUIDE.md) for the full walkthrough.

## Project Layout

```text
TinySigner/
  Models/      SwiftData models and placed field data structures
  Services/    PDF opening/export and rendering services
  Stores/      Editor state, undo/redo, placement logic
  Views/       SwiftUI and PDFKit/AppKit bridge views
  Assets.xcassets/AppIcon.appiconset/

docs/
  USER_GUIDE.md
  DEVELOPMENT.md
  PRIVACY.md
  RELEASE_CHECKLIST.md
  images/

script/
  build_and_run.sh
  generate_app_icon.py
```

## Documentation

- [User Guide](docs/USER_GUIDE.md)
- [Development Notes](docs/DEVELOPMENT.md)
- [Privacy And Signature Scope](docs/PRIVACY.md)
- [Release Checklist](docs/RELEASE_CHECKLIST.md)
- [Changelog](CHANGELOG.md)

## Current Scope

TinySigner v1 is intentionally local and simple. It is a strong fit for signing your own PDF forms, contracts, acknowledgements, and internal documents. It is not intended to replace legally managed envelope workflows that require identity verification, tamper-evident certificate signatures, recipient routing, or third-party audit logs.

## License / Use

TinySigner is public source-visible software, but it is **not open source**. All rights are reserved by Mike Van Amburg. See [LICENSE.md](LICENSE.md).
