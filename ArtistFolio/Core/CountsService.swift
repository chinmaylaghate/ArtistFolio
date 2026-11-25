import CloudKit
import Foundation

/// Public, countable copies of activity that otherwise lives in each user's private database.
/// Saves become `ArtworkLike`, follows become `ArtistFollow`, and opening an artwork writes `ArtworkView`.
/// Record names include the user, so each person counts once per artwork or artist.
enum PublicActivity {
    static let likeType = "ArtworkLike"
    static let followType = "ArtistFollow"
    static let viewType = "ArtworkView"

    static func recordType(for kind: LibraryKind) -> String? {
        switch kind {
        case .saved: return likeType
        case .following: return followType
        case .blocked: return nil
        }
    }

    static func recordName(type: String, userID: String, targetID: String) -> String {
        let prefix: String
        switch type {
        case likeType: prefix = "like"
        case followType: prefix = "follow"
        default: prefix = "view"
        }
        return "\(prefix)_\(userID)_\(targetID)"
    }
}

/// When counts are worth showing publicly, and how to shorten them.
enum CountDisplay {
    static let minimumViews = 25
    static let minimumLikes = 5
    static let minimumFollowers = 5

    /// Buyers see an artwork's stats only once they would not make it look empty. Owners always see theirs.
    static func showsArtworkStats(_ artwork: Artwork, isOwner: Bool) -> Bool {
        if isOwner { return artwork.viewCount > 0 || artwork.likeCount > 0 }
        return artwork.viewCount >= minimumViews || artwork.likeCount >= minimumLikes
    }

    /// "980", "1.8K", "12K", "1.2M".
    static func compact(_ value: Int) -> String {
        func short(_ number: Double, _ suffix: String) -> String {
            if number >= 10 { return String(Int(number.rounded())) + suffix }
            let tenths = (number * 10).rounded() / 10
            let text = tenths.rounded() == tenths ? String(Int(tenths)) : String(format: "%.1f", tenths)
            return text + suffix
        }
        if value >= 1_000_000 { return short(Double(value) / 1_000_000, "M") }
        if value >= 1_000 { return short(Double(value) / 1_000, "K") }
        return String(value)
    }
}

extension CloudKitService {
    /// Mirrors a save or follow publicly. Failures are ignored so the private library still works
    /// if the public record types are not deployed yet.
    func setPublicActivity(_ kind: LibraryKind, id: String, included: Bool, userID: String) async {
        guard let type = PublicActivity.recordType(for: kind) else { return }
        let recordID = CKRecord.ID(recordName: PublicActivity.recordName(type: type, userID: userID, targetID: id))
        if included {
            let record = CKRecord(recordType: type, recordID: recordID)
            record["targetID"] = id
            _ = try? await retrying {
                try await publicDB.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys, atomically: true)
            }
        } else {
            try? await delete([recordID], from: publicDB)
        }
    }

    /// Publishes public copies of saves and follows made before counts existed.
    func mirrorPublicLibrary(_ library: UserLibrary) async throws {
        let userID = try await requireUserID()
        var records: [CKRecord] = []
        for (kind, ids) in [(LibraryKind.saved, library.saved), (.following, library.following)] {
            guard let type = PublicActivity.recordType(for: kind) else { continue }
            for id in ids {
                let record = CKRecord(recordType: type, recordID: CKRecord.ID(recordName: PublicActivity.recordName(type: type, userID: userID, targetID: id)))
                record["targetID"] = id
                records.append(record)
            }
        }
        for start in stride(from: 0, to: records.count, by: 200) {
            let chunk = Array(records[start..<min(start + 200, records.count)])
            _ = try await retrying {
                try await publicDB.modifyRecords(saving: chunk, deleting: [], savePolicy: .allKeys, atomically: false)
            }
        }
    }

    func recordView(artworkID: String) async throws {
        let userID = try await requireUserID()
        let type = PublicActivity.viewType
        let record = CKRecord(recordType: type, recordID: CKRecord.ID(recordName: PublicActivity.recordName(type: type, userID: userID, targetID: artworkID)))
        record["targetID"] = artworkID
        _ = try await retrying {
            try await publicDB.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys, atomically: true)
        }
    }

    /// Counts views, likes and followers for the signed-in artist and saves the totals on their own records,
    /// which only they can write. Everyone else reads those totals.
    func refreshCounts() async throws {
        let owner = try await requireUserID()
        let artworkQuery = CKQuery(recordType: "Artwork", predicate: Self.creatorPredicate(owner))
        let artworks = try await allRecords(publicDB, query: artworkQuery, keys: ["viewCount", "likeCount"])
        let ids = artworks.map(\.recordID.recordName)
        let likes = try await tally(PublicActivity.likeType, targets: ids, excluding: owner)
        let views = try await tally(PublicActivity.viewType, targets: ids, excluding: owner)
        let changed = artworks.filter { record in
            let newViews = Int64(views[record.recordID.recordName] ?? 0)
            let newLikes = Int64(likes[record.recordID.recordName] ?? 0)
            guard record["viewCount"] as? Int64 != newViews || record["likeCount"] as? Int64 != newLikes else { return false }
            record["viewCount"] = newViews
            record["likeCount"] = newLikes
            return true
        }
        for start in stride(from: 0, to: changed.count, by: 200) {
            let chunk = Array(changed[start..<min(start + 200, changed.count)])
            _ = try await retrying {
                try await publicDB.modifyRecords(saving: chunk, deleting: [], savePolicy: .changedKeys, atomically: false)
            }
        }

        let followers = Int64(try await tally(PublicActivity.followType, targets: [owner], excluding: owner)[owner] ?? 0)
        let profileQuery = CKQuery(recordType: "Profile", predicate: Self.creatorPredicate(owner))
        if let profile = try await allRecords(publicDB, query: profileQuery, keys: ["followerCount"]).first,
           profile["followerCount"] as? Int64 != followers {
            profile["followerCount"] = followers
            _ = try await retrying {
                try await publicDB.modifyRecords(saving: [profile], deleting: [], savePolicy: .changedKeys, atomically: true)
            }
            await profileCache.clear()
        }
    }

    /// Public activity records the user created, for account deletion.
    func myPublicActivityIDs(owner: String) async throws -> [CKRecord.ID] {
        var ids: [CKRecord.ID] = []
        for type in [PublicActivity.likeType, PublicActivity.followType, PublicActivity.viewType] {
            let query = CKQuery(recordType: type, predicate: Self.creatorPredicate(owner))
            do {
                ids += try await allRecords(publicDB, query: query, keys: []).map(\.recordID)
            } catch let error as CKError where error.code == .unknownItem {
                continue
            }
        }
        return ids
    }

    /// Number of distinct users per target, ignoring the artist's own activity.
    private func tally(_ type: String, targets: [String], excluding owner: String) async throws -> [String: Int] {
        var counts: [String: Int] = [:]
        for start in stride(from: 0, to: targets.count, by: 100) {
            let chunk = Array(targets[start..<min(start + 100, targets.count)])
            let query = CKQuery(recordType: type, predicate: NSPredicate(format: "targetID IN %@", chunk))
            let records: [CKRecord]
            do {
                records = try await allRecords(publicDB, query: query, keys: ["targetID"])
            } catch let error as CKError where error.code == .unknownItem {
                return [:]
            }
            for record in records {
                guard record.creatorUserRecordID?.recordName != owner,
                      record.creatorUserRecordID?.recordName != CKCurrentUserDefaultName,
                      let target = record["targetID"] as? String else { continue }
                counts[target, default: 0] += 1
            }
        }
        return counts
    }
}
