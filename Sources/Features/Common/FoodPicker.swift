import SwiftUI
import SwiftData

/// Общий список выбора продукта для листов «Записать», «Реакция» и «Запланировать».
///
/// Без поиска сверху — то, что нужно прямо сейчас: что давали сегодня (после
/// реакции ищут именно это) и что сейчас вводится; дальше весь каталог. У каждой
/// строки — статус ребёнка, чтобы «Аллергия» и «Пауза» не терялись в списке.
/// Поиск без результатов предлагает завести свой продукт с уже набранным именем.
struct FoodPickerList<Row: View>: View {
    let childId: UUID
    @Binding var search: String
    /// Порядок верхних секций: для реакции «сегодня давали» важнее всего.
    var todayFirst = true
    @ViewBuilder var row: (Food, IntroState) -> Row
    /// Создан свой продукт из пустого поиска.
    var onCustomAdded: (Food) -> Void = { _ in }

    @Query private var statuses: [IntroductionStatus]
    @Query private var todayLogs: [FoodLog]
    @State private var addCustom = false
    private let catalog = FoodCatalog.shared

    init(childId: UUID, search: Binding<String>, todayFirst: Bool = true,
         onCustomAdded: @escaping (Food) -> Void = { _ in },
         @ViewBuilder row: @escaping (Food, IntroState) -> Row) {
        self.childId = childId
        _search = search
        self.todayFirst = todayFirst
        self.onCustomAdded = onCustomAdded
        self.row = row
        let cid = childId
        _statuses = Query(filter: #Predicate<IntroductionStatus> { $0.childId == cid })
        let dayStart = Calendar.current.startOfDay(for: Date())
        _todayLogs = Query(filter: #Predicate<FoodLog> {
            $0.childId == cid && !$0.planned && $0.date >= dayStart
        }, sort: \FoodLog.date, order: .reverse)
    }

    var body: some View {
        let stateById = Dictionary(statuses.map { ($0.foodId, $0.state) },
                                   uniquingKeysWith: { first, _ in first })
        let state = { (food: Food) in stateById[food.id] ?? .notIntroduced }
        let results = catalog.search(search)

        List {
            if search.isEmpty {
                let sections = todayFirst ? [today, introducing] : [introducing, today]
                ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                    if !section.foods.isEmpty {
                        Section(section.title) {
                            ForEach(section.foods) { food in row(food, state(food)) }
                        }
                    }
                }
                Section(String(localized: "Все продукты")) {
                    ForEach(results) { food in row(food, state(food)) }
                }
            } else if results.isEmpty {
                emptyState
            } else {
                ForEach(results) { food in row(food, state(food)) }
            }
        }
        .sheet(isPresented: $addCustom) {
            AddCustomFoodSheet(onAdded: { food in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { onCustomAdded(food) }
            }, initialName: search)
        }
    }

    private var today: (title: String, foods: [Food]) {
        var seen = Set<String>()
        let foods = todayLogs.filter { seen.insert($0.foodId).inserted }
            .compactMap { catalog.food(id: $0.foodId) }
        return (String(localized: "Сегодня давали"), foods)
    }

    private var introducing: (title: String, foods: [Food]) {
        let foods = statuses.filter { $0.state == .introducing }
            .compactMap { catalog.food(id: $0.foodId) }
        return (String(localized: "Сейчас вводишь"), foods)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("Ничего не нашлось")
                .font(.headline)
            Button {
                addCustom = true
            } label: {
                Label("Добавить «\(search)» как свой продукт", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderless)
            .tint(Theme.accent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .listRowBackground(Color.clear)
    }
}

/// Строка продукта в списке выбора: иконка, имя и статус ребёнка, если он есть.
struct FoodPickerRow<Trailing: View>: View {
    let food: Food
    let state: IntroState
    @ViewBuilder var trailing: Trailing

    init(food: Food, state: IntroState, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.food = food
        self.state = state
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 10) {
            FoodIcon(food: food, size: 30)
            Text(food.localizedName).foregroundStyle(.primary)
            Spacer(minLength: 8)
            if state != .notIntroduced {
                StatusBadge(text: state.title, color: state.color)
            }
            trailing
        }
    }
}
