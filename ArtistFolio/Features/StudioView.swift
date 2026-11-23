import SwiftUI

struct StudioView: View {
    @EnvironmentObject var appState: AppState
    @State private var artworks: [Artwork] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var editing: Artwork?
    @State private var showNew = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let errorMessage, artworks.isEmpty {
                EmptyStateView(icon: "wifi.exclamationmark", title: "Couldn't Load Studio", subtitle: errorMessage, actionTitle: "Try Again") {
                    Task { await load() }
                }
            } else if artworks.isEmpty {
                EmptyStateView(icon: "paintpalette", title: "Your Studio Is Empty", subtitle: "Publish your first artwork so collectors can find it.", actionTitle: "Add Artwork") {
                    showNew = true
                }
            } else {
                List(artworks) { artwork in
                    NavigationLink(value: artwork) { row(artwork) }
                        .swipeActions(edge: .trailing) {
                            Button("Edit", systemImage: "pencil") { editing = artwork }
                                .tint(.afPrimary)
                        }
                        .contextMenu { actions(artwork) }
                }
                .refreshable { await load() }
            }
        }
        .navigationTitle("Studio")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("New Artwork", systemImage: "plus") { showNew = true }
            }
        }
        .task(id: appState.contentVersion) { await load() }
        .sheet(isPresented: $showNew) { ArtworkEditorView(existing: nil) }
        .sheet(item: $editing) { ArtworkEditorView(existing: $0) }
    }

    private func row(_ artwork: Artwork) -> some View {
        HStack(spacing: AFSpacing.sm) {
            CloudImage(url: artwork.thumbnailURL, maxPixels: 240, contentMode: .fit)
                .frame(width: 60, height: 60)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: AFRadius.sm, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(artwork.title).font(.body).lineLimit(1)
                Text("\(artwork.priceText) · \(artwork.status.label)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func actions(_ artwork: Artwork) -> some View {
        Button("Edit", systemImage: "pencil") { editing = artwork }
        Picker(selection: Binding(
            get: { artwork.status },
            set: { value in Task { await setStatus(artwork, value) } }
        )) {
            ForEach(ArtworkStatus.allCases) { Text($0.label).tag($0) }
        } label: {
            Label("Status", systemImage: "tag")
        }
        .pickerStyle(.menu)
    }

    private func load() async {
        guard let id = appState.currentUserID else { return }
        errorMessage = nil
        do {
            artworks = try await appState.backend.artworks(ownerID: id)
        } catch is CancellationError {
            return
        } catch {
            errorMessage = AppState.message(for: error)
        }
        isLoading = false
    }

    private func setStatus(_ artwork: Artwork, _ status: ArtworkStatus) async {
        guard artwork.status != status else { return }
        var updated = artwork
        updated.status = status
        do {
            _ = try await appState.backend.saveArtwork(updated, images: nil)
            appState.refreshContent()
        } catch {
            appState.alertMessage = AppState.message(for: error)
        }
    }
}
