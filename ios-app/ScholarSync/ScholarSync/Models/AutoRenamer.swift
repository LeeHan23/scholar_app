import Foundation

class AutoRenamer {
    /// Renames a file using the format: Author_Year_Title.pdf
    /// Removes special characters to ensure a clean file name.
    static func generateCleanFilename(for paper: Paper) -> String {
        let firstAuthor = paper.authors.components(separatedBy: ",").first ?? paper.authors
        let firstAuthorLastName = firstAuthor.trimmingCharacters(in: .whitespaces).components(separatedBy: .whitespaces).last ?? "UnknownAuthor"
        
        let titleWords = paper.title.split(separator: " ").prefix(4).joined(separator: "_")
        let cleanedTitle = titleWords.replacingOccurrences(of: "[^a-zA-Z0-9_]", with: "", options: .regularExpression, range: nil)
        
        return "\(firstAuthorLastName)_\(paper.year)_\(cleanedTitle).pdf"
    }
}
