import XCTest

/// Обход всех экранов со скриншотами — для ручного UX-аудита, не для ассертов.
/// Запускается ТОЛЬКО с env `AUDIT=1` (TEST_RUNNER_AUDIT=1), в обычных прогонах
/// скипается. Ничего не проверяет: каждый шаг «если элемент есть — тапнуть и снять».
final class AuditWalkUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = true
        try XCTSkipUnless(ProcessInfo.processInfo.environment["AUDIT"] == "1")
    }

    private func launch(seed: String?, pro: Bool, dark: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        var args = ["-uitest", "-AppleLanguages", "(ru)", "-AppleLocale", "ru_RU",
                    "-app.palette", "pudding", "-app.activeChild", "",
                    "-debug.simulateNewUser", "YES",
                    "-app.theme", dark ? "dark" : "light"]
        if pro { args.append("-uitest-pro") }
        if let seed { args.append("-uitest-seed=\(seed)") }
        app.launchArguments = args
        app.launch()
        return app
    }

    private func shoot(_ name: String) {
        sleep(1)
        let att = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        att.name = name; att.lifetime = .keepAlways
        add(att)
    }

    @discardableResult
    private func tap(_ el: XCUIElement, _ t: TimeInterval = 4) -> Bool {
        guard el.waitForExistence(timeout: t) else { return false }
        el.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        return true
    }

    private func dismissSheet(_ app: XCUIApplication) {
        for label in ["Готово", "Отмена", "Закрыть"] {
            let b = app.navigationBars.buttons[label].firstMatch
            if b.exists { b.tap(); sleep(1); return }
        }
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08))
        start.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)))
        sleep(1)
    }

    private func popBack(_ app: XCUIApplication) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5)))
        sleep(1)
    }

    private func tab(_ app: XCUIApplication, _ i: Int) {
        app.tabBars.buttons.element(boundBy: i).tap(); sleep(1)
    }

    func test01_Onboarding() {
        let app = launch(seed: nil, pro: false)
        shoot("A01_onb_welcome")
        if tap(app.buttons.firstMatch) { shoot("A02_onb_disclaimer") }
        if tap(app.buttons["Понятно"]) { shoot("A03a_onb_storage") }
        if tap(app.buttons["onboarding.storage.off"]), tap(app.buttons["Далее"]) { shoot("A03_onb_child") }
        let name = app.textFields["Имя малыша"]
        if tap(name) { name.typeText("Мия"); app.swipeUp(); shoot("A03b_onb_child_filled") }
        for b in ["Дальше", "Продолжить", "Далее"] where app.buttons[b].exists { app.buttons[b].tap(); break }
        shoot("A04_onb_plan")
        for b in ["Дальше", "Продолжить", "Далее"] where app.buttons[b].exists { app.buttons[b].tap(); break }
        shoot("A05_onb_already")
        app.swipeUp(); shoot("A05b_onb_already_bottom")
        app.terminate()
    }

    func test02_MainFlowsPro() {
        let app = launch(seed: "showcase", pro: true)
        app.acceptDisclaimer()
        _ = app.item("Ника").waitForExistence(timeout: 8); sleep(2)
        shoot("B01_dashboard")
        app.swipeUp(); shoot("B02_dashboard_bottom"); app.swipeDown(); app.swipeDown()

        // Быстрая запись
        if tap(app.buttons["Записать"].firstMatch) {
            shoot("B03_quicklog")
            let s = app.searchFields.firstMatch
            if tap(s) { s.typeText("бан"); shoot("B04_quicklog_search") }
            if tap(app.cells.firstMatch) { shoot("B05_logfeeding_sheet"); app.swipeUp(); shoot("B05b_logfeeding_bottom") }
            dismissSheet(app); dismissSheet(app)
        }
        // Реакция
        if tap(app.buttons["Реакция"].firstMatch) {
            shoot("B06_reaction_pick")
            if tap(app.cells.firstMatch) { shoot("B07_reaction_sheet"); app.swipeUp(); shoot("B07b_reaction_bottom") }
            dismissSheet(app); dismissSheet(app)
        }
        // Рекап
        if tap(app.buttons["dashboard.recap"]) {
            shoot("B08_recap_1"); app.swipeLeft(); shoot("B08_recap_2"); app.swipeLeft(); shoot("B08_recap_3")
            dismissSheet(app)
        }
        // Карточка вводимого продукта
        if tap(app.buttons["screenshot.introducing"]) {
            shoot("B09_food_introducing"); app.swipeUp(); shoot("B09b_food_introducing_bottom")
            if tap(app.buttons["Ещё действия"]) { shoot("B10_food_more_menu"); app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)).tap() }
            popBack(app)
        }

        // Каталог
        tab(app, 1); shoot("C01_catalog")
        app.swipeUp(); shoot("C02_catalog_scrolled"); app.swipeDown(); app.swipeDown()
        let search = app.searchFields.firstMatch
        if tap(search) { search.typeText("яб"); shoot("C03_catalog_search"); app.buttons["Отменить"].firstMatch.tap() }
        if tap(app.item("Кабачок").firstMatch) { shoot("C04_food_detail_first"); app.swipeUp(); shoot("C04b_food_detail_bottom"); popBack(app) }
        if tap(app.buttons["Добавить свой продукт"]) { shoot("C05_add_custom"); dismissSheet(app) }

        // Календарь
        tab(app, 2); shoot("D01_calendar_feed")
        if tap(app.buttons["Месяц"]) { shoot("D02_calendar_month") }
        if tap(app.buttons["Лента"]) {}
        if tap(app.item("Овсяная каша").firstMatch) { shoot("D03_day_detail"); app.swipeUp(); shoot("D03b_day_detail_bottom"); popBack(app) }
        if tap(app.buttons["Экспорт"]) { shoot("D04_export_menu"); app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap() }
        if tap(app.buttons["Запланировать ввод"].firstMatch) { shoot("D05_plan_intro"); dismissSheet(app) }
        if tap(app.buttons["screenshot.recap"]) { shoot("D06_calendar_recap_single"); dismissSheet(app) }

        // Аллергены
        tab(app, 3); shoot("E01_allergens"); app.swipeUp(); shoot("E01b_allergens_bottom")

        // Профиль
        tab(app, 4); shoot("F01_profile_top")
        if tap(app.buttons["Изменить"]) { shoot("F02_plan_editor"); app.swipeUp(); shoot("F02b_plan_editor_bottom"); popBack(app); dismissSheet(app) }
        app.swipeUp(); shoot("F03_profile_mid")
        if tap(app.buttons["Цветовая гамма"]) { shoot("F04_palette_picker"); app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)).tap() }
        if tap(app.buttons["Язык"]) { shoot("F05_language"); popBack(app) }
        app.swipeUp(); shoot("F06_profile_bottom")
        if tap(app.buttons["Сбросить все данные"]) { shoot("F07_reset_confirm"); if app.buttons["Отмена"].exists { app.buttons["Отмена"].tap() } }
        app.terminate()
    }

    func test03_FreeUser() {
        let app = launch(seed: "showcase", pro: false)
        app.acceptDisclaimer()
        _ = app.item("Ника").waitForExistence(timeout: 8); sleep(2)
        shoot("G01_dashboard_free")
        if tap(app.buttons["dashboard.recap"]) { shoot("G02_paywall"); app.swipeUp(); shoot("G02b_paywall_bottom"); dismissSheet(app) }
        tab(app, 4); shoot("G03_profile_free"); app.swipeUp(); shoot("G03b_profile_free_mid")
        if tap(app.buttons["Добавить ребёнка"]) { shoot("G04_addchild_free"); dismissSheet(app) }
        app.terminate()
    }

    func test04_EmptyAndDark() {
        var app = launch(seed: "child", pro: true)
        app.acceptDisclaimer()
        sleep(2); shoot("H01_dashboard_empty")
        tab(app, 2); shoot("H02_calendar_empty")
        tab(app, 3); shoot("H03_allergens_empty")
        if tap(app.buttons["dashboard.recap"]) { shoot("H04_recap_empty"); for b in ["Понятно", "OK"] where app.buttons[b].exists { app.buttons[b].tap() } }
        app.terminate()

        app = launch(seed: "showcase", pro: true, dark: true)
        app.acceptDisclaimer()
        _ = app.item("Ника").waitForExistence(timeout: 8); sleep(2)
        shoot("I01_dark_dashboard")
        tab(app, 1); shoot("I02_dark_catalog")
        if tap(app.item("Кабачок").firstMatch) { shoot("I03_dark_food"); popBack(app) }
        tab(app, 2); shoot("I04_dark_calendar")
        tab(app, 3); shoot("I05_dark_allergens")
        tab(app, 4); shoot("I06_dark_profile")
        app.terminate()
    }
}
