import Foundation

enum SearchTokens {
    static func make(from values: [String]) -> [String] {
        Array(Set(values.flatMap(words))).sorted()
    }

    static func words(in text: String) -> [String] {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 2 }
    }
}

enum ContentFilter {
    private static let blockedTerms: Set<String> = [
        "fuck", "fucking", "shit", "cunt", "bitch", "asshole", "motherfucker",
        "porn", "porno", "xxx", "onlyfans", "escort", "escorts"
    ]

    static func isAllowed(_ values: String...) -> Bool {
        isAllowed(values)
    }

    static func isAllowed(_ values: [String]) -> Bool {
        !values.flatMap(SearchTokens.words).contains(where: blockedTerms.contains)
    }
}

struct ContactOption: Identifiable, Hashable {
    enum Kind: String { case email = "Email", whatsapp = "WhatsApp", call = "Call", text = "Text", instagram = "Instagram", website = "Website" }
    var kind: Kind
    var url: URL
    var id: String { kind.rawValue }

    var icon: String {
        switch kind {
        case .email: return "envelope"
        case .whatsapp: return "bubble.left.and.bubble.right"
        case .call: return "phone"
        case .text: return "message"
        case .instagram: return "camera"
        case .website: return "globe"
        }
    }
}

enum ContactLinks {
    static func options(email: String, instagram: String, website: String, phone: String = "", whatsapp: String = "") -> [ContactOption] {
        var result: [ContactOption] = []
        if let url = mailURL(email) { result.append(.init(kind: .email, url: url)) }
        if let url = whatsappURL(whatsapp) { result.append(.init(kind: .whatsapp, url: url)) }
        if let url = callURL(phone) { result.append(.init(kind: .call, url: url)) }
        if let url = textURL(phone) { result.append(.init(kind: .text, url: url)) }
        if let url = instagramURL(instagram) { result.append(.init(kind: .instagram, url: url)) }
        if let url = websiteURL(website) { result.append(.init(kind: .website, url: url)) }
        return result
    }

    static func mailURL(_ value: String) -> URL? {
        let email = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard email.range(of: #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#, options: [.regularExpression, .caseInsensitive]) != nil else { return nil }
        return URL(string: "mailto:\(email)")
    }

    /// Digits of a phone number, keeping a leading "+". Nil unless it has 7–15 digits and only phone punctuation.
    static func phoneNumber(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.range(of: #"^\+?[0-9 ()./-]+$"#, options: .regularExpression) != nil else { return nil }
        let digits = trimmed.filter(\.isASCII).filter(\.isNumber)
        guard (7...15).contains(digits.count) else { return nil }
        return (trimmed.hasPrefix("+") ? "+" : "") + digits
    }

    static func callURL(_ value: String) -> URL? {
        phoneNumber(value).flatMap { URL(string: "tel:\($0)") }
    }

    static func textURL(_ value: String) -> URL? {
        phoneNumber(value).flatMap { URL(string: "sms:\($0)") }
    }

    /// WhatsApp needs the full international number, so a leading "+" (country code) is required.
    static func whatsappURL(_ value: String, message: String? = nil) -> URL? {
        guard let number = phoneNumber(value), number.hasPrefix("+") else { return nil }
        var text = "https://wa.me/\(number.dropFirst())"
        if let message, !message.isEmpty {
            var allowed = CharacterSet.urlQueryAllowed
            allowed.remove(charactersIn: "&=+?#")
            text += "?text=" + (message.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")
        }
        return URL(string: text)
    }

    static func instagramURL(_ value: String) -> URL? {
        var handle = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if handle.hasPrefix("@") { handle.removeFirst() }
        guard handle.range(of: #"^[A-Za-z0-9._]{1,30}$"#, options: .regularExpression) != nil else { return nil }
        return URL(string: "https://www.instagram.com/\(handle)/")
    }

    static func websiteURL(_ value: String) -> URL? {
        var text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !text.contains(where: \.isWhitespace) else { return nil }
        if !text.contains("://") { text = "https://" + text }
        guard let components = URLComponents(string: text),
              components.scheme?.lowercased() == "https",
              components.user == nil, components.password == nil,
              let host = components.host, host.contains("."), !host.hasPrefix("."), !host.hasSuffix(".") else { return nil }
        return components.url
    }
}

/// Pre-filled messages from a buyer to an artist, by email or WhatsApp.
/// Sales happen outside the app, so these only open Mail or WhatsApp.
enum BuyerMessage {
    enum Channel: Hashable {
        case email(String)
        case whatsapp(String)

        var label: String {
            switch self {
            case .email: return "Mail"
            case .whatsapp: return "WhatsApp"
            }
        }
    }

    static let maxNoteLength = 300

    /// The ways a buyer can reach this artist, best first. Empty when no valid contact exists.
    static func channels(for artist: UserProfile?) -> [Channel] {
        guard let artist else { return [] }
        var result: [Channel] = []
        if ContactLinks.mailURL(artist.contactEmail) != nil { result.append(.email(artist.contactEmail)) }
        if ContactLinks.whatsappURL(artist.whatsapp) != nil { result.append(.whatsapp(artist.whatsapp)) }
        return result
    }

    static func offerURL(via channel: Channel, artistName: String, artwork: Artwork, amount: Double, note: String) -> URL? {
        let offer = amount.formatted(.currency(code: "USD").precision(.fractionLength(amount.rounded() == amount ? 0 : 2)))
        var body = "Hi \(firstName(artistName)),\n\nI'd like to offer \(offer) for \u{201C}\(artwork.title)\u{201D} (\(describe(artwork)))"
        body += artwork.priceOnRequest ? ", which I found on Artist Folio." : ", listed on Artist Folio at \(artwork.priceText)."
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { body += "\n\n" + String(trimmed.prefix(maxNoteLength)) }
        body += "\n\nThanks,"
        return url(via: channel, subject: "Offer for \u{201C}\(artwork.title)\u{201D}", body: body)
    }

    static func priceEnquiryURL(via channel: Channel, artistName: String, artwork: Artwork) -> URL? {
        let body = "Hi \(firstName(artistName)),\n\nCould you tell me the price of \u{201C}\(artwork.title)\u{201D} (\(describe(artwork)))? I found it on Artist Folio.\n\nThanks,"
        return url(via: channel, subject: "Price of \u{201C}\(artwork.title)\u{201D}", body: body)
    }

    /// Parses a buyer's typed amount; nil unless it is a positive, sensible number.
    static func amount(from text: String) -> Double? {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
        guard let value = Double(cleaned), value.isFinite, value > 0, value < 100_000_000 else { return nil }
        return value
    }

    static func firstName(_ name: String) -> String {
        name.split(separator: " ").first.map(String.init) ?? name
    }

    private static func describe(_ artwork: Artwork) -> String {
        "\(artwork.medium.rawValue), \(artwork.dimensions.displayString)"
    }

    private static func url(via channel: Channel, subject: String, body: String) -> URL? {
        switch channel {
        case .whatsapp(let number):
            return ContactLinks.whatsappURL(number, message: body)
        case .email(let email):
            guard let base = ContactLinks.mailURL(email) else { return nil }
            var allowed = CharacterSet.urlQueryAllowed
            allowed.remove(charactersIn: "&=+?#")
            func encode(_ value: String) -> String { value.addingPercentEncoding(withAllowedCharacters: allowed) ?? "" }
            return URL(string: "\(base.absoluteString)?subject=\(encode(subject))&body=\(encode(body))")
        }
    }
}
