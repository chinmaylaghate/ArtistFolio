import SwiftUI

/// Five stars, filled up to `rating` (rounded to the nearest half).
struct StarRating: View {
    let rating: Double
    var size: CGFloat = 13

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: symbol(for: index))
                    .font(.system(size: size, weight: .semibold))
                    .foregroundStyle(Color.orange)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(format: "%.1f out of 5 stars", rating))
    }

    private func symbol(for index: Int) -> String {
        let value = (rating * 2).rounded() / 2
        if value >= Double(index) { return "star.fill" }
        if value >= Double(index) - 0.5 { return "star.leadinghalf.filled" }
        return "star"
    }
}

/// "★ 4.8 · 12 reviews", or just the count until there are enough reviews for an average.
struct RatingLine: View {
    let summary: ReviewSummary

    var body: some View {
        if summary.showsAverage {
            HStack(spacing: 4) {
                Image(systemName: "star.fill").foregroundStyle(Color.orange)
                Text(summary.averageText).fontWeight(.semibold)
                Text("· \(summary.countText)").foregroundStyle(Color.afTextSecondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Rated \(summary.averageText) out of 5 from \(summary.countText)")
        } else if summary.count > 0 {
            Text(summary.countText).foregroundStyle(Color.afTextSecondary)
        }
    }
}

struct ReviewRow: View {
    @EnvironmentObject var appState: AppState
    let review: Review
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?
    @State private var showReport = false

    private var isMine: Bool { review.reviewerID == appState.currentUserID }

    var body: some View {
        VStack(alignment: .leading, spacing: AFSpacing.xs) {
            HStack(alignment: .center) {
                StarRating(rating: Double(review.rating))
                Text(review.relationship.rawValue)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.afTextSecondary)
                Spacer()
                Menu {
                    if isMine {
                        Button("Edit Review", systemImage: "pencil") { onEdit?() }
                        Button("Delete Review", systemImage: "trash", role: .destructive) { onDelete?() }
                    } else {
                        Button("Report Review", systemImage: "flag") { showReport = true }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(Color.afIconSecondary)
                        .frame(width: 32, height: 28)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Review options")
            }
            if !review.text.isEmpty {
                Text(review.text).font(.subheadline)
            }
            Text("\(isMine ? "You" : review.reviewerName) · \(review.createdAt.formatted(date: .abbreviated, time: .omitted))")
                .font(.footnote)
                .foregroundStyle(Color.afTextSecondary)
        }
        .padding(AFSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: AFRadius.md, style: .continuous))
        .sheet(isPresented: $showReport) {
            ReportSheet(target: .review, targetID: review.id, name: "\(review.reviewerName)\u{2019}s review")
        }
    }
}

/// Loads, shows and edits reviews for one artist. Used by the artist page and the all-reviews screen.
@MainActor
final class ReviewsModel: ObservableObject {
    @Published private(set) var reviews: [Review] = []
    @Published private(set) var isLoaded = false
    @Published var editing: Review?
    @Published var confirmDelete = false

    let artistID: String

    init(artistID: String) { self.artistID = artistID }

    var summary: ReviewSummary { ReviewSummary(reviews: reviews) }

    func load(_ appState: AppState) async {
        let all = (try? await appState.backend.reviews(artistID: artistID)) ?? []
        reviews = all.filter { !appState.isBlocked($0.reviewerID) }
        isLoaded = true
    }

    func myReview(_ appState: AppState) -> Review? {
        guard let me = appState.currentUserID else { return nil }
        return reviews.first { $0.reviewerID == me }
    }

    func startWriting(_ appState: AppState) {
        guard let me = appState.currentUserID else {
            appState.showICloudPrompt = true
            return
        }
        editing = myReview(appState) ?? Review(artistID: artistID, reviewerID: me, rating: 0, text: "", relationship: .bought)
    }

    func delete(_ appState: AppState) async {
        do {
            try await appState.backend.deleteReview(artistID: artistID)
            await load(appState)
        } catch {
            appState.alertMessage = AppState.message(for: error)
        }
    }
}

/// The reviews block on an artist page: rating, the newest two reviews, and a way to see or write more.
struct ReviewsSection: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var model: ReviewsModel
    let artistName: String
    let isSelf: Bool

    private static let previewCount = 2

    var body: some View {
        VStack(alignment: .leading, spacing: AFSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("Reviews").font(.title2.bold())
                Spacer()
                RatingLine(summary: model.summary).font(.subheadline)
            }
            if model.reviews.isEmpty {
                Text(isSelf ? "Collectors who buy from you or meet you can leave a review here." : "No reviews yet. Bought a piece or met \(BuyerMessage.firstName(artistName))? Be the first to review.")
                    .font(.subheadline)
                    .foregroundStyle(Color.afTextSecondary)
            } else {
                ForEach(model.reviews.prefix(Self.previewCount)) { review in
                    ReviewRow(review: review, onEdit: { model.editing = review }, onDelete: { model.confirmDelete = true })
                }
                if model.reviews.count > Self.previewCount {
                    NavigationLink {
                        AllReviewsView(model: model, artistName: artistName, isSelf: isSelf)
                    } label: {
                        Label("See all \(model.reviews.count) reviews", systemImage: "chevron.forward")
                            .labelStyle(.titleOnly)
                            .font(.subheadline.weight(.medium))
                    }
                    .tint(Color.afPrimary)
                }
            }
            if !isSelf {
                Button {
                    model.startWriting(appState)
                } label: {
                    Label(model.myReview(appState) == nil ? "Write a Review" : "Edit Your Review", systemImage: "star.bubble")
                        .frame(maxWidth: .infinity)
                }
                .secondaryAction()
            }
        }
        .reviewEditing(model: model, artistName: artistName)
    }
}

struct AllReviewsView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var model: ReviewsModel
    let artistName: String
    let isSelf: Bool

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AFSpacing.sm) {
                RatingLine(summary: model.summary).font(.headline)
                if !model.summary.showsAverage {
                    Text("The average rating appears once there are \(ReviewSummary.minimumForAverage) reviews.")
                        .font(.footnote)
                        .foregroundStyle(Color.afTextSecondary)
                }
                ForEach(model.reviews) { review in
                    ReviewRow(review: review, onEdit: { model.editing = review }, onDelete: { model.confirmDelete = true })
                }
            }
            .padding(AFSpacing.md)
        }
        .navigationTitle("Reviews of \(BuyerMessage.firstName(artistName))")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isSelf {
                ToolbarItem(placement: .primaryAction) {
                    Button(model.myReview(appState) == nil ? "Write" : "Edit") { model.startWriting(appState) }
                }
            }
        }
        .reviewEditing(model: model, artistName: artistName)
    }
}

private extension View {
    func reviewEditing(model: ReviewsModel, artistName: String) -> some View {
        modifier(ReviewEditingModifier(model: model, artistName: artistName))
    }
}

private struct ReviewEditingModifier: ViewModifier {
    @EnvironmentObject var appState: AppState
    @ObservedObject var model: ReviewsModel
    let artistName: String

    func body(content: Content) -> some View {
        content
            .sheet(item: $model.editing) { draft in
                ReviewEditorSheet(draft: draft, artistName: artistName) {
                    Task { await model.load(appState) }
                }
            }
            .confirmationDialog("Delete your review?", isPresented: $model.confirmDelete, titleVisibility: .visible) {
                Button("Delete Review", role: .destructive) { Task { await model.delete(appState) } }
            } message: {
                Text("You can write a new one later.")
            }
    }
}

struct ReviewEditorSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let artistName: String
    let onSaved: () -> Void
    @State private var draft: Review
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(draft: Review, artistName: String, onSaved: @escaping () -> Void) {
        _draft = State(initialValue: draft)
        self.artistName = artistName
        self.onSaved = onSaved
    }

    private var isEditingExisting: Bool { draft.rating > 0 && !draft.text.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: AFSpacing.sm) {
                        ForEach(1...5, id: \.self) { value in
                            Button {
                                draft.rating = value
                            } label: {
                                Image(systemName: value <= draft.rating ? "star.fill" : "star")
                                    .font(.title2)
                                    .foregroundStyle(value <= draft.rating ? Color.orange : Color.afIconSecondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(value) star\(value == 1 ? "" : "s")")
                            .accessibilityAddTraits(value == draft.rating ? .isSelected : [])
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .sensoryFeedback(.selection, trigger: draft.rating)
                } header: {
                    Text("Your rating")
                }

                Section("How do you know \(BuyerMessage.firstName(artistName))?") {
                    Picker("Relationship", selection: $draft.relationship) {
                        ForEach(ReviewRelationship.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section {
                    TextField("What was it like buying from or working with \(BuyerMessage.firstName(artistName))?", text: $draft.text, axis: .vertical)
                        .lineLimit(4...8)
                        .onChange(of: draft.text) { _, value in
                            if value.count > Review.maxTextLength { draft.text = String(value.prefix(Review.maxTextLength)) }
                        }
                } header: {
                    Text("Your review")
                } footer: {
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red)
                    } else {
                        Text("Shown publicly with your name. One review per artist; you can edit or delete it later.")
                    }
                }
            }
            .navigationTitle(isEditingExisting ? "Edit Review" : "Write a Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Post") { Task { await save() } }
                            .fontWeight(.semibold)
                            .disabled(!Review.ratingRange.contains(draft.rating) || draft.text.trimmed.isEmpty)
                    }
                }
            }
        }
        .interactiveDismissDisabled(isSaving)
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            _ = try await appState.backend.saveReview(draft)
            onSaved()
            dismiss()
        } catch {
            errorMessage = AppState.message(for: error)
        }
    }
}
