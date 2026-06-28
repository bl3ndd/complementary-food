import SwiftUI
import SwiftData

/// Редактирование заметки записи журнала (п.20). Пишет прямо в `FoodLog.note`.
struct EditNoteSheet: View {
    @Bindable var log: FoodLog
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var text: String

    init(log: FoodLog) {
        self.log = log
        _text = State(initialValue: log.note ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Заметка") {
                    TextField("Например: съел половину", text: $text, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle("Заметка")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") {
                        log.note = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : text
                        try? context.save()
                        dismiss()
                    }
                }
            }
        }
    }
}
