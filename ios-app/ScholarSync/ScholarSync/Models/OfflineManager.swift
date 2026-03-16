import Foundation
import Combine
import Network

/// Manages offline caching for papers and projects.
/// Uses JSON file storage in the app's documents directory.
/// Syncs pending changes when the device goes back online.
@MainActor
class OfflineManager: ObservableObject {
    static let shared = OfflineManager()

    @Published var isOnline = true

    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "network-monitor")

    private let papersFile: URL
    private let projectsFile: URL
    private let pendingActionsFile: URL

    enum PendingActionType: String, Codable {
        case addPaper
        case updatePaper
        case deletePaper
        case addProject
        case updateProject
        case deleteProject
    }

    struct PendingAction: Codable, Identifiable {
        let id: UUID
        let type: PendingActionType
        let data: Data // encoded Paper or Project
        let timestamp: Date

        init(type: PendingActionType, data: Data) {
            self.id = UUID()
            self.type = type
            self.data = data
            self.timestamp = Date()
        }
    }

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        papersFile = docs.appendingPathComponent("cached_papers.json")
        projectsFile = docs.appendingPathComponent("cached_projects.json")
        pendingActionsFile = docs.appendingPathComponent("pending_actions.json")

        startNetworkMonitoring()
    }

    // MARK: - Network Monitoring

    private func startNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                let wasOffline = !(self?.isOnline ?? true)
                self?.isOnline = path.status == .satisfied

                // If we just came back online, sync pending actions
                if wasOffline && path.status == .satisfied {
                    await self?.syncPendingActions()
                }
            }
        }
        monitor.start(queue: monitorQueue)
    }

    // MARK: - Cache Papers

    func cachePapers(_ papers: [Paper]) {
        save(papers, to: papersFile)
    }

    func getCachedPapers() -> [Paper] {
        return load(from: papersFile) ?? []
    }

    // MARK: - Cache Projects

    func cacheProjects(_ projects: [Project]) {
        save(projects, to: projectsFile)
    }

    func getCachedProjects() -> [Project] {
        return load(from: projectsFile) ?? []
    }

    // MARK: - Pending Actions (offline queue)

    func addPendingAction(type: PendingActionType, item: any Codable) {
        guard let data = try? JSONEncoder().encode(item) else { return }
        var actions = getPendingActions()
        actions.append(PendingAction(type: type, data: data))
        save(actions, to: pendingActionsFile)
    }

    func getPendingActions() -> [PendingAction] {
        return load(from: pendingActionsFile) ?? []
    }

    private func clearPendingActions() {
        save([PendingAction](), to: pendingActionsFile)
    }

    var hasPendingActions: Bool {
        !getPendingActions().isEmpty
    }

    // MARK: - Sync

    func syncPendingActions() async {
        let actions = getPendingActions()
        guard !actions.isEmpty else { return }

        let supabase = SupabaseManager.shared
        var remaining: [PendingAction] = []

        for action in actions {
            do {
                switch action.type {
                case .addPaper:
                    let paper = try JSONDecoder().decode(Paper.self, from: action.data)
                    _ = try await supabase.addPaper(paper)
                case .updatePaper:
                    let paper = try JSONDecoder().decode(Paper.self, from: action.data)
                    _ = try await supabase.updatePaper(paper)
                case .deletePaper:
                    // Data stores just the ID as an Int
                    if let id = try? JSONDecoder().decode(Int.self, from: action.data) {
                        try await supabase.deletePaper(id: id)
                    }
                case .addProject:
                    let project = try JSONDecoder().decode(Project.self, from: action.data)
                    _ = try await supabase.addProject(project)
                case .updateProject:
                    let project = try JSONDecoder().decode(Project.self, from: action.data)
                    _ = try await supabase.updateProject(project)
                case .deleteProject:
                    if let id = try? JSONDecoder().decode(Int.self, from: action.data) {
                        try await supabase.deleteProject(id: id)
                    }
                }
            } catch {
                // Keep failed actions for retry
                print("[OfflineManager] Failed to sync action \(action.type): \(error)")
                remaining.append(action)
            }
        }

        // Replace pending with only the failed ones
        save(remaining, to: pendingActionsFile)
    }

    // MARK: - File I/O

    private func save<T: Codable>(_ items: T, to url: URL) {
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: url, options: .atomic)
        } catch {
            print("[OfflineManager] Failed to save to \(url.lastPathComponent): \(error)")
        }
    }

    private func load<T: Codable>(from url: URL) -> T? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            print("[OfflineManager] Failed to load from \(url.lastPathComponent): \(error)")
            return nil
        }
    }
}
