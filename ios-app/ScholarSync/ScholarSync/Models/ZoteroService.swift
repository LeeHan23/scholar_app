import Foundation

class ZoteroService {
    static let shared = ZoteroService()

    private let baseURL = "https://api.zotero.org"

    var apiKey: String? {
        get { KeychainHelper.read(forKey: "zoteroApiKey") }
        set {
            if let value = newValue {
                KeychainHelper.save(value, forKey: "zoteroApiKey")
            } else {
                KeychainHelper.delete(forKey: "zoteroApiKey")
            }
        }
    }

    var userId: String? {
        get { KeychainHelper.read(forKey: "zoteroUserId") }
        set {
            if let value = newValue {
                KeychainHelper.save(value, forKey: "zoteroUserId")
            } else {
                KeychainHelper.delete(forKey: "zoteroUserId")
            }
        }
    }

    var isConfigured: Bool {
        apiKey != nil && userId != nil &&
        !apiKey!.isEmpty && !userId!.isEmpty
    }

    // MARK: - Export Papers to Zotero

    func exportPapers(_ papers: [Paper]) async throws -> Int {
        guard let apiKey = apiKey, let userId = userId else {
            throw ZoteroError.notConfigured
        }

        let url = URL(string: "\(baseURL)/users/\(userId)/items")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "Zotero-API-Key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let items = papers.map { zoteroItem(from: $0) }
        request.httpBody = try JSONSerialization.data(withJSONObject: items)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ZoteroError.invalidResponse
        }

        if httpResponse.statusCode == 403 {
            throw ZoteroError.unauthorized
        }

        if httpResponse.statusCode >= 400 {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ZoteroError.apiError(httpResponse.statusCode, body)
        }

        // Zotero returns a JSON object with "successful", "unchanged", "failed" keys
        if let result = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let successful = result["successful"] as? [String: Any] {
            return successful.count
        }

        return papers.count
    }

    // MARK: - Convert Paper to Zotero Item

    private func zoteroItem(from paper: Paper) -> [String: Any] {
        var item: [String: Any] = [
            "itemType": "journalArticle",
            "title": paper.title,
            "date": String(paper.year)
        ]

        // Parse authors into Zotero creator format
        let authorNames = paper.authors.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        var creators: [[String: String]] = []
        for name in authorNames where !name.isEmpty {
            let parts = name.components(separatedBy: " ")
            if parts.count >= 2 {
                creators.append([
                    "creatorType": "author",
                    "firstName": parts.dropLast().joined(separator: " "),
                    "lastName": parts.last!
                ])
            } else {
                creators.append([
                    "creatorType": "author",
                    "lastName": name
                ])
            }
        }
        item["creators"] = creators

        if let journal = paper.journal {
            item["publicationTitle"] = journal
        }
        if let doi = paper.doi {
            item["DOI"] = doi
        }
        if let abstract = paper.abstract {
            item["abstractNote"] = abstract
        }
        if let tags = paper.tags {
            let tagList = tags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            item["tags"] = tagList.map { ["tag": $0] }
        }

        return item
    }

    func disconnect() {
        apiKey = nil
        userId = nil
    }
}

enum ZoteroError: LocalizedError {
    case notConfigured
    case invalidResponse
    case unauthorized
    case apiError(Int, String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Zotero is not configured. Add your API key and User ID in settings."
        case .invalidResponse: return "Invalid response from Zotero."
        case .unauthorized: return "Invalid Zotero API key. Check your credentials."
        case .apiError(let code, _): return "Zotero API error (\(code))"
        }
    }
}
