import Foundation

/// Extracts metadata identifiers (DOI, arXiv ID, ISBN) from raw PDF data,
/// then looks up full metadata via CrossRef or Open Library.
class PDFExtractor {
    static let shared = PDFExtractor()

    struct ExtractedMetadata {
        var title: String?
        var authors: String?
        var journal: String?
        var year: Int?
        var doi: String?
        var abstract: String?
        var source: String // "crossref", "pdf", "none"
    }

    /// Main extraction pipeline for a PDF file's raw data.
    func extract(from data: Data) async -> ExtractedMetadata {
        let rawText = extractRawText(from: data)

        // 1. Try DOI → CrossRef
        if let doi = findDOI(in: rawText) {
            if let paper = try? await CrossrefService.shared.fetchPaper(doi: doi) {
                return ExtractedMetadata(
                    title: paper.title,
                    authors: paper.authors,
                    journal: paper.journal,
                    year: paper.year,
                    doi: paper.doi,
                    abstract: paper.abstract,
                    source: "crossref"
                )
            }
        }

        // 2. Try arXiv ID → CrossRef via DOI
        if let arxivId = findArxivId(in: rawText) {
            let arxivDoi = "10.48550/arXiv.\(arxivId)"
            if let paper = try? await CrossrefService.shared.fetchPaper(doi: arxivDoi) {
                return ExtractedMetadata(
                    title: paper.title,
                    authors: paper.authors,
                    journal: paper.journal,
                    year: paper.year,
                    doi: paper.doi ?? arxivDoi,
                    abstract: paper.abstract,
                    source: "crossref"
                )
            }
        }

        // 3. Try ISBN → Open Library
        if let isbn = findISBN(in: rawText) {
            if let paper = try? await CrossrefService.shared.fetchPaper(doi: isbn) {
                return ExtractedMetadata(
                    title: paper.title,
                    authors: paper.authors,
                    journal: paper.journal,
                    year: paper.year,
                    doi: nil,
                    abstract: nil,
                    source: "crossref"
                )
            }
        }

        // 4. Fall back to PDF metadata fields and text heuristics
        let pdfMeta = extractPDFMetadata(from: rawText)
        let contentStrings = extractContentStrings(from: rawText)
        let title = pdfMeta.title ?? guessTitle(from: contentStrings)
        let authors = pdfMeta.authors ?? guessAuthors(from: contentStrings, title: title)
        let year = findYear(in: rawText)

        let hasAnything = title != nil || authors != nil
        return ExtractedMetadata(
            title: title,
            authors: authors,
            journal: nil,
            year: year,
            doi: findDOI(in: rawText),
            abstract: nil,
            source: hasAnything ? "pdf" : "none"
        )
    }

    // MARK: - Raw Text

    private func extractRawText(from data: Data) -> String {
        // Decode as latin1 to preserve all byte values
        return String(data: data, encoding: .isoLatin1) ?? ""
    }

    // MARK: - Identifier Finders

    private func findDOI(in text: String) -> String? {
        let patterns = [
            "doi\\.org/(10\\.\\d{4,9}/[^\\s,;)}\\]>\"']+)",
            "doi[:\\s]+\\s*(10\\.\\d{4,9}/[^\\s,;)}\\]>\"']+)",
            "\\b(10\\.\\d{4,9}/[^\\s,;)}\\]>\"']+)"
        ]
        for pattern in patterns {
            if let match = text.range(of: pattern, options: .regularExpression, range: text.startIndex..<text.endIndex) {
                var result = String(text[match])
                // Extract just the DOI part (capture group)
                if let doiRange = result.range(of: "10\\.\\d{4,9}/[^\\s,;)}\\]>\"']+", options: .regularExpression) {
                    result = String(result[doiRange])
                }
                // Clean trailing punctuation
                while result.last == "." || result.last == ")" || result.last == "}" || result.last == "]" || result.last == ">" {
                    result.removeLast()
                }
                return result
            }
        }
        return nil
    }

    private func findArxivId(in text: String) -> String? {
        let patterns = [
            "arXiv[:\\s]*(\\d{4}\\.\\d{4,5}(?:v\\d+)?)",
            "arxiv\\.org/abs/(\\d{4}\\.\\d{4,5}(?:v\\d+)?)",
            "arxiv\\.org/pdf/(\\d{4}\\.\\d{4,5}(?:v\\d+)?)"
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let nsText = text as NSString
                let range = NSRange(location: 0, length: min(nsText.length, 50000))
                if let match = regex.firstMatch(in: text, range: range), match.numberOfRanges > 1 {
                    return nsText.substring(with: match.range(at: 1))
                }
            }
        }
        return nil
    }

    private func findISBN(in text: String) -> String? {
        let pattern = "ISBN[:\\s-]*(\\d{3}[\\s-]?\\d[\\s-]?\\d{3}[\\s-]?\\d{5}[\\s-]?\\d)"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let nsText = text as NSString
            let range = NSRange(location: 0, length: min(nsText.length, 50000))
            if let match = regex.firstMatch(in: text, range: range), match.numberOfRanges > 1 {
                let isbn = nsText.substring(with: match.range(at: 1))
                return isbn.replacingOccurrences(of: "[\\s-]", with: "", options: .regularExpression)
            }
        }
        return nil
    }

    private func findYear(in text: String) -> Int? {
        let pattern = "\\b(19[5-9]\\d|20[0-2]\\d)\\b"
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: min(text.count, 50000))),
           match.numberOfRanges > 1 {
            let yearStr = (text as NSString).substring(with: match.range(at: 1))
            return Int(yearStr)
        }
        return nil
    }

    // MARK: - PDF Metadata Fields

    private func extractPDFMetadata(from raw: String) -> (title: String?, authors: String?) {
        var title: String?
        var authors: String?

        // /Title (literal string)
        if let match = raw.range(of: "/Title\\s*\\(([^)]+)\\)", options: .regularExpression) {
            let full = String(raw[match])
            if let open = full.firstIndex(of: "("), let close = full.lastIndex(of: ")") {
                let t = String(full[full.index(after: open)..<close]).trimmingCharacters(in: .whitespacesAndNewlines)
                if t.count > 3 && !t.lowercased().hasPrefix("untitled") && !t.lowercased().hasPrefix("microsoft") {
                    title = t
                }
            }
        }

        // /Author (literal string)
        if let match = raw.range(of: "/Author\\s*\\(([^)]+)\\)", options: .regularExpression) {
            let full = String(raw[match])
            if let open = full.firstIndex(of: "("), let close = full.lastIndex(of: ")") {
                let a = String(full[full.index(after: open)..<close]).trimmingCharacters(in: .whitespacesAndNewlines)
                if a.count > 1 && a != "null" {
                    authors = a
                }
            }
        }

        return (title, authors)
    }

    // MARK: - Content Stream Extraction

    private func extractContentStrings(from raw: String) -> [String] {
        var strings: [String] = []

        // Match literal strings: (text) Tj or (text) TJ
        let pattern = "\\(([^)]{3,})\\)\\s*(?:Tj|TJ|'|\")"
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let nsRaw = raw as NSString
            let searchLen = min(nsRaw.length, 100000)
            let matches = regex.matches(in: raw, range: NSRange(location: 0, length: searchLen))
            for match in matches where match.numberOfRanges > 1 {
                let s = nsRaw.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
                if s.count > 3 && s.rangeOfCharacter(from: .letters) != nil {
                    strings.append(s)
                }
            }
        }

        // Also grab longer literal strings
        let longPattern = "\\(([^)]{10,200})\\)"
        if let regex = try? NSRegularExpression(pattern: longPattern) {
            let nsRaw = raw as NSString
            let searchLen = min(nsRaw.length, 100000)
            let matches = regex.matches(in: raw, range: NSRange(location: 0, length: searchLen))
            for match in matches where match.numberOfRanges > 1 {
                let s = nsRaw.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
                if s.count > 10 && s.rangeOfCharacter(from: .letters) != nil && !strings.contains(s) {
                    strings.append(s)
                }
            }
        }

        return strings
    }

    private func guessTitle(from strings: [String]) -> String? {
        let candidates = strings.prefix(30).filter { s in
            s.count > 10 && s.count < 300 &&
            !s.lowercased().hasPrefix("abstract") &&
            !s.lowercased().hasPrefix("introduction") &&
            !s.lowercased().hasPrefix("references") &&
            !s.lowercased().hasPrefix("http") &&
            !s.lowercased().hasPrefix("doi") &&
            s.rangeOfCharacter(from: .letters) != nil
        }
        return candidates.prefix(5).max(by: { $0.count < $1.count })
    }

    private func guessAuthors(from strings: [String], title: String?) -> String? {
        let titleIdx = title.flatMap { t in strings.firstIndex(of: t) } ?? -1
        let start = titleIdx >= 0 ? titleIdx + 1 : 0
        let searchStrings = Array(strings.dropFirst(start).prefix(15))

        for s in searchStrings {
            if s == title { continue }
            if s.lowercased().hasPrefix("abstract") || s.lowercased().hasPrefix("http") { continue }

            let hasComma = s.contains(",") || s.contains(";") || s.lowercased().contains(" and ")
            let hasUpperCase = s.range(of: "[A-Z][a-z]+", options: .regularExpression) != nil
            let words = s.split(separator: " ")

            if hasComma && hasUpperCase && words.count >= 2 && s.count < 500 {
                return s
            }
        }
        return nil
    }
}
