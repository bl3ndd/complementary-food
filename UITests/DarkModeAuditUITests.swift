import XCTest

/// Обход всех экранов в ТЁМНОЙ теме со снимками — чтобы ловить прибитые светлые
/// поверхности глазами, а не грепом (греп уже один раз пропустил
/// `listRowBackground(Color.white)` в каталоге).
///
/// Запуск: `TEST_RUNNER_DARKAUDIT=1 xcodebuild test -only-testing:PrikormUITests/DarkModeAuditUITests`.
/// Тема форсится аргументом `-app.theme dark` (его читает `@AppStorage`).
final class DarkModeAuditUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = true
        try XCTSkipUnless(ProcessInfo.processInfo.environment["DARKAUDIT"] == "1",
                          "аудит тёмной темы: запускать с TEST_RUNNER_DARKAUDIT=1")
    }

    private enum Tab: Int { case today = 0, catalog = 1, calendar = 2, allergens = 3, profile = 4 }

    func testWalkAllScreensInDark() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-uitest-seed=showcase",
                               "-app.theme", "dark",
                               "-AppleLanguages", "(ru)", "-AppleLocale", "ru_RU"]
        app.launch()

        let gate = app.buttons["Понятно"]
        if gate.waitForExistence(timeout: 3) { gate.tap() }
        dismissSystemAlert()

        XCTAssertTrue(app.staticTexts["Ника"].waitForExistence(timeout: 8), "главная не загрузилась")
        sleep(2)
        shoot("01_Сегодня")

        // Каталог: список с секциями — тут и был белый listRowBackground.
        app.tabBars.buttons.element(boundBy: Tab.catalog.rawValue).tap()
        sleep(1)
        shoot("02_Каталог")

        // Фильтры каталога — активный чип.
        let paused = app.buttons["Пауза"]
        if paused.waitForExistence(timeout: 3) {
            paused.tap(); sleep(1); shoot("03_Каталог_фильтр")
            app.buttons["Всё"].tap(); sleep(1)
        }

        // Карточка продукта.
        let firstFood = app.cells.element(boundBy: 0)
        if firstFood.waitForExistence(timeout: 3) {
            firstFood.tap(); sleep(1); shoot("04_Карточка_продукта")

            // Лист записи кормления — чипы оценки и даты.
            let log = app.buttons["Записать кормление"]
            if log.waitForExistence(timeout: 3) {
                log.tap(); sleep(1); shoot("05_Запись_кормления")
                app.buttons["Отмена"].tap(); sleep(1)
            }
            popBack(app)
        }

        // Календарь: лента и сетка месяца.
        app.tabBars.buttons.element(boundBy: Tab.calendar.rawValue).tap()
        sleep(1)
        shoot("06_Календарь_лента")
        let month = app.buttons["Месяц"]
        if month.waitForExistence(timeout: 3) { month.tap(); sleep(1); shoot("07_Календарь_месяц") }

        // Рекап — он намеренно светлый (шэр-картинка), проверяем что не сломан.
        let recap = app.buttons["screenshot.recap"]
        if recap.waitForExistence(timeout: 3), recap.isEnabled {
            recap.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            sleep(2); shoot("08_Рекап")
            app.buttons["Готово"].firstMatch.tap(); sleep(1)
        }

        app.tabBars.buttons.element(boundBy: Tab.allergens.rawValue).tap()
        sleep(1)
        shoot("09_Аллергены")

        // Профиль: Form — системные группы, их тоже надо увидеть.
        app.tabBars.buttons.element(boundBy: Tab.profile.rawValue).tap()
        sleep(1)
        shoot("10_Профиль")

        // Редактор плана (пуш из профиля).
        let plan = app.buttons["Твой план"]
        if plan.waitForExistence(timeout: 3) {
            plan.tap(); sleep(1); shoot("11_План")
            popBack(app)
        }

        app.terminate()
    }

    private func dismissSystemAlert() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let alert = springboard.alerts.firstMatch
        if alert.waitForExistence(timeout: 3) {
            alert.buttons.element(boundBy: alert.buttons.count - 1).tap()
        }
    }

    private func popBack(_ app: XCUIApplication) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.5))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end)
        sleep(1)
    }

    private func shoot(_ name: String) {
        let att = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        att.name = name
        att.lifetime = .keepAlways
        add(att)
    }
}
