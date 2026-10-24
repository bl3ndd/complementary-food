import XCTest
@testable import Prikorm

/// Шлагбаум анонимной статистики: что и когда уходит в TelemetryDeck.
/// Сеть и SDK не участвуют — `Analytics.sink` подменён записью в массив.
final class AnalyticsTests: XCTestCase {
    private var sent: [(String, [String: String])] = []
    private var savedSink: ((String, [String: String]) -> Void)!
    private var savedSilent = false
    private var savedEnabled = true

    override func setUp() {
        super.setUp()
        savedSink = Analytics.sink
        savedSilent = Analytics.isSilentRun
        savedEnabled = Analytics.isEnabled
        sent = []
        Analytics.sink = { [unowned self] name, params in sent.append((name, params)) }
        Analytics.isSilentRun = false
        Analytics.setEnabled(true)
    }

    override func tearDown() {
        Analytics.sink = savedSink
        Analytics.isSilentRun = savedSilent
        Analytics.setEnabled(savedEnabled)
        super.tearDown()
    }

    func testTrackSendsEventNameAndParams() {
        Analytics.track(.feedingLogged, ["mode": "feeding"])
        XCTAssertEqual(sent.map(\.0), ["feeding.logged"])
        XCTAssertEqual(sent.first?.1, ["mode": "feeding"])
    }

    func testOptOutSendsNothing() {
        Analytics.setEnabled(false)
        Analytics.track(.tabOpened, ["tab": "today"])
        XCTAssertTrue(sent.isEmpty)
        Analytics.setEnabled(true)
        Analytics.track(.tabOpened, ["tab": "today"])
        XCTAssertEqual(sent.count, 1)
    }

    func testSilentRunSendsNothing() {
        Analytics.isSilentRun = true
        Analytics.track(.proOpened)
        XCTAssertTrue(sent.isEmpty)
    }

    /// Тесты гоняются под тест-хостом — сам прогон обязан распознаваться как «тихий»,
    /// иначе каждый CI-прогон слал бы сигналы в боевую статистику.
    func testHostedTestRunIsSilentByDefault() {
        XCTAssertTrue(savedSilent)
    }

    func testEnabledByDefaultOnFreshInstall() {
        let defaults = UserDefaults(suiteName: "analytics-tests-\(UUID().uuidString)")!
        XCTAssertTrue(Analytics.readEnabled(from: defaults))
        defaults.set(false, forKey: Analytics.enabledKey)
        XCTAssertFalse(Analytics.readEnabled(from: defaults))
    }

    /// Имена событий — короткие латинские ключи; ни одно не несёт содержимого дневника.
    func testEventNamesAreStableKeys() {
        let names: [Analytics.Event] = [.onboardingCompleted, .tabOpened, .feedingLogged, .logEdited,
                                        .logDeleted, .allergenGiven, .customFoodAdded, .pdfExported,
                                        .recapOpened, .recapShared, .proOpened, .proPurchased,
                                        .proRestored, .paletteChanged, .iconChanged, .childAdded,
                                        .settingChanged]
        for e in names {
            XCTAssertNotNil(e.rawValue.range(of: #"^[a-zA-Z]+\.[a-zA-Z]+$"#, options: .regularExpression), e.rawValue)
        }
        XCTAssertEqual(Set(names.map(\.rawValue)).count, names.count)
    }
}
