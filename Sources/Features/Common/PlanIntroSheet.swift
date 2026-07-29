import SwiftUI
import SwiftData

/// Лист планирования ввода: выбрать дату (сегодня/будущее) и **сколько угодно
/// продуктов** — за день ребёнок ест не один продукт, планировать по одному было
/// мучением. Создаёт запланированные записи (`FoodLog.planned`).
/// Используется с Главной и из Календаря.
struct PlanIntroSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<FoodLog> { $0.planned }) private var plannedLogs: [FoodLog]
    @State private var search = ""
    @State private var date: Date
    /// Отмеченные в этом сеансе продукты (id). Уже запланированные на эту дату
    /// показываются отдельной галочкой и не выбираются повторно.
    @State private var picked: Set<String> = []

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
                        row(food)
                    }
                }
                .searchable(text: $search, prompt: Text("Поиск продукта"))
            }
            .navigationTitle("Запланировать ввод")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
            }
            // Подтверждение — крупной кнопкой снизу: она видна и когда открыт поиск
            // (тулбар в этот момент занят строкой поиска), и сразу показывает,
            // сколько продуктов отмечено.
            .safeAreaInset(edge: .bottom) {
                if !picked.isEmpty {
                    BigButton(title: "Готово") { planPicked() }
                        .padding(.horizontal).padding(.vertical, 8)
                        .background(
                            LinearGradient(colors: [Theme.card.opacity(0), Theme.card.opacity(0.95)],
                                           startPoint: .top, endPoint: .bottom)
                                .ignoresSafeArea(edges: .bottom)
                        )
                }
            }
            // Смена даты меняет и «уже запланировано» — выбор сбрасываем, чтобы
            // случайно не перенести галочки на другой день.
            .onChange(of: date) { picked.removeAll() }
        }
        .cozySheet()
    }

    private func row(_ food: Food) -> some View {
        let already = isPlanned(food)
        let selected = picked.contains(food.id)
        return Button {
            guard !already else { return }
            Haptics.select()
            if selected { picked.remove(food.id) } else { picked.insert(food.id) }
        } label: {
            HStack(spacing: 10) {
                FoodIcon(food: food, size: 30)
                Text(food.localizedName)
                    .foregroundStyle(already ? .secondary : .primary)
                Spacer()
                if already {
                    // Уже в планах на этот день — повторно не добавляем.
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.lilac)
                } else {
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selected ? Theme.accent : .secondary)
                }
            }
        }
        .listRowBackground(Theme.card)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    /// Этот продукт уже запланирован на выбранную дату? (дедуп, чтобы не плодить копии).
    private func isPlanned(_ food: Food) -> Bool {
        let cal = Calendar.current
        return plannedLogs.contains {
            $0.foodId == food.id && cal.isDate($0.date, inSameDayAs: date)
        }
    }

    private func planPicked() {
        guard !picked.isEmpty else { return }
        Haptics.success()
        for id in picked {
            context.insert(FoodLog(foodId: id, date: date, type: .intro, planned: true))
        }
        try? context.save()
        dismiss()
    }
}
