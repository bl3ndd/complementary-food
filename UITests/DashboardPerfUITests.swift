import XCTest

/// Замер плавности скролла главной на реальном объёме дневника (флаг `-demo`,
/// ~450 записей за 4 месяца). Гоняется руками:
/// `TEST_RUNNER_PERF=1 xcodebuild test -only-testing:PrikormUITests/DashboardPerfUITests`.
///
/// Зачем: «главная подлагивает при скролле» — субъективно. Здесь цифра, которую
/// можно сравнить до/после правок (сводки считаются один раз за проход body,
/// а не по три-шесть раз на каждый кадр).
final class DashboardPerfUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(ProcessInfo.processInfo.environment["PERF"] == "1",
                          "перф-замер: запускать с TEST_RUNNER_PERF=1")
    }

    func testScrollDashboard() {
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

        let scroll = app.scrollViews.firstMatch
        XCTAssertTrue(scroll.waitForExistence(timeout: 5), "нет скроллвью на главной")

        // Прогрев: первый проход строит вьюху с нуля, в среднее не берём.
        scroll.swipeUp(velocity: .fast)
        scroll.swipeDown(velocity: .fast)

        // Хитчи скролла — то, что глаз читает как «подлагивает».
        measure(metrics: [XCTOSSignpostMetric.scrollDecelerationMetric,
                          XCTClockMetric()]) {
            scroll.swipeUp(velocity: .fast)
            scroll.swipeUp(velocity: .fast)
            scroll.swipeDown(velocity: .fast)
            scroll.swipeDown(velocity: .fast)
        }
    }
}
