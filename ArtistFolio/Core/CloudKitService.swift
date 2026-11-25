import CloudKit
import Foundation

actor ProfileCache {
    private var values: [String: UserProfile] = [:]
    private var misses: Set<String> = []

    func lookup(_ id: String) -> (found: Bool, profile: UserProfile?) {
        if let value = values[id] { return (true, value) }
        return (misses.contains(id), nil)
    }

    func store(_ profile: UserProfile?, id: String) {
        if let profile {
            values[id] = profile
            misses.remove(id)
        } else {
            misses.insert(id)
        }
    }

    func remove(_ id: String) {
        values[id] = nil
        misses.remove(id)
    }

    func clear() {
        values = [:]
        misses = []
    }
}

final class CloudKitService: ArtBackend {
    static let containerID = "iCloud.com.artistfolio.app"

    let container = CKContainer(identifier: CloudKitService.containerID)
    let profileCache = ProfileCache()
    private let identity = IdentityStore()

    var publicDB: CKDatabase { container.publicCloudDatabase }
    var privateDB: CKDatabase { container.privateCloudDatabase }

    func currentUserID() async throws -> String? {
        if let cached = await identity.value { return cached }
        guard try await container.accountStatus() == .available else { return nil }
        let id = try await retrying { try await self.container.userRecordID().recordName }
        await identity.set(id)
        return id
    }

    func resetIdentity() async {
        await identity.set(nil)
        await profileCache.clear()
    }

    func requireUserID() async throws -> String {
        guard let id = try await currentUserID() else { throw AppError.iCloudRequired }
        return id
    }

    static func ownerID(creator: CKRecord.ID?, currentUserID: String?) -> String? {
        guard let name = creator?.recordName else { return nil }
        return name == CKCurrentUserDefaultName ? currentUserID : name
    }

    static func creatorPredicate(_ ownerID: String) -> NSPredicate {
        let reference = CKRecord.Reference(recordID: CKRecord.ID(recordName: ownerID), action: .none)
        return NSPredicate(format: "creatorUserRecordID == %@", reference)
    }

    func retrying<T>(_ operation: () async throws -> T) async throws -> T {
        var attempt = 0
        while true {
            do {
                return try await operation()
            } catch let error as CKError where attempt < 3 && Self.isTransient(error) {
                attempt += 1
                let delay = error.retryAfterSeconds ?? pow(2, Double(attempt))
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }

    private static func isTransient(_ error: CKError) -> Bool {
        [.requestRateLimited, .zoneBusy, .serviceUnavailable].contains(error.code)
    }

    func page(
        _ database: CKDatabase,
        query: CKQuery,
        keys: [CKRecord.FieldKey]?,
        limit: Int,
        cursor: CKQueryOperation.Cursor?
    ) async throws -> (records: [CKRecord], cursor: CKQueryOperation.Cursor?) {
        let response = try await retrying {
            if let cursor {
                return try await database.records(continuingMatchFrom: cursor, desiredKeys: keys, resultsLimit: limit)
            }
            return try await database.records(matching: query, desiredKeys: keys, resultsLimit: limit)
        }
        return (try response.matchResults.map { try $0.1.get() }, response.queryCursor)
    }

    func allRecords(_ database: CKDatabase, query: CKQuery, keys: [CKRecord.FieldKey]?) async throws -> [CKRecord] {
        var output: [CKRecord] = []
        var cursor: CKQueryOperation.Cursor?
        repeat {
            let result = try await page(database, query: query, keys: keys, limit: 200, cursor: cursor)
            output += result.records
            cursor = result.cursor
        } while cursor != nil
        return output
    }

    func delete(_ ids: [CKRecord.ID], from database: CKDatabase) async throws {
        for start in stride(from: 0, to: ids.count, by: 200) {
            let chunk = Array(ids[start..<min(start + 200, ids.count)])
            let response = try await retrying {
                try await database.modifyRecords(saving: [], deleting: chunk, savePolicy: .ifServerRecordUnchanged, atomically: false)
            }
            for (_, result) in response.deleteResults {
                if case .failure(let error) = result, (error as? CKError)?.code != .unknownItem {
                    throw error
                }
            }
        }
    }

    func deleteAccount() async throws {
        let owner = try await requireUserID()
        let mine = CKQuery(recordType: "Artwork", predicate: Self.creatorPredicate(owner))
        let artworks = try await allRecords(publicDB, query: mine, keys: [])
        try await delete(artworks.map(\.recordID), from: publicDB)

        try await delete(try await myReviewIDs(owner: owner), from: publicDB)

        let profileQuery = CKQuery(recordType: "Profile", predicate: Self.creatorPredicate(owner))
        let profiles = try await allRecords(publicDB, query: profileQuery, keys: [])
        try await delete(profiles.map(\.recordID), from: publicDB)

        for kind in LibraryKind.allCases {
            let query = CKQuery(recordType: kind.recordType, predicate: NSPredicate(value: true))
            let records = try await allRecords(privateDB, query: query, keys: [])
            try await delete(records.map(\.recordID), from: privateDB)
        }
        await profileCache.clear()
    }
}

private actor IdentityStore {
    private(set) var value: String?
    func set(_ newValue: String?) { value = newValue }
}
