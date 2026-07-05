import XCTest

/// E-DASH-01…11: главная — hero, плитки быстрой записи, дневник за сегодня,
/// «Сейчас вводишь», коллекция, карточка аллергенов.
final class DashboardUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    func testHeroAndQuickFeedFlow() {
        let app = XCUIApplication.pudding(seed: "rich")
        app.acceptDisclaimer()

        // E-DASH-01: hero с именем и капсулой записей.
        app.staticTexts["Ника"].assertExists(timeout: 8, "нет имени в hero")

        // E-DASH-02: плитка «Записать» → список продуктов.
        app.buttons["Записать"].firstMatch.waitTap()
        app.navigationBars["Записать кормление"].assertExists(timeout: 5)

        // Выбор продукта через поиск в листе.
        let search = app.searchFields["Поиск продукта"]
        search.assertExists()
        search.tap()
        search.typeText("банан")
        app.row(containing: "Банан").waitTap()
        app.navigationBars["Запись кормления"].assertExists(timeout: 5)

        // E-DASH-04: «Отмена» в листе записи → возврат к СПИСКУ продуктов, не на главную.
        app.navigationBars["Запись кормления"].buttons["Отмена"].tap()
        app.searchFields["Поиск продукта"].assertExists(timeout: 5,
            "отмена записи должна вернуть к списку продуктов")

        // Снова продукт → Сохранить → запись в «Дневник за сегодня».
        app.row(containing: "Банан").waitTap()
        app.buttons["Сохранить"].waitTap()
        app.allowNotificationsIfAsked()
        app.staticTexts["Дневник за сегодня"].assertExists(timeout: 8)
        app.staticTexts["Банан"].assertExists(timeout: 5, "сохранённое кормление не в дневнике")
    }

    func testTodayRowOpensEditAndIntroducingNavigates() {
        let app = XCUIApplication.pudding(seed: "rich")
        app.acceptDisclaimer()

        // E-DASH-06: тап записи дневника (брокколи, кормление час назад) → правка.
        app.staticTexts["Дневник за сегодня"].assertExists(timeout: 8)
        app.staticTexts["Брокколи"].firstMatch.waitTap()
        app.navigationBars["Запись"].assertExists(timeout: 5, "тап записи не открыл правку")
        app.navigationBars["Запись"].buttons["Отмена"].tap()
        app.navigationBars["Запись"].waitGone()   // дождаться dismiss, иначе тап глотается

        // E-DASH-08: «Сейчас вводишь» (кабачок, день 1) → карточка продукта.
        // Тап строго по строке карточки (в дневнике тоже есть «Кабачок»); карточка
        // ниже фолда — доскроллить, иначе тап уходит мимо экрана.
        app.staticTexts["Сейчас вводишь"].assertExists(timeout: 5)
        // Строка у нижнего края: центр может быть под таб-баром (isHittable при этом
        // true, тап уходит в таб-бар) — всегда доскроллить перед тапом.
        app.swipeUp()
        app.row(containing: "День 1").waitTap()
        app.navigationBars["Кабачок"].assertExists(timeout: 5,
            "строка «Сейчас вводишь» не открыла карточку")
        app.navigationBars["Кабачок"].buttons.firstMatch.tap()   // назад
    }

    func testCollectionAndAllergenCardNavigation() {
        let app = XCUIApplication.pudding(seed: "rich")
        app.acceptDisclaimer()

        // E-DASH-10: «Вся коллекция» → таб Каталог.
        app.staticTexts["Коллекция продуктов"].assertExists(timeout: 8)
        app.buttons["Вся коллекция"].waitTap()
        app.navigationBars["Каталог"].assertExists(timeout: 5, "«Вся коллекция» не открыла каталог")

        // E-DASH-11: назад на Сегодня → карточка «Аллергены» → таб Аллергены.
        app.openTab("Сегодня")
        let card = app.scrollViews.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Аллергены'")).firstMatch
        card.waitTap()
        app.navigationBars["Аллергены"].assertExists(timeout: 5,
            "карточка аллергенов не переключила таб")
    }

    func testPlanButtonOpensSheet() {
        let app = XCUIApplication.pudding(seed: "rich")
        app.acceptDisclaimer()

        // E-DASH-07: «Запланировать» → лист планирования.
        app.buttons["Запланировать"].firstMatch.waitTap()
        app.navigationBars["Запланировать ввод"].assertExists(timeout: 5)
        app.navigationBars["Запланировать ввод"].buttons["Отмена"].tap()
    }
}
