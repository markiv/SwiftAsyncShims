// MIT License
// Copyright (c) 2022 Vikram Kriplaney
// See the LICENSE file in this repository for this code's licensing information.

import CoreLocation

public extension CLLocationManager {
    typealias LocationStream = AsyncThrowingStream<CLLocation, Error>
    private static var delegateAdaptorKey: UInt8 = 0

    /// A convenience initializer with support for common configuration parameters.
    /// - Parameters:
    ///   - activityType: The type of user activity associated with the location updates.
    ///   - distanceFilter: The accuracy of the location data that your app wants to receive.
    ///   - desiredAccuracy: The minimum distance (measured in meters) a device must move horizontally before an update
    ///   event is generated.
    convenience init(
        activityType: CLActivityType = .other,
        distanceFilter: CLLocationDistance = kCLDistanceFilterNone,
        desiredAccuracy: CLLocationAccuracy = kCLLocationAccuracyBest
    ) {
        self.init()
        self.activityType = activityType
        self.desiredAccuracy = desiredAccuracy
        self.distanceFilter = distanceFilter
    }

    /// An async adaptor for delegate methods, retained as an associated object.
    private var delegateAdaptor: DelegateAdaptor {
        get {
            if let delegateAdaptor = objc_getAssociatedObject(self, &Self.delegateAdaptorKey) as? DelegateAdaptor {
                return delegateAdaptor
            }
            let delegateAdaptor = DelegateAdaptor()
            self.delegateAdaptor = delegateAdaptor
            delegate = delegateAdaptor
            return delegateAdaptor
        }
        set {
            objc_setAssociatedObject(self, &Self.delegateAdaptorKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    /// Asynchronously requests the user’s permission to use location services while the app is in use.
    ///
    ///     if await manager.requestWhenInUseAuthorization().isAuthorizedWhenInUse {
    ///        print("Authorized!")
    ///        do {
    ///            let location = try await manager.requestLocation()
    ///            print(location)
    ///        } catch {
    ///            print(error)
    ///        }
    ///     }
    ///
    /// You can also ignore the return value and check ``authorizationStatus`` as usual.
    ///
    ///     await manager.requestWhenInUseAuthorization()
    ///     ⋮
    ///     if manager.authorizationStatus.isAuthorizedWhenInUse {
    ///         ⋮
    ///     }
    ///
    /// - Returns: the authorization status after requesting the user's permission.
    @discardableResult func requestWhenInUseAuthorization() async -> CLAuthorizationStatus {
        guard authorizationStatus == .notDetermined else {
            return authorizationStatus
        }

        return await withCheckedContinuation { continuation in
            delegateAdaptor.authorizationContinuation = continuation
            requestWhenInUseAuthorization()
        }
    }

    /// Asynchronously requests the user’s permission to use location services while the app is in use.
    ///
    ///     if await manager.requestAlwaysAuthorization().isAuthorizedAlways {
    ///        print("Authorized!")
    ///        do {
    ///            let location = try await manager.requestLocation()
    ///            print(location)
    ///        } catch {
    ///            print(error)
    ///        }
    ///     }
    ///
    /// You can also ignore the return value and check ``authorizationStatus`` as usual.
    ///
    ///     await manager.requestAlwaysAuthorization()
    ///     ⋮
    ///     if manager.authorizationStatus.isAuthorizedAlways {
    ///         ⋮
    ///     }
    ///
    /// - Returns: the authorization status after requesting the user's permission.
    func requestAlwaysAuthorization() async -> CLAuthorizationStatus {
        guard [.notDetermined, .authorizedWhenInUse].contains(authorizationStatus) else {
            return authorizationStatus
        }
        return await withCheckedContinuation { continuation in
            delegateAdaptor.authorizationContinuation = continuation
            requestAlwaysAuthorization()
        }
    }

    /// Requests a single location.
    ///
    ///     if await manager.requestWhenInUseAuthorization().isAuthorizedWhenInUse {
    ///        print("Authorized!")
    ///        do {
    ///            let location = try await manager.requestLocation()
    ///            print(location)
    ///        } catch {
    ///            print(error)
    ///        }
    ///     }
    /// - Returns: a single location
    func requestLocation() async throws -> CLLocation {
        try await withCheckedThrowingContinuation { continuation in
            delegateAdaptor.locationContinuation = continuation
            requestLocation()
        }
    }

    /// Requests a stream of locations. Because the stream is an `AsyncSequence`, the call point can use the
    /// `for`-`await`-`in` syntax to process each location instance as produced by the stream:
    ///
    ///     do {
    ///         // Get at most 5 locations in an asynchronous stream
    ///         for try await location in manager.requestLocationStream().prefix(5) {
    ///             if location.horizontalAccuracy < 50 {
    ///                 print("Stopping the stream...")
    ///                 break // stop updating locations
    ///             }
    ///         }
    ///     } catch {
    ///         print("Error: \(error)")
    ///     }
    /// - Returns: An `AsyncThrowingStream` of locations
    func requestLocationStream() -> LocationStream {
        LocationStream { continuation in
            continuation.onTermination = { [weak self] _ in
                // When the async stream is stopped, e.g. with a `break`
                self?.stopUpdatingLocation()
                self?.delegateAdaptor.locationStreamContinuation = nil
            }
            delegateAdaptor.locationStreamContinuation = continuation
            startUpdatingLocation()
        }
    }

    /// Handles `CLLocationManager` delegate methods, adapting them for async continuations.
    private class DelegateAdaptor: NSObject, CLLocationManagerDelegate {
        typealias LocationContinuation = CheckedContinuation<CLLocation, Error>
        typealias AuthorizationContinuation = CheckedContinuation<CLAuthorizationStatus, Never>

        var locationStreamContinuation: LocationStream.Continuation?
        var locationContinuation: LocationContinuation?
        var authorizationContinuation: AuthorizationContinuation?

        func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
            authorizationContinuation?.resume(returning: manager.authorizationStatus)
            authorizationContinuation = nil
        }

        public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
            locationContinuation?.resume(throwing: error)
            locationContinuation = nil
            locationStreamContinuation?.finish(throwing: error)
            locationStreamContinuation = nil
        }

        public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            if let continuation = locationStreamContinuation {
                locations.forEach {
                    continuation.yield($0)
                }
            } else if let location = locations.first {
                locationContinuation?.resume(returning: location)
                locationContinuation = nil
            }
        }
    }
}

public extension CLAuthorizationStatus {
    var isAuthorizedWhenInUse: Bool {
        self == .authorizedWhenInUse || self == .authorizedAlways
    }

    var isAuthorizedAlways: Bool {
        self == .authorizedAlways
    }

    var wasDenied: Bool {
        self == .denied || self == .restricted
    }
}
