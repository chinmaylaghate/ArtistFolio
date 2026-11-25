import CloudKit
import Foundation

extension CloudKitService {
    func library() async throws -> UserLibrary {
        guard try await currentUserID() != nil else { return UserLibrary() }
        var output = UserLibrary()
        for kind in LibraryKind.allCases {
            let query = CKQuery(recordType: kind.recordType, predicate: NSPredicate(value: true))
            let records = try await allRecords(privateDB, query: query, keys: ["targetID"])
            let ids = Set(records.compactMap { $0["targetID"] as? String })
            switch kind {
            case .saved: output.saved = ids
            case .following: output.following = ids
            case .blocked: output.blocked = ids
            }
        }
        return output
    }

    func setLibrary(_ kind: LibraryKind, id: String, included: Bool) async throws {
        let userID = try await requireUserID()
        let recordID = CKRecord.ID(recordName: "\(kind.rawValue)-\(id)")
        if included {
            let record = CKRecord(recordType: kind.recordType, recordID: recordID)
            record["targetID"] = id
            _ = try await retrying {
                try await privateDB.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys, atomically: true)
            }
        } else {
            try await delete([recordID], from: privateDB)
        }
        // Only after the private change succeeds, so counts never include a save the user doesn't have.
        Task { await setPublicActivity(kind, id: id, included: included, userID: userID) }
    }

    func submitReport(target: ReportTarget, targetID: String, reason: ReportReason, note: String) async throws {
        _ = try await requireUserID()
        let record = CKRecord(recordType: "Report")
        record["targetType"] = target.rawValue
        record["targetID"] = targetID
        record["reason"] = reason.rawValue
        record["note"] = String(note.prefix(500))
        _ = try await retrying { try await self.publicDB.save(record) }
    }
}
