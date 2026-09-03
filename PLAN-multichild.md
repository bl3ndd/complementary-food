# Несколько детей: бесплатно один, в Pro сколько угодно

## Overview

Сейчас второго ребёнка завести **невозможно**: онбординг показывается только когда
`children.isEmpty`, кнопки добавления нет, а везде в коде стоит `children.first`
(`RootView.swift:28`, `CalendarView.swift`, `DayDetailView.swift:55`).

Но главная проблема глубже интерфейса: **у записей нет привязки к ребёнку.**
`FoodLog` и `IntroductionStatus` хранят только `foodId`, поэтому дневник в
приложении глобальный. Заведи мы второго ребёнка сегодня — оба смотрели бы в один
журнал. Значит это в первую очередь изменение модели данных, и только потом UI.

Правило доступа: **бесплатно — один ребёнок, Pro — сколько угодно.** Это ёмкость,
а не доступ к уже введённым данным, поэтому принцип «не паволим свои данные» не
нарушается. Жёсткое условие: **потеря Pro никогда не удаляет и не прячет данные**
второго ребёнка — блокируется только ДОБАВЛЕНИЕ нового.

**Не входит в этот план:**
- **Полный экспорт «за всё время»** — он уже существует: `DiaryPDFExport` берёт весь
  журнал без ограничения по датам, вместе с фото. Строить нечего.
- **Машиночитаемая выгрузка (JSON/CSV)** — отдельная потребность (перенос в другое
  приложение), делается отдельно и бесплатно.
- **Раздельный шаринг по детям** между родителями — синк один на аккаунт iCloud.
- **Перенос записей между детьми** — редкий сценарий, руками через удаление и
  повторный ввод.

## Context

### Files involved

**Меняем — модель и миграция:**
- `Sources/Models/FoodLog.swift` — добавляется `childId: UUID?`.
- `Sources/Models/IntroductionStatus.swift` — добавляется `childId: UUID?`.
- `Sources/App/PlanMigration.swift` — рядом с `ObservationWindowsV2` появляется
  разовый бэкфилл: все записи с `childId == nil` привязываются к единственному ребёнку.
- `Sources/App/AppSchema.swift` — **версию НЕ бампаем** (поля опциональные, см. правило
  в `CLAUDE.md`), но комментарий про бэкфилл добавить.

**Меняем — активный ребёнок:**
- `Sources/App/ActiveChild.swift` (новый) — хранение выбранного ребёнка в
  `@AppStorage`, разрешение «какой ребёнок активен» с откатом на первого.
- `Sources/App/RootView.swift` — `children.first` → активный ребёнок.

**Меняем — фильтрация (12 мест с `@Query` логов/статусов):**
- `Sources/Features/Dashboard/DashboardView.swift` — `todayLogs`, `recentLogs`,
  `allergenLogs`, `statuses`.
- `Sources/Features/MainTabView.swift` — `logs`, `statuses`.
- `Sources/Features/Calendar/CalendarView.swift`, `DayDetailView.swift`.
- `Sources/Features/Catalog/CatalogView.swift`, `FoodDetailView.swift`.
- `Sources/Features/Allergens/AllergensView.swift`.
- `Sources/Features/Profile/ProfileView.swift`.

**Меняем — запись:**
- `Sources/Services/FeedingService.swift` — `status(for:)`, `startIntroduction`,
  `logFeeding` и прочее проставляют `childId`.

**Меняем — UI:**
- `Sources/Features/Profile/ProfileView.swift` — секция «Дети»: список, переключение,
  добавление (под Pro), удаление с подтверждением.
- `Sources/Features/Onboarding/OnboardingView.swift` — переиспользуется для добавления
  второго ребёнка.
- `Sources/Features/Profile/ProSheet.swift` — в список возможностей добавить детей.

**Тесты:** `Tests/ActiveChildTests.swift`, `Tests/MultiChildTests.swift`,
`Tests/PlanMigrationTests.swift` (бэкфилл), обновление `FeedingServiceTests`.

### Related patterns

- **Предикаты `@Query` строятся в `init` и обязаны быть СТАБИЛЬНЫМИ** между проходами
  `body` — иначе выборка пересоздаётся на ровном месте (это мы чинили в перф-разборе:
  границы выровнены по началу дня). Добавляя `childId`, держать то же правило.
- **Разовые миграции данных** — по образцу `PlanMigration.ObservationWindowsV2.apply(to:)`,
  вызывается из `MainTabView.syncIntroductions()`.
- **Поля CloudKit-safe** — опциональные или с дефолтом; иначе синк не поднимется.
- **Новое ПОЛЕ у существующего типа — без бампа схемы** (`CLAUDE.md`): все
  `VersionedSchema` ссылаются на одни и те же типы, лишняя версия роняет приложение.
- **Право на Pro** — `Entitlements` (`purchased || isEarlyAdopter`), берётся из самой
  ранней записи `AppInstall`.

### Dependencies

Ничего нового. Apple-фреймворки, существующий `Entitlements`.

## Development Approach

**Regular** (код, затем тесты в той же задаче). Репозиторий зелёный: 244 теста,
прогон на устройстве `xcodebuild test-without-building -destination 'id=<DEVICE>'`.

**Покрывается юнит-тестами:**
- Бэкфилл: записи без `childId` привязываются к единственному ребёнку; повторный
  запуск ничего не портит; при нескольких детях бэкфилл НЕ гадает.
- `ActiveChild`: выбор, откат на первого при удалённом/неизвестном id, пустой список.
- Правило Pro: без Pro нельзя добавить второго, но существующие дети остаются
  доступными; с Pro лимита нет.
- `FeedingService` проставляет `childId` во все создаваемые записи.
- Фильтрация: сервисы получают уже отфильтрованные массивы, поэтому проверяем
  предикаты через выборку из in-memory контейнера.

**Не покрывается:** сам рендер экранов и системные листы — проверяется самозапуском.

**Опасное место, требующее осторожности:** бэкфилл трогает данные существующих
пользователей. Он должен быть идемпотентным и никогда не перепривязывать уже
привязанные записи.

## Implementation Steps

### Task 1: Привязка записей к ребёнку

Files:
• Modify: `Sources/Models/FoodLog.swift`, `Sources/Models/IntroductionStatus.swift`,
  `Sources/App/AppSchema.swift`

- [ ] `childId: UUID?` в обеих моделях (опциональное — требование CloudKit и условие
      lightweight-перехода без бампа версии).
- [ ] В `AppSchema.swift` — комментарий, что поле добавлено без новой версии и почему.
- [ ] Написать тесты (round-trip `childId`; запись без `childId` валидна).
- [ ] run project test suite — must pass before Task 2

### Task 2: Бэкфилл существующих записей

Files:
• Modify: `Sources/App/PlanMigration.swift`, `Sources/Features/MainTabView.swift`
• Create: `Tests/PlanMigrationTests.swift` (если нет)

- [ ] `PlanMigration.ChildOwnership.apply(context:)` — если ребёнок ровно ОДИН, все
      записи с `childId == nil` получают его id.
- [ ] **Если детей несколько — не трогаем ничего**: угадывать владельца нельзя.
      Такое состояние возможно только у того, кто уже пользовался мульти-детьми,
      то есть после этого релиза; для существующих пользователей ребёнок всегда один.
- [ ] Идемпотентность: уже привязанные записи не перезаписываются.
- [ ] Вызов из `syncIntroductions()` — там же, где уже живёт `ObservationWindowsV2`.
- [ ] Написать тесты (один ребёнок → всё привязалось; повторный запуск не меняет
      ничего; несколько детей → ни одна запись не тронута; пустой стор не падает).
- [ ] run project test suite — must pass before Task 3

### Task 3: Активный ребёнок

Files:
• Create: `Sources/App/ActiveChild.swift`, `Tests/ActiveChildTests.swift`
• Modify: `Sources/App/RootView.swift`

- [ ] `ActiveChild.storageKey = "app.activeChild"`; чистая функция
      `resolve(children:storedId:) -> Child?` — выбранный, иначе первый, иначе `nil`.
- [ ] `RootView` берёт активного вместо `children.first`; гейт онбординга остаётся
      на `children.isEmpty`.
- [ ] Написать тесты (сохранённый id выбирает нужного; неизвестный id откатывается на
      первого; удалённый ребёнок откатывается на первого; пустой список даёт `nil`).
- [ ] run project test suite — must pass before Task 4

### Task 4: Фильтрация выборок по активному ребёнку

Files:
• Modify: `DashboardView.swift`, `MainTabView.swift`, `CalendarView.swift`,
  `DayDetailView.swift`, `CatalogView.swift`, `FoodDetailView.swift`,
  `AllergensView.swift`, `ProfileView.swift`

- [ ] Во всех `@Query` логов и статусов предикат дополняется `childId == активный`.
- [ ] Предикаты по-прежнему строятся в `init` и остаются **стабильными** между
      проходами `body` — иначе выборка пересоздаётся, что мы уже чинили в перфе.
- [ ] Записи со старым `childId == nil` подхватываются бэкфиллом из Task 2 до первого
      показа; отдельной ветки «или nil» в предикатах НЕ добавляем, иначе чужие записи
      будут видны у второго ребёнка.
- [ ] Написать тесты (выборка с двумя детьми возвращает только записи активного;
      счётчики дашборда и коллекции не смешивают детей).
- [ ] run project test suite — must pass before Task 5

### Task 5: Запись проставляет владельца

Files:
• Modify: `Sources/Services/FeedingService.swift`
• Modify: `Tests/FeedingServiceTests.swift`

- [ ] `FeedingService` получает `childId` и проставляет его во все создаваемые
      `FoodLog` и `IntroductionStatus`.
- [ ] `status(for:)` ищет статус **в пределах ребёнка**: иначе продукт, введённый
      старшему, считался бы введённым и младшему.
- [ ] Написать тесты (созданные записи принадлежат ребёнку; `status(for:)` не находит
      чужой статус; автозавершение ввода считает только свои кормления).
- [ ] run project test suite — must pass before Task 6

### Task 6: Правило Pro и лимит

Files:
• Create: `Sources/Services/ChildLimit.swift`, `Tests/ChildLimitTests.swift`

- [ ] `ChildLimit.canAdd(currentCount:isPro:) -> Bool` — бесплатно один, с Pro без
      ограничения.
- [ ] `ChildLimit.freeLimit = 1` константой, чтобы не размазывать по вьюхам.
- [ ] Написать тесты (0 и 1 ребёнок без Pro: добавить можно только первого; с Pro
      можно всегда; **существующие дети остаются доступными без Pro** — лимит
      ограничивает только добавление).
- [ ] run project test suite — must pass before Task 7

### Task 7: Секция «Дети» в Профиле

Files:
• Modify: `Sources/Features/Profile/ProfileView.swift`,
  `Sources/Features/Onboarding/OnboardingView.swift`,
  `Sources/Features/Profile/ProSheet.swift`

- [ ] Список детей с отметкой активного, тап — переключение.
- [ ] «Добавить ребёнка»: с Pro открывает онбординг в режиме добавления, без Pro —
      `ProSheet`. Молча игнорировать тап нельзя.
- [ ] Удаление ребёнка — с подтверждением и с явным текстом, что удалится и его дневник.
- [ ] В `ProSheet` добавить пункт «Сколько угодно детей».
- [ ] Строки — в `Localizable.xcstrings`, RU + EN.
- [ ] Тестов нет (лист-UI); правило лимита покрыто в Task 6.

### Task 8: Verify acceptance criteria

- [ ] У существующего пользователя после обновления **ничего не изменилось**: его
      дневник на месте, ребёнок один, записи привязались бэкфиллом молча.
- [ ] Без Pro «Добавить ребёнка» открывает экран покупки.
- [ ] С Pro добавляется второй; его дневник **пустой**, записи первого не видны.
- [ ] Переключение между детьми меняет дашборд, календарь, аллергены, каталог и PDF.
- [ ] Продукт, введённый старшему, у младшего показан как невведённый.
- [ ] После «потери» Pro оба ребёнка остаются доступными, блокируется только добавление.
- [ ] Удаление ребёнка уносит его записи и не трогает чужие.
- [ ] Прогон тестов на устройстве зелёный.

### Task 9: Update documentation

- [ ] `CLAUDE.md` — раздел про мульти-детей: `childId`, бэкфилл, активный ребёнок,
      правило «лимит ограничивает добавление, а не доступ».
- [ ] `SPEC.md` — поведение при нескольких детях.
- [ ] `docs/TEST-CASES.md` — новые кейсы.
- [ ] `docs/appstore/ASC-METADATA.md` §8а — добавить детей в состав Pro и в Review Notes.
