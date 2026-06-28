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
                ToolbarItem(placement: .principal) {
                    Picker("", selection: $section) {
                        ForEach(CatalogSection.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 260)
                }
            }
            .navigationDestination(for: Food.self) { food in
                FoodDetailView(food: food, child: child)
            }
            .sheet(isPresented: $showAddCustom) { AddCustomFoodSheet() }
            .onAppear { FoodCatalog.setCustom(customFoods) }
            .onChange(of: customFoods.map(\.id)) { FoodCatalog.setCustom(customFoods) }
        }
    }

    private var foodList: some View {
        List {
            ForEach(FoodCategory.allCases, id: \.self) { category in
                let foods = foods(in: category)
                if category == .other {
                    Section(category.title) {
                        ForEach(foods) { food in foodRow(food) }
                        addCustomRow
                    }
                } else if !foods.isEmpty {
                    Section(category.title) {
                        ForEach(foods) { food in foodRow(food) }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .safeAreaInset(edge: .top) { searchBar }
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

    private var addCustomRow: some View {
        Button { showAddCustom = true } label: {
            Label("Добавить свой продукт", systemImage: "plus.circle.fill")
                .foregroundStyle(Theme.accent).fontWeight(.semibold)
        }
        .listRowBackground(Color.white)
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
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
        .padding(.horizontal)
        .padding(.bottom, 6)
    }

    private func row(for food: Food) -> some View {
        HStack(spacing: 12) {
            FoodIcon(food: food, size: 38)
            Text(food.name).fontWeight(.medium)
            if food.isAllergen {
                StatusBadge(text: "аллерген", color: .orange)
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

    private func foods(in category: FoodCategory) -> [Food] {
        catalog.search(search).filter { $0.category == category }
    }
}
