import Foundation

class CrossrefService {
    static let shared = CrossrefService()
    
    private let baseURL = "https://api.crossref.org/works/"
    
    /// Fetch paper metadata by DOI or ISBN. Detects the identifier type automatically.
    func fetchPaper(doi: String) async throws -> Paper {
        let trimmed = doi.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check if this looks like an ISBN (10 or 13 digits, possibly with hyphens)
        let digitsOnly = trimmed.replacingOccurrences(of: "[^0-9X]", with: "", options: .regularExpression)
        if (digitsOnly.count == 10 || digitsOnly.count == 13) && !trimmed.hasPrefix("10.") {
            return try await fetchByISBN(digitsOnly)
        }

        return try await fetchByDOI(trimmed)
    }

    private func fetchByDOI(_ doi: String) async throws -> Paper {
        // Validate DOI format: must start with "10." and contain a "/"
        guard doi.hasPrefix("10."), doi.contains("/") else {
            throw URLError(.badURL)
        }

        // URL-encode the DOI to prevent path traversal or injection
        guard let encoded = doi.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "\(baseURL)\(encoded)") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("ScholarSync/1.0 (mailto:contact@scholarsync.app)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(CrossrefResponse.self, from: data)
        let item = decoded.message

        let title = item.title?.first ?? "Unknown Title"
        let authorsList = item.author?.compactMap { "\($0.given ?? "") \($0.family ?? "")".trimmingCharacters(in: .whitespaces) } ?? []
        let authors = authorsList.joined(separator: ", ")
        let journal = item.container_title?.first

        var year = Calendar.current.component(.year, from: Date())
        if let parts = item.issued?.date_parts?.first, let parsedYear = parts.first {
            year = parsedYear
        }

        return Paper(
            title: title,
            authors: authors,
            journal: journal,
            year: year,
            doi: item.DOI,
            abstract: item.abstract,
            status: .unread
        )
    }

    /// Look up a book by ISBN using the Open Library API.
    private func fetchByISBN(_ isbn: String) async throws -> Paper {
        guard let url = URL(string: "https://openlibrary.org/api/books?bibkeys=ISBN:\(isbn)&format=json&jscmd=data") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("ScholarSync/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        // Open Library returns { "ISBN:1234567890": { ... } }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let bookData = json["ISBN:\(isbn)"] as? [String: Any] else {
            throw URLError(.cannotParseResponse)
        }

        let title = bookData["title"] as? String ?? "Unknown Title"

        var authors = ""
        if let authorArray = bookData["authors"] as? [[String: Any]] {
            authors = authorArray.compactMap { $0["name"] as? String }.joined(separator: ", ")
        }

        var publisher: String?
        if let pubArray = bookData["publishers"] as? [[String: Any]] {
            publisher = pubArray.first?["name"] as? String
        }

        var year = Calendar.current.component(.year, from: Date())
        if let publishDate = bookData["publish_date"] as? String {
            // Extract 4-digit year from strings like "March 2020" or "2019"
            let yearPattern = try? NSRegularExpression(pattern: "\\b(\\d{4})\\b")
            let range = NSRange(publishDate.startIndex..., in: publishDate)
            if let match = yearPattern?.firstMatch(in: publishDate, range: range),
               let yearRange = Range(match.range(at: 1), in: publishDate),
               let parsed = Int(publishDate[yearRange]) {
                year = parsed
            }
        }

        return Paper(
            title: title,
            authors: authors,
            journal: publisher,
            year: year,
            doi: nil,
            abstract: nil,
            status: .unread
        )
    }
}

// MARK: - API Response Models
struct CrossrefResponse: Codable {
    let message: CrossrefItem
}

struct CrossrefItem: Codable {
    let title: [String]?
    let DOI: String?
    let author: [CrossrefAuthor]?
    let container_title: [String]?
    let abstract: String?
    let issued: CrossrefIssued?
    
    enum CodingKeys: String, CodingKey {
        case title, DOI, author, abstract, issued
        case container_title = "container-title"
    }
}

struct CrossrefAuthor: Codable {
    let given: String?
    let family: String?
}

struct CrossrefIssued: Codable {
    let date_parts: [[Int]]?
    
    enum CodingKeys: String, CodingKey {
        case date_parts = "date-parts"
    }
}
