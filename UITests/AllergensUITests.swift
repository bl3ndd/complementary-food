import XCTest

/// E-ALG-01…05: аллергены — сводка, «Дал» на просроченном, тап строки → карточка,
/// бейдж на табе.
final class AllergensUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    func testGiveOverdueAllergenAndRowNavigation() {
        let app = XCUIApplication.pudding(seed: "rich")
        app.acceptDisclaimer()

        // E-ALG-05: бейдж таба не экспортируется в a11y на устройстве (value пустой) —
        // проверяем сам due-флоу ниже («Пора освежить» + «Дал»), бейдж — ручной кейс.
        app.tabBars.buttons["Аллергены"].assertExists(timeout: 8)

        app.openTab("Аллергены")
        // E-ALG-01: сводка «пора освежить».
        app.staticTexts["Пора освежить"].assertExists(timeout: 6)

        // E-ALG-02: «Дал» на группе «Яйцо» → статус «В норме».
        app.buttons["Дал"].firstMatch.waitTap()
        app.allowNotificationsIfAsked()
        app.staticTexts["В норме"].firstMatch.assertExists(timeout: 6,
            "после «Дал» группа не перешла в «В норме»")

        // E-ALG-03: тап строки → карточка продукта-представителя.
        app.staticTexts["Яйцо"].firstMatch.waitTap()
        app.navigationBars["Яичный желток"].assertExists(timeout: 6,
            "строка группы не открыла карточку продукта")
    }
}
