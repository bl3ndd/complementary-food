import SwiftUI
import SwiftData

/// Вкладка «Каталог»: продукты по категориям с поиском. Аллергены — отдельный таб.
struct CatalogView: View {
    let child: Child
    @Environment(\.modelContext) private var context
    @Query private var statuses: [IntroductionStatus]
    @Query private var customFoods: [CustomFood]
    @State private var search = ""
    @State private var filter: CatalogFilter = .all
    @State private var showAddCustom = false
    @State private var pendingDeleteCustom: Food?
    @State private var path: [Food] = []
    @ObservedObject private var router = AppRouter.shared

    private let catalog = FoodCatalog.shared

    var body: some View {
        NavigationStack(path: $path) {
            foodList
                .background(AppBackground())
                .navigationTitle("Каталог")
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(for: Food.self) { food in
                    FoodDetailView(food: food, child: child)
                }
                .onAppear { openPending(router.pendingFoodId) }
                .onChange(of: router.pendingFoodId) { _, fid in openPending(fid) }
                .sheet(isPresented: $showAddCustom) { AddCustomFoodSheet() }
                .alert("Удалить свой продукт?",
                       isPresented: Binding(get: { pendingDeleteCustom != nil },
                                            set: { if !$0 { pendingDeleteCustom = nil } }),
                       presenting: pendingDeleteCustom) { food in
                    Button("Удалить", role: .destructive) { deleteCustom(food.id) }
                    Button("Отмена", role: .cancel) {}
                } message: { food in
                    Text("«\(food.localizedName)» и все его записи в дневнике удалятся. Действие необратимо.")
                }
                .onAppear { FoodCatalog.setCustom(customFoods) }
                .onChange(of: customFoods.map(\.id)) { FoodCatalog.setCustom(customFoods) }
        }
    }

    private var foodList: some View {
        // Поиск считаем один раз за рендер (fuzzy с Левенштейном) — затем фильтруем
        // по категориям, а не вызываем search() на каждую секцию.
        let results = catalog.search(search).filter { filter.matches(state(for: $0)) }
        return VStack(spacing: 10) {
            // Поиск и «свой продукт» — над списком, чтобы не было большого инсета List
            // и кнопка не обрезалась рядом.
            VStack(spacing: 8) {
                searchBar
                filterChips
                addCustomButton
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            List {
                ForEach(FoodCategory.allCases, id: \.self) { category in
                    let foods = results.filter { $0.category == category }
                    if !foods.isEmpty {
                        Section(category.title) {
                            ForEach(foods) { food in foodRow(food) }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
    }

    @ViewBuilder
    private func foodRow(_ food: Food) -> some View {
        NavigationLink(value: food) { row(for: food) }
            .listRowBackground(Theme.card)
            .swipeActions(edge: .trailing) {
                if food.id.hasPrefix("custom-") {
                    Button(role: .destructive) { pendingDeleteCustom = food } label: {
                        Label("Удалить", systemImage: "trash")
                    }
                }
            }
    }

    /// Линзы по СВОЕМУ статусу — это фильтр по собственным данным, а не совет
    /// «что вводить». Подписи переиспользуют локализованные `IntroState.title`.
    private enum CatalogFilter: String, CaseIterable, Identifiable {
        case all, notIntroduced, introducing, introduced, paused

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all:           return String(localized: "Всё")
            case .notIntroduced: return IntroState.notIntroduced.title
            case .introducing:   return IntroState.introducing.title
            case .introduced:    return IntroState.introduced.title
            case .paused:        return IntroState.paused.title
            }
        }

        func matches(_ state: IntroState) -> Bool {
            switch self {
            case .all:           return true
            case .notIntroduced: return state == .notIntroduced
            case .introducing:   return state == .introducing
            case .introduced:    return state == .introduced
            // «Пауза» — всё отложенное: и пауза, и помеченная аллергия.
            case .paused:        return state == .paused || state == .allergy
            }
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CatalogFilter.allCases) { f in
                    let active = filter == f
                    Button {
                        Haptics.select()
                        withAnimation(.snappy) { filter = f }
                    } label: {
                        Text(f.title)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 13).padding(.vertical, 7)
                            .background(active ? Theme.accent.opacity(0.16) : Theme.fill, in: Capsule())
                            .overlay(Capsule().stroke(active ? Theme.accent.opacity(0.45) : .clear,
                                                      lineWidth: 1.5))
                            .foregroundStyle(active ? Theme.accent : .secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(f.title))
                    .accessibilityAddTraits(active ? [.isButton, .isSelected] : .isButton)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private var addCustomButton: some View {
        Button { showAddCustom = true } label: {
            Label("Добавить свой продукт", systemImage: "plus.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14).padding(.vertical, 11)
                .background(Theme.card, in: Capsule())
                .overlay(Capsule().stroke(Theme.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func deleteCustom(_ id: String) {
        // Удаляем продукт + связанные статус/логи (чистка орфанов), затем обновляем реестр.
        FeedingService(context: context).deleteCustomFood(id: id)
        FoodCatalog.setCustom(customFoods.filter { $0.id != id })
    }

    /// Открыть карточку продукта по deep-link из пуша (foodId → push FoodDetailView).
    private func openPending(_ fid: String?) {
        guard let fid, let food = catalog.food(id: fid) else { return }
        path = [food]
        router.pendingFoodId = nil
    }

    /// Свой поиск: системный `.searchable` не рисуется внутри страничного TabView.
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Поиск продукта", text: $search)
                .autocorrectionDisabled()
            if !search.isEmpty {
                Button { search = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Theme.card, in: Capsule())
        .overlay(Capsule().stroke(Theme.hairline, lineWidth: 1))
    }

    private func row(for food: Food) -> some View {
        HStack(spacing: 12) {
            FoodIcon(food: food, size: 38)
            Text(food.localizedName).fontWeight(.medium)
            if food.isAllergen {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2).foregroundStyle(.orange)
                    .accessibilityLabel(Text("аллерген"))
            }
            Spacer()
            let state = state(for: food)
            if state != .notIntroduced {
                StatusBadge(text: state.title, color: state.color)
            }
        }
    }

    private func state(for food: Food) -> IntroState {
        statuses.first { $0.foodId == food.id }?.state ?? .notIntroduced
    }
}
