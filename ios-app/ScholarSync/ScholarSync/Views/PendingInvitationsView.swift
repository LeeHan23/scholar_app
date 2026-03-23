import SwiftUI

struct PendingInvitationsView: View {
    @EnvironmentObject var viewModel: QueueViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Group {
                if viewModel.pendingInvitations.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No Pending Invitations")
                            .font(.headline)
                        Text("When someone invites you to a group project, it will appear here.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(viewModel.pendingInvitations) { invitation in
                        InvitationRow(invitation: invitation)
                    }
                }
            }
            .navigationTitle("Group Invitations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await viewModel.loadPendingInvitations()
            }
        }
    }
}

// MARK: - Invitation Row

private struct InvitationRow: View {
    @EnvironmentObject var viewModel: QueueViewModel
    let invitation: ProjectMember
    @State private var isAccepting = false
    @State private var isDeclining = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundColor(.blue)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(invitation.projectName)
                        .font(.headline)
                    Text("Invited as \(invitation.role.displayName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            HStack(spacing: 12) {
                Button(action: accept) {
                    HStack {
                        if isAccepting {
                            ProgressView().scaleEffect(0.75)
                        } else {
                            Image(systemName: "checkmark")
                        }
                        Text("Accept")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(isAccepting || isDeclining)

                Button(action: decline) {
                    HStack {
                        if isDeclining {
                            ProgressView().scaleEffect(0.75)
                        } else {
                            Image(systemName: "xmark")
                        }
                        Text("Decline")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(isAccepting || isDeclining)
            }
        }
        .padding(.vertical, 4)
    }

    private func accept() {
        isAccepting = true
        Task {
            await viewModel.acceptInvitation(invitation)
            isAccepting = false
        }
    }

    private func decline() {
        isDeclining = true
        Task {
            await viewModel.declineInvitation(invitation)
            isDeclining = false
        }
    }
}
