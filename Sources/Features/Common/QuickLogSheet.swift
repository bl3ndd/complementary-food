import SwiftUI

/// Быстрая запись кормления с главной: выбрать продукт → открыть лог кормления.
struct QuickLogSheet: View {
    let child: Child
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var picked: Food?

    private let catalog = FoodCatalog.shared

    var body: some View {
        NavigationStack {
            List {
                ForEach(catalog.search(search)) { food in
                    Button { picked = food } label: {
                        HStack(spacing: 10) {
                            FoodIcon(food: food, size: 30)
                            Text(food.localizedName).foregroundStyle(.primary)
                        }
                    }
                }
            }
            .searchable(text: $search, prompt: Text("Поиск продукта"))
            .navigationTitle("Записать кормление")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
            }
            .sheet(item: $picked, onDismiss: { dismiss() }) { food in
                LogFeedingSheet(food: food, child: child, mode: .feeding)
            }
        }
    }
}
