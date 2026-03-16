import Foundation

class CitationExporter {

    enum ExportFormat {
        case bibtex
        case ris
        case csv
    }

    static func export(papers: [Paper], format: ExportFormat) -> String {
        switch format {
        case .bibtex:
            return papers.map { toBibTeX($0) }.joined(separator: "\n\n")
        case .csv:
            return toCSV(papers)
        case .ris:
            return papers.map { toRIS($0) }.joined(separator: "\n\n")
        }
    }

    private static func authorComponents(_ paper: Paper) -> [String] {
        paper.authors.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private static func toBibTeX(_ paper: Paper) -> String {
        let authors = authorComponents(paper)
        let firstAuthorLastName = authors.first?.components(separatedBy: .whitespaces).last ?? "Author"
        let citeKey = "\(firstAuthorLastName)\(paper.year)"
        let authorsString = authors.joined(separator: " and ")

        return """
        @article{\(citeKey),
          title={\(paper.title)},
          author={\(authorsString)},
          journal={\(paper.journal ?? "Unknown")},
          year={\(paper.year)},
          doi={\(paper.doi ?? "")}
        }
        """
    }

    private static func escapeCSV(_ value: String) -> String {
        // Escape embedded quotes by doubling them, then wrap in quotes
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private static func toCSV(_ papers: [Paper]) -> String {
        var csv = "Title,Authors,Journal,Year,DOI\n"
        for p in papers {
            csv += "\(escapeCSV(p.title)),\(escapeCSV(p.authors)),\(escapeCSV(p.journal ?? "")),\(p.year),\(escapeCSV(p.doi ?? ""))\n"
        }
        return csv
    }

    private static func toRIS(_ paper: Paper) -> String {
        let authors = authorComponents(paper)
        var ris = "TY  - JOUR\n"
        ris += "TI  - \(paper.title)\n"
        for author in authors {
            ris += "AU  - \(author)\n"
        }
        if let journal = paper.journal {
            ris += "JO  - \(journal)\n"
        }
        ris += "PY  - \(paper.year)\n"
        if let doi = paper.doi {
            ris += "DO  - \(doi)\n"
        }
        ris += "ER  - "
        return ris
    }
}
