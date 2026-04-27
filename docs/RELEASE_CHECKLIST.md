# Release Checklist

Use this checklist before packaging or sharing a TinySigner build.

## Product

- Confirm app launches to the welcome screen without a PDF.
- Open a normal local PDF through the file picker.
- Confirm smart suggestions appear on a fixture or real form with signature/date/checkbox fields.
- Accept one suggestion by clicking the PDF overlay.
- Accept all high-confidence suggestions from the inspector.
- Place signature, initials, text, date, and checkbox fields.
- Confirm manual Signature/Date/Initials/Checkbox placement snaps to nearby compatible suggestions.
- Drag and resize a signature without duplicate trails.
- Switch a selected signature between typed, drawn, and imported sources.
- Open Settings and update signer name, initials, date format, default signature, and default initials.
- Create or import a reusable signature asset from Signature Setup.
- Export a signed PDF and open it in Preview.
- Confirm export success actions work: open signed PDF, reveal in Finder, and sign another.
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
- Confirm documentation images render in README and docs pages:
  - `docs/images/editor-hero.svg`
  - `docs/images/workflow.svg`
  - `docs/images/smart-suggestions.svg`
  - `docs/images/signature-source.svg`
  - `docs/images/settings-signature-setup.svg`
  - `docs/images/export-success.svg`
  - `docs/images/ci-validation.svg`
  - `docs/images/app-icon-preview.png`
- Regenerate icon assets if the design changed:

```bash
python3 script/generate_app_icon.py
```

## Sandbox

- Confirm `com.apple.security.app-sandbox` is enabled.
- Confirm user-selected read/write file access is enabled.
- Confirm security-scoped bookmarks survive relaunch for recent PDFs.

## Packaging

- Build the release DMG:

```bash
./script/build_release_dmg.sh
```

- If the Xcode project does not set a development team, provide it locally through the environment:

```bash
DEVELOPMENT_TEAM_ID="YOURTEAMID" ./script/build_release_dmg.sh
```

- For public distribution, notarize and staple the DMG before attaching it to a GitHub release:

```bash
NOTARYTOOL_PROFILE="TinySigner" ./script/build_release_dmg.sh --notarize
```

- Confirm `build/release/validation.log` shows a Developer ID signed app and DMG.
- Confirm `xcrun stapler validate build/release/TinySigner-1.0.dmg` succeeds before calling the release final.

## Docs

- Update `README.md` if feature scope changed.
- Update `docs/USER_GUIDE.md` if user-facing controls changed.
- Update `docs/DEVELOPMENT.md` if architecture, CI, or detection behavior changed.
- Update `docs/PRIVACY.md` if storage or network behavior changed.
- Update `CHANGELOG.md` with the release date and highlights.
