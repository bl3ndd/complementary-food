import SwiftUI
import SwiftData

/// Онбординг (SPEC §12): Welcome → Дисклеймер → Ребёнок → План → Что уже ввели.
/// Дисклеймер стоит ДО ввода данных ребёнка: человек читает «мы не медицинский
/// совет» прежде, чем что-то заполнять (App Review 1.4.1). Тот же текст всегда
/// доступен в Профиле → «О приложении».
/// Разрешение на уведомления просим сразу после онбординга, в MainTabView.
struct OnboardingView: View {
    @Environment(\.modelContext) private var context

    @State private var step = 0
    @State private var name = ""
    @State private var birthDate = Calendar.current.date(byAdding: .month, value: -5, to: Date()) ?? Date()
    /// Черновик для настроек «своего плана» (вставляется в контекст только в finish).
    @State private var draftChild = Child()
    /// id продуктов, уже введённых до начала работы с приложением (п.23).
    @State private var introduced: Set<String> = []
    /// Поиск на шаге «что уже ввели».
    @State private var search = ""

    private let catalog = FoodCatalog.shared
    private let lastStep = 4

    var body: some View {
        VStack(spacing: 16) {
            Group {
                switch step {
                case 0:  centered(welcomeStep)
                case 1:  centered(disclaimerStep)
                case 2:  centered(childStep)
                case 3:  planStep
                default: alreadyStep
                }
            }
            .frame(maxHeight: .infinity)
            button
            if step > 0 {
                Button("Назад") { withAnimation { step -= 1 } }
                    .font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
        .padding()
        .background(AppBackground())
    }

    private func centered<V: View>(_ view: V) -> some View {
        VStack {
            Spacer(minLength: 0)
            view.multilineTextAlignment(.center)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Шаги

    private var welcomeStep: some View {
        VStack(spacing: 16) {
            haloMascot(.happy)
            Text("Pudding").font(.largeTitle.bold())
            Text("Дневник прикорма без паники: что вводить, когда и не забыть про аллергены.")
                .foregroundStyle(.secondary).padding(.horizontal)
        }
    }

    /// Медицинский дисклеймер — перед вводом данных ребёнка.
    private var disclaimerStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 52)).foregroundStyle(Theme.accent)
            Text("Прежде чем начать").font(.title2.bold())
            Text(Disclaimer.medical)
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 4)
    }

    private var childStep: some View {
        VStack(spacing: 16) {
            haloMascot(.curious, color: Theme.sky)
            Text("О ребёнке").font(.title.bold())
            VStack(spacing: 4) {
                TextField("Имя малыша", text: $name)
                    .multilineTextAlignment(.center)
                    .font(.headline)
                    .padding(.vertical, 12)
                Divider()
                HStack {
                    Text("Дата рождения").foregroundStyle(.secondary)
                    Spacer()
                    DatePicker("", selection: $birthDate, in: ...Date(),
                               displayedComponents: .date)
                        .labelsHidden()
                }
                .padding(.vertical, 6)
            }
            .cartoonCard()
        }
    }

    private var planStep: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text("Свой план прикорма").font(.title2.bold())
                Text("Настрой старт, окна наблюдения и аллергены. Можно изменить позже.")
                    .font(.footnote).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                PlanDetailEditor(child: draftChild)
            }
            .padding(.top, 28)
            .padding(.bottom, 8)
            .padding(.horizontal, 3)
        }
        .scrollIndicators(.hidden)
    }

    /// Шаг «что уже ввели». Раньше был плоской простынёй из 71 продукта — теперь
    /// поиск + группировка по категориям, чтобы не скроллить полэкрана на первом запуске.
    private var alreadyStep: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("Что уже ввели?").font(.title2.bold())
                Text("Отметь продукты, которые малыш уже пробовал без проблем. Можно пропустить.")
                    .font(.footnote).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                searchField

                let results = catalog.search(search)
                ForEach(FoodCategory.allCases, id: \.self) { category in
                    let foods = results.filter { $0.category == category }
                    if !foods.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(category.title)
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8),
                                                GridItem(.flexible(), spacing: 8)], spacing: 8) {
                                ForEach(foods) { food in introducedChip(food) }
                            }
                        }
                        .padding(.top, 4)
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 3)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Поиск продукта", text: $search)
                .autocorrectionDisabled()
            if !search.isEmpty {
                Button { search = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .accessibilityLabel(Text("Поиск продукта"))
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Theme.card, in: Capsule())
        .overlay(Capsule().stroke(Theme.hairline, lineWidth: 1))
    }

    private func introducedChip(_ food: Food) -> some View {
        let on = introduced.contains(food.id)
        return Button {
            Haptics.select()
            withAnimation(.snappy) {
                if on { introduced.remove(food.id) } else { introduced.insert(food.id) }
            }
        } label: {
            HStack(spacing: 8) {
                FoodIcon(food: food, size: 32)
                Text(food.localizedName).font(.subheadline.weight(.semibold))
                    .foregroundStyle(on ? Theme.accent : .primary).lineLimit(1)
                Spacer(minLength: 0)
                if on {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.footnote).foregroundStyle(Theme.accent)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(on ? Theme.accent.opacity(0.14) : Theme.fill,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(on ? Theme.accent.opacity(0.5) : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    /// Маскот-гид в мягком цветном круге.
    private func haloMascot(_ mood: MascotMood, color: Color = Theme.accent) -> some View {
        Mascot(mood: mood, size: 96)
            .gentleBob()
            .frame(width: 132, height: 132)
            .background(Theme.softGradient(color), in: Circle())
            .overlay(Circle().stroke(Theme.cardStroke, lineWidth: 1.5))
            .shadow(color: color.opacity(0.25), radius: 16, y: 8)
    }

    // MARK: - Кнопка / переходы

    /// Имя необязательно (SPEC §12) — двигаться можно всегда.
    private var canProceed: Bool { true }

    /// На шаге дисклеймера кнопка читается как подтверждение, а не «дальше».
    private var buttonTitle: String {
        if step >= lastStep { return String(localized: "Погнали!") }
        return step == 1 ? String(localized: "Понятно") : String(localized: "Далее")
    }

    private var button: some View {
        Button(action: next) {
            HStack(spacing: 8) {
                Text(buttonTitle)
                    .font(.headline.bold())
                if step >= lastStep {
                    OpenMojiIcon(asset: "ui_rocket", fallback: "🚀", size: 22)
                }
            }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundStyle(.white)
                .background {
                    if canProceed { Theme.accentGradient } else { Color.gray.opacity(0.4) }
                }
                .clipShape(Capsule())
                .shadow(color: Theme.accent.opacity(canProceed ? 0.35 : 0), radius: 10, y: 5)
        }
        .buttonStyle(BouncyButtonStyle())
        .disabled(!canProceed)
    }

    private func next() {
        if step >= lastStep {
            finish()
        } else {
            withAnimation { step += 1 }
        }
    }

    private func finish() {
        // AppRouter — синглтон: после сброса из Профиля таб остался бы .profile.
        // Свежий старт всегда открывается на главной.
        AppRouter.shared.selectedTab = .today
        let child = Child(name: name.trimmingCharacters(in: .whitespaces),
                          birthDate: birthDate, feedingProfileId: FeedingProfile.customId)
        child.customStartAgeMonths = draftChild.customStartAgeMonths
        child.customObservationDaysRegular = draftChild.customObservationDaysRegular
        child.customObservationDaysAllergen = draftChild.customObservationDaysAllergen
        child.customAllergenFrequencyPerWeek = draftChild.customAllergenFrequencyPerWeek
        child.customAllergenGroupsRaw = draftChild.customAllergenGroupsRaw
        child.clampCustom()
        context.insert(child)
        if !introduced.isEmpty {
            let foods = introduced.compactMap { catalog.food(id: $0) }
            FeedingService(context: context).markIntroduced(foods)
        }
        try? context.save()
    }
}
