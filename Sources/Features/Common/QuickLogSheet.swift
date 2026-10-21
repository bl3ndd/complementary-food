import SwiftUI

/// Быстрая запись кормления с главной: выбрать продукт → открыть лог кормления.
struct QuickLogSheet: View {
    let child: Child
    var mode: LogFeedingSheet.Mode = .feeding
    var initialDate: Date = Date()
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var picked: Food?

    var body: some View {
        NavigationStack {
            // Для реакции сверху — что давали сегодня: её отмечают по свежим следам.
            FoodPickerList(childId: child.id, search: $search, todayFirst: mode == .reaction,
                           onCustomAdded: { picked = $0 }) { food, state in
                Button { picked = food } label: { FoodPickerRow(food: food, state: state) }
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
        .cozySheet()
    }
}
