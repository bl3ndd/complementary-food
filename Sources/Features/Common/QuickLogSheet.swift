import SwiftUI

/// Быстрая запись кормления с главной: выбрать продукт → открыть лог кормления.
struct QuickLogSheet: View {
    let child: Child
    var mode: LogFeedingSheet.Mode = .feeding
    var initialDate: Date = Date()
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
            .navigationTitle(mode == .feeding ? Text("Записать кормление") : Text("Записать реакцию"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
            }
            .sheet(item: $picked) { food in
                // Закрываем быстрый лист только после сохранения; по «Отмена»
                // возвращаемся к списку продуктов (picked сбросится сам).
                LogFeedingSheet(food: food, child: child, mode: mode,
                                initialDate: initialDate, onSaved: { dismiss() })
            }
        }
    }
}
