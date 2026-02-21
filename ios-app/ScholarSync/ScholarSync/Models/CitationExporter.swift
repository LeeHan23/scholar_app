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
    
    private static func toBibTeX(_ paper: Paper) -> String {
        let firstAuthor = paper.authors.first?.components(separatedBy: .whitespaces).last ?? "Author"
        let citeKey = "\(firstAuthor)\(paper.year)"
        
        let authorsString = paper.authors.joined(separator: " and ")
        
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
    
    private static func toCSV(_ papers: [Paper]) -> String {
        var csv = "Title,Authors,Journal,Year,DOI\n"
        for p in papers {
            let authorsString = p.authors.joined(separator: "; ")
            csv += "\"\(p.title)\",\"\(authorsString)\",\"\(p.journal ?? "")\",\(p.year),\"\(p.doi ?? "")\"\n"
        }
        return csv
    }
    
    private static func toRIS(_ paper: Paper) -> String {
        var ris = "TY  - JOUR\n"
        ris += "TI  - \(paper.title)\n"
        for author in paper.authors {
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
