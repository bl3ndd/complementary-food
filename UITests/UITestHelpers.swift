import XCTest

/// Общие хелперы E2E (карта кейсов — docs/E2E-CASES.md).
/// Запуск всегда с `-uitest`: in-memory стор (данные устройства не трогаем), RU-язык.
extension XCUIApplication {
    static func pudding(seed: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-AppleLanguages", "(ru)", "-AppleLocale", "ru_RU",
                               // Настройки берутся из UserDefaults ТЕЛЕФОНА — изолируем:
                               // платная гамма владельца при подтверждении Pro меняла
                               // `.id` корня и сбрасывала навигацию посреди теста.
                               "-app.palette", "pudding", "-app.activeChild", "",
                               // Детерминированно бесплатный: sandbox-покупка на
                               // телефоне не должна менять, что видит тест.
                               "-debug.simulateNewUser", "YES"]
        if let seed { app.launchArguments.append("-uitest-seed=\(seed)") }
        app.launch()
        return app
    }

    /// Гейт «Прежде чем начать» показывается на каждом чистом старте — принять.
    /// Сразу после него апп просит разрешение на уведомления — гасим и его.
    func acceptDisclaimer(timeout: TimeInterval = 6) {
        let ok = buttons["Понятно"]
        if ok.waitForExistence(timeout: timeout) { ok.tap() }
        allowNotificationsIfAsked()
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
        // Поднятая клавиатура (поиск каталога) накрывает таббар — тап по вкладке
        // уходит в её нижнюю полосу. Enter гасит фокус без onSubmit-эффектов.
        if keyboards.firstMatch.exists { typeText("\n") }
        let tab = tabBars.buttons[name]
        tab.tap()
        // Страховка: если тап съела уезжающая клавиатура — повторить.
        if !tab.isSelected {
            _ = keyboards.firstMatch.waitForNonExistence(timeout: 2)
            if !tab.isSelected { tab.tap() }
        }
    }

    /// Открыть карточку продукта через поиск в Каталоге.
    /// Строка — NavigationLink: её label склеен («Брокколи, Введён»), ищем по CONTAINS.
    func openFoodCard(_ query: String, rowTitle: String) {
        openTab("Каталог")
        let search = textFields["Поиск продукта"]
        XCTAssertTrue(search.waitForExistence(timeout: 5), "нет поиска в каталоге")
        search.tap()
        // Флейк: тап не всегда успевает дать фокус — без клавиатуры typeText падает.
        if !keyboards.firstMatch.waitForExistence(timeout: 2) { search.tap() }
        search.typeText(query)
        row(containing: rowTitle).waitTap()
        XCTAssertTrue(navigationBars[rowTitle].waitForExistence(timeout: 5),
                      "не открылась карточка «\(rowTitle)»")
    }

    /// Элемент с ТОЧНЫМ label любого типа. Строки ленты, истории и аллергенов —
    /// кнопки (тап открывает запись), а не staticText: ищем по подписи, не по типу.
    func item(_ label: String) -> XCUIElement {
        descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    /// Кнопка/строка, чей label СОДЕРЖИТ подстроку (для склеенных лейблов списков).
    func row(containing text: String) -> XCUIElement {
        buttons.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    /// Листать вниз, пока элемент не появится на экране. Form ленивая: строк ниже
    /// сгиба нет в иерархии, а фиксированное число свайпов ломается от каждой новой секции.
    func scrollTo(_ element: XCUIElement, maxSwipes: Int = 8,
                  file: StaticString = #filePath, line: UInt = #line) {
        // Только `exists`: подпись внутри строки формы сама по себе не hittable,
        // и ожидание hittable проматывало мимо нужной строки.
        for _ in 0..<maxSwipes where !element.exists { swipeUp() }
        XCTAssertTrue(element.exists, "Не доскроллили до: \(element)", file: file, line: line)
    }

    /// Счётчик коллекции: цифры на экране нет, она живёт в accessibilityValue
    /// шкалы («1 продукт введён» — плюральная форма, поэтому сверяем начало).
    func assertCollection(_ count: Int, timeout: TimeInterval = 6, _ message: String = "",
                          file: StaticString = #filePath, line: UInt = #line) {
        progressIndicators.matching(NSPredicate(
            format: "identifier == 'collection.progress' AND value BEGINSWITH %@", "\(count) "))
            .firstMatch.assertExists(timeout: timeout, message, file: file, line: line)
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

    /// Дождаться исчезновения (закрытие шита/алерта) — иначе следующий тап
    /// глотается анимацией dismiss.
    func waitGone(timeout: TimeInterval = 6,
                  file: StaticString = #filePath, line: UInt = #line) {
        let gone = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: self)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: timeout), .completed,
                       "Элемент не исчез: \(self)", file: file, line: line)
    }
}
