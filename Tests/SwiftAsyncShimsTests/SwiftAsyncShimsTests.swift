import CoreLocation
import CoreLocationAsync
import XCTest

final class SwiftAsyncShimsTests: XCTestCase {
    func testAuthorizationStatusExtensions() {
        XCTAssertTrue(CLAuthorizationStatus.authorizedAlways.isAuthorizedAlways)
        XCTAssertTrue(CLAuthorizationStatus.authorizedAlways.isAuthorizedWhenInUse)
        XCTAssertTrue(CLAuthorizationStatus.authorizedWhenInUse.isAuthorizedWhenInUse)
        XCTAssertFalse(CLAuthorizationStatus.authorizedWhenInUse.isAuthorizedAlways)
        XCTAssertFalse(CLAuthorizationStatus.denied.isAuthorizedWhenInUse)
        XCTAssertFalse(CLAuthorizationStatus.denied.isAuthorizedAlways)
        XCTAssertFalse(CLAuthorizationStatus.notDetermined.isAuthorizedWhenInUse)
        XCTAssertFalse(CLAuthorizationStatus.notDetermined.wasDenied)
        XCTAssertTrue(CLAuthorizationStatus.denied.wasDenied)
        XCTAssertFalse(CLAuthorizationStatus.notDetermined.wasDenied)
    }

    func testConvenienceInitializer() {
        XCTAssertEqual(
            CLLocationManager().desiredAccuracy,
            CLLocationManager(activityType: .otherNavigation).desiredAccuracy
        )
        XCTAssertEqual(
            CLLocationManager().activityType,
            CLLocationManager(desiredAccuracy: kCLLocationAccuracyBest).activityType
        )
        XCTAssertEqual(
            CLLocationManager().distanceFilter,
            CLLocationManager(desiredAccuracy: kCLLocationAccuracyBest).distanceFilter
        )
    }
}
