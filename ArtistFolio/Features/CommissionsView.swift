import SwiftUI

// MARK: - Commission Request Form (collector → artist)

struct CommissionRequestSheet: View {
    @EnvironmentObject var appState: AppState
    let artist: UserProfile
    @Binding var isPresented: Bool

    @State private var description = ""
    @State private var budget = ""
    @State private var selectedStyles: Set<ArtworkStyle> = []
    @State private var isSending = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        AvatarCircle(name: artist.displayName, url: artist.avatarURL, size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(artist.displayName).font(.headline)
                            if !artist.location.isEmpty {
                                Text(artist.location).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } header: { Text("Artist") }

                Section {
                    TextAreaField(label: "DESCRIPTION", placeholder: "Describe what you're looking for...", text: $description)
                        .frame(minHeight: 80)
                } header: { Text("Description") }
                    .listRowBackground(Color(uiColor: .secondarySystemGroupedBackground))

                Section {
                    FormField(label: "Budget (USD)", placeholder: "e.g. 500", text: $budget)
                        .keyboardType(.decimalPad)
                    if artist.commissionMinBudget > 0 {
                        Text("Minimum: \(artist.commissionMinBudget.formatted(.currency(code: "USD").precision(.fractionLength(0))))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if !artist.commissionWeeks.isEmpty {
                        Text("Typical turnaround: \(artist.commissionWeeks)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } header: { Text("Budget & Terms") }

                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))], spacing: 8) {
                        ForEach(ArtworkStyle.allCases) { style in
                            let on = selectedStyles.contains(style)
                            Text(style.rawValue)
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .frame(maxWidth: .infinity)
                                .background(on ? Color.afPrimary : Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
                                .foregroundStyle(on ? .white : .primary)
                                .onTapGesture {
                                    if on { selectedStyles.remove(style) } else { selectedStyles.insert(style) }
                                }
                        }
                    }
                    .padding(.vertical, 4)
                } header: { Text("Preferred Styles (optional)") }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red).font(.subheadline)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Commission Request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") { Task { await send() } }
                        .bold()
                        .disabled(!canSend || isSending)
                }
            }
            .overlay {
                if isSending { ProgressView().tint(.afPrimary) }
            }
        }
    }

    private var canSend: Bool {
        !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && budgetValue > 0
    }

    private var budgetValue: Double { Double(budget) ?? 0 }

    private func send() async {
        isSending = true
        defer { isSending = false }
        do {
            _ = try await appState.backend.sendCommissionRequest(
                artistID: artist.id,
                artistName: artist.displayName,
                description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                budget: budgetValue,
                styles: Array(selectedStyles)
            )
            isPresented = false
        } catch {
            errorMessage = AppState.message(for: error)
        }
    }
}

// MARK: - Commission Management (artist in Studio / collector in profile)

@MainActor
final class CommissionsModel: ObservableObject {
    @Published var requests: [CommissionRequest] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load(backend: ArtBackend) async {
        isLoading = requests.isEmpty
        defer { isLoading = false }
        do {
            requests = try await backend.commissionRequests()
        } catch {
            errorMessage = AppState.message(for: error)
        }
    }

    func update(_ id: String, status: CommissionStatus, backend: ArtBackend) async {
        do {
            try await backend.updateCommissionRequest(id: id, status: status)
            if let idx = requests.firstIndex(where: { $0.id == id }) {
                requests[idx].status = status
            }
        } catch {
            errorMessage = AppState.message(for: error)
        }
    }
}

struct CommissionsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var model = CommissionsModel()

    var body: some View {
        Group {
            if model.isLoading {
                ProgressView().tint(.afPrimary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.requests.isEmpty {
                EmptyStateView(icon: "pencil.and.ruler", title: "No Commissions", subtitle: "Commission requests will appear here.")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(CommissionStatus.allCases) { status in
                        let items = model.requests.filter { $0.status == status }
                        if !items.isEmpty {
                            Section(status.label) {
                                ForEach(items) { req in
                                    CommissionCard(request: req, myID: appState.currentUserID ?? "") { newStatus in
                                        Task { await model.update(req.id, status: newStatus, backend: appState.backend) }
                                    }
                                    .listRowBackground(Color(uiColor: .secondarySystemGroupedBackground))
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Commissions")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: appState.contentVersion) { await model.load(backend: appState.backend) }
        .refreshable { await model.load(backend: appState.backend) }
        .alert("Error", isPresented: .constant(model.errorMessage != nil)) {
            Button("OK") { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
    }
}

struct CommissionCard: View {
    let request: CommissionRequest
    let myID: String
    let onStatusChange: (CommissionStatus) -> Void

    private var isArtist: Bool { request.artistID == myID }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(isArtist ? request.collectorName : request.artistName)
                        .font(.headline)
                    Text(request.date, style: .date)
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(request.status.label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor, in: Capsule())
            }

            Text(request.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            HStack(spacing: 16) {
                Label(request.budgetText, systemImage: "dollarsign.circle")
                if !request.styles.isEmpty {
                    Label(request.styles.map(\.rawValue).joined(separator: ", "), systemImage: "paintpalette")
                        .lineLimit(1)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if isArtist && request.status == .pending {
                HStack(spacing: 10) {
                    Button { onStatusChange(.declined) } label: {
                        Text("Decline")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(.primary)
                    }
                    Button { onStatusChange(.accepted) } label: {
                        Text("Accept")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.afPrimary, in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
                .font(.subheadline.weight(.medium))
            }
        }
        .padding(.vertical, 6)
    }

    private var statusColor: Color {
        switch request.status {
        case .pending: return .orange
        case .accepted: return .green
        case .declined: return .red
        }
    }
}
