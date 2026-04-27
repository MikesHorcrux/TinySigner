import AppKit
import Foundation
import PDFKit

struct PDFFieldDetectionService {
    private struct TextLabel {
        var kind: PlacedField.Kind
        var rect: CGRect
        var text: String
    }

    private struct HorizontalLine {
        var rect: CGRect
    }

    private struct PageBitmap {
        var bitmap: NSBitmapImageRep
        var pageBounds: CGRect
        var scale: CGFloat
        var darkPixels: [Bool]

        func pageRect(forPixelBounds pixelBounds: CGRect) -> CGRect {
            CGRect(
                x: pageBounds.minX + pixelBounds.minX / scale,
                y: pageBounds.maxY - pixelBounds.maxY / scale,
                width: pixelBounds.width / scale,
                height: pixelBounds.height / scale
            )
        }

        func isDarkPixel(x: Int, y: Int) -> Bool {
            guard x >= 0, x < bitmap.pixelsWide, y >= 0, y < bitmap.pixelsHigh else { return false }
            return darkPixels[y * bitmap.pixelsWide + x]
        }
    }

    func detectSuggestions(in document: PDFDocument) -> [DetectedFieldSuggestion] {
        guard document.pageCount > 0 else { return [] }

        var suggestions: [DetectedFieldSuggestion] = []
        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }

            let pageBounds = page.bounds(for: .cropBox)
            let labels = textLabels(on: page)
            let bitmap = renderBitmap(for: page, pageBounds: pageBounds)
            let lines = bitmap.map(detectHorizontalLines(in:)) ?? []
            let checkboxes = bitmap.map(detectCheckboxRects(in:)) ?? []

            suggestions.append(contentsOf: labelDrivenSuggestions(labels: labels, lines: lines, pageIndex: pageIndex, pageBounds: pageBounds))
            suggestions.append(contentsOf: checkboxes.map { rect in
                DetectedFieldSuggestion(
                    kind: .checkbox,
                    pageIndex: pageIndex,
                    rectInPageSpace: rect.clamped(to: pageBounds).snapped(to: 1),
                    sourceLabel: "checkbox",
                    confidence: .high
                )
            })
        }

        return deduplicated(suggestions)
    }

    private func textLabels(on page: PDFPage) -> [TextLabel] {
        guard let pageText = page.string, !pageText.isEmpty else { return [] }
        let patterns: [(PlacedField.Kind, String)] = [
            (.signature, #"(?i)\b(signature|signed by|sign here|signer)\b"#),
            (.initials, #"(?i)\b(initials?|initial here)\b"#),
            (.date, #"(?i)\b(date|dated)\b"#)
        ]

        var labels: [TextLabel] = []
        let nsText = pageText as NSString

        for (kind, pattern) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let matches = regex.matches(in: pageText, range: NSRange(location: 0, length: nsText.length))
            for match in matches {
                guard
                    match.range.location != NSNotFound,
                    let selection = page.selection(for: match.range)
                else { continue }

                let rect = selection.bounds(for: page).standardized
                guard rect.width > 0, rect.height > 0 else { continue }
                labels.append(TextLabel(kind: kind, rect: rect, text: nsText.substring(with: match.range)))
            }
        }

        return labels
    }

    private func labelDrivenSuggestions(
        labels: [TextLabel],
        lines: [HorizontalLine],
        pageIndex: Int,
        pageBounds: CGRect
    ) -> [DetectedFieldSuggestion] {
        labels.compactMap { label in
            if let line = nearestLine(for: label, in: lines) {
                return DetectedFieldSuggestion(
                    kind: label.kind,
                    pageIndex: pageIndex,
                    rectInPageSpace: suggestedRect(for: label.kind, line: line.rect, pageBounds: pageBounds),
                    sourceLabel: label.text,
                    confidence: .high
                )
            }

            return DetectedFieldSuggestion(
                kind: label.kind,
                pageIndex: pageIndex,
                rectInPageSpace: inferredRect(for: label, pageBounds: pageBounds),
                sourceLabel: label.text,
                confidence: .medium
            )
        }
    }

    private func nearestLine(for label: TextLabel, in lines: [HorizontalLine]) -> HorizontalLine? {
        let expectedWidth = max(label.kind.defaultSize.width * 0.58, 64)
        let searchRect = CGRect(
            x: label.rect.minX - 40,
            y: label.rect.minY - 34,
            width: max(label.rect.width + label.kind.defaultSize.width + 120, expectedWidth),
            height: 92
        )

        return lines
            .filter { line in
                line.rect.width >= expectedWidth &&
                    line.rect.intersects(searchRect) &&
                    abs(line.rect.midY - label.rect.midY) <= 46
            }
            .min { lhs, rhs in
                lineScore(lhs.rect, for: label) < lineScore(rhs.rect, for: label)
            }
    }

    private func lineScore(_ line: CGRect, for label: TextLabel) -> CGFloat {
        let verticalDistance = abs(line.midY - label.rect.midY)
        let horizontalDistance = max(0, label.rect.minX - line.maxX, line.minX - label.rect.maxX)
        let labelStartsNearLine = abs(line.minX - label.rect.minX) * 0.25
        return verticalDistance + horizontalDistance + labelStartsNearLine
    }

    private func suggestedRect(for kind: PlacedField.Kind, line: CGRect, pageBounds: CGRect) -> CGRect {
        let defaultSize = kind.defaultSize
        let width: CGFloat
        switch kind {
        case .signature:
            width = min(max(line.width, 168), 320)
        case .initials:
            width = min(max(line.width, 72), 160)
        case .date:
            width = min(max(line.width, 108), 190)
        case .text:
            width = min(max(line.width, defaultSize.width), 320)
        case .checkbox:
            return line
        }

        let rect = CGRect(
            x: line.minX,
            y: line.midY - defaultSize.height * lineAnchorRatio(for: kind),
            width: width,
            height: defaultSize.height
        )
        return rect.clamped(to: pageBounds).snapped(to: 1)
    }

    private func inferredRect(for label: TextLabel, pageBounds: CGRect) -> CGRect {
        let size = label.kind.defaultSize
        let rect = CGRect(
            x: label.rect.maxX + 12,
            y: label.rect.midY - size.height * lineAnchorRatio(for: label.kind),
            width: size.width,
            height: size.height
        )
        return rect.clamped(to: pageBounds).snapped(to: 1)
    }

    private func lineAnchorRatio(for kind: PlacedField.Kind) -> CGFloat {
        switch kind {
        case .signature: 0.22
        case .initials: 0.24
        case .date, .text, .checkbox: 0.50
        }
    }

    private func renderBitmap(for page: PDFPage, pageBounds: CGRect) -> PageBitmap? {
        let maxDimension: CGFloat = 1_200
        let scale = min(1, maxDimension / max(pageBounds.width, pageBounds.height))
        let pixelWidth = max(1, Int(ceil(pageBounds.width * scale)))
        let pixelHeight = max(1, Int(ceil(pageBounds.height * scale)))

        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelWidth,
            pixelsHigh: pixelHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }

        guard let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }
        let previousContext = NSGraphicsContext.current
        NSGraphicsContext.current = graphicsContext
        defer { NSGraphicsContext.current = previousContext }

        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight).fill()

        let context = graphicsContext.cgContext
        context.saveGState()
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -pageBounds.minX, y: -pageBounds.minY)
        page.draw(with: .cropBox, to: context)
        context.restoreGState()

        return PageBitmap(
            bitmap: bitmap,
            pageBounds: pageBounds,
            scale: scale,
            darkPixels: darkPixelMask(for: bitmap)
        )
    }

    private func detectHorizontalLines(in pageBitmap: PageBitmap) -> [HorizontalLine] {
        let bitmap = pageBitmap.bitmap
        let minimumRun = max(48, Int(64 * pageBitmap.scale))
        var rawRuns: [CGRect] = []

        for y in 0..<bitmap.pixelsHigh {
            var runStart: Int?
            for x in 0..<bitmap.pixelsWide {
                if pageBitmap.isDarkPixel(x: x, y: y) {
                    if runStart == nil {
                        runStart = x
                    }
                } else if let start = runStart {
                    if x - start >= minimumRun {
                        rawRuns.append(CGRect(x: start, y: y, width: x - start, height: 1))
                    }
                    runStart = nil
                }
            }

            if let start = runStart, bitmap.pixelsWide - start >= minimumRun {
                rawRuns.append(CGRect(x: start, y: y, width: bitmap.pixelsWide - start, height: 1))
            }
        }

        return mergeHorizontalRuns(rawRuns).map { HorizontalLine(rect: pageBitmap.pageRect(forPixelBounds: $0).snapped(to: 1)) }
    }

    private func mergeHorizontalRuns(_ runs: [CGRect]) -> [CGRect] {
        var merged: [CGRect] = []

        for run in runs.sorted(by: { $0.minY == $1.minY ? $0.minX < $1.minX : $0.minY < $1.minY }) {
            if let index = merged.lastIndex(where: { existing in
                abs(existing.minY - run.minY) <= 2 &&
                    abs(existing.minX - run.minX) <= 4 &&
                    abs(existing.maxX - run.maxX) <= 4
            }) {
                merged[index] = merged[index].union(run)
            } else {
                merged.append(run)
            }
        }

        return merged.filter { $0.width >= 48 && $0.height <= 5 }
    }

    private func detectCheckboxRects(in pageBitmap: PageBitmap) -> [CGRect] {
        let bitmap = pageBitmap.bitmap
        let pixelCount = bitmap.pixelsWide * bitmap.pixelsHigh
        guard pixelCount > 0 else { return [] }

        var visited = Array(repeating: false, count: pixelCount)
        var rects: [CGRect] = []

        func offset(_ x: Int, _ y: Int) -> Int { y * bitmap.pixelsWide + x }

        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                let startOffset = offset(x, y)
                guard !visited[startOffset], pageBitmap.isDarkPixel(x: x, y: y) else { continue }

                var queue = [(x, y)]
                visited[startOffset] = true
                var head = 0
                var minX = x
                var maxX = x
                var minY = y
                var maxY = y
                var darkCount = 0

                while head < queue.count {
                    let (currentX, currentY) = queue[head]
                    head += 1
                    darkCount += 1
                    minX = min(minX, currentX)
                    maxX = max(maxX, currentX)
                    minY = min(minY, currentY)
                    maxY = max(maxY, currentY)

                    for neighborY in max(0, currentY - 1)...min(bitmap.pixelsHigh - 1, currentY + 1) {
                        for neighborX in max(0, currentX - 1)...min(bitmap.pixelsWide - 1, currentX + 1) {
                            let neighborOffset = offset(neighborX, neighborY)
                            guard !visited[neighborOffset] else { continue }
                            visited[neighborOffset] = true
                            guard pageBitmap.isDarkPixel(x: neighborX, y: neighborY) else { continue }
                            queue.append((neighborX, neighborY))
                        }
                    }
                }

                let width = maxX - minX + 1
                let height = maxY - minY + 1
                guard
                    isLikelyCheckbox(width: width, height: height, darkCount: darkCount),
                    hasCheckboxBorder(in: pageBitmap, minX: minX, maxX: maxX, minY: minY, maxY: maxY)
                else { continue }

                rects.append(pageBitmap.pageRect(forPixelBounds: CGRect(x: minX, y: minY, width: width, height: height)))
            }
        }

        return rects
            .map { $0.insetBy(dx: -1, dy: -1).snapped(to: 1) }
            .filter { $0.width >= 10 && $0.height >= 10 }
    }

    private func isLikelyCheckbox(width: Int, height: Int, darkCount: Int) -> Bool {
        guard width >= 12, width <= 42, height >= 12, height <= 42 else { return false }
        let aspect = CGFloat(width) / CGFloat(height)
        guard aspect >= 0.72, aspect <= 1.32 else { return false }
        let area = width * height
        let density = CGFloat(darkCount) / CGFloat(area)
        return density >= 0.10 && density <= 0.55
    }

    private func hasCheckboxBorder(in pageBitmap: PageBitmap, minX: Int, maxX: Int, minY: Int, maxY: Int) -> Bool {
        let width = maxX - minX + 1
        let height = maxY - minY + 1
        let edgeThickness = 2

        func horizontalCoverage(yRange: ClosedRange<Int>) -> CGFloat {
            var coveredColumns = 0
            for x in minX...maxX {
                let hasDarkPixel = yRange.contains { y in
                    pageBitmap.isDarkPixel(x: x, y: y)
                }
                if hasDarkPixel { coveredColumns += 1 }
            }
            return CGFloat(coveredColumns) / CGFloat(width)
        }

        func verticalCoverage(xRange: ClosedRange<Int>) -> CGFloat {
            var coveredRows = 0
            for y in minY...maxY {
                let hasDarkPixel = xRange.contains { x in
                    pageBitmap.isDarkPixel(x: x, y: y)
                }
                if hasDarkPixel { coveredRows += 1 }
            }
            return CGFloat(coveredRows) / CGFloat(height)
        }

        let top = horizontalCoverage(yRange: max(minY, maxY - edgeThickness)...maxY)
        let bottom = horizontalCoverage(yRange: minY...min(maxY, minY + edgeThickness))
        let left = verticalCoverage(xRange: minX...min(maxX, minX + edgeThickness))
        let right = verticalCoverage(xRange: max(minX, maxX - edgeThickness)...maxX)

        return top > 0.58 && bottom > 0.58 && left > 0.58 && right > 0.58
    }

    private func darkPixelMask(for bitmap: NSBitmapImageRep) -> [Bool] {
        var mask = Array(repeating: false, count: bitmap.pixelsWide * bitmap.pixelsHigh)
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                guard let color = bitmap.colorAt(x: x, y: y), color.alphaComponent > 0.05 else { continue }
                let red = color.redComponent
                let green = color.greenComponent
                let blue = color.blueComponent
                let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
                mask[y * bitmap.pixelsWide + x] = luminance < 0.55
            }
        }
        return mask
    }

    private func deduplicated(_ suggestions: [DetectedFieldSuggestion]) -> [DetectedFieldSuggestion] {
        var result: [DetectedFieldSuggestion] = []

        for suggestion in suggestions.sorted(by: suggestionSort) {
            guard !result.contains(where: { existing in
                existing.kind == suggestion.kind &&
                    existing.pageIndex == suggestion.pageIndex &&
                    existing.rectInPageSpace.center.distance(to: suggestion.rectInPageSpace.center) < 28
            }) else { continue }

            result.append(suggestion)
        }

        return result.sorted {
            if $0.pageIndex != $1.pageIndex { return $0.pageIndex < $1.pageIndex }
            if abs($0.rectInPageSpace.minY - $1.rectInPageSpace.minY) > 1 {
                return $0.rectInPageSpace.minY > $1.rectInPageSpace.minY
            }
            return $0.rectInPageSpace.minX < $1.rectInPageSpace.minX
        }
    }

    private func suggestionSort(_ lhs: DetectedFieldSuggestion, _ rhs: DetectedFieldSuggestion) -> Bool {
        if lhs.confidence.rank != rhs.confidence.rank {
            return lhs.confidence.rank > rhs.confidence.rank
        }
        return lhs.rectInPageSpace.area > rhs.rectInPageSpace.area
    }
}

private extension DetectionConfidence {
    var rank: Int {
        switch self {
        case .high: 3
        case .medium: 2
        case .low: 1
        }
    }
}

private extension CGRect {
    var area: CGFloat { width * height }
}
