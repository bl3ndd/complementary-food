import SwiftUI
import SwiftData

/// Лист записи кормления: вкусовая оценка + реакция + заметка (SPEC §5).
struct LogFeedingSheet: View {
    let food: Food
    let child: Child

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var liking: Liking?
    @State private var reaction: ReactionType = .none
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Как зашло?") {
                    HStack { Spacer(); LikingPicker(selection: $liking); Spacer() }
                        .padding(.vertical, 4)
                }

                Section("Реакция") {
                    Picker("Реакция", selection: $reaction) {
                        ForEach(ReactionType.allCases, id: \.self) { r in
                            Text(r.title).tag(r)
                        }
                    }
                    .pickerStyle(.menu)
                    if reaction != .none {
                        Label("Реакция переведёт продукт в «паузу», а если он уже введён — в «аллергию».",
                              systemImage: "exclamationmark.triangle")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }

                Section("Заметка") {
                    TextField("Например: съел половину", text: $note, axis: .vertical)
                }
            }
            .navigationTitle(food.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { save() }
                }
            }
        }
    }

    private func save() {
        let service = FeedingService(context: context)
        service.logFeeding(food,
                           liking: liking,
                           reaction: reaction == .none ? nil : reaction)
        if !note.isEmpty {
            // заметку кладём отдельной записью-комментарием, чтобы не усложнять API
            context.insert(FoodLog(foodId: food.id, note: note))
            try? context.save()
        }
        NotificationManager.shared.refresh(context: context, profile: child.feedingProfile)
        dismiss()
    }
}
