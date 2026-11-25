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
    @State private var showShare = false
    @State private var viewerMode: ArtworkViewMode?
    @State private var isPastHero = false
    @State private var showOffer = false
    @State private var openFailed = false
    @State private var chooseEnquiryChannel = false
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let sheetOverlap: CGFloat = 110
    private static let sheetRadius: CGFloat = 34

    private var isOwner: Bool { artwork.artistId == appState.currentUserID }
    private var isSaved: Bool { appState.isSaved(artwork.id) }
    private var toolbarTint: Color { isPastHero ? .afPrimary : .white }
    private var galleryURLs: [URL] {
        imageURLs.isEmpty ? [artwork.thumbnailURL].compactMap { $0 } : imageURLs
    }

    var body: some View {
        ScrollView {
            VStack(spacing: -Self.sheetOverlap) {
                hero
                infoSheet.zIndex(1)
            }
        }
        .background(Color(uiColor: .systemBackground))
        .ignoresSafeArea(.container, edges: .top)
        .navigationTitle(isPastHero ? artwork.title : "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(isPastHero ? .automatic : .hidden, for: .navigationBar)
        .toolbarColorScheme(isPastHero ? nil : .dark, for: .navigationBar)
        .fullScreenCover(item: $viewerMode) { mode in
            ArtworkViewer(urls: galleryURLs, title: artwork.title, dimensions: artwork.dimensions, selection: $selectedImage, initialMode: mode)
        }
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    appState.toggleSaved(artwork.id)
                } label: {
                    Label(isSaved ? "Remove from Saved" : "Save", systemImage: isSaved ? "heart.fill" : "heart")
                        .symbolEffect(.bounce, value: isSaved)
                }
                .tint(toolbarTint)
                .sensoryFeedback(.selection, trigger: isSaved)

                Button("Share", systemImage: "square.and.arrow.up") { showShare = true }
                    .tint(toolbarTint)

                if !isOwner {
                    Menu {
                        Button("Report Artwork", systemImage: "flag") { showReport = true }
                        Button("Block Artist", systemImage: "hand.raised", role: .destructive) { showBlockConfirm = true }
                    } label: {
                        Label("More", systemImage: "ellipsis.circle")
                    }
                    .tint(toolbarTint)
                }
            }
        }
        .afBottomBar { bottomBar }
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
        .sheet(isPresented: $showShare) {
            SocialShareSheet(subject: .artwork(artwork, preferredImage: galleryURLs.indices.contains(selectedImage) ? galleryURLs[selectedImage] : nil))
        }
        .sheet(isPresented: $showOffer) {
            OfferSheet(artwork: artwork, artistName: artwork.artistName, channels: buyerChannels)
        }
        .confirmationDialog("Ask \(BuyerMessage.firstName(artwork.artistName)) for the price", isPresented: $chooseEnquiryChannel, titleVisibility: .visible) {
            ForEach(buyerChannels, id: \.self) { channel in
                Button(channel.label) { askForPrice(via: channel) }
            }
        }
        .alert("Couldn\u{2019}t open the app", isPresented: $openFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Use another contact option on \(BuyerMessage.firstName(artwork.artistName))\u{2019}s profile.")
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

    private var hero: some View {
        Color.clear
            .containerRelativeFrame(.vertical) { height, _ in height * (artwork.dimensions.isPortrait ? 0.76 : 0.62) + Self.sheetOverlap - 28 }
            .overlay {
                gallery
                    .visualEffect { [reduceMotion] content, proxy in
                        let y = proxy.frame(in: .scrollView).minY
                        let stretch = 1 + max(y, 0) / max(proxy.size.height, 1)
                        let shift = y > 0 ? -y : (reduceMotion ? 0 : -y * 0.35)
                        return content
                            .scaleEffect(stretch, anchor: .top)
                            .offset(y: shift)
                    }
            }
            .overlay(alignment: .bottom) {
                LinearGradient(colors: [.clear, Color(uiColor: .systemBackground)], startPoint: .top, endPoint: .bottom)
                    .frame(height: Self.sheetOverlap)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .bottomTrailing) {
                if !galleryURLs.isEmpty {
                    Button { viewerMode = .wall } label: {
                        Label("View on Wall", systemImage: "photo.artframe")
                            .font(.subheadline.weight(.semibold))
                            .frame(minHeight: 28)
                    }
                    .afGlassButton()
                    .tint(.white)
                    .environment(\.colorScheme, .dark)
                    .padding(.trailing, AFSpacing.md)
                    .padding(.bottom, Self.sheetOverlap + AFSpacing.sm)
                }
            }
            .overlay(alignment: .bottomLeading) {
                if galleryURLs.count > 1 {
                    HStack(spacing: 6) {
                        ForEach(galleryURLs.indices, id: \.self) { index in
                            Capsule()
                                .fill(.white.opacity(index == selectedImage ? 1 : 0.5))
                                .frame(width: index == selectedImage ? 20 : 6, height: 6)
                        }
                    }
                    .animation(.smooth, value: selectedImage)
                    .padding(.leading, AFSpacing.md)
                    .padding(.bottom, Self.sheetOverlap + AFSpacing.lg)
                    .accessibilityHidden(true)
                }
            }
            .onGeometryChange(for: Bool.self) { proxy in
                proxy.frame(in: .scrollView).maxY < 130 + Self.sheetOverlap
            } action: { isPastHero = $0 }
    }

    private var gallery: some View {
        TabView(selection: $selectedImage) {
            if galleryURLs.isEmpty {
                CloudImage(url: nil).tag(0)
            }
            ForEach(Array(galleryURLs.enumerated()), id: \.offset) { index, url in
                heroImage(url)
                    .contentShape(Rectangle())
                    .onTapGesture { viewerMode = .full }
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .overlay(alignment: .top) {
            LinearGradient(colors: [.black.opacity(0.45), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 150)
                .allowsHitTesting(false)
        }
        .accessibilityLabel("Photos of \(artwork.title). Double tap to view full screen.")
    }

    private func heroImage(_ url: URL) -> some View {
        Color.clear
            .overlay(CloudImage(url: url, maxPixels: 400).blur(radius: 36).overlay(Color.black.opacity(0.25)))
            .clipped()
            .overlay {
                CloudImage(url: url, maxPixels: 1600, contentMode: .fit)
                    .shadow(color: .black.opacity(0.35), radius: 14, y: 6)
                    .padding(.top, 100)
                    .padding(.bottom, Self.sheetOverlap + 64)
                    .padding(.horizontal, AFSpacing.md)
            }
    }

    private var infoSheet: some View {
        VStack(alignment: .leading, spacing: AFSpacing.lg) {
            Capsule()
                .fill(Color(uiColor: .tertiaryLabel))
                .frame(width: 36, height: 5)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)

            listingHeader
            priceCard

            NavigationLink(value: ArtistLink(id: artwork.artistId)) {
                HStack(spacing: AFSpacing.sm) {
                    AvatarCircle(name: artwork.artistName, url: artist?.avatarURL, size: 44)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(artwork.artistName).font(.body.weight(.medium))
                        Text("View profile").font(.footnote).foregroundStyle(Color.afTextSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.forward")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.afIconSecondary)
                }
                .padding(AFSpacing.sm)
                .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: AFRadius.md, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: AFRadius.md, style: .continuous))
            }
            .buttonStyle(.plain)

            if !artwork.details.isEmpty {
                VStack(alignment: .leading, spacing: AFSpacing.xs) {
                    Text("About").font(.headline)
                    Text(artwork.details).font(.body).foregroundStyle(Color.afTextSecondary)
                }
            }

            VStack(alignment: .leading, spacing: AFSpacing.xs) {
                Text("Details").font(.headline)
                VStack(spacing: AFSpacing.sm) {
                    LabeledContent("Medium", value: artwork.medium.rawValue)
                    Divider()
                    LabeledContent("Style", value: artwork.style.rawValue)
                    Divider()
                    LabeledContent("Dimensions", value: artwork.dimensions.displayString)
                    Divider()
                    LabeledContent("Year", value: String(artwork.year))
                    Divider()
                    LabeledContent("Status", value: artwork.status.label)
                }
                .labeledContentStyle(AFLabeledContentStyle())
                .padding(AFSpacing.md)
                .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: AFRadius.md, style: .continuous))
            }

            if !artwork.tags.isEmpty {
                FlowLayout(spacing: AFSpacing.xs) {
                    ForEach(artwork.tags, id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.footnote)
                            .foregroundStyle(Color.afTextSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, AFSpacing.xxs)
                            .background(Color(uiColor: .tertiarySystemFill), in: Capsule())
                    }
                }
            }

            Text("Artist Folio does not process sales. Arrange payment and delivery directly with the artist.")
                .font(.footnote)
                .foregroundStyle(Color.afTextSecondary)
        }
        .padding(.horizontal, AFSpacing.lg)
        .padding(.top, AFSpacing.sm)
        .padding(.bottom, AFSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .afGlass(
            in: UnevenRoundedRectangle(topLeadingRadius: Self.sheetRadius, topTrailingRadius: Self.sheetRadius, style: .continuous),
            tint: Color(uiColor: .systemBackground).opacity(0.62)
        )
    }

    private var listingHeader: some View {
        VStack(alignment: .leading, spacing: AFSpacing.xs) {
            VStack(alignment: .leading, spacing: AFSpacing.xxs) {
                Text(artwork.title)
                    .font(.title.bold())
                    .accessibilityAddTraits(.isHeader)
                Text("\(artwork.medium.rawValue) · \(artwork.dimensions.displayString) · \(String(artwork.year))")
                    .font(.subheadline)
                    .foregroundStyle(Color.afTextSecondary)
            }
            FlowLayout(spacing: AFSpacing.xs) {
                ListingChip(status: artwork.status)
                ListingChip(text: artwork.style.rawValue)
            }
        }
    }

    private var artistFirstName: String {
        artwork.artistName.split(separator: " ").first.map(String.init) ?? artwork.artistName
    }

    private var priceCard: some View {
        HStack(spacing: AFSpacing.sm) {
            if artwork.status == .sold {
                VStack(alignment: .leading, spacing: 2) {
                    Text("This piece has sold")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Color.afTextSecondary)
                    Text(isOwner ? artwork.priceText : "Follow \(artistFirstName) for new work")
                        .font(isOwner ? .title2.weight(.semibold) : .headline)
                }
                Spacer(minLength: 0)
                if !isOwner {
                    followButton
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Price")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Color.afTextSecondary)
                    if artwork.priceOnRequest {
                        Text("On request").font(.headline)
                    } else {
                        Text(artwork.priceText).font(.title2.weight(.semibold))
                    }
                }
                Spacer(minLength: 0)
                if canMessageArtist {
                    buyerAction
                }
            }
        }
        .padding(.horizontal, AFSpacing.md)
        .padding(.vertical, 14)
        .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: AFRadius.md, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    /// Offers and price questions go by email or WhatsApp, whichever the artist listed.
    private var buyerChannels: [BuyerMessage.Channel] { BuyerMessage.channels(for: artist) }

    private var canMessageArtist: Bool {
        !isOwner && artwork.status == .available && !buyerChannels.isEmpty
    }

    private func askForPrice(via channel: BuyerMessage.Channel) {
        guard let url = BuyerMessage.priceEnquiryURL(via: channel, artistName: artwork.artistName, artwork: artwork) else { return }
        openURL(url) { accepted in if !accepted { openFailed = true } }
    }

    @ViewBuilder
    private var buyerAction: some View {
        if artwork.priceOnRequest {
            Button {
                if buyerChannels.count == 1, let channel = buyerChannels.first {
                    askForPrice(via: channel)
                } else {
                    chooseEnquiryChannel = true
                }
            } label: {
                Text("Ask for Price")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, AFSpacing.xs)
            }
            .afGlassProminentButton()
            .tint(Color.afPrimary)
        } else {
            Button { showOffer = true } label: {
                Text("Make an Offer")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, AFSpacing.xs)
            }
            .afGlassButton()
            .tint(Color.afPrimary)
        }
    }

    private var followButton: some View {
        let following = appState.isFollowing(artwork.artistId)
        return Button {
            appState.toggleFollowing(artwork.artistId)
        } label: {
            Text(following ? "Following" : "Follow")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, AFSpacing.xs)
        }
        .afGlassButton()
        .tint(Color.afPrimary)
        .sensoryFeedback(.selection, trigger: following)
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
            // The price card already says it has sold and offers Follow.
            EmptyView()
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
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .afGlass(in: Capsule())
            }
        }
    }

    private func barContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, AFSpacing.md)
            .padding(.vertical, AFSpacing.xs)
    }
}

enum ArtworkViewMode: String, CaseIterable, Identifiable {
    case full = "Full", frame = "Frame", wall = "On Wall", ar = "AR"
    var id: String { rawValue }
}

private struct ArtworkViewer: View {
    @Environment(\.dismiss) private var dismiss
    let urls: [URL]
    let title: String
    let dimensions: ArtworkDimensions
    @Binding var selection: Int
    @State private var mode: ArtworkViewMode

    @State private var imageAspect: CGFloat?

    init(urls: [URL], title: String, dimensions: ArtworkDimensions, selection: Binding<Int>, initialMode: ArtworkViewMode) {
        self.urls = urls
        self.title = title
        self.dimensions = dimensions
        _selection = selection
        _mode = State(initialValue: initialMode)
    }

    private var currentURL: URL? {
        urls.indices.contains(selection) ? urls[selection] : urls.first
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch mode {
                case .full:
                    TabView(selection: $selection) {
                        ForEach(Array(urls.enumerated()), id: \.offset) { index, url in
                            CloudImage(url: url, maxPixels: 2048, contentMode: .fit).tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: urls.count > 1 ? .automatic : .never))
                    .background(Color.black)
                case .frame:
                    GeometryReader { proxy in
                        FramedArtwork(url: currentURL, aspectRatio: imageAspect ?? dimensions.aspectRatio, matWidth: 28, frameWidth: 10)
                            .padding(.horizontal, AFSpacing.xl)
                            .padding(.top, 90)
                            .padding(.bottom, 110)
                            .frame(width: proxy.size.width, height: proxy.size.height)
                    }
                    .background(WallBackground())
                case .wall:
                    WallPreview(url: currentURL, dimensions: dimensions, imageAspect: imageAspect)
                case .ar:
                    ARPaintingView(imageURL: currentURL, dimensions: dimensions)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()

            Picker("View", selection: $mode.animation(.smooth)) {
                ForEach(ArtworkViewMode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(AFSpacing.xxs)
            .afGlass(in: Capsule())
            .padding(.horizontal, AFSpacing.md)
            .padding(.bottom, AFSpacing.sm)
        }
        .background(Color.black)
        .overlay(alignment: .topTrailing) {
            Button("Close", systemImage: "xmark") { dismiss() }
                .labelStyle(.iconOnly)
                .font(.headline)
                .buttonBorderShape(.circle)
                .secondaryAction()
                .padding(AFSpacing.md)
        }
        .task(id: currentURL) {
            guard let url = currentURL else { imageAspect = nil; return }
            imageAspect = await Task.detached { ImageProcessor.aspectRatio(url) }.value
        }
        .environment(\.colorScheme, .dark)
        .accessibilityLabel("Full screen view of \(title)")
    }
}

private struct WallBackground: View {
    var body: some View {
        LinearGradient(colors: [Color(white: 0.93), Color(white: 0.84)], startPoint: .top, endPoint: .bottom)
    }
}

private struct FramedArtwork: View {
    let url: URL?
    let aspectRatio: CGFloat
    let matWidth: CGFloat
    let frameWidth: CGFloat

    var body: some View {
        Color.clear
            .aspectRatio(aspectRatio, contentMode: .fit)
            .overlay(CloudImage(url: url, maxPixels: 2048))
            .clipped()
            .padding(matWidth)
            .background(Color.white)
            .padding(frameWidth)
            .background(Color(white: 0.08))
            .compositingGroup()
            .shadow(color: .black.opacity(0.3), radius: min(16, frameWidth * 2), x: 0, y: min(10, frameWidth))
    }
}

private struct WallPreview: View {
    let url: URL?
    let dimensions: ArtworkDimensions
    let imageAspect: CGFloat?

    private static let wallWidthCM: CGFloat = 320
    private static let benchWidthCM: CGFloat = 160
    private static let benchHeightCM: CGFloat = 45

    var body: some View {
        GeometryReader { proxy in
            let art = dimensions.sizeInCentimeters(matching: imageAspect)
            let floorHeight = proxy.size.height * 0.2
            let wallHeight = proxy.size.height - floorHeight
            // Oversized work shrinks the whole room so the bench still shows true relative scale.
            let scale = min(proxy.size.width / Self.wallWidthCM,
                            proxy.size.width * 0.82 / art.width,
                            wallHeight * 0.52 / art.height)

            VStack(spacing: 0) {
                ZStack {
                    WallBackground()
                    VStack(spacing: AFSpacing.sm) {
                        Spacer(minLength: 96)
                        FramedArtwork(url: url,
                                      aspectRatio: art.width / art.height,
                                      matWidth: 0,
                                      frameWidth: max(2, 2.5 * scale))
                            .frame(width: art.width * scale + 2 * max(2, 2.5 * scale))
                        Text(dimensions.displayString)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(Color(white: 0.3))
                        Spacer(minLength: AFSpacing.md)
                        bench(scale: scale)
                    }
                }
                Color(white: 0.45)
                    .frame(height: floorHeight)
                    .overlay(alignment: .bottom) {
                        Text("Approximate scale")
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(.bottom, 96)
                    }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Preview of a \(dimensions.displayString) artwork on a wall above a bench, at approximate scale")
    }

    private func bench(scale: CGFloat) -> some View {
        let width = Self.benchWidthCM * scale
        let height = Self.benchHeightCM * scale
        return VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(white: 0.22))
                .frame(width: width, height: height * 0.24)
            HStack {
                Rectangle().frame(width: max(2, 3 * scale))
                Spacer()
                Rectangle().frame(width: max(2, 3 * scale))
            }
            .foregroundStyle(Color(white: 0.15))
            .frame(width: width * 0.9, height: height * 0.76)
        }
        .accessibilityHidden(true)
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
                    EmptyStateView(icon: "checkmark.shield", title: "Report Received", subtitle: "Thank you. We will review your report.", actionTitle: "Done") {
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
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Report")
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
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

private struct OfferSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let artwork: Artwork
    let artistName: String
    let channels: [BuyerMessage.Channel]
    @State private var amount = ""
    @State private var note = ""
    @State private var openFailed = false
    @State private var chooseChannel = false
    @FocusState private var amountFocused: Bool

    private var firstName: String { BuyerMessage.firstName(artistName) }
    private var amountValue: Double? { BuyerMessage.amount(from: amount) }

    private var sendTitle: String {
        channels.count == 1 ? "Open \(channels[0].label)" : "Send"
    }

    private var channelNames: String {
        channels.map(\.label).joined(separator: " or ")
    }

    private func send(via channel: BuyerMessage.Channel) {
        guard let amountValue,
              let url = BuyerMessage.offerURL(via: channel, artistName: artistName, artwork: artwork, amount: amountValue, note: note) else { return }
        openURL(url) { accepted in
            if accepted { dismiss() } else { openFailed = true }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Amount", text: $amount, prompt: Text("1200"))
                        .keyboardType(.decimalPad)
                        .focused($amountFocused)
                } header: {
                    Text("Your offer (USD)")
                } footer: {
                    if !artwork.priceOnRequest {
                        Text("Listed at \(artwork.priceText).")
                    }
                }

                Section {
                    TextField("Add a message for \(firstName)", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                        .onChange(of: note) { _, value in
                            if value.count > BuyerMessage.maxNoteLength { note = String(value.prefix(BuyerMessage.maxNoteLength)) }
                        }
                } header: {
                    Text("Note (optional)")
                } footer: {
                    Text("Opens \(channelNames) with your offer to \(firstName). Artist Folio doesn\u{2019}t handle payment or delivery.")
                }
            }
            .navigationTitle("Make an Offer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(sendTitle) {
                        if channels.count == 1, let channel = channels.first {
                            send(via: channel)
                        } else {
                            chooseChannel = true
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(amountValue == nil || channels.isEmpty)
                }
            }
            .confirmationDialog("Send your offer with", isPresented: $chooseChannel, titleVisibility: .visible) {
                ForEach(channels, id: \.self) { channel in
                    Button(channel.label) { send(via: channel) }
                }
            }
            .alert("Couldn\u{2019}t open the app", isPresented: $openFailed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Use another contact option on \(firstName)\u{2019}s profile.")
            }
            .onAppear { amountFocused = true }
        }
        .presentationDetents([.medium, .large])
    }
}
