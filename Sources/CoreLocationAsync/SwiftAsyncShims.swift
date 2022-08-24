public struct SwiftAsyncShims {
    public private(set) var text = "Hello, World!"

    public init() {}
}

import CoreLocation

extension CLLocationManager: CLLocationManagerDelegate {
    typealias LocationContinuation = CheckedContinuation<CLLocation, Error>
    typealias AuthorizationContinuation = CheckedContinuation<CLAuthorizationStatus, Never>
    typealias LocationStream = AsyncStream<CLLocation>

    private static var locationContinuationKey: UInt8 = 0
    private static var locationStreamContinuationKey: UInt8 = 0
    private static var authorizationContinuationKey: UInt8 = 0

    public convenience init(
        activityType: CLActivityType = .other,
        distanceFilter: CLLocationDistance = kCLDistanceFilterNone,
        desiredAccuracy: CLLocationAccuracy = kCLLocationAccuracyBest
    ) {
        self.init()
        self.activityType = activityType
        self.desiredAccuracy = desiredAccuracy
        self.distanceFilter = distanceFilter
    }

    private var locationStreamContinuation: LocationStream.Continuation? {
        get { objc_getAssociatedObject(self, &Self.locationStreamContinuationKey) as? LocationStream.Continuation }
        set { objc_setAssociatedObject(self, &Self.locationStreamContinuationKey, newValue, .OBJC_ASSOCIATION_COPY) }
    }

    private var locationContinuation: LocationContinuation? {
        get { objc_getAssociatedObject(self, &Self.locationContinuationKey) as? LocationContinuation }
        set { objc_setAssociatedObject(self, &Self.locationContinuationKey, newValue, .OBJC_ASSOCIATION_COPY) }
    }

    private var authorizationContinuation: AuthorizationContinuation? {
        get { objc_getAssociatedObject(self, &Self.authorizationContinuationKey) as? AuthorizationContinuation }
        set { objc_setAssociatedObject(self, &Self.authorizationContinuationKey, newValue, .OBJC_ASSOCIATION_COPY) }
    }

    public func requestWhenInUseAuthorization() async -> CLAuthorizationStatus {
        guard authorizationStatus == .notDetermined else {
            return authorizationStatus
        }
        delegate = self
        return await withCheckedContinuation { continuation in
            authorizationContinuation = continuation
            requestWhenInUseAuthorization()
        }
    }

    func requestAlwaysAuthorization() async -> CLAuthorizationStatus {
        guard [.notDetermined, .authorizedWhenInUse].contains(authorizationStatus) else {
            return authorizationStatus
        }
        delegate = self
        return await withCheckedContinuation { continuation in
            authorizationContinuation = continuation
            requestAlwaysAuthorization()
        }
    }

    public func requestLocation() async throws -> CLLocation {
        delegate = self
        return try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            requestLocation()
        }
    }

    public func requestLocations() -> AsyncStream<CLLocation> {
        AsyncStream<CLLocation> { continuation in
            continuation.onTermination = { _ in
                self.stopUpdatingLocation()
            }
            locationStreamContinuation = continuation
            delegate = self
            startUpdatingLocation()
        }
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let continuation = locationStreamContinuation {
            locations.forEach {
                continuation.yield($0)
            }
        } else if let location = locations.first {
            locationContinuation?.resume(returning: location)
        }
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationContinuation?.resume(throwing: error)
    }

    private class AdaptorDelegate: NSObject, CLLocationManagerDelegate {
//        enum Continuation {
//            case locationStream(LocationStream.Continuation)
//            case location(LocationContinuation)
//            case authorization(AuthorizationContinuation)
//        }
//        private var continuation: Continuation?

        private var locationStreamContinuation: LocationStream.Continuation?
        private var locationContinuation: LocationContinuation?
        private var authorizationContinuation: AuthorizationContinuation?

        public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
            locationContinuation?.resume(throwing: error)
        }
    }
}

/*
 public class AsyncLocationManager: CLLocationManager, CLLocationManagerDelegate {
     typealias LocationContinuation = CheckedContinuation<CLLocation, Error>
     typealias AuthorizationContinuation = CheckedContinuation<CLAuthorizationStatus, Never>
     private var locationContinuation: LocationContinuation?
     private var authorizationContinuation: AuthorizationContinuation?

     public func requestLocation() async throws -> CLLocation {
         delegate = self
         return try await withCheckedThrowingContinuation { continuation in
             self.locationContinuation = continuation
             super.requestLocation()
         }
     }

     public func requestWhenInUseAuthorization() async -> CLAuthorizationStatus {
         guard authorizationStatus == .notDetermined else {
             return authorizationStatus
         }
         delegate = self
         return await withCheckedContinuation { continuation in
             self.authorizationContinuation = continuation
             super.requestWhenInUseAuthorization()
         }
     }

     public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
         if let location = locations.first {
             locationContinuation?.resume(returning: location)
         }
     }

     public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
         locationContinuation?.resume(throwing: error)
     }

     public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
         authorizationContinuation?.resume(returning: manager.authorizationStatus)
     }
 }
 */
