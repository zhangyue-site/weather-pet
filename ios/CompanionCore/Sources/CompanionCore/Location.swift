import Foundation

public enum LocationEvent: Equatable, Sendable {
    case coordinates(lat: Double, lon: Double)
    case placeName(String)
    case failure(String)
}

@MainActor
public protocol LocationProviding: AnyObject {
    /// One-shot foreground location, then (optionally) a readable place name.
    func request(_ handler: @escaping @MainActor (LocationEvent) -> Void)
}

#if canImport(CoreLocation)
import CoreLocation
#if canImport(MapKit)
import MapKit
#endif

/// Foreground, one-shot location; no background tracking. Port of `CompanionLocation.kt`.
@MainActor
public final class DeviceLocation: NSObject, LocationProviding, CLLocationManagerDelegate {
    let manager = CLLocationManager()
    var handler: (@MainActor (LocationEvent) -> Void)?
    var generation = 0
    var pending = false
    var waitingForPermission = false
    var timeout: Task<Void, Never>?

    public override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    public func request(_ handler: @escaping @MainActor (LocationEvent) -> Void) {
        stop()
        generation += 1
        self.handler = handler
        switch manager.authorizationStatus {
        case .notDetermined:
            waitingForPermission = true
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            emit(.failure("未获得定位权限，请在设置中选择城市"))
        default:
            locate()
        }
    }

    func locate() {
        // A fix from the last 15 minutes is good enough for weather.
        if let cached = manager.location, -cached.timestamp.timeIntervalSinceNow < 15 * 60 {
            deliver(cached)
            return
        }
        pending = true
        manager.requestLocation()
        let token = generation
        timeout = Task { [weak self] in
            try? await Task.sleep(for: .seconds(20))
            guard let self, !Task.isCancelled, self.generation == token, self.pending else { return }
            self.stop()
            self.emit(.failure("暂时未取得位置，请重试或选择城市"))
        }
    }

    func stop() {
        pending = false
        waitingForPermission = false
        timeout?.cancel()
        timeout = nil
    }

    func emit(_ event: LocationEvent) { handler?(event) }

    func deliver(_ location: CLLocation) {
        stop()
        generation += 1
        let token = generation
        emit(.coordinates(lat: location.coordinate.latitude, lon: location.coordinate.longitude))
        Task { [weak self] in
            let name = await Self.placeName(for: location)
            guard let self, self.generation == token, let name, !name.isEmpty else { return }
            self.emit(.placeName(name))
        }
    }

    static func placeName(for location: CLLocation) async -> String? {
        let locale = Locale(identifier: "zh-Hans")
        #if canImport(MapKit)
        if #available(iOS 26.0, watchOS 26.0, macOS 26.0, *) {
            guard let request = MKReverseGeocodingRequest(location: location) else { return nil }
            request.preferredLocale = locale
            guard let item = try? await request.mapItems.first, let names = item.addressRepresentations else { return nil }
            return names.cityName ?? names.regionName
        }
        #endif
        let marks = try? await CLGeocoder().reverseGeocodeLocation(location, preferredLocale: locale)
        guard let p = marks?.first else { return nil }
        var parts: [String] = []
        for part in [p.locality ?? p.administrativeArea, p.subLocality ?? p.subAdministrativeArea] {
            if let part, !part.isEmpty, !parts.contains(part) { parts.append(part) }
        }
        return parts.joined(separator: " · ")
    }

    nonisolated public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        MainActor.assumeIsolated {
            guard waitingForPermission, status != .notDetermined else { return }
            waitingForPermission = false
            if status == .denied || status == .restricted {
                emit(.failure("未获得定位权限，请在设置中选择城市"))
            } else {
                locate()
            }
        }
    }

    nonisolated public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        MainActor.assumeIsolated {
            guard pending else { return }
            deliver(last)
        }
    }

    nonisolated public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let denied = (error as? CLError)?.code == .denied
        MainActor.assumeIsolated {
            guard pending else { return }
            stop()
            emit(.failure(denied ? "未获得定位权限，请在设置中选择城市" : "暂时未取得位置，请重试或选择城市"))
        }
    }
}
#endif
