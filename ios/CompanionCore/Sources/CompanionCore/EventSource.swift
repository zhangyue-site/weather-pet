import Foundation

/// Festival catalog: bundled, cached, and refreshed from the server every 6 hours.
/// Only HTTPS, no redirects, at most 128 KiB, and never an older revision. Port of `event_source.gd`.
@MainActor
public final class EventSource {
    public private(set) var catalog: EventCatalog
    public private(set) var status = "本地节日日历"
    public var onChange: (() -> Void)?
    public let url: String
    public static let refreshInterval: TimeInterval = 21600
    let cacheURL: URL?
    let fetcher: DataFetcher
    let now: () -> Date
    var lastRequest = Date.distantPast
    var inFlight = false

    public convenience init(cacheURL: URL?, fetcher: @escaping DataFetcher, now: @escaping () -> Date = Date.init) {
        self.init(bundle: .module, cacheURL: cacheURL, fetcher: fetcher, now: now)
    }

    init(bundle: Bundle, cacheURL: URL?, fetcher: @escaping DataFetcher, now: @escaping () -> Date = Date.init) {
        func content(_ name: String) -> Data? {
            bundle.url(forResource: name, withExtension: "json", subdirectory: "Content").flatMap { try? Data(contentsOf: $0) }
        }
        guard let bundled = content("events").flatMap(Events.catalog(from:)) else { fatalError("bundled events.json is invalid") }
        catalog = bundled
        self.cacheURL = cacheURL
        self.fetcher = fetcher
        self.now = now
        if let url = cacheURL, let data = try? Data(contentsOf: url),
           let cached = Events.catalog(from: data), cached.revision > catalog.revision {
            catalog = cached
            status = "已缓存节日日历"
        }
        let config = content("server").flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
        url = config?["events_url"] as? String ?? ""
    }

    public func tick() {
        guard now().timeIntervalSince(lastRequest) >= Self.refreshInterval else { return }
        refresh()
    }

    public func refresh() {
        lastRequest = now()
        guard !url.isEmpty, !inFlight else { return }
        guard url.hasPrefix("https://"), let target = URL(string: url) else {
            status = "活动地址需使用 HTTPS · 继续本地日历"
            return
        }
        var request = URLRequest(url: target)
        request.timeoutInterval = 12
        inFlight = true
        let fetcher = self.fetcher
        Task { [weak self] in
            let result: (Data, Int)?
            do { result = try await fetcher(request) } catch { result = nil }
            self?.inFlight = false
            self?.completed(result)
        }
    }

    /// Handles a server response. `nil` means the request failed.
    public func completed(_ result: (Data, Int)?) {
        guard let (body, code) = result, code == 200, body.count <= Events.maxBytes else {
            status = "活动暂未更新 · 继续已存日历"
            return
        }
        guard let incoming = Events.catalog(from: body), incoming.revision >= catalog.revision else {
            status = "活动内容未通过校验 · 继续已存日历"
            return
        }
        catalog = incoming
        status = "服务器节日日历"
        if let url = cacheURL { try? body.write(to: url, options: .atomic) }
        onChange?()
    }
}
