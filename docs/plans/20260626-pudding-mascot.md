# План — маскот «Pudding»

## Overview

Вводим бренд-маскота **Pudding** — мягкий «дрожащий» пудинг-персонаж — как эмоциональный акцент приложения. Цель не «сделать детское приложение», а снизить тревожность родителя (прикорм = стресс: аллергены, «рано/поздно», реакции) и дать бренду лицо. Маскот появляется **точечно**, в эмоциональных точках: пустые состояния, онбординг-гид, шапки-сводки и момент успеха при завершении ввода продукта. В рабочих экранах (каталог, история, статусы) маскота нет — там чистая взрослая вёрстка.

Технически маскот — это **векторный персонаж, нарисованный средствами SwiftUI** (формы + лицо по «настроению»), а не картинка. Так он масштабируется, анимируется и не требует заказа графики прямо сейчас.

**Вне скоупа (и почему):**
- **Заказная иллюстрация/3D-арт маскота** — нужен дизайнер; сейчас шиппим SwiftUI-плейсхолдер, заменим позже.
- **Иконка приложения** — отдельная история с экспортом размеров и графикой; делаем, когда будет финальный арт.
- **Сложная анимация (Lottie / спрайты)** — только лёгкий idle-wobble на SwiftUI; полноценная анимация позже.
- **Переименование таргета/bundle id** (`Prikorm` → `Pudding`) — рискованно (схема, тест-таргет, обязательный `xcodegen`); рабочее имя уже задано через `CFBundleDisplayName`.

## Context

- **Files involved:**
  - Create: `Sources/Features/Common/Mascot.swift` — `struct Mascot: View` (SwiftUI-рисованный пудинг), `enum MascotMood`, чистые хелперы выбора настроения
  - Create: `Tests/MascotTests.swift` — тесты на чистую логику `MascotMood`
  - Modify: `Sources/Features/Dashboard/DashboardView.swift` — `emptyState` (сейчас `🍽️`) и `heroCard` (сейчас `Text("👶")`) переводим на `Mascot`
  - Modify: `Sources/Features/Calendar/CalendarView.swift` — `emptyState` (сейчас `📅`)
  - Modify: `Sources/Features/Calendar/DayDetailView.swift` — `emptyState` (сейчас `🌙`)
  - Modify: `Sources/Features/Allergens/AllergensView.swift` — `summaryCard` (сейчас `🔔`/`✅`) реагирует настроением маскота на `dueCount`
  - Modify: `Sources/Features/Onboarding/OnboardingView.swift` — `haloEmoji(_:color:)` → маскот-гид; бренд «Pudding» в шаге 0
  - Modify: `Sources/Features/Catalog/FoodDetailView.swift` — момент успеха в `complete()` (маскот-поздравление)
  - Modify: `project.yml` — ничего нового в синтаксисе; но `Mascot.swift` и `MascotTests.swift` попадают в folder-references → нужен `xcodegen generate`
- **Related patterns:** скруглённая мультяшная тема (`Theme.accentGradient`, `Theme.softGradient`, `cartoonCard`), общие компоненты (`EmojiAvatar`, `ProgressRingOnColor`, `PillButton`), `AppBackground`. Маскот живёт рядом с ними в `Common/`.
- **Dependencies:** только SwiftUI/SwiftData (системные, без сторонних пакетов). После добавления файлов — пользователь сам гоняет `xcodegen generate` и сборку (CLAUDE.md: билд/тесты — на пользователе).

## Development Approach

- Подход: Regular (сначала код, потом тесты). Тест-таргет `PrikormTests` уже есть в `project.yml`, гоняется через схему `Prikorm`.
- **Тестируемое vs нет:** сам рисунок и анимация маскота (`Shape`/`View`) юнит-тестами осмысленно не покрыть — это валидируется self-launch. Покрываем **чистую логику настроения**: `MascotMood.forProgress(introduced:total:)` и `MascotMood.forDue(_:)` — детерминированные функции без `ModelContext`. Это держит планку ≥80% покрытия логики (CLAUDE.md).
- **Плейсхолдеры:** сам персонаж — временный SwiftUI-рисунок; финальный арт + иконка приходят позже (см. Out of scope).

## Implementation Steps

### Task 1: Компонент маскота + логика настроения

Files:

- Create: `Sources/Features/Common/Mascot.swift`
- Create: `Tests/MascotTests.swift`
- Modify: `project.yml` (только напоминание про `xcodegen generate` после добавления файлов)

[ ] Объявить `enum MascotMood: CaseIterable { case neutral, happy, cheer, curious, sleepy, worried }`
[ ] Добавить чистые хелперы: `static func forProgress(introduced: Int, total: Int) -> MascotMood` (0 или total==0 → `.curious`; всё введено → `.cheer`; иначе → `.happy`) и `static func forDue(_ count: Int) -> MascotMood` (0 → `.happy`; иначе → `.worried`)
[ ] Реализовать `struct Mascot: View` — тело пудинга формами SwiftUI (купол `UnevenRoundedRectangle`/`Ellipse` + карамельная «шапка», цвет из `Theme.accentGradient`/`Theme.softGradient`), глаза-кружки и рот/брови, меняющиеся по `mood`; параметры `mood: MascotMood = .neutral`, `size: CGFloat = 96`
[ ] Добавить лёгкий idle-wobble (небольшой `rotationEffect`/`scaleEffect` с `.easeInOut.repeatForever`), включаемый флагом `animated: Bool = true`
[ ] Добавить SwiftUI `#Preview` со всеми настроениями (сетка по `MascotMood.allCases`)
[ ] Написать тесты (`MascotTests`): таблица истинности `forProgress` (0/частично/всё/`total==0`) и `forDue` (0 → happy, >0 → worried); проверить, что `MascotMood.allCases` не пуст
[ ] run project test suite — must pass before Task 2

### Task 2: Маскот в пустых состояниях

Files:

- Modify: `Sources/Features/Dashboard/DashboardView.swift`
- Modify: `Sources/Features/Calendar/CalendarView.swift`
- Modify: `Sources/Features/Calendar/DayDetailView.swift`

[ ] `DashboardView.emptyState`: заменить `Text("🍽️")` на `Mascot(mood: .happy)`; текст «Всё под контролем!» оставить
[ ] `CalendarView.emptyState`: заменить `Text("📅")` на `Mascot(mood: .curious)`; текст «Пока пусто» оставить
[ ] `DayDetailView.emptyState`: заменить `Text("🌙")` на `Mascot(mood: .sleepy)`; текст «В этот день ничего не давали» оставить
[ ] Leaf-UI без тестируемой логики — отдельные тесты не пишем (рисунок проверяется self-launch); прогнать набор, чтобы ничего не сломалось в сборке
[ ] run project test suite — must pass before Task 3

### Task 3: Маскот-гид в онбординге + бренд «Pudding»

Files:

- Modify: `Sources/Features/Onboarding/OnboardingView.swift`

[ ] Заменить `haloEmoji(_:color:)` на маскота: оставить тот же мягкий ореол-круг, но внутрь поставить `Mascot` вместо `Text(emoji)`; настроение по шагу — welcome `.happy`, дисклеймер `.worried`, ребёнок `.curious`, методика `.neutral`
[ ] В шаге 0 (`stepView` welcome) заголовок сделать брендовым: «Pudding» + подзаголовок «Дневник прикорма» (сейчас заголовок = «Дневник прикорма»)
[ ] Сохранить существующую логику шагов/кнопок (`next()`, `canProceed`, `finish()`) без изменений
[ ] Leaf-UI — отдельных тестов нет; прогнать набор на отсутствие регрессий
[ ] run project test suite — must pass before Task 4

### Task 4: Маскот в шапках-сводках (реакция на состояние)

Files:

- Modify: `Sources/Features/Dashboard/DashboardView.swift`
- Modify: `Sources/Features/Allergens/AllergensView.swift`

[ ] `DashboardView.heroCard`: заменить `Text("👶")` на `Mascot(mood: MascotMood.forProgress(introduced: introducedCount, total: catalog.foods.count), size: 56)` — маскот «радуется» по мере прогресса
[ ] `AllergensView.summaryCard`: заменить эмодзи `🔔`/`✅` на `Mascot(mood: MascotMood.forDue(dueCount), size: 48)` — `worried`, когда что-то просрочено, иначе `happy`
[ ] Убедиться, что маскот на градиентном фоне читается (белый ободок/контраст), при необходимости подложить полупрозрачный круг как сейчас
[ ] Логика настроения уже покрыта тестами из Task 1; новых тестов не требуется (UI-привязка проверяется self-launch)
[ ] run project test suite — must pass before Task 5

### Task 5: Момент успеха при завершении ввода

Files:

- Modify: `Sources/Features/Catalog/FoodDetailView.swift`

[ ] Добавить `@State private var showCheer = false`; в `complete()` после `service.completeIntroduction(food)` выставлять `showCheer = true`
[ ] Показать кратковременный оверлей-поздравление: `Mascot(mood: .cheer)` + подпись «Продукт введён! 🎉» поверх экрана, авто-скрытие через ~1.5 c (`.task`/`DispatchQueue` с анимацией), не блокируя навигацию
[ ] Не трогать доменную логику (`FeedingService.completeIntroduction`, `refresh()`) — только визуальный фидбэк
[ ] Leaf-UI/визуальный фидбэк — юнит-тестов нет; проверяется self-launch
[ ] run project test suite — must pass before Task 6

### Task 6: Verify acceptance criteria

[ ] запустить полный набор тестов (схема `Prikorm`, прогон пользователем) — зелёный
[ ] self-launch: маскот виден и адекватен по настроению — пустые состояния (Сегодня/Календарь/День), онбординг (4 шага), герой «Сегодня» (меняется с прогрессом), сводка аллергенов (`worried` при просрочке), поздравление при «Ввёл успешно»
[ ] подтвердить, что в рабочих экранах (Каталог, История, статусы продуктов) маскота НЕТ — вёрстка чистая
[ ] под иконкой отображается «Pudding» (`CFBundleDisplayName`)
[ ] новая логика (`MascotMood.forProgress` / `forDue`) покрыта юнит-тестами

### Task 7: Update documentation

[ ] `SPEC.md` §10 (дизайн/тон) — описать маскота Pudding, его роль и правило «только в эмоциональных точках, не в рабочих экранах»
[ ] `README.md` — упомянуть рабочее имя «Pudding» и компонент `Mascot`
[ ] `CLAUDE.md` — добавить `Mascot` в список общих компонентов `Features/Common`; зафиксировать, что финальный арт/иконка — вне текущего скоупа
[ ] напомнить пользователю про `xcodegen generate` (добавлены `Mascot.swift`, `MascotTests.swift`)
