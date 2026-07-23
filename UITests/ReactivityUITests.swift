import XCTest

/// Реактивность между экранами (docs/REACTIVITY.md): мутация на одном экране
/// обязана БЕЗ перезапуска обновить все зависимые. Каждый тест — одна сессия,
/// переключение табов, ассерты «до/после».
final class ReactivityUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    // R1: кормление с плитки → дневник главной + лента календаря + гейт рекапа.
    func testR1_FeedingPropagatesToDiaryCalendarAndGates() {
        let app = XCUIApplication.pudding(seed: "child")
        app.acceptDisclaimer()

        // До: рекап в профиле закрыт (алерт «Пока рано»).
        app.openTab("Профиль")
        app.swipeUp()
        app.buttons["Рекап месяца"].waitTap(timeout: 8)
        app.alerts["Пока рано"].assertExists(timeout: 4)
        app.alerts.buttons["Понятно"].tap()

        // Мутация: записать кормление банана с плитки главной.
        app.openTab("Сегодня")
        app.buttons["Записать"].firstMatch.waitTap()
        let search = app.searchFields["Поиск продукта"]
        search.waitTap(); search.typeText("банан")
        app.row(containing: "Банан").waitTap()
        app.buttons["Сохранить"].waitTap()
        app.allowNotificationsIfAsked()

        // Дневник главной обновился.
        app.staticTexts["Банан"].assertExists(timeout: 6, "дневник главной не обновился")
        // Лента календаря обновилась.
        app.openTab("Календарь")
        app.staticTexts["Банан"].firstMatch.assertExists(timeout: 6, "лента календаря не обновилась")
        // Гейт рекапа открылся.
        app.openTab("Профиль")
        app.swipeUp()
        app.buttons["Рекап месяца"].waitTap(timeout: 8)
        app.navigationBars["Рекап месяца"].assertExists(timeout: 6,
            "гейт рекапа не отреагировал на появление записи")
        app.navigationBars["Рекап месяца"].buttons["Готово"].tap()
    }

    // R2: свой продукт — знаменатель/счётчик коллекции живут (⚠️ статик-каталог).
    func testR2_CustomFoodUpdatesCollectionCounter() {
        let app = XCUIApplication.pudding(seed: "child")
        app.acceptDisclaimer()

        // До: коллекция пуста, 0/71.
        app.staticTexts["0/71"].assertExists(timeout: 8, "нет стартового счётчика 0/71")

        // Мутация: добавить свой продукт.
        app.openTab("Каталог")
        app.buttons["Добавить свой продукт"].waitTap()
        let name = app.textFields["Например: компот"]
        name.waitTap(); name.typeText("Тестик\n")
        app.buttons["Добавить"].waitTap()

        // Главная: счётчик и знаменатель обновились без перезапуска.
        app.openTab("Сегодня")
        app.staticTexts["1/72"].assertExists(timeout: 6,
            "коллекция не отреагировала на свой продукт (статик-каталог протух?)")

        // Мутация: удалить свой продукт.
        app.openTab("Каталог")
        let search = app.textFields["Поиск продукта"]
        search.waitTap(); search.typeText("тестик")
        app.row(containing: "Тестик").swipeLeft()
        app.buttons["Удалить"].waitTap()
        app.alerts.buttons["Удалить"].waitTap()

        // Главная: счётчик вернулся.
        app.openTab("Сегодня")
        app.staticTexts["0/71"].assertExists(timeout: 6,
            "коллекция не отреагировала на удаление своего продукта")
    }

    // R3: старт ввода → «Сейчас вводишь» + дневник + бейдж в каталоге.
    func testR3_StartIntroductionPropagates() {
        let app = XCUIApplication.pudding(seed: "child")
        app.acceptDisclaimer()

        XCTAssertFalse(app.staticTexts["Сейчас вводишь"].exists)

        app.openFoodCard("брокк", rowTitle: "Брокколи")
        app.buttons["Начать введение"].waitTap()
        app.allowNotificationsIfAsked()
        app.staticTexts["Вводится"].assertExists(timeout: 6)
        app.navigationBars.buttons.firstMatch.tap()   // назад в каталог

        // Каталог: бейдж «Вводится» в строке.
        app.buttons.matching(NSPredicate(
            format: "label CONTAINS 'Брокколи' AND label CONTAINS 'Вводится'"))
            .firstMatch.assertExists(timeout: 5, "бейдж каталога не обновился")

        // Главная: карточка «Сейчас вводишь» + intro-запись в дневнике.
        app.openTab("Сегодня")
        app.staticTexts["Сейчас вводишь"].assertExists(timeout: 6,
            "«Сейчас вводишь» не появилось после старта")
        app.staticTexts["Дневник за сегодня"].assertExists(timeout: 4)
        app.staticTexts["Брокколи"].firstMatch.assertExists(timeout: 4,
            "intro-запись не попала в дневник")
    }

    // R4: «Ввёл успешно» → «Сейчас вводишь» исчез, коллекция 1/71, бейдж «Введён».
    func testR4_CompleteIntroductionPropagates() {
        let app = XCUIApplication.pudding(seed: "window-done")
        app.acceptDisclaimer()

        app.staticTexts["Сейчас вводишь"].assertExists(timeout: 8)
        app.staticTexts["0/71"].assertExists(timeout: 4)

        app.openFoodCard("брокк", rowTitle: "Брокколи")
        app.buttons["Ввёл успешно ✅"].waitTap()
        app.staticTexts["Введён"].assertExists(timeout: 8)
        app.navigationBars.buttons.firstMatch.tap()

        app.buttons.matching(NSPredicate(
            format: "label CONTAINS 'Брокколи' AND label CONTAINS 'Введён'"))
            .firstMatch.assertExists(timeout: 5, "бейдж «Введён» не обновился в каталоге")

        app.openTab("Сегодня")
        app.staticTexts["1/71"].assertExists(timeout: 6, "коллекция не выросла после ввода")
        XCTAssertFalse(app.staticTexts["Сейчас вводишь"].waitForExistence(timeout: 2),
                       "«Сейчас вводишь» должно исчезнуть после завершения")
    }

    // R5: «Дал» аллерген → строка «В норме» + запись в ленте календаря.
    func testR5_GiveAllergenPropagatesToCalendar() {
        let app = XCUIApplication.pudding(seed: "rich")
        app.acceptDisclaimer()

        app.openTab("Аллергены")
        app.staticTexts["Пора освежить"].assertExists(timeout: 8)
        app.buttons["Дал"].firstMatch.waitTap()
        app.allowNotificationsIfAsked()
        app.staticTexts["В норме"].firstMatch.assertExists(timeout: 6)

        // Лента календаря: появилась сегодняшняя запись желтка.
        app.openTab("Календарь")
        app.staticTexts["Яичный желток"].firstMatch.assertExists(timeout: 6,
            "запись «Дал» не попала в ленту календаря")
    }

    // R6: «Пометить аллергию» → бейдж «Аллергия» на табе Аллергены, «Дал» исчез.
    func testR6_MarkAllergyPropagatesToAllergens() {
        let app = XCUIApplication.pudding(seed: "rich")
        app.acceptDisclaimer()

        app.openFoodCard("желток", rowTitle: "Яичный желток")
        app.buttons["food.more"].waitTap()
        app.buttons["Пометить аллергию"].waitTap()
        app.alerts.buttons["Пометить аллергию"].waitTap()
        app.staticTexts["Аллергия"].assertExists(timeout: 6)

        app.openTab("Аллергены")
        app.staticTexts["Аллергия"].firstMatch.assertExists(timeout: 6,
            "бейдж «Аллергия» не появился на табе аллергенов")
        XCTAssertFalse(app.buttons["Дал"].waitForExistence(timeout: 2),
                       "«Дал» должен исчезнуть: единственный due-аллерген помечен аллергией")
    }

    // R7: план → «ПЛАНЫ» в ленте → «Выполнено» → запись в дневнике главной.
    func testR7_PlanConfirmPropagatesToDashboard() {
        let app = XCUIApplication.pudding(seed: "child")
        app.acceptDisclaimer()

        app.openTab("Календарь")
        app.buttons["Запланировать ввод"].waitTap()
        let search = app.searchFields["Поиск продукта"]
        search.waitTap(); search.typeText("манго")
        app.row(containing: "Манго").waitTap()

        // Лента: план появился (на сегодня → в прошло-сегодняшней группе с «Выполнено»).
        app.staticTexts["Манго"].firstMatch.assertExists(timeout: 6, "план не попал в ленту")
        app.buttons["Выполнено"].firstMatch.waitTap()
        app.allowNotificationsIfAsked()

        // Главная: подтверждённый план стал записью дневника.
        app.openTab("Сегодня")
        app.staticTexts["Дневник за сегодня"].assertExists(timeout: 6)
        app.staticTexts["Манго"].firstMatch.assertExists(timeout: 6,
            "подтверждённый план не появился в дневнике главной")
    }

    // R8: снять группу аллергенов в плане → строка ушла с таба Аллергены (и обратно).
    func testR8_PlanGroupsPropagateToAllergensTab() {
        let app = XCUIApplication.pudding(seed: "child")
        app.acceptDisclaimer()

        app.openTab("Аллергены")
        app.staticTexts["Кунжут"].firstMatch.assertExists(timeout: 8)

        app.openTab("Профиль")
        app.staticTexts["Твой план"].firstMatch.waitTap()
        app.buttons["Кунжут"].firstMatch.waitTap(timeout: 6)   // снять группу
        app.navigationBars.buttons.firstMatch.tap()            // назад

        app.openTab("Аллергены")
        XCTAssertFalse(app.staticTexts["Кунжут"].waitForExistence(timeout: 3),
                       "снятая группа не ушла с таба Аллергены")

        // Вернуть обратно — строка снова появляется.
        app.openTab("Профиль")
        app.staticTexts["Твой план"].firstMatch.waitTap()
        app.buttons["Кунжут"].firstMatch.waitTap(timeout: 6)
        app.navigationBars.buttons.firstMatch.tap()
        app.openTab("Аллергены")
        app.staticTexts["Кунжут"].firstMatch.assertExists(timeout: 5,
            "возвращённая группа не появилась на табе Аллергены")
    }

    // R9: удалить запись в календаре → hero-счётчик главной уменьшился.
    func testR9_DeleteLogPropagatesToHeroCounter() {
        let app = XCUIApplication.pudding(seed: "rich")
        app.acceptDisclaimer()

        // До: 2 записи за сегодня (брокколи + intro кабачка).
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'записей: 2'"))
            .firstMatch.assertExists(timeout: 8, "нет стартового счётчика 2")

        // Мутация: удалить сегодняшнюю запись брокколи из ленты календаря.
        app.openTab("Календарь")
        app.staticTexts["Брокколи"].firstMatch.press(forDuration: 1.2)
        app.buttons["Удалить"].waitTap()
        app.alerts.buttons["Удалить"].waitTap()

        // Главная: счётчик пересчитался.
        app.openTab("Сегодня")
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'записей: 1'"))
            .firstMatch.assertExists(timeout: 6,
            "hero-счётчик не отреагировал на удаление записи")
    }
}
