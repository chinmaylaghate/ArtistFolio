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
    private var galleryURLs: [URL] {
        imageURLs.isEmpty ? [artwork.thumbnailURL].compactMap { $0 } : imageURLs
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                gallery

                HStack(spacing: AFSpacing.sm) {
                    chip(icon: appState.isSaved(artwork.id) ? "heart.fill" : "heart",
                         label: appState.isSaved(artwork.id) ? "Saved" : "Save",
                         tint: appState.isSaved(artwork.id) ? .afError : .afTextSecondary) {
                        appState.toggleSaved(artwork.id)
                    }
                    ShareLink(item: "\(artwork.title) by \(artwork.artistName) on Artist Folio") {
                        chipLabel(icon: "square.and.arrow.up", label: "Share", tint: .afTextSecondary)
                    }
                    Spacer()
                }
                .padding(AFSpacing.md)

                VStack(alignment: .leading, spacing: AFSpacing.lg) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(artwork.title).font(AFFont.displaySmall).foregroundColor(.afTextPrimary)
                            Text("\(artwork.medium.rawValue) · \(String(artwork.year))")
                                .font(AFFont.bodySmall)
                                .foregroundColor(.afTextSecondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(artwork.priceText).font(AFFont.priceLarge).foregroundColor(.afPrimary)
                            if artwork.status != .available { StatusBadge(status: artwork.status) }
                        }
                    }

                    Divider()

                    NavigationLink(value: ArtistLink(id: artwork.artistId)) {
                        HStack(spacing: AFSpacing.md) {
                            AvatarCircle(name: artwork.artistName, url: artist?.avatarURL, size: 48)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(artwork.artistName).font(AFFont.headlineSmall).foregroundColor(.afTextPrimary)
                                Text("View profile").font(AFFont.caption).foregroundColor(.afTextSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(.afTextTertiary)
                        }
                    }
                    .buttonStyle(.plain)

                    Divider()

                    if !artwork.details.isEmpty {
                        VStack(alignment: .leading, spacing: AFSpacing.xs) {
                            Text("About this piece").font(AFFont.headlineSmall).foregroundColor(.afTextPrimary)
                            Text(artwork.details).font(AFFont.bodyMedium).foregroundColor(.afTextSecondary).lineSpacing(4)
                        }
                    }

                    detailsTable

                    if !artwork.tags.isEmpty {
                        FlowLayout(spacing: AFSpacing.xs) {
                            ForEach(artwork.tags, id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(AFFont.labelMedium)
                                    .foregroundColor(.afPrimary)
                                    .padding(.horizontal, AFSpacing.sm)
                                    .padding(.vertical, AFSpacing.xxs)
                                    .background(Color.afPrimaryBg)
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    Text("Artist Folio does not process sales. Arrange payment and delivery directly with the artist.")
                        .font(AFFont.caption)
                        .foregroundColor(.afTextSecondary)
                }
                .padding(.horizontal, AFSpacing.md)
                .padding(.bottom, AFSpacing.lg)
            }
        }
        .background(Color.afBackground)
        .onAppear { appState.tabBarHiders += 1 }
        .onDisappear { appState.tabBarHiders -= 1 }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isOwner {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Report Artwork", systemImage: "flag") { showReport = true }
                        Button("Block Artist", systemImage: "hand.raised", role: .destructive) { showBlockConfirm = true }
                    } label: {
                        Image(systemName: "ellipsis.circle").foregroundColor(.afTextPrimary)
                    }
                    .accessibilityLabel("More options")
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
        VStack(spacing: AFSpacing.xs) {
            TabView(selection: $selectedImage) {
                if galleryURLs.isEmpty {
                    CloudImage(url: nil).tag(0)
                }
                ForEach(Array(galleryURLs.enumerated()), id: \.offset) { index, url in
                    CloudImage(url: url, maxPixels: 1600, contentMode: .fit).tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: galleryURLs.count > 1 ? .automatic : .never))
            .frame(height: 400)
            .background(Color.afSurface2)
            .accessibilityLabel("Photos of \(artwork.title)")
        }
    }

    private var detailsTable: some View {
        let rows = [
            ("Medium", artwork.medium.rawValue),
            ("Style", artwork.style.rawValue),
            ("Dimensions", artwork.dimensions.displayString),
            ("Year", String(artwork.year)),
            ("Status", artwork.status.label)
        ]
        return VStack(spacing: 0) {
            ForEach(rows, id: \.0) { row in
                HStack {
                    Text(row.0).foregroundColor(.afTextSecondary)
                    Spacer()
                    Text(row.1).foregroundColor(.afTextPrimary)
                }
                .font(AFFont.bodySmall)
                .padding(.vertical, AFSpacing.sm)
                .accessibilityElement(children: .combine)
                if row.0 != rows.last?.0 { Divider() }
            }
        }
        .padding(.horizontal, AFSpacing.md)
        .background(Color.afSurface2)
        .clipShape(RoundedRectangle(cornerRadius: AFRadius.md))
    }

    @ViewBuilder
    private var bottomBar: some View {
        Group {
            if isOwner {
                Button("Edit Artwork") { showEditor = true }
                    .buttonStyle(AFPrimaryButtonStyle())
            } else if artwork.status == .sold {
                Text("This piece has sold")
                    .font(AFFont.headlineSmall)
                    .foregroundColor(.afTextSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.afSurface2)
                    .clipShape(Capsule())
            } else if let options = artist?.contactOptions, !options.isEmpty {
                Button { showContact = true } label: {
                    Label("Contact Artist", systemImage: "paperplane.fill")
                }
                .buttonStyle(AFPrimaryButtonStyle())
            } else {
                Text("No contact details available")
                    .font(AFFont.headlineSmall)
                    .foregroundColor(.afTextSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
            }
        }
        .padding(.horizontal, AFSpacing.md)
        .padding(.vertical, AFSpacing.sm)
        .background(.ultraThinMaterial)
    }

    private func chip(icon: String, label: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) { chipLabel(icon: icon, label: label, tint: tint) }
    }

    private func chipLabel(icon: String, label: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 13, weight: .medium))
            Text(label).font(AFFont.captionBold)
        }
        .foregroundColor(tint)
        .padding(.horizontal, AFSpacing.md)
        .frame(height: 36)
        .background(tint.opacity(0.1))
        .clipShape(Capsule())
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
                    .frame(maxHeight: .infinity)
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
                    .tint(.afPrimary)
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
