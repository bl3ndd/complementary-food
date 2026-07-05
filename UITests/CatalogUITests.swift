import XCTest

/// E-CAT-01…05: каталог — поиск (вхождение/опечатка/категория), статус-бейджи,
/// свой продукт (создание/удаление с подтверждением).
final class CatalogUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    func testSearchExactTypoAndCategory() {
        let app = XCUIApplication.pudding(seed: "introduced")
        app.acceptDisclaimer()
        app.openTab("Каталог")

        let search = app.textFields["Поиск продукта"]
        search.assertExists(timeout: 6)

        // Опечатка (E-CAT-02): «брокол» находит брокколи; бейдж статуса (E-CAT-03) —
        // label строки склеен: «Брокколи, Введён».
        search.tap()
        search.typeText("брокол")
        app.row(containing: "Брокколи").assertExists(timeout: 4, "опечатка не находит продукт")
        app.buttons.matching(NSPredicate(
            format: "label CONTAINS 'Брокколи' AND label CONTAINS 'Введён'"))
            .firstMatch.assertExists(timeout: 3, "нет статус-бейджа в строке")

        // Поиск по категории: «овощи» → вся категория. Крестик очистки — сосед
        // TextField (не потомок), чистим бэкспейсами.
        search.tap()
        search.typeText(String(repeating: "\u{8}", count: 6))
        search.typeText("овощи")
        app.row(containing: "Кабачок").assertExists(timeout: 4, "категория не находит продукты")
        app.row(containing: "Брокколи").assertExists(timeout: 2)
    }

    func testCustomFoodCreateAndDelete() {
        let app = XCUIApplication.pudding(seed: "child")
        app.acceptDisclaimer()
        app.openTab("Каталог")

        // E-CAT-04: создать свой продукт.
        app.buttons["Добавить свой продукт"].waitTap()
        app.navigationBars["Свой продукт"].assertExists(timeout: 5)
        let name = app.textFields["Например: компот"]
        name.waitTap()
        name.typeText("Компотик\n")
        app.buttons["Добавить"].waitTap()

        // Появился в секции «Свои продукты» со статусом «Введён» (сразу в коллекции).
        let search = app.textFields["Поиск продукта"]
        search.waitTap()
        search.typeText("компотик")
        app.row(containing: "Компотик").assertExists(timeout: 5, "свой продукт не появился")
        app.buttons.matching(NSPredicate(
            format: "label CONTAINS 'Компотик' AND label CONTAINS 'Введён'"))
            .firstMatch.assertExists(timeout: 3, "свой продукт должен быть сразу введён")

        // E-CAT-05: свайп-удаление с подтверждением.
        app.row(containing: "Компотик").swipeLeft()
        app.buttons["Удалить"].waitTap()
        app.alerts.buttons["Удалить"].waitTap()
        XCTAssertFalse(app.row(containing: "Компотик").waitForExistence(timeout: 3),
                       "свой продукт не удалился")
    }
}
