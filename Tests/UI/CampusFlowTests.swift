import XCTest

final class CampusFlowTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }
    let server = ProcessInfo.processInfo.environment["UNIRIDE_TEST_API_URL"] ?? "http://127.0.0.1:8788"
    @MainActor func api(_ path: String, method: String = "POST", body: [String: Any], token: String? = nil) async throws -> [String: Any] {
        var request = URLRequest(url: URL(string: server + path)!)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200, String(data: data, encoding: .utf8) ?? "")
        return try JSONSerialization.jsonObject(with: data) as! [String: Any]
    }
    @MainActor func scrollTo(_ element: XCUIElement, app: XCUIApplication) {
        for _ in 0..<6 { if element.isHittable { return }; app.scrollViews.firstMatch.swipeUp() }
    }
    enum Failure: Error { case abort }
    @MainActor func login(_ email: String, app: XCUIApplication) throws {
        XCTAssertTrue(app.textFields["Email"].waitForExistence(timeout: 10))
        app.textFields["Email"].tap(); app.textFields["Email"].typeText(email + "\n")
        app.secureTextFields.firstMatch.typeText("test-password-123\n")
        guard app.buttons["Profile"].waitForExistence(timeout: 12) else { XCTFail(app.debugDescription); throw Failure.abort }
    }
    @MainActor func logout(_ app: XCUIApplication) {
        app.buttons["Profile"].tap()
        let out = app.buttons["Sign Out"]; scrollTo(out, app: app); out.tap()
        XCTAssertTrue(app.textFields["Email"].waitForExistence(timeout: 10))
    }
    @MainActor func testRealPublishRequestAcceptChatCompleteReview() async throws {
        let suffix = UUID().uuidString.prefix(8)
        let driverEmail = "driver-\(suffix)@example.test"
        let studentEmail = "student-\(suffix)@example.test"
        let driver = try await api("/signup", body: ["name": "Test Driver \(suffix)", "email": driverEmail, "password": "test-password-123", "university": "Hassan I"])
        _ = try await api("/signup", body: ["name": "Test Student", "email": studentEmail, "password": "test-password-123", "university": "Hassan I"])
        _ = try await api("/profile", method: "PATCH", body: ["carModel": "Dacia Sandero", "carColor": "White", "plate": "TEST 123"], token: driver["token"] as? String)
        let app = XCUIApplication(); app.launchArguments = ["--ui-testing", "--server", server]; app.launch()
        try login(driverEmail, app: app)
        let offer = app.buttons["Offer a ride"].firstMatch; scrollTo(offer, app: app); offer.tap()
        let meeting = app.textFields["Entrance, landmark and how to find your car"]
        XCTAssertTrue(meeting.waitForExistence(timeout: 10)); scrollTo(meeting, app: app); meeting.tap(); meeting.typeText("Main entrance. White Dacia.")
        if app.buttons["Done"].waitForExistence(timeout: 2) && app.buttons["Done"].isHittable { app.buttons["Done"].tap() }
        let publish = app.buttons["Publish ride"]; scrollTo(publish, app: app); publish.tap()
        XCTAssertTrue(app.buttons["Profile"].waitForExistence(timeout: 10))
        logout(app); try login(studentEmail, app: app)
        let route = app.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "Gare de Settat → ISTA 2", "Test Driver \(suffix)")).firstMatch
        XCTAssertTrue(route.waitForExistence(timeout: 10)); scrollTo(route, app: app); route.tap()
        let request = app.buttons["Request seat"]; scrollTo(request, app: app); request.tap()
        XCTAssertTrue(app.staticTexts["Awaiting driver"].waitForExistence(timeout: 10))
        let chat = app.buttons["Message driver"]; scrollTo(chat, app: app); chat.tap()
        XCTAssertTrue(app.textFields["Message"].waitForExistence(timeout: 5))
        app.textFields["Message"].tap(); app.textFields["Message"].typeText("I will meet you at the main entrance.")
        app.buttons["Send message"].tap()
        XCTAssertTrue(app.staticTexts["I will meet you at the main entrance."].waitForExistence(timeout: 10))
        app.buttons["Close"].tap(); logout(app); try login(driverEmail, app: app)
        app.buttons["Rides"].tap()
        XCTAssertTrue(route.waitForExistence(timeout: 10)); route.tap()
        let accept = app.buttons["Accept"]; scrollTo(accept, app: app); accept.tap()
        XCTAssertTrue(app.staticTexts["Confirmed"].waitForExistence(timeout: 10))
        let start = app.buttons["Start ride"]; scrollTo(start, app: app); start.tap(); app.buttons["Confirm"].tap()
        let complete = app.buttons["Complete trip"]; XCTAssertTrue(complete.waitForExistence(timeout: 10)); complete.tap(); app.buttons["Confirm"].tap()
        XCTAssertTrue(app.staticTexts["Completed"].waitForExistence(timeout: 10))
        logout(app); try login(studentEmail, app: app); app.buttons["Rides"].tap(); app.buttons["History"].tap()
        XCTAssertTrue(route.waitForExistence(timeout: 10)); route.tap()
        let review = app.buttons["Rate your driver"]; scrollTo(review, app: app); review.tap()
        let submit = app.buttons["Submit review"]; XCTAssertTrue(submit.waitForExistence(timeout: 10)); submit.tap()
        XCTAssertTrue(app.buttons["Profile"].waitForExistence(timeout: 10))
        let response = try await api("/login", body: ["email": studentEmail, "password": "test-password-123"])
        let state = response["snapshot"] as! [String: Any]
        XCTAssertEqual((state["reviews"] as! [[String: Any]]).filter { $0["authorId"] as? String == (state["currentUser"] as! [String: Any])["id"] as? String }.count, 1)
    }
    @MainActor func testVerificationErrorInsideSheet() async throws {
        let email = "verification-\(UUID().uuidString.prefix(8))@example.test"
        _ = try await api("/signup", body: ["name": "Test Student", "email": email, "password": "test-password-123", "university": "Hassan I"])
        let app = XCUIApplication(); app.launchArguments = ["--ui-testing", "--server", server]; app.launch()
        try login(email, app: app); app.buttons["Profile"].tap(); app.buttons["Verify email"].tap()
        let send = app.buttons["Send verification code"]
        XCTAssertTrue(send.waitForExistence(timeout: 5)); send.tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.alerts.firstMatch.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "configured")).firstMatch.exists)
        app.alerts.firstMatch.buttons["OK"].tap()
        XCTAssertTrue(send.exists)
    }
    @MainActor func testFrenchAndArabic() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--fresh-preview", "--preview-home", "--language-fr"]
        app.launch(); XCTAssertTrue(app.staticTexts["Où allez-vous ?"].waitForExistence(timeout: 10)); XCTAssertTrue(app.buttons["Profil"].exists); XCTAssertTrue(app.staticTexts["1 trajet"].exists)
        app.terminate(); app.launchArguments = ["--ui-testing", "--fresh-preview", "--preview-home", "--language-ar"]
        app.launch(); XCTAssertTrue(app.staticTexts["إلى أين تتجه؟"].waitForExistence(timeout: 10)); XCTAssertTrue(app.buttons["الملف الشخصي"].exists)
        app.terminate(); app.launchArguments = ["--ui-testing", "--fresh-preview", "--preview-home"]
        app.launch(); XCTAssertTrue(app.staticTexts["1 ride"].waitForExistence(timeout: 10))
    }
}
