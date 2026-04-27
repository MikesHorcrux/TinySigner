# Contributing

TinySigner is open source under the MIT License.

Issues and pull requests are welcome. For a smooth review:

- Keep changes focused and explain the user-facing behavior they affect.
- Run the relevant build or test command before opening a pull request.
- Do not include real signatures, private PDFs, secrets, or customer documents in issues, tests, screenshots, or fixtures.
- Preserve the local-first privacy model unless the change explicitly proposes a new networked feature.

Useful checks:

```bash
xcodebuild build \
  -project TinySigner.xcodeproj \
  -scheme TinySigner \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO

xcodebuild test \
  -project TinySigner.xcodeproj \
  -scheme TinySigner \
  -destination 'platform=macOS' \
  -only-testing:TinySignerTests \
  CODE_SIGNING_ALLOWED=NO
```
