import Foundation
import Vision
import UIKit

class TitlePageReader {

    struct ExtractedInfo {
        var title: String?
        var authors: String?
        var publisher: String?
        var year: Int?
        var isbn: String?
    }

    /// A recognized text block with its bounding box height (proxy for font size).
    private struct TextBlock {
        let text: String
        let height: CGFloat   // bounding box height in normalized coordinates
        let minY: CGFloat     // vertical position (0 = bottom, 1 = top)
    }

    static func extractInfo(from image: UIImage) async throws -> ExtractedInfo {
        guard let cgImage = image.cgImage else {
            throw NSError(domain: "TitlePageReader", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Could not process image"])
        }

        let blocks = try await recognizeTextBlocks(in: cgImage)
        return parseTextBlocks(blocks)
    }

    // MARK: - OCR

    private static func recognizeTextBlocks(in image: CGImage) async throws -> [TextBlock] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let blocks = observations.compactMap { obs -> TextBlock? in
                    guard let candidate = obs.topCandidates(1).first else { return nil }
                    let box = obs.boundingBox
                    return TextBlock(
                        text: candidate.string,
                        height: box.height,
                        minY: box.minY
                    )
                }
                continuation.resume(returning: blocks)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Parsing

    private static let publisherKeywords = [
        "press", "publishing", "publishers", "books", "university",
        "editions", "verlag", "editorial", "harper", "penguin",
        "macmillan", "wiley", "springer", "elsevier", "routledge",
        "cambridge", "oxford", "mit press"
    ]

    private static let noisePatterns: [String] = [
        "new york times", "bestseller", "#1", "national book",
        "pulitzer", "award", "praise for", "a novel", "a memoir",
        "introduction by", "foreword by", "translated by",
        "edition", "revised", "updated"
    ]

    private static func parseTextBlocks(_ blocks: [TextBlock]) -> ExtractedInfo {
        var info = ExtractedInfo()

        let cleaned = blocks
            .map { TextBlock(text: $0.text.trimmingCharacters(in: .whitespaces), height: $0.height, minY: $0.minY) }
            .filter { !$0.text.isEmpty }

        guard !cleaned.isEmpty else { return info }

        // Extract ISBN
        let isbnRegex = try? NSRegularExpression(pattern: "(?:ISBN[:\\-\\s]*)?(?:97[89][\\-\\s]?)?\\d{1,5}[\\-\\s]?\\d{1,7}[\\-\\s]?\\d{1,7}[\\-\\s]?[\\dX]", options: .caseInsensitive)
        for block in cleaned {
            let range = NSRange(block.text.startIndex..., in: block.text)
            if let match = isbnRegex?.firstMatch(in: block.text, range: range),
               let matchRange = Range(match.range, in: block.text) {
                let raw = block.text[matchRange]
                info.isbn = raw.replacingOccurrences(of: "[^0-9X]", with: "", options: .regularExpression)
            }
        }

        // Extract year
        let yearRegex = try? NSRegularExpression(pattern: "\\b(1[4-9]\\d{2}|20\\d{2})\\b")
        for block in cleaned.reversed() {
            let range = NSRange(block.text.startIndex..., in: block.text)
            if let match = yearRegex?.firstMatch(in: block.text, range: range),
               let yearRange = Range(match.range(at: 1), in: block.text) {
                info.year = Int(block.text[yearRange])
                break
            }
        }

        // Find publisher line
        for block in cleaned {
            let lower = block.text.lowercased()
            if publisherKeywords.contains(where: { lower.contains($0) }) {
                info.publisher = block.text
                break
            }
        }

        // Filter to candidate lines: skip noise, publisher, year-only, copyright, short lines
        let candidates = cleaned.filter { block in
            let lower = block.text.lowercased()
            guard block.text.count > 2 else { return false }
            if lower.hasPrefix("copyright") || lower.hasPrefix("©") { return false }
            if let yr = info.year, block.text == String(yr) { return false }
            if publisherKeywords.contains(where: { lower.contains($0) }) { return false }
            if noisePatterns.contains(where: { lower.contains($0) }) { return false }
            // Skip ISBN lines
            if lower.contains("isbn") { return false }
            // Skip lines that are purely numeric
            if block.text.trimmingCharacters(in: .decimalDigits).isEmpty { return false }
            return true
        }

        guard !candidates.isEmpty else { return info }

        // Use bounding box height as a proxy for font size.
        // Title is typically the largest text on the cover.
        let maxHeight = candidates.map(\.height).max() ?? 0
        let heightThreshold = maxHeight * 0.6

        // Collect title lines: all large-text lines (they may span multiple observations)
        let titleBlocks = candidates
            .filter { $0.height >= heightThreshold }
            .sorted { $0.minY > $1.minY } // top-to-bottom (Vision: higher minY = higher on page)

        if !titleBlocks.isEmpty {
            info.title = titleBlocks.map(\.text).joined(separator: " ")
        }

        // Author: the next-largest text that isn't the title.
        // On book covers, the author name is usually the second most prominent text.
        let titleTexts = Set(titleBlocks.map(\.text))
        let authorCandidates = candidates
            .filter { !titleTexts.contains($0.text) }
            .sorted { $0.height > $1.height }

        if let authorBlock = authorCandidates.first {
            var authorLine = authorBlock.text
            let lower = authorLine.lowercased()
            if lower.hasPrefix("by ") {
                authorLine = String(authorLine.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            }
            info.authors = authorLine
        }

        return info
    }
}
