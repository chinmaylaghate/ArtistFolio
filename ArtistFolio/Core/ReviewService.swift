import CloudKit
import Foundation

enum ReviewMapper {
    static let keys: [CKRecord.FieldKey] = ["artistID", "rating", "text", "relationship"]

    static func review(from record: CKRecord, reviewerID: String) -> Review? {
        guard let artistID = record["artistID"] as? String, !artistID.isEmpty,
              let rating = (record["rating"] as? Int64).map(Int.init), Review.ratingRange.contains(rating),
              let relationship = (record["relationship"] as? String).flatMap(ReviewRelationship.init(rawValue:)) else { return nil }
        return Review(
            artistID: artistID,
            reviewerID: reviewerID,
            rating: rating,
            text: record["text"] as? String ?? "",
            relationship: relationship,
            createdAt: record.creationDate ?? Date()
        )
    }

    static func apply(_ review: Review, to record: CKRecord) {
        record["artistID"] = review.artistID
        record["rating"] = Int64(min(max(review.rating, Review.ratingRange.lowerBound), Review.ratingRange.upperBound))
        record["text"] = String(review.text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Review.maxTextLength))
        record["relationship"] = review.relationship.rawValue
    }
}

extension CloudKitService {
    /// Loads at most 200 reviews; the summary is worked out in the app because CloudKit has no server code.
    func reviews(artistID: String) async throws -> [Review] {
        let query = CKQuery(recordType: "Review", predicate: NSPredicate(format: "artistID == %@", artistID))
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let me = try? await currentUserID()
        let result = try await page(publicDB, query: query, keys: ReviewMapper.keys, limit: 200, cursor: nil)
        let reviews = result.records.compactMap { record -> Review? in
            guard let reviewer = Self.ownerID(creator: record.creatorUserRecordID, currentUserID: me),
                  reviewer != artistID else { return nil }
            return ReviewMapper.review(from: record, reviewerID: reviewer)
        }
        let names = await profiles(ownerIDs: Set(reviews.map(\.reviewerID)))
        return reviews.map { review in
            var named = review
            named.reviewerName = names[review.reviewerID]?.displayName ?? "ArtistFolio member"
            return named
        }
    }

    func saveReview(_ review: Review) async throws -> Review {
        let reviewer = try await requireUserID()
        guard reviewer != review.artistID else { throw AppError.cannotReviewSelf }
        guard ContentFilter.isAllowed(review.text) else { throw AppError.objectionableContent }
        var output = review
        output.reviewerID = reviewer
        let recordID = CKRecord.ID(recordName: Review.recordName(reviewerID: reviewer, artistID: review.artistID))
        let record = CKRecord(recordType: "Review", recordID: recordID)
        ReviewMapper.apply(output, to: record)
        _ = try await retrying {
            try await publicDB.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys, atomically: true)
        }
        output.text = record["text"] as? String ?? ""
        return output
    }

    func deleteReview(artistID: String) async throws {
        let reviewer = try await requireUserID()
        try await delete([CKRecord.ID(recordName: Review.recordName(reviewerID: reviewer, artistID: artistID))], from: publicDB)
    }

    /// All reviews the user wrote, for account deletion. Tolerates the record type not existing yet.
    func myReviewIDs(owner: String) async throws -> [CKRecord.ID] {
        let query = CKQuery(recordType: "Review", predicate: Self.creatorPredicate(owner))
        do {
            return try await allRecords(publicDB, query: query, keys: []).map(\.recordID)
        } catch let error as CKError where error.code == .unknownItem {
            return []
        }
    }
}
