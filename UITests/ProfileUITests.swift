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

    // E-PRF-05: гейты «Данных» — пусто → тап объясняет алертом; rich → работает.
    // Form ленивая: до секции «Данные» надо доскроллить, иначе строк нет в иерархии.
    func testDataGatesEmptyVsRich() {
        var app = XCUIApplication.pudding(seed: "child")
        app.acceptDisclaimer()
        app.openTab("Профиль")
        app.swipeUp()
        // Пусто: тап по PDF → объясняющий алерт «Пока рано».
        app.buttons["Дневник для педиатра"].waitTap(timeout: 8)
        app.alerts["Пока рано"].assertExists(timeout: 4,
            "тап по недоступному экспорту должен объяснить почему")
        app.alerts.buttons["Понятно"].tap()

        app.terminate()
        app = XCUIApplication.pudding(seed: "rich")
        app.acceptDisclaimer()
        app.openTab("Профиль")
        app.swipeUp()
        // Rich: рекап реально открывается (не алерт).
        app.buttons["Рекап месяца"].waitTap(timeout: 8)
        app.navigationBars["Рекап месяца"].assertExists(timeout: 6,
            "при наличии данных рекап должен открыться")
        app.navigationBars["Рекап месяца"].buttons["Готово"].tap()
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
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Погнали'")).firstMatch.waitTap()
        app.staticTexts["Прежде чем начать"].assertExists(timeout: 8,
            "после сброса гейт дисклеймера должен показаться снова")
        app.buttons["Понятно"].tap()
        let todayTab = app.tabBars.buttons["Сегодня"]
        todayTab.assertExists(timeout: 6)
        // Регресс: сброс шёл из Профиля — синглтон-роутер не должен утащить на
        // старый таб, свежий старт всегда с главной.
        XCTAssertTrue(todayTab.isSelected, "после онбординга должен быть выбран таб «Сегодня»")
    }
}
