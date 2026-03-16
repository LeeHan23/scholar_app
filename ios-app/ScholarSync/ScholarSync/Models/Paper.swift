import Foundation

struct Paper: Identifiable, Codable {
    var id: Int?
    var title: String
    var authors: String
    var journal: String?
    var year: Int
    var doi: String?
    var abstract: String?
    var status: PaperStatus
    var userId: String?
    var projectId: Int?
    var tags: String?
    var locationName: String?
    var latitude: Double?
    var longitude: Double?
    var pageNumber: String?
    var pdfUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, title, authors, journal, year, doi, abstract, status, tags, latitude, longitude
        case userId = "user_id"
        case projectId = "project_id"
        case locationName = "location_name"
        case pageNumber = "page_number"
        case pdfUrl = "pdf_url"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(authors, forKey: .authors)
        try container.encodeIfPresent(journal, forKey: .journal)
        try container.encode(year, forKey: .year)
        try container.encodeIfPresent(doi, forKey: .doi)
        try container.encodeIfPresent(abstract, forKey: .abstract)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(userId, forKey: .userId)
        try container.encodeIfPresent(projectId, forKey: .projectId)
        try container.encodeIfPresent(tags, forKey: .tags)
        try container.encodeIfPresent(locationName, forKey: .locationName)
        try container.encodeIfPresent(latitude, forKey: .latitude)
        try container.encodeIfPresent(longitude, forKey: .longitude)
        try container.encodeIfPresent(pageNumber, forKey: .pageNumber)
        try container.encodeIfPresent(pdfUrl, forKey: .pdfUrl)
    }

    // MARK: - Tag Helpers

    var tagsList: [String] {
        tags?.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty } ?? []
    }

    mutating func setTags(_ list: [String]) {
        tags = list.isEmpty ? nil : list.joined(separator: ", ")
    }
}

enum PaperStatus: String, Codable {
    case unread
    case read
}
