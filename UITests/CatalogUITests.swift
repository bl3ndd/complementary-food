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

        // Опечатка (E-CAT-02): «брокол» находит брокколи; бейдж статуса (E-CAT-03).
        search.tap()
        search.typeText("брокол")
        app.buttons["Брокколи"].firstMatch.assertExists(timeout: 4, "опечатка не находит продукт")
        app.staticTexts["Введён"].assertExists(timeout: 3, "нет статус-бейджа в строке")

        // Поиск по категории: «овощи» → вся категория.
        search.buttons.firstMatch.tap()   // очистить (крестик)
        search.typeText("овощи")
        app.buttons["Кабачок"].firstMatch.assertExists(timeout: 4, "категория не находит продукты")
        app.buttons["Брокколи"].firstMatch.assertExists(timeout: 2)
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
        app.buttons["Компотик"].firstMatch.assertExists(timeout: 5, "свой продукт не появился")
        app.staticTexts["Введён"].assertExists(timeout: 3, "свой продукт должен быть сразу введён")

        // E-CAT-05: свайп-удаление с подтверждением.
        app.buttons["Компотик"].firstMatch.swipeLeft()
        app.buttons["Удалить"].waitTap()
        app.alerts.buttons["Удалить"].waitTap()
        XCTAssertFalse(app.buttons["Компотик"].waitForExistence(timeout: 3),
                       "свой продукт не удалился")
    }
}
