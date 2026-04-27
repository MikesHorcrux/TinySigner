# Development Notes

TinySigner is a macOS SwiftUI app with a small AppKit/PDFKit bridge for document rendering and hit testing.

## Architecture

```mermaid
flowchart LR
    ContentView --> EditorWorkspaceView
    EditorWorkspaceView --> PDFKitDocumentView
    EditorWorkspaceView --> InspectorPanelView
    PDFKitDocumentView --> SigningPDFView
    SigningPDFView --> SigningOverlayView
    InspectorPanelView --> PDFEditorStore
    SigningPDFView --> PDFEditorStore
    PDFEditorStore --> PDFDocumentService
    PDFDocumentService --> SigningFieldRenderer
    SignatureAsset --> SigningFieldRenderer
```

## Key Components

- `PDFEditorStore`: editor state, selected field, undo/redo, placement defaults, zoom, and export command wiring.
- `PDFDocumentService`: PDF open/export, bookmark helpers, demo fixture generation, and flattened PDF rendering.
- `SigningFieldRenderer`: shared field renderer used by both live preview and exported PDFs.
- `PDFKitDocumentView`: SwiftUI wrapper around the PDFKit/AppKit editor surface.
- `SigningOverlayView`: transparent live preview layer. This avoids mutating the PDF document during drag.
- `InspectorPanelView`: tool picker, signer profile, signature library, and selected field inspector.

## Coordinate Model

Placed fields store `rectInPageSpace` in PDF page coordinates. The live overlay converts page-space rects into view-space rects for preview rendering. Export uses the original page-space rects directly while rendering each PDF page.

This is important because it keeps field placement stable across:

- Zoom changes.
- Scrolling.
- Page thumbnail navigation.
- Export flattening.

## Live Preview Rendering

Interactive previews should not be PDF annotations. Earlier annotation-based previews caused repeated stamp rendering when dragging. The current design draws fields in `SigningOverlayView`, keeping the document model clean until export.

## Export Rendering

Export follows this sequence:

1. Remove any TinySigner preview annotations from the document as a safety cleanup.
2. Create a new PDF context at the original page media box.
3. Draw each source PDF page.
4. Draw TinySigner fields assigned to that page.
5. Close the output PDF.

## SwiftData Models

- `SignerProfile`: name, initials, date format, default signature asset IDs.
- `SignatureAsset`: typed, drawn, imported, or initials asset with optional image data.
- `RecentDocument`: recent PDF security-scoped bookmark data.

## Build

```bash
./script/build_and_run.sh --verify
```

## Tests

Focused unit tests:

```bash
xcodebuild test \
  -project TinySigner.xcodeproj \
  -scheme TinySigner \
  -destination 'platform=macOS' \
  -only-testing:TinySignerTests \
  CODE_SIGNING_ALLOWED=NO
```

UI smoke tests:

```bash
xcodebuild test \
  -project TinySigner.xcodeproj \
  -scheme TinySigner \
  -destination 'platform=macOS' \
  -only-testing:TinySignerUITests \
  CODE_SIGNING_ALLOWED=NO
```

## Visual Assets

The app icon is generated into `TinySigner/Assets.xcassets/AppIcon.appiconset`.

```bash
python3 -m pip install Pillow
python3 script/generate_app_icon.py
```

Documentation graphics live in `docs/images`. SVGs are committed as source so they remain easy to review and tweak.

## Implementation Guardrails

- Do not mutate the source PDF during live editing.
- Keep placement rectangles in page coordinates.
- Keep exports flattened and original PDFs unchanged.
- Keep signature assets local.
- Use PDFKit/AppKit bridge code only where SwiftUI cannot model the behavior cleanly.
