# SwiftAsyncShims

A collection of extensions that add async methods to existing Apple APIs. These allow you to replace delegates and callbacks with modern Swift concurrency – making code easier to reason about. 🙌

## Installation
Integrate it in your project via the Swift Package Manager. Just add [https://github.com/markiv/SwiftAsyncShims.git](https://github.com/markiv/SwiftAsyncShims.git) to your list of dependecies.

## CoreLocation

### Common Tasks

Use the convenience `CLLocationManager` initializer with support for common configuration parameters:

```swift
let manager = CLLocationManager(distanceFilter: 100)
```

Ask for permission if necessary, and ***then*** get a single location:

```swift
if await manager.requestWhenInUseAuthorization().isAuthorizedWhenInUse {
    print("Authorized!")
    do {
        let location = try await manager.requestLocation()
        print(location)
    } catch {
        print(error)
    }
}
```

You can also ignore the return value and check ``authorizationStatus`` as usual.

```swift
await manager.requestWhenInUseAuthorization()
⋮
if manager.authorizationStatus.isAuthorizedWhenInUse {
    ⋮
}
```

Request an **asynchronous stream** of locations. Because the stream is an `AsyncSequence`, the call point can use the `for`-`await`-`in` syntax to process each location instance as produced by the stream – and a simple `break` statement to stop the stream. This also allows us to use [sequence operators](https://developer.apple.com/documentation/swift/asyncthrowingstream/asyncsequence-implementations) such as `prefix`, `map`, `reduce` and `max`, for example:

 
```swift
if await manager.requestWhenInUseAuthorization().isAuthorizedWhenInUse {
    print("Authorized!")
    do {
        // Get at most 5 locations in an asynchronous stream
        for try await location in manager.requestLocationStream().prefix(5) {
            print(location)
            if location.horizontalAccuracy < 50 {
                print("Stopping the stream...")
                break // stop updating locations
            }
        }
    } catch {
        print(error)
    }
} else {
    // Show Settings button 
}
```
