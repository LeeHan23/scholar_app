import Foundation

struct Paper: Identifiable, Codable {
    var id: String { doi ?? UUID().uuidString }
    let title: String
    let authors: [String]
    let journal: String?
    let year: Int
    let doi: String?
    let abstract: String?
    var status: PaperStatus
}

enum PaperStatus: String, Codable {
    case unread
    case read
}
