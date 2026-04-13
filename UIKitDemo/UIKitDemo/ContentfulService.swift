import Foundation

/// Fetches Contentful entries as `[String: Any]` dictionaries for use with the Optimization SDK.
///
/// Uses raw URLSession calls to the Contentful CDN API with manual link resolution,
/// because the Optimization SDK requires `[String: Any]` dictionaries and the Contentful
/// Swift SDK returns typed objects that would need conversion.
struct ContentfulService {

    enum ServiceError: LocalizedError {
        case invalidURL
        case invalidResponse
        case noEntryFound

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid Contentful URL"
            case .invalidResponse: return "Invalid response from Contentful"
            case .noEntryFound: return "Entry not found"
            }
        }
    }

    // MARK: - Public API

    /// Fetch a single entry by ID with link resolution.
    static func fetchEntry(id: String, include: Int = 10) async throws -> [String: Any] {
        let url = try buildURL(params: [
            "sys.id": id,
            "include": "\(include)",
        ])

        let (data, _) = try await URLSession.shared.data(from: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["items"] as? [[String: Any]],
              let entry = items.first
        else {
            throw ServiceError.noEntryFound
        }

        let includes = json["includes"] as? [String: Any]
        return resolveLinks(in: entry, includes: includes)
    }

    /// Fetch entries by content type with optional ordering.
    static func fetchEntries(
        contentType: String,
        order: String? = nil,
        include: Int = 2
    ) async throws -> [[String: Any]] {
        var params: [String: String] = [
            "content_type": contentType,
            "include": "\(include)",
        ]
        if let order {
            params["order"] = order
        }

        let url = try buildURL(params: params)

        let (data, _) = try await URLSession.shared.data(from: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["items"] as? [[String: Any]]
        else {
            throw ServiceError.invalidResponse
        }

        let includes = json["includes"] as? [String: Any]
        return items.map { resolveLinks(in: $0, includes: includes) }
    }

    // MARK: - URL Building

    private static func buildURL(params: [String: String]) throws -> URL {
        let base = "\(AppConfig.contentfulBaseUrl)/spaces/\(AppConfig.contentfulSpaceId)/environments/\(AppConfig.contentfulEnvironment)/entries"

        var components = URLComponents(string: base)
        components?.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        components?.queryItems?.append(URLQueryItem(name: "access_token", value: AppConfig.contentfulAccessToken))

        guard let url = components?.url else {
            throw ServiceError.invalidURL
        }
        return url
    }

    // MARK: - Link Resolution

    private static func resolveLinks(in entry: [String: Any], includes: [String: Any]?) -> [String: Any] {
        var lookup: [String: [String: Any]] = [:]

        if let includeEntries = includes?["Entry"] as? [[String: Any]] {
            for e in includeEntries {
                if let sys = e["sys"] as? [String: Any], let id = sys["id"] as? String {
                    lookup[id] = e
                }
            }
        }

        if let includeAssets = includes?["Asset"] as? [[String: Any]] {
            for a in includeAssets {
                if let sys = a["sys"] as? [String: Any], let id = sys["id"] as? String {
                    lookup[id] = a
                }
            }
        }

        return resolveValue(entry, lookup: lookup) as? [String: Any] ?? entry
    }

    private static func resolveValue(_ value: Any, lookup: [String: [String: Any]], depth: Int = 0) -> Any {
        guard depth < 10 else { return value }

        if let dict = value as? [String: Any] {
            if let sys = dict["sys"] as? [String: Any],
               let type = sys["type"] as? String,
               type == "Link",
               let id = sys["id"] as? String,
               let resolved = lookup[id] {
                return resolveValue(resolved, lookup: lookup, depth: depth + 1)
            }

            var result: [String: Any] = [:]
            for (key, val) in dict {
                result[key] = resolveValue(val, lookup: lookup, depth: depth + 1)
            }
            return result
        } else if let array = value as? [Any] {
            return array.map { resolveValue($0, lookup: lookup, depth: depth + 1) }
        }

        return value
    }
}
