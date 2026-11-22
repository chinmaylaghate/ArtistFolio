import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @State private var showEditor = false
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AFSpacing.md) {
                if let profile = appState.profile {
                    profileCard(profile)
                } else {
                    joinCard
                }

                settingsGroup {
                    if appState.hasICloud {
                        if appState.isArtist {
                            row(icon: "heart", title: "Saved Artworks") { SavedView() }
                            Divider().padding(.leading, 56)
                            row(icon: "pencil.and.ruler", title: "Commissions") { CommissionsView() }
                            Divider().padding(.leading, 56)
                        }
                        if !appState.isArtist {
                            row(icon: "pencil.and.ruler", title: "My Commissions") { CommissionsView() }
                            Divider().padding(.leading, 56)
                        }
                        row(icon: "person.2", title: "Following") {
                            ArtistListView(kind: .following)
                        }
                        Divider().padding(.leading, 56)
                        row(icon: "hand.raised", title: "Blocked Artists") {
                            ArtistListView(kind: .blocked)
                        }
                        Divider().padding(.leading, 56)
                    }
                    row(icon: "doc.text", title: "Terms & Privacy") { LegalView() }
                }

                if appState.profile != nil {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        if isDeleting {
                            ProgressView()
                        } else {
                            Text("Delete Account").font(AFFont.bodyMedium)
                        }
                    }
                    .foregroundColor(.afError)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .disabled(isDeleting)
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
                Text("Profile").font(AFFont.headlineMedium).foregroundColor(.afTextPrimary)
            }
        }
        .artNavigation()
        .sheet(isPresented: $showEditor) { ProfileEditorView(mode: .edit) }
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

    private func profileCard(_ profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: AFSpacing.md) {
            HStack(alignment: .top, spacing: AFSpacing.md) {
                AvatarCircle(name: profile.displayName, url: profile.avatarURL, size: 72)
                VStack(alignment: .leading, spacing: AFSpacing.xxs) {
                    Text(profile.displayName).font(AFFont.headlineMedium).foregroundColor(.afTextPrimary)
                    Text(profile.role.label)
                        .font(AFFont.captionBold)
                        .foregroundColor(.white)
                        .padding(.horizontal, AFSpacing.sm)
                        .padding(.vertical, 3)
                        .background(profile.role == .artist ? Color.afPrimary : Color(hex: "#1F8A3D"))
                        .clipShape(Capsule())
                    if !profile.location.isEmpty {
                        Label(profile.location, systemImage: "mappin")
                            .font(AFFont.caption)
                            .foregroundColor(.afTextSecondary)
                    }
                }
                Spacer()
                Button { showEditor = true } label: {
                    Image(systemName: "pencil")
                        .foregroundColor(.afTextSecondary)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Edit profile")
            }
            if !profile.bio.isEmpty {
                Text(profile.bio).font(AFFont.bodySmall).foregroundColor(.afTextSecondary).lineSpacing(3)
            }
            if profile.acceptsCommissions {
                Label("Open to commissions", systemImage: "paintbrush")
                    .font(AFFont.captionBold)
                    .foregroundColor(.afPrimary)
            }
        }
        .padding(AFSpacing.md)
        .background(Color.afSurface)
        .clipShape(RoundedRectangle(cornerRadius: AFRadius.lg))
        .overlay(RoundedRectangle(cornerRadius: AFRadius.lg).stroke(Color.afBorder, lineWidth: 1))
    }

    private var joinCard: some View {
        EmptyStateView(
            icon: "person.crop.circle.badge.plus",
            title: "Join Artist Folio",
            subtitle: "Create a profile to publish your work. Browsing never needs an account.",
            actionTitle: "Create Profile"
        ) {
            appState.beginProfileSetup()
        }
        .background(Color.afSurface)
        .clipShape(RoundedRectangle(cornerRadius: AFRadius.lg))
        .overlay(RoundedRectangle(cornerRadius: AFRadius.lg).stroke(Color.afBorder, lineWidth: 1))
    }

    private func settingsGroup<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background(Color.afSurface)
            .clipShape(RoundedRectangle(cornerRadius: AFRadius.lg))
            .overlay(RoundedRectangle(cornerRadius: AFRadius.lg).stroke(Color.afBorder, lineWidth: 1))
    }

    private func row<Destination: View>(icon: String, title: String, @ViewBuilder destination: () -> Destination) -> some View {
        NavigationLink(destination: destination()) {
            HStack(spacing: AFSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(.afPrimary)
                    .frame(width: 36, height: 36)
                    .background(Color.afPrimaryBg)
                    .clipShape(RoundedRectangle(cornerRadius: AFRadius.sm))
                Text(title).font(AFFont.bodyMedium).foregroundColor(.afTextPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.afTextTertiary)
            }
            .padding(.horizontal, AFSpacing.md)
            .padding(.vertical, AFSpacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
        ScrollView {
            VStack(spacing: AFSpacing.sm) {
                if isLoading {
                    ProgressView().tint(.afPrimary).padding(.top, AFSpacing.xxxl)
                } else if artists.isEmpty {
                    EmptyStateView(
                        icon: kind == .following ? "person.2" : "hand.raised",
                        title: kind == .following ? "Not Following Anyone" : "No Blocked Artists",
                        subtitle: kind == .following ? "Follow artists to see their new work on Home." : "Artists you block will appear here."
                    )
                    .padding(.top, AFSpacing.xxxl)
                } else {
                    ForEach(artists) { artist in
                        if kind == .following {
                            NavigationLink(value: ArtistLink(id: artist.id)) { ArtistRow(profile: artist) }
                                .buttonStyle(.plain)
                        } else {
                            HStack {
                                AvatarCircle(name: artist.displayName, url: artist.avatarURL)
                                Text(artist.displayName).font(AFFont.headlineSmall).foregroundColor(.afTextPrimary)
                                Spacer()
                                Button("Unblock") { appState.setBlocked(artist.id, blocked: false) }
                                    .font(AFFont.headlineSmall)
                                    .foregroundColor(.afPrimary)
                                    .frame(minHeight: 44)
                            }
                            .padding(AFSpacing.sm)
                        }
                    }
                }
            }
            .padding(AFSpacing.md)
            .padding(.bottom, 100)
        }
        .background(Color.afBackground)
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
    @State private var showCommissionSheet = false

    private var isSelf: Bool { artistId == appState.currentUserID }

    var body: some View {
        ScrollView(showsIndicators: false) {
            if isLoading {
                ProgressView().tint(.afPrimary).padding(.top, AFSpacing.xxxl)
            } else if let profile {
                VStack(alignment: .leading, spacing: AFSpacing.lg) {
                    VStack(spacing: AFSpacing.sm) {
                        AvatarCircle(name: profile.displayName, url: profile.avatarURL, size: 88)
                        Text(profile.displayName).font(AFFont.displaySmall).foregroundColor(.afTextPrimary).multilineTextAlignment(.center)
                        if !profile.location.isEmpty {
                            Label(profile.location, systemImage: "mappin").font(AFFont.caption).foregroundColor(.afTextSecondary)
                        }
                        if !profile.bio.isEmpty {
                            Text(profile.bio).font(AFFont.bodyMedium).foregroundColor(.afTextSecondary).multilineTextAlignment(.center)
                        }
                        if profile.acceptsCommissions {
                            Label("Open to commissions", systemImage: "paintbrush").font(AFFont.captionBold).foregroundColor(.afPrimary)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    if !isSelf {
                        HStack(spacing: 12) {
                            Button(appState.isFollowing(artistId) ? "Following" : "Follow") {
                                appState.toggleFollowing(artistId)
                            }
                            .buttonStyle(AFPrimaryButtonStyle())

                            if profile.acceptsCommissions {
                                Button("Commission") { showCommissionSheet = true }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .background(Color.afPrimaryBg, in: RoundedRectangle(cornerRadius: 100))
                                    .foregroundStyle(Color.afPrimary)
                                    .font(.system(.headline, design: .rounded).weight(.semibold))
                            }
                        }
                    }

                    if !profile.contactOptions.isEmpty {
                        HStack(spacing: AFSpacing.sm) {
                            ForEach(profile.contactOptions) { option in
                                Link(destination: option.url) {
                                    Label(option.kind.rawValue, systemImage: option.icon)
                                        .labelStyle(.titleAndIcon)
                                        .font(AFFont.captionBold)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                        .frame(maxWidth: .infinity, minHeight: 44)
                                        .foregroundColor(.afPrimary)
                                        .background(Color.afPrimaryBg)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }

                    Text("Artworks").font(AFFont.headlineMedium).foregroundColor(.afTextPrimary)
                    if artworks.isEmpty {
                        EmptyStateView(icon: "photo.artframe", title: "No Artworks Yet", subtitle: "Check back soon.")
                    } else {
                        ArtworkGrid(artworks: artworks)
                    }
                }
                .padding(AFSpacing.lg)
                .padding(.bottom, 100)
            } else {
                EmptyStateView(icon: "person.crop.circle.badge.questionmark", title: "Artist Unavailable", subtitle: errorMessage ?? "This profile may have been removed.")
                    .padding(.top, AFSpacing.xxxl)
            }
        }
        .background(Color.afBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isSelf, profile != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Report Artist", systemImage: "flag") { showReport = true }
                        Button("Block Artist", systemImage: "hand.raised", role: .destructive) { showBlockConfirm = true }
                    } label: {
                        Image(systemName: "ellipsis.circle").foregroundColor(.afTextPrimary)
                    }
                    .accessibilityLabel("More options")
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
        .sheet(isPresented: $showReport) {
            ReportSheet(target: .artist, targetID: artistId, name: profile?.displayName ?? "Artist")
        }
        .sheet(isPresented: $showCommissionSheet) {
            if let p = profile {
                CommissionRequestSheet(artist: p, isPresented: $showCommissionSheet)
            }
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
}
