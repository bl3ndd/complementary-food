import SwiftUI
import SwiftData
import WidgetKit

struct MainTabView: View {
    let child: Child
    /// Право на Pro — от корня: виджеты без него получают заглушку.
    var isPro = false
    @Environment(\.modelContext) private var context
    @Query private var statuses: [IntroductionStatus]
    /// Тот же хвост журнала, что и у дашборда, а не весь дневник: бейдж таба иначе
    /// пересчитывает поддержку аллергенов по тысячам записей на каждое изменение
    /// стора — и утаскивает в пересчёт весь шелл табов вместе со вкладками.
    @Query private var logs: [FoodLog]
    @ObservedObject private var router = AppRouter.shared
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.displayScale) private var displayScale

    init(child: Child, isPro: Bool = false) {
        self.child = child
        self.isPro = isPro
        // Выровнено по началу дня — предикат обязан быть стабильным между проходами
        // body, иначе @Query перевыбирает журнал на ровном месте.
        let cal = Calendar.current
        let cutoff = cal.date(byAdding: .day, value: -DashboardView.recentWindowDays,
                              to: cal.startOfDay(for: Date())) ?? .distantPast
        let cid = child.id
        _statuses = Query(FetchDescriptor<IntroductionStatus>(
            predicate: #Predicate { $0.childId == cid }))
        _logs = Query(FetchDescriptor<FoodLog>(
            predicate: #Predicate { $0.date >= cutoff && $0.childId == cid }))
    }

    enum Tab { case today, catalog, calendar, allergens, profile }

    /// Сколько аллергенов «пора освежить» — для бейджа на табе.
    private var dueCount: Int {
        AllergenMaintenance(catalog: .shared, profile: child.feedingProfile,
                            statuses: statuses, logs: logs).dueForDashboard().count
    }

    var body: some View {
        tabs
            .task {
                // Подмешиваем свои продукты в каталог (для истории/календаря).
                let customs = (try? context.fetch(FetchDescriptor<CustomFood>())) ?? []
                FoodCatalog.setCustom(customs)
                // Иконки продуктов декодим заранее и в фоне: иначе первый скролл
                // главной/каталога разжимает PNG прямо в кадре и заметно дёргается.
                IconCache.shared.prewarm(
                    FoodCatalog.shared.all.map { FoodIcon.assetCandidates(for: $0) },
                    px: 46 * displayScale)
                // Разрешение на уведомления просим сразу после онбординга:
                // ensureAuthorized промптит только в notDetermined, т.е. один раз.
                await NotificationManager.shared.ensureAuthorized()
                // Окно наблюдения закрывается само (кнопки «Ввёл успешно» нет),
                // поэтому при каждом запуске догоняем то, что дозрело, пока
                // приложение было закрыто.
                syncIntroductions()
                refreshWidget()
            }
            .onChange(of: scenePhase) { _, phase in
                // И при возврате из фона: день мог смениться.
                if phase == .active { syncIntroductions() }
            }
            // Изменилось то, что видно в виджетах, — обновляем снимок. Сигнатура
            // дешёвая: пересчитывать снимок на каждое изменение любого поля незачем.
            .onChange(of: widgetSignature) { _, _ in refreshWidget() }
    }

    /// Всё, от чего зависят виджеты: коллекция, что вводится, число записей
    /// в хвосте журнала (прогресс ввода и планы) и право на Pro.
    private var widgetSignature: String {
        let introducing = statuses.filter { $0.state == .introducing }.map(\.foodId).sorted()
        let introduced = statuses.filter { $0.state == .introduced }.count
        return "\(isPro)|\(introduced)|\(introducing)|\(logs.count)"
    }

    /// Кладёт снимок в App Group и просит WidgetKit перерисоваться.
    /// Без App Group (не выдана в профиле) — тихо ничего, виджет просто пустой.
    private func refreshWidget() {
        let snapshot = WidgetContent(catalog: .shared, profile: child.feedingProfile,
                                     statuses: statuses, logs: logs, isPro: isPro,
                                     icon: WidgetIcons.png).snapshot()
        if WidgetSnapshotStore.save(snapshot) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// Закрывает дозревшие окна наблюдения и переставляет напоминания.
    /// Заодно разово подтягивает план на новые дефолты окон (2/3), если юзер
    /// их не менял руками.
    private func syncIntroductions() {
        if PlanMigration.ObservationWindowsV2.apply(to: child) {
            try? context.save()
        }
        // Старые записи (дневник был глобальным) привязываем к ребёнку. Идемпотентно:
        // уже привязанные не трогаются, при нескольких детях не делается ничего.
        PlanMigration.ChildOwnership.apply(context: context)
        FeedingService(context: context, childId: child.id).completeDueIntroductions(profile: child.feedingProfile)
        NotificationManager.shared.refresh(context: context)
    }

    private var tabs: some View {
        TabView(selection: $router.selectedTab) {
            DashboardView(child: child, isPro: isPro, goToCatalog: { router.selectedTab = .catalog })
                .tabItem { Label("Сегодня", systemImage: "sun.max.fill") }
                .tag(Tab.today)

            CatalogView(child: child)
                .tabItem { Label("Каталог", systemImage: "list.bullet") }
                .tag(Tab.catalog)

            CalendarView(child: child)
                .tabItem { Label("Календарь", systemImage: "calendar") }
                .tag(Tab.calendar)

            NavigationStack {
                AllergensView(child: child)
                    .background(AppBackground())
                    .navigationTitle("Аллергены")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem { Label("Аллергены", systemImage: "exclamationmark.shield.fill") }
            .tag(Tab.allergens)
            .badge(dueCount)

            ProfileView(child: child)
                .tabItem { Label("Профиль", systemImage: "person.crop.circle.fill") }
                .tag(Tab.profile)
        }
    }
}


/// Иконки продуктов для виджета: расширение не видит ассеты приложения, поэтому
/// приложение само рисует `FoodIcon` в PNG и кладёт в снимок. Кэш по id — снимок
/// пересобирается на каждую запись, а иконка продукта от этого не меняется.
@MainActor
enum WidgetIcons {
    private static var cache: [String: Data] = [:]

    static func png(_ food: Food) -> Data? {
        if let hit = cache[food.id] { return hit }
        let renderer = ImageRenderer(content: FoodIcon(food: food, size: 40, circular: true)
            .environment(\.colorScheme, .light))
        renderer.scale = 3
        let data = renderer.uiImage?.pngData()
        cache[food.id] = data
        return data
    }
}
