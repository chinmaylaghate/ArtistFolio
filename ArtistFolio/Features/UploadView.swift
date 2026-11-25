import PhotosUI
import SwiftUI

struct ArtworkEditorView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let existing: Artwork?
    var onFinished: ((Artwork?) -> Void)?

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var previews: [UIImage] = []
    @State private var processed: [ProcessedImage] = []
    @State private var title = ""
    @State private var details = ""
    @State private var medium: ArtworkMedium = .oilOnCanvas
    @State private var style: ArtworkStyle = .abstract
    @State private var status: ArtworkStatus = .available
    @State private var width = ""
    @State private var height = ""
    @State private var unit = "cm"
    @State private var year = String(Calendar.current.component(.year, from: Date()))
    @State private var price = ""
    @State private var priceOnRequest = false
    @State private var tags = ""
    @State private var isProcessing = false
    @State private var isSaving = false
    @State private var showDelete = false
    @State private var errorMessage: String?

    private static let maxPhotos = 5

    init(existing: Artwork?, onFinished: ((Artwork?) -> Void)? = nil) {
        self.existing = existing
        self.onFinished = onFinished
    }

    private var parsedPrice: Double? { positive(price) }
    private var parsedWidth: Double? { positive(width) }
    private var parsedHeight: Double? { positive(height) }
    private var parsedYear: Int? {
        guard let value = Int(year), (1000...Calendar.current.component(.year, from: Date())).contains(value) else { return nil }
        return value
    }

    private var validationMessage: String? {
        if existing == nil && processed.isEmpty { return "Add at least one photo." }
        if title.trimmed.isEmpty { return "Add a title." }
        if !priceOnRequest && parsedPrice == nil { return "Enter a price above zero, or turn on Price on request." }
        if parsedWidth == nil || parsedHeight == nil { return "Enter width and height." }
        if parsedYear == nil { return "Enter a valid year." }
        return nil
    }

    var body: some View {
        NavigationStack {
            Form {
                photoSection

                Section("Details") {
                    TextField("Title", text: $title)
                    TextField("Description", text: $details, axis: .vertical)
                        .lineLimit(3...8)
                        .onChange(of: details) { _, value in
                            if value.count > 1000 { details = String(value.prefix(1000)) }
                        }
                    Picker("Medium", selection: $medium) {
                        ForEach(ArtworkMedium.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Picker("Style", selection: $style) {
                        ForEach(ArtworkStyle.allCases) { Text($0.rawValue).tag($0) }
                    }
                }

                Section("Dimensions") {
                    numberField("Width", placeholder: "60", text: $width, keyboard: .decimalPad)
                    numberField("Height", placeholder: "80", text: $height, keyboard: .decimalPad)
                    Picker("Unit", selection: $unit) {
                        Text("cm").tag("cm")
                        Text("in").tag("in")
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Toggle("Price on request", isOn: $priceOnRequest.animation())
                    if !priceOnRequest {
                        numberField("Price (USD)", placeholder: "1200", text: $price, keyboard: .decimalPad)
                    }
                    numberField("Year", placeholder: "2026", text: $year, keyboard: .numberPad)
                    if existing != nil {
                        Picker("Status", selection: $status) {
                            ForEach(ArtworkStatus.allCases) { Text($0.label).tag($0) }
                        }
                    }
                } header: {
                    Text("Listing")
                } footer: {
                    if priceOnRequest {
                        Text("Buyers see \u{201C}Price on request\u{201D} and can ask you for it.")
                    }
                }

                Section {
                    TextField("ocean, blue, calm", text: $tags)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Tags")
                } footer: {
                    if let message = errorMessage ?? validationMessage {
                        Text(message).foregroundStyle(errorMessage == nil ? Color.afTextSecondary : Color.red)
                    } else {
                        Text("Separate tags with commas.")
                    }
                }

                if existing != nil {
                    Section {
                        Button("Delete Artwork", role: .destructive) { showDelete = true }
                    }
                } else {
                    Section {
                    } footer: {
                        Text("By publishing, you confirm you created this work and hold its copyright. Selling the piece does not transfer reproduction rights unless you agree that with the buyer. Artist Folio takes no commission and does not handle payment or delivery.")
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(AFSpacing.md)
                            .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: AFRadius.md, style: .continuous))
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(existing == nil ? "New Artwork" : "Edit Artwork")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button(existing == nil ? "Publish" : "Save") {
                            Task { await save() }
                        }
                        .fontWeight(.semibold)
                        .disabled(validationMessage != nil || isProcessing)
                    }
                }
            }
            .confirmationDialog("Delete this artwork?", isPresented: $showDelete, titleVisibility: .visible) {
                Button("Delete Permanently", role: .destructive) { Task { await delete() } }
            } message: {
                Text("This cannot be undone.")
            }
        }
        .interactiveDismissDisabled(isSaving)
        .onAppear(perform: populate)
        .onChange(of: pickerItems) { _, items in
            Task { await loadPhotos(items) }
        }
    }

    private var photoSection: some View {
        Section {
            if !previews.isEmpty || existing?.thumbnailURL != nil {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AFSpacing.xs) {
                        if previews.isEmpty, let url = existing?.thumbnailURL {
                            CloudImage(url: url, maxPixels: 300, contentMode: .fit)
                                .frame(width: 88, height: 88)
                                .background(Color(uiColor: .secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: AFRadius.sm, style: .continuous))
                        }
                        ForEach(Array(previews.enumerated()), id: \.offset) { _, image in
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 88, height: 88)
                                .background(Color(uiColor: .secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: AFRadius.sm, style: .continuous))
                                .accessibilityLabel("Selected photo")
                        }
                    }
                }
            }
            PhotosPicker(selection: $pickerItems, maxSelectionCount: Self.maxPhotos, matching: .images) {
                HStack {
                    Label(existing == nil ? "Add Photos" : "Replace Photos", systemImage: "photo.badge.plus")
                    if isProcessing {
                        Spacer()
                        ProgressView()
                    }
                }
            }
        } header: {
            Text("Photos")
        } footer: {
            Text("Add up to \(Self.maxPhotos) photos.")
        }
    }

    private func numberField(_ label: String, placeholder: String, text: Binding<String>, keyboard: UIKeyboardType) -> some View {
        LabeledContent(label) {
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .multilineTextAlignment(.trailing)
                .accessibilityLabel(label)
        }
    }

    private func positive(_ text: String) -> Double? {
        guard let value = Double(text.trimmed.replacingOccurrences(of: ",", with: ".")), value.isFinite, value > 0, value < 100_000_000 else { return nil }
        return value
    }

    private func populate() {
        guard let existing, title.isEmpty else { return }
        title = existing.title
        details = existing.details
        medium = existing.medium
        style = existing.style
        status = existing.status
        width = String(existing.dimensions.width)
        height = String(existing.dimensions.height)
        unit = existing.dimensions.unit
        year = String(existing.year)
        priceOnRequest = existing.priceOnRequest
        price = existing.priceOnRequest ? "" : String(existing.price)
        tags = existing.tags.joined(separator: ", ")
    }

    private func loadPhotos(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }
        var output: [ProcessedImage] = []
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = await Task.detached(operation: { try? ImageProcessor.process(data) }).value else {
                errorMessage = AppError.invalidImage.errorDescription
                continue
            }
            output.append(image)
        }
        processed = output
        previews = output.compactMap { UIImage(data: $0.thumbnail) }
    }

    private func save() async {
        guard let parsedWidth, let parsedHeight, let parsedYear,
              priceOnRequest || parsedPrice != nil else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        let parsedTags = Array(tags.split(separator: ",").map { String($0).trimmed.lowercased() }.filter { !$0.isEmpty }.prefix(10))
        let artwork = Artwork(
            id: existing?.id ?? UUID().uuidString,
            artistId: existing?.artistId ?? "",
            artistName: existing?.artistName ?? "",
            title: title.trimmed,
            details: details.trimmed,
            price: priceOnRequest ? 0 : (parsedPrice ?? 0),
            status: status,
            medium: medium,
            style: style,
            dimensions: ArtworkDimensions(width: parsedWidth, height: parsedHeight, unit: unit),
            year: parsedYear,
            tags: parsedTags,
            thumbnailURL: existing?.thumbnailURL,
            createdAt: existing?.createdAt ?? Date(),
            priceOnRequest: priceOnRequest
        )
        do {
            let saved = try await appState.backend.saveArtwork(artwork, images: processed.isEmpty ? nil : processed)
            appState.refreshContent()
            onFinished?(saved)
            dismiss()
        } catch {
            errorMessage = AppState.message(for: error)
        }
    }

    private func delete() async {
        guard let existing else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await appState.backend.deleteArtwork(id: existing.id)
            appState.refreshContent()
            onFinished?(nil)
            dismiss()
        } catch {
            errorMessage = AppState.message(for: error)
        }
    }
}
