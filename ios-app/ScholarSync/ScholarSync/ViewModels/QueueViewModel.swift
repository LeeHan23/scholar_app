import Foundation
import Combine
import CoreLocation

@MainActor
class QueueViewModel: ObservableObject {
    @Published var papers: [Paper] = []
    @Published var projects: [Project] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let supabase = SupabaseManager.shared
    private let offline = OfflineManager.shared

    // MARK: - Data Loading

    func loadData() async {
        isLoading = true
        errorMessage = nil

        if offline.isOnline {
            do {
                async let papersResult = supabase.fetchPapers()
                async let projectsResult = supabase.fetchProjects()

                papers = try await papersResult
                projects = try await projectsResult

                // Cache for offline use
                offline.cachePapers(papers)
                offline.cacheProjects(projects)
            } catch {
                // Fall back to cached data
                papers = offline.getCachedPapers()
                projects = offline.getCachedProjects()
                if papers.isEmpty {
                    errorMessage = error.localizedDescription
                }
            }
        } else {
            // Offline — load from cache
            papers = offline.getCachedPapers()
            projects = offline.getCachedProjects()
        }

        isLoading = false
    }

    // MARK: - Papers CRUD

    func addPaper(_ paper: Paper) async {
        var newPaper = paper
        newPaper.userId = supabase.currentUserId

        if offline.isOnline {
            do {
                let saved = try await supabase.addPaper(newPaper)
                papers.insert(saved, at: 0)
                offline.cachePapers(papers)
            } catch {
                errorMessage = error.localizedDescription
            }
        } else {
            // Optimistic local insert + queue for sync
            papers.insert(newPaper, at: 0)
            offline.cachePapers(papers)
            offline.addPendingAction(type: .addPaper, item: newPaper)
        }
    }

    func updatePaper(_ paper: Paper) async {
        // Optimistic local update
        if let index = papers.firstIndex(where: { $0.id == paper.id }) {
            papers[index] = paper
        }

        if offline.isOnline {
            do {
                let updated = try await supabase.updatePaper(paper)
                if let index = papers.firstIndex(where: { $0.id == updated.id }) {
                    papers[index] = updated
                }
                offline.cachePapers(papers)
            } catch {
                errorMessage = error.localizedDescription
            }
        } else {
            offline.cachePapers(papers)
            offline.addPendingAction(type: .updatePaper, item: paper)
        }
    }

    func deletePaper(_ paper: Paper) async {
        guard let id = paper.id else { return }

        // Optimistic local delete
        papers.removeAll { $0.id == id }

        if offline.isOnline {
            do {
                try await supabase.deletePaper(id: id)
                offline.cachePapers(papers)
            } catch {
                errorMessage = error.localizedDescription
            }
        } else {
            offline.cachePapers(papers)
            offline.addPendingAction(type: .deletePaper, item: id)
        }
    }

    func togglePaperStatus(_ paper: Paper) async {
        var updated = paper
        updated.status = paper.status == .unread ? .read : .unread
        await updatePaper(updated)
    }

    // MARK: - Projects CRUD

    func addProject(name: String) async {
        let project = Project(name: name, userId: supabase.currentUserId)

        if offline.isOnline {
            do {
                let saved = try await supabase.addProject(project)
                projects.insert(saved, at: 0)
                offline.cacheProjects(projects)
            } catch {
                errorMessage = error.localizedDescription
            }
        } else {
            projects.insert(project, at: 0)
            offline.cacheProjects(projects)
            offline.addPendingAction(type: .addProject, item: project)
        }
    }

    func updateProject(_ project: Project) async {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index] = project
        }

        if offline.isOnline {
            do {
                let updated = try await supabase.updateProject(project)
                if let index = projects.firstIndex(where: { $0.id == updated.id }) {
                    projects[index] = updated
                }
                offline.cacheProjects(projects)
            } catch {
                errorMessage = error.localizedDescription
            }
        } else {
            offline.cacheProjects(projects)
            offline.addPendingAction(type: .updateProject, item: project)
        }
    }

    func deleteProject(_ project: Project) async {
        guard let id = project.id else { return }

        projects.removeAll { $0.id == id }
        for i in papers.indices where papers[i].projectId == id {
            papers[i].projectId = nil
        }

        if offline.isOnline {
            do {
                try await supabase.deleteProject(id: id)
                offline.cachePapers(papers)
                offline.cacheProjects(projects)
            } catch {
                errorMessage = error.localizedDescription
            }
        } else {
            offline.cachePapers(papers)
            offline.cacheProjects(projects)
            offline.addPendingAction(type: .deleteProject, item: id)
        }
    }

    // MARK: - Filtering

    func papersForProject(_ project: Project) -> [Paper] {
        papers.filter { $0.projectId == project.id }
    }

    // MARK: - PDF

    func uploadPDF(for paper: Paper, data: Data) async {
        guard let paperId = paper.id else { return }
        do {
            let storagePath = try await supabase.uploadPDF(data: data, paperId: paperId)
            var updated = paper
            updated.pdfUrl = storagePath
            await updatePaper(updated)
        } catch {
            errorMessage = "PDF upload failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Scanner

    func handleScannedCode(_ code: String, pageNumber: String? = nil) async {
        do {
            let fetchedPaper = try await CrossrefService.shared.fetchPaper(doi: code)
            var paper = fetchedPaper
            paper.userId = supabase.currentUserId
            paper.pageNumber = pageNumber

            // Auto-tag with current location if available
            let locationManager = LocationManager.shared
            if let placeName = locationManager.currentPlaceName {
                paper.locationName = placeName
            }
            if let location = locationManager.currentLocation {
                paper.latitude = location.coordinate.latitude
                paper.longitude = location.coordinate.longitude
            }

            let saved = try await supabase.addPaper(paper)
            papers.insert(saved, at: 0)
            offline.cachePapers(papers)
        } catch {
            errorMessage = "Failed to fetch paper: \(error.localizedDescription)"
        }
    }
}
