import PhotosUI
import SwiftUI

struct ProfileEditorView: View {
    enum Mode { case create, edit }

    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let mode: Mode

    @State private var role: UserRole = .collector
    @State private var displayName = ""
    @State private var location = ""
    @State private var bio = ""
    @State private var email = ""
    @State private var instagram = ""
    @State private var website = ""
    @State private var acceptsCommissions = false
    @State private var acceptedTerms = false
    @State private var avatarItem: PhotosPickerItem?
    @State private var avatarData: Data?
    @State private var avatarPreview: UIImage?
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var validationMessage: String? {
        if displayName.trimmed.isEmpty { return "Add a display name." }
        if !email.trimmed.isEmpty, ContactLinks.mailURL(email) == nil { return "Enter a valid email." }
        if !instagram.trimmed.isEmpty, ContactLinks.instagramURL(instagram) == nil { return "Enter a valid Instagram handle." }
        if !website.trimmed.isEmpty, ContactLinks.websiteURL(website) == nil { return "Enter a valid https website." }
        if role == .artist, ContactLinks.options(email: email, instagram: instagram, website: website).isEmpty {
            return "Add at least one way for collectors to reach you."
        }
        if mode == .create, !acceptedTerms { return "Accept the terms to continue." }
        return nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AFSpacing.lg) {
                    avatarPicker

                    if mode == .create {
                        HStack(spacing: 0) {
                            RolePill(label: "I'm a Collector", isSelected: role == .collector) { role = .collector }
                            RolePill(label: "I'm an Artist", isSelected: role == .artist) { role = .artist }
                        }
                        .background(Color.afSurface2)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.afBorder, lineWidth: 1))
                    }

                    FormField(label: "DISPLAY NAME", placeholder: "Your name", text: $displayName)
                    FormField(label: "LOCATION", placeholder: "City, Country", text: $location)

                    if role == .artist {
                        TextAreaField(label: "BIO", placeholder: "Tell collectors about your style and process", text: $bio, limit: 280)

                        VStack(alignment: .leading, spacing: AFSpacing.md) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("How collectors reach you").font(AFFont.headlineMedium).foregroundColor(.afTextPrimary)
                                Text("Anything you add here is public.").font(AFFont.bodySmall).foregroundColor(.afTextSecondary)
                            }
                            FormField(label: "CONTACT EMAIL", placeholder: "you@example.com", text: $email, keyboardType: .emailAddress, autocapitalize: false)
                            FormField(label: "INSTAGRAM", placeholder: "@yourhandle", text: $instagram, autocapitalize: false)
                            FormField(label: "WEBSITE", placeholder: "yourwebsite.com", text: $website, keyboardType: .URL, autocapitalize: false)
                            Toggle("Open to commissions", isOn: $acceptsCommissions)
                                .font(AFFont.headlineSmall)
                                .foregroundColor(.afTextPrimary)
                                .tint(.afPrimary)
                        }
                    }

                    if mode == .create {
                        Toggle(isOn: $acceptedTerms) {
                            NavigationLink("I agree to the Terms & Privacy, including zero tolerance for abusive content.") {
                                LegalView()
                            }
                            .font(AFFont.bodySmall)
                            .multilineTextAlignment(.leading)
                        }
                        .tint(.afPrimary)
                    }

                    if let message = errorMessage ?? validationMessage {
                        Text(message)
                            .font(AFFont.bodySmall)
                            .foregroundColor(errorMessage == nil ? .afTextSecondary : .afError)
                    }

                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving { ProgressView().tint(.white) } else { Text(mode == .create ? "Create Profile" : "Save Changes") }
                    }
                    .buttonStyle(AFPrimaryButtonStyle())
                    .opacity(validationMessage == nil ? 1 : 0.45)
                    .disabled(validationMessage != nil || isSaving)
                }
                .padding(AFSpacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.afBackground)
            .navigationTitle(mode == .create ? "Create Profile" : "Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(.afTextSecondary)
                }
            }
        }
        .interactiveDismissDisabled(isSaving)
        .onAppear(perform: populate)
        .onChange(of: avatarItem) { _, item in
            Task { await loadAvatar(item) }
        }
    }

    private var avatarPicker: some View {
        HStack {
            Spacer()
            PhotosPicker(selection: $avatarItem, matching: .images) {
                ZStack(alignment: .bottomTrailing) {
                    if let avatarPreview {
                        Image(uiImage: avatarPreview).resizable().scaledToFill().frame(width: 88, height: 88).clipShape(Circle())
                    } else {
                        AvatarCircle(name: displayName.isEmpty ? "+" : displayName, url: appState.profile?.avatarURL, size: 88)
                    }
                    Circle().fill(Color.afPrimary).frame(width: 28, height: 28)
                        .overlay(Image(systemName: "camera.fill").font(.system(size: 12)).foregroundColor(.white))
                }
            }
            .accessibilityLabel("Choose profile photo")
            Spacer()
        }
    }

    private func populate() {
        guard let profile = appState.profile, mode == .edit else { return }
        role = profile.role
        displayName = profile.displayName
        location = profile.location
        bio = profile.bio
        email = profile.contactEmail
        instagram = profile.instagramHandle
        website = profile.website
        acceptsCommissions = profile.acceptsCommissions
    }

    private func loadAvatar(_ item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self),
              let processed = try? ImageProcessor.process(data) else {
            if item != nil { errorMessage = AppError.invalidImage.errorDescription }
            return
        }
        errorMessage = nil
        avatarData = processed.thumbnail
        avatarPreview = UIImage(data: processed.thumbnail)
    }

    private func save() async {
        guard let userID = appState.currentUserID else {
            appState.showICloudPrompt = true
            return
        }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        var profile = appState.profile ?? UserProfile(id: userID, displayName: "", role: role)
        profile.displayName = displayName.trimmed
        profile.location = location.trimmed
        profile.bio = role == .artist ? bio.trimmed : ""
        profile.contactEmail = role == .artist ? email.trimmed : ""
        profile.instagramHandle = role == .artist ? instagram.trimmed : ""
        profile.website = role == .artist ? website.trimmed : ""
        profile.acceptsCommissions = role == .artist && acceptsCommissions
        do {
            let saved = try await appState.backend.saveProfile(profile, avatar: avatarData)
            appState.updateProfile(saved)
            dismiss()
        } catch {
            errorMessage = AppState.message(for: error)
        }
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
