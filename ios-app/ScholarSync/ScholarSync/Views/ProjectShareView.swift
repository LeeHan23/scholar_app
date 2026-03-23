import SwiftUI

struct ProjectShareView: View {
    @EnvironmentObject var viewModel: QueueViewModel
    let project: Project
    let currentUserId: String

    @State private var inviteEmail = ""
    @State private var inviteRole: ProjectMember.MemberRole = .viewer
    @State private var isInviting = false
    @State private var inviteMessage: String?
    @State private var inviteSuccess = false
    @State private var roleChangeTarget: ProjectMember?
    @Environment(\.dismiss) private var dismiss

    var members: [ProjectMember] {
        viewModel.projectMembers[project.id ?? -1] ?? []
    }

    var isOwner: Bool {
        project.userId == currentUserId
    }

    var body: some View {
        NavigationView {
            List {
                // Invite section (owners only)
                if isOwner {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            TextField("Email address", text: $inviteEmail)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)

                            Picker("Role", selection: $inviteRole) {
                                ForEach([ProjectMember.MemberRole.viewer, .editor], id: \.self) { role in
                                    Label(role.displayName, systemImage: role.icon).tag(role)
                                }
                            }
                            .pickerStyle(.segmented)

                            Button(action: sendInvite) {
                                HStack {
                                    if isInviting {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "person.badge.plus")
                                    }
                                    Text(isInviting ? "Sending…" : "Send Invitation")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(inviteEmail.isEmpty || isInviting)

                            if let message = inviteMessage {
                                HStack {
                                    Image(systemName: inviteSuccess ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                        .foregroundColor(inviteSuccess ? .green : .red)
                                    Text(message)
                                        .font(.caption)
                                        .foregroundColor(inviteSuccess ? .green : .red)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    } header: {
                        Label("Invite Member", systemImage: "person.badge.plus")
                    }
                }

                // Members list
                Section {
                    if members.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                Image(systemName: "person.2")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                                Text("No members yet")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            Spacer()
                        }
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(members) { member in
                            MemberRow(
                                member: member,
                                isOwner: isOwner,
                                isSelf: member.userId == currentUserId,
                                onRoleChange: { newRole in
                                    Task { await viewModel.updateMemberRole(member, role: newRole, in: project) }
                                },
                                onRemove: {
                                    Task { await viewModel.removeCollaborator(member, from: project) }
                                }
                            )
                        }
                    }
                } header: {
                    Label("Members (\(members.count))", systemImage: "person.2.fill")
                }
            }
            .navigationTitle(project.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await viewModel.loadMembers(for: project)
            }
        }
    }

    private func sendInvite() {
        guard !inviteEmail.isEmpty else { return }
        isInviting = true
        inviteMessage = nil
        Task {
            do {
                try await viewModel.inviteMember(to: project, email: inviteEmail, role: inviteRole)
                inviteEmail = ""
                inviteSuccess = true
                inviteMessage = "Invitation sent!"
            } catch {
                inviteSuccess = false
                inviteMessage = error.localizedDescription
            }
            isInviting = false
        }
    }
}

// MARK: - Member Row

private struct MemberRow: View {
    let member: ProjectMember
    let isOwner: Bool
    let isSelf: Bool
    let onRoleChange: (ProjectMember.MemberRole) -> Void
    let onRemove: () -> Void

    @State private var showingRolePicker = false

    var body: some View {
        HStack(spacing: 12) {
            // Avatar circle
            ZStack {
                Circle()
                    .fill(avatarColor)
                    .frame(width: 36, height: 36)
                Text(avatarInitial)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(member.displayEmail)
                    .font(.subheadline)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    if member.isPending {
                        pendingBadge
                    }
                    roleBadge
                }
            }

            Spacer()

            // Role change / remove buttons (owner only, not for self if owner)
            if isOwner && member.role != .owner {
                Menu {
                    ForEach([ProjectMember.MemberRole.editor, .viewer], id: \.self) { role in
                        Button {
                            onRoleChange(role)
                        } label: {
                            Label(role.displayName, systemImage: role.icon)
                        }
                    }
                    Divider()
                    Button(role: .destructive, action: onRemove) {
                        Label("Remove", systemImage: "person.badge.minus")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var avatarInitial: String {
        String(member.displayEmail.prefix(1)).uppercased()
    }

    private var avatarColor: Color {
        switch member.role {
        case .owner: return .purple
        case .editor: return .blue
        case .viewer: return .gray
        }
    }

    private var roleBadge: some View {
        Text(member.role.displayName)
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(roleBadgeColor.opacity(0.15))
            .foregroundColor(roleBadgeColor)
            .cornerRadius(4)
    }

    private var pendingBadge: some View {
        Text("Pending")
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.orange.opacity(0.15))
            .foregroundColor(.orange)
            .cornerRadius(4)
    }

    private var roleBadgeColor: Color {
        switch member.role {
        case .owner: return .purple
        case .editor: return .blue
        case .viewer: return .gray
        }
    }
}
