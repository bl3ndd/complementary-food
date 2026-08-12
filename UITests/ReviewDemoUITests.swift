import XCTest

/// Демо-прогон для App Review: сценарий «как пользоваться», который снимается в видео
/// и прикладывается к заявке (App Review Information → Attachment).
///
/// Запускается ТОЛЬКО с env `DEMO=1` (`TEST_RUNNER_DEMO=1` в xcodebuild) — в обычных
/// прогонах скипается. Язык — английский: ревью в Купертино.
/// Паузы намеренные: видео должно читаться человеком, а не мигать экранами.
/// Порядок шагов повторяет то, что написано в Review Notes: дисклеймер ДО данных
/// ребёнка (1.4.1) → свой план → запись кормления → прогресс ввода по кормлениям →
/// аллергены → дневник → «О приложении» со ссылками на политику.
final class ReviewDemoUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(ProcessInfo.processInfo.environment["DEMO"] == "1",
                          "демо-режим: запускать с TEST_RUNNER_DEMO=1")
    }

    /// Пауза «дать посмотреть»: в видео кадр должен успеть прочитаться.
    private func beat(_ seconds: UInt32 = 2) { sleep(seconds) }

    func testRecordReviewDemo() {
        let app = XCUIApplication()
        // Без сида — чистая установка: ревьюер видит ровно то, что увидит пользователь.
        app.launchArguments = ["-uitest", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        // 1. Welcome.
        app.staticTexts["Pudding"].assertExists(timeout: 10, "нет welcome-экрана")
        beat(3)
        app.buttons["Next"].waitTap()

        // 2. Медицинский дисклеймер — ДО любых данных ребёнка (1.4.1).
        app.staticTexts["Before you start"].assertExists(timeout: 5, "нет дисклеймера")
        beat(6)   // дать прочитать целиком — это ключевой кадр для ревью
        app.buttons["Got it"].waitTap()

        // 3. Данные ребёнка.
        let name = app.textFields["Baby's name"]
        name.assertExists()
        name.tap()
        name.typeText("Nika\n")
        beat()
        app.buttons["Next"].waitTap()

        // 4. Свой план: окна наблюдения и список аллергенов задаёт пользователь.
        app.staticTexts["Your feeding plan"].assertExists(timeout: 4, "нет шага плана")
        beat(4)
        app.buttons["Next"].waitTap()

        // 5. «Что уже ввели» — отметка не создаёт записей в дневнике.
        app.staticTexts["Already introduced?"].assertExists(timeout: 4)
        beat(2)
        app.row(containing: "Broccoli").waitTap()
        beat()
        // Апостроф в «Let's go» ломает литерал в предикате — подставляем аргументом.
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Let's go"))
            .firstMatch.waitTap()
        app.allowNotificationsIfAsked()

        // 6. Главная.
        app.tabBars.buttons["Today"].assertExists(timeout: 8, "таббар не появился")
        beat(3)

        // 7. Каталог → карточка продукта. Поиск набираем ЛАТИНИЦЕЙ: показываем, что
        // продукты ищутся на языке интерфейса.
        // Хелперы openFoodCard/openTab прибиты к русским подписям — здесь EN, вручную.
        app.tabBars.buttons["Catalog"].waitTap()
        let catalogSearch = app.textFields["Search foods"]
        catalogSearch.assertExists(timeout: 5)
        catalogSearch.tap()
        catalogSearch.typeText("banana")
        beat(2)
        app.row(containing: "Banana").waitTap()
        app.navigationBars["Banana"].assertExists(timeout: 5)
        beat(3)

        // 8. Ввод начинает пользователь — приложение ничего не решает за него.
        app.buttons["Start introducing"].waitTap()
        beat(4)   // статус «Introducing», окно наблюдения пошло

        // 9. Кормление прямо с карточки → прогресс «1 of 2 feedings».
        app.buttons["Log a feeding"].firstMatch.waitTap()
        app.navigationBars["Feeding entry"].assertExists(timeout: 5)
        beat(3)   // видно оценку «как зашло», заметку и фото
        app.buttons["Save"].waitTap()
        app.allowNotificationsIfAsked()
        beat(5)   // кольцо на карточке: продукт введётся после кормлений в разные дни

        // 10. Главная: запись в дневнике за сегодня + карточка «Introducing now».
        app.tabBars.buttons["Today"].waitTap()
        app.staticTexts["Today's journal"].assertExists(timeout: 8)
        beat(5)

        // 11. Аллергены — напоминания повторить введённое.
        app.tabBars.buttons["Allergens"].waitTap()
        beat(4)

        // 12. Дневник-календарь.
        app.tabBars.buttons["Calendar"].waitTap()
        beat(4)

        // 13. Профиль → «О приложении»: дисклеймер, политика, условия, поддержка.
        app.tabBars.buttons["Profile"].waitTap()
        beat(2)
        app.swipeUp()
        beat(2)
        app.swipeUp()
        app.staticTexts["About"].assertExists(timeout: 5, "нет секции «О приложении»")
        beat(6)
    }
}
