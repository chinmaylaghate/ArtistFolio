// MARK: - Home View (Artist & Collector)
// Matches Figma: Artist > Home (36:21076), Collector > Home (30:2992)
import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        if appState.isArtist {
            ArtistHomeView()
        } else {
            CollectorHomeView()
        }
    }
}

// MARK: - Artist Home (Figma: 36:21076)

struct ArtistHomeView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: AFSpacing.xl) {

                // ── Greeting ─────────────────────────────────────
                VStack(alignment: .leading, spacing: 2) {
                    Text(appState.currentUser?.displayName ?? "Artist")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.afTextPrimary)
                    Text("Good morning")
                        .font(AFFont.bodyMedium)
                        .foregroundColor(.afTextSecondary)
                }
                .padding(.horizontal, AFSpacing.lg)

                // ── Stats Row ─────────────────────────────────────
                HStack(spacing: 10) {
                    ArtistStatCard(value: "6,490", label: "Total Views",
                                   valueColor: .afPrimary, bgColor: .afPrimaryBg)
                    ArtistStatCard(value: "$0", label: "Earnings",
                                   valueColor: .afSuccess, bgColor: .afSuccessBg)
                    ArtistStatCard(value: "3", label: "Pending",
                                   valueColor: .afOrange, bgColor: .afOrangeBg)
                }
                .padding(.horizontal, AFSpacing.lg)

                // ── Recent Activity ───────────────────────────────
                VStack(alignment: .leading, spacing: AFSpacing.sm) {
                    SectionHeader2(title: "Recent Activity", actionLabel: "See all") {}
                        .padding(.horizontal, AFSpacing.lg)

                    VStack(spacing: 8) {
                        ActivityRow(icon: "dollarsign.circle.fill", iconBg: .afSuccess,
                                    title: "'Golden Hour Reverie' sold!",
                                    subtitle: "Alex Thompson · $1,200", time: "2m ago")
                        ActivityRow(icon: "person.badge.plus", iconBg: .afPrimary,
                                    title: "New follower",
                                    subtitle: "Sarah Mitchell started following you", time: "1h ago")
                        ActivityRow(icon: "heart.fill", iconBg: .afError,
                                    title: "142 new likes",
                                    subtitle: "'Tidal Resonance' is trending", time: "3h ago")
                        ActivityRow(icon: "shippingbox.fill", iconBg: .afOrange,
                                    title: "Commission request",
                                    subtitle: "James Park · $1,400 budget", time: "Yesterday")
                    }
                    .padding(.horizontal, AFSpacing.lg)
                }

                // ── Top Listings ──────────────────────────────────
                VStack(alignment: .leading, spacing: AFSpacing.sm) {
                    SectionHeader2(title: "Your Top Listings", actionLabel: "View all") {}
                        .padding(.horizontal, AFSpacing.lg)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Artwork.previews) { artwork in
                                TopListingCard(artwork: artwork)
                            }
                        }
                        .padding(.horizontal, AFSpacing.lg)
                    }
                }

                // ── Commission Requests Banner ─────────────────────
                CommissionRequestBanner()
                    .padding(.horizontal, AFSpacing.lg)

                // ── Market Insights ───────────────────────────────
                VStack(alignment: .leading, spacing: AFSpacing.sm) {
                    Text("Market Insights")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.afTextPrimary)
                        .padding(.horizontal, AFSpacing.lg)
                    MarketInsightsCard()
                        .padding(.horizontal, AFSpacing.lg)
                }

                Spacer(minLength: 120)
            }
            .padding(.top, AFSpacing.sm)
        }
        .background(Color.afBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Home").font(AFFont.headlineMedium).foregroundColor(.afTextPrimary)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    NavigationLink(destination: NotificationsView()) {
                        GlassCircleButton(icon: "bell", badge: appState.unreadNotificationCount)
                    }
                    NavigationLink(destination: NewListingView()) {
                        Circle().fill(Color.afPrimary).frame(width: 44, height: 44)
                            .overlay(Image(systemName: "plus").font(.system(size: 16, weight: .bold)).foregroundColor(.white))
                            .afGlassShadow()
                    }
                }
            }
        }
    }
}

// MARK: - Collector Home (Figma: 30:2992)

struct CollectorHomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedMedium: String = "All"
    @State private var dismissedBanner = false

    let mediums = ["All", "Oil", "Acrylic", "Watercolor", "Mixed Media", "Digital"]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: AFSpacing.xl) {

                // Category pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(mediums, id: \.self) { m in
                            Button { selectedMedium = m } label: {
                                Text(m)
                                    .font(AFFont.headlineSmall)
                                    .foregroundColor(selectedMedium == m ? .white : .afTextSecondary)
                                    .padding(.horizontal, AFSpacing.md)
                                    .padding(.vertical, AFSpacing.xs)
                                    .background(selectedMedium == m ? Color.afPrimary : Color.afSurface)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(selectedMedium == m ? Color.clear : Color.afBorder, lineWidth: 1))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, AFSpacing.lg)
                }

                // Greeting
                VStack(alignment: .leading, spacing: 2) {
                    Text(appState.currentUser?.displayName ?? "Collector")
                        .font(.system(size: 34, weight: .bold)).foregroundColor(.afTextPrimary)
                    Text("Welcome back").font(AFFont.bodyMedium).foregroundColor(.afTextSecondary)
                }
                .padding(.horizontal, AFSpacing.lg)

                // Featured Collection Banner
                FeaturedCollectionBanner().padding(.horizontal, AFSpacing.lg)

                // Discover Artists CTA
                if !dismissedBanner {
                    DiscoverArtistsCTA { withAnimation { dismissedBanner = true } }
                        .padding(.horizontal, AFSpacing.lg)
                }

                // Featured Artists
                VStack(alignment: .leading, spacing: AFSpacing.sm) {
                    SectionHeader2(title: "Featured Artists", actionLabel: "See all") {}
                        .padding(.horizontal, AFSpacing.lg)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: AFSpacing.md) {
                            ForEach(["Elena V.", "Marcus C.", "Amara O.", "Isabelle", "Yuki T."], id: \.self) { name in
                                FeaturedArtistBubble(name: name, sales: "87 sales")
                            }
                        }
                        .padding(.horizontal, AFSpacing.lg)
                    }
                }

                // Trending Now
                VStack(alignment: .leading, spacing: AFSpacing.sm) {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill").foregroundColor(.afOrange)
                        Text("Trending Now").font(.system(size: 16, weight: .regular)).foregroundColor(.afTextPrimary)
                    }
                    .padding(.horizontal, AFSpacing.lg)
                    VStack(spacing: 8) {
                        ForEach(Artwork.previews) { artwork in
                            NavigationLink(destination: ArtworkDetailView(artwork: artwork)) {
                                TrendingArtworkRow(artwork: artwork)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, AFSpacing.lg)
                }

                // New Arrivals
                VStack(alignment: .leading, spacing: AFSpacing.sm) {
                    SectionHeader2(title: "New Arrivals", actionLabel: "See all") {}
                        .padding(.horizontal, AFSpacing.lg)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
                        ForEach(Artwork.previews + Artwork.previews) { artwork in
                            NavigationLink(destination: ArtworkDetailView(artwork: artwork)) {
                                ArtworkCard(artwork: artwork)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, AFSpacing.lg)
                }

                Spacer(minLength: 120)
            }
            .padding(.top, AFSpacing.sm)
        }
        .background(Color.afBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Home").font(AFFont.headlineMedium).foregroundColor(.afTextPrimary)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    NavigationLink(destination: NotificationsView()) {
                        GlassCircleButton(icon: "bell", badge: appState.unreadNotificationCount)
                    }
                    NavigationLink(destination: CartView()) {
                        ZStack(alignment: .topTrailing) {
                            GlassCircleButton(icon: "bag", badge: 0)
                            if appState.cartCount > 0 {
                                Text("\(appState.cartCount)")
                                    .font(.system(size: 9, weight: .bold)).foregroundColor(.white)
                                    .padding(3).background(Color.afError).clipShape(Circle())
                                    .offset(x: 2, y: -2)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Shared Components

struct GlassCircleButton: View {
    let icon: String
    var badge: Int = 0

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(.afTextPrimary)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
                .afGlassShadow()
            if badge > 0 {
                Circle().fill(Color.afError).frame(width: 8, height: 8).offset(x: 2, y: -2)
            }
        }
    }
}

struct SectionHeader2: View {
    let title: String
    var actionLabel: String = "See all"
    let action: () -> Void

    var body: some View {
        HStack {
            Text(title).font(.system(size: 16, weight: .regular)).foregroundColor(.afTextPrimary)
            Spacer()
            Button(action: action) {
                Text(actionLabel).font(.system(size: 13)).foregroundColor(.afPrimary)
            }
        }
    }
}

struct ArtistStatCard: View {
    let value: String
    let label: String
    let valueColor: Color
    let bgColor: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(AFFont.statNumber).foregroundColor(valueColor)
            Text(label).font(AFFont.statLabel).foregroundColor(.afTextSecondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(bgColor)
        .clipShape(RoundedRectangle(cornerRadius: AFRadius.sm))
    }
}

struct ActivityRow: View {
    let icon: String
    let iconBg: Color
    let title: String
    let subtitle: String
    let time: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 15)).foregroundColor(iconBg)
                .frame(width: 36, height: 36).background(iconBg.opacity(0.10)).clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(AFFont.headlineSmall).foregroundColor(.afTextPrimary).lineLimit(1)
                Text(subtitle).font(AFFont.bodySmall).foregroundColor(.afTextSecondary).lineLimit(1)
            }
            Spacer()
            Text(time).font(AFFont.caption).foregroundColor(.afTextTertiary).lineLimit(1)
        }
        .padding(AFSpacing.md)
        .background(Color.afSurface)
        .clipShape(RoundedRectangle(cornerRadius: AFRadius.sm))
        .overlay(RoundedRectangle(cornerRadius: AFRadius.sm).stroke(Color.afBorder, lineWidth: 1))
    }
}

struct TopListingCard: View {
    let artwork: Artwork

    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: AFRadius.sm).fill(Color.afSurface2).frame(width: 150, height: 110)
                HStack(spacing: 4) {
                    Image(systemName: "eye").font(.system(size: 10))
                    Text(formatCount(artwork.viewsCount)).font(.system(size: 10))
                }
                .foregroundColor(.white).padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color.black.opacity(0.52)).clipShape(Capsule()).padding(8)
            }
            Text(artwork.title).font(AFFont.labelMedium).foregroundColor(.afTextPrimary).lineLimit(1).frame(width: 150)
            Text("$\(Int(artwork.price))").font(AFFont.captionBold).foregroundColor(.afPrimary)
        }
        .frame(width: 150)
    }
}

struct CommissionRequestBanner: View {
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "paintbrush.fill").font(.system(size: 22)).foregroundColor(.afOrange)
                .frame(width: 48, height: 48).background(Color.afOrange.opacity(0.12)).clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("3 Commission Requests").font(AFFont.headlineSmall).foregroundColor(.afTextPrimary)
                Text("2 pending · 1 in progress").font(AFFont.caption).foregroundColor(.afTextSecondary)
            }
            Spacer()
            Button("Review") {}.font(AFFont.headlineSmall).foregroundColor(.afPrimary)
        }
        .padding(.horizontal, 17).padding(.vertical, 12)
        .background(Color.afSurface)
        .clipShape(RoundedRectangle(cornerRadius: AFRadius.sm))
        .overlay(RoundedRectangle(cornerRadius: AFRadius.sm).stroke(Color.afBorder, lineWidth: 1))
    }
}

struct MarketInsightsCard: View {
    let tags = ["Abstract", "Seascape", "Portrait", "Oil"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.fill").font(.system(size: 14)).foregroundColor(.afTextPrimary)
                Text("Trending styles this week").font(AFFont.headlineSmall).foregroundColor(.afTextPrimary)
            }
            HStack(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag).font(AFFont.caption).foregroundColor(.afTextPrimary)
                        .padding(.horizontal, 12).padding(.vertical, 4)
                        .background(Color.afPrimary.opacity(0.08)).clipShape(Capsule())
                }
            }
            Text("Abstract and seascape works are getting 3× more views this week. Adding detailed texture photos can increase engagement.")
                .font(AFFont.caption).foregroundColor(.afTextSecondary).lineSpacing(4)
        }
        .padding(AFSpacing.md)
        .background(Color.afSurface)
        .clipShape(RoundedRectangle(cornerRadius: AFRadius.sm))
        .overlay(RoundedRectangle(cornerRadius: AFRadius.sm).stroke(Color.afBorder, lineWidth: 1))
    }
}

struct FeaturedCollectionBanner: View {
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: AFRadius.lg)
                .fill(LinearGradient(colors: [Color(hex: "#8B4513"), Color(hex: "#3D1A00")],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(height: 180)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles").font(.system(size: 10))
                    Text("FEATURED COLLECTION").font(.system(size: 11, weight: .medium)).tracking(1)
                }
                .foregroundColor(.white.opacity(0.7))
                Text("Abstract Masters").font(.system(size: 20, weight: .semibold)).foregroundColor(.white)
                Text("Bold forms & pure emotion").font(AFFont.bodySmall).foregroundColor(.white.opacity(0.7))
            }
            .padding(AFSpacing.lg)
        }
    }
}

struct DiscoverArtistsCTA: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "person.2.fill").font(.system(size: 22)).foregroundColor(.afPrimary)
                    .frame(width: 44, height: 44).background(Color.afPrimaryLight).clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Follow your favourite artists").font(AFFont.headlineSmall).foregroundColor(.afTextPrimary)
                    Text("Get notified when they drop new works").font(AFFont.bodySmall).foregroundColor(.afTextSecondary)
                }
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark").font(.system(size: 13)).foregroundColor(.afTextTertiary)
                }
            }
            Button {} label: { HStack { Image(systemName: "sparkles"); Text("Discover Artists") } }
                .buttonStyle(AFPrimaryButtonStyle())
        }
        .padding(AFSpacing.md)
        .background(Color.afSurface)
        .clipShape(RoundedRectangle(cornerRadius: AFRadius.lg))
        .overlay(RoundedRectangle(cornerRadius: AFRadius.lg).stroke(Color.afBorder, lineWidth: 1))
    }
}

struct FeaturedArtistBubble: View {
    let name: String
    let sales: String

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle().stroke(AFGradient.avatarBorder, lineWidth: 2).frame(width: 64, height: 64)
                Circle().fill(Color.afSurface2).frame(width: 58, height: 58)
                Text(String(name.prefix(1))).font(AFFont.headlineLarge).foregroundColor(.afTextSecondary)
            }
            Text(name).font(AFFont.headlineSmall).foregroundColor(.afTextPrimary).lineLimit(1)
            Text(sales).font(AFFont.caption).foregroundColor(.afTextSecondary)
        }
        .frame(width: 74)
    }
}

struct TrendingArtworkRow: View {
    let artwork: Artwork

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: AFRadius.sm).fill(Color.afSurface2).frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text(artwork.title).font(AFFont.headlineSmall).foregroundColor(.afTextPrimary)
                Text(artwork.artistName).font(AFFont.bodySmall).foregroundColor(.afTextSecondary)
            }
            Spacer()
            Text("$\(Int(artwork.price))").font(AFFont.price).foregroundColor(.afPrimary)
        }
        .padding(12).background(Color.afSurface)
        .clipShape(RoundedRectangle(cornerRadius: AFRadius.sm))
        .overlay(RoundedRectangle(cornerRadius: AFRadius.sm).stroke(Color.afBorder, lineWidth: 1))
    }
}

// Legacy alias for AllScreens.swift compatibility
struct StatCard: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        ArtistStatCard(value: value, label: label, valueColor: color,
                       bgColor: color.opacity(0.08))
    }
}

#Preview {
    NavigationStack { HomeView().environmentObject(AppState()) }
}
