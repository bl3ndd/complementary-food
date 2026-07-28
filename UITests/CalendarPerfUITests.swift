import XCTest

/// Замер перехода на «Календарь» на реальном объёме дневника (флаг `-demo`,
/// ~450 записей за 4 месяца). Гоняется руками:
/// `TEST_RUNNER_PERF=1 xcodebuild test -only-testing:PrikormUITests/CalendarPerfUITests`.
///
/// Зачем: «подлагивает при переходе» — субъективно. Здесь цифра, которую можно
/// сравнить до/после правок (ленивая лента + один расчёт сводок вместо 42).
final class CalendarPerfUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(ProcessInfo.processInfo.environment["PERF"] == "1",
                          "перф-замер: запускать с TEST_RUNNER_PERF=1")
    }

    func testSwitchToCalendarTab() {
        let app = XCUIApplication()
        app.launchArguments = ["-demo", "-AppleLanguages", "(ru)", "-AppleLocale", "ru_RU"]
        app.launch()

        let gate = app.buttons["Понятно"]
        if gate.waitForExistence(timeout: 3) { gate.tap() }
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let alert = springboard.alerts.firstMatch
        if alert.waitForExistence(timeout: 3) {
            alert.buttons.element(boundBy: alert.buttons.count - 1).tap()
        }
        XCTAssertTrue(app.staticTexts["Ника"].waitForExistence(timeout: 10))

        let tabs = app.tabBars.buttons
        let today = tabs.element(boundBy: 0)
        let calendar = tabs.element(boundBy: 2)

        // Прогрев: первый заход строит вьюху с нуля, его в среднее не берём.
        calendar.tap()
        _ = app.staticTexts["Дневник"].waitForExistence(timeout: 5)
        today.tap()

        measure(metrics: [XCTClockMetric()]) {
            calendar.tap()
            _ = app.staticTexts["Дневник"].waitForExistence(timeout: 5)
            today.tap()
            _ = app.staticTexts["Ника"].waitForExistence(timeout: 5)
        }
    }

    /// Переключение «Лента ↔ Месяц» на том же объёме данных.
    func testSwitchFeedAndMonth() {
        let app = XCUIApplication()
        app.launchArguments = ["-demo", "-AppleLanguages", "(ru)", "-AppleLocale", "ru_RU"]
        app.launch()

        let gate = app.buttons["Понятно"]
        if gate.waitForExistence(timeout: 3) { gate.tap() }
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let alert = springboard.alerts.firstMatch
        if alert.waitForExistence(timeout: 3) {
            alert.buttons.element(boundBy: alert.buttons.count - 1).tap()
        }
        XCTAssertTrue(app.staticTexts["Ника"].waitForExistence(timeout: 10))
        app.tabBars.buttons.element(boundBy: 2).tap()

        let month = app.buttons["Месяц"]
        let feed = app.buttons["Лента"]
        XCTAssertTrue(month.waitForExistence(timeout: 5))

        // ⚠️ Wall-clock тут почти не двигается: его съедают запросы XCUITest по
        // дереву доступности (сотни строк ленты), а не отрисовка. Метрика хитчей
        // (animationOverTimeMetric) данных не даёт — SwiftUI не эмитит нужные
        // сигнпосты. То есть этот замер ловит регрессии «в разы», но не джанк.
        measure(metrics: [XCTClockMetric()]) {
            month.tap()
            _ = app.staticTexts["есть записи"].waitForExistence(timeout: 5)   // легенда сетки
            feed.tap()
            _ = app.buttons["Реакции"].waitForExistence(timeout: 5)
        }
    }
}
