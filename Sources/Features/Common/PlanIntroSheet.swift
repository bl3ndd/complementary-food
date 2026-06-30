import SwiftUI
import SwiftData

/// Лист планирования ввода: выбрать дату (сегодня/будущее) и продукт. Создаёт
/// запланированную запись (`FoodLog.planned`). Используется с Главной и из Календаря.
struct PlanIntroSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<FoodLog> { $0.planned }) private var plannedLogs: [FoodLog]
    @State private var search = ""
    @State private var date: Date
    @State private var dupAlert = false

    private let catalog = FoodCatalog.shared

    init(initialDate: Date = Date()) {
        _date = State(initialValue: initialDate)
    }

    private var minDate: Date { Calendar.current.startOfDay(for: Date()) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DatePicker(selection: $date, in: minDate..., displayedComponents: .date) {
                    Label("Когда", systemImage: "calendar").font(.subheadline.weight(.medium))
                }
                .tint(Theme.accent)
                .padding(.horizontal).padding(.top, 8).padding(.bottom, 4)

                List {
                    ForEach(catalog.search(search)) { food in
                        Button { plan(food) } label: {
                            HStack(spacing: 10) {
                                FoodIcon(food: food, size: 30)
                                Text(food.localizedName).foregroundStyle(.primary)
                                if isPlanned(food) {
                                    Spacer()
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Theme.lilac)
                                }
                            }
                        }
                    }
                }
                .searchable(text: $search, prompt: Text("Поиск продукта"))
            }
            .navigationTitle("Запланировать ввод")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
            }
            .alert("Уже запланировано", isPresented: $dupAlert) {
                Button("Ок", role: .cancel) {}
            } message: {
                Text("Этот продукт уже запланирован на выбранную дату.")
            }
        }
    }

    /// Этот продукт уже запланирован на выбранную дату? (дедуп, чтобы не плодить копии).
    private func isPlanned(_ food: Food) -> Bool {
        let cal = Calendar.current
        return plannedLogs.contains {
            $0.foodId == food.id && cal.isDate($0.date, inSameDayAs: date)
        }
    }

    private func plan(_ food: Food) {
        guard !isPlanned(food) else { dupAlert = true; return }
        context.insert(FoodLog(foodId: food.id, date: date, type: .intro, planned: true))
        try? context.save()
        dismiss()
    }
}
