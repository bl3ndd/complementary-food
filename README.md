# Прикорм (Prikorm)

iOS-дневник прикорма: каталог продуктов, ввод по одному с окном наблюдения, трекер
поддержки аллергенов и еженедельные напоминания. SwiftUI + SwiftData (iOS 17+),
русский UI, без бэкенда (каталог — статический JSON в бандле).

Рабочее имя приложения — **«Pudding»** (`CFBundleDisplayName`; внутренний таргет
пока `Prikorm`). Бренд-маскот — пудинг-персонаж `Mascot` в `Features/Common/`
(векторный SwiftUI-плейсхолдер; меняет настроение под контекст).

См. полное ТЗ в [SPEC.md](SPEC.md).

## Четыре опоры

1. **Каталог продуктов** — браузер по категориям + поиск (`FoodCatalog`, CatalogView)
2. **Аллергены** — статусы поддержки + поддержка толерантности (`AllergenTracker` /
   `AllergenMaintenance`, AllergensView)
3. **Календарь** — ежедневный таймлайн введений (`CalendarService`, CalendarView /
   DayDetailView)
4. **Напоминания** — еженедельные локальные пуши по «протухшим» аллергенам
   (`NotificationManager`)

## Стек

- SwiftUI + SwiftData (iOS 17.0+)
- UserNotifications — локальные напоминания
- Только Apple-фреймворки, без сторонних зависимостей
- Проект генерируется [XcodeGen](https://github.com/yonaskolb/XcodeGen) из `project.yml`
- Bundle id `com.prikorm.app`

## Сборка и запуск

Требуется Xcode 15+ и XcodeGen (`brew install xcodegen`).

```sh
# 1. Сгенерировать Prikorm.xcodeproj из project.yml
xcodegen generate

# 2. Открыть в Xcode и запустить на симуляторе iOS 17+
open Prikorm.xcodeproj
```

Или из командной строки:

```sh
xcodebuild -project Prikorm.xcodeproj -scheme Prikorm \
  -destination 'platform=iOS Simulator,name=iPhone 15' build
```

Каждый раз после правки `project.yml` (новые файлы/таргеты) — перезапускай
`xcodegen generate`.

### Отладочные данные

Сэмпл-данные (ребёнок + логи) сидируются под флагом запуска `-seedSample` в DEBUG —
добавь его в схему (Run → Arguments) или передай при `xcodebuild`/`simctl launch`.

## Тесты

Юнит-тесты лежат в `Tests/` (таргет `PrikormTests`, `@testable import Prikorm`):

```sh
xcodebuild -project Prikorm.xcodeproj -scheme Prikorm \
  -destination 'platform=iOS Simulator,name=iPhone 15' test
```

Логика сосредоточена в сервис-слое и моделях, поэтому покрывается без UI. Подробнее о
конвенциях тестирования — в [CLAUDE.md](CLAUDE.md).

## Структура

```
Sources/
  App/          PrikormApp, RootView, SampleData
  Models/       Child, IntroductionStatus, FoodLog (@Model);
                Food, FeedingProfile, Enums (value types)
  Services/     FoodCatalog, FeedingService, AllergenTracker,
                AllergenMaintenance, CalendarService, NotificationManager
  Features/     MainTabView + Dashboard / Catalog / Allergens /
                Calendar / Profile / Onboarding / Common
Resources/      foods.json (статический каталог), Media.xcassets
Tests/          юнит-тесты сервисов и моделей
docs/plans/     планы разработки
```
