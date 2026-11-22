// MARK: - Upload / Artist Studio
import SwiftUI
import PhotosUI

struct UploadView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @StateObject private var vm = UploadViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AFSpacing.lg) {
                    // Image picker
                    ImagePickerSection(images: $vm.selectedImages, photosPickerItems: $vm.photosPickerItems)

                    // Title
                    AFTextField(placeholder: "Artwork title", text: $vm.title, icon: "textformat")

                    // Description
                    TextEditorField(placeholder: "Describe your artwork...", text: $vm.description)

                    // Medium & Style
                    PickerRow(label: "Medium", options: ArtworkMedium.allCases.map { $0.rawValue }, selected: Binding(
                        get: { vm.medium.rawValue },
                        set: { val in vm.medium = ArtworkMedium.allCases.first { $0.rawValue == val } ?? .oilOnCanvas }
                    ))

                    PickerRow(label: "Style", options: ArtworkStyle.allCases.map { $0.rawValue }, selected: Binding(
                        get: { vm.style.rawValue },
                        set: { val in vm.style = ArtworkStyle.allCases.first { $0.rawValue == val } ?? .abstract }
                    ))

                    // Dimensions
                    DimensionsSection(width: $vm.width, height: $vm.height, unit: $vm.unit)

                    // Year
                    AFTextField(placeholder: "Year created", text: $vm.year, icon: "calendar", keyboardType: .numberPad)

                    // Pricing section
                    PricingSection(vm: vm)

                    // Shipping
                    ShippingSection(includeShipping: $vm.includesShipping, shippingPrice: $vm.shippingPrice)

                    // Certificate
                    CertificateToggle(isEnabled: $vm.addCertificate)

                    // Upload button
                    Button {
                        Task { await vm.upload() }
                    } label: {
                        ZStack {
                            if vm.isUploading {
                                HStack(spacing: AFSpacing.sm) {
                                    ProgressView().tint(Color.afPrimary)
                                    Text("Uploading...")
                                        .font(AFFont.headlineMedium)
                                        .foregroundColor(Color.afPrimary)
                                }
                            } else {
                                Text("List Artwork · $\(vm.price.isEmpty ? "0" : vm.price)")
                                    .font(AFFont.headlineMedium)
                                    .foregroundColor(Color.afPrimary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(vm.canUpload ? AFGradient.primaryGold : LinearGradient(colors: [Color.afBorder], startPoint: .leading, endPoint: .trailing))
                        .clipShape(RoundedRectangle(cornerRadius: AFRadius.full))
                    }
                    .disabled(!vm.canUpload || vm.isUploading)

                    if let error = vm.errorMessage {
                        Text(error).font(AFFont.caption).foregroundColor(.afError)
                    }

                    if vm.uploadSuccess {
                        VStack(spacing: AFSpacing.sm) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.afSuccess)
                            Text("Artwork listed successfully!")
                                .font(AFFont.headlineSmall)
                                .foregroundColor(.afTextPrimary)
                        }
                        .padding()
                    }
                }
                .padding(.horizontal, AFSpacing.md)
                .padding(.bottom, AFSpacing.xxxl)
            }
            .background(Color.afBackground)
            .navigationTitle("List Artwork")
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

// MARK: - Image Picker

struct ImagePickerSection: View {
    @Binding var images: [UIImage]
    @Binding var photosPickerItems: [PhotosPickerItem]

    var body: some View {
        VStack(alignment: .leading, spacing: AFSpacing.sm) {
            Text("Photos (up to 8)")
                .font(AFFont.headlineSmall)
                .foregroundColor(.afTextPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AFSpacing.sm) {
                    // Add button
                    PhotosPicker(selection: $photosPickerItems, maxSelectionCount: 8, matching: .images) {
                        ZStack {
                            RoundedRectangle(cornerRadius: AFRadius.md)
                                .fill(Color.afSurface)
                                .frame(width: 88, height: 88)
                                .overlay(
                                    RoundedRectangle(cornerRadius: AFRadius.md)
                                        .stroke(Color.afBorder, style: StrokeStyle(lineWidth: 1, dash: [4]))
                                )

                            VStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.system(size: 22, weight: .medium))
                                Text("Add")
                                    .font(AFFont.caption)
                            }
                            .foregroundColor(.afTextTertiary)
                        }
                    }

                    // Selected images
                    ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 88, height: 88)
                                .clipShape(RoundedRectangle(cornerRadius: AFRadius.md))

                            Button {
                                images.remove(at: index)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.white)
                                    .shadow(radius: 2)
                            }
                            .offset(x: 6, y: -6)
                        }
                    }
                }
            }
        }
        .onChange(of: photosPickerItems) { _, items in
            Task {
                var loaded: [UIImage] = []
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        loaded.append(image)
                    }
                }
                images = loaded
            }
        }
    }
}

// MARK: - Pricing Section with AI

struct PricingSection: View {
    @ObservedObject var vm: UploadViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: AFSpacing.sm) {
            HStack {
                Text("Pricing")
                    .font(AFFont.headlineSmall)
                    .foregroundColor(.afTextPrimary)

                Spacer()

                // AI Pricing button
                if Config.aiPricingEnabled {
                    Button {
                        Task { await vm.getAIPricingSuggestion() }
                    } label: {
                        HStack(spacing: 4) {
                            if vm.isLoadingAIPrice {
                                ProgressView().tint(Color.afPrimary).scaleEffect(0.7)
                            } else {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 12))
                            }
                            Text("AI Suggest")
                                .font(AFFont.captionBold)
                        }
                        .foregroundColor(Color.afPrimary)
                        .padding(.horizontal, AFSpacing.sm)
                        .padding(.vertical, 6)
                        .background(Color.afAccent)
                        .clipShape(Capsule())
                    }
                    .disabled(vm.isLoadingAIPrice)
                }
            }

            AFTextField(placeholder: "Price in USD", text: $vm.price, icon: "dollarsign", keyboardType: .decimalPad)

            // AI suggestion card
            if let suggestion = vm.pricingSuggestion {
                AIPricingCard(suggestion: suggestion) { price in
                    vm.price = String(Int(price))
                }
            }
        }
    }
}

struct AIPricingCard: View {
    let suggestion: PricingSuggestion
    let onAccept: (Double) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AFSpacing.sm) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.afAccent)
                Text("AI Pricing Insight")
                    .font(AFFont.captionBold)
                    .foregroundColor(.afAccent)
                Spacer()
                Text("\(Int(suggestion.confidence * 100))% confidence")
                    .font(AFFont.caption)
                    .foregroundColor(.afTextTertiary)
            }

            HStack(spacing: AFSpacing.lg) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Range")
                        .font(AFFont.caption)
                        .foregroundColor(.afTextTertiary)
                    Text("$\(Int(suggestion.suggestedMinPrice)) – $\(Int(suggestion.suggestedMaxPrice))")
                        .font(AFFont.headlineSmall)
                        .foregroundColor(.afTextPrimary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Recommended")
                        .font(AFFont.caption)
                        .foregroundColor(.afTextTertiary)
                    Text("$\(Int(suggestion.recommendedPrice))")
                        .font(AFFont.headlineSmall)
                        .foregroundStyle(AFGradient.primaryGold)
                }

                Spacer()

                Button {
                    onAccept(suggestion.recommendedPrice)
                } label: {
                    Text("Use")
                        .font(AFFont.captionBold)
                        .foregroundColor(Color.afPrimary)
                        .padding(.horizontal, AFSpacing.md)
                        .padding(.vertical, 6)
                        .background(Color.afAccent)
                        .clipShape(Capsule())
                }
            }

            // Factors
            ForEach(suggestion.factors.prefix(3)) { factor in
                HStack(spacing: AFSpacing.xs) {
                    Image(systemName: factor.impact == "positive" ? "arrow.up" : factor.impact == "negative" ? "arrow.down" : "minus")
                        .font(.system(size: 10))
                        .foregroundColor(factor.impact == "positive" ? .afSuccess : factor.impact == "negative" ? .afError : .afTextTertiary)
                    Text(factor.description)
                        .font(AFFont.caption)
                        .foregroundColor(.afTextSecondary)
                }
            }
        }
        .padding(AFSpacing.md)
        .background(Color.afAccent.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: AFRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: AFRadius.md)
                .stroke(Color.afAccent.opacity(0.25), lineWidth: 1)
        )
    }
}

// MARK: - Supporting Views

struct DimensionsSection: View {
    @Binding var width: String
    @Binding var height: String
    @Binding var unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: AFSpacing.xs) {
            Text("Dimensions")
                .font(AFFont.headlineSmall)
                .foregroundColor(.afTextPrimary)

            HStack(spacing: AFSpacing.sm) {
                AFTextField(placeholder: "Width", text: $width, icon: "arrow.left.and.right", keyboardType: .decimalPad)
                AFTextField(placeholder: "Height", text: $height, icon: "arrow.up.and.down", keyboardType: .decimalPad)

                Picker("Unit", selection: $unit) {
                    Text("cm").tag("cm")
                    Text("in").tag("in")
                }
                .pickerStyle(.segmented)
                .frame(width: 80)
            }
        }
    }
}

struct PickerRow: View {
    let label: String
    let options: [String]
    @Binding var selected: String

    var body: some View {
        VStack(alignment: .leading, spacing: AFSpacing.xs) {
            Text(label)
                .font(AFFont.headlineSmall)
                .foregroundColor(.afTextPrimary)

            Menu {
                ForEach(options, id: \.self) { option in
                    Button(option) { selected = option }
                }
            } label: {
                HStack {
                    Text(selected.isEmpty ? "Select \(label)" : selected)
                        .font(AFFont.bodyMedium)
                        .foregroundColor(selected.isEmpty ? .afTextTertiary : .afTextPrimary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(.afTextTertiary)
                }
                .padding(.horizontal, AFSpacing.md)
                .frame(height: 52)
                .background(Color.afSurface)
                .clipShape(RoundedRectangle(cornerRadius: AFRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: AFRadius.md)
                        .stroke(Color.afBorder, lineWidth: 1)
                )
            }
        }
    }
}

struct ShippingSection: View {
    @Binding var includeShipping: Bool
    @Binding var shippingPrice: String

    var body: some View {
        VStack(alignment: .leading, spacing: AFSpacing.sm) {
            Toggle(isOn: $includeShipping) {
                Text("Offer Shipping")
                    .font(AFFont.headlineSmall)
                    .foregroundColor(.afTextPrimary)
            }
            .tint(Color.afAccent)

            if includeShipping {
                AFTextField(placeholder: "Shipping price (USD)", text: $shippingPrice, icon: "shippingbox", keyboardType: .decimalPad)
            }
        }
    }
}

struct CertificateToggle: View {
    @Binding var isEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AFSpacing.xs) {
            Toggle(isOn: $isEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("Add Certificate of Authenticity")
                            .font(AFFont.headlineSmall)
                            .foregroundColor(.afTextPrimary)
                        Text("$19")
                            .font(AFFont.captionBold)
                            .foregroundColor(.afAccent)
                    }
                    Text("Blockchain verified + physical NFC tag")
                        .font(AFFont.caption)
                        .foregroundColor(.afTextSecondary)
                }
            }
            .tint(Color.afAccent)
        }
    }
}

// MARK: - Upload ViewModel

@MainActor
final class UploadViewModel: ObservableObject {
    @Published var selectedImages: [UIImage] = []
    @Published var photosPickerItems: [PhotosPickerItem] = []
    @Published var title: String = ""
    @Published var description: String = ""
    @Published var medium: ArtworkMedium = .oilOnCanvas
    @Published var style: ArtworkStyle = .abstract
    @Published var width: String = ""
    @Published var height: String = ""
    @Published var unit: String = "cm"
    @Published var year: String = String(Calendar.current.component(.year, from: Date()))
    @Published var price: String = ""
    @Published var includesShipping: Bool = true
    @Published var shippingPrice: String = ""
    @Published var addCertificate: Bool = false
    @Published var pricingSuggestion: PricingSuggestion?
    @Published var isLoadingAIPrice: Bool = false
    @Published var isUploading: Bool = false
    @Published var uploadSuccess: Bool = false
    @Published var errorMessage: String?

    private let artworkService = ArtworkService()
    private let certService = CertificateService()

    var canUpload: Bool {
        !selectedImages.isEmpty && !title.isEmpty && !price.isEmpty && !width.isEmpty && !height.isEmpty
    }

    func getAIPricingSuggestion() async {
        guard !width.isEmpty, !height.isEmpty else { return }
        isLoadingAIPrice = true
        do {
            let dims = ArtworkDimensions(width: Double(width) ?? 60, height: Double(height) ?? 80, unit: unit)
            pricingSuggestion = try await artworkService.getAIPricingSuggestion(
                medium: medium, style: style, dimensions: dims, year: Int(year) ?? 2024
            )
        } catch {
            errorMessage = "Could not get AI suggestion. Please try again."
        }
        isLoadingAIPrice = false
    }

    func upload() async {
        isUploading = true
        errorMessage = nil
        do {
            let imageDatas = selectedImages.compactMap { $0.jpegData(compressionQuality: 0.85) }
            let artwork = Artwork(
                id: UUID().uuidString, artistId: "current_user", artistName: "Me",
                title: title, description: description, imageURLs: [],
                price: Double(price) ?? 0, originalPrice: nil, status: .available,
                medium: medium, style: style,
                dimensions: ArtworkDimensions(width: Double(width) ?? 0, height: Double(height) ?? 0, unit: unit),
                year: Int(year) ?? 2024, tags: [], colorPalette: [],
                likesCount: 0, viewsCount: 0, isLiked: false,
                hasCertificate: addCertificate, certificateHash: nil,
                shippingOptions: [], createdAt: Date(), updatedAt: Date()
            )
            _ = try await artworkService.uploadArtwork(artwork, images: imageDatas)
            uploadSuccess = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isUploading = false
    }
}

#Preview {
    UploadView()
        .environmentObject(AppState())
}
