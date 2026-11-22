// MARK: - First-Time Setup Flow
// Shown once after account creation, before MainTabView.
// Artist: 4 steps — Studio Profile → First Listing → Delivery → Commissions
// Collector: 4 steps — Art Taste → Commission an Artist → Payment → All Set
import SwiftUI

// MARK: - Setup Step Progress Bar

private struct SetupProgressBar: View {
    let current: Int   // 1-based
    let total: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(1...total, id: \.self) { step in
                ZStack {
                    Circle()
                        .fill(step <= current ? Color.afPrimary : Color.afSurface2)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Circle().stroke(step <= current ? Color.afPrimary : Color.afBorder, lineWidth: 1.5)
                        )
                    Text("\(step)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(step <= current ? .white : .afTextTertiary)
                }
                if step < total {
                    Rectangle()
                        .fill(step < current ? Color.afPrimary : Color.afBorder)
                        .frame(height: 2)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, AFSpacing.xl)
        .padding(.vertical, AFSpacing.md)
    }
}

// MARK: - Setup Section Header

private struct SetupSectionHeader: View {
    let icon: String
    let iconColor: Color
    let title: String

    var body: some View {
        HStack(spacing: AFSpacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: AFRadius.sm)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(iconColor)
            }
            Text(title)
                .font(AFFont.headlineLarge)
                .foregroundColor(.afTextPrimary)
        }
    }
}

// MARK: - Setup Bottom Controls

private struct SetupBottomControls: View {
    let primaryLabel: String
    let onPrimary: () -> Void
    let onSkip: (() -> Void)?
    var primaryEnabled: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onPrimary) {
                Text(primaryLabel)
                    .font(AFFont.headlineLarge)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(primaryEnabled ? Color.afPrimary : Color.afTextTertiary)
                    .clipShape(Capsule())
            }
            .disabled(!primaryEnabled)

            if let onSkip {
                Button(action: onSkip) {
                    Text("Skip for now")
                        .font(AFFont.bodyMedium)
                        .foregroundColor(.afTextSecondary)
                        .frame(height: 44)
                }
            }
        }
        .padding(.horizontal, AFSpacing.xl)
        .padding(.bottom, AFSpacing.xxxl)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Style Tag Pill

private struct StyleTagPill: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(AFFont.bodyMedium)
                .foregroundColor(isSelected ? Color.afPrimary : .afTextSecondary)
                .padding(.horizontal, AFSpacing.md)
                .padding(.vertical, AFSpacing.xs)
                .background(isSelected ? Color.afPrimaryBg : Color.afSurface2)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(isSelected ? Color.afPrimary : Color.afBorder, lineWidth: 1))
        }
    }
}

// MARK: - Shipping Option Row

private struct ShippingOptionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AFSpacing.md) {
                Text(icon)
                    .font(.system(size: 26))
                    .frame(width: 44, height: 44)
                    .background(Color.afSurface2)
                    .clipShape(RoundedRectangle(cornerRadius: AFRadius.sm))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(AFFont.headlineSmall).foregroundColor(.afTextPrimary)
                    Text(subtitle).font(AFFont.bodySmall).foregroundColor(.afTextSecondary)
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.afPrimary : Color.afBorder, lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle().fill(Color.afPrimary).frame(width: 12, height: 12)
                    }
                }
            }
            .padding(AFSpacing.md)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: AFRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: AFRadius.lg)
                    .stroke(isSelected ? Color.afPrimary : Color.afBorder, lineWidth: 1.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Artist Commission Artist Row (for Collector step 2)

private struct CommissionArtistRow: View {
    let name: String
    let location: String
    let styles: String
    let rating: String
    let startingPrice: String

    var body: some View {
        HStack(spacing: AFSpacing.md) {
            ZStack {
                Circle().fill(Color.afPrimaryBg).frame(width: 52, height: 52)
                Image(systemName: "person.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.afPrimary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(AFFont.headlineSmall).foregroundColor(.afTextPrimary)
                HStack(spacing: 4) {
                    Image(systemName: "mappin.fill").font(.system(size: 10)).foregroundColor(.afError)
                    Text(location).font(AFFont.bodySmall).foregroundColor(.afTextSecondary)
                }
                Text(styles).font(AFFont.bodySmall).foregroundColor(.afTextSecondary)
                HStack(spacing: 2) {
                    Text("⭐").font(.system(size: 11))
                    Text(rating).font(AFFont.captionBold).foregroundColor(.afTextPrimary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Button {
                } label: {
                    Text("Request →")
                        .font(AFFont.captionBold)
                        .foregroundColor(.afPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.afPrimaryBg)
                        .clipShape(Capsule())
                }
                Text("From \(startingPrice)")
                    .font(AFFont.captionBold)
                    .foregroundColor(.afPrimary)
            }
        }
        .padding(AFSpacing.md)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: AFRadius.lg))
        .overlay(RoundedRectangle(cornerRadius: AFRadius.lg).stroke(Color.afBorder, lineWidth: 1))
    }
}

// MARK: - ════════════════════════════════════
// MARK:   ARTIST SETUP FLOW
// MARK: ════════════════════════════════════

struct ArtistSetupFlow: View {
    @EnvironmentObject var appState: AppState
    @State private var step = 1
    let totalSteps = 4

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Spacer()
                LogoSmall()
                Spacer()
            }
            .padding(.horizontal, AFSpacing.xl)
            .padding(.top, AFSpacing.md)
            .padding(.bottom, AFSpacing.xs)
            .background(Color.white)

            SetupProgressBar(current: step, total: totalSteps)
                .background(Color.white)
                .overlay(Divider(), alignment: .bottom)

            // Step Content
            Group {
                switch step {
                case 1: ArtistStep1StudioProfile(onNext: { step = 2 })
                case 2: ArtistStep2FirstListing(onNext: { step = 3 }, onSkip: { step = 3 })
                case 3: ArtistStep3Delivery(onNext: { step = 4 }, onSkip: { step = 4 })
                case 4: ArtistStep4Commissions(onDone: { appState.completeFirstTimeSetup() })
                default: EmptyView()
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
            .animation(.easeInOut(duration: 0.28), value: step)
        }
        .background(Color(hex: "#F4F6FB").ignoresSafeArea())
    }
}

// MARK: Artist Step 1 — Set Up Your Studio

private struct ArtistStep1StudioProfile: View {
    let onNext: () -> Void
    @State private var displayName = ""
    @State private var bio = ""
    @State private var location = ""
    @State private var mediums: Set<String> = []

    private let allMediums = ["Oil", "Acrylic", "Watercolour", "Gouache", "Pastel",
                               "Mixed Media", "Digital", "Charcoal", "Ink", "Encaustic"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AFSpacing.xl) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Set Up Your Studio")
                        .font(AFFont.displayMedium).foregroundColor(.afTextPrimary)
                    Text("Tell collectors who you are and what you create")
                        .font(AFFont.bodyMedium).foregroundColor(.afTextSecondary)
                }

                // Profile photo placeholder
                HStack {
                    Spacer()
                    ZStack {
                        Circle().fill(Color.afPrimaryBg).frame(width: 88, height: 88)
                        Image(systemName: "camera.fill")
                            .font(.system(size: 28)).foregroundColor(.afPrimary)
                    }
                    .overlay(
                        Circle()
                            .fill(Color.afPrimary)
                            .frame(width: 26, height: 26)
                            .overlay(Image(systemName: "plus").font(.system(size: 12, weight: .bold)).foregroundColor(.white))
                        , alignment: .bottomTrailing
                    )
                    Spacer()
                }

                VStack(spacing: AFSpacing.md) {
                    FormField(label: "DISPLAY NAME", placeholder: "Your artist name", text: $displayName)
                    FormField(label: "LOCATION", placeholder: "City, Country", text: $location)

                    VStack(alignment: .leading, spacing: AFSpacing.xs) {
                        Text("BIO").font(AFFont.sectionHeader).foregroundColor(.afTextSecondary).tracking(0.5)
                        ZStack(alignment: .topLeading) {
                            if bio.isEmpty {
                                Text("Tell collectors about your style and process…")
                                    .font(AFFont.bodyMedium)
                                    .foregroundColor(.afTextTertiary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                            }
                            TextEditor(text: $bio)
                                .font(AFFont.bodyMedium)
                                .frame(minHeight: 90)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .scrollContentBackground(.hidden)
                        }
                        .background(Color.afSurface2)
                        .clipShape(RoundedRectangle(cornerRadius: AFRadius.md))
                        .overlay(RoundedRectangle(cornerRadius: AFRadius.md).stroke(Color.afBorder, lineWidth: 1))
                    }
                }

                // Medium tags
                VStack(alignment: .leading, spacing: AFSpacing.sm) {
                    SetupSectionHeader(icon: "paintbrush.fill", iconColor: .afPrimary, title: "Your Mediums")
                    Text("Select all that apply").font(AFFont.bodySmall).foregroundColor(.afTextSecondary)
                    FlowLayout(spacing: 8) {
                        ForEach(allMediums, id: \.self) { m in
                            StyleTagPill(label: m, isSelected: mediums.contains(m)) {
                                if mediums.contains(m) { mediums.remove(m) }
                                else { mediums.insert(m) }
                            }
                        }
                    }
                }
            }
            .padding(AFSpacing.xl)
            .padding(.bottom, 120)
        }

        SetupBottomControls(
            primaryLabel: "Save & Continue",
            onPrimary: onNext,
            onSkip: nil,
            primaryEnabled: !displayName.isEmpty
        )
    }
}

// MARK: Artist Step 2 — Add First Listing

private struct ArtistStep2FirstListing: View {
    let onNext: () -> Void
    let onSkip: () -> Void
    @State private var title = ""
    @State private var price = ""
    @State private var width = ""
    @State private var height = ""
    @State private var year = ""
    @State private var medium = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AFSpacing.xl) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("New Listing")
                        .font(AFFont.displayMedium).foregroundColor(.afTextPrimary)
                    Text("Showcase your first artwork to collectors")
                        .font(AFFont.bodyMedium).foregroundColor(.afTextSecondary)
                }

                // Photo upload area
                VStack(spacing: AFSpacing.md) {
                    SetupSectionHeader(icon: "photo.on.rectangle", iconColor: .afPrimary, title: "Photos")
                    Text("Add up to 5 high-quality photos")
                        .font(AFFont.bodySmall).foregroundColor(.afTextSecondary)

                    RoundedRectangle(cornerRadius: AFRadius.lg)
                        .stroke(Color.afPrimary.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                        .frame(height: 180)
                        .overlay(
                            VStack(spacing: AFSpacing.sm) {
                                ZStack {
                                    Circle().fill(Color.afPrimaryBg).frame(width: 56, height: 56)
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 22)).foregroundColor(.afPrimary)
                                }
                                Text("Add Photos")
                                    .font(AFFont.headlineSmall).foregroundColor(.afTextPrimary)
                                Text("High quality photos help sell your art")
                                    .font(AFFont.bodySmall).foregroundColor(.afTextSecondary)
                            }
                        )
                }
                .padding(AFSpacing.lg)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: AFRadius.xl))
                .afCardShadow()

                // Basic Info
                VStack(alignment: .leading, spacing: AFSpacing.md) {
                    SetupSectionHeader(icon: "pencil", iconColor: .afPrimary, title: "Basic Info")

                    FormField(label: "TITLE *", placeholder: "Name your painting", text: $title)

                    VStack(alignment: .leading, spacing: AFSpacing.xs) {
                        Text("PRICE (USD) *").font(AFFont.sectionHeader).foregroundColor(.afTextSecondary).tracking(0.5)
                        HStack {
                            Text("$").font(AFFont.bodyLarge).foregroundColor(.afTextSecondary).padding(.leading, 14)
                            TextField("0.00", text: $price).font(AFFont.bodyLarge).keyboardType(.decimalPad)
                        }
                        .frame(height: 50)
                        .background(Color.afSurface2)
                        .clipShape(RoundedRectangle(cornerRadius: AFRadius.md))
                        .overlay(RoundedRectangle(cornerRadius: AFRadius.md).stroke(Color.afBorder, lineWidth: 1))
                    }

                    VStack(alignment: .leading, spacing: AFSpacing.xs) {
                        Text("DIMENSIONS (CM)").font(AFFont.sectionHeader).foregroundColor(.afTextSecondary).tracking(0.5)
                        HStack(spacing: AFSpacing.sm) {
                            TextField("Width", text: $width).font(AFFont.bodyLarge).keyboardType(.decimalPad)
                                .padding(.horizontal, AFSpacing.md).frame(height: 50)
                                .background(Color.afSurface2)
                                .clipShape(RoundedRectangle(cornerRadius: AFRadius.md))
                                .overlay(RoundedRectangle(cornerRadius: AFRadius.md).stroke(Color.afBorder, lineWidth: 1))
                            TextField("Height", text: $height).font(AFFont.bodyLarge).keyboardType(.decimalPad)
                                .padding(.horizontal, AFSpacing.md).frame(height: 50)
                                .background(Color.afSurface2)
                                .clipShape(RoundedRectangle(cornerRadius: AFRadius.md))
                                .overlay(RoundedRectangle(cornerRadius: AFRadius.md).stroke(Color.afBorder, lineWidth: 1))
                        }
                    }

                    FormField(label: "YEAR CREATED", placeholder: "e.g. 2024", text: $year, keyboardType: .numberPad)
                    FormField(label: "MEDIUM", placeholder: "e.g. Oil on Canvas", text: $medium)
                }
                .padding(AFSpacing.lg)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: AFRadius.xl))
                .afCardShadow()
            }
            .padding(AFSpacing.xl)
            .padding(.bottom, 120)
        }

        SetupBottomControls(
            primaryLabel: "Save & Continue",
            onPrimary: onNext,
            onSkip: onSkip,
            primaryEnabled: !title.isEmpty && !price.isEmpty
        )
    }
}

// MARK: Artist Step 3 — Set Up Delivery

private struct ArtistStep3Delivery: View {
    let onNext: () -> Void
    let onSkip: () -> Void
    @State private var selectedMethod: String = "rolled"

    private let methods: [(id: String, icon: String, title: String, subtitle: String)] = [
        ("rolled",  "📦", "Rolled Canvas",      "Unframed, shipped in a protective tube"),
        ("framed",  "🖼️", "Framed & Boxed",     "Protective crating for framed artwork"),
        ("courier", "🚚", "Courier Collection", "Buyer arranges their own courier"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AFSpacing.xl) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Set Up Delivery")
                        .font(AFFont.displayMedium).foregroundColor(.afTextPrimary)
                    Text("Tell buyers how you ship your paintings")
                        .font(AFFont.bodyMedium).foregroundColor(.afTextSecondary)
                }

                Text("How do you ship?")
                    .font(AFFont.headlineLarge).foregroundColor(.afTextPrimary)

                VStack(spacing: AFSpacing.sm) {
                    ForEach(methods, id: \.id) { m in
                        ShippingOptionRow(
                            icon: m.icon, title: m.title, subtitle: m.subtitle,
                            isSelected: selectedMethod == m.id
                        ) { selectedMethod = m.id }
                    }
                }

                VStack(spacing: 6) {
                    HStack(spacing: AFSpacing.sm) {
                        Text("📅").font(.system(size: 15))
                        Text("Dispatch usually within 5–7 business days")
                            .font(AFFont.bodySmall).foregroundColor(.afTextSecondary)
                    }
                    HStack(spacing: AFSpacing.sm) {
                        Text("🌍").font(.system(size: 15))
                        Text("Worldwide shipping supported via integrated carriers")
                            .font(AFFont.bodySmall).foregroundColor(.afTextSecondary)
                    }
                }
                .padding(AFSpacing.md)
                .background(Color.afSurface2)
                .clipShape(RoundedRectangle(cornerRadius: AFRadius.md))

                Button {
                } label: {
                    Text("+ Add More Details")
                        .font(AFFont.headlineSmall).foregroundColor(.afPrimary)
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .background(Color.afPrimaryBg)
                        .clipShape(RoundedRectangle(cornerRadius: AFRadius.lg))
                }
            }
            .padding(AFSpacing.xl)
            .padding(.bottom, 120)
        }

        SetupBottomControls(
            primaryLabel: "Save & Continue",
            onPrimary: onNext,
            onSkip: onSkip
        )
    }
}

// MARK: Artist Step 4 — Commissions

private struct ArtistStep4Commissions: View {
    let onDone: () -> Void
    @State private var acceptCommissions = true
    @State private var minBudget = "300"
    @State private var turnaround = "4–6 weeks"
    @State private var deposit = "50%"
    @State private var selectedStyles: Set<String> = ["Oil", "Abstract"]
    @State private var showSuccess = false

    private let styles = ["Abstract", "Botanical", "Landscape", "Expressionism",
                           "Minimalist", "Seascape", "Portrait", "Geometric",
                           "Spiritual", "Still Life", "Contemporary", "Surrealism"]

    var body: some View {
        if showSuccess {
            ArtistSetupSuccess(onDone: onDone)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: AFSpacing.xl) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Commissions")
                            .font(AFFont.displayMedium).foregroundColor(.afTextPrimary)
                        Text("Let collectors request custom paintings")
                            .font(AFFont.bodyMedium).foregroundColor(.afTextSecondary)
                    }

                    // Accept toggle card
                    HStack(spacing: AFSpacing.md) {
                        Text("🎨").font(.system(size: 20))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Accept commissioned work").font(AFFont.headlineSmall).foregroundColor(.afTextPrimary)
                            Text("Collectors can request bespoke paintings from you")
                                .font(AFFont.bodySmall).foregroundColor(.afTextSecondary)
                        }
                        Spacer()
                        Toggle("", isOn: $acceptCommissions).labelsHidden().tint(.afPrimary)
                    }
                    .padding(AFSpacing.md)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: AFRadius.lg))
                    .overlay(RoundedRectangle(cornerRadius: AFRadius.lg).stroke(Color.afBorder, lineWidth: 1))

                    if acceptCommissions {
                        VStack(alignment: .leading, spacing: AFSpacing.md) {
                            Text("Your Commission Terms")
                                .font(AFFont.headlineLarge).foregroundColor(.afTextPrimary)

                            HStack(spacing: AFSpacing.sm) {
                                CommissionTermCard(label: "Min. Budget", value: "$\(minBudget) USD") {
                                    VStack(alignment: .leading, spacing: AFSpacing.xs) {
                                        Text("MIN. BUDGET (USD)").font(AFFont.sectionHeader).foregroundColor(.afTextSecondary).tracking(0.5)
                                        HStack {
                                            Text("$").font(AFFont.bodyLarge).foregroundColor(.afTextSecondary).padding(.leading, 14)
                                            TextField("300", text: $minBudget).font(AFFont.bodyLarge).keyboardType(.numberPad)
                                        }
                                        .frame(height: 50)
                                        .background(Color.afSurface2)
                                        .clipShape(RoundedRectangle(cornerRadius: AFRadius.md))
                                        .overlay(RoundedRectangle(cornerRadius: AFRadius.md).stroke(Color.afBorder, lineWidth: 1))
                                    }
                                }
                                CommissionTermCard(label: "Avg. Turnaround", value: turnaround) {
                                    FormField(label: "AVG. TURNAROUND", placeholder: "e.g. 4–6 weeks", text: $turnaround)
                                }
                            }

                            CommissionTermCard(label: "Deposit Required", value: "\(deposit) upfront") {
                                FormField(label: "DEPOSIT REQUIRED", placeholder: "e.g. 50%", text: $deposit)
                            }
                        }

                        // Style tags
                        VStack(alignment: .leading, spacing: AFSpacing.sm) {
                            Text("Style").font(AFFont.headlineLarge).foregroundColor(.afTextPrimary)
                            Text("Select all that apply").font(AFFont.bodySmall).foregroundColor(.afTextSecondary)
                            FlowLayout(spacing: 8) {
                                ForEach(styles, id: \.self) { s in
                                    StyleTagPill(label: s, isSelected: selectedStyles.contains(s)) {
                                        if selectedStyles.contains(s) { selectedStyles.remove(s) }
                                        else { selectedStyles.insert(s) }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(AFSpacing.xl)
                .padding(.bottom, 120)
            }
            .animation(.easeInOut(duration: 0.2), value: acceptCommissions)

            SetupBottomControls(
                primaryLabel: "Finish Setup",
                onPrimary: { withAnimation { showSuccess = true } },
                onSkip: { withAnimation { showSuccess = true } }
            )
        }
    }
}

// Helper: commission term expandable card
private struct CommissionTermCard<Editor: View>: View {
    let label: String
    let value: String
    @ViewBuilder let editor: () -> Editor
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: AFSpacing.sm) {
            Button { withAnimation { expanded.toggle() } } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label).font(AFFont.bodySmall).foregroundColor(.afTextSecondary)
                    Text(value).font(AFFont.headlineSmall).foregroundColor(.afTextPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AFSpacing.md)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: AFRadius.lg))
                .overlay(RoundedRectangle(cornerRadius: AFRadius.lg).stroke(Color.afBorder, lineWidth: 1))
            }
            .buttonStyle(PlainButtonStyle())

            if expanded { editor().padding(.horizontal, 4) }
        }
    }
}

// MARK: Artist Setup Success

private struct ArtistSetupSuccess: View {
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: AFSpacing.xl) {
            Spacer()

            ZStack {
                Circle().fill(Color.afSuccessBg).frame(width: 96, height: 96)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 44)).foregroundColor(.afSuccess)
            }

            VStack(spacing: AFSpacing.sm) {
                Text("Your studio is live\non ArtistFolio")
                    .font(AFFont.displaySmall).foregroundColor(.afTextPrimary)
                    .multilineTextAlignment(.center).lineSpacing(4)
                Text("You're ready to reach collectors worldwide.\nAdd more artworks anytime from your Studio tab.")
                    .font(AFFont.bodyMedium).foregroundColor(.afTextSecondary)
                    .multilineTextAlignment(.center).lineSpacing(4)
            }

            VStack(spacing: AFSpacing.md) {
                successFeature(icon: "photo.stack.fill",   color: .afPrimary,  title: "List Artworks",       sub: "Upload and manage your art anytime")
                successFeature(icon: "message.fill",        color: .afSuccess,  title: "Chat with Buyers",    sub: "Built-in messaging, no middlemen")
                successFeature(icon: "paintpalette.fill",   color: .afWarning,  title: "Take Commissions",    sub: "Collectors can request custom work")
                successFeature(icon: "chart.line.uptrend.xyaxis", color: .afInfo, title: "Track Your Sales", sub: "Real-time earnings dashboard")
            }
            .padding(AFSpacing.lg)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: AFRadius.xl))
            .afCardShadow()

            Spacer()

            Button(action: onDone) {
                Text("Start Selling")
                    .font(AFFont.headlineLarge).foregroundColor(.white)
                    .frame(maxWidth: .infinity).frame(height: 54)
                    .background(Color.afPrimary).clipShape(Capsule())
            }
            .padding(.horizontal, AFSpacing.xl)
            .padding(.bottom, AFSpacing.xxxl)
        }
        .padding(.horizontal, AFSpacing.xl)
        .background(Color(hex: "#F4F6FB").ignoresSafeArea())
    }

    @ViewBuilder
    private func successFeature(icon: String, color: Color, title: String, sub: String) -> some View {
        HStack(spacing: AFSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: AFRadius.sm).fill(color.opacity(0.1)).frame(width: 40, height: 40)
                Image(systemName: icon).font(.system(size: 18)).foregroundColor(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(AFFont.headlineSmall).foregroundColor(.afTextPrimary)
                Text(sub).font(AFFont.bodySmall).foregroundColor(.afTextSecondary)
            }
            Spacer()
        }
    }
}

// MARK: - ════════════════════════════════════
// MARK:   COLLECTOR SETUP FLOW
// MARK: ════════════════════════════════════

struct CollectorSetupFlow: View {
    @EnvironmentObject var appState: AppState
    @State private var step = 1
    let totalSteps = 4

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                LogoSmall()
                Spacer()
            }
            .padding(.horizontal, AFSpacing.xl)
            .padding(.top, AFSpacing.md)
            .padding(.bottom, AFSpacing.xs)
            .background(Color.white)

            SetupProgressBar(current: step, total: totalSteps)
                .background(Color.white)
                .overlay(Divider(), alignment: .bottom)

            Group {
                switch step {
                case 1: CollectorStep1Taste(onNext: { step = 2 }, onSkip: { step = 2 })
                case 2: CollectorStep2Commission(onNext: { step = 3 }, onSkip: { step = 3 })
                case 3: CollectorStep3Payment(onNext: { step = 4 }, onSkip: { step = 4 })
                case 4: CollectorStep4AllSet(onDone: { appState.completeFirstTimeSetup() })
                default: EmptyView()
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
            .animation(.easeInOut(duration: 0.28), value: step)
        }
        .background(Color(hex: "#F4F6FB").ignoresSafeArea())
    }
}

// MARK: Collector Step 1 — Discover Your Taste

private struct CollectorStep1Taste: View {
    let onNext: () -> Void
    let onSkip: () -> Void
    @State private var selectedStyles: Set<String> = []
    @State private var selectedMediums: Set<String> = []
    @State private var budget = ""

    private let styles = ["Abstract", "Figurative", "Landscape", "Botanical", "Portrait",
                           "Minimalist", "Expressionism", "Surrealism", "Geometric", "Seascape"]
    private let mediums = ["Oil", "Acrylic", "Watercolour", "Mixed Media", "Pastel",
                            "Gouache", "Digital", "Charcoal", "Ink"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AFSpacing.xl) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Discover Your Taste")
                        .font(AFFont.displayMedium).foregroundColor(.afTextPrimary)
                    Text("Help us surface art you'll love")
                        .font(AFFont.bodyMedium).foregroundColor(.afTextSecondary)
                }

                VStack(alignment: .leading, spacing: AFSpacing.sm) {
                    SetupSectionHeader(icon: "sparkles", iconColor: .afPrimary, title: "Styles You Love")
                    Text("Select all that apply").font(AFFont.bodySmall).foregroundColor(.afTextSecondary)
                    FlowLayout(spacing: 8) {
                        ForEach(styles, id: \.self) { s in
                            StyleTagPill(label: s, isSelected: selectedStyles.contains(s)) {
                                if selectedStyles.contains(s) { selectedStyles.remove(s) }
                                else { selectedStyles.insert(s) }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: AFSpacing.sm) {
                    SetupSectionHeader(icon: "paintbrush", iconColor: .afWarning, title: "Preferred Mediums")
                    FlowLayout(spacing: 8) {
                        ForEach(mediums, id: \.self) { m in
                            StyleTagPill(label: m, isSelected: selectedMediums.contains(m)) {
                                if selectedMediums.contains(m) { selectedMediums.remove(m) }
                                else { selectedMediums.insert(m) }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: AFSpacing.xs) {
                    SetupSectionHeader(icon: "dollarsign.circle.fill", iconColor: .afSuccess, title: "Typical Budget")
                    HStack {
                        Text("$").font(AFFont.bodyLarge).foregroundColor(.afTextSecondary).padding(.leading, 14)
                        TextField("e.g. 500", text: $budget).font(AFFont.bodyLarge).keyboardType(.numberPad)
                    }
                    .frame(height: 50)
                    .background(Color.afSurface2)
                    .clipShape(RoundedRectangle(cornerRadius: AFRadius.md))
                    .overlay(RoundedRectangle(cornerRadius: AFRadius.md).stroke(Color.afBorder, lineWidth: 1))
                    Text("Optional — helps us filter artworks to your range")
                        .font(AFFont.caption).foregroundColor(.afTextTertiary)
                }
            }
            .padding(AFSpacing.xl)
            .padding(.bottom, 120)
        }

        SetupBottomControls(
            primaryLabel: "Save & Continue",
            onPrimary: onNext,
            onSkip: onSkip,
            primaryEnabled: !selectedStyles.isEmpty
        )
    }
}

// MARK: Collector Step 2 — Commission an Artist

private struct CollectorStep2Commission: View {
    let onNext: () -> Void
    let onSkip: () -> Void
    @State private var searchText = ""

    private let artists: [(name: String, location: String, styles: String, rating: String, price: String)] = [
        ("Elena Vasquez",  "Madrid",    "Oil · Abstract · Landscape",  "4.9", "$400"),
        ("Marcus Chen",    "Hong Kong", "Acrylic · Minimalist",         "4.8", "$280"),
        ("Amara Okonkwo",  "Lagos",     "Mixed Media · Portrait",       "5.0", "$350"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AFSpacing.xl) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Commission an Artist")
                        .font(AFFont.displayMedium).foregroundColor(.afTextPrimary)
                    Text("Request a one-of-a-kind painting")
                        .font(AFFont.bodyMedium).foregroundColor(.afTextSecondary)
                }

                HStack(spacing: AFSpacing.sm) {
                    Image(systemName: "magnifyingglass").foregroundColor(.afTextTertiary)
                    TextField("Search artworks, artists, styles…", text: $searchText)
                        .font(AFFont.bodyMedium)
                }
                .padding(.horizontal, AFSpacing.md)
                .frame(height: 46)
                .background(Color.afSurface2)
                .clipShape(RoundedRectangle(cornerRadius: AFRadius.full))
                .overlay(RoundedRectangle(cornerRadius: AFRadius.full).stroke(Color.afBorder, lineWidth: 1))

                Text("Available for Commissions")
                    .font(AFFont.headlineLarge).foregroundColor(.afTextPrimary)

                VStack(spacing: AFSpacing.sm) {
                    ForEach(artists, id: \.name) { a in
                        CommissionArtistRow(
                            name: a.name, location: a.location, styles: a.styles,
                            rating: a.rating, startingPrice: a.price
                        )
                    }
                }

                Button {} label: {
                    Text("Browse All Artists")
                        .font(AFFont.headlineLarge).foregroundColor(.white)
                        .frame(maxWidth: .infinity).frame(height: 54)
                        .background(Color.afPrimary).clipShape(Capsule())
                }
            }
            .padding(AFSpacing.xl)
            .padding(.bottom, 120)
        }

        SetupBottomControls(
            primaryLabel: "Save & Continue",
            onPrimary: onNext,
            onSkip: onSkip
        )
    }
}

// MARK: Collector Step 3 — Set Up Payment

private struct CollectorStep3Payment: View {
    let onNext: () -> Void
    let onSkip: () -> Void
    @State private var selectedPayment: String = ""

    private let methods: [(id: String, icon: String, title: String, subtitle: String)] = [
        ("card",   "💳", "Credit / Debit Card",    "Visa, Mastercard, Amex accepted"),
        ("apple",  "",   "Apple Pay",               "Fast and secure one-tap checkout"),
        ("stripe", "🔒", "Stripe Secure Checkout",  "Bank-level encryption on every purchase"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AFSpacing.xl) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Set Up Payment")
                        .font(AFFont.displayMedium).foregroundColor(.afTextPrimary)
                    Text("Secure checkout powered by Stripe")
                        .font(AFFont.bodyMedium).foregroundColor(.afTextSecondary)
                }

                VStack(spacing: AFSpacing.sm) {
                    ForEach(methods, id: \.id) { m in
                        Button { selectedPayment = m.id } label: {
                            HStack(spacing: AFSpacing.md) {
                                if m.id == "apple" {
                                    Image(systemName: "apple.logo")
                                        .font(.system(size: 22))
                                        .frame(width: 44, height: 44)
                                        .background(Color.afSurface2)
                                        .clipShape(RoundedRectangle(cornerRadius: AFRadius.sm))
                                } else {
                                    Text(m.icon)
                                        .font(.system(size: 24))
                                        .frame(width: 44, height: 44)
                                        .background(Color.afSurface2)
                                        .clipShape(RoundedRectangle(cornerRadius: AFRadius.sm))
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(m.title).font(AFFont.headlineSmall).foregroundColor(.afTextPrimary)
                                    Text(m.subtitle).font(AFFont.bodySmall).foregroundColor(.afTextSecondary)
                                }
                                Spacer()
                                ZStack {
                                    Circle().stroke(selectedPayment == m.id ? Color.afPrimary : Color.afBorder, lineWidth: 1.5)
                                        .frame(width: 22, height: 22)
                                    if selectedPayment == m.id {
                                        Circle().fill(Color.afPrimary).frame(width: 12, height: 12)
                                    }
                                }
                            }
                            .padding(AFSpacing.md)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: AFRadius.lg))
                            .overlay(RoundedRectangle(cornerRadius: AFRadius.lg)
                                .stroke(selectedPayment == m.id ? Color.afPrimary : Color.afBorder, lineWidth: 1.5))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }

                HStack(spacing: AFSpacing.sm) {
                    Image(systemName: "lock.shield.fill").foregroundColor(.afSuccess).font(.system(size: 15))
                    Text("Your payment info is encrypted and never stored on our servers")
                        .font(AFFont.bodySmall).foregroundColor(.afTextSecondary)
                }
                .padding(AFSpacing.md)
                .background(Color.afSuccessBg)
                .clipShape(RoundedRectangle(cornerRadius: AFRadius.md))
            }
            .padding(AFSpacing.xl)
            .padding(.bottom, 120)
        }

        SetupBottomControls(
            primaryLabel: "Save & Continue",
            onPrimary: onNext,
            onSkip: onSkip
        )
    }
}

// MARK: Collector Step 4 — All Set!

private struct CollectorStep4AllSet: View {
    let onDone: () -> Void

    private let features: [(icon: String, color: Color, title: String, sub: String)] = [
        ("magnifyingglass",       .afPrimary, "Discover Art",    "Browse originals filtered to your taste"),
        ("creditcard.fill",       .afSuccess, "Buy Securely",    "Protected by Stripe & escrow"),
        ("hand.thumbsup.fill",    .afWarning, "Commission",      "Request bespoke paintings anytime"),
        ("shippingbox.fill",      .afInfo,    "Track Orders",    "Real-time shipping updates"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: AFSpacing.xl) {
                VStack(spacing: AFSpacing.sm) {
                    ZStack {
                        Circle().fill(Color.afSuccessBg).frame(width: 80, height: 80)
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 38)).foregroundColor(.afSuccess)
                    }
                    Text("You're all set!")
                        .font(AFFont.displayMedium).foregroundColor(.afTextPrimary)
                    Text("Your collector profile is ready to go")
                        .font(AFFont.bodyMedium).foregroundColor(.afTextSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, AFSpacing.xl)

                VStack(alignment: .leading, spacing: AFSpacing.md) {
                    Text("What you can do now")
                        .font(AFFont.headlineLarge).foregroundColor(.afTextPrimary)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AFSpacing.sm) {
                        ForEach(features, id: \.title) { f in
                            VStack(alignment: .leading, spacing: AFSpacing.sm) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: AFRadius.xs)
                                        .fill(f.color.opacity(0.1)).frame(width: 36, height: 36)
                                    Image(systemName: f.icon).font(.system(size: 16)).foregroundColor(f.color)
                                }
                                Text(f.title).font(AFFont.headlineSmall).foregroundColor(.afTextPrimary)
                                Text(f.sub).font(AFFont.bodySmall).foregroundColor(.afTextSecondary).lineSpacing(2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(AFSpacing.md)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: AFRadius.lg))
                            .afCardShadow()
                        }
                    }
                }

                // AR banner
                HStack(spacing: AFSpacing.sm) {
                    Text("🎨").font(.system(size: 18))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Preview art in your room with AR")
                            .font(AFFont.headlineSmall).foregroundColor(.afPrimary)
                        Text("Tap any artwork to see it on your wall before buying")
                            .font(AFFont.bodySmall).foregroundColor(.afTextSecondary)
                    }
                }
                .padding(AFSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.afPrimaryBg)
                .clipShape(RoundedRectangle(cornerRadius: AFRadius.lg))
            }
            .padding(AFSpacing.xl)
            .padding(.bottom, 120)
        }

        SetupBottomControls(
            primaryLabel: "Start Exploring Art",
            onPrimary: onDone,
            onSkip: nil
        )
    }
}

