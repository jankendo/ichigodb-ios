import Foundation

enum SupabaseError: LocalizedError, Equatable {
    case invalidURL
    case badStatus(Int, String)
    case missingData
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Supabase URLが不正です。"
        case .badStatus(let status, let body):
            return "Supabase request failed: \(status) \(body)"
        case .missingData:
            return "Supabase response is empty."
        case .encodingFailed:
            return "JSONの生成に失敗しました。"
        }
    }
}

struct PostgrestFilter: Equatable {
    var name: String
    var value: String

    static func eq(_ column: String, _ value: String) -> PostgrestFilter {
        PostgrestFilter(name: column, value: "eq.\(value)")
    }

    static func neq(_ column: String, _ value: String) -> PostgrestFilter {
        PostgrestFilter(name: column, value: "neq.\(value)")
    }

    static func isNull(_ column: String) -> PostgrestFilter {
        PostgrestFilter(name: column, value: "is.null")
    }

    static func notNull(_ column: String) -> PostgrestFilter {
        PostgrestFilter(name: column, value: "not.is.null")
    }

    static func ilike(_ column: String, _ value: String) -> PostgrestFilter {
        PostgrestFilter(name: column, value: "ilike.*\(value)*")
    }

    static func gte(_ column: String, _ value: String) -> PostgrestFilter {
        PostgrestFilter(name: column, value: "gte.\(value)")
    }

    static func lte(_ column: String, _ value: String) -> PostgrestFilter {
        PostgrestFilter(name: column, value: "lte.\(value)")
    }

    static func `in`(_ column: String, _ values: [String]) -> PostgrestFilter {
        let joined = values.joined(separator: ",")
        return PostgrestFilter(name: column, value: "in.(\(joined))")
    }

    static func or(_ expression: String) -> PostgrestFilter {
        PostgrestFilter(name: "or", value: "(\(expression))")
    }
}

final class SupabaseClient {
    let config: SupabaseConfig
    private let session: URLSession
    private let decoder: JSONDecoder

    init(config: SupabaseConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
        self.decoder = JSONDecoder()
    }

    func select<T: Decodable>(
        _ type: T.Type,
        table: String,
        columns: String = "*",
        filters: [PostgrestFilter] = [],
        order: String? = nil,
        range: ClosedRange<Int>? = nil
    ) async throws -> [T] {
        var queryItems = [URLQueryItem(name: "select", value: columns)]
        queryItems.append(contentsOf: filters.map { URLQueryItem(name: $0.name, value: $0.value) })
        if let order {
            queryItems.append(URLQueryItem(name: "order", value: order))
        }
        var request = try request(path: "rest/v1/\(table)", queryItems: queryItems, method: "GET")
        if let range {
            request.setValue("\(range.lowerBound)-\(range.upperBound)", forHTTPHeaderField: "Range")
            request.setValue("items", forHTTPHeaderField: "Range-Unit")
        }
        let data = try await data(for: request)
        return try decoder.decode([T].self, from: data)
    }

    func selectAll<T: Decodable>(
        _ type: T.Type,
        table: String,
        columns: String = "*",
        filters: [PostgrestFilter] = [],
        order: String? = nil,
        pageSize: Int = 1000,
        maxRows: Int = 20000
    ) async throws -> [T] {
        let normalizedPageSize = max(1, pageSize)
        var start = 0
        var rows = [T]()
        while start < maxRows {
            let end = min(start + normalizedPageSize - 1, maxRows - 1)
            let page = try await select(
                T.self,
                table: table,
                columns: columns,
                filters: filters,
                order: order,
                range: start...end
            )
            rows.append(contentsOf: page)
            if page.count < normalizedPageSize {
                break
            }
            start += normalizedPageSize
        }
        return rows
    }

    func insertJSON<T: Decodable>(
        _ type: T.Type,
        table: String,
        payload: [String: Any],
        returning: Bool = true
    ) async throws -> [T] {
        var request = try request(path: "rest/v1/\(table)", method: "POST")
        request.httpBody = try jsonData(payload)
        request.setValue(returning ? "return=representation" : "return=minimal", forHTTPHeaderField: "Prefer")
        let data = try await data(for: request, allowEmpty: !returning)
        guard returning else { return [] }
        return try decoder.decode([T].self, from: data)
    }

    func updateJSON<T: Decodable>(
        _ type: T.Type,
        table: String,
        payload: [String: Any],
        filters: [PostgrestFilter],
        returning: Bool = true
    ) async throws -> [T] {
        var queryItems = filters.map { URLQueryItem(name: $0.name, value: $0.value) }
        var request = try request(path: "rest/v1/\(table)", queryItems: queryItems, method: "PATCH")
        request.httpBody = try jsonData(payload)
        request.setValue(returning ? "return=representation" : "return=minimal", forHTTPHeaderField: "Prefer")
        let data = try await data(for: request, allowEmpty: !returning)
        guard returning else { return [] }
        return try decoder.decode([T].self, from: data)
    }

    func upsertJSON<T: Decodable>(
        _ type: T.Type,
        table: String,
        payload: [String: Any],
        onConflict: String? = nil,
        returning: Bool = true
    ) async throws -> [T] {
        let queryItems = onConflict.map { [URLQueryItem(name: "on_conflict", value: $0)] } ?? []
        var request = try request(path: "rest/v1/\(table)", queryItems: queryItems, method: "POST")
        request.httpBody = try jsonData(payload)
        request.setValue(
            returning ? "resolution=merge-duplicates,return=representation" : "resolution=merge-duplicates,return=minimal",
            forHTTPHeaderField: "Prefer"
        )
        let data = try await data(for: request, allowEmpty: !returning)
        guard returning else { return [] }
        return try decoder.decode([T].self, from: data)
    }

    func deleteRows(table: String, filters: [PostgrestFilter]) async throws {
        let queryItems = filters.map { URLQueryItem(name: $0.name, value: $0.value) }
        let request = try request(path: "rest/v1/\(table)", queryItems: queryItems, method: "DELETE")
        _ = try await data(for: request, allowEmpty: true)
    }

    func softDelete<T: Decodable>(_ type: T.Type, table: String, id: String) async throws -> [T] {
        try await updateJSON(
            type,
            table: table,
            payload: ["deleted_at": ISO8601DateFormatter().string(from: Date())],
            filters: [.eq("id", id)]
        )
    }

    func restore<T: Decodable>(_ type: T.Type, table: String, id: String) async throws -> [T] {
        try await updateJSON(type, table: table, payload: ["deleted_at": NSNull()], filters: [.eq("id", id)])
    }

    func uploadObject(bucket: String, path: String, data: Data, contentType: String) async throws {
        var request = try storageObjectRequest(bucket: bucket, path: path, method: "POST")
        request.httpBody = data
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("false", forHTTPHeaderField: "x-upsert")
        _ = try await self.data(for: request, allowEmpty: true)
    }

    func downloadObject(bucket: String, path: String) async throws -> Data {
        let request = try storageObjectRequest(bucket: bucket, path: path, method: "GET")
        return try await data(for: request)
    }

    func deleteObject(bucket: String, path: String) async throws {
        var request = try request(path: "storage/v1/object/\(bucket)", method: "DELETE")
        request.httpBody = try jsonData(["prefixes": [path]])
        _ = try await data(for: request, allowEmpty: true)
    }

    func updateObjectMetadata(bucket: String, path: String, metadata: [String: Any]) async throws {
        var request = try request(path: "storage/v1/object/info/\(bucket)/\(Self.escapedObjectPath(path))", method: "POST")
        request.httpBody = try jsonData(metadata)
        _ = try await data(for: request, allowEmpty: true)
    }

    func signedURL(bucket: String, path: String, expiresIn: Int = 60 * 60 * 12) async throws -> URL {
        var request = try request(path: "storage/v1/object/sign/\(bucket)/\(Self.escapedObjectPath(path))", method: "POST")
        request.httpBody = try jsonData(["expiresIn": expiresIn])
        let data = try await self.data(for: request)
        let response = try decoder.decode(SignedURLResponse.self, from: data)
        let signed = response.signedURL ?? response.signedUrl
        guard let signed else { throw SupabaseError.missingData }
        if signed.hasPrefix("http"), let url = URL(string: signed) {
            return url
        }
        guard let url = URL(string: signed, relativeTo: config.url)?.absoluteURL else {
            throw SupabaseError.invalidURL
        }
        return url
    }

    func request(
        path: String,
        queryItems: [URLQueryItem] = [],
        method: String
    ) throws -> URLRequest {
        let base = config.url.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard var components = URLComponents(string: "\(base)/\(path)") else {
            throw SupabaseError.invalidURL
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else {
            throw SupabaseError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    func storageObjectRequest(bucket: String, path: String, method: String) throws -> URLRequest {
        try request(path: "storage/v1/object/\(bucket)/\(Self.escapedObjectPath(path))", method: method)
    }

    private func data(for request: URLRequest, allowEmpty: Bool = false) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SupabaseError.missingData
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw SupabaseError.badStatus(http.statusCode, body)
        }
        if data.isEmpty && !allowEmpty {
            throw SupabaseError.missingData
        }
        return data
    }

    private func jsonData(_ payload: [String: Any]) throws -> Data {
        guard JSONSerialization.isValidJSONObject(payload) else {
            throw SupabaseError.encodingFailed
        }
        return try JSONSerialization.data(withJSONObject: payload, options: [])
    }

    private static func escapedObjectPath(_ path: String) -> String {
        path
            .split(separator: "/")
            .map { segment in
                String(segment).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String(segment)
            }
            .joined(separator: "/")
    }
}

private struct SignedURLResponse: Decodable {
    var signedURL: String?
    var signedUrl: String?
}
