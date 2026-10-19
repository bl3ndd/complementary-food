import XCTest

/// Скриншот экрана покупки для App Review (обязателен у IAP в App Store Connect).
/// Снимается на английском — ревьюер читает его; экран — как у нового
/// пользователя (`debug.simulateNewUser`), иначе sandbox-покупка на телефоне
/// показала бы «Pro открыт» вместо кнопки покупки.
final class ProReviewScreenshotUITests: XCTestCase {

    func testCaptureProPaywall() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-uitest-seed=child",
                               "-debug.simulateNewUser", "YES",
                               "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        let gotIt = app.buttons["Got it"]
        if gotIt.waitForExistence(timeout: 6) { gotIt.tap() }
        let allow = XCUIApplication(bundleIdentifier: "com.apple.springboard").buttons["Allow"]
        if allow.waitForExistence(timeout: 3) { allow.tap() }

        // Профиль — пятая вкладка; по индексу, чтобы не зависеть от подписи.
        app.tabBars.buttons.element(boundBy: 4).waitTap()
        let open = app.buttons["Get Pudding Pro"]
        for _ in 0..<6 where !open.isHittable { app.swipeUp() }
        open.waitTap()

        // Цена приходит из App Store — даём витрине загрузиться.
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Get Pro'"))
            .firstMatch.waitForExistence(timeout: 10), "нет кнопки покупки")
        sleep(4)

        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "ProPaywall_en"
        shot.lifetime = .keepAlways
        add(shot)
    }
}
