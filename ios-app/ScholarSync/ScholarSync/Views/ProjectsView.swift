import SwiftUI

struct ProjectsView: View {
    @EnvironmentObject var viewModel: QueueViewModel
    @State private var showingNewProject = false
    @State private var newProjectName = ""
    @State private var editingProject: Project?
    @State private var editProjectName = ""

    var body: some View {
        NavigationView {
            List {
                if viewModel.projects.isEmpty && !viewModel.isLoading {
                    VStack(alignment: .center, spacing: 16) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No projects yet")
                            .font(.headline)
                        Text("Create a project to organize your papers.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(viewModel.projects) { project in
                        NavigationLink(destination: ProjectDetailView(project: project)) {
                            HStack {
                                Image(systemName: "folder.fill")
                                    .foregroundColor(.blue)
                                VStack(alignment: .leading) {
                                    Text(project.name)
                                        .font(.headline)
                                    Text("\(viewModel.papersForProject(project).count) papers")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task { await viewModel.deleteProject(project) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }

                            Button {
                                editingProject = project
                                editProjectName = project.name
                            } label: {
                                Label("Rename", systemImage: "pencil")
                            }
                            .tint(.orange)
                        }
                    }
                }
            }
            .navigationTitle("Projects")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingNewProject = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("New Project", isPresented: $showingNewProject) {
                TextField("Project name", text: $newProjectName)
                Button("Cancel", role: .cancel) { newProjectName = "" }
                Button("Create") {
                    guard !newProjectName.isEmpty else { return }
                    let name = newProjectName
                    newProjectName = ""
                    Task { await viewModel.addProject(name: name) }
                }
            }
            .alert("Rename Project", isPresented: Binding(
                get: { editingProject != nil },
                set: { if !$0 { editingProject = nil } }
            )) {
                TextField("Project name", text: $editProjectName)
                Button("Cancel", role: .cancel) { editingProject = nil }
                Button("Save") {
                    if var project = editingProject {
                        project.name = editProjectName
                        Task { await viewModel.updateProject(project) }
                    }
                    editingProject = nil
                }
            }
        }
    }
}

// MARK: - Project Detail

struct ProjectDetailView: View {
    @EnvironmentObject var viewModel: QueueViewModel
    let project: Project
    @State private var showingAddPaper = false
    @State private var editingPaper: Paper?

    var papers: [Paper] {
        viewModel.papersForProject(project)
    }

    var body: some View {
        List {
            if papers.isEmpty {
                VStack(alignment: .center, spacing: 16) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No papers in this project")
                        .font(.headline)
                    Text("Tap + to add a paper.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            } else {
                ForEach(papers) { paper in
                    NavigationLink(destination: PaperDetailView(paper: paper)) {
                        PaperRow(paper: paper)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            var updated = paper
                            updated.projectId = nil
                            Task { await viewModel.updatePaper(updated) }
                        } label: {
                            Label("Remove", systemImage: "folder.badge.minus")
                        }

                        Button {
                            editingPaper = paper
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.orange)
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            Task { await viewModel.togglePaperStatus(paper) }
                        } label: {
                            Label(
                                paper.status == .unread ? "Read" : "Unread",
                                systemImage: paper.status == .unread ? "checkmark.circle" : "circle"
                            )
                        }
                        .tint(.green)
                    }
                }
            }
        }
        .navigationTitle(project.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddPaper = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddPaper) {
            AddEditPaperView(projects: viewModel.projects) { paper in
                var newPaper = paper
                newPaper.projectId = project.id
                Task { await viewModel.addPaper(newPaper) }
            } onPDFSelected: { data in
                Task {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    if let saved = viewModel.papers.first {
                        await viewModel.uploadPDF(for: saved, data: data)
                    }
                }
            }
        }
        .sheet(item: $editingPaper) { paper in
            AddEditPaperView(paper: paper, projects: viewModel.projects) { updatedPaper in
                Task { await viewModel.updatePaper(updatedPaper) }
            } onPDFSelected: { data in
                Task { await viewModel.uploadPDF(for: paper, data: data) }
            }
        }
    }
}
