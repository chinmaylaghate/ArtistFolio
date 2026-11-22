import CloudKit
import Foundation

// MARK: - CloudKit messaging + commissions

extension CloudKitService {

    // MARK: Conversations

    func conversations() async throws -> [Conversation] {
        let me = try await requireUserID()
        let myName = (try? await profile(ownerID: me))?.displayName ?? "Me"
        // Fetch messages where I'm a participant (last 200 messages)
        let pred = NSPredicate(format: "participant1 == %@ OR participant2 == %@", me, me)
        let query = CKQuery(recordType: "Message", predicate: pred)
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let result = try await page(publicDB, query: query, keys: nil, limit: 200, cursor: nil)
        // Group by conversationID, pick latest per conversation
        var latestByConv: [String: CKRecord] = [:]
        for record in result.records {
            guard let convID = record["conversationID"] as? String else { continue }
            if latestByConv[convID] == nil { latestByConv[convID] = record }
        }
        var convos: [Conversation] = []
        for (convID, record) in latestByConv {
            guard let p1 = record["participant1"] as? String,
                  let p2 = record["participant2"] as? String,
                  let text = record["text"] as? String else { continue }
            let otherID = p1 == me ? p2 : p1
            let otherName = (try? await profile(ownerID: otherID))?.displayName ?? "Unknown"
            let otherAvatar = (try? await profile(ownerID: otherID))?.avatarURL
            convos.append(Conversation(
                id: convID,
                otherUserID: otherID,
                otherName: otherName,
                otherAvatarURL: otherAvatar,
                lastMessage: text,
                lastDate: record.creationDate ?? Date()
            ))
        }
        return convos.sorted { $0.lastDate > $1.lastDate }
    }

    // MARK: Messages

    func messages(conversationID: String) async throws -> [Message] {
        let me = try await requireUserID()
        let pred = NSPredicate(format: "conversationID == %@", conversationID)
        let query = CKQuery(recordType: "Message", predicate: pred)
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        let records = try await allRecords(publicDB, query: query, keys: nil)
        return records.compactMap { record -> Message? in
            guard let sender = record["senderID"] as? String,
                  let senderName = record["senderName"] as? String,
                  let text = record["text"] as? String else { return nil }
            return Message(
                id: record.recordID.recordName,
                conversationID: conversationID,
                senderID: sender,
                senderName: senderName,
                text: text,
                date: record.creationDate ?? Date()
            )
        }
    }

    func sendMessage(to recipientID: String, recipientName: String, text: String) async throws -> Message {
        let me = try await requireUserID()
        let myProfile = try await profile(ownerID: me)
        let myName = myProfile?.displayName ?? "Me"
        let convID = Conversation.conversationID(me, recipientID)
        let record = CKRecord(recordType: "Message")
        record["conversationID"] = convID
        record["participant1"] = [me, recipientID].sorted()[0]
        record["participant2"] = [me, recipientID].sorted()[1]
        record["senderID"] = me
        record["senderName"] = myName
        record["recipientID"] = recipientID
        record["text"] = text
        let saved = try await retrying { try await self.publicDB.save(record) }
        return Message(
            id: saved.recordID.recordName,
            conversationID: convID,
            senderID: me,
            senderName: myName,
            text: text,
            date: saved.creationDate ?? Date()
        )
    }

    // MARK: Commissions

    func commissionRequests() async throws -> [CommissionRequest] {
        let me = try await requireUserID()
        let pred = NSPredicate(format: "artistID == %@ OR collectorID == %@", me, me)
        let query = CKQuery(recordType: "CommissionRequest", predicate: pred)
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let records = try await allRecords(publicDB, query: query, keys: nil)
        return records.compactMap { record -> CommissionRequest? in
            guard let artistID = record["artistID"] as? String,
                  let artistName = record["artistName"] as? String,
                  let collectorID = record["collectorID"] as? String,
                  let collectorName = record["collectorName"] as? String,
                  let description = record["description"] as? String,
                  let budget = record["budget"] as? Double,
                  let statusRaw = record["status"] as? String,
                  let status = CommissionStatus(rawValue: statusRaw) else { return nil }
            let styleStrings = record["styles"] as? [String] ?? []
            let styles = styleStrings.compactMap(ArtworkStyle.init(rawValue:))
            return CommissionRequest(
                id: record.recordID.recordName,
                artistID: artistID,
                artistName: artistName,
                collectorID: collectorID,
                collectorName: collectorName,
                description: description,
                budget: budget,
                styles: styles,
                status: status,
                date: record.creationDate ?? Date()
            )
        }
    }

    func sendCommissionRequest(artistID: String, artistName: String, description: String, budget: Double, styles: [ArtworkStyle]) async throws -> CommissionRequest {
        let me = try await requireUserID()
        let myProfile = try await profile(ownerID: me)
        let myName = myProfile?.displayName ?? "Collector"
        let record = CKRecord(recordType: "CommissionRequest")
        record["artistID"] = artistID
        record["artistName"] = artistName
        record["collectorID"] = me
        record["collectorName"] = myName
        record["description"] = description
        record["budget"] = budget
        record["styles"] = styles.map(\.rawValue)
        record["status"] = CommissionStatus.pending.rawValue
        let saved = try await retrying { try await self.publicDB.save(record) }
        return CommissionRequest(
            id: saved.recordID.recordName,
            artistID: artistID,
            artistName: artistName,
            collectorID: me,
            collectorName: myName,
            description: description,
            budget: budget,
            styles: styles,
            status: .pending,
            date: saved.creationDate ?? Date()
        )
    }

    func updateCommissionRequest(id: String, status: CommissionStatus) async throws {
        let recordID = CKRecord.ID(recordName: id)
        let record = try await retrying { try await self.publicDB.record(for: recordID) }
        record["status"] = status.rawValue
        _ = try await retrying { try await self.publicDB.save(record) }
    }
}
