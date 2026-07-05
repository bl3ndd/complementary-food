import XCTest

/// E-PRF-01…07: профиль — секции, план (предупреждение пустых аллергенов),
/// гейты «Данных», сброс → онбординг → гейт дисклеймера снова.
final class ProfileUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    // E-PRF-01/04/06: все секции на месте.
    func testSectionsPresent() {
        let app = XCUIApplication.pudding(seed: "rich")
        app.acceptDisclaimer()
        app.openTab("Профиль")

        app.textFields["Имя малыша"].assertExists(timeout: 8, "нет поля имени")
        XCTAssertEqual(app.textFields["Имя малыша"].value as? String, "Ника")
        app.staticTexts["Напоминания"].assertExists()
        app.staticTexts["Язык"].firstMatch.assertExists()
        app.staticTexts["Дневник для педиатра"].assertExists()
        // Низ формы: легалка и сброс.
        app.swipeUp(); app.swipeUp()
        app.staticTexts["Политика конфиденциальности"].assertExists(timeout: 4)
        app.staticTexts["Версия"].assertExists(timeout: 2)
        app.staticTexts["Сбросить все данные"].assertExists(timeout: 2)
    }

    // E-PRF-05: гейты «Данных» — пусто → выключены; rich → включены.
    // Form ленивая: до секции «Данные» надо доскроллить, иначе строк нет в иерархии.
    func testDataGatesEmptyVsRich() {
        var app = XCUIApplication.pudding(seed: "child")
        app.acceptDisclaimer()
        app.openTab("Профиль")
        app.swipeUp()
        let pdfEmpty = app.buttons["Дневник для педиатра"]
        pdfEmpty.assertExists(timeout: 8)
        XCTAssertFalse(pdfEmpty.isEnabled, "PDF должен быть выключен без записей")
        let recapEmpty = app.buttons["Рекап месяца"]
        recapEmpty.assertExists(timeout: 4)
        XCTAssertFalse(recapEmpty.isEnabled, "рекап без данных должен быть выключен")

        app.terminate()
        app = XCUIApplication.pudding(seed: "rich")
        app.acceptDisclaimer()
        app.openTab("Профиль")
        app.swipeUp()
        let pdfRich = app.buttons["Дневник для педиатра"]
        pdfRich.assertExists(timeout: 8)
        XCTAssertTrue(pdfRich.isEnabled, "PDF должен быть доступен при записях")
        let avoid = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'не давать'")).firstMatch
        avoid.assertExists(timeout: 4)
        XCTAssertTrue(avoid.isEnabled, "«не давать» должен быть доступен (треска на паузе)")
    }

    // E-PRF-02: план — снятие всех аллергенов показывает предупреждение.
    func testPlanEditorEmptyAllergenWarning() {
        let app = XCUIApplication.pudding(seed: "child")
        app.acceptDisclaimer()
        app.openTab("Профиль")

        app.staticTexts["Твой план"].firstMatch.waitTap()
        app.navigationBars["Твой план прикорма"].assertExists(timeout: 5)
        app.staticTexts["Аллергены для ввода"].assertExists(timeout: 4)

        // Снять все 9 групп (Big-9 включены по умолчанию).
        for group in ["Яйцо", "Арахис", "Орехи", "Молочные", "Глютен",
                      "Рыба", "Морепродукты", "Соя", "Кунжут"] {
            let chip = app.buttons[group].firstMatch
            if !chip.isHittable { app.swipeUp() }
            chip.waitTap(timeout: 4)
        }
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Не выбран ни один аллерген'"))
            .firstMatch.assertExists(timeout: 4, "нет предупреждения о пустом наборе")

        // Вернуть один — предупреждение уходит.
        app.buttons["Яйцо"].firstMatch.tap()
        XCTAssertFalse(app.staticTexts
            .matching(NSPredicate(format: "label CONTAINS 'Не выбран ни один аллерген'"))
            .firstMatch.waitForExistence(timeout: 2))
    }

    // E-PRF-07: сброс → онбординг; после нового онбординга гейт дисклеймера снова.
    func testResetLeadsToOnboardingAndGateAgain() {
        let app = XCUIApplication.pudding(seed: "child")
        app.acceptDisclaimer()
        app.openTab("Профиль")

        app.swipeUp(); app.swipeUp()
        app.buttons["Сбросить все данные"].waitTap()
        app.alerts.buttons["Сбросить"].waitTap()

        // Онбординг с нуля.
        app.staticTexts["Pudding"].assertExists(timeout: 8, "сброс не вернул к онбордингу")
        app.buttons["Далее"].waitTap()
        app.buttons["Далее"].waitTap()
        app.buttons["Далее"].waitTap()
        app.buttons["Погнали! 🚀"].waitTap()
        app.staticTexts["Прежде чем начать"].assertExists(timeout: 8,
            "после сброса гейт дисклеймера должен показаться снова")
        app.buttons["Понятно"].tap()
        app.tabBars.buttons["Сегодня"].assertExists(timeout: 6)
    }
}
