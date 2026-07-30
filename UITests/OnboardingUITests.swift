import XCTest

/// E-ONB-01…04: онбординг, дисклеймер перед данными ребёнка, «Назад», «уже введённые».
final class OnboardingUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    func testFullOnboardingBackButtonAndPreIntroduced() {
        let app = XCUIApplication.pudding()   // без сида → чистая установка → онбординг

        // Шаг 0: Welcome.
        app.staticTexts["Pudding"].assertExists(timeout: 10, "нет welcome-экрана")
        app.buttons["Далее"].waitTap()

        // Шаг 1: дисклеймер — ДО ввода данных ребёнка (1.4.1).
        app.staticTexts["Прежде чем начать"].assertExists(timeout: 5,
            "дисклеймер должен быть перед данными ребёнка")
        app.buttons["Понятно"].waitTap()

        // Шаг 2: ребёнок — вводим имя (E-ONB-01), «\n» прячет клавиатуру.
        let name = app.textFields["Имя малыша"]
        name.assertExists()
        name.tap()
        name.typeText("Ника\n")

        // E-ONB-02: «Назад» возвращает на дисклеймер, имя не теряется.
        app.buttons["Назад"].waitTap()
        app.staticTexts["Прежде чем начать"].assertExists(timeout: 4, "«Назад» не вернул на дисклеймер")
        app.buttons["Понятно"].tap()
        XCTAssertEqual(app.textFields["Имя малыша"].value as? String, "Ника",
                       "имя потерялось после «Назад»")

        // Шаг 3: план.
        app.buttons["Далее"].tap()
        app.staticTexts["Свой план прикорма"].assertExists(timeout: 4, "нет шага плана")

        // Шаг 4: «Что уже ввели?» — отмечаем брокколи (E-ONB-04).
        app.buttons["Далее"].tap()
        app.staticTexts["Что уже ввели?"].assertExists(timeout: 4)
        app.row(containing: "Брокколи").waitTap()

        // Финиш → таббар (дисклеймер уже прочитан на шаге 1) (E-ONB-01).
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Погнали'")).firstMatch.waitTap()
        app.allowNotificationsIfAsked()
        app.tabBars.buttons["Сегодня"].assertExists(timeout: 8, "таббар не появился после онбординга")

        // E-ONB-04: «уже введён» — в дневнике записей НЕТ (никаких фейковых логов).
        app.staticTexts["Ника"].assertExists()
        app.staticTexts["Записей сегодня ещё нет"].assertExists(timeout: 4,
            "отметка «уже введён» не должна создавать запись в дневнике")

        // …а в каталоге брокколи со статусом «Введён».
        app.openFoodCard("брокк", rowTitle: "Брокколи")
        app.staticTexts["Введён"].firstMatch.assertExists(timeout: 4,
            "статус «Введён» не доехал из онбординга")
    }
}
