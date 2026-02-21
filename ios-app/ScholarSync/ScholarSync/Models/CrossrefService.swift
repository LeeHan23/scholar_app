import Foundation

class CrossrefService {
    static let shared = CrossrefService()
    
    private let baseURL = "https://api.crossref.org/works/"
    
    func fetchPaper(doi: String) async throws -> Paper {
        guard let url = URL(string: "\(baseURL)\(doi)") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        // Polite pool pattern for Crossref
        request.setValue("ScholarSync/1.0 (mailto:youremail@example.com)", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        // Decode Crossref specific JSON
        let decoded = try JSONDecoder().decode(CrossrefResponse.self, from: data)
        let item = decoded.message
        
        let title = item.title?.first ?? "Unknown Title"
        let authors = item.author?.compactMap { "\($0.given ?? "") \($0.family ?? "")".trimmingCharacters(in: .whitespaces) } ?? []
        let journal = item.container_title?.first
        
        // Extract year from issued > date-parts
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
