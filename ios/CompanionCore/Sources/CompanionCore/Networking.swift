import Foundation

/// URLSession fetchers used by the apps. Tests inject their own `DataFetcher`.
public enum Networking {
    public static let weather: DataFetcher = { request in
        let (data, response) = try await URLSession.shared.data(for: request)
        return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
    }

    /// Server content follows no redirects and stops reading past the size limit.
    public static let content: DataFetcher = { request in
        let session = URLSession(configuration: .ephemeral, delegate: NoRedirect(), delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        let (bytes, response) = try await session.bytes(for: request)
        var data = Data()
        for try await byte in bytes {
            data.append(byte)
            if data.count > Events.maxBytes { break }
        }
        return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
    }

    final class NoRedirect: NSObject, URLSessionTaskDelegate, Sendable {
        func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest) async -> URLRequest? {
            nil
        }
    }
}
