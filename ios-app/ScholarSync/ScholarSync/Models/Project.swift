import Foundation

struct Project: Identifiable, Codable {
    var id: Int?
    var name: String
    var userId: String?
    var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name
        case userId = "user_id"
        case createdAt = "created_at"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(userId, forKey: .userId)
    }
}
