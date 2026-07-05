import XCTest

/// E-CAL-01…12: календарь — лента/фильтры/поиск, месяц («К сегодня», день),
/// планы (дедуп, «Выполнено»), long-press, экспорт-меню, рекап.
final class CalendarUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    func testFeedFiltersAndSearch() {
        let app = XCUIApplication.pudding(seed: "rich")
        app.acceptDisclaimer()
        app.openTab("Календарь")

        // E-CAL-01: лента по умолчанию — записи + секция планов (заголовок капсом:
        // .textCase(.uppercase) → «ПЛАНЫ»).
        app.staticTexts["ПЛАНЫ"].assertExists(timeout: 8, "нет секции планов")
        app.staticTexts["Груша"].assertExists(timeout: 4)
        app.staticTexts["Брокколи"].firstMatch.assertExists(timeout: 4)

        // E-CAL-02: чип «Реакции» — остаётся только запись с реакцией.
        app.buttons["Реакции"].firstMatch.waitTap()
        app.staticTexts["Кожа (сыпь)"].firstMatch.assertExists(timeout: 4)
        XCTAssertFalse(app.staticTexts["Груша"].exists, "план не должен попадать в «Реакции»")

        // E-CAL-09: чип «Планы» → «Выполнено» на сегодняшнем плане (яблоко) → факт.
        app.buttons["Планы"].firstMatch.waitTap()
        app.staticTexts["Яблоко"].assertExists(timeout: 4)
        app.buttons["Выполнено"].firstMatch.waitTap()
        app.allowNotificationsIfAsked()
        XCTAssertFalse(app.staticTexts["Яблоко"].waitForExistence(timeout: 4),
                       "выполненный план должен уйти из фильтра «Планы»")

        // E-CAL-03: чип «Всё» + поиск по заметке.
        app.buttons["Всё"].firstMatch.waitTap()
        let search = app.searchFields.firstMatch
        search.waitTap()
        search.typeText("сыпь")
        app.staticTexts["Брокколи"].firstMatch.assertExists(timeout: 4,
            "поиск по заметке не нашёл запись")
    }

    func testMonthGridTodayAndDayDetail() {
        let app = XCUIApplication.pudding(seed: "rich")
        app.acceptDisclaimer()
        app.openTab("Календарь")

        // E-CAL-04: сегмент «Месяц» → сетка.
        app.buttons["Месяц"].firstMatch.waitTap()
        app.staticTexts["Пн"].assertExists(timeout: 5, "нет сетки месяца")

        // Листание назад → «К сегодня» возвращает.
        app.buttons["Предыдущий месяц"].waitTap()
        app.buttons["К сегодня"].waitTap()
        XCTAssertFalse(app.buttons["К сегодня"].waitForExistence(timeout: 2),
                       "«К сегодня» должна исчезать в текущем месяце")

        // E-CAL-05/06: тап дня с записями → детали дня с ретро-кнопкой.
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'есть записи'"))
            .firstMatch.waitTap()
        app.buttons["Записать кормление"].assertExists(timeout: 5,
            "в деталях прошедшего дня нет ретро-записи кормления")
    }

    func testPlanDedupAlert() {
        let app = XCUIApplication.pudding(seed: "rich")
        app.acceptDisclaimer()
        app.openTab("Календарь")

        // E-CAL-08: яблоко уже запланировано на сегодня → повторный выбор → алерт.
        // Поиск — именно поле шита («Поиск продукта»), а не календаря позади.
        app.buttons["Запланировать ввод"].waitTap()
        let search = app.searchFields["Поиск продукта"]
        search.waitTap()
        search.typeText("яблоко")
        app.row(containing: "Яблоко").waitTap()
        app.alerts["Уже запланировано"].assertExists(timeout: 4, "нет дедупа планов")
        app.alerts.buttons["Ок"].tap()
        // Закрыть шит, если ещё открыт (ядро кейса — сам алерт дедупа выше).
        let cancel = app.navigationBars["Запланировать ввод"].buttons["Отмена"]
        if cancel.waitForExistence(timeout: 2) { cancel.tap() }
    }

    func testLongPressExportMenuAndRecap() {
        let app = XCUIApplication.pudding(seed: "rich")
        app.acceptDisclaimer()
        app.openTab("Календарь")

        // E-CAL-10: long-press записи → контекст-меню с «Удалить» → алерт → отмена.
        app.staticTexts["Брокколи"].firstMatch.press(forDuration: 1.2)
        app.buttons["Удалить"].waitTap()
        app.alerts.buttons["Отмена"].waitTap()

        // E-CAL-11: экспорт-меню содержит оба документа.
        app.buttons["Экспорт"].waitTap()
        app.buttons["Дневник для педиатра"].assertExists(timeout: 4)
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'Не давать'"))
            .firstMatch.assertExists(timeout: 2)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)).tap()   // закрыть меню

        // E-CAL-12: рекап месяца.
        app.buttons["Рекап месяца"].waitTap()
        app.navigationBars["Рекап месяца"].assertExists(timeout: 6)
        app.buttons["Поделиться"].assertExists(timeout: 4)
        app.navigationBars["Рекап месяца"].buttons["Готово"].tap()
    }
}
