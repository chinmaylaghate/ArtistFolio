import SwiftUI

struct FirstTimeSetupView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if appState.isArtist {
            ArtistSetupView()
        } else {
            CollectorSetupView()
        }
    }
}

// MARK: - Artist First-Time Setup

struct ArtistSetupView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var page = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TabView(selection: $page) {
                    welcomePage.tag(0)
                    commissionPage.tag(1)
                    readyPage.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                pageIndicator

                bottomButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
            }
            .background(Color(uiColor: .systemBackground).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") { dismiss() }.foregroundStyle(.secondary)
                }
            }
        }
    }

    private var welcomePage: some View {
        setupPage(
            icon: "paintpalette.fill",
            gradient: [Color(hex: "#3F73D3"), Color(hex: "#5B3CC4")],
            title: "Welcome, Artist!",
            body: "Your profile is live. Add your first artwork to start reaching collectors. You can upload photos directly from your camera roll."
        )
    }

    private var commissionPage: some View {
        setupPage(
            icon: "pencil.and.ruler.fill",
            gradient: [Color(hex: "#FF6B6B"), Color(hex: "#C0392B")],
            title: "Open to Commissions?",
            body: "Collectors can send you custom work requests. Set your minimum budget and typical turnaround in Profile → Edit Profile → Commissions."
        )
    }

    private var readyPage: some View {
        setupPage(
            icon: "checkmark.circle.fill",
            gradient: [Color(hex: "#34C759"), Color(hex: "#1A7F3C")],
            title: "You're All Set!",
            body: "Head to your Studio to upload artwork. Your gallery is waiting."
        )
    }

    private func setupPage(icon: String, gradient: [Color], title: String, body: String) -> some View {
        VStack(spacing: 28) {
            Spacer()
            ZStack {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .frame(width: 160, height: 160)
                    .overlay(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .stroke(LinearGradient(colors: gradient.map { $0.opacity(0.5) }, startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
                    )
                    .shadow(color: gradient[0].opacity(0.3), radius: 20, y: 6)
                Image(systemName: icon)
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .symbolEffect(.bounce, options: .speed(0.6))
            }

            VStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 26, weight: .bold))
                    .multilineTextAlignment(.center)
                Text(body)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 24)
            }
            Spacer()
            Spacer()
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(i == page ? Color.afPrimary : Color.afBorder)
                    .frame(width: i == page ? 24 : 6, height: 6)
                    .animation(.spring(response: 0.3), value: page)
            }
        }
        .padding(.bottom, 20)
    }

    private var bottomButton: some View {
        Group {
            if page < 2 {
                Button("Continue") {
                    withAnimation(.easeInOut(duration: 0.3)) { page += 1 }
                }
                .buttonStyle(AFPrimaryButtonStyle())
            } else {
                Button("Go to Studio") {
                    dismiss()
                    appState.selectedTab = .studio
                }
                .buttonStyle(AFPrimaryButtonStyle())
            }
        }
    }
}

// MARK: - Collector First-Time Setup

struct CollectorSetupView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedStyles: Set<ArtworkStyle> = []
    @State private var page = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TabView(selection: $page) {
                    welcomePage.tag(0)
                    styleSelectionPage.tag(1)
                    readyPage.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                pageIndicator

                bottomButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
            }
            .background(Color(uiColor: .systemBackground).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") { dismiss() }.foregroundStyle(.secondary)
                }
            }
        }
    }

    private var welcomePage: some View {
        VStack(spacing: 28) {
            Spacer()
            ZStack {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .frame(width: 160, height: 160)
                    .overlay(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .stroke(LinearGradient(colors: [Color(hex: "#5B3CC4").opacity(0.5), Color(hex: "#3F73D3").opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
                    )
                    .shadow(color: Color(hex: "#5B3CC4").opacity(0.3), radius: 20, y: 6)
                Image(systemName: "sparkles")
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(LinearGradient(colors: [Color(hex: "#5B3CC4"), Color(hex: "#3F73D3")], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .symbolEffect(.pulse, options: .repeating)
            }
            VStack(spacing: 12) {
                Text("Welcome, Collector!")
                    .font(.system(size: 26, weight: .bold))
                    .multilineTextAlignment(.center)
                Text("Discover original work from independent artists. Tell us what you love and we'll personalize your feed.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 24)
            }
            Spacer()
            Spacer()
        }
    }

    private var styleSelectionPage: some View {
        VStack(spacing: 20) {
            Spacer()
            VStack(spacing: 8) {
                Text("What styles do you love?")
                    .font(.system(size: 26, weight: .bold))
                    .multilineTextAlignment(.center)
                Text("Pick as many as you like. You can always browse all styles.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))], spacing: 10) {
                ForEach(ArtworkStyle.allCases) { style in
                    let on = selectedStyles.contains(style)
                    Text(style.rawValue)
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(on ? Color.afPrimary : Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(on ? .white : .primary)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.25)) {
                                if on { selectedStyles.remove(style) } else { selectedStyles.insert(style) }
                            }
                        }
                }
            }
            .padding(.horizontal, 24)
            Spacer()
        }
    }

    private var readyPage: some View {
        VStack(spacing: 28) {
            Spacer()
            ZStack {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .frame(width: 160, height: 160)
                    .overlay(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .stroke(LinearGradient(colors: [Color(hex: "#34C759").opacity(0.5), Color(hex: "#1A7F3C").opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
                    )
                    .shadow(color: Color(hex: "#34C759").opacity(0.3), radius: 20, y: 6)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(LinearGradient(colors: [Color(hex: "#34C759"), Color(hex: "#1A7F3C")], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .symbolEffect(.bounce, options: .speed(0.6))
            }
            VStack(spacing: 12) {
                Text("You're Ready!")
                    .font(.system(size: 26, weight: .bold))
                    .multilineTextAlignment(.center)
                Text("Start discovering art from independent artists around the world.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 24)
            }
            Spacer()
            Spacer()
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(i == page ? Color.afPrimary : Color.afBorder)
                    .frame(width: i == page ? 24 : 6, height: 6)
                    .animation(.spring(response: 0.3), value: page)
            }
        }
        .padding(.bottom, 20)
    }

    private var bottomButton: some View {
        Group {
            if page < 2 {
                Button(page == 1 && selectedStyles.isEmpty ? "Skip" : "Continue") {
                    withAnimation(.easeInOut(duration: 0.3)) { page += 1 }
                }
                .buttonStyle(AFPrimaryButtonStyle())
            } else {
                Button("Start Discovering") { dismiss() }
                    .buttonStyle(AFPrimaryButtonStyle())
            }
        }
    }
}
