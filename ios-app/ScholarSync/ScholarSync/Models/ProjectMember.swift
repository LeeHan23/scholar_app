import Foundation

struct ProjectMember: Identifiable, Codable {
    var id: Int?
    var projectId: Int
    var userId: String?
    var role: MemberRole
    var invitedEmail: String?
    var accepted: Bool
    var inviteToken: String?
    var createdAt: String?

    // Populated via Supabase join: select=*,projects(name,user_id)
    var projects: ProjectInfo?

    struct ProjectInfo: Codable {
        let name: String
        let userId: String?

        enum CodingKeys: String, CodingKey {
            case name
            case userId = "user_id"
        }
    }

    enum MemberRole: String, Codable, CaseIterable {
        case owner = "owner"
        case editor = "editor"
        case viewer = "viewer"

        var displayName: String {
            switch self {
            case .owner: return "Owner"
            case .editor: return "Editor"
            case .viewer: return "Viewer"
            }
        }

        var icon: String {
            switch self {
            case .owner: return "crown.fill"
            case .editor: return "pencil.circle.fill"
            case .viewer: return "eye.fill"
            }
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, role, accepted
        case projectId = "project_id"
        case userId = "user_id"
        case invitedEmail = "invited_email"
        case inviteToken = "invite_token"
        case createdAt = "created_at"
        case projects
    }

    var isPending: Bool { !accepted }
    var displayEmail: String { invitedEmail ?? userId ?? "Unknown" }
    var projectName: String { projects?.name ?? "Unknown Project" }
}
