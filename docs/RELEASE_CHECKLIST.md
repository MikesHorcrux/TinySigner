# Release Checklist

Use this checklist before packaging or sharing a TinySigner build.

## Product

- Confirm app launches to the welcome screen without a PDF.
- Open a normal local PDF through the file picker.
- Place signature, initials, text, date, and checkbox fields.
- Drag and resize a signature without duplicate trails.
- Switch a selected signature between typed, drawn, and imported sources.
- Export a signed PDF and open it in Preview.
- Confirm the original PDF timestamp/content is unchanged.

## Tests

```bash
xcodebuild test \
  -project TinySigner.xcodeproj \
  -scheme TinySigner \
  -destination 'platform=macOS' \
  -only-testing:TinySignerTests \
  CODE_SIGNING_ALLOWED=NO
```

```bash
xcodebuild test \
  -project TinySigner.xcodeproj \
  -scheme TinySigner \
  -destination 'platform=macOS' \
  -only-testing:TinySignerUITests \
  CODE_SIGNING_ALLOWED=NO
```

## Assets

- Confirm the app icon appears in the Dock and app switcher.
- Regenerate icon assets if the design changed:

```bash
python3 script/generate_app_icon.py
```

## Sandbox

- Confirm `com.apple.security.app-sandbox` is enabled.
- Confirm user-selected read/write file access is enabled.
- Confirm security-scoped bookmarks survive relaunch for recent PDFs.

## Docs

- Update `README.md` if feature scope changed.
- Update `docs/USER_GUIDE.md` if user-facing controls changed.
- Update `docs/PRIVACY.md` if storage or network behavior changed.
- Update `CHANGELOG.md` with the release date and highlights.
