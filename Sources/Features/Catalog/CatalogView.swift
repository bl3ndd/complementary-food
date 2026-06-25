import SwiftUI
import SwiftData

/// Каталог продуктов по категориям с поиском (SPEC §7).
struct CatalogView: View {
    let child: Child
    @Query private var statuses: [IntroductionStatus]
    @State private var search = ""

    private let catalog = FoodCatalog.shared

    var body: some View {
        NavigationStack {
            List {
                ForEach(FoodCategory.allCases, id: \.self) { category in
                    let foods = foods(in: category)
                    if !foods.isEmpty {
                        Section(category.title) {
                            ForEach(foods) { food in
                                NavigationLink(value: food) { row(for: food) }
                                    .listRowBackground(Color.white)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .searchable(text: $search, prompt: "Поиск продукта")
            .navigationTitle("Каталог")
            .navigationDestination(for: Food.self) { food in
                FoodDetailView(food: food, child: child)
            }
        }
    }

    private func row(for food: Food) -> some View {
        HStack(spacing: 12) {
            FoodIcon(food: food, size: 38)
            Text(food.name).fontWeight(.medium)
            if food.isAllergen {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2).foregroundStyle(.orange)
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
