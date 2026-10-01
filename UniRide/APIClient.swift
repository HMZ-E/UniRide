import Foundation
import Security

struct APIError: LocalizedError {
    let message: String
    var status: Int? = nil
    var errorDescription: String? { message }
}
struct APIClient {
    let endpoint: String
    let token: String?
    static let decoder: JSONDecoder = { let d = JSONDecoder(); d.dateDecodingStrategy = .secondsSince1970; return d }()
    static let encoder: JSONEncoder = { let e = JSONEncoder(); e.dateEncodingStrategy = .secondsSince1970; return e }()

    func request<T: Decodable>(_ path: String, method: String = "GET", body: [String: Any]? = nil) async throws -> T {
        guard let url = URL(string: endpoint + path), let host = url.host else { throw APIError(message: "Set your server address first.") }
        let octets = host.split(separator: ".", omittingEmptySubsequences: false).compactMap { Int($0) }
        let ipv4 = octets.count == 4 && octets.allSatisfy { (0...255).contains($0) }
        let local = host == "localhost" || host.hasSuffix(".local") || (ipv4 && (octets[0] == 127 || octets[0] == 10 || (octets[0] == 192 && octets[1] == 168) || (octets[0] == 172 && (16...31).contains(octets[1]))))
        guard url.user == nil, url.password == nil else { throw APIError(message: "Set your server address first.") }
        #if DEBUG
        guard url.scheme == "https" || (url.scheme == "http" && local) else { throw APIError(message: "Use HTTPS, or a local development server.") }
        #else
        guard url.scheme == "https" else { throw APIError(message: "Use an HTTPS server.") }
        #endif
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body { request.httpBody = try JSONSerialization.data(withJSONObject: body) }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError(message: "Unable to connect to the server.") }
        guard (200..<300).contains(http.statusCode) else {
            let error = (try? JSONSerialization.jsonObject(with: data)) as? [String: String]
            throw APIError(message: error?["error"] ?? "Unable to complete the request.", status: http.statusCode)
        }
        return try Self.decoder.decode(T.self, from: data)
    }
}

enum SessionKeychain {
    static func read(_ server: String) -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "HMZ.UniRide.session", kSecAttrAccount as String: server, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    static func save(_ token: String?, server: String) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "HMZ.UniRide.session", kSecAttrAccount as String: server]
        SecItemDelete(query as CFDictionary)
        guard let token else { return }
        var item = query
        item[kSecValueData as String] = Data(token.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }
}
