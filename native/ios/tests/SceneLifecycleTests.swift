import XCTest
import UIKit
final class SceneLifecycleTests: XCTestCase {
    @MainActor func testGodotWindowBelongsToAnActiveScene() throws {
        let application = UIApplication.shared
        let delegate = try XCTUnwrap(application.delegate as? NSObject)
        let deadline = Date().addingTimeInterval(10)
        while (delegate.value(forKey: "window") as? UIWindow)?.windowScene == nil && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
        let window = try XCTUnwrap(delegate.value(forKey: "window") as? UIWindow)
        let scene = try XCTUnwrap(window.windowScene, "Legacy app windows cannot launch on iOS 27 with the new SDK")
        XCTAssertTrue(application.connectedScenes.contains(scene))
        XCTAssertEqual(scene.activationState, .foregroundActive)
        XCTAssertFalse(window.isHidden)
        XCTAssertNotNil(window.rootViewController)
        XCTAssertGreaterThan(window.bounds.width, 0)
        XCTAssertFalse(application.supportsMultipleScenes)
    }
}
