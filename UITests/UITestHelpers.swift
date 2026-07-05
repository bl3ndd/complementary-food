import XCTest

/// Общие хелперы E2E (карта кейсов — docs/E2E-CASES.md).
/// Запуск всегда с `-uitest`: in-memory стор (данные устройства не трогаем), RU-язык.
extension XCUIApplication {
    static func pudding(seed: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-AppleLanguages", "(ru)", "-AppleLocale", "ru_RU"]
        if let seed { app.launchArguments.append("-uitest-seed=\(seed)") }
        app.launch()
        return app
    }

    /// Гейт «Прежде чем начать» показывается на каждом чистом старте — принять.
    func acceptDisclaimer(timeout: TimeInterval = 6) {
        let ok = buttons["Понятно"]
        if ok.waitForExistence(timeout: timeout) { ok.tap() }
    }

    /// Системный промпт уведомлений (после первого планирования напоминаний).
    func allowNotificationsIfAsked() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for label in ["Разрешить", "Allow"] {
            let button = springboard.buttons[label]
            if button.waitForExistence(timeout: 2) { button.tap(); return }
        }
    }

    func openTab(_ name: String) {
        tabBars.buttons[name].tap()
    }

    /// Открыть карточку продукта через поиск в Каталоге.
    func openFoodCard(_ query: String, rowTitle: String) {
        openTab("Каталог")
        let search = textFields["Поиск продукта"]
        XCTAssertTrue(search.waitForExistence(timeout: 5), "нет поиска в каталоге")
        search.tap()
        search.typeText(query)
        buttons[rowTitle].firstMatch.waitTap()
        XCTAssertTrue(navigationBars[rowTitle].waitForExistence(timeout: 5),
                      "не открылась карточка «\(rowTitle)»")
    }
}

extension XCUIElement {
    /// Дождаться и тапнуть; фейлит тест, если элемент не появился.
    @discardableResult
    func waitTap(timeout: TimeInterval = 6,
                 file: StaticString = #filePath, line: UInt = #line) -> Bool {
        guard waitForExistence(timeout: timeout) else {
            XCTFail("Не дождались элемента: \(self)", file: file, line: line)
            return false
        }
        tap()
        return true
    }

    func assertExists(timeout: TimeInterval = 6, _ message: String = "",
                      file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(waitForExistence(timeout: timeout),
                      message.isEmpty ? "Не найден: \(self)" : message,
                      file: file, line: line)
    }
}
