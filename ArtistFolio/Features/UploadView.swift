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
        if parsedPrice == nil { return "Enter a price above zero." }
        if parsedWidth == nil || parsedHeight == nil { return "Enter width and height." }
        if parsedYear == nil { return "Enter a valid year." }
        return nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AFSpacing.lg) {
                    photoSection
                    FormField(label: "TITLE", placeholder: "Name your artwork", text: $title)
                    TextAreaField(label: "DESCRIPTION", placeholder: "Describe the piece", text: $details)

                    HStack(spacing: AFSpacing.sm) {
                        menu("MEDIUM", selection: $medium, options: ArtworkMedium.allCases, label: \.rawValue)
                        menu("STYLE", selection: $style, options: ArtworkStyle.allCases, label: \.rawValue)
                    }

                    HStack(alignment: .bottom, spacing: AFSpacing.sm) {
                        FormField(label: "WIDTH", placeholder: "60", text: $width, keyboardType: .decimalPad)
                        FormField(label: "HEIGHT", placeholder: "80", text: $height, keyboardType: .decimalPad)
                        Picker("Unit", selection: $unit) {
                            Text("cm").tag("cm")
                            Text("in").tag("in")
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 90, height: 50)
                    }

                    HStack(spacing: AFSpacing.sm) {
                        FormField(label: "PRICE (USD)", placeholder: "1200", text: $price, keyboardType: .decimalPad)
                        FormField(label: "YEAR", placeholder: "2026", text: $year, keyboardType: .numberPad)
                    }

                    FormField(label: "TAGS (COMMA SEPARATED)", placeholder: "ocean, blue, calm", text: $tags, autocapitalize: false)

                    if existing != nil {
                        menu("STATUS", selection: $status, options: ArtworkStatus.allCases, label: \.label)
                    }

                    if let message = errorMessage ?? validationMessage {
                        Text(message)
                            .font(AFFont.bodySmall)
                            .foregroundColor(errorMessage == nil ? .afTextSecondary : .afError)
                    }

                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving { ProgressView().tint(.white) } else { Text(existing == nil ? "Publish Artwork" : "Save Changes") }
                    }
                    .buttonStyle(AFPrimaryButtonStyle())
                    .opacity(validationMessage == nil ? 1 : 0.45)
                    .disabled(validationMessage != nil || isSaving || isProcessing)

                    if existing != nil {
                        Button("Delete Artwork", role: .destructive) { showDelete = true }
                            .font(AFFont.headlineSmall)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                }
                .padding(AFSpacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.afBackground)
            .navigationTitle(existing == nil ? "New Artwork" : "Edit Artwork")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(.afTextSecondary)
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
        VStack(alignment: .leading, spacing: AFSpacing.sm) {
            Text("PHOTOS (UP TO \(Self.maxPhotos))").font(AFFont.sectionHeader).foregroundColor(.afTextSecondary).tracking(0.5)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AFSpacing.sm) {
                    PhotosPicker(selection: $pickerItems, maxSelectionCount: Self.maxPhotos, matching: .images) {
                        VStack(spacing: 4) {
                            if isProcessing { ProgressView() } else { Image(systemName: "plus").font(.system(size: 22, weight: .medium)) }
                            Text(existing == nil ? "Add" : "Replace").font(AFFont.caption)
                        }
                        .foregroundColor(.afTextSecondary)
                        .frame(width: 88, height: 88)
                        .background(Color.afSurface2)
                        .clipShape(RoundedRectangle(cornerRadius: AFRadius.md))
                        .overlay(RoundedRectangle(cornerRadius: AFRadius.md).stroke(Color.afBorder, style: StrokeStyle(lineWidth: 1, dash: [4])))
                    }
                    .accessibilityLabel(existing == nil ? "Add photos" : "Replace photos")

                    if previews.isEmpty, let url = existing?.thumbnailURL {
                        CloudImage(url: url, maxPixels: 300)
                            .frame(width: 88, height: 88)
                            .clipShape(RoundedRectangle(cornerRadius: AFRadius.md))
                    }
                    ForEach(Array(previews.enumerated()), id: \.offset) { _, image in
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 88, height: 88)
                            .clipShape(RoundedRectangle(cornerRadius: AFRadius.md))
                            .accessibilityLabel("Selected photo")
                    }
                }
            }
        }
    }

    private func menu<T: Hashable & Identifiable>(_ title: String, selection: Binding<T>, options: [T], label: KeyPath<T, String>) -> some View {
        VStack(alignment: .leading, spacing: AFSpacing.xs) {
            Text(title).font(AFFont.sectionHeader).foregroundColor(.afTextSecondary).tracking(0.5)
            Menu {
                ForEach(options) { option in
                    Button(option[keyPath: label]) { selection.wrappedValue = option }
                }
            } label: {
                HStack {
                    Text(selection.wrappedValue[keyPath: label]).font(AFFont.bodyMedium).foregroundColor(.afTextPrimary).lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.down").font(.system(size: 12)).foregroundColor(.afTextTertiary)
                }
                .padding(.horizontal, AFSpacing.md)
                .frame(height: 50)
                .background(Color.afSurface2)
                .clipShape(RoundedRectangle(cornerRadius: AFRadius.md))
                .overlay(RoundedRectangle(cornerRadius: AFRadius.md).stroke(Color.afBorder, lineWidth: 1))
            }
            .accessibilityLabel("\(title.capitalized): \(selection.wrappedValue[keyPath: label])")
        }
        .frame(maxWidth: .infinity)
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
        price = String(existing.price)
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
        guard let parsedPrice, let parsedWidth, let parsedHeight, let parsedYear else { return }
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
            price: parsedPrice,
            status: status,
            medium: medium,
            style: style,
            dimensions: ArtworkDimensions(width: parsedWidth, height: parsedHeight, unit: unit),
            year: parsedYear,
            tags: parsedTags,
            thumbnailURL: existing?.thumbnailURL,
            createdAt: existing?.createdAt ?? Date()
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
