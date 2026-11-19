import Foundation
import RuuviCloud

/// Reuses connections across zoom requests. Never logs tokens, sensor IDs or history.
@available(iOS 15.0, macOS 12.0, *)
enum CloudGraphTransport {
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 35
        configuration.httpMaximumConnectionsPerHost = 4
        return URLSession(configuration: configuration)
    }()

    private struct Envelope: Decodable {
        let result: String
        let data: CloudGraphResponse
    }

    static func load(
        _ query: CloudGraphQuery, baseURL: URL, authorization: String,
        session: URLSession? = nil
    ) async throws -> CloudGraphResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent("history/graph"))
        request.httpMethod = "POST"
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(query)
        let (data, response) = try await (session ?? Self.session).data(for: request)
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse else { throw CloudGraphError.invalid("Missing HTTP response.") }
        guard http.statusCode == 200 else {
            if http.statusCode == 404 { throw CloudGraphError.unavailable }
            throw CloudGraphError.http(
                status: http.statusCode,
                retryAfter: http.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
            )
        }
        guard data.count <= 4 * 1024 * 1024 else { throw CloudGraphError.invalid("Graph response exceeds byte limit.") }
        let envelope: Envelope
        do { envelope = try JSONDecoder().decode(Envelope.self, from: data) }
        catch { throw CloudGraphError.invalid("Malformed graph response.") }
        guard envelope.result == "success" else { throw CloudGraphError.invalid("Unsuccessful graph response.") }
        try query.validate(envelope.data)
        try Task.checkCancellation()
        return envelope.data
    }
}
