import SwiftUI
import SwiftData
import WidgetKit

struct MainTabView: View {
    let child: Child
    @Environment(\.modelContext) private var context
    @Query private var statuses: [IntroductionStatus]
    /// Тот же хвост журнала, что и у дашборда, а не весь дневник: бейдж таба иначе
    /// пересчитывает поддержку аллергенов по тысячам записей на каждое изменение
    /// стора — и утаскивает в пересчёт весь шелл табов вместе со вкладками.
    @Query private var logs: [FoodLog]
    @ObservedObject private var router = AppRouter.shared
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.displayScale) private var displayScale

    init(child: Child) {
        self.child = child
        // Выровнено по началу дня — предикат обязан быть стабильным между проходами
        // body, иначе @Query перевыбирает журнал на ровном месте.
        let cal = Calendar.current
        let cutoff = cal.date(byAdding: .day, value: -DashboardView.recentWindowDays,
                              to: cal.startOfDay(for: Date())) ?? .distantPast
        _logs = Query(FetchDescriptor<FoodLog>(predicate: #Predicate { $0.date >= cutoff }))
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
            // Коллекция выросла — обновляем снимок для виджета. Считаем по числу
            // введённых, а не по всему массиву: пересчитывать снимок на каждое
            // изменение любого статуса незачем.
            .onChange(of: statuses.filter { $0.state == .introduced }.count) { _, _ in
                refreshWidget()
            }
    }

    /// Кладёт снимок коллекции в App Group и просит WidgetKit перерисоваться.
    /// Без App Group (не выдана в профиле) — тихо ничего, виджет просто пустой.
    private func refreshWidget() {
        let catalog = FoodCatalog.shared
        let items = statuses
            .filter { $0.state == .introduced }
            .compactMap { catalog.food(id: $0.foodId) }
            .map { WidgetSnapshot.Item(id: $0.id, emoji: $0.emoji) }
        if WidgetSnapshotStore.save(.make(items: items)) {
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
        FeedingService(context: context).completeDueIntroductions(profile: child.feedingProfile)
        NotificationManager.shared.refresh(context: context, profile: child.feedingProfile)
    }

    private var tabs: some View {
        TabView(selection: $router.selectedTab) {
            DashboardView(child: child, goToCatalog: { router.selectedTab = .catalog })
                .tabItem { Label("Сегодня", systemImage: "sun.max.fill") }
                .tag(Tab.today)

            CatalogView(child: child)
                .tabItem { Label("Каталог", systemImage: "list.bullet") }
                .tag(Tab.catalog)

            CalendarView()
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

