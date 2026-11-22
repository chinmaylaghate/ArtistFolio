// MARK: - Messages Screen
// Matches Figma: Collector > Messages (34:5302), Artist > Messages (39:22869)
import SwiftUI

// Preview data
private struct PreviewConvo: Identifiable {
    let id = UUID()
    let name: String
    let message: String
    let time: String
    let unread: Int
    let artworkTitle: String?
}

private let previewConvos: [PreviewConvo] = [
    PreviewConvo(name: "Elena Vasquez", message: "Thank you for your interest in Golden Hour", time: "2m ago", unread: 2, artworkTitle: "Golden Hour Reverie"),
    PreviewConvo(name: "Marcus Chen", message: "The painting is now framed and ready for shipment", time: "1h ago", unread: 0, artworkTitle: "Ocean Silence"),
    PreviewConvo(name: "Amara Okonkwo", message: "I have a new collection dropping next week!", time: "3h ago", unread: 1, artworkTitle: nil),
    PreviewConvo(name: "James Park", message: "Would you be open to a commission for $1,400?", time: "Yesterday", unread: 0, artworkTitle: nil),
    PreviewConvo(name: "Sarah Mitchell", message: "Just left a review on your profile ⭐️", time: "2d ago", unread: 0, artworkTitle: nil),
]

struct MessagesView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = MessagesViewModel()

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(Array(previewConvos.enumerated()), id: \.element.id) { index, convo in
                        NavigationLink(destination: ConversationDetailView(
                            contactName: convo.name,
                            artworkTitle: convo.artworkTitle
                        )) {
                            ConversationRow(name: convo.name, verified: true,
                                           message: convo.message, time: convo.time,
                                           unread: convo.unread)
                        }
                        .buttonStyle(PlainButtonStyle())
                        if index < previewConvos.count - 1 {
                            Divider().padding(.leading, 76)
                        }
                    }
                }
                .padding(.top, AFSpacing.xs)
                Spacer(minLength: 100)
            }
        }
        .background(Color.afBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Messages").font(AFFont.headlineMedium).foregroundColor(.afTextPrimary)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {} label: {
                    Image(systemName: "square.and.pencil")
                        .foregroundColor(.afPrimary)
                }
            }
        }
        .task { await vm.load() }
    }
}

// MARK: - Conversation Detail View
// Matches Figma: Collector > Messages > Message Details (34:5438)

struct ConversationDetailView: View {
    let contactName: String
    var artworkTitle: String?
    @State private var messageText = ""
    @FocusState private var isInputFocused: Bool
    @Environment(\.dismiss) var dismiss

    // Sample messages
    @State private var messages: [ChatMessage] = [
        ChatMessage(id: "1", text: "Hi! I'm interested in your 'Golden Hour Reverie' painting. Is it still available?", isFromMe: false, time: "9:45 AM"),
        ChatMessage(id: "2", text: "Yes, it's still available! Would you like more details or additional photos?", isFromMe: true, time: "9:52 AM"),
        ChatMessage(id: "3", text: "That would be great. Also, do you offer international shipping?", isFromMe: false, time: "10:01 AM"),
        ChatMessage(id: "4", text: "Absolutely! I ship worldwide with full insurance and tracking. Typical delivery to Europe takes 7–10 business days.", isFromMe: true, time: "10:05 AM"),
        ChatMessage(id: "5", text: "Wonderful. Could you tell me more about the certificate of authenticity?", isFromMe: false, time: "10:12 AM"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Artwork context banner
            if let title = artworkTitle {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: AFRadius.xs)
                        .fill(Color.afSurface2)
                        .frame(width: 44, height: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Re:").font(AFFont.caption).foregroundColor(.afTextSecondary)
                        Text(title).font(AFFont.headlineSmall).foregroundColor(.afTextPrimary).lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(.afTextTertiary)
                }
                .padding(.horizontal, AFSpacing.md).padding(.vertical, 10)
                .background(Color.afSurface)
                .overlay(Rectangle().fill(Color.afBorder).frame(height: 1), alignment: .bottom)
            }

            // Messages list
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        ForEach(messages) { msg in
                            MessageBubble(message: msg)
                                .id(msg.id)
                        }
                    }
                    .padding(.horizontal, AFSpacing.md)
                    .padding(.vertical, AFSpacing.md)
                }
                .onChange(of: messages.count) {
                    withAnimation { proxy.scrollTo(messages.last?.id) }
                }
            }

            // Input bar
            HStack(spacing: 12) {
                Button {} label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.afPrimary)
                }

                TextField("Message...", text: $messageText, axis: .vertical)
                    .font(AFFont.bodyMedium)
                    .lineLimit(1...4)
                    .focused($isInputFocused)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Color.afSurface2)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.afBorder, lineWidth: 1))

                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(messageText.isEmpty ? .afTextTertiary : .afPrimary)
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, AFSpacing.md)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .overlay(Rectangle().fill(Color.afBorder).frame(height: 0.5), alignment: .top)
        }
        .background(Color.afBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    HStack(spacing: 4) {
                        Text(contactName).font(AFFont.headlineMedium).foregroundColor(.afTextPrimary)
                        Image(systemName: "checkmark.seal.fill").font(.system(size: 12)).foregroundColor(.afPrimary)
                    }
                    Text("Active now").font(.system(size: 11)).foregroundColor(.afSuccess)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("View Profile", action: {})
                    Button("Block User", role: .destructive, action: {})
                } label: {
                    Image(systemName: "ellipsis.circle").foregroundColor(.afTextPrimary)
                }
            }
        }
        .onTapGesture { isInputFocused = false }
    }

    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let msg = ChatMessage(id: UUID().uuidString, text: text, isFromMe: true, time: "Now")
        withAnimation { messages.append(msg) }
        messageText = ""
    }
}

struct ChatMessage: Identifiable {
    let id: String
    let text: String
    let isFromMe: Bool
    let time: String
}

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isFromMe { Spacer(minLength: 60) }

            if !message.isFromMe {
                AvatarCircle(name: "E", size: 32)
            }

            VStack(alignment: message.isFromMe ? .trailing : .leading, spacing: 3) {
                Text(message.text)
                    .font(AFFont.bodyMedium)
                    .foregroundColor(message.isFromMe ? .white : .afTextPrimary)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(message.isFromMe ? Color.afPrimary : Color.afSurface2)
                    .clipShape(RoundedRectangle(cornerRadius: message.isFromMe ? 18 : 18,
                                               style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(message.isFromMe ? Color.clear : Color.afBorder, lineWidth: 1)
                    )

                Text(message.time)
                    .font(.system(size: 11)).foregroundColor(.afTextTertiary)
            }

            if !message.isFromMe { Spacer(minLength: 60) }
        }
    }
}

struct ConversationRow: View {
    let name: String
    var verified: Bool = false
    let message: String
    let time: String
    var unread: Int = 0

    var body: some View {
        HStack(spacing: AFSpacing.sm) {
            ZStack(alignment: .bottomTrailing) {
                AvatarCircle(name: name, size: 52)
                if unread > 0 {
                    Text("\(unread)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 18, height: 18)
                        .background(Color.afPrimary)
                        .clipShape(Circle())
                        .offset(x: 2, y: 2)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(name)
                        .font(AFFont.headlineSmall)
                        .foregroundColor(.afTextPrimary)
                    if verified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.afPrimary)
                    }
                    Spacer()
                    Text(time)
                        .font(AFFont.caption)
                        .foregroundColor(.afTextTertiary)
                }
                Text(message)
                    .font(AFFont.bodySmall)
                    .foregroundColor(.afTextSecondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, AFSpacing.md)
        .padding(.vertical, AFSpacing.sm)
    }
}

@MainActor final class MessagesViewModel: ObservableObject {
    @Published var conversations: [Conversation] = []
    let service = ChatService()
    func load() async { try? await service.fetchConversations() }
}

// MARK: - Profile Screen

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @State private var showEditProfile: Bool = false

    var user: AppUser? { appState.currentUser }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AFSpacing.md) {
                // Profile Card
                ProfileCard(user: user, onEdit: { showEditProfile = true })

                // Quick Actions
                QuickActionsSection()

                // Account Section
                AccountSection()

                // Preferences Section
                PreferencesSection()

                // Sign Out
                Button {
                    appState.signOut()
                } label: {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Sign Out")
                    }
                    .font(AFFont.bodyMedium)
                    .foregroundColor(.afError)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AFSpacing.md)
                }
                .padding(.bottom, 100)
            }
            .padding(.horizontal, AFSpacing.md)
            .padding(.top, AFSpacing.sm)
        }
        .background(Color.afBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Profile").font(AFFont.headlineMedium).foregroundColor(.afTextPrimary)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: NotificationsView()) {
                    Image(systemName: "bell")
                        .foregroundColor(.afTextPrimary)
                }
            }
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileSheet()
        }
    }
}

// MARK: - Profile Card

struct ProfileCard: View {
    let user: AppUser?
    let onEdit: () -> Void
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: AFSpacing.md) {
            HStack(alignment: .top) {
                // Avatar with gradient border
                ZStack {
                    Circle()
                        .stroke(AFGradient.avatarBorder, lineWidth: 3)
                        .frame(width: 72, height: 72)
                    Circle()
                        .fill(Color.afAvatarBg)
                        .frame(width: 64, height: 64)
                    Text(String((user?.displayName ?? "U").prefix(1)))
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: AFSpacing.xxs) {
                    HStack(spacing: AFSpacing.xxs) {
                        Text(user?.displayName ?? "User")
                            .font(AFFont.headlineMedium)
                            .foregroundColor(.afTextPrimary)
                        if user?.isVerified == true {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.afPrimary)
                        }
                    }

                    // Role badge
                    Text(appState.isArtist ? "Artist" : "Collector")
                        .font(AFFont.captionBold)
                        .foregroundColor(.white)
                        .padding(.horizontal, AFSpacing.sm)
                        .padding(.vertical, 3)
                        .background(appState.isArtist ? Color.afArtistBadge : Color.afCollectorBadge)
                        .clipShape(Capsule())

                    if let location = user?.location {
                        HStack(spacing: 3) {
                            Image(systemName: "mappin")
                                .font(.system(size: 10))
                            Text(location)
                                .font(AFFont.caption)
                        }
                        .foregroundColor(.afTextSecondary)
                    }
                }

                Spacer()

                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 14))
                        .foregroundColor(.afTextSecondary)
                        .frame(width: 32, height: 32)
                        .background(Color.afBackground)
                        .clipShape(Circle())
                }
            }

            // Bio
            if let bio = user?.bio, !bio.isEmpty {
                Text(bio)
                    .font(AFFont.bodySmall)
                    .foregroundColor(.afTextSecondary)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Medium tags
            if appState.isArtist {
                HStack(spacing: AFSpacing.xs) {
                    MediumTag(text: "Oil")
                    MediumTag(text: "Mixed Media")
                    Spacer()
                }
            }

            // Stats row
            HStack {
                if appState.isArtist {
                    StatValue(value: "\(user?.totalSales ?? 0)", label: "Sales")
                    Spacer()
                    StatValue(value: formatCount(user?.followersCount ?? 0), label: "Followers")
                    Spacer()
                    HStack(spacing: 2) {
                        StatValue(value: "4.9", label: "Rating")
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.afWarning)
                    }
                } else {
                    StatValue(value: "5", label: "Orders")
                    Spacer()
                    StatValue(value: "0", label: "Saved")
                    Spacer()
                    StatValue(value: "0", label: "Following")
                }

                Spacer()

                Button {
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 12))
                        Text("Share")
                            .font(AFFont.captionBold)
                    }
                    .foregroundColor(.afTextSecondary)
                    .padding(.horizontal, AFSpacing.sm)
                    .padding(.vertical, AFSpacing.xs)
                    .overlay(
                        RoundedRectangle(cornerRadius: AFRadius.sm)
                            .stroke(Color.afBorder, lineWidth: 1)
                    )
                }
            }
        }
        .padding(AFSpacing.md)
        .background(Color.afSurface)
        .clipShape(RoundedRectangle(cornerRadius: AFRadius.lg))
        .afCardShadow()
    }
}

// MARK: - Quick Actions Section

struct QuickActionsSection: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: AFSpacing.sm) {
            Text("QUICK ACTIONS")
                .font(AFFont.sectionHeader)
                .foregroundColor(.afTextSecondary)
                .tracking(0.5)

            if appState.isArtist {
                HStack(spacing: AFSpacing.md) {
                    NavigationLink(destination: AnalyticsView()) {
                        QuickActionButton(icon: "chart.line.uptrend.xyaxis", label: "Analytics", color: Color(hex: "#3B82F6"))
                    }
                    NavigationLink(destination: MyWorkView()) {
                        QuickActionButton(icon: "paintpalette.fill", label: "My Works", color: Color(hex: "#8B5CF6"))
                    }
                    NavigationLink(destination: ReviewsView()) {
                        QuickActionButton(icon: "star.fill", label: "Reviews", color: Color(hex: "#F59E0B"))
                    }
                    NavigationLink(destination: SalesOrdersView()) {
                        QuickActionButton(icon: "shippingbox.fill", label: "Orders", color: Color(hex: "#10B981"), badge: 5)
                    }
                    QuickActionButton(icon: "bubble.left.fill", label: "Messages", color: Color(hex: "#3B82F6"))
                }
            } else {
                HStack(spacing: AFSpacing.md) {
                    NavigationLink(destination: MyOrdersView()) {
                        QuickActionButton(icon: "shippingbox.fill", label: "Orders", color: Color(hex: "#10B981"), badge: 5)
                    }
                    QuickActionButton(icon: "heart.fill", label: "Saved", color: Color(hex: "#EF4444"))
                    NavigationLink(destination: CartView()) {
                        QuickActionButton(icon: "bag.fill", label: "Cart", color: Color(hex: "#F59E0B"))
                    }
                    QuickActionButton(icon: "bubble.left.fill", label: "Messages", color: Color(hex: "#3B82F6"))
                }
            }
        }
    }
}

struct QuickActionButton: View {
    let icon: String
    let label: String
    let color: Color
    var badge: Int = 0

    var body: some View {
        VStack(spacing: AFSpacing.xs) {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 20))
                            .foregroundColor(color)
                    )
                if badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 18, height: 18)
                        .background(Color.afError)
                        .clipShape(Circle())
                        .offset(x: 4, y: -4)
                }
            }
            Text(label)
                .font(AFFont.caption)
                .foregroundColor(.afTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Account Section

struct AccountSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AFSpacing.xs) {
            Text("ACCOUNT")
                .font(AFFont.sectionHeader)
                .foregroundColor(.afTextSecondary)
                .tracking(0.5)

            VStack(spacing: 0) {
                NavigationLink(destination: PaymentMethodsView()) {
                    AccountRow(icon: "creditcard", iconColor: Color(hex: "#3B82F6"), title: "Payment Methods", subtitle: "Cards & billing")
                }
                Divider().padding(.leading, 56)
                NavigationLink(destination: NotificationSettingsView()) {
                    AccountRow(icon: "bell", iconColor: Color(hex: "#F59E0B"), title: "Notifications", subtitle: "Manage what you hear about")
                }
                Divider().padding(.leading, 56)
                NavigationLink(destination: PrivacySecurityView()) {
                    AccountRow(icon: "lock.shield", iconColor: Color(hex: "#8B5CF6"), title: "Privacy & Security", subtitle: "Visibility, 2FA, data")
                }
            }
            .background(Color.afSurface)
            .clipShape(RoundedRectangle(cornerRadius: AFRadius.lg))
            .afCardShadow()
        }
    }
}

struct AccountRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: AFSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(iconColor)
                .frame(width: 36, height: 36)
                .background(iconColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: AFRadius.sm))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(AFFont.bodyMedium)
                    .foregroundColor(.afTextPrimary)
                Text(subtitle)
                    .font(AFFont.caption)
                    .foregroundColor(.afTextSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.afTextTertiary)
        }
        .padding(.horizontal, AFSpacing.md)
        .padding(.vertical, AFSpacing.sm)
    }
}

// MARK: - Preferences Section

struct PreferencesSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AFSpacing.xs) {
            Text("PREFERENCES")
                .font(AFFont.sectionHeader)
                .foregroundColor(.afTextSecondary)
                .tracking(0.5)

            VStack(spacing: 0) {
                NavigationLink(destination: AppSettingsView()) {
                    AccountRow(icon: "gearshape", iconColor: Color(hex: "#6B7280"), title: "App Settings", subtitle: "Language, currency, display")
                }
                Divider().padding(.leading, 56)
                NavigationLink(destination: HelpCenterView()) {
                    AccountRow(icon: "questionmark.circle", iconColor: Color(hex: "#10B981"), title: "Help Center", subtitle: "FAQs & support")
                }
            }
            .background(Color.afSurface)
            .clipShape(RoundedRectangle(cornerRadius: AFRadius.lg))
            .afCardShadow()
        }
    }
}

// MARK: - Edit Profile Sheet

struct EditProfileSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var displayName: String = ""
    @State private var bio: String = ""
    @State private var location: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Handle
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.afBorder)
                    .frame(width: 36, height: 4)
                    .padding(.top, AFSpacing.sm)

                Text("Edit Profile")
                    .font(AFFont.headlineMedium)
                    .padding(.top, AFSpacing.md)

                Divider().padding(.top, AFSpacing.md)

                ScrollView {
                    VStack(spacing: AFSpacing.lg) {
                        // Avatar
                        ZStack(alignment: .bottomTrailing) {
                            Circle()
                                .fill(LinearGradient(colors: [Color(hex: "#7C3AED"), Color(hex: "#4355DB")], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Text(String((appState.currentUser?.displayName ?? "U").prefix(1)))
                                        .font(.system(size: 32, weight: .bold))
                                        .foregroundColor(.white)
                                )
                            Circle()
                                .fill(Color.afPrimary)
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white)
                                )
                        }
                        .padding(.top, AFSpacing.md)

                        // Fields
                        FormField(label: "DISPLAY NAME", placeholder: "Your name", text: $displayName)

                        if appState.isArtist {
                            VStack(alignment: .leading, spacing: AFSpacing.xs) {
                                Text("BIO")
                                    .font(AFFont.sectionHeader)
                                    .foregroundColor(.afTextSecondary)
                                    .tracking(0.5)
                                TextEditor(text: $bio)
                                    .font(AFFont.bodyLarge)
                                    .frame(minHeight: 80)
                                    .padding(AFSpacing.sm)
                                    .background(Color.afBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: AFRadius.md))
                                    .overlay(RoundedRectangle(cornerRadius: AFRadius.md).stroke(Color.afBorder, lineWidth: 1))
                                    .scrollContentBackground(.hidden)
                                HStack {
                                    Spacer()
                                    Text("\(bio.count)/280")
                                        .font(AFFont.caption)
                                        .foregroundColor(.afTextTertiary)
                                }
                            }
                        }

                        FormField(label: "LOCATION", placeholder: "City, Country", text: $location)

                        // Role (locked)
                        VStack(alignment: .leading, spacing: AFSpacing.xs) {
                            Text("ROLE")
                                .font(AFFont.sectionHeader)
                                .foregroundColor(.afTextSecondary)
                                .tracking(0.5)
                            HStack(spacing: AFSpacing.xs) {
                                Text(appState.isArtist ? "Artist" : "Collector")
                                    .font(AFFont.headlineSmall)
                                    .foregroundColor(.afPrimary)
                                    .padding(.horizontal, AFSpacing.sm)
                                    .padding(.vertical, AFSpacing.xs)
                                    .background(Color.afPrimaryLight)
                                    .clipShape(Capsule())
                                Text("· Cannot be changed")
                                    .font(AFFont.caption)
                                    .foregroundColor(.afTextTertiary)
                            }
                        }
                    }
                    .padding(.horizontal, AFSpacing.lg)
                }

                // Bottom buttons
                HStack(spacing: AFSpacing.md) {
                    Button {
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "xmark")
                            Text("Cancel")
                        }
                    }
                    .buttonStyle(AFSecondaryButtonStyle())

                    Button {
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "checkmark")
                            Text("Save")
                        }
                    }
                    .buttonStyle(AFPrimaryButtonStyle())
                }
                .padding(.horizontal, AFSpacing.lg)
                .padding(.vertical, AFSpacing.md)
            }
            .background(Color.white)
            .onAppear {
                displayName = appState.currentUser?.displayName ?? ""
                bio = appState.currentUser?.bio ?? ""
                location = appState.currentUser?.location ?? ""
            }
        }
    }
}

// MARK: - My Work View (Artist)

struct MyWorkView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: AFSpacing.md) {
                ForEach(Artwork.previews) { artwork in
                    ArtworkListingCard(artwork: artwork)
                }
            }
            .padding(.horizontal, AFSpacing.md)
            .padding(.top, AFSpacing.sm)
        }
        .background(Color.afBackground)
        .navigationTitle("My Work")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ArtworkListingCard: View {
    let artwork: Artwork

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: AFSpacing.sm) {
                // Thumbnail
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: AFRadius.sm)
                        .fill(Color.afSurface2)
                        .frame(width: 80, height: 80)
                    Text("Active")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.afActiveBadge)
                        .clipShape(Capsule())
                        .padding(4)
                }

                VStack(alignment: .leading, spacing: AFSpacing.xxs) {
                    HStack {
                        Text(artwork.title)
                            .font(AFFont.headlineSmall)
                            .foregroundColor(.afTextPrimary)
                        Spacer()
                        Text("$\(Int(artwork.price))")
                            .font(AFFont.price)
                            .foregroundColor(.afPrimary)
                    }

                    HStack(spacing: AFSpacing.xs) {
                        Text(artwork.medium.rawValue)
                            .font(AFFont.caption)
                            .foregroundColor(.afPrimary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.afPrimaryLight)
                            .clipShape(Capsule())
                        Text(artwork.style.rawValue)
                            .font(AFFont.caption)
                            .foregroundColor(.afTextSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.afBackground)
                            .clipShape(Capsule())
                    }

                    HStack(spacing: AFSpacing.sm) {
                        Label("\(artwork.viewsCount)", systemImage: "eye")
                        Label("\(artwork.likesCount)", systemImage: "heart")
                        Label("\(artwork.year)", systemImage: "calendar")
                    }
                    .font(AFFont.caption)
                    .foregroundColor(.afTextTertiary)
                }
            }

            Divider().padding(.vertical, AFSpacing.xs)

            HStack {
                Button {
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                        Text("Edit Listing")
                    }
                    .font(AFFont.headlineSmall)
                    .foregroundColor(.afPrimary)
                }
                .frame(maxWidth: .infinity)

                Button {
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                        Text("Delete")
                    }
                    .font(AFFont.headlineSmall)
                    .foregroundColor(.afError)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(AFSpacing.md)
        .background(Color.afSurface)
        .clipShape(RoundedRectangle(cornerRadius: AFRadius.lg))
        .afCardShadow()
    }
}

// MARK: - Reviews View

struct ReviewsView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: AFSpacing.md) {
                // Rating Summary
                HStack(spacing: AFSpacing.lg) {
                    VStack(spacing: AFSpacing.xxs) {
                        Text("4.7")
                            .font(.system(size: 44, weight: .bold))
                            .foregroundColor(.afTextPrimary)
                        HStack(spacing: 2) {
                            ForEach(0..<5) { _ in
                                Image(systemName: "star.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.afWarning)
                            }
                        }
                        Text("3 reviews")
                            .font(AFFont.caption)
                            .foregroundColor(.afTextSecondary)
                    }

                    VStack(spacing: 4) {
                        ForEach((1...5).reversed(), id: \.self) { rating in
                            HStack(spacing: AFSpacing.xs) {
                                Text("\(rating)")
                                    .font(AFFont.caption)
                                    .foregroundColor(.afTextSecondary)
                                    .frame(width: 12)
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color.afBorder)
                                            .frame(height: 6)
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color.afWarning)
                                            .frame(width: geo.size.width * barWidth(for: rating), height: 6)
                                    }
                                }
                                .frame(height: 6)
                                Text("\(reviewCount(for: rating))")
                                    .font(AFFont.caption)
                                    .foregroundColor(.afTextSecondary)
                                    .frame(width: 16)
                            }
                        }
                    }
                }
                .padding(AFSpacing.lg)
                .background(Color.afSurface)
                .clipShape(RoundedRectangle(cornerRadius: AFRadius.lg))
                .afCardShadow()

                // Review Cards
                ReviewCard(name: "Sarah Mitchell", date: "Feb 2026", rating: 5,
                    text: "Absolutely stunning work. The painting exceeded my expectations in every way — the colours are even more vibrant in person, and the quality of the canvas and framing is impeccable.",
                    reply: "Thank you so much — this means everything to me. It was a joy to work on this piece.")
                ReviewCard(name: "James Park", date: "Jan 2026", rating: 5,
                    text: "I purchased 'Golden Hour Reverie' as a gift for my wife and she was moved to tears. Elena's work captures an emotional depth that photographs simply cannot convey. Will buy again.")
            }
            .padding(.horizontal, AFSpacing.md)
            .padding(.top, AFSpacing.sm)
        }
        .background(Color.afBackground)
        .navigationTitle("Reviews")
        .navigationBarTitleDisplayMode(.inline)
    }

    func barWidth(for rating: Int) -> CGFloat {
        switch rating {
        case 5: return 0.65
        case 4: return 0.35
        default: return 0
        }
    }
    func reviewCount(for rating: Int) -> Int {
        switch rating {
        case 5: return 2
        case 4: return 1
        default: return 0
        }
    }
}

struct ReviewCard: View {
    let name: String
    let date: String
    let rating: Int
    let text: String
    var reply: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: AFSpacing.sm) {
            HStack(spacing: AFSpacing.sm) {
                AvatarCircle(name: name, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).font(AFFont.headlineSmall).foregroundColor(.afTextPrimary)
                    HStack(spacing: 4) {
                        HStack(spacing: 1) {
                            ForEach(0..<rating, id: \.self) { _ in
                                Image(systemName: "star.fill").font(.system(size: 10)).foregroundColor(.afWarning)
                            }
                        }
                        Text(date).font(AFFont.caption).foregroundColor(.afTextTertiary)
                    }
                }
            }

            Text(text)
                .font(AFFont.bodySmall)
                .foregroundColor(.afTextSecondary)
                .lineSpacing(4)

            if let reply = reply {
                VStack(alignment: .leading, spacing: AFSpacing.xxs) {
                    Text("Elena Vasquez replied:")
                        .font(AFFont.captionBold)
                        .foregroundColor(.afPrimary)
                    Text(reply)
                        .font(AFFont.bodySmall)
                        .foregroundColor(.afTextSecondary)
                }
                .padding(AFSpacing.sm)
                .background(Color.afBackground)
                .clipShape(RoundedRectangle(cornerRadius: AFRadius.sm))
                .overlay(
                    Rectangle()
                        .fill(Color.afPrimary)
                        .frame(width: 3),
                    alignment: .leading
                )
                .clipShape(RoundedRectangle(cornerRadius: AFRadius.sm))
            }
        }
        .padding(AFSpacing.md)
        .background(Color.afSurface)
        .clipShape(RoundedRectangle(cornerRadius: AFRadius.lg))
        .afCardShadow()
    }
}

// MARK: - Analytics View

struct AnalyticsView: View {
    let days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    let heights: [CGFloat] = [0.3, 0.35, 0.5, 0.45, 0.55, 0.7, 1.0]

    var body: some View {
        ScrollView {
            VStack(spacing: AFSpacing.md) {
                // Views Chart
                VStack(alignment: .leading, spacing: AFSpacing.md) {
                    Text("Views (Last 30 days)")
                        .font(AFFont.headlineMedium)
                        .foregroundColor(.afTextPrimary)

                    HStack(alignment: .bottom, spacing: AFSpacing.sm) {
                        ForEach(0..<7, id: \.self) { i in
                            VStack(spacing: AFSpacing.xxs) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(i == 6 ? Color.afPrimary : Color.afPrimaryLight)
                                    .frame(height: 120 * heights[i])
                                Text(days[i])
                                    .font(AFFont.caption)
                                    .foregroundColor(.afTextSecondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(AFSpacing.md)
                .background(Color.afSurface)
                .clipShape(RoundedRectangle(cornerRadius: AFRadius.lg))
                .afCardShadow()

                // Top Artworks
                VStack(alignment: .leading, spacing: AFSpacing.md) {
                    Text("Top Artworks")
                        .font(AFFont.headlineMedium)
                        .foregroundColor(.afTextPrimary)

                    ForEach(Array(Artwork.previews.enumerated()), id: \.element.id) { index, artwork in
                        HStack(spacing: AFSpacing.sm) {
                            Text("\(index + 1)")
                                .font(AFFont.headlineLarge)
                                .foregroundColor(.afTextTertiary)
                                .frame(width: 20)

                            RoundedRectangle(cornerRadius: AFRadius.sm)
                                .fill(Color.afSurface2)
                                .frame(width: 44, height: 44)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(artwork.title)
                                    .font(AFFont.headlineSmall)
                                    .foregroundColor(.afTextPrimary)
                                Text("\(artwork.viewsCount) views · \(artwork.likesCount) likes")
                                    .font(AFFont.caption)
                                    .foregroundColor(.afTextSecondary)
                            }

                            Spacer()

                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.afPrimary)
                                .frame(width: CGFloat(60 - index * 10), height: 8)
                        }
                    }
                }
                .padding(AFSpacing.md)
                .background(Color.afSurface)
                .clipShape(RoundedRectangle(cornerRadius: AFRadius.lg))
                .afCardShadow()

                // Total Earnings
                VStack(alignment: .leading, spacing: AFSpacing.xs) {
                    Text("Total Earnings")
                        .font(AFFont.bodyMedium)
                        .foregroundColor(.afTextSecondary)
                    Text("$0")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.afTextPrimary)
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 11))
                        Text("From 0 sales on Artist Folio")
                            .font(AFFont.caption)
                    }
                    .foregroundColor(.afPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AFSpacing.md)
                .background(Color.afSurface)
                .clipShape(RoundedRectangle(cornerRadius: AFRadius.lg))
                .afCardShadow()
            }
            .padding(.horizontal, AFSpacing.md)
            .padding(.top, AFSpacing.sm)
        }
        .background(Color.afBackground)
        .navigationTitle("Analytics")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Sales & Orders View (Artist)

struct SalesOrdersView: View {
    @State private var selectedFilter: String = "All"
    let filters = ["All", "Processing", "Shipped", "Delivered"]

    var body: some View {
        ScrollView {
            VStack(spacing: AFSpacing.md) {
                // Revenue Summary
                HStack(spacing: AFSpacing.sm) {
                    StatCard(value: "$10,800", label: "Total Revenue", color: .afPrimary)
                    StatCard(value: "5", label: "Total Sales", color: .afTextPrimary)
                    StatCard(value: "4", label: "Active", color: .afOrange)
                }

                // Filter pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AFSpacing.xs) {
                        ForEach(filters, id: \.self) { filter in
                            Button {
                                selectedFilter = filter
                            } label: {
                                HStack(spacing: 4) {
                                    Text(filter)
                                    if filter != "Delivered" {
                                        Text(filter == "All" ? "5" : filter == "Processing" ? "3" : "1")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(selectedFilter == filter ? .afPrimary : .afTextSecondary)
                                            .padding(4)
                                            .background(selectedFilter == filter ? Color.white : Color.afBackground)
                                            .clipShape(Circle())
                                    }
                                }
                                .font(AFFont.headlineSmall)
                                .foregroundColor(selectedFilter == filter ? .white : .afTextSecondary)
                                .padding(.horizontal, AFSpacing.md)
                                .padding(.vertical, AFSpacing.xs)
                                .background(selectedFilter == filter ? Color.afPrimary : Color.afSurface)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(selectedFilter == filter ? Color.clear : Color.afBorder, lineWidth: 1))
                            }
                        }
                    }
                }

                // Order cards
                OrderCard(title: "Layered Memories", artist: "Amara Okonkwo", orderNum: "#FRM-17745603175370", date: "Mar 26, 2026", price: "$3,200", status: "Processing", isArtist: true)
                OrderCard(title: "Layered Memories", artist: "Amara Okonkwo", orderNum: "#FRM-17745602652920", date: "Mar 26, 2026", price: "$3,200", status: "Processing", isArtist: true)
            }
            .padding(.horizontal, AFSpacing.md)
            .padding(.top, AFSpacing.sm)
        }
        .background(Color.afBackground)
        .navigationTitle("Sales & Orders")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - My Orders View (Collector)

struct MyOrdersView: View {
    @State private var selectedFilter: String = "All"
    let filters = ["All", "Processing", "Shipped", "Delivered"]

    var body: some View {
        ScrollView {
            VStack(spacing: AFSpacing.md) {
                // Summary
                HStack(spacing: AFSpacing.sm) {
                    Image(systemName: "shippingbox")
                        .foregroundColor(.afPrimary)
                        .frame(width: 36, height: 36)
                        .background(Color.afPrimaryLight)
                        .clipShape(RoundedRectangle(cornerRadius: AFRadius.sm))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("5 orders")
                            .font(AFFont.headlineSmall)
                            .foregroundColor(.afTextPrimary)
                        Text("4 in progress · 1 complete")
                            .font(AFFont.caption)
                            .foregroundColor(.afTextSecondary)
                    }

                    Spacer()

                    Text("4 active")
                        .font(AFFont.captionBold)
                        .foregroundColor(.afOrange)
                        .padding(.horizontal, AFSpacing.sm)
                        .padding(.vertical, AFSpacing.xxs)
                        .background(Color.afOrange.opacity(0.1))
                        .clipShape(Capsule())
                }
                .padding(AFSpacing.md)
                .background(Color.afSurface)
                .clipShape(RoundedRectangle(cornerRadius: AFRadius.lg))
                .afCardShadow()

                // Filters
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AFSpacing.xs) {
                        ForEach(filters, id: \.self) { filter in
                            Button { selectedFilter = filter } label: {
                                HStack(spacing: 4) {
                                    Text(filter)
                                    if filter != "Delivered" {
                                        Text(filter == "All" ? "5" : filter == "Processing" ? "3" : "1")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(selectedFilter == filter ? .afPrimary : .afTextSecondary)
                                            .padding(4)
                                            .background(selectedFilter == filter ? Color.white : Color.afBackground)
                                            .clipShape(Circle())
                                    }
                                }
                                .font(AFFont.headlineSmall)
                                .foregroundColor(selectedFilter == filter ? .white : .afTextSecondary)
                                .padding(.horizontal, AFSpacing.md)
                                .padding(.vertical, AFSpacing.xs)
                                .background(selectedFilter == filter ? Color.afPrimary : Color.afSurface)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(selectedFilter == filter ? Color.clear : Color.afBorder, lineWidth: 1))
                            }
                        }
                    }
                }

                // Order cards
                OrderCard(title: "Layered Memories", artist: "Amara Okonkwo", orderNum: "#FRM-17745603175370", date: "Mar 26, 2026", price: "$3,200", status: "Processing", isArtist: false)
            }
            .padding(.horizontal, AFSpacing.md)
            .padding(.top, AFSpacing.sm)
        }
        .background(Color.afBackground)
        .navigationTitle("My Orders")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct OrderCard: View {
    let title: String
    let artist: String
    let orderNum: String
    let date: String
    let price: String
    let status: String
    var isArtist: Bool = false

    var body: some View {
        VStack(spacing: AFSpacing.sm) {
            // Image
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: AFRadius.md)
                    .fill(Color.afSurface2)
                    .frame(height: 160)

                Text(status)
                    .font(AFFont.captionBold)
                    .foregroundColor(.white)
                    .padding(.horizontal, AFSpacing.sm)
                    .padding(.vertical, AFSpacing.xxs)
                    .background(
                        Capsule().fill(status == "Processing" ? Color.afOrange : status == "Shipped" ? Color.afPrimary : Color.afSuccess)
                    )
                    .padding(AFSpacing.sm)
            }

            // Info
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(AFFont.headlineSmall).foregroundColor(.afTextPrimary)
                    Text("by \(artist)    \(orderNum)")
                        .font(AFFont.caption)
                        .foregroundColor(.afTextSecondary)
                    Text(date).font(AFFont.caption).foregroundColor(.afTextTertiary)
                }
                Spacer()
                Text(price).font(AFFont.price).foregroundColor(.afTextPrimary)
            }

            // Status tracker
            HStack {
                ForEach(["Ordered", "Confirmed", "Shipped", "Delivered"], id: \.self) { step in
                    VStack(spacing: 4) {
                        Circle()
                            .fill(step == "Ordered" ? Color.afPrimary : Color.afBorder)
                            .frame(width: 12, height: 12)
                        Text(step)
                            .font(.system(size: 10))
                            .foregroundColor(step == "Ordered" ? .afPrimary : .afTextTertiary)
                    }
                    if step != "Delivered" {
                        Rectangle()
                            .fill(Color.afBorder)
                            .frame(height: 1)
                    }
                }
            }

            // Action buttons
            HStack(spacing: AFSpacing.sm) {
                Button { } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right.square")
                        Text("View Artwork")
                    }
                }
                .buttonStyle(AFOutlineButtonStyle())

                Button { } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.left")
                        Text(isArtist ? "Message Buyer" : "Message Artist")
                    }
                }
                .buttonStyle(AFPrimaryButtonStyle())
            }
        }
        .padding(AFSpacing.md)
        .background(Color.afSurface)
        .clipShape(RoundedRectangle(cornerRadius: AFRadius.lg))
        .afCardShadow()
    }
}

// MARK: - Notifications View

struct NotificationsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AFSpacing.md) {
                Text("NEW")
                    .font(AFFont.sectionHeader)
                    .foregroundColor(.afTextSecondary)
                    .tracking(0.5)

                NotificationRow2(icon: "dollarsign.circle.fill", iconBg: .afSuccess, title: "New Sale! \u{1F389}", message: "Your painting 'Golden Hour Reverie' sold for $1,200", time: "2m ago", isNew: true)
                NotificationRow2(icon: "person.badge.plus", iconBg: .afPrimary, title: "New Follower", message: "Marcus Chen started following you", time: "1h ago", isNew: true)
                NotificationRow2(icon: "heart.fill", iconBg: .afError, title: "142 likes", message: "'Tidal Resonance' is trending — 142 people liked it today", time: "3h ago", isNew: true)

                Divider()

                Text("EARLIER")
                    .font(AFFont.sectionHeader)
                    .foregroundColor(.afTextSecondary)
                    .tracking(0.5)

                NotificationRow2(icon: "shippingbox.fill", iconBg: .afOrange, title: "Order Shipped", message: "'Pacific Morning' has been shipped. Tracking: UPS123456789US", time: "Yesterday")
                NotificationRow2(icon: "bubble.left.fill", iconBg: .afPrimary, title: "New Message", message: "Amara Okonkwo: I have a new collection dropping next week...", time: "Yesterday")
                NotificationRow2(icon: "paintbrush.fill", iconBg: Color(hex: "#8B5CF6"), title: "New Artwork", message: "Elena Vasquez posted a new painting: 'Whispered Portrait'", time: "2 days ago")
            }
            .padding(.horizontal, AFSpacing.md)
            .padding(.top, AFSpacing.sm)
        }
        .background(Color.afBackground)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { } label: {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(.afPrimary)
                }
            }
        }
    }
}

struct NotificationRow2: View {
    let icon: String
    let iconBg: Color
    let title: String
    let message: String
    let time: String
    var isNew: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: AFSpacing.sm) {
            ZStack(alignment: .bottomTrailing) {
                AvatarCircle(name: title, size: 44)
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(.white)
                    .frame(width: 20, height: 20)
                    .background(iconBg)
                    .clipShape(Circle())
                    .offset(x: 2, y: 2)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(title)
                        .font(AFFont.headlineSmall)
                        .foregroundColor(.afTextPrimary)
                    Spacer()
                    Text(time)
                        .font(AFFont.caption)
                        .foregroundColor(.afTextTertiary)
                    if isNew {
                        Circle()
                            .fill(Color.afPrimary)
                            .frame(width: 8, height: 8)
                    }
                }
                Text(message)
                    .font(AFFont.bodySmall)
                    .foregroundColor(.afTextSecondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, AFSpacing.xs)
    }
}

// MARK: - Payment Methods View

struct PaymentMethodsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AFSpacing.md) {
            Text("SAVED CARDS")
                .font(AFFont.sectionHeader)
                .foregroundColor(.afTextSecondary)
                .tracking(0.5)

            VStack(spacing: 0) {
                PaymentCardRow(brand: "VISA", last4: "4242", expiry: "09/27", isDefault: true)
                Divider().padding(.leading, AFSpacing.md)
                PaymentCardRow(brand: "MC", last4: "1234", expiry: "03/26", isDefault: false)
            }
            .background(Color.afSurface)
            .clipShape(RoundedRectangle(cornerRadius: AFRadius.lg))
            .afCardShadow()

            Button { } label: {
                HStack {
                    Image(systemName: "plus")
                    Text("Add Payment Method")
                }
            }
            .buttonStyle(AFPrimaryButtonStyle())

            HStack {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12))
                Text("Your payment details are encrypted and never stored on our servers.")
                    .font(AFFont.caption)
            }
            .foregroundColor(.afTextTertiary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)

            Spacer()
        }
        .padding(.horizontal, AFSpacing.md)
        .padding(.top, AFSpacing.md)
        .background(Color.afBackground)
        .navigationTitle("Payment Methods")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PaymentCardRow: View {
    let brand: String
    let last4: String
    let expiry: String
    let isDefault: Bool

    var body: some View {
        HStack(spacing: AFSpacing.sm) {
            Text(brand)
                .font(AFFont.captionBold)
                .foregroundColor(.white)
                .frame(width: 40, height: 26)
                .background(brand == "VISA" ? Color.afPrimary : Color.afError)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 2) {
                Text("•••• •••• •••• \(last4)")
                    .font(AFFont.bodyMedium)
                    .foregroundColor(.afTextPrimary)
                Text("Expires \(expiry)")
                    .font(AFFont.caption)
                    .foregroundColor(.afTextSecondary)
            }

            Spacer()

            if isDefault {
                Text("Default")
                    .font(AFFont.captionBold)
                    .foregroundColor(.afPrimary)
                    .padding(.horizontal, AFSpacing.xs)
                    .padding(.vertical, 3)
                    .overlay(RoundedRectangle(cornerRadius: AFRadius.sm).stroke(Color.afPrimary, lineWidth: 1))
            } else {
                Button { } label: {
                    Text("Set default")
                        .font(AFFont.caption)
                        .foregroundColor(.afTextTertiary)
                }
            }

            Button { } label: {
                Image(systemName: "trash")
                    .foregroundColor(.afError)
            }
        }
        .padding(.horizontal, AFSpacing.md)
        .padding(.vertical, AFSpacing.sm)
    }
}

// MARK: - Notification Settings View

struct NotificationSettingsView: View {
    @State private var allowNotifications = true
    @State private var orderUpdates = true
    @State private var likes = true
    @State private var followers = true
    @State private var messages = true
    @State private var newArtworks = true
    @State private var weeklyDigest = false
    @State private var appUpdates = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AFSpacing.lg) {
                SettingsSection(title: "PUSH NOTIFICATIONS") {
                    ToggleRow(icon: "bell", iconColor: .afPrimary, title: "Allow Notifications", subtitle: "Push notifications are on", isOn: $allowNotifications)
                }
                SettingsSection(title: "ACTIVITY") {
                    ToggleRow(icon: "shippingbox", iconColor: .afOrange, title: "Order Updates", subtitle: "Shipping, delivery & status changes", isOn: $orderUpdates)
                    ToggleRow(icon: "heart", iconColor: .afError, title: "Likes", subtitle: "When someone likes your work", isOn: $likes)
                    ToggleRow(icon: "person.2", iconColor: .afPrimary, title: "New Followers", subtitle: "When someone follows you", isOn: $followers)
                    ToggleRow(icon: "bubble.left", iconColor: .afInfo, title: "Messages", subtitle: "Direct messages from others", isOn: $messages)
                }
                SettingsSection(title: "CONTENT") {
                    ToggleRow(icon: "sparkles", iconColor: Color(hex: "#8B5CF6"), title: "New Artworks", subtitle: "From artists you follow", isOn: $newArtworks)
                    ToggleRow(icon: "envelope", iconColor: .afTextSecondary, title: "Weekly Digest", subtitle: "A curated weekly email from Artist Folio", isOn: $weeklyDigest)
                    ToggleRow(icon: "bell.badge", iconColor: .afPrimary, title: "App Updates", subtitle: "New features & announcements", isOn: $appUpdates)
                }
            }
            .padding(.horizontal, AFSpacing.md)
            .padding(.top, AFSpacing.sm)
        }
        .background(Color.afBackground)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Privacy & Security View

struct PrivacySecurityView: View {
    @State private var publicProfile = true
    @State private var appearInSearch = true
    @State private var showLocation = true
    @State private var activityStatus = true
    @State private var twoFactor = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AFSpacing.lg) {
                SettingsSection(title: "VISIBILITY") {
                    ToggleRow(icon: "eye", iconColor: .afPrimary, title: "Public Profile", subtitle: "Anyone can view your profile", isOn: $publicProfile)
                    ToggleRow(icon: "magnifyingglass", iconColor: .afInfo, title: "Appear in Search", subtitle: "Let others find you by name", isOn: $appearInSearch)
                    ToggleRow(icon: "mappin.circle", iconColor: .afOrange, title: "Show Location", subtitle: "Display your city on your profile", isOn: $showLocation)
                    ToggleRow(icon: "circle.fill", iconColor: .afSuccess, title: "Activity Status", subtitle: "Show when you were last active", isOn: $activityStatus)
                }
                SettingsSection(title: "SECURITY") {
                    ToggleRow(icon: "lock.shield", iconColor: Color(hex: "#8B5CF6"), title: "Two-Factor Authentication", subtitle: "Add an extra layer of security", isOn: $twoFactor)
                    NavigationRow(icon: "key", iconColor: .afPrimary, title: "Change Password", subtitle: "Update your account password")
                    NavigationRow(icon: "rectangle.stack.person.crop", iconColor: .afInfo, title: "Active Sessions", subtitle: "1 device — this iPhone")
                }
                SettingsSection(title: "YOUR DATA") {
                    NavigationRow(icon: "arrow.down.circle", iconColor: .afPrimary, title: "Download My Data", subtitle: "Export your account data as a ZIP")
                    NavigationRow(icon: "doc.text", iconColor: .afInfo, title: "Privacy Policy", subtitle: "How we handle your information")
                }
            }
            .padding(.horizontal, AFSpacing.md)
            .padding(.top, AFSpacing.sm)
        }
        .background(Color.afBackground)
        .navigationTitle("Privacy & Security")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - App Settings View

struct AppSettingsView: View {
    @State private var darkMode = false
    @State private var useCm = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AFSpacing.lg) {
                SettingsSection(title: "DISPLAY") {
                    NavigationRow(icon: "globe", iconColor: .afPrimary, title: "Language", subtitle: "English (US)")
                    NavigationRow(icon: "dollarsign.circle", iconColor: .afSuccess, title: "Currency", subtitle: "USD — US Dollar")
                    ToggleRow(icon: "moon", iconColor: Color(hex: "#8B5CF6"), title: "Dark Mode", subtitle: "Off", isOn: $darkMode)
                }
                SettingsSection(title: "ARTWORK DIMENSIONS") {
                    HStack(spacing: AFSpacing.sm) {
                        Image(systemName: "ruler")
                            .foregroundColor(.afTextSecondary)
                            .frame(width: 36, height: 36)
                            .background(Color.afBackground)
                            .clipShape(RoundedRectangle(cornerRadius: AFRadius.sm))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Measurement Unit")
                                .font(AFFont.bodyMedium)
                                .foregroundColor(.afTextPrimary)
                            Text("Used on artwork detail pages")
                                .font(AFFont.caption)
                                .foregroundColor(.afTextSecondary)
                        }
                        Spacer()
                        HStack(spacing: 0) {
                            Button { useCm = true } label: {
                                Text("cm")
                                    .font(AFFont.captionBold)
                                    .foregroundColor(useCm ? .white : .afTextSecondary)
                                    .frame(width: 36, height: 28)
                                    .background(useCm ? Color.afPrimary : Color.afBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: AFRadius.sm))
                            }
                            Button { useCm = false } label: {
                                Text("in")
                                    .font(AFFont.captionBold)
                                    .foregroundColor(!useCm ? .white : .afTextSecondary)
                                    .frame(width: 36, height: 28)
                                    .background(!useCm ? Color.afPrimary : Color.afBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: AFRadius.sm))
                            }
                        }
                        .background(Color.afBackground)
                        .clipShape(RoundedRectangle(cornerRadius: AFRadius.sm))
                        .overlay(RoundedRectangle(cornerRadius: AFRadius.sm).stroke(Color.afBorder, lineWidth: 1))
                    }
                    .padding(.horizontal, AFSpacing.md)
                    .padding(.vertical, AFSpacing.sm)
                }
                SettingsSection(title: "STORAGE") {
                    NavigationRow(icon: "trash", iconColor: .afError, title: "Clear Cache", subtitle: "Free up storage · ~14 MB cached")
                }
                SettingsSection(title: "LEGAL") {
                    NavigationRow(icon: "info.circle", iconColor: .afInfo, title: "Terms of Service", subtitle: "")
                    NavigationRow(icon: "lock.circle", iconColor: .afInfo, title: "Privacy Policy", subtitle: "")
                    NavigationRow(icon: "doc.circle", iconColor: .afInfo, title: "Licences", subtitle: "")
                }

                Text("Artist Folio v2.0.0 (Build 2047) © 2026 Artist Folio Inc. All rights reserved.")
                    .font(AFFont.caption)
                    .foregroundColor(.afTextTertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, AFSpacing.sm)
            }
            .padding(.horizontal, AFSpacing.md)
            .padding(.top, AFSpacing.sm)
        }
        .background(Color.afBackground)
        .navigationTitle("App Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Help Center View

struct HelpCenterView: View {
    @State private var searchText = ""
    @State private var expandedFAQ: String? = nil

    let buyingFAQs = [
        ("How does shipping work?", "All artworks are carefully packed by the artist and shipped with tracked courier services. Shipping times vary by region: 3–7 days domestically, 7–21 days internationally. A tracking number is provided once your order ships."),
        ("What is the return policy?", "Returns are accepted within 14 days of delivery if the artwork arrives damaged."),
        ("Are artworks insured during shipping?", "Yes, all shipments include basic insurance coverage."),
        ("Can I buy multiple artworks in one order?", "Yes, you can add multiple artworks to your cart and check out together."),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AFSpacing.lg) {
                // Search
                HStack {
                    Image(systemName: "magnifyingglass").foregroundColor(.afTextTertiary)
                    TextField("Search FAQs", text: $searchText)
                        .font(AFFont.bodyMedium)
                }
                .padding(.horizontal, AFSpacing.md)
                .frame(height: 44)
                .background(Color.afSurface)
                .clipShape(RoundedRectangle(cornerRadius: AFRadius.lg))
                .overlay(RoundedRectangle(cornerRadius: AFRadius.lg).stroke(Color.afBorder, lineWidth: 1))

                Text("BUYING & SHIPPING")
                    .font(AFFont.sectionHeader)
                    .foregroundColor(.afTextSecondary)
                    .tracking(0.5)

                VStack(spacing: 0) {
                    ForEach(buyingFAQs, id: \.0) { faq in
                        FAQRow(question: faq.0, answer: faq.1, isExpanded: expandedFAQ == faq.0) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                expandedFAQ = expandedFAQ == faq.0 ? nil : faq.0
                            }
                        }
                        if faq.0 != buyingFAQs.last?.0 {
                            Divider()
                        }
                    }
                }
                .background(Color.afSurface)
                .clipShape(RoundedRectangle(cornerRadius: AFRadius.lg))
                .afCardShadow()
            }
            .padding(.horizontal, AFSpacing.md)
            .padding(.top, AFSpacing.sm)
        }
        .background(Color.afBackground)
        .navigationTitle("Help Center")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FAQRow: View {
    let question: String
    let answer: String
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onTap) {
                HStack {
                    Text(question)
                        .font(AFFont.bodyMedium)
                        .foregroundColor(.afTextPrimary)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(.afTextTertiary)
                }
                .padding(.horizontal, AFSpacing.md)
                .padding(.vertical, AFSpacing.sm)
            }

            if isExpanded {
                Text(answer)
                    .font(AFFont.bodySmall)
                    .foregroundColor(.afTextSecondary)
                    .lineSpacing(4)
                    .padding(.horizontal, AFSpacing.md)
                    .padding(.bottom, AFSpacing.sm)
            }
        }
    }
}

// MARK: - Cart View

struct CartView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            if appState.cartItems.isEmpty {
                EmptyStateView(icon: "bag", title: "Your cart is empty", subtitle: "Browse artworks and add pieces you love.")
            } else {
                List {
                    ForEach(appState.cartItems) { item in
                        HStack(spacing: AFSpacing.md) {
                            RoundedRectangle(cornerRadius: AFRadius.sm)
                                .fill(Color.afSurface2)
                                .frame(width: 72, height: 72)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.artwork.title).font(AFFont.headlineSmall).foregroundColor(.afTextPrimary)
                                Text(item.artwork.artistName).font(AFFont.bodySmall).foregroundColor(.afTextSecondary)
                                Text("$\(Int(item.artwork.price))").font(AFFont.price).foregroundColor(.afPrimary)
                            }
                            Spacer()
                            Button { appState.removeFromCart(id: item.id) } label: {
                                Image(systemName: "trash").foregroundColor(.afError)
                            }
                        }
                        .listRowBackground(Color.afSurface)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)

                // Summary
                VStack(spacing: AFSpacing.sm) {
                    HStack {
                        Text("Subtotal").foregroundColor(.afTextSecondary)
                        Spacer()
                        Text("$\(Int(appState.cartTotal))").foregroundColor(.afTextPrimary)
                    }
                    HStack {
                        Text("Shipping & Handling").foregroundColor(.afTextSecondary)
                        Spacer()
                        Text("$45").foregroundColor(.afTextPrimary)
                    }
                    Divider()
                    HStack {
                        Text("Total").font(AFFont.headlineSmall).foregroundColor(.afTextPrimary)
                        Spacer()
                        Text("$\(Int(appState.cartTotal) + 45)").font(AFFont.price).foregroundColor(.afPrimary)
                    }

                    Button { } label: {
                        HStack {
                            Text("Continue to Shipping")
                            Image(systemName: "chevron.right")
                        }
                    }
                    .buttonStyle(AFPrimaryButtonStyle())
                }
                .font(AFFont.bodyMedium)
                .padding(AFSpacing.md)
                .background(Color.afSurface)
            }
        }
        .background(Color.afBackground)
        .navigationTitle("Cart (\(appState.cartCount))")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Studio View (Artist)

struct StudioView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: String = "Listings"
    let tabs = ["Listings", "Commissions", "Orders", "Analytics"]

    var body: some View {
        VStack(spacing: 0) {
            // Stats bar
            HStack(spacing: AFSpacing.sm) {
                StatCard(value: "$0", label: "Earnings", color: .afSuccess)
                StatCard(value: "6,490", label: "Total Views", color: .afPrimary)
                StatCard(value: "496", label: "Likes", color: .afOrange)
            }
            .padding(.horizontal, AFSpacing.md)
            .padding(.top, AFSpacing.sm)

            // Tab selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AFSpacing.lg) {
                    ForEach(tabs, id: \.self) { tab in
                        Button { selectedTab = tab } label: {
                            VStack(spacing: AFSpacing.xs) {
                                HStack(spacing: 4) {
                                    Text(tab)
                                        .font(AFFont.headlineSmall)
                                        .foregroundColor(selectedTab == tab ? .afTextPrimary : .afTextTertiary)
                                    if tab == "Commissions" {
                                        Text("2")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.white)
                                            .frame(width: 18, height: 18)
                                            .background(Color.afPrimary)
                                            .clipShape(Circle())
                                    }
                                }
                                Rectangle()
                                    .fill(selectedTab == tab ? Color.afPrimary : Color.clear)
                                    .frame(height: 2)
                            }
                        }
                    }
                }
                .padding(.horizontal, AFSpacing.md)
            }
            .padding(.top, AFSpacing.md)

            Divider()

            // Tab content
            ScrollView {
                switch selectedTab {
                case "Listings":
                    VStack(spacing: AFSpacing.md) {
                        ForEach(Artwork.previews) { artwork in
                            ArtworkListingCard(artwork: artwork)
                        }
                    }
                    .padding(.horizontal, AFSpacing.md)
                    .padding(.top, AFSpacing.sm)
                case "Analytics":
                    AnalyticsView()
                default:
                    EmptyStateView(icon: "doc.text", title: "No \(selectedTab.lowercased()) yet", subtitle: "This section will show your \(selectedTab.lowercased()).")
                        .frame(minHeight: 300)
                }
            }

            Spacer(minLength: 80)
        }
        .background(Color.afBackground)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Studio").font(AFFont.headlineMedium).foregroundColor(.afTextPrimary)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: NewListingView()) {
                    Circle()
                        .fill(Color.afPrimary)
                        .frame(width: 32, height: 32)
                        .overlay(Image(systemName: "plus").font(.system(size: 14, weight: .bold)).foregroundColor(.white))
                }
            }
        }
    }
}

// MARK: - Saved View (Collector)

struct SavedView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        EmptyStateView(icon: "heart", title: "No saved artworks yet", subtitle: "Tap the heart on any artwork to save it here.")
            .background(Color.afBackground)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Saved").font(AFFont.headlineMedium).foregroundColor(.afTextPrimary)
                }
            }
    }
}

// MARK: - New Listing View

struct NewListingView: View {
    @Environment(\.dismiss) var dismiss
    @State private var title = ""
    @State private var price = ""
    @State private var width = ""
    @State private var height = ""
    @State private var year = "2026"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AFSpacing.lg) {
                // Photos section
                HStack(spacing: AFSpacing.sm) {
                    Image(systemName: "photo.on.rectangle")
                        .foregroundColor(.afPrimary)
                        .frame(width: 32, height: 32)
                        .background(Color.afPrimaryLight)
                        .clipShape(RoundedRectangle(cornerRadius: AFRadius.sm))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Photos").font(AFFont.headlineSmall).foregroundColor(.afTextPrimary)
                        Text("Add up to 5 high-quality photos").font(AFFont.caption).foregroundColor(.afTextSecondary)
                    }
                }

                // Photo upload area
                VStack(spacing: AFSpacing.sm) {
                    Image(systemName: "camera")
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(.afTextTertiary)
                    HStack(spacing: 0) {
                        Text("Add Photos ").font(AFFont.bodyMedium).foregroundColor(.afTextSecondary)
                        Text("*").foregroundColor(.afError)
                    }
                    Text("High quality photos help sell your art")
                        .font(AFFont.caption)
                        .foregroundColor(.afTextTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AFSpacing.xl)
                .background(Color.afSurface)
                .clipShape(RoundedRectangle(cornerRadius: AFRadius.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: AFRadius.lg)
                        .stroke(Color.afBorder, style: StrokeStyle(lineWidth: 1, dash: [6]))
                )

                // Basic Info
                HStack(spacing: AFSpacing.sm) {
                    Image(systemName: "pencil")
                        .foregroundColor(.afPrimary)
                        .frame(width: 32, height: 32)
                        .background(Color.afPrimaryLight)
                        .clipShape(RoundedRectangle(cornerRadius: AFRadius.sm))
                    Text("Basic Info").font(AFFont.headlineSmall).foregroundColor(.afTextPrimary)
                }

                FormField(label: "TITLE *", placeholder: "Name your painting", text: $title)
                FormField(label: "PRICE (USD) *", placeholder: "$ 0.00", text: $price, keyboardType: .decimalPad)

                Text("DIMENSIONS (CM)")
                    .font(AFFont.sectionHeader)
                    .foregroundColor(.afTextSecondary)
                    .tracking(0.5)
                HStack(spacing: AFSpacing.sm) {
                    TextField("Width", text: $width)
                        .keyboardType(.decimalPad)
                        .padding(.horizontal, AFSpacing.md)
                        .frame(height: 50)
                        .background(Color.afBackground)
                        .clipShape(RoundedRectangle(cornerRadius: AFRadius.md))
                        .overlay(RoundedRectangle(cornerRadius: AFRadius.md).stroke(Color.afBorder, lineWidth: 1))
                    TextField("Height", text: $height)
                        .keyboardType(.decimalPad)
                        .padding(.horizontal, AFSpacing.md)
                        .frame(height: 50)
                        .background(Color.afBackground)
                        .clipShape(RoundedRectangle(cornerRadius: AFRadius.md))
                        .overlay(RoundedRectangle(cornerRadius: AFRadius.md).stroke(Color.afBorder, lineWidth: 1))
                }

                FormField(label: "YEAR CREATED", placeholder: "2026", text: $year, keyboardType: .numberPad)
            }
            .padding(.horizontal, AFSpacing.md)
            .padding(.top, AFSpacing.sm)
            .padding(.bottom, AFSpacing.xxl)
        }
        .background(Color.afBackground)
        .navigationTitle("New Listing")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { } label: {
                    Circle()
                        .fill(Color.afPrimary)
                        .frame(width: 32, height: 32)
                        .overlay(Image(systemName: "square.and.arrow.down").font(.system(size: 14, weight: .semibold)).foregroundColor(.white))
                }
            }
        }
    }
}

// MARK: - Shared Components

struct AvatarCircle: View {
    let name: String
    var size: CGFloat = 44

    var body: some View {
        Circle()
            .fill(Color.afSurface2)
            .frame(width: size, height: size)
            .overlay(
                Text(String(name.prefix(1)))
                    .font(.system(size: size * 0.38, weight: .semibold))
                    .foregroundColor(.afTextSecondary)
            )
    }
}

struct MediumTag: View {
    let text: String
    var body: some View {
        Text(text)
            .font(AFFont.caption)
            .foregroundColor(.afTextSecondary)
            .padding(.horizontal, AFSpacing.sm)
            .padding(.vertical, AFSpacing.xxs)
            .overlay(RoundedRectangle(cornerRadius: AFRadius.full).stroke(Color.afBorder, lineWidth: 1))
    }
}

struct StatValue: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(AFFont.statNumber)
                .foregroundColor(.afTextPrimary)
            Text(label)
                .font(AFFont.statLabel)
                .foregroundColor(.afTextSecondary)
        }
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: AFSpacing.xs) {
            Text(title)
                .font(AFFont.sectionHeader)
                .foregroundColor(.afTextSecondary)
                .tracking(0.5)

            VStack(spacing: 0) {
                content
            }
            .background(Color.afSurface)
            .clipShape(RoundedRectangle(cornerRadius: AFRadius.lg))
            .afCardShadow()
        }
    }
}

struct ToggleRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: AFSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(iconColor)
                .frame(width: 36, height: 36)
                .background(iconColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: AFRadius.sm))

            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(AFFont.bodyMedium).foregroundColor(.afTextPrimary)
                Text(subtitle).font(AFFont.caption).foregroundColor(.afTextSecondary)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .tint(.afPrimary)
                .labelsHidden()
        }
        .padding(.horizontal, AFSpacing.md)
        .padding(.vertical, AFSpacing.sm)
    }
}

struct NavigationRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: AFSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(iconColor)
                .frame(width: 36, height: 36)
                .background(iconColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: AFRadius.sm))

            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(AFFont.bodyMedium).foregroundColor(.afTextPrimary)
                if !subtitle.isEmpty {
                    Text(subtitle).font(AFFont.caption).foregroundColor(.afTextSecondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.afTextTertiary)
        }
        .padding(.horizontal, AFSpacing.md)
        .padding(.vertical, AFSpacing.sm)
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: AFSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 50, weight: .ultraLight))
                .foregroundColor(.afTextTertiary)
            Text(title).font(AFFont.headlineSmall).foregroundColor(.afTextPrimary)
            Text(subtitle).font(AFFont.bodySmall).foregroundColor(.afTextSecondary).multilineTextAlignment(.center)
        }
        .padding(.horizontal, AFSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct AFTextField: View {
    let placeholder: String
    @Binding var text: String
    var icon: String = ""
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        HStack(spacing: AFSpacing.sm) {
            if !icon.isEmpty {
                Image(systemName: icon)
                    .foregroundColor(.afTextTertiary)
                    .frame(width: 20)
            }
            TextField(placeholder, text: $text)
                .font(AFFont.bodyMedium)
                .keyboardType(keyboardType)
        }
        .padding(.horizontal, AFSpacing.md)
        .frame(height: 48)
        .background(Color.afSurface)
        .clipShape(RoundedRectangle(cornerRadius: AFRadius.md))
        .overlay(RoundedRectangle(cornerRadius: AFRadius.md).stroke(Color.afBorder, lineWidth: 1))
    }
}

struct TextEditorField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .font(AFFont.bodyMedium)
                    .foregroundColor(.afTextTertiary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 8)
            }
            TextEditor(text: $text)
                .font(AFFont.bodyMedium)
                .frame(minHeight: 80)
                .scrollContentBackground(.hidden)
        }
        .padding(AFSpacing.sm)
        .background(Color.afSurface)
        .clipShape(RoundedRectangle(cornerRadius: AFRadius.md))
        .overlay(RoundedRectangle(cornerRadius: AFRadius.md).stroke(Color.afBorder, lineWidth: 1))
    }
}

struct ArtworkCard: View {
    let artwork: Artwork

    var body: some View {
        VStack(alignment: .leading, spacing: AFSpacing.xs) {
            RoundedRectangle(cornerRadius: AFRadius.md)
                .fill(Color.afSurface2)
                .aspectRatio(0.85, contentMode: .fit)
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "heart")
                        .font(.system(size: 14))
                        .foregroundColor(.afTextSecondary)
                        .frame(width: 28, height: 28)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .padding(AFSpacing.xs)
                }

            Text(artwork.title)
                .font(AFFont.headlineSmall)
                .foregroundColor(.afTextPrimary)
                .lineLimit(1)
            Text("$\(Int(artwork.price))")
                .font(AFFont.price)
                .foregroundColor(.afPrimary)
        }
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    var actionLabel: String = ""
    var action: () -> Void = {}

    var body: some View {
        HStack {
            Text(title)
                .font(AFFont.headlineMedium)
                .foregroundColor(.afTextPrimary)
            Spacer()
            if !actionLabel.isEmpty {
                Button(action: action) {
                    Text(actionLabel)
                        .font(AFFont.labelMedium)
                        .foregroundColor(.afPrimary)
                }
            }
        }
    }
}

// MARK: - Artwork Grid

struct ArtworkGrid: View {
    let artworks: [Artwork]
    var isLoading: Bool = false
    var onSelect: ((Artwork) -> Void)? = nil

    var body: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible())]
        LazyVGrid(columns: columns, spacing: AFSpacing.sm) {
            ForEach(artworks) { artwork in
                ArtworkCard(artwork: artwork)
                    .onTapGesture { onSelect?(artwork) }
            }
        }
    }
}

// MARK: - Artist Profile View (stub)

struct ArtistProfileView: View {
    let artistId: String

    var body: some View {
        VStack(spacing: AFSpacing.md) {
            AvatarCircle(name: "A", size: 80)
            Text("Artist Profile")
                .font(AFFont.headlineLarge)
                .foregroundColor(.afTextPrimary)
            Text("Profile details coming soon.")
                .font(AFFont.bodySmall)
                .foregroundColor(.afTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.afBackground)
        .navigationTitle("Artist")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Checkout View (stub)

struct CheckoutView: View {
    let artwork: Artwork
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: AFSpacing.lg) {
                Image(systemName: "creditcard")
                    .font(.system(size: 50, weight: .ultraLight))
                    .foregroundColor(.afTextTertiary)
                Text("Checkout")
                    .font(AFFont.headlineLarge)
                    .foregroundColor(.afTextPrimary)
                Text("$\(Int(artwork.price))")
                    .font(AFFont.priceLarge)
                    .foregroundColor(.afPrimary)
                Text("Payment flow coming soon.")
                    .font(AFFont.bodySmall)
                    .foregroundColor(.afTextSecondary)
                Spacer()
            }
            .padding(.top, AFSpacing.xxxl)
            .frame(maxWidth: .infinity)
            .background(Color.afBackground)
            .navigationTitle("Checkout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.afTextSecondary)
                }
            }
        }
    }
}

func formatCount(_ count: Int) -> String {
    if count >= 1000 {
        let k = Double(count) / 1000.0
        return String(format: "%.1fK", k)
    }
    return "\(count)"
}
