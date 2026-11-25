import Foundation

/// Shareable web links that open the app (universal links) or, without the app,
/// a page on artistfolioapp.com that points to the App Store.
///
///   https://artistfolioapp.com/a/<artwork record name>
///   https://artistfolioapp.com/artist/<artist user record name>
enum AppLink: Hashable, Identifiable {
    case artwork(id: String)
    case artist(id: String)

    static let host = "artistfolioapp.com"

    var id: String {
        switch self {
        case .artwork(let id): return "artwork-\(id)"
        case .artist(let id): return "artist-\(id)"
        }
    }

    var url: URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = Self.host
        switch self {
        case .artwork(let id): components.path = "/a/\(id)"
        case .artist(let id): components.path = "/artist/\(id)"
        }
        return components.url ?? URL(string: "https://\(Self.host)")!
    }

    /// Parses an incoming link. Accepts the bare and www host, with or without a trailing slash.
    init?(url: URL) {
        guard url.scheme?.lowercased() == "https",
              let host = url.host?.lowercased(),
              host == Self.host || host == "www.\(Self.host)" else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count == 2, let id = Self.validID(parts[1]) else { return nil }
        switch parts[0].lowercased() {
        case "a": self = .artwork(id: id)
        case "artist": self = .artist(id: id)
        default: return nil
        }
    }

    /// CloudKit record names: letters, digits, "-" and "_", at most 255 characters.
    private static func validID(_ value: String) -> String? {
        guard !value.isEmpty, value.count <= 255,
              value.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil else { return nil }
        return value
    }
}
