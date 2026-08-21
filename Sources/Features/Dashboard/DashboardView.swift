import SwiftUI
import SwiftData

/// Главная «Стена Pudding» (концепт A): маскот-барометр → быстрые действия →
/// заполняющаяся коллекция продуктов → витрина аллергенов → лента дня.
/// Коллекция показывает то, что УЖЕ сделано (ретроспектива), без советов/рекомендаций.
struct DashboardView: View {
    let child: Child
    var goToCatalog: () -> Void = {}
    @Environment(\.modelContext) private var context
    @Query private var statuses: [IntroductionStatus]
    /// Только записи за сегодня — из них рисуется лента дня.
    @Query private var todayLogs: [FoodLog]
    /// Хвост журнала (см. `recentWindowDays`) — поддержка аллергенов и прогресс
    /// окна наблюдения смотрят назад недалеко, весь дневник им не нужен.
    @Query private var recentLogs: [FoodLog]
    @State private var editingLog: FoodLog?
    @State private var showFeed = false
    @State private var showReaction = false
    @State private var showPlan = false
    /// Явный навигационный путь: value-based NavigationLink в ScrollView на этом
    /// экране инертен (iOS 26) — пушим программно через Button + path.
    @State private var path: [Food] = []

    private let catalog = FoodCatalog.shared

    /// Насколько далеко назад дашборду нужен журнал.
    ///
    /// Для статуса аллергена окно **точное**: интервал поддержки — максимум 7 дней,
    /// всё, что старше, и так «просрочено», а базой в этом случае служит `completedAt`
    /// статуса (см. `AllergenMaintenance`). Единственное огрубление — подпись
    /// «N из M кормлений» у ввода, который висит незакрытым дольше этого срока:
    /// там счётчик может недосчитать старые кормления. На автозакрытие ввода это
    /// не влияет — свипер `completeDueIntroductions` считает по полному фетчу.
    static let recentWindowDays = 30

    init(child: Child, goToCatalog: @escaping () -> Void = {}) {
        self.child = child
        self.goToCatalog = goToCatalog

        // Весь журнал в @Query — это две беды сразу. Первая: каждый проход body
        // сканирует тысячи SwiftData-объектов (у живого дневника их 2678, и одна
        // только лента дня стоила 28 мс — при бюджете кадра 8.3 мс). Вторая, хуже:
        // чтение полей подписывает вьюху на изменения КАЖДОГО объекта, и любая
        // запись в стор роняет весь экран в полный пересчёт. Фильтрует пусть SQLite.
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: Date())
        _todayLogs = Query(FetchDescriptor<FoodLog>(
            predicate: #Predicate { $0.date >= dayStart }))

        // Границы берём на момент создания вьюхи и ВЫРАВНИВАЕМ ПО НАЧАЛУ ДНЯ: вьюха
        // пересоздаётся на каждый проход body шелла табов, и «сейчас минус 30 дней»
        // давало бы каждый раз чуть другой предикат — то есть новую выборку.
        // Если приложение переживёт полночь, в выборках просто окажется чуть больше
        // старых записей: день ленты всё равно отсекается по актуальной дате
        // в `todayEntries`, а окно поддержки от лишних суток не страдает.
        let cutoff = cal.date(byAdding: .day, value: -Self.recentWindowDays, to: dayStart) ?? .distantPast
        _recentLogs = Query(FetchDescriptor<FoodLog>(
            predicate: #Predicate { $0.date >= cutoff }))
    }

    var body: some View {
        // Сводки считаются ОДИН раз за проход body и дальше передаются готовыми.
        // Раньше это были вычисляемые свойства, и каждое прочёсывало весь дневник
        // при каждом обращении: todayEntries — 7 раз, allergenGroups — 4, коллекция — 3.
        // На демо-объёме (~450 записей) скролл проседал до 46 fps.
        // `child.feedingProfile` тоже не бесплатный: парсит строку групп аллергенов
        // и дёргает String(localized:) — а раньше он собирался заново в каждой сводке.
        let _ = DashboardPerf.on ? Self._printChanges() : ()
        let t0 = CFAbsoluteTimeGetCurrent()
        let profile = child.feedingProfile
        let today = todayEntries
        let tToday = CFAbsoluteTimeGetCurrent()
        let groups = allergenGroups(profile)
        let tGroups = CFAbsoluteTimeGetCurrent()
        let introducing = introducingItems(profile)
        let introducedStatuses = statuses.filter { $0.state == .introduced }
        let collection = introducedStatuses.compactMap { catalog.food(id: $0.foodId) }
        let _ = DashboardPerf.log(t0: t0, afterToday: tToday, afterGroups: tGroups,
                                  logs: recentLogs.count, statuses: statuses.count)

        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 16) {
                    heroCard(today: today).cozyAppear()
                    actionTiles.cozyAppear(0.06)
                    todayCard(today: today).cozyAppear(0.12)
                    introducingCard(introducing).cozyAppear(0.18)
                    collectionCard(collection, introduced: introducedStatuses.count).cozyAppear(0.24)
                    allergenCard(groups).cozyAppear(0.30)
                }
                .padding()
                // Карточка «Сейчас вводишь» появляется/уходит пружиной, а не скачком.
                .animation(.spring(response: 0.5, dampingFraction: 0.85),
                           value: introducing.map(\.food.id))
            }
            .background(AppBackground())
            .navigationTitle("Сегодня")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Food.self) { food in
                FoodDetailView(food: food, child: child)
            }
            .sheet(item: $editingLog) { EditLogSheet(log: $0) }
            .sheet(isPresented: $showFeed) { QuickLogSheet(child: child, mode: .feeding) }
            .sheet(isPresented: $showReaction) { QuickLogSheet(child: child, mode: .reaction) }
            .sheet(isPresented: $showPlan) {
                PlanIntroSheet(initialDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date())
            }
        }
    }

    // MARK: - Шапка (компактная строка, без карточной обвязки)

    private func heroCard(today: [DayEntry]) -> some View {
        HStack(spacing: 12) {
            Mascot(mood: today.isEmpty ? .happy : .cheer, size: 44).gentleBob()
            VStack(alignment: .leading, spacing: 1) {
                Text(greeting)
                    .font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Text(child.name.isEmpty ? String(localized: "Малыш") : child.name)
                        .font(.headline).lineLimit(1)
                    Text("\(child.ageInMonths) мес")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            if !today.isEmpty {
                // «записей: N» — формат пинится E2E (R9, CONTAINS).
                Text("записей: \(today.count)")
                    .font(.caption.weight(.bold)).foregroundStyle(Theme.accent)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: today.count)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Theme.accent.opacity(0.12), in: Capsule())
            }
        }
        .padding(.horizontal, 4)
    }

    /// Приветствие по времени суток (тёплый акцент карточки ребёнка).
    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12:  return String(localized: "Доброе утро")
        case 12..<18: return String(localized: "Добрый день")
        case 18..<23: return String(localized: "Добрый вечер")
        default:      return String(localized: "Доброй ночи")
        }
    }

    // MARK: - Быстрые действия

    /// Быстрые действия: «Записать» — главная (бренд-градиент), «Реакция» —
    /// вторичная (белая с оранжевым акцентом). Компактные строки, не «квадраты».
    private var actionTiles: some View {
        HStack(spacing: 12) {
            Button {
                Haptics.tap(); showFeed = true
            } label: {
                actionLabel("Записать", asset: "ui_plate", emoji: "🍽️",
                            iconBackground: .white.opacity(0.22))
                    .foregroundStyle(.white)
                    // Бренд-градиент — как BigButton: primary-действие экрана.
                    // Тень на фигуре, а не на плитке целиком (см. cartoonCard).
                    .background {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Theme.accentGradient)
                            .shadow(color: Theme.accentDeep.opacity(0.30), radius: 10, x: 0, y: 5)
                    }
            }
            .buttonStyle(BouncyButtonStyle())

            Button {
                Haptics.tap(); showReaction = true
            } label: {
                actionLabel("Реакция", asset: "react_skin", emoji: "🩹",
                            iconBackground: Color.orange.opacity(0.15))
                    .foregroundStyle(.primary)
                    .background {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Theme.card)
                            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
                    }
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.orange.opacity(0.35), lineWidth: 1.5))
            }
            .buttonStyle(BouncyButtonStyle())
        }
    }

    private func actionLabel(_ title: LocalizedStringKey, asset: String, emoji: String,
                             iconBackground: Color) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(iconBackground).frame(width: 38, height: 38)
                OpenMojiIcon(asset: asset, fallback: emoji, size: 24)
            }
            Text(title).font(.subheadline.bold())
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    // MARK: - Сейчас вводишь (окно наблюдения)

    @ViewBuilder
    private func introducingCard(_ items: [IntroducingItem]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "leaf.fill").foregroundStyle(Theme.mint)
                    Text("Сейчас вводишь").font(.headline)
                }
                ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                    if idx > 0 { Divider() }
                    Button { path.append(item.food) } label: {
                        HStack(spacing: 12) {
                            FoodIcon(food: item.food, size: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.food.localizedName).font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(item.progress).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(idx == 0 ? "screenshot.introducing" : "")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cartoonCard()
            .transition(.scale(scale: 0.96).combined(with: .opacity))
        }
    }

    /// Строка карточки «Сейчас вводишь» с уже готовым прогрессом окна.
    private struct IntroducingItem: Identifiable {
        let food: Food
        let status: IntroductionStatus
        /// Прогресс окна — по числу дней, в которые продукт давали.
        let progress: String
        var id: String { status.foodId }
    }

    private func introducingItems(_ profile: FeedingProfile) -> [IntroducingItem] {
        let active = statuses.filter { $0.state == .introducing }
        guard !active.isEmpty else { return [] }

        var starts: [String: Date] = [:]
        for s in active { if let start = s.introStartedAt { starts[s.foodId] = start } }
        // Один проход по журналу на всю карточку вместо полного скана на продукт.
        let done = FeedingService.introFeedingDays(logs: recentLogs, since: starts)

        return active.compactMap { s in
            guard let food = catalog.food(id: s.foodId) else { return nil }
            guard s.introStartedAt != nil else {
                return IntroducingItem(food: food, status: s, progress: "")
            }
            let window = profile.observationDays(for: food)
            let text = String(localized: "\(min(done[s.foodId] ?? 0, window)) из \(window) кормлений")
            return IntroducingItem(food: food, status: s, progress: text)
        }
    }

    // MARK: - Коллекция продуктов (заполняется)

    private func collectionCard(_ foods: [Food], introduced: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Коллекция продуктов").font(.headline)
                Spacer()
                // Цель — ближайшая веха, а не весь каталог: до 71 продукта не доходит
                // никто, и шкала «почти пустая» вместо мотивации давала обратное.
                Text("\(introduced)/\(collectionGoal(introduced))")
                    .font(.subheadline.bold()).foregroundStyle(Theme.accent)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: introduced)
            }
            ProgressView(value: Double(introduced), total: Double(collectionGoal(introduced)))
                .tint(Theme.accent)
                .animation(.spring(response: 0.5, dampingFraction: 0.85), value: introduced)

            if foods.isEmpty {
                // Пустая коллекция: тёплый эмпти-стейт вместо сетки пунктирных кругов.
                HStack(spacing: 14) {
                    Mascot(mood: .curious, size: 56).gentleBob()
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Коллекция пока пуста").font(.subheadline.bold())
                        Text("Каждый введённый продукт появится здесь — начни с первого!")
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 6)
            } else {
                // Только то, что реально введено: пунктирные «пустые слоты» до 20 штук
                // читались как невыполненный план, хотя коллекция — про уже сделанное.
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 46), spacing: 10)], spacing: 10) {
                    ForEach(foods.prefix(20)) { food in
                        Button { path.append(food) } label: { FoodIcon(food: food, size: 44) }
                            .buttonStyle(.plain)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.45, dampingFraction: 0.7), value: introduced)
            }

            Button { goToCatalog() } label: {
                Label(foods.isEmpty ? "Открыть каталог" : "Вся коллекция",
                      systemImage: "square.grid.2x2")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.accent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartoonCard()
    }

    private var ghostCell: some View {
        Circle().fill(Theme.fill)
            .frame(width: 44, height: 44)
            .overlay(Circle().stroke(Theme.hairline,
                                     style: StrokeStyle(lineWidth: 1, dash: [3])))
    }

    // MARK: - Витрина аллергенов

    private func allergenCard(_ groups: [AllergenGroupStatus]) -> some View {
        Button { AppRouter.shared.selectedTab = .allergens } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Аллергены").font(.headline)
                    Spacer()
                    let due = dueCount(groups)
                    if due > 0 {
                        Text("\(due)").font(.caption.bold()).foregroundStyle(.white)
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(Color.orange, in: Capsule())
                            .gentlePulse()
                    }
                    Text("\(groups.filter(\.isIntroduced).count)/\(groups.count)")
                        .font(.subheadline.bold()).foregroundStyle(Theme.accent)
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 56), spacing: 8)], spacing: 10) {
                    ForEach(groups) { allergenCircle($0) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cartoonCard()
        }
        .buttonStyle(.plain)
    }

    private func allergenCircle(_ g: AllergenGroupStatus) -> some View {
        let due = g.isIntroduced && !g.hasAllergy && g.status != .ok
        return VStack(spacing: 4) {
            ZStack {
                if let rep = g.representativeFood {
                    FoodIcon(food: rep, size: 40)
                        .grayscale(g.isIntroduced ? 0 : 1)
                        .opacity(g.isIntroduced ? 1 : 0.4)
                } else {
                    ghostCell.frame(width: 40, height: 40)
                }
                if due {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(Color.orange, lineWidth: 2).frame(width: 46, height: 46)
                }
                if g.hasAllergy {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(Color.red, lineWidth: 2).frame(width: 46, height: 46)
                }
            }
            Text(g.group.title).font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(1)
        }
    }

    // MARK: - Лента дня

    private func todayCard(today: [DayEntry]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("Дневник за сегодня").font(.headline)
                Spacer()
                Button { showPlan = true } label: {
                    Label("Запланировать", systemImage: "calendar.badge.plus")
                        .font(.caption.weight(.semibold)).foregroundStyle(Theme.accent)
                }
            }
            if today.isEmpty {
                Text("Записей сегодня ещё нет").font(.subheadline).foregroundStyle(.secondary)
            } else {
                ForEach(today) { entry in
                    HStack(spacing: 12) {
                        if let food = entry.food { FoodIcon(food: food, size: 38) }
                        else { EmojiAvatar(emoji: "🍽️", asset: "ui_plate", size: 38) }
                        Text(entry.food?.localizedName ?? entry.foodName)
                            .font(.subheadline.weight(.medium)).lineLimit(1)
                        if let r = entry.reaction, r != .none {
                            StatusBadge(text: r.title, color: .red)
                        }
                        if let liking = entry.liking {
                            OpenMojiIcon(asset: "like_\(liking.rawValue)", fallback: liking.emoji, size: 24)
                        }
                        Spacer(minLength: 8)
                        // Время — всегда крайнее справа, ровным столбцом.
                        Text(entry.date.formatted(.dateTime.hour().minute()))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { editingLog = entry.log }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartoonCard()
        // Новая запись мягко «вплывает» в дневник (сохранение из быстрого листа).
        .animation(.spring(response: 0.45, dampingFraction: 0.8),
                   value: today.map(\.id))
    }

    // MARK: - Данные

    /// Ближайшая веха коллекции: 5 → 10 → 25 → 50 → весь каталог. Шкала реально
    /// заполняется и сбрасывается на следующую цель, а не висит почти пустой.
    private func collectionGoal(_ introduced: Int) -> Int {
        let steps = [5, 10, 25, 50, catalog.all.count]
        return steps.first { $0 > introduced } ?? max(1, catalog.all.count)
    }

    private var todayEntries: [DayEntry] {
        CalendarService(catalog: catalog, logs: todayLogs).day(Date()).entries.filter { !$0.planned }
    }

    private func allergenGroups(_ profile: FeedingProfile) -> [AllergenGroupStatus] {
        AllergenMaintenance(catalog: catalog, profile: profile,
                            statuses: statuses, logs: recentLogs).groups()
    }
    private func dueCount(_ groups: [AllergenGroupStatus]) -> Int {
        groups.filter { $0.isIntroduced && !$0.hasAllergy && $0.status != .ok }.count
    }
}

// MARK: - Временная диагностика перфа (флаг `-dashperf`)

/// ВРЕМЕННО. Показывает, сколько раз и почему пересчитывается body главной и
/// во что обходятся сводки. Снести, как только причина рывков найдена.
enum DashboardPerf {
    static let on = ProcessInfo.processInfo.arguments.contains("-dashperf")

    private nonisolated(unsafe) static var count = 0

    static func log(t0: CFAbsoluteTime, afterToday: CFAbsoluteTime, afterGroups: CFAbsoluteTime,
                    logs: Int, statuses: Int) {
        guard on else { return }
        count += 1
        let end = CFAbsoluteTimeGetCurrent()
        let ms = { (a: CFAbsoluteTime, b: CFAbsoluteTime) in String(format: "%.2f", (b - a) * 1000) }
        print("⏱ dash.body #\(count) total=\(ms(t0, end))ms "
              + "today=\(ms(t0, afterToday))ms groups=\(ms(afterToday, afterGroups))ms "
              + "rest=\(ms(afterGroups, end))ms | logs=\(logs) statuses=\(statuses)")
    }
}
