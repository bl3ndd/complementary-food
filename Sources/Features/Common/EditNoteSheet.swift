import SwiftUI
import SwiftData

/// Редактирование заметки записи журнала (п.20). Пишет прямо в `FoodLog.note`.
struct EditNoteSheet: View {
    @Bindable var log: FoodLog
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool
    @State private var text: String

    init(log: FoodLog) {
        self.log = log
        _text = State(initialValue: log.note ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Заметка").font(.headline)
                    TextField("Например: съел половину", text: $text, axis: .vertical)
                        .lineLimit(3...8)
                        .focused($focused)
                        .padding(12)
                        .background(Color.black.opacity(0.03),
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .cartoonCard()
                .padding()
            }
            .background(AppBackground())
            .scrollDismissesKeyboard(.interactively)
            .hideKeyboardOnTap()
            .navigationTitle("Заметка")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { save() }
                }
            }
        }
        .onAppear { focused = true }
    }

    private func save() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        log.note = trimmed.isEmpty ? nil : text
        try? context.save()
        dismiss()
    }
}
