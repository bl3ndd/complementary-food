import SwiftUI
import SwiftData

/// Вкладка «Каталог» с сегментным переключателем «Продукты | Аллергены» (SPEC §7).
/// Продукты — каталог по категориям с поиском; Аллергены — список поддержки.
struct CatalogView: View {
    let child: Child
    @Environment(\.modelContext) private var context
    @Query private var statuses: [IntroductionStatus]
    @Query private var customFoods: [CustomFood]
    @State private var search = ""
    @State private var section: CatalogSection = .foods
    @State private var showAddCustom = false

    private let catalog = FoodCatalog.shared

    enum CatalogSection: String, CaseIterable, Identifiable {
        case foods = "Продукты"
        case allergens = "Аллергены"
        var id: String { rawValue }

        /// Локализованная подпись сегмента (rawValue — ключ каталога/идентификатор).
        var title: String {
            switch self {
            case .foods:     return String(localized: "Продукты")
            case .allergens: return String(localized: "Аллергены")
            }
        }
    }

    var body: some View {
        NavigationStack {
            TabView(selection: $section) {
                foodList.tag(CatalogSection.foods)
                AllergensView(child: child).tag(CatalogSection.allergens)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.snappy, value: section)
            .background(AppBackground())
            .navigationTitle("Каталог")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { segmentControl }
            }
            .navigationDestination(for: Food.self) { food in
                FoodDetailView(food: food, child: child)
            }
            .sheet(isPresented: $showAddCustom) { AddCustomFoodSheet() }
            .onAppear { FoodCatalog.setCustom(customFoods) }
            .onChange(of: customFoods.map(\.id)) { FoodCatalog.setCustom(customFoods) }
        }
    }

    /// Капсульный сегмент-контрол в стиле приложения (системный выглядит «квадратным»).
    private var segmentControl: some View {
        HStack(spacing: 0) {
            ForEach(CatalogSection.allCases) { s in
                let on = section == s
                Text(s.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(on ? .white : Color.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background {
                        if on { Capsule().fill(Theme.accentGradient) }
                    }
                    .contentShape(Capsule())
                    .onTapGesture { withAnimation(.snappy) { section = s } }
            }
        }
        .padding(3)
        .background(Capsule().fill(.black.opacity(0.06)))
        .frame(width: 240)
    }

    private var foodList: some View {
        // Поиск считаем один раз за рендер (fuzzy с Левенштейном) — затем фильтруем
        // по категориям, а не вызываем search() на каждую секцию.
        let results = catalog.search(search)
        return VStack(spacing: 10) {
            // Поиск и «свой продукт» — над списком, чтобы не было большого инсета List
            // и кнопка не обрезалась рядом.
            VStack(spacing: 8) {
                searchBar
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
            .listRowBackground(Color.white)
            .swipeActions(edge: .trailing) {
                if food.id.hasPrefix("custom-") {
                    Button(role: .destructive) { deleteCustom(food.id) } label: {
                        Label("Удалить", systemImage: "trash")
                    }
                }
            }
    }

    private var addCustomButton: some View {
        Button { showAddCustom = true } label: {
            Label("Добавить свой продукт", systemImage: "plus.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14).padding(.vertical, 11)
                .background(.white, in: Capsule())
                .overlay(Capsule().stroke(.black.opacity(0.06), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func deleteCustom(_ id: String) {
        if let cf = customFoods.first(where: { $0.id == id }) {
            context.delete(cf)
            try? context.save()
            FoodCatalog.setCustom(customFoods.filter { $0.id != id })
        }
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
        .background(.white, in: Capsule())
        .overlay(Capsule().stroke(.black.opacity(0.06), lineWidth: 1))
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
