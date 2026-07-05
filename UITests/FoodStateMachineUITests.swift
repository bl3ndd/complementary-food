import XCTest

/// E-FOOD-01…09: карточка продукта — вся стейт-машина ввода, реакции, история,
/// аккордеон пользы. Каждый тест — свой сид и свежий запуск.
final class FoodStateMachineUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    // E-FOOD-01/02: не введён → старт → вводится (день 1, primary + меню «…»).
    func testStartIntroduction() {
        let app = XCUIApplication.pudding(seed: "child")
        app.acceptDisclaimer()
        app.openFoodCard("брокк", rowTitle: "Брокколи")

        app.staticTexts["Не введён"].assertExists()
        app.buttons["Начать введение"].waitTap()
        app.allowNotificationsIfAsked()

        app.staticTexts["Вводится"].assertExists(timeout: 5)
        app.staticTexts["День 1 из 3"].assertExists(timeout: 4, "нет счётчика окна")
        app.buttons["Записать кормление"].assertExists(timeout: 4, "нет primary-действия")

        // Меню «…»: вторичные действия.
        app.buttons["food.more"].waitTap()
        app.buttons["Была реакция"].assertExists(timeout: 4)
        app.buttons["Приостановить ввод"].assertExists(timeout: 2)
        // Закрыть меню тапом вне.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15)).tap()
    }

    // E-FOOD-03: окно прошло → «Ввёл успешно» → поздравление → введён + сводка.
    func testCompleteIntroductionAfterWindow() {
        let app = XCUIApplication.pudding(seed: "window-done")
        app.acceptDisclaimer()
        app.openFoodCard("брокк", rowTitle: "Брокколи")

        app.buttons["Ввёл успешно ✅"].waitTap()
        app.staticTexts["Продукт введён! 🎉"].assertExists(timeout: 4, "нет поздравления")
        app.staticTexts["Введён"].assertExists(timeout: 6)
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Кормлений'"))
            .firstMatch.assertExists(timeout: 4, "нет строки-сводки у введённого")
    }

    // E-FOOD-06/07: пауза → «через 2 месяца» → возобновить; окно НЕ скипается.
    func testPauseRetryResumeDoesNotSkipWindow() {
        let app = XCUIApplication.pudding(seed: "window-done")
        app.acceptDisclaimer()
        app.openFoodCard("брокк", rowTitle: "Брокколи")

        // Пауза с подтверждением.
        app.buttons["food.more"].waitTap()
        app.buttons["Приостановить ввод"].waitTap()
        app.alerts.buttons["Приостановить"].waitTap()
        app.staticTexts["Пауза"].assertExists(timeout: 5)

        // «Попробовать через 2 месяца» → появляется срок напоминания.
        app.buttons["food.more"].waitTap()
        app.buttons["Попробовать через 2 месяца"].waitTap()
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Напомним попробовать'"))
            .firstMatch.assertExists(timeout: 4, "нет строки о retry-напоминании")

        // Возобновить → «Вводится», окно с НАЧАЛА (E-FOOD-07: старые логи не скипают).
        app.buttons["Возобновить ввод"].waitTap()
        app.allowNotificationsIfAsked()
        app.staticTexts["Вводится"].assertExists(timeout: 5)
        app.staticTexts["День 1 из 3"].assertExists(timeout: 4,
            "повторный ввод должен начинать окно заново")
        app.buttons["Записать кормление"].assertExists(timeout: 4,
            "primary должен быть «Записать кормление», а не «Ввёл успешно»")
    }

    // E-FOOD-04/05: введён → пометить аллергию → вернуть в оборот.
    func testMarkAllergyAndReturn() {
        let app = XCUIApplication.pudding(seed: "introduced")
        app.acceptDisclaimer()
        app.openFoodCard("брокк", rowTitle: "Брокколи")

        app.staticTexts["Введён"].assertExists()
        app.buttons["food.more"].waitTap()
        app.buttons["Пометить аллергию"].waitTap()
        app.alerts.buttons["Пометить аллергию"].waitTap()

        app.staticTexts["Аллергия"].assertExists(timeout: 5)
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Зафиксирована аллергия'"))
            .firstMatch.assertExists(timeout: 4, "нет предупреждения об аллергии")

        app.buttons["Вернуть в оборот (врач разрешил)"].waitTap()
        app.staticTexts["Вводится"].assertExists(timeout: 5, "возврат в оборот не сработал")
    }

    // E-LOG-02 + E-FOOD-09: реакция (без «дыхания») → бейдж в истории → правка/удаление.
    func testReactionSheetAndHistoryEdit() {
        let app = XCUIApplication.pudding(seed: "introduced")
        app.acceptDisclaimer()
        app.openFoodCard("брокк", rowTitle: "Брокколи")

        app.buttons["food.more"].waitTap()
        app.buttons["Была реакция"].waitTap()
        app.navigationBars["Запись реакции"].assertExists(timeout: 5)

        // Сетка реакций: «дыхания» нет, запор/диарея есть.
        XCTAssertFalse(app.buttons["Затруднённое дыхание"].exists,
                       "«Затруднённое дыхание» должно быть убрано из выбора")
        app.buttons["Запор"].assertExists(timeout: 3)
        app.buttons["Диарея"].assertExists(timeout: 2)

        app.buttons["Кожа (сыпь)"].waitTap()
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Реакция сохранится'"))
            .firstMatch.assertExists(timeout: 3, "нет пояснения, что реакция — только запись")
        app.buttons["Сохранить"].waitTap()
        app.allowNotificationsIfAsked()

        // История: запись с бейджем реакции; тап → правка; удаление с алертом.
        app.staticTexts["История"].assertExists(timeout: 6)
        app.staticTexts["Кожа (сыпь)"].firstMatch.assertExists(timeout: 4,
            "реакция не попала в историю")
        app.staticTexts["Кормление"].firstMatch.waitTap()
        app.navigationBars["Запись"].assertExists(timeout: 5)
        app.buttons["Удалить запись"].waitTap()
        app.alerts.buttons["Удалить"].waitTap()
        XCTAssertFalse(app.navigationBars["Запись"].waitForExistence(timeout: 3),
                       "правка должна закрыться после удаления")
    }

    // E-FOOD-08: аккордеон «Чем полезен» раскрывается.
    func testBenefitsAccordion() {
        let app = XCUIApplication.pudding(seed: "child")
        app.acceptDisclaimer()
        app.openFoodCard("брокк", rowTitle: "Брокколи")

        XCTAssertFalse(app.staticTexts["Витамин C"].exists, "аккордеон должен быть свёрнут")
        app.buttons["Чем полезен"].firstMatch.waitTap()
        app.staticTexts["Витамин C"].assertExists(timeout: 4, "нутриенты не раскрылись")
    }
}
