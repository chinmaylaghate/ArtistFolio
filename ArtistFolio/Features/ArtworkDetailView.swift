import SwiftUI

struct ArtworkDetailView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State var artwork: Artwork
    @State private var imageURLs: [URL] = []
    @State private var selectedImage = 0
    @State private var artist: UserProfile?
    @State private var showContact = false
    @State private var showReport = false
    @State private var showBlockConfirm = false
    @State private var showEditor = false

    private var isOwner: Bool { artwork.artistId == appState.currentUserID }
    private var isSaved: Bool { appState.isSaved(artwork.id) }
    private var galleryURLs: [URL] {
        imageURLs.isEmpty ? [artwork.thumbnailURL].compactMap { $0 } : imageURLs
    }

    var body: some View {
        List {
            Section {
                gallery
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            Section {
                VStack(alignment: .leading, spacing: AFSpacing.xxs) {
                    Text(artwork.title).font(.title2.bold())
                    Text("\(artwork.medium.rawValue) · \(String(artwork.year))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack(spacing: AFSpacing.xs) {
                        Text(artwork.priceText).font(.title3.weight(.semibold))
                        if artwork.status != .available { StatusBadge(status: artwork.status) }
                    }
                    .padding(.top, AFSpacing.xxs)
                }
                .padding(.vertical, AFSpacing.xxs)

                NavigationLink(value: ArtistLink(id: artwork.artistId)) {
                    HStack(spacing: AFSpacing.sm) {
                        AvatarCircle(name: artwork.artistName, url: artist?.avatarURL, size: 36)
                        Text(artwork.artistName)
                    }
                }
            }

            if !artwork.details.isEmpty {
                Section("About") {
                    Text(artwork.details).font(.body)
                }
            }

            Section("Details") {
                LabeledContent("Medium", value: artwork.medium.rawValue)
                LabeledContent("Style", value: artwork.style.rawValue)
                LabeledContent("Dimensions", value: artwork.dimensions.displayString)
                LabeledContent("Year", value: String(artwork.year))
                LabeledContent("Status", value: artwork.status.label)
            }

            if !artwork.tags.isEmpty {
                Section("Tags") {
                    FlowLayout(spacing: AFSpacing.xs) {
                        ForEach(artwork.tags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, AFSpacing.xxs)
                                .background(Color(uiColor: .tertiarySystemFill), in: Capsule())
                        }
                    }
                    .padding(.vertical, AFSpacing.xxs)
                }
            }

            Section {
            } footer: {
                Text("Artist Folio does not process sales. Arrange payment and delivery directly with the artist.")
            }
        }
        .listSectionSpacing(.compact)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    appState.toggleSaved(artwork.id)
                } label: {
                    Label(isSaved ? "Remove from Saved" : "Save", systemImage: isSaved ? "heart.fill" : "heart")
                        .symbolEffect(.bounce, value: isSaved)
                }
                .tint(isSaved ? .red : nil)
                .sensoryFeedback(.selection, trigger: isSaved)

                ShareLink(item: "\(artwork.title) by \(artwork.artistName) on Artist Folio")

                if !isOwner {
                    Menu {
                        Button("Report Artwork", systemImage: "flag") { showReport = true }
                        Button("Block Artist", systemImage: "hand.raised", role: .destructive) { showBlockConfirm = true }
                    } label: {
                        Label("More", systemImage: "ellipsis.circle")
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) { bottomBar }
        .confirmationDialog("Contact \(artwork.artistName)", isPresented: $showContact, titleVisibility: .visible) {
            ForEach(artist?.contactOptions ?? []) { option in
                Link(option.kind.rawValue, destination: option.url)
            }
        }
        .confirmationDialog("Block \(artwork.artistName)?", isPresented: $showBlockConfirm, titleVisibility: .visible) {
            Button("Block Artist", role: .destructive) {
                appState.setBlocked(artwork.artistId, blocked: true)
                dismiss()
            }
        } message: {
            Text("You won't see their work. You can unblock them from Profile.")
        }
        .sheet(isPresented: $showReport) {
            ReportSheet(target: .artwork, targetID: artwork.id, name: artwork.title)
        }
        .sheet(isPresented: $showEditor) {
            ArtworkEditorView(existing: artwork) { updated in
                if let updated { artwork = updated } else { dismiss() }
            }
        }
        .task(id: artwork.id) {
            artist = try? await appState.backend.profile(ownerID: artwork.artistId)
            imageURLs = (try? await appState.backend.fullImages(artworkID: artwork.id)) ?? []
        }
    }

    private var gallery: some View {
        TabView(selection: $selectedImage) {
            if galleryURLs.isEmpty {
                CloudImage(url: nil).tag(0)
            }
            ForEach(Array(galleryURLs.enumerated()), id: \.offset) { index, url in
                CloudImage(url: url, maxPixels: 1600, contentMode: .fit).tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: galleryURLs.count > 1 ? .automatic : .never))
        .frame(height: 380)
        .clipShape(RoundedRectangle(cornerRadius: AFRadius.md, style: .continuous))
        .accessibilityLabel("Photos of \(artwork.title)")
    }

    @ViewBuilder
    private var bottomBar: some View {
        if isOwner {
            barContainer {
                Button { showEditor = true } label: {
                    Text("Edit Artwork").frame(maxWidth: .infinity)
                }
                .primaryAction()
            }
        } else if artwork.status == .sold {
            barContainer {
                Text("This piece has sold")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        } else if let options = artist?.contactOptions, !options.isEmpty {
            barContainer {
                Button { showContact = true } label: {
                    Label("Contact Artist", systemImage: "paperplane.fill").frame(maxWidth: .infinity)
                }
                .primaryAction()
            }
        } else {
            barContainer {
                Text("No contact details available")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func barContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, AFSpacing.md)
            .padding(.vertical, AFSpacing.xs)
            .background(.bar)
    }
}

struct ReportSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let target: ReportTarget
    let targetID: String
    let name: String
    @State private var reason: ReportReason = .stolen
    @State private var note = ""
    @State private var isSending = false
    @State private var didSend = false

    var body: some View {
        NavigationStack {
            Group {
                if didSend {
                    EmptyStateView(icon: "checkmark.shield", title: "Report Received", subtitle: "Thank you. We review reports within 24 hours.", actionTitle: "Done") {
                        dismiss()
                    }
                } else {
                    Form {
                        Section("Reporting \(name)") {
                            Picker("Reason", selection: $reason) {
                                ForEach(ReportReason.allCases) { Text($0.rawValue).tag($0) }
                            }
                            .pickerStyle(.inline)
                            .labelsHidden()
                        }
                        Section("Details (optional)") {
                            TextField("Add anything that helps us review this", text: $note, axis: .vertical)
                                .lineLimit(3...6)
                        }
                    }
                }
            }
            .navigationTitle("Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !didSend {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        if isSending {
                            ProgressView()
                        } else {
                            Button("Submit") {
                                Task {
                                    isSending = true
                                    didSend = await appState.report(target: target, targetID: targetID, reason: reason, note: note.trimmed)
                                    isSending = false
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
