import XCTest

/// Съёмка сырых скриншотов для App Store (docs/appstore + скилл appstore-screenshots).
/// Запускается ТОЛЬКО с env `SNAPSHOT=1` (TEST_RUNNER_SNAPSHOT=1 в xcodebuild) на
/// симуляторе iPhone Pro Max (6.9", 1320×2868) — в обычных прогонах скипается.
/// Навигация — по ИНДЕКСАМ вкладок и `screenshot.*` идентификаторам, чтобы не
/// зависеть от локализованных подписей: один сценарий снимает все 14 языков.
/// Скрины уходят в attachments (.keepAlways) → выгружаются из xcresult.
final class ScreenshotUITests: XCTestCase {

    /// UI-язык → (-AppleLanguages код, -AppleLocale). Код каталога = ASC-локаль маппится в generate.py.
    private static let langs: [(ui: String, locale: String)] = [
        ("ru", "ru_RU"), ("en", "en_US"), ("de", "de_DE"), ("fr", "fr_FR"),
        ("es", "es_ES"), ("it", "it_IT"), ("pt-BR", "pt_BR"), ("pl", "pl_PL"),
        ("tr", "tr_TR"), ("uk", "uk_UA"), ("nl", "nl_NL"), ("ja", "ja_JP"),
        ("ko", "ko_KR"), ("zh-Hans", "zh_Hans_CN"),
    ]

    override func setUpWithError() throws {
        // Съёмка многоязычная — сбой одного языка НЕ должен ронять остальные.
        continueAfterFailure = true
        try XCTSkipUnless(ProcessInfo.processInfo.environment["SNAPSHOT"] == "1",
                          "скриншот-режим: запускать с TEST_RUNNER_SNAPSHOT=1")
    }

    /// Один тест снимает все языки последовательно (перезапуская приложение).
    func testCaptureAllLanguages() {
        for lang in Self.langs { capture(lang: lang.ui, locale: lang.locale) }
    }

    // Индексы вкладок (порядок фиксирован в MainTabView): 0 сегодня, 1 каталог,
    // 2 календарь, 3 аллергены, 4 профиль. Язык-независимо.
    private enum Tab: Int { case today = 0, catalog = 1, calendar = 2, allergens = 3, profile = 4 }

    private func capture(lang: String, locale: String) {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-uitest-seed=showcase",
                               "-AppleLanguages", "(\(lang))",
                               "-AppleLocale", locale]
        app.launch()

        // Гейт дисклеймера — точные подписи «Понятно» из каталога (14 языков).
        for label in ["Понятно", "Got it", "Alles klar", "Compris", "Entendido",
                      "Ho capito", "Entendi", "Rozumiem", "Anladım", "Зрозуміло",
                      "Begrepen", "わかりました", "알겠어요", "明白了"] {
            let b = app.buttons[label]
            if b.waitForExistence(timeout: 2) { b.tap(); break }
        }
        // Системный промпт уведомлений — погасить (сначала по подписи, иначе — последняя
        // кнопка алерта спрингборда, т.к. «Allow» локализуется системой непредсказуемо).
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        var dismissed = false
        for label in ["Allow", "Разрешить", "Erlauben", "Autoriser", "Permitir",
                      "Consenti", "Zezwól", "İzin ver", "Дозволити", "Sta toe",
                      "許可", "허용", "允许"] {
            let b = springboard.buttons[label]
            if b.waitForExistence(timeout: 1) { b.tap(); dismissed = true; break }
        }
        if !dismissed {
            let alert = springboard.alerts.firstMatch
            if alert.waitForExistence(timeout: 2) {
                alert.buttons.element(boundBy: alert.buttons.count - 1).tap()
            }
        }

        // 01 — Главная (ждём имя ребёнка «Ника» — оно из сида, не локализуется).
        XCTAssertTrue(app.staticTexts["Ника"].waitForExistence(timeout: 8),
                      "\(lang): главная не загрузилась")
        sleep(2)   // cozy-анимации карточек должны доиграть
        shoot("01_Dashboard", lang)

        // 02 — Карточка продукта «вводится» (кольцо «день 2 из 3»).
        // Координатный тап — не бросает на hittable-проверке кастомной кнопки.
        let introRow = app.buttons["screenshot.introducing"]
        if introRow.waitForExistence(timeout: 5) {
            introRow.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            sleep(1)   // дать кольцу дорисоваться
            shoot("02_FoodCard", lang)
            popBack(app)   // назад на главную (edge-swipe, язык-независимо)
        }

        // 03 — Календарь-лента.
        app.tabBars.buttons.element(boundBy: Tab.calendar.rawValue).tap()
        sleep(1)
        shoot("03_Calendar", lang)

        // 04 — Аллергены.
        app.tabBars.buttons.element(boundBy: Tab.allergens.rawValue).tap()
        sleep(1)
        shoot("04_Allergens", lang)

        // 05 — Рекап месяца (кнопка-«sparkles» в тулбаре календаря).
        app.tabBars.buttons.element(boundBy: Tab.calendar.rawValue).tap()
        let recap = app.buttons["screenshot.recap"]
        if recap.waitForExistence(timeout: 4), recap.isEnabled {
            recap.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            _ = app.buttons.firstMatch.waitForExistence(timeout: 4)
            sleep(1)
            shoot("05_Recap", lang)
        }

        app.terminate()
    }

    /// Возврат с pushed-экрана: свайп от левого края (interactive pop) — не зависит
    /// от локализованной кнопки «назад» и не бросает, если экран уже корневой.
    private func popBack(_ app: XCUIApplication) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.5))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end)
        sleep(1)
    }

    private func shoot(_ name: String, _ lang: String) {
        let shot = XCUIScreen.main.screenshot()
        let att = XCTAttachment(screenshot: shot)
        att.name = "\(name)__\(lang)"
        att.lifetime = .keepAlways
        add(att)
    }
}
