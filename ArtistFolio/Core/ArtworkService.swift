import CloudKit
import Foundation

enum ArtworkMapper {
    static let listKeys: [CKRecord.FieldKey] = [
        "title", "details", "price", "status", "medium", "style",
        "width", "height", "unit", "year", "tags", "thumbnail", "priceOnRequest",
        "careNote", "showCareTips", "series", "viewCount", "likeCount"
    ]

    static func artwork(from record: CKRecord, ownerID: String, thumbnailURL: URL?) -> Artwork? {
        guard let title = record["title"] as? String, !title.isEmpty,
              let price = record["price"] as? Double, price.isFinite, price >= 0,
              let status = (record["status"] as? String).flatMap(ArtworkStatus.init(rawValue:)),
              let medium = (record["medium"] as? String).flatMap(ArtworkMedium.init(rawValue:)),
              let style = (record["style"] as? String).flatMap(ArtworkStyle.init(rawValue:)),
              let width = record["width"] as? Double, width.isFinite,
              let height = record["height"] as? Double, height.isFinite,
              let unit = record["unit"] as? String,
              let year = record["year"] as? Int64 else { return nil }
        return Artwork(
            id: record.recordID.recordName,
            artistId: ownerID,
            title: title,
            details: record["details"] as? String ?? "",
            price: price,
            status: status,
            medium: medium,
            style: style,
            dimensions: ArtworkDimensions(width: width, height: height, unit: unit),
            year: Int(year),
            tags: record["tags"] as? [String] ?? [],
            thumbnailURL: thumbnailURL,
            createdAt: record.creationDate ?? Date(),
            priceOnRequest: (record["priceOnRequest"] as? Int64 ?? 0) == 1,
            careNote: record["careNote"] as? String ?? "",
            // Listings saved before 1.1 have no value; show the standard tips for them.
            showCareTips: (record["showCareTips"] as? Int64 ?? 1) == 1,
            series: record["series"] as? String ?? "",
            viewCount: Int(record["viewCount"] as? Int64 ?? 0),
            likeCount: Int(record["likeCount"] as? Int64 ?? 0)
        )
    }

    static func apply(_ artwork: Artwork, to record: CKRecord) {
        record["title"] = artwork.title
        record["details"] = artwork.details
        record["price"] = artwork.priceOnRequest ? 0 : artwork.price
        record["priceOnRequest"] = Int64(artwork.priceOnRequest ? 1 : 0)
        record["careNote"] = CareGuide.cleanNote(artwork.careNote)
        record["showCareTips"] = Int64(artwork.showCareTips ? 1 : 0)
        record["series"] = String(artwork.series.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Artwork.maxSeriesLength))
        record["sizeClass"] = artwork.dimensions.sizeClass.rawValue
        record["status"] = artwork.status.rawValue
        record["medium"] = artwork.medium.rawValue
        record["style"] = artwork.style.rawValue
        record["width"] = artwork.dimensions.width
        record["height"] = artwork.dimensions.height
        record["unit"] = artwork.dimensions.unit
        record["year"] = Int64(artwork.year)
        record["tags"] = artwork.tags
        record["searchTokens"] = SearchTokens.make(
            from: [artwork.title, artwork.medium.rawValue, artwork.style.rawValue, artwork.series] + artwork.tags
        )
    }

    static func predicate(for filters: ArtworkFilters) -> NSPredicate {
        var parts = SearchTokens.words(in: filters.text).map {
            NSPredicate(format: "searchTokens CONTAINS %@", $0)
        }
        if !filters.styles.isEmpty {
            parts.append(NSPredicate(format: "style IN %@", filters.styles.map(\.rawValue)))
        }
        if !filters.mediums.isEmpty {
            parts.append(NSPredicate(format: "medium IN %@", filters.mediums.map(\.rawValue)))
        }
        if !filters.sizes.isEmpty {
            parts.append(NSPredicate(format: "sizeClass IN %@", filters.sizes.map(\.rawValue)))
        }
        if filters.minPrice > 0 {
            parts.append(NSPredicate(format: "price >= %f", filters.minPrice))
        }
        if filters.maxPrice < ArtworkFilters.priceCeiling {
            parts.append(NSPredicate(format: "price <= %f", filters.maxPrice))
            // Price-on-request pieces are stored at 0; a price limit should not match them.
            if filters.minPrice <= 0 { parts.append(NSPredicate(format: "price > 0")) }
        }
        return parts.isEmpty ? NSPredicate(value: true) : NSCompoundPredicate(andPredicateWithSubpredicates: parts)
    }

    static func sort(for option: ArtworkFilters.SortOption) -> NSSortDescriptor {
        switch option {
        case .newest: return NSSortDescriptor(key: "creationDate", ascending: false)
        case .priceAsc: return NSSortDescriptor(key: "price", ascending: true)
        case .priceDesc: return NSSortDescriptor(key: "price", ascending: false)
        }
    }
}

extension CloudKitService {
    func artworks(filters: ArtworkFilters, cursor: CKQueryOperation.Cursor?) async throws -> ArtworkPage {
        let query = CKQuery(recordType: "Artwork", predicate: ArtworkMapper.predicate(for: filters))
        query.sortDescriptors = [ArtworkMapper.sort(for: filters.sortBy)]
        let result = try await page(publicDB, query: query, keys: ArtworkMapper.listKeys, limit: 24, cursor: cursor)
        return ArtworkPage(items: filters.ordered(await hydrate(result.records)), cursor: result.cursor)
    }

    func artworks(ownerID: String) async throws -> [Artwork] {
        let query = CKQuery(recordType: "Artwork", predicate: Self.creatorPredicate(ownerID))
        query.sortDescriptors = [ArtworkMapper.sort(for: .newest)]
        let records = try await allRecords(publicDB, query: query, keys: ArtworkMapper.listKeys)
        return await hydrate(records)
    }

    func artworks(ids: [String]) async throws -> [Artwork] {
        guard !ids.isEmpty else { return [] }
        var records: [CKRecord] = []
        for start in stride(from: 0, to: ids.count, by: 100) {
            let chunk = ids[start..<min(start + 100, ids.count)].map { CKRecord.ID(recordName: $0) }
            let response = try await retrying {
                try await publicDB.records(for: chunk, desiredKeys: ArtworkMapper.listKeys)
            }
            records += response.values.compactMap { try? $0.get() }
        }
        return await hydrate(records)
    }

    func fullImages(artworkID: String) async throws -> [URL] {
        let id = CKRecord.ID(recordName: artworkID)
        let response = try await retrying { try await publicDB.records(for: [id], desiredKeys: ["images"]) }
        guard let record = try response[id]?.get(), let assets = record["images"] as? [CKAsset] else { return [] }
        let tag = record.recordChangeTag ?? ""
        return assets.enumerated().compactMap { index, asset in
            ImageStore.cache(asset, key: "full-\(artworkID)-\(tag)-\(index)")
        }
    }

    func saveArtwork(_ artwork: Artwork, images: [ProcessedImage]?) async throws -> Artwork {
        let owner = try await requireUserID()
        guard ContentFilter.isAllowed([artwork.title, artwork.details, artwork.careNote, artwork.series] + artwork.tags) else {
            throw AppError.objectionableContent
        }
        let id = CKRecord.ID(recordName: artwork.id)
        let record: CKRecord
        if !artwork.artistId.isEmpty {
            guard artwork.artistId == owner else { throw AppError.notOwner }
            record = try await retrying { try await self.publicDB.record(for: id) }
            guard Self.ownerID(creator: record.creatorUserRecordID, currentUserID: owner) == owner else {
                throw AppError.notOwner
            }
        } else {
            record = CKRecord(recordType: "Artwork", recordID: id)
        }
        ArtworkMapper.apply(artwork, to: record)

        var temporary: [URL] = []
        defer { temporary.forEach { try? FileManager.default.removeItem(at: $0) } }
        if let images, let first = images.first {
            let thumbnail = try ImageStore.temporaryFile(first.thumbnail)
            temporary.append(thumbnail)
            let fullURLs = try images.map { try ImageStore.temporaryFile($0.full) }
            temporary += fullURLs
            record["thumbnail"] = CKAsset(fileURL: thumbnail)
            record["images"] = fullURLs.map(CKAsset.init(fileURL:))
        }
        let saved = try await retrying { try await self.publicDB.save(record) }
        guard let output = await hydrate([saved]).first else { throw CKError(.internalError) }
        return output
    }

    func deleteArtwork(id: String) async throws {
        let owner = try await requireUserID()
        let recordID = CKRecord.ID(recordName: id)
        let record = try await retrying { try await self.publicDB.record(for: recordID) }
        guard Self.ownerID(creator: record.creatorUserRecordID, currentUserID: owner) == owner else {
            throw AppError.notOwner
        }
        try await delete([recordID], from: publicDB)
    }

    func backfillSizeClasses() async throws -> Int {
        let owner = try await requireUserID()
        let query = CKQuery(recordType: "Artwork", predicate: Self.creatorPredicate(owner))
        let records = try await allRecords(publicDB, query: query, keys: ["width", "height", "unit", "sizeClass"])
        let missing = records.compactMap { record -> CKRecord? in
            guard record["sizeClass"] == nil,
                  let width = record["width"] as? Double, let height = record["height"] as? Double,
                  let unit = record["unit"] as? String else { return nil }
            record["sizeClass"] = ArtworkDimensions(width: width, height: height, unit: unit).sizeClass.rawValue
            return record
        }
        guard !missing.isEmpty else { return 0 }
        _ = try await retrying {
            try await publicDB.modifyRecords(saving: missing, deleting: [], savePolicy: .changedKeys, atomically: false)
        }
        return missing.count
    }

    private func hydrate(_ records: [CKRecord]) async -> [Artwork] {
        let me = try? await currentUserID()
        let owners = records.compactMap { Self.ownerID(creator: $0.creatorUserRecordID, currentUserID: me) }
        let profiles = await profiles(ownerIDs: Set(owners))
        return records.compactMap { record in
            guard let owner = Self.ownerID(creator: record.creatorUserRecordID, currentUserID: me),
                  let profile = profiles[owner], profile.role == .artist else { return nil }
            let thumbnail = (record["thumbnail"] as? CKAsset).flatMap {
                ImageStore.cache($0, key: "thumb-\(record.recordID.recordName)-\(record.recordChangeTag ?? "")")
            }
            var artwork = ArtworkMapper.artwork(from: record, ownerID: owner, thumbnailURL: thumbnail)
            artwork?.artistName = profile.displayName
            return artwork
        }
    }
}
