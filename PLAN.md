# План: баги и предложения по «Прикорм» (26 пунктов)

## Overview

Сводный план по списку из 26 багов/предложений. Делаем в порядке зависимостей:
сначала модель/сервисы (чистая логика + тесты), потом UI-проводка, потом локализация
и лендос. Каждая задача с логикой заканчивается своими тестами и гейтом «прогнать
весь набор — должен быть зелёным перед следующей задачей».

Две развилки зафиксированы пользователем и меняют структуру:

1. **Методики → только своя** (пункт 11). Сносим пресеты (`who`/`aap`/`russia`),
   `MethodologyCard`, `FeedingProfile.visiblePresets`. Онбординг и профиль редактируют
   единственный кастом-план. **Последствие:** платный крючок «Custom-профиль» из
   SPEC §6 исчезает — монетизацию надо переосмыслить (кандидат: экспорт PDF / шеринг).
   Это вне scope данного плана, но помечаем в SPEC.
2. **Реакция → просто запись** (пункты 4/15/16). Убираем авто-переход
   `реакция → paused/allergy` из `FeedingService.logFeeding`. Реакция — запись в
   журнал. Остановка ввода — явная кнопка «Остановить ввод» (→ `paused`). В
   остановленном состоянии показываем «Возобновить» и «Попробовать через 2 месяца»
   (ставим локальное уведомление ~60 дн). Для уже введённого аллергена остаётся
   **ручная** пометка проблемы (→ `allergy`), чтобы гасить напоминания поддержки —
   killer-фича §4.3 не ломается, просто перестаёт быть автоматической. **Последствие:**
   стейт-машина SPEC §4.4 переписывается.

### Не входит в scope (и почему)
- **Paywall / StoreKit / новая монетизация** — отдельная продуктовая задача; здесь
  только убираем платный крючок и помечаем в SPEC.
- **CloudKit-синхрон** — не трогаем; все новые поля моделей даём с дефолтами
  (CloudKit-safe), без `.unique`.
- **Контент «чем полезен» для всех 72 продуктов** — задаём схему + UI + 5–10 примеров;
  полное наполнение текстами — placeholder-работа на потом (помечено).
- **Заказной арт иконок** — чиним рендер и аудит ассетов `food_<id>`; рисование новых
  иконок — вне scope (placeholder).
- **Полная переверстка лендоса** — он уже адаптивный (viewport, `clamp()`, grid
  auto-fit, медиа-запрос 720px); только точечные фиксы.

## Context

### Файлы — что меняется

**Модели (`Sources/Models/`)**
- `Enums.swift` — `ReactionType`: добавить `constipation`, `diarrhea`; переименовать
  тайтлы `gi`/`breathing` (raw-значения НЕ трогаем — персист в `FoodLog.reactionRaw`).
  `FoodCategory`: убрать кейс `.allergen`.
- `FoodLog.swift` — добавить `planned: Bool = false` (планирование на будущее, п.21);
  заметка остаётся `note: String?` (унифицируем — пишем в тот же лог, не отдельный).
- `IntroductionStatus.swift` — добавить `retryAt: Date?` (напоминание «через 2 мес», п.16).
- `Child.swift` — `customObservationDays` → пара `customObservationDaysRegular` /
  `customObservationDaysAllergen` (п.10); поля кастом-плана остаются.
- `FeedingProfile.swift` — убрать `who`/`aap`/`russia`, `visiblePresets`, `isPreset`,
  `source`/`sourceURL`/`caveat`; оставить `custom(from:)`. Добавить
  `observationDaysAllergen` рядом с `observationDays` (regular).
- `Food.swift` — добавить `benefits: String?`, `nutrients: [String]?` (п.12).

**Сервисы (`Sources/Services/`)**
- `FeedingService.swift` — `logFeeding`: убрать авто-переход по реакции; в `.introducing`
  тянуть `introStartedAt` назад при бэкдейте (п.22). `startIntroduction(date:)`,
  `reintroduce(date:)` — принимать дату. Новые: `stopIntroduction(_:)`,
  `scheduleRetry(_:after:)`. Window-start helper.
- `FoodCatalog.swift` — `search(_:)`: ранжированный fuzzy + матч по названию категории/
  аллерген-группы (п.1, п.17).
- `NotificationManager.swift` — новый префикс `retry-`; one-shot уведомление по
  `IntroductionStatus.retryAt`. Перестать опираться на авто-`allergy`.
- `CalendarService.swift` — учитывать `FoodLog.planned`; будущие дни (п.21).
- `AllergenMaintenance.swift` — выбор окна по `food.isAllergen` (п.10), без правок логики
  авто-аллергии (её больше нет).

**Фичи (`Sources/Features/`)**
- `Catalog/CatalogView.swift` — отступ поиска (п.2), кнопка «свой продукт» вверх (п.19),
  бейдж «аллерген» + перегруппировка (п.14), показ группы по поиску (п.17).
- `Catalog/FoodDetailView.swift` — убрать каунтер истории (п.3), новые кнопки реакции/
  стоп/возобновить/повторить (п.4/16), секция «чем полезен» (п.12), дата старта (п.22).
- `Catalog/LogFeedingSheet.swift` — заметку писать в лог кормления (п.20), расширенные
  теги реакции (п.15).
- `Catalog/AddCustomFoodSheet.swift` — поля benefits (опц.) под п.12.
- `Calendar/CalendarView.swift` — различимые цвета (п.6), планирование на будущее (п.21).
- `Calendar/DayDetailView.swift` — редактирование заметки (п.20), плановые записи (п.21).
- `Dashboard/DashboardView.swift` — переделать блок ребёнка (п.24), отступ сверху (п.5),
  раздел «повторить через 2 мес» (п.16).
- `Profile/ProfileView.swift` — имя лейбл+значение (п.25), отступ сверху (п.5), вместо
  `MethodologyCard`-пикера — редактор своего плана (п.11).
- `Onboarding/OnboardingView.swift` — настройка плана внутри (п.8), выбор уже введённых
  продуктов (п.23).
- `Common/CustomPlanEditor.swift` — тап по бейджу вместо +/- (п.9), второй степпер окна
  (п.10).
- `Common/MethodologyCard.swift` — **удалить** (п.11).
- `Common/FoodIcon.swift` — фикс рендера/аудит ассетов (п.13).
- `App/Disclaimer.swift` — `short`/`welcome` обернуть в `String(localized:)` (п.7).

**Ресурсы**
- `Resources/foods.json` — убрать воду (п.18), перекатегоризировать из `allergen` (п.14),
  поля `benefits`/`nutrients` (п.12).
- `Resources/Localizable.xcstrings` — 5 недостающих EN, новые строки под новый UI (п.7).
- `site/` — точечный адаптив (п.26).

### Существующие паттерны (следовать)
- Чистые сервисы над `ModelContext` + инъекция `now`/`calendar` для детерминизма
  (`FeedingService.observationDay`, `AllergenTracker.status`, `CalendarService.calendar`).
- In-memory `ModelContainer` в тестах (`isStoredInMemoryOnly: true`).
- Компоненты: `BigButton`/`GhostButton`/`PillButton` (`LocalizedStringKey`),
  `Chip`/`StatusBadge` (`String`), `cartoonCard()`, `Theme` (палитра), `FoodIcon`.
- Локализация: ключ = русская строка; `Text("литерал")` авто-локализуется; `Text(var)`
  — verbatim (модельные строки через `String(localized:)`); интерполяцию — через
  формат-строки `%lld`/`%@`, не `\()`.

### Зависимости
- Apple-only (SwiftUI, SwiftData, UserNotifications, Swift Charts). **Без сторонних
  пакетов** — fuzzy-поиск пишем сами (не fuse.js как библиотека, а как поведение).
- После добавления/удаления файлов — напомнить юзеру `xcodegen generate`
  (удаляем `MethodologyCard.swift`).

## Development Approach

- **Code-first («Regular»)** с тестами в конце каждой логической задачи. Текущие тесты:
  `DisclaimerTests`, `FoodCatalogTests`, `AppLanguageTests` (+ `ModelTests`,
  `FeedingServiceTests`, `AllergenTests`, `CalendarServiceTests`,
  `NotificationManagerTests`, `AppShellTests`, `MascotTests` по CLAUDE.md).
- **Тестируемое (чистая логика):** `FoodCatalog.search` (fuzzy/группы), `FeedingService`
  (стоп/возобновить/window-start/бэкдейт), `NotificationManager.requests`/`retryRequests`,
  `CalendarService` (плановые/будущие дни), `AllergenMaintenance` (окно по типу),
  декод `foods.json` (новые поля, без воды, без `.allergen`).
- **Проверяется запуском (не юнит):** отступы (п.2/5), цвета календаря (п.6), рендер
  иконок (п.13), редизайн блока ребёнка (п.24), тап-бейджи (п.9), верстка профиля (п.25),
  лендос (п.26). У этих задач НЕТ тест-гейта — помечено явно, проверка self-launch.
- **Юзер сам билдит/гоняет** — мы не запускаем `xcodebuild`/`simctl`. После правок
  файлов напоминаем `xcodegen generate`.

### Placeholder-значения
- Тексты «чем полезен / нутриенты» для 72 продуктов — наполняем позже (схема + примеры).
- Ассеты `food_<id>` — аудит/фикс, новый арт позже.
- Интервал «попробовать снова» = **+2 календарных месяца** (через `Calendar`), время 10:00.
- Новая монетизация — вне scope (помечаем в SPEC).

## Implementation Steps

### Task 1: Реакция — только запись + расширенные теги (п.4 логика, п.15, п.16 ядро)

Files:
• Modify: `Sources/Services/FeedingService.swift`
• Modify: `Sources/Models/Enums.swift`
• Modify: `Tests/FeedingServiceTests.swift`

[ ] В `FeedingService.logFeeding(_:liking:reaction:date:)` убрать блок
    `if let reaction { s.state = isMaintenance ? .allergy : .paused }` — состояние от
    реакции больше НЕ меняется; лог пишется как раньше.
[ ] В `ReactionType` (Enums.swift) добавить кейсы `constipation`, `diarrhea`; задать им
    эмодзи и `title` (через `String(localized:)`). Переименовать `title` у `gi`
    (→ «Срыгивание/рвота») и `breathing` (→ «Затруднённое дыхание»). **Raw-значения
    `gi`/`breathing` НЕ менять** (декод старых `FoodLog.reactionRaw`).
[ ] Обновить инфо-текст в `LogFeedingSheet` (см. Task 11) — убрать «переведёт в паузу».
[ ] Тесты: `logFeeding` с реакцией в `.introducing` НЕ переводит в `.paused`; в
    `.introduced` НЕ переводит в `.allergy`; лог с реакцией сохраняется; декод старого
    raw `"gi"` валиден; все `ReactionType.allCases` имеют непустой `title`.
[ ] прогнать весь набор тестов — должен быть зелёным перед Task 2

### Task 2: Остановить / возобновить / повторить через 2 месяца (п.16)

Files:
• Modify: `Sources/Models/IntroductionStatus.swift`
• Modify: `Sources/Services/FeedingService.swift`
• Modify: `Sources/Services/NotificationManager.swift`
• Modify: `Tests/FeedingServiceTests.swift`, `Tests/NotificationManagerTests.swift`

[ ] `IntroductionStatus`: добавить `var retryAt: Date? = nil` (CloudKit-safe дефолт).
[ ] `FeedingService.stopIntroduction(_ food:)` — `.introducing`/`.introduced` → `.paused`,
    `retryAt = nil`.
[ ] `FeedingService.scheduleRetry(_ food:, after months: Int = 2, now: Date = Date(),
    calendar: Calendar = .current)` — оставляет `.paused`, ставит
    `retryAt = calendar.date(byAdding: .month, value: months, to: now)`.
[ ] `FeedingService.reintroduce(_:date:)` (расширяем сигнатуру в Task 3) — также чистит
    `retryAt = nil`.
[ ] Оставить `markAllergy(_:)` как **ручную** пометку проблемы для уже введённого
    (гасит напоминания поддержки — `AllergenMaintenance` уже фильтрует `hasAllergy`).
[ ] `NotificationManager`: новый `retryPrefix = "retry-"`. Метод
    `retryRequests(statuses:now:calendar:) -> [UNNotificationRequest]` — для статусов с
    `retryAt` в будущем: one-shot (`repeats:false`) на дату `retryAt`, 10:00, id
    `"retry-<foodId>"`, нейтральный текст. Влить в `refresh`/`apply`; в `clearAll` гасить
    и `retry-`.
[ ] Тесты (`FeedingServiceTests`): `stopIntroduction` → `.paused`; `scheduleRetry` ставит
    `retryAt = now + 2 мес`; `reintroduce` чистит `retryAt`. Тесты
    (`NotificationManagerTests`): `retryRequests` строит один запрос на статус с будущим
    `retryAt`, пропускает прошедшие/`nil`, id `retry-<foodId>` (мок-центр, без реального
    UNUserNotificationCenter).
[ ] прогнать весь набор тестов — должен быть зелёным перед Task 3

### Task 3: Бэкдейт ввода + якорь окна наблюдения по реальной дате (п.22)

Files:
• Modify: `Sources/Services/FeedingService.swift`
• Modify: `Tests/FeedingServiceTests.swift`

[ ] `startIntroduction(_ food:, date: Date = Date())` — `introStartedAt = date`, intro-лог
    с `date` (сейчас всегда `Date()`).
[ ] `reintroduce(_ food:, date: Date = Date())` — `introStartedAt = date`.
[ ] В `logFeeding`: если `s.state == .introducing` и тип intro и `date < s.introStartedAt`
    → подтянуть `introStartedAt = date` (бэкдейт двигает окно).
[ ] Чистый хелпер `static func windowStart(introStartedAt: Date?, introLogDates: [Date])
    -> Date?` = минимум из `introStartedAt` и самой ранней intro-даты; использовать в
    `FoodDetailView.observationDay` вместо «голого» `introStartedAt`.
[ ] Тесты: старт с прошлой датой → `observationDay` считает от неё; бэкдейт-кормление в
    `.introducing` тянет `introStartedAt` назад и делает `isObservationComplete=true`
    когда надо; `windowStart` берёт самый ранний из стартов/логов.
[ ] прогнать весь набор тестов — должен быть зелёным перед Task 4

### Task 4: Только своя методика — снос пресетов (п.11)

Files:
• Modify: `Sources/Models/FeedingProfile.swift`
• Modify: `Sources/Models/Child.swift`
• Delete: `Sources/Features/Common/MethodologyCard.swift`
• Modify: `Tests/` (тесты пресетов — найти и обновить/удалить), `project.yml` напоминание

[ ] `FeedingProfile`: удалить статические `who`/`aap`/`russia`, `visiblePresets(language:)`,
    `preset(id:)`, поля `isPreset`/`source`/`sourceURL`/`caveat`. Оставить `id`, `name`,
    параметры, `custom(from:)`, `customId`, `CustomLimits`.
[ ] `Child.feedingProfile` — всегда `FeedingProfile.custom(from: self)`; `feedingProfileId`
    можно зафиксировать на `customId` (оставить поле ради CloudKit-совместимости).
[ ] Удалить `MethodologyCard.swift`; вычистить импорты/использования (Onboarding — Task 17,
    Profile — Task 15).
[ ] Найти тесты, ассертящие значения пресетов (grep по `who`/`aap`/`russia`/`visiblePresets`)
    — удалить/переписать на кастом-профиль.
[ ] Напомнить юзеру `xcodegen generate` (удалён файл).
[ ] Тесты: `FeedingProfile.custom(from:)` отдаёт корректные параметры из `Child`; нет
    ссылок на удалённые символы (компиляция = тест).
[ ] прогнать весь набор тестов — должен быть зелёным перед Task 5

### Task 5: Раздельное окно наблюдения — аллерген vs обычный (п.10)

Files:
• Modify: `Sources/Models/Child.swift`, `Sources/Models/FeedingProfile.swift`
• Modify: `Sources/Services/FeedingService.swift`, `Sources/Services/AllergenMaintenance.swift`
• Modify: `Tests/FeedingServiceTests.swift`, `Tests/AllergenTests.swift`

[ ] `Child`: `customObservationDays` → `customObservationDaysRegular: Int = 3` +
    `customObservationDaysAllergen: Int = 5` (CloudKit-safe дефолты).
[ ] `FeedingProfile`: `observationDays` → `observationDaysRegular` + `observationDaysAllergen`;
    `custom(from:)` мапит оба поля.
[ ] Хелпер `FeedingProfile.observationDays(for food: Food) -> Int` = allergen-окно если
    `food.isAllergen`, иначе regular. Использовать в `FoodDetailView` (Task 11) и при
    подсчёте `isObservationComplete`.
[ ] Тесты: для аллергена берётся allergen-окно, для обычного — regular; `custom(from:)`
    переносит оба значения из `Child`.
[ ] прогнать весь набор тестов — должен быть зелёным перед Task 6

### Task 6: Перестройка каталога — убрать псевдо-категорию `allergen` и воду (п.14, п.18)

Files:
• Modify: `Resources/foods.json`
• Modify: `Sources/Models/Enums.swift` (`FoodCategory`)
• Modify: `Sources/Features/Common/Theme.swift` (`categoryColor` switch)
• Modify: `Tests/FoodCatalogTests.swift`

[ ] `foods.json`: удалить запись `water`. Перекатегоризировать все `"category":"allergen"`
    в реальные группы (яйцо→`egg`, молочка→`dairy`, рыба→`fish`, арахис/орехи/кунжут/соя/
    глютен → `other` или существующая профильная), оставив `isAllergen:true` +
    `allergenGroup`.
[ ] `FoodCategory`: удалить кейс `.allergen`; обновить все исчерпывающие `switch`
    (`title`, `Theme.categoryColor`, любые иконки `cat_allergen`).
[ ] Тесты: декод `foods.json` — нет продукта с id `water`; нет продукта с категорией
    `allergen` (кейса больше нет); каждый `isAllergen==true` имеет `allergenGroup != nil`;
    счётчик продуктов обновлён (72 → актуальное).
[ ] прогнать весь набор тестов — должен быть зелёным перед Task 7

### Task 7: Поля «чем полезен / нутриенты» в модели и JSON (п.12)

Files:
• Modify: `Sources/Models/Food.swift`
• Modify: `Resources/foods.json`
• Modify: `Tests/FoodCatalogTests.swift`

[ ] `Food`: добавить `let benefits: String?` и `let nutrients: [String]?` (опциональны →
    старый JSON декодится). `localizedBenefits` через `String(localized:)` если ключ-строка.
[ ] `foods.json`: добавить поля для **5–10 продуктов** как образец (кабачок, брокколи,
    мясо, яйцо, рыба…). Остальные — placeholder (помечено, наполняется позже).
[ ] Добавить RU-ключи + EN в `Localizable.xcstrings` для образцовых текстов (Task 18
    финализирует остальные).
[ ] Тесты: декод записи с `benefits`/`nutrients` и без них (оба валидны); `nutrients`
    парсится в массив.
[ ] прогнать весь набор тестов — должен быть зелёным перед Task 8

### Task 8: Fuzzy-поиск + поиск по группе (п.1, п.17)

Files:
• Modify: `Sources/Services/FoodCatalog.swift`
• Modify: `Tests/FoodCatalogTests.swift`

[ ] Переписать `search(_ query:) -> [Food]`: нормализация (lowercase, диакритика, ё→е),
    скоринг = точное вхождение > префикс токена > подпоследовательность (fuzzy, опечатки) >
    нет. Возврат отсортирован по скору; пустой запрос → все.
[ ] Матч по группе: если запрос совпадает с `FoodCategory.title` (напр. «овощи») или
    `AllergenGroup.title` — добавить все продукты этой группы в результат (п.17).
[ ] Тесты: «кабачёк»/«кабчок» (опечатка) находит «Кабачок»; вхождение в середине слова
    находит; «овощи» возвращает все `vegetable`; ранжирование (точное выше fuzzy); пустой
    запрос → все.
[ ] прогнать весь набор тестов — должен быть зелёным перед Task 9

### Task 9: CatalogView — отступ поиска, кнопка «свой продукт» вверх, бейдж/группировка (п.2, п.19, п.14)

Files:
• Modify: `Sources/Features/Catalog/CatalogView.swift`

[ ] Отступ поиска (п.2): уменьшить зазор под `searchBar` — поправить `listRowInsets`
    (сейчас top:8/bottom:4) и/или верхний инсет `List`; убрать лишний воздух до первой
    секции.
[ ] Кнопка «Добавить свой продукт» (п.19): вынести `addCustomRow` из секции `.other`
    наверх — заметной строкой под `searchBar` (или `ToolbarItem` `+`). Убрать её из
    `.other`.
[ ] Бейдж «аллерген» (п.14): заменить громкий оранжевый `StatusBadge("аллерген")` в
    `row(for:)` на компактный значок (напр. `exclamationmark.triangle` тинтом) или убрать
    совсем; группировка теперь по реальным категориям (Task 6).
[ ] Поиск-группа (п.17): UI уже отрендерит результат из обновлённого `catalog.search`
    (Task 8) — проверить, что секции категорий показывают найденную группу.
[ ] Без юнит-тестов (leaf UI; логика поиска покрыта Task 8). Проверка self-launch:
    отступ, позиция кнопки, поиск «овощи».

### Task 10: FoodIcon — фикс рендера и аудит ассетов (п.13)

Files:
• Modify: `Sources/Features/Common/FoodIcon.swift`
• Modify: `Resources/` (ассеты `food_<id>` — аудит)

[ ] Центрирование/паддинг: убрать обрезание/смещение эмодзи-фолбэка (baseline) — рендерить
    эмодзи в контейнере фикс. размера с центровкой; единый размер для `food_<id>` и
    `cat_<category>`.
[ ] Аудит: какие `food_<id>` ассеты отсутствуют и валятся в `cat_<category>`/эмодзи;
    список на догенерацию (placeholder-арт позже).
[ ] Без юнит-тестов (рендер). Проверка self-launch: ряд каталога и герой деталки.

### Task 11: FoodDetailView — реакции/стоп/возобновить/повторить, секция пользы, дата старта, без каунтера (п.3, п.4, п.16, п.12, п.22)

Files:
• Modify: `Sources/Features/Catalog/FoodDetailView.swift`
• Modify: `Sources/Features/Catalog/LogFeedingSheet.swift`

[ ] Каунтер истории (п.3): удалить `Text("\(logs.count)")` в `historyCard`.
[ ] Кнопки по состоянию (`actionButtons`):
    - `.notIntroduced`: «Начать введение» с выбором даты старта (дефолт сегодня, можно
      прошлое) → `service.startIntroduction(food, date:)` (Task 3).
    - `.introducing`: «Записать кормление», «Ввёл успешно ✅» (когда окно прошло — окно по
      `observationDays(for:)` Task 5), + **«Остановить ввод»** → `stopIntroduction`.
    - `.introduced`: «Записать кормление» + ручное «Пометить проблему/аллергию» →
      `markAllergy` (гасит напоминания).
    - `.paused`: **«Возобновить»** → `reintroduce(food, date:)` и **«Попробовать через 2
      месяца»** → `scheduleRetry(food)`; показать `retryAt` если стоит.
    - `.allergy`: как сейчас (`allergyCard` + «Вернуть в оборот»).
[ ] Реакция (п.4): «Была реакция» открывает `LogFeedingSheet`, но без авто-перехода (Task
    1) — просто фиксирует запись; обновить инфо-текст листа (убрать «переведёт в паузу»).
[ ] Секция «Чем полезен» (п.12): показать `food.benefits`/`nutrients` если есть (чипами/
    текстом) под героем.
[ ] Окно наблюдения: `observationDay`/`canComplete` считать через `windowStart` (Task 3) и
    `observationDays(for: food)` (Task 5).
[ ] Без отдельных юнит-тестов (UI поверх покрытых сервисов). Проверка self-launch: все
    переходы состояний, секция пользы, бэкдейт-старт.

### Task 12: LogFeedingSheet — заметка в лог кормления, расширенные теги (п.20 часть, п.15 UI)

Files:
• Modify: `Sources/Features/Catalog/LogFeedingSheet.swift`
• Modify: `Tests/FeedingServiceTests.swift` (если выносим запись заметки в сервис)

[ ] Заметку писать в **тот же** `FoodLog` кормления (передавать `note` в
    `FeedingService.logFeeding` → расширить сигнатуру `note: String? = nil`), а не
    отдельной записью (сейчас строка `FoodLog(foodId:date:note:)`). Это делает «редактировать
    заметку» (Task 13) естественным.
[ ] Reaction picker: показать новые теги (`constipation`/`diarrhea`, переименованные
    `gi`/`breathing`) — `ReactionType.allCases` уже отрендерит.
[ ] Тесты: `logFeeding(..., note:)` сохраняет заметку в том же логе; отдельная запись
    заметки больше не создаётся.
[ ] прогнать весь набор тестов — должен быть зелёным перед Task 13

### Task 13: Редактирование заметки (п.20)

Files:
• Modify: `Sources/Features/Calendar/DayDetailView.swift`
• Modify: `Sources/Features/Catalog/FoodDetailView.swift`
• Create: `Sources/Features/Common/EditNoteSheet.swift`

[ ] `EditNoteSheet(log: FoodLog)` — `TextField` с `log.note`, сохранение в `log.note` +
    `context.save()`.
[ ] В `DayDetailView` и `historyRow` (FoodDetailView): тап по записи/заметке открывает
    `EditNoteSheet`. Показывать заметку в `DayDetailView` (сейчас не рендерится).
[ ] Без юнит-тестов (UI + прямое присваивание `log.note`). Проверка self-launch: правка и
    сохранение заметки.

### Task 14: Календарь — различимые цвета + планирование на будущее (п.6, п.21)

Files:
• Modify: `Sources/Features/Calendar/CalendarView.swift`
• Modify: `Sources/Features/Calendar/DayDetailView.swift`
• Modify: `Sources/Models/FoodLog.swift`
• Modify: `Sources/Services/CalendarService.swift`
• Modify: `Tests/CalendarServiceTests.swift`

[ ] Цвета (п.6): «есть записи» сменить с `Theme.accent` (коралл) на холодный
    (`Theme.sky`/`Theme.mint`), «реакция» оставить `.red`; обновить `legend`. Для плановых
    — третий стиль (пунктир/`Theme.lilac`).
[ ] `FoodLog.planned: Bool = false`. Планирование: тап по будущему дню → лист «запланировать
    ввод» (создаёт `FoodLog(planned:true, date:future)`); `canGoNext`/навигация разрешает
    будущие месяцы.
[ ] `CalendarService`: `activeDays()`/`days()`/`day()` учитывают плановые; `DaySummary`
    помечает плановость; будущие дни не считаются «реакцией».
[ ] `DayDetailView`: плановые записи отдельным стилем; «отметить выполненным» снимает
    `planned`.
[ ] Тесты: `CalendarService` группирует будущий плановый лог в нужный день; `hasActivity`/
    плановость различаются; граница дня/таймзона детерминированы (инъекция `calendar`).
[ ] прогнать весь набор тестов — должен быть зелёным перед Task 15

### Task 15: Dashboard — блок ребёнка, отступ сверху, «повторить через 2 мес» (п.24, п.5, п.16)

Files:
• Modify: `Sources/Features/Dashboard/DashboardView.swift`

[ ] Отступ сверху (п.5): `.navigationBarTitleDisplayMode(.inline)` для «Сегодня» (Каталог/
    деталь уже inline) ИЛИ кастом-хедер; ужать верхний `.padding()`/spacing до первого блока.
[ ] Блок ребёнка (п.24): переработать `heroCard` — компоновка имени/возраста/прогресса
    (макет на self-launch; держать `ProgressRingOnColor`, `Mascot.forProgress`).
[ ] Раздел «Повторить ввод» (п.16): показать продукты с `retryAt`/`.paused` с датой
    «попробовать ~`retryAt`».
[ ] Без юнит-тестов (leaf UI). Проверка self-launch: отступ, новый блок, раздел повторов.

### Task 16: Profile — имя лейбл+значение, отступ, редактор своего плана (п.25, п.5, п.11)

Files:
• Modify: `Sources/Features/Profile/ProfileView.swift`

[ ] Имя (п.25): строка `LabeledContent("Имя") { TextField(...) }` или HStack «Имя» слева +
    значение/поле справа (сейчас просто инлайн `TextField`).
[ ] Отступ (п.5): `.navigationBarTitleDisplayMode(.inline)` для «Профиль».
[ ] План (п.11): вместо `MethodologyCard(expanded:)` + пикера пресетов — встроить
    `CustomPlanEditor(child: child)` (своя методика).
[ ] Без юнит-тестов (leaf UI). Проверка self-launch: верстка имени, редактор плана.

### Task 17: CustomPlanEditor — тап-бейджи + второй степпер окна (п.9, п.10 UI)

Files:
• Modify: `Sources/Features/Common/CustomPlanEditor.swift`

[ ] Замена +/- (п.9): значения (старт/окно/частота) выбирать тапом по бейджам/сегментам
    (ряд кликабельных капсул со значениями) вместо `roundButton("minus"/"plus")`.
[ ] Второй степпер окна (п.10): отдельные контролы «окно обычного» и «окно аллергена»
    (`customObservationDaysRegular`/`customObservationDaysAllergen`, Task 5).
[ ] Без юнит-тестов (UI поверх покрытой модели). Проверка self-launch: тап-выбор, два окна.

### Task 18: Онбординг — настройка плана внутри + выбор уже введённых продуктов (п.8, п.23)

Files:
• Modify: `Sources/Features/Onboarding/OnboardingView.swift`
• Modify: `Sources/Services/FeedingService.swift` (хелпер засева)
• Modify: `Tests/FeedingServiceTests.swift`

[ ] Шаг плана (п.8): заменить выбор пресетов (`visiblePresets`/`MethodologyCard`, удалены
    Task 4) на встроенный `CustomPlanEditor(child: draftChild)`.
[ ] Шаг «уже введено» (п.23): мульти-выбор продуктов из каталога → на финише создать
    `IntroductionStatus(state: .introduced)` для каждого. Вынести в
    `FeedingService.markIntroduced(_ foods:)` (тестируемо).
[ ] `lastStep` и индикатор шагов обновить под новое число шагов.
[ ] Тесты: `markIntroduced([...])` создаёт статусы `.introduced` без дублей.
[ ] прогнать весь набор тестов — должен быть зелёным перед Task 19

### Task 19: Локализация — добить EN, формат-строки, дисклеймер (п.7)

Files:
• Modify: `Resources/Localizable.xcstrings`
• Modify: `Sources/App/Disclaimer.swift`
• Modify: `Sources/Features/Dashboard/DashboardView.swift` (интерполяции)
• Modify: `Tests/DisclaimerTests.swift`, `Tests/AppLanguageTests.swift`

[ ] Интерполяции через формат-строки (не `\()`): `DashboardView` стр.101 (ранний баннер),
    стр.126 (если есть), стр.139 (`"%lld мес"`/`"\(ageInMonths) мес"`); проверить новые
    строки из Task 11/15.
[ ] `Disclaimer.short`/`Disclaimer.welcome` обернуть в `String(localized:)`.
[ ] Добавить EN для всех новых ключей (стоп/возобновить/повторить, теги реакции, «чем
    полезен», заголовки планирования, лейбл «Имя» и т.д.) + 5 ранее недостающих.
[ ] Тесты: `Disclaimer.short`/`welcome` непустые/локализуются; новые модельные строки
    (`ReactionType.title` новых кейсов) непустые в обоих языках (locale-robust ассерты).
[ ] прогнать весь набор тестов — должен быть зелёным перед Task 20

### Task 20: Лендос — точечный адаптив (п.26)

Files:
• Modify: `site/styles.css`, `site/index.html`, `site/en/index.html` (по необходимости)

[ ] Проверить на узких ширинах (320–414px): переполнения, длинные строки, sticky-CTA,
    отступы. Точечные фиксы (он уже адаптивный — viewport/`clamp()`/grid auto-fit/медиа
    720px).
[ ] Добавить промежуточный брейкпоинт при необходимости (480px) для карточек/шагов.
[ ] Без юнит-тестов (статичный сайт). Проверка: DevTools responsive RU+EN.

### Task 21: Проверка критериев приёмки

[ ] Поиск находит по опечатке/вхождению; «овощи» показывает группу овощей (п.1, п.17).
[ ] Отступ под поиском адекватный; кнопка «свой продукт» сверху (п.2, п.19).
[ ] В истории нет каунтера (п.3).
[ ] Тап «была реакция» = понятная запись без авто-перехода; есть «Остановить ввод», а в
    паузе — «Возобновить» и «Попробовать через 2 мес» с уведомлением (п.4, п.16).
[ ] Отступ сверху на Главной/Календаре/Профиле уменьшен (п.5).
[ ] Цвета «есть записи» и «реакция» в календаре различимы (п.6).
[ ] EN-локализация без дыр; дисклеймер локализован (п.7).
[ ] Настройка плана в онбординге; выбор уже введённых продуктов работает (п.8, п.23).
[ ] В редакторе плана выбор тапом по бейджу; два окна наблюдения (п.9, п.10).
[ ] Пресетов методик нет — только своя (п.11).
[ ] У продуктов есть секция «чем полезен» (хотя бы образцы) (п.12).
[ ] Иконки ровные (п.13).
[ ] Каталог перестроен; псевдо-категория `allergen` убрана; воды нет (п.14, п.18).
[ ] Теги реакции: ЖКТ → запор/диарея; «дыхание» прояснено; ЖКТ не уходит в аллергию (п.15).
[ ] Заметку можно отредактировать (п.20).
[ ] Календарь умеет планировать на будущее (п.21).
[ ] Бэкдейт-кормление двигает окно/засчитывается (п.22).
[ ] Блок ребёнка переработан (п.24); имя в профиле — лейбл+значение (п.25).
[ ] Лендос ок на мобильных (п.26).
[ ] Вся новая логика покрыта юнит-тестами (сервисы/модели ≥80%).

### Task 22: Обновить документацию

Files:
• Modify: `SPEC.md`, `CLAUDE.md`, `README.md`, `docs/` (по необходимости)

[ ] `SPEC.md`: переписать §4.4 (реакция = запись + ручной стоп/возобновить/повтор; нет
    авто-`paused`/`allergy`); §4.1/§13 (только своя методика, пресеты убраны); §6
    (платный крючок Custom исчез — пометить TODO по новой монетизации); §4.2 (раздельное
    окно аллерген/обычный); §7.1 (планирование на будущее).
[ ] `CLAUDE.md`: обновить раздел архитектуры (удалён `MethodologyCard`; новые поля моделей;
    `retry-` уведомления; fuzzy-поиск).
[ ] `docs/legal/methodology-sources.md` — пометить, что пресеты убраны из UI (источники
    оставить для истории/возможного возврата).
[ ] Напомнить юзеру `xcodegen generate` (удалён `MethodologyCard.swift`, добавлен
    `EditNoteSheet.swift`).
