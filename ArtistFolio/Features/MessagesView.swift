import SwiftUI

// MARK: - Conversation List

@MainActor
final class MessagesModel: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load(backend: ArtBackend) async {
        isLoading = conversations.isEmpty
        defer { isLoading = false }
        do {
            conversations = try await backend.conversations()
        } catch {
            errorMessage = AppState.message(for: error)
        }
    }
}

struct MessagesView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var model = MessagesModel()

    var body: some View {
        Group {
            if !appState.hasICloud {
                iCloudPrompt
            } else if model.isLoading {
                ProgressView().tint(.afPrimary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.conversations.isEmpty {
                emptyState
            } else {
                conversationList
            }
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Messages").font(AFFont.headlineMedium).foregroundStyle(.primary)
            }
        }
        .artNavigation()
        .task(id: appState.contentVersion) { await model.load(backend: appState.backend) }
        .refreshable { await model.load(backend: appState.backend) }
    }

    private var conversationList: some View {
        List {
            ForEach(model.conversations) { conv in
                NavigationLink(value: ConversationLink(conversation: conv)) {
                    ConversationRow(conversation: conv, myID: appState.currentUserID ?? "")
                }
                .listRowBackground(Color(uiColor: .secondarySystemGroupedBackground))
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 56, weight: .ultraLight))
                .foregroundStyle(.secondary)
                .symbolEffect(.pulse, options: .repeating)
            Text("No Messages Yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
            Text("Start a conversation by contacting an artist from their profile.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var iCloudPrompt: some View {
        EmptyStateView(
            icon: "icloud",
            title: "Sign In to Message",
            subtitle: "Messages are stored privately in your iCloud account.",
            actionTitle: "Learn How"
        ) {
            appState.showICloudPrompt = true
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ConversationRow: View {
    let conversation: Conversation
    let myID: String

    var body: some View {
        HStack(spacing: 12) {
            AvatarCircle(name: conversation.otherName, url: conversation.otherAvatarURL, size: 50)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(conversation.otherName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(conversation.lastDate, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(conversation.lastMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Navigation Value

struct ConversationLink: Hashable {
    let conversation: Conversation
}

// MARK: - Message Detail

@MainActor
final class ConversationModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isLoading = false
    @Published var draftText = ""
    @Published var isSending = false
    @Published var errorMessage: String?

    let conversation: Conversation

    init(conversation: Conversation) {
        self.conversation = conversation
    }

    func load(backend: ArtBackend) async {
        isLoading = messages.isEmpty
        defer { isLoading = false }
        do {
            messages = try await backend.messages(conversationID: conversation.id)
        } catch {
            errorMessage = AppState.message(for: error)
        }
    }

    func send(backend: ArtBackend) async {
        let text = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draftText = ""
        isSending = true
        defer { isSending = false }
        do {
            let msg = try await backend.sendMessage(
                to: conversation.otherUserID,
                recipientName: conversation.otherName,
                text: text
            )
            messages.append(msg)
        } catch {
            errorMessage = AppState.message(for: error)
            draftText = text
        }
    }
}

struct ConversationDetailView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var model: ConversationModel
    @FocusState private var inputFocused: Bool
    private let scrollAnchor = "bottom"

    init(conversation: Conversation) {
        _model = StateObject(wrappedValue: ConversationModel(conversation: conversation))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        if model.isLoading {
                            ProgressView().tint(.afPrimary).padding(.top, 40)
                        }
                        ForEach(model.messages) { msg in
                            MessageBubble(
                                message: msg,
                                isFromMe: msg.senderID == appState.currentUserID
                            )
                        }
                        Color.clear.frame(height: 1).id(scrollAnchor)
                    }
                    .padding(.vertical, 12)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: model.messages.count) { _, _ in
                    withAnimation { proxy.scrollTo(scrollAnchor, anchor: .bottom) }
                }
                .onAppear {
                    proxy.scrollTo(scrollAnchor, anchor: .bottom)
                }
            }

            Divider()
            composeBar
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(model.conversation.otherName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load(backend: appState.backend) }
        .alert("Error", isPresented: .constant(model.errorMessage != nil)) {
            Button("OK") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private var composeBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Message", text: $model.draftText, axis: .vertical)
                .lineLimit(1...5)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
                .focused($inputFocused)
                .onSubmit {
                    Task { await model.send(backend: appState.backend) }
                }

            Button {
                Task { await model.send(backend: appState.backend) }
            } label: {
                Image(systemName: model.isSending ? "arrow.up.circle" : "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .symbolEffect(.bounce, value: model.isSending)
                    .foregroundStyle(model.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.secondary : Color.afPrimary)
            }
            .disabled(model.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isSending)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }
}

struct MessageBubble: View {
    let message: Message
    let isFromMe: Bool

    var body: some View {
        HStack {
            if isFromMe { Spacer(minLength: 60) }
            VStack(alignment: isFromMe ? .trailing : .leading, spacing: 2) {
                Text(message.text)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        isFromMe ? Color.afPrimary : Color(uiColor: .secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                    .foregroundStyle(isFromMe ? .white : .primary)
                    .font(.body)
                Text(message.date, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 4)
            }
            if !isFromMe { Spacer(minLength: 60) }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 2)
    }
}

// MARK: - Navigation extension

extension View {
    func messagesNavigation() -> some View {
        navigationDestination(for: ConversationLink.self) {
            ConversationDetailView(conversation: $0.conversation)
        }
    }
}
