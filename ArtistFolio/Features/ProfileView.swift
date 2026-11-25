import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @State private var showEditor = false
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var showShare = false

    var body: some View {
        List {
            if appState.isDemoMode {
                Section {
                    Button("Exit Demo", systemImage: "rectangle.portrait.and.arrow.right") {
                        Task { await appState.exitDemo() }
                    }
                } footer: {
                    Text("You're viewing sample artists and artworks. Changes are not saved.")
                }
            }
            if let profile = appState.profile {
                Section { header(profile) }
            } else if appState.isProfileUnavailable {
                Section {
                    EmptyStateView(
                        icon: "wifi.exclamationmark",
                        title: "Couldn't Load Profile",
                        subtitle: "Check your connection and try again.",
                        actionTitle: "Try Again"
                    ) {
                        Task {
                            await appState.reloadSession()
                            if appState.isProfileUnavailable {
                                appState.alertMessage = AppError.accountUnavailable.errorDescription
                            }
                        }
                    }
                }
            } else {
                Section {
                    EmptyStateView(
                        icon: "person.crop.circle.badge.plus",
                        title: "Join Artist Folio",
                        subtitle: "Create a profile to publish your work. Browsing never needs an account.",
                        actionTitle: "Create Profile"
                    ) {
                        appState.beginProfileSetup()
                    }
                }
            }

            if appState.hasICloud {
                Section("Activity") {
                    if appState.isArtist {
                        NavigationLink { SavedView() } label: { Label("Saved Artworks", systemImage: "heart") }
                    }
                    NavigationLink { ArtistListView(kind: .following) } label: { Label("Following", systemImage: "person.2") }
                }
                Section("Privacy") {
                    NavigationLink { ArtistListView(kind: .blocked) } label: { Label("Blocked Artists", systemImage: "hand.raised") }
                    NavigationLink { LegalView() } label: { Label("Terms & Privacy", systemImage: "doc.text") }
                }
            } else {
                Section {
                    NavigationLink { LegalView() } label: { Label("Terms & Privacy", systemImage: "doc.text") }
                }
            }

            if appState.profile != nil {
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        if isDeleting { ProgressView() } else { Text("Delete Account") }
                    }
                    .disabled(isDeleting)
                }
            }
        }
        .navigationTitle("Profile")
        .toolbar {
            if appState.isArtist {
                ToolbarItem(placement: .primaryAction) {
                    Button("Share Profile", systemImage: "square.and.arrow.up") { showShare = true }
                }
            }
            if appState.profile != nil {
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit") { showEditor = true }
                }
            }
        }
        .sheet(isPresented: $showEditor) { ProfileEditorView(mode: .edit) }
        .sheet(isPresented: $showShare) {
            if let profile = appState.profile {
                SocialShareSheet(subject: .artist(profile))
            }
        }
        .confirmationDialog("Delete your account?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete Permanently", role: .destructive) {
                Task {
                    isDeleting = true
                    _ = await appState.deleteAccount()
                    isDeleting = false
                }
            }
        } message: {
            Text("This permanently removes your profile, artworks, saved art, follows, and blocks. It cannot be undone.")
        }
    }

    private func header(_ profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: AFSpacing.sm) {
            HStack(spacing: AFSpacing.md) {
                AvatarCircle(name: profile.displayName, url: profile.avatarURL, size: 64)
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.displayName).font(.title3.weight(.semibold))
                    Text(profile.location.isEmpty ? profile.role.label : "\(profile.role.label) · \(profile.location)")
                        .font(.subheadline)
                        .foregroundStyle(Color.afTextSecondary)
                }
            }
            if !profile.bio.isEmpty {
                Text(profile.bio).font(.subheadline).foregroundStyle(Color.afTextSecondary)
            }
            if profile.acceptsCommissions {
                Label("Open to commissions", systemImage: "paintbrush")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.tint)
            }
        }
        .padding(.vertical, AFSpacing.xxs)
    }
}

struct ArtistListView: View {
    enum Kind { case following, blocked }

    @EnvironmentObject var appState: AppState
    let kind: Kind
    @State private var artists: [UserProfile] = []
    @State private var isLoading = true

    private var ids: Set<String> {
        kind == .following ? appState.library.following : appState.library.blocked
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if artists.isEmpty {
                EmptyStateView(
                    icon: kind == .following ? "person.2" : "hand.raised",
                    title: kind == .following ? "Not Following Anyone" : "No Blocked Artists",
                    subtitle: kind == .following ? "Follow artists to see their new work on Home." : "Artists you block will appear here."
                )
            } else {
                List(artists) { artist in
                    if kind == .following {
                        NavigationLink(value: ArtistLink(id: artist.id)) { ArtistRow(profile: artist) }
                    } else {
                        HStack {
                            ArtistRow(profile: artist)
                            Spacer()
                            Button("Unblock") { appState.setBlocked(artist.id, blocked: false) }
                                .afGlassButton()
                                .controlSize(.small)
                        }
                    }
                }
            }
        }
        .navigationTitle(kind == .following ? "Following" : "Blocked Artists")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: ids) {
            var output: [UserProfile] = []
            for id in ids.sorted() {
                if let profile = try? await appState.backend.profile(ownerID: id) { output.append(profile) }
            }
            artists = output.sorted { $0.displayName < $1.displayName }
            isLoading = false
        }
    }
}

struct ArtistProfileView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let artistId: String
    @State private var profile: UserProfile?
    @State private var artworks: [Artwork] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showReport = false
    @State private var showBlockConfirm = false
    @State private var showShare = false

    private var isSelf: Bool { artistId == appState.currentUserID }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let profile {
                ScrollView { content(profile) }
            } else {
                EmptyStateView(icon: "person.crop.circle.badge.questionmark", title: "Artist Unavailable", subtitle: errorMessage ?? "This profile may have been removed.")
            }
        }
        .navigationTitle(profile?.displayName ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            if isSelf, profile?.role == .artist {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Share Profile", systemImage: "square.and.arrow.up") { showShare = true }
                }
            }
            if !isSelf, profile != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Report Artist", systemImage: "flag") { showReport = true }
                        Button("Block Artist", systemImage: "hand.raised", role: .destructive) { showBlockConfirm = true }
                    } label: {
                        Label("More", systemImage: "ellipsis.circle")
                    }
                }
            }
        }
        .confirmationDialog("Block \(profile?.displayName ?? "artist")?", isPresented: $showBlockConfirm, titleVisibility: .visible) {
            Button("Block Artist", role: .destructive) {
                appState.setBlocked(artistId, blocked: true)
                dismiss()
            }
        } message: {
            Text("You won't see their work. You can unblock them from Profile.")
        }
        .sheet(isPresented: $showShare) {
            if let profile {
                SocialShareSheet(subject: .artist(profile))
            }
        }
        .sheet(isPresented: $showReport) {
            ReportSheet(target: .artist, targetID: artistId, name: profile?.displayName ?? "Artist")
        }
        .task(id: "\(artistId)-\(appState.contentVersion)") {
            do {
                profile = try await appState.backend.profile(ownerID: artistId)
                artworks = try await appState.backend.artworks(ownerID: artistId)
            } catch is CancellationError {
                return
            } catch {
                errorMessage = AppState.message(for: error)
            }
            isLoading = false
        }
    }

    private func content(_ profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: AFSpacing.lg) {
            VStack(spacing: AFSpacing.xs) {
                AvatarCircle(name: profile.displayName, url: profile.avatarURL, size: 88)
                Text(profile.displayName).font(.title2.bold()).multilineTextAlignment(.center)
                if !profile.location.isEmpty {
                    Label(profile.location, systemImage: "mappin.and.ellipse")
                        .font(.subheadline)
                        .foregroundStyle(Color.afTextSecondary)
                }
                if !profile.bio.isEmpty {
                    Text(profile.bio).font(.body).foregroundStyle(Color.afTextSecondary).multilineTextAlignment(.center)
                }
                if profile.acceptsCommissions {
                    Label("Open to commissions", systemImage: "paintbrush")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.tint)
                }
            }
            .frame(maxWidth: .infinity)

            if !isSelf {
                followButton
            }

            if !profile.contactOptions.isEmpty {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: AFSpacing.xs), count: min(profile.contactOptions.count, 3)), spacing: AFSpacing.xs) {
                    ForEach(profile.contactOptions) { option in
                        Link(destination: option.url) {
                            Label(option.kind.rawValue, systemImage: option.icon)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .frame(maxWidth: .infinity)
                        }
                        .afGlassButton()
                        .controlSize(.regular)
                        .font(.footnote)
                    }
                }
            }

            Text("Artworks").font(.title2.bold())
            if artworks.isEmpty {
                EmptyStateView(icon: "photo.artframe", title: "No Artworks Yet", subtitle: "Check back soon.")
            } else {
                ArtworkGrid(artworks: artworks)
            }
        }
        .padding(AFSpacing.md)
    }

    @ViewBuilder
    private var followButton: some View {
        if appState.isFollowing(artistId) {
            Button { appState.toggleFollowing(artistId) } label: {
                Label("Following", systemImage: "checkmark").frame(maxWidth: .infinity)
            }
            .secondaryAction()
            .sensoryFeedback(.success, trigger: appState.isFollowing(artistId))
        } else {
            Button { appState.toggleFollowing(artistId) } label: {
                Text("Follow").frame(maxWidth: .infinity)
            }
            .primaryAction()
        }
    }
}
