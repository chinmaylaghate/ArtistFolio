import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

/// Makes crisp QR code images for artwork links.
enum QRCode {
    /// A black-on-white QR code for `url`, scaled up without smoothing so it prints sharply.
    static func image(for url: URL, pixelSize: CGFloat = 600) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(url.absoluteString.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage, output.extent.width > 0 else { return nil }
        let scale = max(1, (pixelSize / output.extent.width).rounded(.down))
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

/// A printable wall label: what the piece is, its price, and a QR code that opens it in the app.
struct ArtworkLabelCard: View {
    let artwork: Artwork
    let qrImage: UIImage?

    static let width: CGFloat = 400

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(artwork.title)
                    .font(.system(size: 24, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)
                Text(artwork.artistName)
                    .font(.system(size: 17, weight: .medium))
                Text("\(artwork.medium.rawValue) · \(artwork.dimensions.displayString) · \(String(artwork.year))")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(white: 0.37))
            }
            Text(artwork.status == .sold ? "Sold" : artwork.priceText)
                .font(.system(size: 20, weight: .semibold))
            Rectangle().fill(Color(white: 0.85)).frame(height: 1)
            HStack(alignment: .center, spacing: 16) {
                Group {
                    if let qrImage {
                        Image(uiImage: qrImage).interpolation(.none).resizable()
                    } else {
                        Color(white: 0.9)
                    }
                }
                .frame(width: 120, height: 120)
                .accessibilityLabel("QR code linking to this artwork")
                VStack(alignment: .leading, spacing: 4) {
                    Text("Scan to view in ArtistFolio")
                        .font(.system(size: 15, weight: .semibold))
                    Text("See it on your wall in AR and contact the artist.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(white: 0.37))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(AppLink.host)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(white: 0.37))
                        .padding(.top, 2)
                }
            }
        }
        .foregroundStyle(.black)
        .padding(28)
        .frame(width: Self.width, alignment: .leading)
        .background(.white)
        .environment(\.colorScheme, .light)
    }
}

/// Preview of the label with Share and Print, for the artist who owns the piece.
struct QRLabelSheet: View {
    @Environment(\.dismiss) private var dismiss
    let artwork: Artwork
    @State private var qrImage: UIImage?
    @State private var rendered: UIImage?

    private var link: URL { AppLink.artwork(id: artwork.id).url }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AFSpacing.lg) {
                    ArtworkLabelCard(artwork: artwork, qrImage: qrImage)
                        .clipShape(RoundedRectangle(cornerRadius: AFRadius.md, style: .continuous))
                        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
                        .scaleEffect(0.86)

                    Text("Print it and hang it beside the piece at fairs, cafes and open studios. Scanning opens this artwork in ArtistFolio, or the App Store if the app isn't installed.")
                        .font(.footnote)
                        .foregroundStyle(Color.afTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AFSpacing.lg)
                }
                .padding(.vertical, AFSpacing.md)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("QR Label")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .afBottomBar {
                HStack(spacing: AFSpacing.sm) {
                    if let rendered {
                        ShareLink(item: Image(uiImage: rendered), preview: SharePreview("\(artwork.title) label", image: Image(uiImage: rendered))) {
                            Label("Share", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                        }
                        .secondaryAction()
                        Button { print(rendered) } label: {
                            Label("Print", systemImage: "printer").frame(maxWidth: .infinity)
                        }
                        .primaryAction()
                    } else {
                        ProgressView().frame(maxWidth: .infinity, minHeight: 50)
                    }
                }
                .padding(.horizontal, AFSpacing.md)
                .padding(.vertical, AFSpacing.xs)
            }
            .task(id: artwork.id) { render() }
        }
    }

    @MainActor
    private func render() {
        qrImage = QRCode.image(for: link)
        let renderer = ImageRenderer(content: ArtworkLabelCard(artwork: artwork, qrImage: qrImage))
        renderer.scale = 3
        rendered = renderer.uiImage
    }

    private func print(_ image: UIImage) {
        let info = UIPrintInfo.printInfo()
        info.outputType = .general
        info.jobName = "\(artwork.title) label"
        let controller = UIPrintInteractionController.shared
        controller.printInfo = info
        controller.printingItem = image
        controller.present(animated: true)
    }
}
