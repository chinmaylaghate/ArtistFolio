import SwiftUI

struct StudioView: View {
    @EnvironmentObject var appState: AppState
    @State private var artworks: [Artwork] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var editing: Artwork?
    @State private var showNew = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AFSpacing.sm) {
                if isLoading {
                    ProgressView().tint(.afPrimary).padding(.top, AFSpacing.xxxl)
                } else if let errorMessage, artworks.isEmpty {
                    EmptyStateView(icon: "wifi.exclamationmark", title: "Couldn't Load Studio", subtitle: errorMessage, actionTitle: "Try Again") {
                        Task { await load() }
                    }
                } else if artworks.isEmpty {
                    EmptyStateView(icon: "paintpalette", title: "Your Studio Is Empty", subtitle: "Publish your first artwork so collectors can find it.", actionTitle: "Add Artwork") {
                        showNew = true
                    }
                    .padding(.top, AFSpacing.xxxl)
                } else {
                    ForEach(artworks) { artwork in
                        listingRow(artwork)
                    }
                }
            }
            .padding(.horizontal, AFSpacing.md)
            .padding(.top, AFSpacing.sm)
            .padding(.bottom, 110)
        }
        .background(Color.afBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Studio").font(AFFont.headlineMedium).foregroundColor(.afTextPrimary)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showNew = true } label: {
                    Image(systemName: "plus").font(.system(size: 16, weight: .bold)).foregroundColor(.afPrimary)
                }
                .accessibilityLabel("New artwork")
            }
        }
        .artNavigation()
        .refreshable { await load() }
        .task(id: appState.contentVersion) { await load() }
        .sheet(isPresented: $showNew) { ArtworkEditorView(existing: nil) }
        .sheet(item: $editing) { ArtworkEditorView(existing: $0) }
    }

    private func listingRow(_ artwork: Artwork) -> some View {
        HStack(spacing: AFSpacing.sm) {
            NavigationLink(value: artwork) {
                HStack(spacing: AFSpacing.sm) {
                    CloudImage(url: artwork.thumbnailURL, maxPixels: 240)
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: AFRadius.sm))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(artwork.title).font(AFFont.headlineSmall).foregroundColor(.afTextPrimary).lineLimit(1)
                        Text(artwork.priceText).font(AFFont.bodySmall).foregroundColor(.afPrimary)
                        Text(artwork.status.label).font(AFFont.caption).foregroundColor(.afTextSecondary)
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Menu {
                Button("Edit", systemImage: "pencil") { editing = artwork }
                Picker("Status", selection: Binding(
                    get: { artwork.status },
                    set: { value in Task { await setStatus(artwork, value) } }
                )) {
                    ForEach(ArtworkStatus.allCases) { Text("Mark \($0.label)").tag($0) }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundColor(.afTextSecondary)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Options for \(artwork.title)")
        }
        .padding(AFSpacing.xs)
        .background(Color.afSurface)
        .clipShape(RoundedRectangle(cornerRadius: AFRadius.md))
        .overlay(RoundedRectangle(cornerRadius: AFRadius.md).stroke(Color.afBorder, lineWidth: 1))
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
