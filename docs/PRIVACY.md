# Privacy And Signature Scope

TinySigner is designed as a local-first PDF signing tool.

## Local Data

TinySigner stores this data locally on the Mac:

- Signer profile name and initials.
- Preferred date format.
- Saved typed, drawn, imported, and initials signature assets.
- Recent document bookmarks used by the sandbox to reopen user-selected PDFs.

## Network

TinySigner v1 does not require a network service to sign PDFs. It does not upload PDFs, signature assets, or signer profile data to a remote server.

## PDF Handling

- The original PDF is opened for preview and placement.
- Smart field detection runs locally using PDF text extraction and rendered page geometry.
- Detection suggestions are not uploaded and are not exported unless the user accepts them as fields.
- TinySigner exports a separate flattened copy.
- The original file is not modified by the export process.

## Signature Type

TinySigner creates visible/electronic signature marks. It does not create certificate-based digital signatures, cryptographic tamper seals, recipient identity verification, or third-party audit trails.

Use a managed signing provider when a workflow requires cryptographic validation, remote recipients, identity checks, or formal compliance audit trails.
