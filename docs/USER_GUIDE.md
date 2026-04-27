# TinySigner User Guide

![TinySigner workflow](images/workflow.svg)

TinySigner helps you add visible signing fields to a PDF and export a new flattened copy. Everything happens locally on your Mac.

## Open A PDF

1. Launch TinySigner.
2. Click **Open PDF**.
3. Pick a local PDF file.

TinySigner keeps the original PDF untouched. Exports are written as a new file, usually named with `-signed.pdf`.

## Place Fields

![TinySigner editor](images/editor-hero.svg)

Use the **Tools** section in the right inspector:

- **Signature**: place a signature field.
- **Initials**: place initials.
- **Text**: add custom text.
- **Date**: add the current date using your profile format.
- **Checkbox**: add a checkmark box.

Click a tool, then click on the PDF. After placing a field, TinySigner returns to Select mode so you can drag or edit that field immediately.

## Smart Suggestions

![Smart field suggestions](images/smart-suggestions.svg)

When a PDF opens, TinySigner scans searchable PDF text and rendered page geometry for likely signing fields:

- Signature and initials labels with nearby lines.
- Date labels with nearby lines.
- Checkbox-style square outlines.

Suggestions appear as subtle dashed outlines on the PDF and in **Smart Suggestions** in the inspector. Click an outline to accept one field, or use **Accept High Confidence** to create the obvious fields in one pass. Medium-confidence suggestions stay manual until you click them.

When you select Signature, Date, Initials, or Checkbox and click near a compatible suggestion, TinySigner snaps the new field to that suggestion.

## Signature Placement

For signature and initials fields, click the signature line itself. TinySigner anchors the signature box so the writing sits on the clicked line instead of centering the entire box around the pointer.

You can still fine-tune placement:

- Drag the selected field to move it.
- Drag the bottom-right handle to resize it.
- Use the width and height steppers in the inspector.
- Press Delete or Backspace to remove the selected field.

## Choose Signature Source

![Signature source picker](images/signature-source.svg)

When a signature or initials field is selected, use **Signature Source** to pick how that field is rendered:

- **Typed name** uses the selected field value or your signer profile name.
- **Drawn signature** uses a saved drawing from the signature library.
- **Imported image** uses a PNG/JPEG image converted to reusable signature artwork.

Changing the source affects only the selected field, so you can use a drawn full signature in one place and typed initials somewhere else.

## Manage Signer Profile

![Settings and signature setup](images/settings-signature-setup.svg)

Open **TinySigner > Settings** to manage signer defaults:

- Full name.
- Initials.
- Preferred date format.
- Default signature asset.
- Default initials asset.

The date preview updates live so you can confirm the format before placing date fields.

## Signature Library

In Settings, **Open Signature Setup** to save reusable assets:

- **Save Typed** creates a signature image from your full name.
- **Save Initials** creates an initials asset.
- **Draw here** captures hand-drawn strokes.
- **Save Drawing** stores the drawn signature.
- **Import Image** imports an existing image as a signature asset.

Saved assets persist locally through SwiftData.

## Export

![Export success actions](images/export-success.svg)

Use **Export Signed PDF** to create a flattened copy. TinySigner renders the original PDF content, then draws each placed field into normal page content.

Export behavior:

- Original PDF remains unchanged.
- Exported PDF is readable in Preview.
- Fields are flattened as visible page content.
- Existing visible PDF content and annotations are preserved by PDFKit rendering.
- Export completion offers to open the signed PDF, reveal it in Finder, or start another signing flow.

## Keyboard Shortcuts

- `Command-O`: open PDF.
- `Shift-Command-E`: export signed PDF.
- `Command-Z`: undo.
- `Shift-Command-Z`: redo.
- `Command-+`: zoom in.
- `Command--`: zoom out.
- `Command-0`: actual size.
- `Option-Command-1` through `Option-Command-6`: select editor tools.
- `Shift-Command-A`: accept high-confidence smart suggestions.
- `Delete` or `Backspace`: remove selected field.

## Troubleshooting

If a signature appears too high or low, drag it slightly or adjust height in the inspector. Different PDFs use different line spacing and page boxes, so small manual tuning is normal.

If a saved signature does not appear in the picker, save/import it again and select the placed field. The picker only shows signature assets for signature fields and initials assets for initials fields.

If export fails due to permissions, reopen the PDF through TinySigner so the app receives sandbox access again.
