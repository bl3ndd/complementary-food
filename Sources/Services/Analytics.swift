import Foundation
import TelemetryDeck

/// Анонимный счёт использования функций (TelemetryDeck): какие экраны открывают и
/// какие кнопки жмут. Каждое событие — короткое имя и максимум флаг-параметр
/// (`"mode": "reaction"`, `"photo": "true"`). Ничего из самого дневника — названий
/// продуктов, реакций, заметок, имени и возраста ребёнка, фото — сюда не попадает
/// и попадать не должно: это данные о здоровье ребёнка.
///
/// Молчит, пока человек выключил «Анонимную статистику» в Профиле, в UI-тестах,
/// юнит-тестах и демо, и пока не заполнен `appID`. DEBUG-сборки SDK сам помечает
/// как тестовые сигналы — в боевую статистику они не попадают.
enum Analytics {
    /// TelemetryDeck App ID. Публичный UUID, не секрет.
    static let appID = "05697887-C9AE-4BA6-AED3-87E3AAFFAF41"
    /// У организации есть namespace: сигналы без него до дашборда не доходят.
    static let namespace = "com.whitteam"
    static let enabledKey = "analytics.enabled"

    enum Event: String {
        case onboardingCompleted = "onboarding.completed"
        case tabOpened = "tab.opened"
        case feedingLogged = "feeding.logged"
        case logEdited = "log.edited"
        case logDeleted = "log.deleted"
        case allergenGiven = "allergen.given"
        case customFoodAdded = "customFood.added"
        case pdfExported = "pdf.exported"
        case recapOpened = "recap.opened"
        case recapShared = "recap.shared"
        case proOpened = "pro.opened"
        case proPurchased = "pro.purchased"
        case proRestored = "pro.restored"
        case paletteChanged = "palette.changed"
        case iconChanged = "icon.changed"
        case childAdded = "child.added"
        case settingChanged = "setting.changed"
    }

    /// Куда уходят события. Тесты подменяют на запись в массив.
    static var sink: (String, [String: String]) -> Void = { name, params in
        TelemetryDeck.signal(name, parameters: params)
    }

    private(set) static var isEnabled = true
    private static var config: TelemetryDeck.Config?

    /// Тестовые и демо-прогоны не шлют ничего — ни наши события, ни сессии SDK.
    /// Переменная, а не вычисляемое: юнит-тест шлагбаума снимает её на время проверки.
    static var isSilentRun = UITestSupport.isActive
        || CommandLine.arguments.contains("-demo")
        || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    /// Ключа нет на свежей установке — читаем как «не выключено».
    static func readEnabled(from defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: enabledKey) == nil ? true : defaults.bool(forKey: enabledKey)
    }

    /// Один раз при запуске, до первого экрана.
    static func configure(enabled: Bool) {
        isEnabled = enabled
        guard !appID.isEmpty, !isSilentRun else { return }
        let config = TelemetryDeck.Config(appID: appID, namespace: namespace)
        config.analyticsDisabled = !enabled
        self.config = config
        TelemetryDeck.initialize(config: config)
    }

    /// Переключает и наш шлагбаум, и выключатель SDK — чтобы замолчал и его
    /// автоматический сигнал сессии.
    static func setEnabled(_ on: Bool) {
        isEnabled = on
        config?.analyticsDisabled = !on
    }

    static func track(_ event: Event, _ params: [String: String] = [:]) {
        guard isEnabled, !isSilentRun else { return }
        sink(event.rawValue, params)
    }
}
