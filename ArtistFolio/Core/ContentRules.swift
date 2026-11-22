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
    enum Kind: String { case email = "Email", instagram = "Instagram", website = "Website" }
    var kind: Kind
    var url: URL
    var id: String { kind.rawValue }

    var icon: String {
        switch kind {
        case .email: return "envelope"
        case .instagram: return "camera"
        case .website: return "globe"
        }
    }
}

enum ContactLinks {
    static func options(email: String, instagram: String, website: String) -> [ContactOption] {
        var result: [ContactOption] = []
        if let url = mailURL(email) { result.append(.init(kind: .email, url: url)) }
        if let url = instagramURL(instagram) { result.append(.init(kind: .instagram, url: url)) }
        if let url = websiteURL(website) { result.append(.init(kind: .website, url: url)) }
        return result
    }

    static func mailURL(_ value: String) -> URL? {
        let email = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard email.range(of: #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#, options: [.regularExpression, .caseInsensitive]) != nil else { return nil }
        return URL(string: "mailto:\(email)")
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
