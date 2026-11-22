import CloudKit
import Foundation

enum ProfileMapper {
    static func profile(from record: CKRecord, ownerID: String, avatarURL: URL?) -> UserProfile? {
        guard let name = record["displayName"] as? String, !name.isEmpty,
              let role = (record["role"] as? String).flatMap(UserRole.init(rawValue:)) else { return nil }
        return UserProfile(
            id: ownerID,
            recordName: record.recordID.recordName,
            displayName: name,
            bio: record["bio"] as? String ?? "",
            role: role,
            location: record["location"] as? String ?? "",
            website: record["website"] as? String ?? "",
            instagramHandle: record["instagramHandle"] as? String ?? "",
            contactEmail: record["contactEmail"] as? String ?? "",
            acceptsCommissions: (record["acceptsCommissions"] as? Int64 ?? 0) == 1,
            avatarURL: avatarURL
        )
    }

    static func apply(_ profile: UserProfile, to record: CKRecord) {
        record["displayName"] = profile.displayName
        record["bio"] = profile.bio
        record["role"] = profile.role.rawValue
        record["location"] = profile.location
        record["website"] = profile.website
        record["instagramHandle"] = profile.instagramHandle
        record["contactEmail"] = profile.contactEmail
        record["acceptsCommissions"] = (profile.acceptsCommissions ? 1 : 0) as Int64
        record["searchTokens"] = SearchTokens.make(from: [profile.displayName, profile.location])
    }
}

extension CloudKitService {
    func profile(ownerID: String) async throws -> UserProfile? {
        let cached = await profileCache.lookup(ownerID)
        if cached.found { return cached.profile }
        let query = CKQuery(recordType: "Profile", predicate: Self.creatorPredicate(ownerID))
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        let result = try await page(publicDB, query: query, keys: nil, limit: 1, cursor: nil)
        let profile = result.records.first.flatMap { mapProfile($0, ownerID: ownerID) }
        await profileCache.store(profile, id: ownerID)
        return profile
    }

    func saveProfile(_ profile: UserProfile, avatar: Data?) async throws -> UserProfile {
        let owner = try await requireUserID()
        guard ContentFilter.isAllowed(profile.displayName, profile.bio, profile.location) else {
            throw AppError.objectionableContent
        }
        await profileCache.remove(owner)
        let existing = try await self.profile(ownerID: owner)
        let record: CKRecord
        if let name = existing?.recordName {
            let id = CKRecord.ID(recordName: name)
            record = try await retrying { try await self.publicDB.record(for: id) }
        } else {
            record = CKRecord(recordType: "Profile")
        }
        ProfileMapper.apply(profile, to: record)
        var temporary: URL?
        if let avatar {
            let url = try ImageStore.temporaryFile(avatar)
            temporary = url
            record["avatar"] = CKAsset(fileURL: url)
        }
        defer { temporary.map { try? FileManager.default.removeItem(at: $0) } }
        let saved = try await retrying { try await self.publicDB.save(record) }
        guard let output = mapProfile(saved, ownerID: owner) else { throw CKError(.internalError) }
        await profileCache.store(output, id: owner)
        return output
    }

    func searchProfiles(text: String) async throws -> [UserProfile] {
        let words = SearchTokens.words(in: text)
        guard !words.isEmpty else { return [] }
        var predicates = words.map { NSPredicate(format: "searchTokens CONTAINS %@", $0) }
        predicates.append(NSPredicate(format: "role == %@", UserRole.artist.rawValue))
        let query = CKQuery(recordType: "Profile", predicate: NSCompoundPredicate(andPredicateWithSubpredicates: predicates))
        let me = try? await currentUserID()
        let result = try await page(publicDB, query: query, keys: nil, limit: 20, cursor: nil)
        return result.records.compactMap { record in
            guard let owner = Self.ownerID(creator: record.creatorUserRecordID, currentUserID: me) else { return nil }
            return mapProfile(record, ownerID: owner)
        }
    }

    func profiles(ownerIDs: Set<String>) async -> [String: UserProfile] {
        await withTaskGroup(of: UserProfile?.self) { group in
            for id in ownerIDs {
                group.addTask { try? await self.profile(ownerID: id) }
            }
            var output: [String: UserProfile] = [:]
            for await profile in group {
                if let profile { output[profile.id] = profile }
            }
            return output
        }
    }

    private func mapProfile(_ record: CKRecord, ownerID: String) -> UserProfile? {
        let avatar = (record["avatar"] as? CKAsset).flatMap {
            ImageStore.cache($0, key: "avatar-\(record.recordID.recordName)-\(record.recordChangeTag ?? "")")
        }
        return ProfileMapper.profile(from: record, ownerID: ownerID, avatarURL: avatar)
    }
}
