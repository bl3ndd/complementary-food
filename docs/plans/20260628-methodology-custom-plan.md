# План — наглядный выбор методики, смягчённый дисклеймер, свой план прикорма

## Overview

Три связанные правки вокруг методики прикорма:
1. **Наглядный выбор методики** — сейчас при выборе видно только название. Показать
   все параметры пресета (старт, окно наблюдения, частота аллергена, список
   аллергенов, источник) карточками — и в онбординге, и в профиле.
2. **Смягчить дисклеймер** — убрать пугающий отдельный шаг онбординга с галкой
   «беру ответственность». Оставить лёгкую строку в «О приложении» (уже есть) и
   мягкую сноску на welcome-экране. Держим App Review 1.4.1, но ненавязчиво.
3. **Свой план прикорма** — пользователь создаёт собственную методику, если пресеты
   не подходят: настраивает **возраст старта, окно наблюдения, частоту поддержки
   аллергена и список аллергенов**.

**Вне скоупа (и почему):**
- **Несколько детей / несколько своих планов** — в MVP один Child, один custom; модель
  уже готова к расширению без миграции (SPEC §3).
- **Pro-гейт на custom** — монетизации пока нет; свой план бесплатен для всех. Когда
  появится StoreKit — навесим гейт отдельно (см. пример в `create-plan`).
- **Клиническая валидация custom-значений** — это осознанный выбор пользователя; даём
  разумные границы (range) и мягкий дисклеймер, не блокируем.

## Context

- **Files involved:**
  - Modify: `Sources/Models/FeedingProfile.swift` — добавить `customId`, билдер
    `custom(from:)`, источник/оговорку для custom
  - Modify: `Sources/Models/Child.swift` — CloudKit-safe поля custom-параметров
    (`customStartAgeMonths`, `customObservationDays`, `customAllergenFrequencyPerWeek`,
    `customAllergenGroupsRaw`) с дефолтами от ВОЗ; `feedingProfile` возвращает custom,
    когда `feedingProfileId == FeedingProfile.customId`
  - Modify: `Sources/Models/Enums.swift` — `AllergenGroup` уже `CaseIterable`; ничего
    нового, используем для мультивыбора
  - Create: `Sources/Features/Common/MethodologyCard.swift` — переиспользуемая карточка
    методики (параметры + источник + выбор) для онбординга и профиля
  - Create: `Sources/Features/Common/CustomPlanEditor.swift` — редактор своего плана
    (степперы + мультивыбор аллергенов); используется в онбординге и профиле
  - Modify: `Sources/Features/Onboarding/OnboardingView.swift` — убрать disclaimer-шаг
    и `acceptedDisclaimer`-гейт; методика-шаг на `MethodologyCard` + опция «Свой план»
  - Modify: `Sources/Features/Profile/ProfileView.swift` — секция методики на
    `MethodologyCard`; добавить Custom + редактор; сохранять custom-поля
  - Modify: `Sources/App/Disclaimer.swift` — добавить короткую `welcome`-строку
  - Tests: `Tests/FeedingProfileTests.swift`, `Tests/ModelTests.swift` — custom билдер,
    round-trip полей, fallback
- **Related patterns:** `FeedingProfile` уже несёт `source/sourceURL/caveat`;
  параметры (`startAgeMonths`, `observationDays`, `allergenFrequencyPerWeek`,
  `allergenGroups`) — готовы к показу. Cartoon-карточки (`cartoonCard`), `BigButton`,
  `Theme`. Профиль — Form; редактор custom — степперы/тогглы.
- **Dependencies:** только SwiftUI/SwiftData. CloudKit-safe: новые поля Child с
  дефолтами; список аллергенов храним строкой rawValue через запятую (примитив, не
  ломает CloudKit).

## Development Approach

- Подход: Regular. Логику custom-профиля (билдер, fallback, парс/сериализация списка
  аллергенов, границы значений) делаем чистой и тестируемой; редактор/карточки — UI,
  валидируются self-launch.
- Тестируемое: `FeedingProfile.custom(from:)`, `Child.feedingProfile` (custom vs preset
  vs неизвестный id → fallback who), сериализация `customAllergenGroupsRaw ↔ [AllergenGroup]`,
  `maintenanceIntervalDays` для custom, границы степперов (через clamp-функцию).
- Плейсхолдеры: нет.

## Implementation Steps

### Task 1: Данные custom-профиля (модель)

Files:
- Modify: `Sources/Models/FeedingProfile.swift`
- Modify: `Sources/Models/Child.swift`

[ ] `FeedingProfile`: добавить `static let customId = "custom"` и
    `static func custom(from child: Child) -> FeedingProfile` — собирает профиль из
    custom-полей Child (source = «Свой план», caveat = мягкая оговорка)
[ ] `Child`: добавить CloudKit-safe поля с дефолтами от ВОЗ —
    `customStartAgeMonths: Int = 6`, `customObservationDays: Int = 3`,
    `customAllergenFrequencyPerWeek: Int = 2`,
    `customAllergenGroupsRaw: String = "egg,peanut,dairy,gluten,fish,soy,treenut,sesame"`
[ ] Хелперы сериализации: `customAllergenGroups: [AllergenGroup]` (парс/запись raw-строки)
[ ] `Child.feedingProfile`: если `feedingProfileId == FeedingProfile.customId` →
    `FeedingProfile.custom(from: self)`, иначе `preset(id:)`
[ ] Написать тесты (custom билдер, fallback на who при неизвестном id, round-trip
    списка аллергенов, `maintenanceIntervalDays`, разумные границы)
[ ] run project test suite — must pass before Task 2

### Task 2: Переиспользуемая карточка методики

Files:
- Create: `Sources/Features/Common/MethodologyCard.swift`

[ ] `MethodologyCard(profile:selected:onTap:)` — показывает: название, старт (мес),
    окно наблюдения (дн), частота аллергена (×/нед), число/список групп аллергенов,
    ссылку-источник; рамка-выделение при `selected`
[ ] Компактный режим для онбординга и развёрнутый для профиля (параметр `expanded`)
[ ] Leaf-UI — без юнит-логики; превью со всеми пресетами
[ ] run project test suite — must pass before Task 3

### Task 3: Редактор своего плана

Files:
- Create: `Sources/Features/Common/CustomPlanEditor.swift`

[ ] `CustomPlanEditor(child:)` (`@Bindable`) — степперы: старт (4–8 мес), окно
    наблюдения (1–14 дн), частота аллергена (1–7 ×/нед); мультивыбор `AllergenGroup`
    тогглами; живой предпросмотр `maintenanceIntervalDays`
[ ] Значения пишутся в custom-поля Child; clamp в границах (чистая функция, тестируемая)
[ ] Мягкая строка-оговорка снизу (`Disclaimer.short`)
[ ] Тесты на clamp-функцию границ
[ ] run project test suite — must pass before Task 4

### Task 4: Онбординг — наглядная методика + свой план, мягкий дисклеймер

Files:
- Modify: `Sources/Features/Onboarding/OnboardingView.swift`
- Modify: `Sources/App/Disclaimer.swift`

[ ] Убрать `disclaimerStep` и состояние/гейт `acceptedDisclaimer`; шагов станет 3
    (welcome → ребёнок → методика). Поправить `next()/canProceed/step`-индексы
[ ] На welcome-экран добавить мягкую сноску `Disclaimer.welcome` («не медсовет — решения
    с педиатром») мелким текстом, без галки
[ ] Методика-шаг: список `MethodologyCard` по пресетам + карточка **«Свой план»**;
    при выборе custom — кнопка/переход в `CustomPlanEditor`
[ ] `finish()`: сохранить выбранный `feedingProfileId` (включая `customId`) и custom-поля
[ ] Leaf-UI; прогнать набор на отсутствие регрессий
[ ] run project test suite — must pass before Task 5

### Task 5: Профиль — наглядная методика + редактор custom

Files:
- Modify: `Sources/Features/Profile/ProfileView.swift`

[ ] Секцию «Методика» переделать: показать текущую `MethodologyCard(expanded:)` со всеми
    параметрами и источником (вместо голого пикера + строк)
[ ] Пикер методики: пресеты + «Свой план»; при выборе custom — раскрыть `CustomPlanEditor`
[ ] Сохранять изменения custom-полей и `feedingProfileId`, дёргать
    `NotificationManager.refresh` (расписание зависит от окна/частоты)
[ ] Leaf-UI; прогнать набор
[ ] run project test suite — must pass before Task 6

### Task 6: Verify acceptance criteria

[ ] прогнать полный набор тестов — зелёный
[ ] онбординг: 3 шага, дисклеймер-шага с галкой нет; на welcome мягкая сноска
[ ] выбор методики показывает ВСЕ параметры (старт/окно/частота/аллергены/источник),
    и в онбординге, и в профиле
[ ] «Свой план»: можно задать старт/окно/частоту/список аллергенов; сохраняется и
    реально влияет на логику (окно ввода, due аллергенов, уведомления)
[ ] неизвестный `feedingProfileId` → fallback на ВОЗ (без краша)
[ ] новая логика (custom билдер, сериализация, clamp) покрыта юнит-тестами

### Task 7: Update documentation

[ ] `SPEC.md` §6/§12 — custom-профиль бесплатен в MVP; онбординг без отдельного
    дисклеймер-шага (дисклеймер смягчён, остаётся в «О приложении»)
[ ] `CLAUDE.md` — `MethodologyCard`/`CustomPlanEditor` в общих компонентах; custom-поля Child
[ ] напомнить про `xcodegen generate` (добавлены `MethodologyCard.swift`, `CustomPlanEditor.swift`)
