import XCTest
import Vision

final class CjmpUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testRunSmokeCheckFromUiTestPage() throws {
        let app = XCUIApplication()
        launchApp(app)
        attachScreenshot(named: "post-launch", from: app)

        guard let terminalStatus = waitForTerminalStatus(in: app, timeout: 120) else {
            attachScreenshot(named: "smoke-terminal-missing", from: app)
            XCTFail("Smoke suite did not expose a terminal status")
            return
        }

        attachScreenshot(named: "smoke-terminal-\(terminalStatus.replacingOccurrences(of: " ", with: "-"))", from: app)
        XCTAssertEqual(terminalStatus, "Smoke suite passed")
    }

    func testTelegramLoginScreenProbe() throws {
        let app = XCUIApplication()
        app.launch()
        waitForLaunchSettled()
        app.activate()

        let window = app.windows.element(boundBy: 0)
        XCTAssertTrue(window.waitForExistence(timeout: 15), "Main window did not appear")
        attachScreenshot(named: "telegram-login-probe", from: app)
        print("CJMP_UI_TREE_BEGIN")
        print(app.debugDescription)
        print("CJMP_UI_TREE_END")
        print("CJMP_OCR_BEGIN")
        print(recognizeText(from: app.screenshot()))
        print("CJMP_OCR_END")
    }

    func testTelegramHomeDataSurfaceProbe() throws {
        let app = XCUIApplication()
        app.launch()
        waitForLaunchSettled()
        app.activate()

        let window = app.windows.element(boundBy: 0)
        XCTAssertTrue(window.waitForExistence(timeout: 15), "Main window did not appear")

        guard let chatsText = waitForRecognizedText(
            in: app,
            timeout: 70,
            containingAny: [
                "Real Telegram chats",
                "Saved Messages",
                "Chats"
            ]
        ) else {
            attachScreenshot(named: "telegram-home-data-chats-timeout", from: app)
            XCTFail("Telegram home did not restore to the chat list")
            return
        }
        attachScreenshot(named: "telegram-home-data-chats", from: app)
        print("CJMP_HOME_CHATS_OCR_BEGIN")
        print(chatsText)
        print("CJMP_HOME_CHATS_OCR_END")
        XCTAssertFalse(chatsText.contains("Failed to create a TDLib client"), "TDLib client creation failed")
        XCTAssertFalse(chatsText.contains("Saved Telegram data is available"), "App stayed on the login restore prompt")

        tapWindow(app, dx: 0.50, dy: 0.955)
        guard let contactsText = waitForRecognizedText(
            in: app,
            timeout: 40,
            containingAny: [
                "Contacts",
                "Loading Telegram contacts",
                "No synced contacts"
            ]
        ) else {
            attachScreenshot(named: "telegram-home-data-contacts-timeout", from: app)
            XCTFail("Contacts tab did not become visible")
            return
        }
        attachScreenshot(named: "telegram-home-data-contacts", from: app)
        print("CJMP_HOME_CONTACTS_OCR_BEGIN")
        print(contactsText)
        print("CJMP_HOME_CONTACTS_OCR_END")
        XCTAssertTrue(contactsText.contains("Contacts"), "Contacts tab title was not visible")

        tapWindow(app, dx: 0.83, dy: 0.955)
        guard let settingsText = waitForRecognizedText(
            in: app,
            timeout: 60,
            containingAny: [
                "Signed in with Telegram",
                "Real TDLib session is active",
                "Settings"
            ]
        ) else {
            attachScreenshot(named: "telegram-home-data-settings-timeout", from: app)
            XCTFail("Settings tab did not become visible")
            return
        }
        attachScreenshot(named: "telegram-home-data-settings", from: app)
        print("CJMP_HOME_SETTINGS_OCR_BEGIN")
        print(settingsText)
        print("CJMP_HOME_SETTINGS_OCR_END")
        XCTAssertTrue(settingsText.contains("Settings"), "Settings tab title was not visible")
        XCTAssertFalse(settingsText.contains("No local demo session is active"), "Settings stayed on the local placeholder session")
    }

    func testTelegramSubmitPhoneForRealDevice() throws {
        let phoneLocal = try XCTUnwrap(
            ProcessInfo.processInfo.environment["CJMP_TELEGRAM_PHONE_LOCAL"],
            "CJMP_TELEGRAM_PHONE_LOCAL must be set"
        )
        XCTAssertFalse(phoneLocal.isEmpty, "CJMP_TELEGRAM_PHONE_LOCAL must not be empty")

        let app = XCUIApplication()
        app.launch()
        waitForLaunchSettled()
        app.activate()

        let window = app.windows.element(boundBy: 0)
        XCTAssertTrue(window.waitForExistence(timeout: 15), "Main window did not appear")
        attachScreenshot(named: "telegram-submit-phone-before", from: app)

        tapWindow(app, dx: 0.50, dy: 0.575)
        app.typeText(phoneLocal)
        attachScreenshot(named: "telegram-submit-phone-typed", from: app)
        dismissKeyboardIfPresent(in: app)
        tapWindow(app, dx: 0.50, dy: 0.915)

        guard let recognized = waitForRecognizedText(
            in: app,
            timeout: 90,
            containingAny: [
                "Verification Code",
                "Telegram Password",
                "Saved Telegram data is available",
                "Telegram did not respond",
                "Failed",
                "Chats"
            ]
        ) else {
            attachScreenshot(named: "telegram-submit-phone-timeout", from: app)
            XCTFail("Telegram phone submission did not reach a recognizable terminal state")
            return
        }

        attachScreenshot(named: "telegram-submit-phone-after", from: app)
        print("CJMP_SUBMIT_PHONE_OCR_BEGIN")
        print(recognized)
        print("CJMP_SUBMIT_PHONE_OCR_END")
        XCTAssertFalse(recognized.contains("Failed"), "Telegram auth failed: \(recognized)")
        XCTAssertFalse(recognized.contains("Telegram did not respond"), "Telegram auth timed out: \(recognized)")
        XCTAssertTrue(
            recognized.contains("Verification Code") ||
                recognized.contains("Telegram Password") ||
                recognized.contains("Chats"),
            "Unexpected Telegram auth state: \(recognized)"
        )
    }

    private func launchApp(_ app: XCUIApplication) {
        app.launchArguments = [
            "test", "test",
            "bundleName", "bundleName",
            "moduleName", "moduleName",
            "unittest", "unittest",
            "timeout", "101",
        ]
        app.launch()
        waitForLaunchSettled()
        app.activate()

        let window = app.windows.element(boundBy: 0)
        XCTAssertTrue(window.waitForExistence(timeout: 15), "Main window did not appear")
    }

    private func waitForTerminalStatus(in app: XCUIApplication, timeout: TimeInterval) -> String? {
        let terminalStatuses = [
            "Smoke suite passed",
            "Smoke suite failed",
            "Smoke suite crashed",
        ]
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let recognized = recognizeText(from: app.screenshot())
            for status in terminalStatuses {
                if recognized.contains(status) {
                    return status
                }
            }
            RunLoop.current.run(until: Date().addingTimeInterval(2.0))
        }
        return nil
    }

    private func waitForRecognizedText(
        in app: XCUIApplication,
        timeout: TimeInterval,
        containingAny expectedTexts: [String]
    ) -> String? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let recognized = recognizeText(from: app.screenshot())
            if expectedTexts.contains(where: { recognized.contains($0) }) {
                return recognized
            }
            RunLoop.current.run(until: Date().addingTimeInterval(2.0))
        }
        return nil
    }

    private func tapWindow(_ app: XCUIApplication, dx: CGFloat, dy: CGFloat) {
        let window = app.windows.element(boundBy: 0)
        window.coordinate(withNormalizedOffset: CGVector(dx: dx, dy: dy)).tap()
    }

    private func dismissKeyboardIfPresent(in app: XCUIApplication) {
        guard app.keyboards.count > 0 else { return }
        let doneButton = app.keyboards.buttons["Done"]
        if doneButton.exists {
            doneButton.tap()
            return
        }
        let returnButton = app.keyboards.buttons["Return"]
        if returnButton.exists {
            returnButton.tap()
            return
        }
        tapWindow(app, dx: 0.50, dy: 0.30)
    }

    private func recognizeText(from screenshot: XCUIScreenshot) -> String {
        guard let cgImage = screenshot.image.cgImage else { return "" }
        var recognizedText = ""
        if #available(iOS 13.0, *) {
            let request = VNRecognizeTextRequest { request, _ in
                guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
                recognizedText = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
            }
            request.recognitionLevel = .accurate
            do {
                try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
            } catch {
                return ""
            }
        }
        return recognizedText
    }

    private func waitForLaunchSettled() {
        Thread.sleep(forTimeInterval: 20.0)
    }

    private func attachScreenshot(named name: String, from app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
