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
    @State private var phone = ""
    @State private var whatsapp = ""
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
        if !phone.trimmed.isEmpty, ContactLinks.phoneNumber(phone) == nil { return "Enter a valid phone number." }
        if !whatsapp.trimmed.isEmpty, ContactLinks.whatsappURL(whatsapp) == nil {
            return "Enter your WhatsApp number with the country code, like +34 612 345 678."
        }
        if role == .artist, ContactLinks.options(email: email, instagram: instagram, website: website, phone: phone, whatsapp: whatsapp).isEmpty {
            return "Add at least one way for collectors to reach you."
        }
        if mode == .create, !acceptedTerms { return "Accept the terms to continue." }
        return nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    avatarPicker
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                }

                if mode == .create {
                    Section("I am a") {
                        Picker("Role", selection: $role) {
                            Text("Collector").tag(UserRole.collector)
                            Text("Artist").tag(UserRole.artist)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                }

                Section("About") {
                    TextField("Display Name", text: $displayName)
                        .textContentType(.name)
                    TextField("City, Country", text: $location)
                    if role == .artist {
                        TextField("Bio", text: $bio, axis: .vertical)
                            .lineLimit(3...6)
                            .onChange(of: bio) { _, value in
                                if value.count > 280 { bio = String(value.prefix(280)) }
                            }
                    }
                }

                if role == .artist {
                    Section {
                        TextField("Email", text: $email)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        TextField("Phone (optional)", text: $phone)
                            .keyboardType(.phonePad)
                            .textContentType(.telephoneNumber)
                        TextField("WhatsApp, with country code", text: $whatsapp)
                            .keyboardType(.phonePad)
                        TextField("Instagram", text: $instagram)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        TextField("Website", text: $website)
                            .keyboardType(.URL)
                            .textContentType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } header: {
                        Text("Contact")
                    } footer: {
                        Text("Anything you add here is public, including phone numbers. Collectors can call, text or message you on WhatsApp.")
                    }

                    Section {
                        Toggle("Open to Commissions", isOn: $acceptsCommissions)
                    } footer: {
                        Text("Collectors see this on your profile and can reach you using your contact details.")
                    }
                }

                if mode == .create {
                    Section {
                        NavigationLink("Terms & Privacy") { LegalView() }
                        Toggle("I Agree to the Terms", isOn: $acceptedTerms)
                    } footer: {
                        Text("Artist Folio has zero tolerance for abusive content.")
                    }
                }

                if let message = errorMessage ?? validationMessage {
                    Section {
                    } footer: {
                        Text(message).foregroundStyle(errorMessage == nil ? Color.afTextSecondary : Color.red)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(mode == .create ? "Create Profile" : "Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button(mode == .create ? "Create" : "Save") {
                            Task { await save() }
                        }
                        .fontWeight(.semibold)
                        .disabled(validationMessage != nil)
                    }
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
        PhotosPicker(selection: $avatarItem, matching: .images) {
            VStack(spacing: AFSpacing.xs) {
                if let avatarPreview {
                    Image(uiImage: avatarPreview).resizable().scaledToFill().frame(width: 88, height: 88).clipShape(Circle())
                } else {
                    AvatarCircle(name: displayName.isEmpty ? "?" : displayName, url: appState.profile?.avatarURL, size: 88)
                }
                Text("Choose Photo").font(.subheadline)
            }
        }
        .accessibilityLabel("Choose profile photo")
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
        phone = profile.phone
        whatsapp = profile.whatsapp
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
        profile.phone = role == .artist ? phone.trimmed : ""
        profile.whatsapp = role == .artist ? whatsapp.trimmed : ""
        profile.acceptsCommissions = role == .artist && acceptsCommissions
        do {
            let saved = try await appState.backend.saveProfile(profile, avatar: avatarData)
            appState.updateProfile(saved, isFirstTime: mode == .create)
            dismiss()
        } catch {
            errorMessage = AppState.message(for: error)
        }
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
