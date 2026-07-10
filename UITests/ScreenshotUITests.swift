import XCTest

/// Съёмка сырых скриншотов для App Store (docs/appstore + скилл appstore-screenshots).
/// Запускается ТОЛЬКО с env `SNAPSHOT=1` (TEST_RUNNER_SNAPSHOT=1 в xcodebuild) на
/// симуляторе iPhone Pro Max (6.9", 1320×2868) — в обычных прогонах скипается.
/// Скрины уходят в attachments (.keepAlways) → выгружаются из xcresult.
final class ScreenshotUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(ProcessInfo.processInfo.environment["SNAPSHOT"] == "1",
                          "скриншот-режим: запускать с TEST_RUNNER_SNAPSHOT=1")
    }

    func testCaptureRU() { capture(lang: "ru") }
    func testCaptureEN() { capture(lang: "en") }

    // MARK: - Сценарий съёмки (одинаковый для обоих языков)

    private struct L {
        let today: String, calendar: String, allergens: String
        let introducingDay: String, recap: String, done: String
        static let ru = L(today: "Сегодня", calendar: "Календарь", allergens: "Аллергены",
                          introducingDay: "День 2", recap: "Рекап месяца", done: "Готово")
        static let en = L(today: "Today", calendar: "Calendar", allergens: "Allergens",
                          introducingDay: "Day 2", recap: "Monthly recap", done: "Done")
    }

    private func capture(lang: String) {
        let l: L = lang == "ru" ? .ru : .en
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-uitest-seed=showcase",
                               "-AppleLanguages", "(\(lang))",
                               "-AppleLocale", lang == "ru" ? "ru_RU" : "en_US"]
        app.launch()

        // Гейт дисклеймера (локализован — ищем любой из вариантов).
        for label in ["Понятно", "Got it", "OK"] {
            let b = app.buttons[label]
            if b.waitForExistence(timeout: 3) { b.tap(); break }
        }

        // 01 — Главная.
        XCTAssertTrue(app.staticTexts["Ника"].waitForExistence(timeout: 8))
        shoot("01_Dashboard", lang)

        // 02 — Карточка продукта «вводится» (кольцо «день 2 из 3») из «Сейчас вводишь».
        let introducingRow = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", l.introducingDay)).firstMatch
        if !introducingRow.isHittable { app.swipeUp() }
        introducingRow.tap()
        _ = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", l.introducingDay))
            .firstMatch.waitForExistence(timeout: 5)
        sleep(1)   // дать кольцу дорисоваться
        shoot("02_FoodCard", lang)
        app.navigationBars.buttons.firstMatch.tap()   // назад

        // 03 — Календарь-лента.
        app.tabBars.buttons[l.calendar].tap()
        sleep(1)
        shoot("03_Calendar", lang)

        // 04 — Аллергены.
        app.tabBars.buttons[l.allergens].tap()
        sleep(1)
        shoot("04_Allergens", lang)

        // 05 — Рекап месяца (из календаря).
        app.tabBars.buttons[l.calendar].tap()
        let recap = app.buttons[l.recap]
        if recap.waitForExistence(timeout: 4) {
            recap.tap()
            _ = app.buttons.firstMatch.waitForExistence(timeout: 4)
            sleep(1)
            shoot("05_Recap", lang)
            app.navigationBars.buttons[l.done].tap()
        }

        app.terminate()
    }

    private func shoot(_ name: String, _ lang: String) {
        let shot = XCUIScreen.main.screenshot()
        let att = XCTAttachment(screenshot: shot)
        att.name = "\(name)__\(lang)"
        att.lifetime = .keepAlways
        add(att)
    }
}
