import SwiftUI
import SwiftData

/// Онбординг (SPEC §12): Welcome → Дисклеймер → Где хранить → Ребёнок → План → Что уже ввели.
/// Дисклеймер стоит ДО ввода данных ребёнка: человек читает «мы не медицинский
/// совет» прежде, чем что-то заполнять (App Review 1.4.1). Тот же текст всегда
/// доступен в Профиле → «О приложении».
/// «Где хранить» — тоже до данных: копия в iCloud только с явного согласия, и там же
/// отдельная кнопка восстановления, чтобы после переустановки не завести второй дневник.
/// Разрешение на уведомления просим сразу после онбординга, в MainTabView.
struct OnboardingView: View {
    /// Зовётся с созданным ребёнком. Онбординг используется и для ПЕРВОГО входа
    /// (тогда колбэк не нужен: `RootView` сам покажет приложение), и для
    /// добавления следующего ребёнка из Профиля — там вызывающему нужно сделать
    /// нового активным и закрыть лист.
    var onCreated: (Child) -> Void = { _ in }
    /// Добавление следующего ребёнка из Профиля: приветствие и дисклеймер человек
    /// уже видел — начинаем сразу с «О ребёнке», с «Отменой», без смены таба.
    var addingChild = false
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var step = 0
    @State private var name = ""
    @State private var birthDate = Calendar.current.date(byAdding: .month, value: -5, to: Date()) ?? Date()
    /// Черновик для настроек «своего плана» (вставляется в контекст только в finish).
    @State private var draftChild = Child()
    /// id продуктов, уже введённых до начала работы с приложением (п.23).
    @State private var introduced: Set<String> = []
    /// Поиск на шаге «что уже ввели».
    @State private var search = ""
    @ObservedObject private var store = DiaryStore.shared
    /// Выбор на шаге «Где хранить». Пусто, пока человек не нажал сам.
    @State private var storage: CloudSync.Choice?
    @State private var cloudAvailable = true
    /// Ждём дневник из iCloud. Как только приедет ребёнок, `RootView` сам уйдёт в приложение.
    @State private var restoring = false
    @State private var restoreSlow = false

    private let catalog = FoodCatalog.shared
    private let lastStep = 5
    private static let storageStep = 2
    private static let childStep = 3
    private var firstStep: Int { addingChild ? Self.childStep : 0 }

    init(addingChild: Bool = false, onCreated: @escaping (Child) -> Void = { _ in }) {
        self.addingChild = addingChild
        self.onCreated = onCreated
        _step = State(initialValue: addingChild ? Self.childStep : 0)
        // После сброса данных выбор уже сделан — показываем его, а не пустой шаг.
        let current = DiaryStore.shared.choice
        _storage = State(initialValue: current == .undecided ? nil : current)
    }

    var body: some View {
        VStack(spacing: 16) {
            // Сколько шагов осталось — пять экранов подряд без ориентира утомляют.
            HStack(spacing: 6) {
                ForEach(firstStep...lastStep, id: \.self) { i in
                    Capsule()
                        .fill(i <= step ? Theme.accent : Theme.hairline)
                        .frame(width: i == step ? 18 : 6, height: 6)
                }
            }
            .animation(.snappy, value: step)
            .accessibilityHidden(true)
            .padding(.top, 4)
            Group {
                switch step {
                case 0:  centered(welcomeStep)
                case 1:  centered(disclaimerStep)
                case 2:  centered(storageStep)
                case 3:  centered(childStep)
                case 4:  planStep
                default: alreadyStep
                }
            }
            .frame(maxHeight: .infinity)
            if !restoring { button }
            if step > firstStep && !restoring {
                Button("Назад") { withAnimation { step -= 1 } }
                    .font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
        .overlay(alignment: .topLeading) {
            if addingChild {
                Button("Отмена") { dismiss() }
                    .font(.body.weight(.medium)).tint(Theme.accent)
                    .padding(.top, 4)
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
            Text("Дневник прикорма: что давали, как зашло, были ли реакции.")
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

    private var storageStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "icloud")
                .font(.system(size: 52)).foregroundStyle(Theme.accent)
            Text("Где хранить дневник").font(.title2.bold())
            if restoring {
                restoringView
            } else {
                VStack(spacing: 10) {
                    storageOption(.on, icon: "icloud", title: "На телефоне и в iCloud",
                                  detail: "Дневник переживёт смену или потерю телефона. Копия лежит в твоём личном iCloud, у нас к ней доступа нет.")
                        .disabled(!cloudAvailable)
                        .opacity(cloudAvailable ? 1 : 0.5)
                    storageOption(.off, icon: "iphone", title: "Только на этом телефоне",
                                  detail: "Никаких копий. Если удалить приложение или потерять телефон, записи пропадут.")
                }
                if !cloudAvailable {
                    Text("На этом iPhone не выполнен вход в iCloud. Войди в Настройках, чтобы хранить копию.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                VStack(spacing: 4) {
                    Text("Уже вёл дневник в Pudding?")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("Восстановить дневник из iCloud", action: restore)
                        .font(.subheadline.weight(.semibold)).tint(Theme.accent)
                        .disabled(!cloudAvailable)
                        .accessibilityIdentifier("onboarding.restore")
                }
                .padding(.top, 4)
            }
        }
        .task {
            // UI-тесты — in-memory без облака: аккаунт не спрашиваем.
            if !UITestSupport.isActive { cloudAvailable = await CloudSync.accountAvailable() }
        }
    }

    private func storageOption(_ choice: CloudSync.Choice, icon: String,
                               title: LocalizedStringKey, detail: LocalizedStringKey) -> some View {
        let on = storage == choice
        return Button {
            Haptics.select()
            withAnimation(.snappy) { storage = choice }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.title3).foregroundStyle(Theme.accent)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.subheadline.weight(.bold)).foregroundStyle(.primary)
                    Text(detail).font(.footnote).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(on ? Theme.accent : Theme.hairline)
            }
            .padding(14)
            .background(on ? Theme.accent.opacity(0.10) : Theme.card,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(on ? Theme.accent.opacity(0.5) : Theme.hairline, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
        .accessibilityIdentifier("onboarding.storage.\(choice.rawValue)")
    }

    private var restoringView: some View {
        VStack(spacing: 14) {
            ProgressView().controlSize(.large)
            Text("Ищем дневник в iCloud…").font(.headline)
            Text(restoreSlow
                 ? String(localized: "Пока ничего не нашли. Большой дневник может скачиваться пару минут.")
                 : String(localized: "Не закрывай приложение — записи и фото скачиваются из твоего iCloud."))
                .font(.footnote).foregroundStyle(.secondary)
            if restoreSlow {
                GhostButton(title: "Начать новый дневник") {
                    withAnimation { restoring = false; step = Self.childStep }
                }
            }
        }
        .padding(.top, 8)
    }

    /// Восстановление = синк включён + ждём. Сам переход в приложение делает `RootView`,
    /// когда из iCloud приедет ребёнок.
    private func restore() {
        storage = .on
        store.choose(.on, reopen: true)
        withAnimation { restoring = true }
        Task {
            try? await Task.sleep(for: .seconds(25))
            withAnimation { restoreSlow = true }
        }
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
                Text("Твой план прикорма").font(.title2.bold())
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
                .accessibilityLabel(Text("Очистить"))
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
    }

    // MARK: - Кнопка / переходы

    /// Имя необязательно (SPEC §12). Ждём только явного выбора, где хранить.
    private var canProceed: Bool { step != Self.storageStep || storage != nil }

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
        }
        .buttonStyle(BouncyButtonStyle())
        .disabled(!canProceed)
    }

    private func next() {
        if step >= lastStep {
            finish()
        } else {
            // Дневник ещё пустой — переоткрыть стор можно прямо сейчас.
            if step == Self.storageStep, let storage { store.choose(storage, reopen: true) }
            withAnimation { step += 1 }
        }
    }

    private func finish() {
        // AppRouter — синглтон: после сброса из Профиля таб остался бы .profile.
        // Свежий старт всегда открывается на главной.
        if !addingChild { AppRouter.shared.selectedTab = .today }
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
            FeedingService(context: context, childId: child.id).markIntroduced(foods)
        }
        try? context.save()
        onCreated(child)
    }
}
