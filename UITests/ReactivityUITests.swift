import XCTest

/// Реактивность между экранами (docs/REACTIVITY.md): мутация на одном экране
/// обязана БЕЗ перезапуска обновить все зависимые. Каждый тест — одна сессия,
/// переключение табов, ассерты «до/после».
final class ReactivityUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    // R1: кормление с плитки → дневник главной + лента календаря; рекап без Pro → пейвол.
    func testR1_FeedingPropagatesToDiaryCalendarAndGates() {
        let app = XCUIApplication.pudding(seed: "child")
        app.acceptDisclaimer()

        // Мутация: записать кормление банана с плитки главной.
        app.openTab("Сегодня")
        app.buttons["Записать"].firstMatch.waitTap()
        let search = app.searchFields["Поиск продукта"]
        search.waitTap(); search.typeText("банан")
        app.row(containing: "Банан").waitTap()
        app.buttons["Сохранить"].waitTap()
        app.allowNotificationsIfAsked()

        // Дневник главной обновился.
        app.item("Банан").assertExists(timeout: 6, "дневник главной не обновился")
        // Лента календаря обновилась.
        app.openTab("Календарь")
        app.item("Банан").firstMatch.assertExists(timeout: 6, "лента календаря не обновилась")
        // Рекап на главной: UI-тесты идут без Pro — кнопка ведёт на пейвол.
        app.openTab("Сегодня")
        app.buttons["dashboard.recap"].waitTap(timeout: 8)
        app.navigationBars["Pudding Pro"].assertExists(timeout: 6, "без Pro рекап обязан вести на пейвол")
        app.navigationBars["Pudding Pro"].buttons["Готово"].tap()
    }

    // R2: свой продукт живёт в каталоге без перезапуска (⚠️ статик-каталог). Создаётся
    // НЕ введённым (аудит п.5), поэтому коллекцию он не двигает — и это тоже проверяем.
    func testR2_CustomFoodAppearsInCatalogNotInCollection() {
        let app = XCUIApplication.pudding(seed: "child")
        app.acceptDisclaimer()
        app.assertCollection(0, timeout: 8, "нет стартового счётчика коллекции 0")

        // Мутация: добавить свой продукт.
        app.openTab("Каталог")
        app.buttons["Добавить свой продукт"].waitTap()
        let name = app.textFields["Например: компот"]
        name.waitTap(); name.typeText("Тестик\n")
        app.buttons["Добавить"].waitTap()

        // После создания открывается карточка нового продукта — и он «Не введён».
        app.navigationBars["Тестик"].assertExists(timeout: 6, "не открылась карточка своего продукта")
        app.item("Не введён").firstMatch.assertExists(timeout: 4, "свой продукт создаётся НЕ введённым")
        app.navigationBars["Тестик"].buttons.firstMatch.tap()   // назад в каталог

        // Главная: созданный продукт не считается введённым.
        app.openTab("Сегодня")
        app.assertCollection(0, timeout: 6, "свой продукт не должен сразу попадать в коллекцию")

        // Мутация: удалить свой продукт — из каталога он уходит.
        app.openTab("Каталог")
        let search = app.textFields["Поиск продукта"]
        search.waitTap(); search.typeText("тестик")
        app.row(containing: "Тестик").swipeLeft()
        app.buttons["Удалить"].waitTap()
        app.alerts.buttons["Удалить"].waitTap()
        XCTAssertFalse(app.row(containing: "Тестик").waitForExistence(timeout: 3),
                       "удалённый свой продукт остался в каталоге")
    }

    // R3: старт ввода → «Сейчас вводишь» + дневник + бейдж в каталоге.
    func testR3_StartIntroductionPropagates() {
        let app = XCUIApplication.pudding(seed: "child")
        app.acceptDisclaimer()

        XCTAssertFalse(app.item("Сейчас вводишь").exists)

        app.openFoodCard("брокк", rowTitle: "Брокколи")
        app.buttons["Начать введение"].waitTap()
        app.allowNotificationsIfAsked()
        app.item("Вводится").assertExists(timeout: 6)
        app.navigationBars.buttons.firstMatch.tap()   // назад в каталог

        // Каталог: бейдж «Вводится» в строке.
        app.buttons.matching(NSPredicate(
            format: "label CONTAINS 'Брокколи' AND label CONTAINS 'Вводится'"))
            .firstMatch.assertExists(timeout: 5, "бейдж каталога не обновился")

        // Главная: карточка «Сейчас вводишь» + intro-запись в дневнике.
        app.openTab("Сегодня")
        app.item("Сейчас вводишь").assertExists(timeout: 6,
            "«Сейчас вводишь» не появилось после старта")
        app.item("Дневник за сегодня").assertExists(timeout: 4)
        app.item("Брокколи").firstMatch.assertExists(timeout: 4,
            "intro-запись не попала в дневник")
    }

    // R4: окно прошло → продукт закрывается САМ (ручной кнопки нет) и это
    // разъезжается по экранам: «Сейчас вводишь» пусто, коллекция +1, бейдж «Введён».
    func testR4_CompleteIntroductionPropagates() {
        let app = XCUIApplication.pudding(seed: "window-done")
        app.acceptDisclaimer()

        XCTAssertFalse(app.item("Сейчас вводишь").waitForExistence(timeout: 3),
                       "продукт с прошедшим окном не должен оставаться «в процессе»")
        app.assertCollection(1, timeout: 8, "коллекция не выросла после автозавершения")

        app.openTab("Каталог")
        app.buttons.matching(NSPredicate(
            format: "label CONTAINS 'Брокколи' AND label CONTAINS 'Введён'"))
            .firstMatch.assertExists(timeout: 6, "бейдж «Введён» не обновился в каталоге")
    }

    // R5: «Дал» аллерген → строка «В норме» + запись в ленте календаря.
    func testR5_GiveAllergenPropagatesToCalendar() {
        let app = XCUIApplication.pudding(seed: "rich")
        app.acceptDisclaimer()

        app.openTab("Аллергены")
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'срок по плану'"))
            .firstMatch.assertExists(timeout: 8)
        app.buttons["Дали"].firstMatch.waitTap()
        app.allowNotificationsIfAsked()
        app.item("В норме").firstMatch.assertExists(timeout: 6)

        // Лента календаря: появилась сегодняшняя запись желтка.
        app.openTab("Календарь")
        app.item("Яичный желток").firstMatch.assertExists(timeout: 6,
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
        app.item("Аллергия").assertExists(timeout: 6)

        app.openTab("Аллергены")
        app.item("Аллергия").firstMatch.assertExists(timeout: 6,
            "бейдж «Аллергия» не появился на табе аллергенов")
        XCTAssertFalse(app.buttons["Дали"].waitForExistence(timeout: 2),
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
        app.buttons["Готово"].waitTap()   // мультивыбор: подтверждаем выбранное

        // Лента: план появился (на сегодня → в прошло-сегодняшней группе с «Выполнено»).
        app.item("Манго").firstMatch.assertExists(timeout: 6, "план не попал в ленту")
        app.buttons["Выполнено"].firstMatch.waitTap()
        app.allowNotificationsIfAsked()

        // Главная: подтверждённый план стал записью дневника.
        app.openTab("Сегодня")
        app.item("Дневник за сегодня").assertExists(timeout: 6)
        app.item("Манго").firstMatch.assertExists(timeout: 6,
            "подтверждённый план не появился в дневнике главной")
    }

    // R8: снять группу аллергенов в плане → строка ушла с таба Аллергены (и обратно).
    func testR8_PlanGroupsPropagateToAllergensTab() {
        let app = XCUIApplication.pudding(seed: "child")
        app.acceptDisclaimer()

        app.openTab("Аллергены")
        app.item("Кунжут").firstMatch.assertExists(timeout: 8)

        app.openTab("Профиль")
        app.item("Твой план").firstMatch.waitTap()
        app.buttons["Кунжут"].firstMatch.waitTap(timeout: 6)   // снять группу
        app.navigationBars.buttons.firstMatch.tap()            // назад

        app.openTab("Аллергены")
        XCTAssertFalse(app.item("Кунжут").waitForExistence(timeout: 3),
                       "снятая группа не ушла с таба Аллергены")

        // Вернуть обратно — строка снова появляется.
        app.openTab("Профиль")
        app.item("Твой план").firstMatch.waitTap()
        app.buttons["Кунжут"].firstMatch.waitTap(timeout: 6)
        app.navigationBars.buttons.firstMatch.tap()
        app.openTab("Аллергены")
        app.item("Кунжут").firstMatch.assertExists(timeout: 5,
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
        app.item("Брокколи").firstMatch.press(forDuration: 1.2)
        app.buttons["Удалить"].waitTap()
        app.alerts.buttons["Удалить"].waitTap()

        // Главная: счётчик пересчитался.
        app.openTab("Сегодня")
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'записей: 1'"))
            .firstMatch.assertExists(timeout: 6,
            "hero-счётчик не отреагировал на удаление записи")
    }
}
