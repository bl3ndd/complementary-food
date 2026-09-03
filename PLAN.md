# Pro-версия Pudding: разовая покупка + «приятности»

## Overview

Первая монетизация приложения: **разовая непотребляемая покупка** «Pudding Pro»,
открывающая набор необязательных, эмоциональных возможностей — рекап-карусель для
сторис, цветовые темы, альтернативные иконки и виджет «Коллекция». Модель выбрана
разовой, а не подпиской: окно жизни продукта ~4–12 месяцев ребёнка, и подписка на
такой срок даёт отписки, возвраты и злые отзывы вместо выручки.

Право на Pro = **куплено ИЛИ ранний пользователь**. Обещание «ранним — пожизненно
бесплатно» уже подкреплено записью `AppInstall` (`Sources/Models/AppInstall.swift`),
и первый релиз с пейволом обязан его исполнить с первого запуска, без «восстановить».

Бесплатным навсегда остаётся всё, что составляет сам дневник: каталог, вводы,
кормления, реакции, фото, заметки, аллергены с напоминаниями, календарь,
iCloud-синк, мульти-профили, **PDF «для педиатра»**, **лист «Не давать»**,
**одиночная рекап-карточка** (крючок к карусели) и **фото ребёнка**. Принцип
раздела: платим за необязательное и приятное, не платим за доступ к собственным
данным и за то, что нужно в момент, когда с ребёнком что-то не так.

**Не входит в этот план:**
- **Подписка и любые расходуемые покупки** — модель выбрана разовой, обсуждение закрыто.
- **Переезд интерфейса на Liquid Glass целиком** — `deploymentTarget: iOS 17.0`
  (`project.yml`), а API доступны с 26. Новые экраны используют системные материалы
  через `if #available`, существующие вьюхи не трогаем.
- **«Год еды»** (годовой рекап в духе Wrapped) — сезонная фича, отдельный релиз в декабре.
- **Экран покупки с A/B и аналитикой конверсии** — аналитики в приложении нет и не
  планируется («Data Not Collected»); эффективность оцениваем по выручке в ASC.
- **Изменение цены и территорий** — заводится в ASC руками, кодом не управляется.

## Context

### Files involved

**Создаём:**
- `Sources/Services/Entitlements.swift` — единственный ответ на вопрос «открыт ли Pro»:
  `isPro`, `isEarlyAdopter`, сравнение `AppInstall.firstVersion` с `proVersion`.
- `Sources/Services/ProStore.swift` — обёртка StoreKit 2: загрузка продукта,
  покупка, `Transaction.currentEntitlements`, восстановление, слушатель обновлений.
- `Sources/Features/Common/Palette.swift` — тип палитры (набор токенов) + список
  готовых палитр; `Theme` начинает читать активную палитру.
- `Sources/Features/Profile/ProSheet.swift` — экран покупки.
- `Sources/Features/Calendar/RecapCarouselView.swift` — свайп-карусель карточек.
- `Sources/Features/Calendar/RecapCards.swift` — сами карточки: коллекция-постер,
  веха, «первый раз», топ-5, календарь вкусов.
- `Sources/App/AppIconManager.swift` — смена альтернативной иконки.
- `Sources/App/WidgetSnapshot.swift` — запись снимка коллекции в App Group.
- `PuddingWidget/` — новый таргет расширения (виджет «Коллекция»).
- `Tests/EntitlementsTests.swift`, `Tests/PaletteTests.swift`,
  `Tests/RecapCardsTests.swift`, `Tests/AppIconManagerTests.swift`,
  `Tests/WidgetSnapshotTests.swift`.
- `Prikorm.storekit` — конфигурация StoreKit для локального тестирования покупки.

**Меняем:**
- `Sources/Models/Child.swift` — добавляется `photo: Data?`
  (`@Attribute(.externalStorage)`) под фото ребёнка.
- `Sources/App/AppSchema.swift` — `AppSchemaV3` + стадия `.lightweight` в
  `AppMigrationPlan`; `AppSchemaCurrent` переключается на V3. **Старые версии не править.**
- `Sources/Features/Common/Theme.swift` — токены (`accent`, `bgTop`, `bgBottom`,
  `card`, `fill`, `hairline`, `cardStroke`) начинают браться из активной палитры;
  `Theme.dynamic` остаётся как есть.
- `Sources/App/AppTheme.swift` — рядом с выбором светлая/тёмная появляется хранение
  выбранной палитры (`@AppStorage("app.palette")`).
- `Sources/Features/Profile/ProfileView.swift` — в `appSection` пикер палитры и
  строка иконки приложения; новая секция Pro со статусом и кнопкой покупки;
  в `aboutSection` строка «Ранний пользователь» получает пометку «Pro открыт».
- `Sources/Features/Calendar/RecapView.swift` — `RecapSheet` становится входом в
  карусель; одиночная `RecapCard` остаётся бесплатной; шэр учитывает палитру.
- `Sources/Services/RecapService.swift` — добавляются выборки под новые карточки:
  вехи, «первый раз», топ-5 любимых/нелюбимых, дни месяца с новым продуктом.
- `Sources/Features/Onboarding/OnboardingView.swift` — необязательный шаг «фото малыша».
- `project.yml` — таргет `PuddingWidget`, App Group в entitlements обоих таргетов,
  `INFOPLIST_KEY_CFBundleAlternateIcons` под альтернативные иконки.
- `Resources/Media.xcassets` — наборы альтернативных иконок.
- `docs/appstore/ASC-METADATA.md`, `docs/SUBMISSION.md`,
  `docs/appstore/GUIDELINES-AUDIT.md` — IAP, 3.1.1, Family Sharing, новые Review Notes.
- `CLAUDE.md` — раздел про Pro, палитры и виджет.

### Related patterns

- **Сервисы — чистые функции над данными** (`AllergenMaintenance`, `RecapService`,
  `FeedingService`): без чтения системных часов внутри, `now`/`calendar` инъектируются.
  `Entitlements` и `RecapService` расширяем в том же стиле.
- **Seam над системным API** — `NotificationManager` ходит в `UNUserNotificationCenter`
  через протокол `NotificationScheduling`, а тесты подсовывают мок. `ProStore` строится
  так же: протокол над StoreKit, тесты не трогают реальный StoreKit.
- **Схема версионируется** (`AppSchema.swift`): новая модель/поле = новая
  `VersionedSchema` + стадия миграции. Все поля CloudKit-safe: опциональные или с дефолтом.
- **Тема адаптивная**, в вьюхах только семантические токены `Theme.card` / `Theme.fill` /
  `Theme.hairline` / `Theme.cardStroke` — не литералы `.white` и `Color.black.opacity(…)`.
- **Исключение из адаптивности** — `RecapCard`: это шэр-картинка, принудительно светлая
  (`.environment(\.colorScheme, .light)`). Палитра к ней применяется явно, а не через среду.
- **Локализация**: ключи = русские строки в `Resources/Localizable.xcstrings`, минимум
  `en` для каждой новой строки; `Text(переменная)` не локализуется — модельные строки
  возвращают `String(localized:)`.
- **Анимации уважают** `accessibilityReduceMotion` (`Delight.swift`).

### Dependencies

- **StoreKit 2** (системный, iOS 17+) — `Product`, `Transaction`, `Product.PurchaseResult`.
- **WidgetKit** + **App Group** — новый таргет и общий контейнер.
- Apple-фреймворки только, сторонних пакетов не добавляем.
- **Заводится пользователем вне кода:** non-consumable в App Store Connect
  (product id, цена, Family Sharing = on), локализации названия покупки,
  App Group id в аккаунте разработчика, скриншот покупки для ревью.

## Development Approach

**Подход — Regular (код, затем тесты в той же задаче).** Репозиторий уже в зелёном:
`PrikormTests` покрывает сервисы и модели, прогон на устройстве
(`xcodebuild test-without-building -destination 'id=<DEVICE>'`), симуляторы не используем.

**Что покрывается юнит-тестами** (детерминированная логика):
- `Entitlements` — сравнение версий, ранний/не ранний, отсутствие `AppInstall`,
  мусорная строка версии, покупка перекрывает всё.
- `Palette` — полнота набора токенов, контраст текста к фону, отсутствие кислотных
  значений (проверяем насыщенность), стабильность id для `@AppStorage`.
- `RecapService` — новые выборки: вехи на границах, «первый раз» по самой ранней
  записи, топ-5 при равенстве оценок, календарь вкусов по дням месяца.
- `WidgetSnapshot` — сериализация/десериализация, ограничение размера, пустой стор.
- `AppIconManager` — маппинг палитры/выбора на имя иконки, `nil` = основная.

**Что юнит-тестами не покрывается и почему:**
- **Сама покупка** — `Product.purchase()` требует живой сессии App Store. Тестируем
  протоколом-моком (логика «после успешной покупки `isPro == true`») плюс ручной
  прогон на устройстве с `Prikorm.storekit`. В юнит-тестах реальный StoreKit не дёргаем.
- **Смена иконки** — `UIApplication.setAlternateIconName` работает только в живом
  приложении; тестируем чистый маппинг, само переключение проверяем запуском.
- **Виджет** — рендер WidgetKit проверяется только на устройстве; тестируем снимок данных.
- **Вид карточек карусели** — тестируем данные (`RecapService`), а не пиксели;
  визуально проверяем самозапуском на iPhone.

**Плейсхолдеры, которые проставит пользователь:**
- `ProStore.productId` — `com.pudding.app.pro` (черновик; финальный из ASC).
- App Group — `group.com.pudding.app` (создать в аккаунте разработчика).
- Цена — ставится в ASC, в коде не хардкодится: показываем `product.displayPrice`.
- `Entitlements.proVersion` — версия, с которой Pro платный; поставить фактическую
  (`1.1.0`) в момент выпуска, не раньше.

## Implementation Steps

### Task 1: Шов Entitlements

Files:
• Create: `Sources/Services/Entitlements.swift`
• Create: `Tests/EntitlementsTests.swift`

- [ ] `struct Entitlements` с полями `install: AppInstall?`, `purchased: Bool`,
      `proVersion: String` (инъектируется, дефолт — константа).
- [ ] `var isEarlyAdopter: Bool` — `install.firstVersion` ниже `proVersion`, сравнение
      через `compare(options: .numeric)`; при пустой или непарсящейся версии откат на
      `firstLaunchedAt < proReleaseDate` (тоже инъектируется) — щедро, а не строго:
      человек, реально пришедший рано, не должен терять статус из-за поля.
- [ ] `var isPro: Bool { purchased || isEarlyAdopter }`.
- [ ] Ничего не читает из системных часов и не ходит в StoreKit — только данные на входе.
- [ ] Написать тесты (нет `AppInstall` → не Pro; `1.0.0` при `proVersion 1.1.0` → ранний;
      `1.1.0` и `1.2.0` → не ранний; `1.10.0` vs `1.9.0` — численное сравнение, а не
      лексикографическое; пустая версия + ранняя дата → ранний; `purchased` перекрывает всё).
- [ ] run project test suite — must pass before Task 2

### Task 2: Обёртка StoreKit 2

Files:
• Create: `Sources/Services/ProStore.swift`
• Create: `Prikorm.storekit`
• Create: `Tests/ProStoreTests.swift`
• Modify: `project.yml`

- [ ] Протокол `ProPurchasing` (`products()`, `purchase()`, `currentEntitlements()`,
      `restore()`) — seam ровно как `NotificationScheduling` у `NotificationManager`.
- [ ] `ProStore: ProPurchasing` поверх StoreKit 2: `Product.products(for:)`,
      `product.purchase()`, разбор `Product.PurchaseResult` (`.success` с верификацией,
      `.userCancelled`, `.pending`), `Transaction.currentEntitlements`,
      `Transaction.updates` слушателем на старте.
- [ ] `@Observable` (или `ObservableObject`) состояние: `product`, `isPurchased`,
      `isLoading`, `lastError` — чтобы вьюха не знала про StoreKit.
- [ ] `Prikorm.storekit` с одним non-consumable `com.pudding.app.pro` для локального прогона.
- [ ] `project.yml`: подключить `.storekit` к схеме Prikorm (Run action).
- [ ] Написать тесты на моке `ProPurchasing` (успешная покупка → `isPurchased`;
      отмена не выставляет флаг и не пишет ошибку; `pending` не выставляет флаг;
      восстановление поднимает флаг; ошибка сети попадает в `lastError` и не роняет).
- [ ] run project test suite — must pass before Task 3

### Task 3: Палитры оформления

Files:
• Create: `Sources/Features/Common/Palette.swift`
• Create: `Tests/PaletteTests.swift`
• Modify: `Sources/Features/Common/Theme.swift`, `Sources/App/AppTheme.swift`

- [ ] `struct Palette: Identifiable` — `id: String`, `title` (через `String(localized:)`),
      `isPro: Bool` и набор пар (светлая, тёмная) под токены: `accent`, `accentDeep`,
      `bgTop`, `bgBottom`, `card`, `fill`, `hairline`, `cardStroke`.
- [ ] `Palette.all`: **Пудинг** (текущая, бесплатная) + Pro-палитры **Зефир**, **Матча**,
      **Лаванда**, **Персик**, **Молоко и мёд**, **Черника**. Приглушённые, десатурированные:
      один акцент на палитру, фон почти нейтральный. Никакого неона.
- [ ] `Palette.current` читается из `@AppStorage("app.palette")`; неизвестный или
      Pro-id без права → откат на «Пудинг» (потеря Pro не должна ломать вид).
- [ ] `Theme` берёт значения токенов из активной палитры; сигнатуры токенов и
      `Theme.dynamic` не меняются, чтобы вьюхи не трогать.
- [ ] Написать тесты (у каждой палитры заполнены все токены; id уникальны и стабильны;
      «Пудинг» не Pro, остальные Pro; акцент каждой палитры отличается от фона по
      яркости не меньше порога; насыщенность акцента не превышает потолок — защита от
      кислоты; неизвестный id даёт «Пудинг»).
- [ ] run project test suite — must pass before Task 4

### Task 4: Данные для карточек карусели

Files:
• Modify: `Sources/Services/RecapService.swift`
• Create: `Tests/RecapCardsTests.swift`

- [ ] `struct CollectionPoster` — все введённые продукты по порядку ввода + счётчик.
- [ ] `struct Milestone` — ближайшая достигнутая веха (10/25/50 продуктов) и дата.
- [ ] `struct FirstTime` — самая ранняя запись по продукту: продукт, дата, оценка, фото.
- [ ] `struct TastesTop` — топ-5 «понравилось» и топ-5 «не понравилось» по оценкам,
      детерминированный tie-break по дате первой записи (не по случайному порядку словаря).
- [ ] `struct TasteCalendar` — дни месяца, в которые появился новый продукт.
- [ ] Всё считается за один проход по журналу, `now`/`calendar` инъектируются.
- [ ] Написать тесты (веха ровно на границе 10 и на 9; «первый раз» берёт самую раннюю
      запись, планы игнорируются; топ-5 при равенстве оценок стабилен между прогонами;
      календарь вкусов помечает день только для впервые введённого; пустой журнал даёт
      пустые структуры, а не падение).
- [ ] run project test suite — must pass before Task 5

### Task 5: Рекап-карусель и карточки

Files:
• Create: `Sources/Features/Calendar/RecapCards.swift`, `Sources/Features/Calendar/RecapCarouselView.swift`
• Modify: `Sources/Features/Calendar/RecapView.swift`

- [ ] Карточки на данных из Task 4, в едином формате шэр-картинки: воздух, крупная
      цифра, подпись мелким весом, фото как герой. Без градиентных подложек, свечений
      и блёсток — по `human-not-ai-design`.
- [ ] `RecapCarouselView` — горизонтальный пейджинг по карточкам, шэр текущей через
      `ImageRenderer` (как уже сделано в `RecapSheet.share()`).
- [ ] Карточки красятся активной палитрой явно (не через `colorScheme`), сохраняя
      принудительно светлый режим `RecapCard`.
- [ ] Бесплатно — одиночная месячная карточка; карусель под `Entitlements.isPro`,
      у бесплатного пользователя показывается превью и кнопка в `ProSheet`.
- [ ] Анимации уважают `accessibilityReduceMotion`.
- [ ] Тестов на пиксели нет — вся логика вынесена в `RecapService` и покрыта в Task 4;
      вид проверяется самозапуском на iPhone.

### Task 6: Экран покупки и Pro в Профиле

Files:
• Create: `Sources/Features/Profile/ProSheet.swift`
• Modify: `Sources/Features/Profile/ProfileView.swift`

- [ ] `ProSheet` — что входит в Pro списком, `product.displayPrice` (не хардкод),
      кнопка покупки, **кнопка «Восстановить покупки»** (требование Apple),
      ссылки на условия и политику.
- [ ] В `appSection` — пикер палитры (Pro-палитры с замком) и строка выбора иконки.
- [ ] Новая секция Pro: у купившего и у раннего — «Открыт», у остальных — кнопка.
- [ ] Ранний пользователь видит Pro открытым **без нажатия «восстановить»**;
      строка в `aboutSection` про пожизненный доступ остаётся и получает пометку.
- [ ] Все новые строки — в `Localizable.xcstrings` с русским ключом и `en`.
- [ ] Тестов нет (лист-UI); логика права уже покрыта в Task 1, покупка — в Task 2.

### Task 7: Фото ребёнка (бесплатно) + схема V3

Files:
• Modify: `Sources/Models/Child.swift`, `Sources/App/AppSchema.swift`,
  `Sources/Features/Profile/ProfileView.swift`, `Sources/Features/Onboarding/OnboardingView.swift`
• Modify: `Tests/ModelTests.swift`

- [ ] `Child.photo: Data?` с `@Attribute(.externalStorage)` — опциональное, CloudKit-safe.
- [ ] `AppSchemaV3` = `AppSchemaV2.models` с обновлённым `Child`; стадия
      `.lightweight(from: V2, to: V3)`; `AppSchemaCurrent = AppSchemaV3`. V1/V2 не трогать.
- [ ] Загрузка через `PhotosPicker` (как уже сделано в `UIHelpers.swift`) — доступ к
      галерее не запрашивается, purpose string не нужен.
- [ ] Фото подставляется в карточки карусели как герой.
- [ ] Написать тесты (миграция V2→V3 на in-memory контейнере не теряет данные;
      `Child` без фото валиден; фото сохраняется и читается обратно).
- [ ] run project test suite — must pass before Task 8

### Task 8: Альтернативные иконки

Files:
• Create: `Sources/App/AppIconManager.swift`, `Tests/AppIconManagerTests.swift`
• Modify: `project.yml`, `Resources/Media.xcassets`

- [ ] Наборы иконок под палитры (1024×1024, **без прозрачности, без своих скруглений
      и бевелей** — система накладывает блики сама).
- [ ] `INFOPLIST_KEY_CFBundleAlternateIcons` в `project.yml` с именами наборов.
- [ ] `AppIconManager` — чистый маппинг «выбор → имя иконки» (`nil` = основная) и
      отдельный метод, дёргающий `UIApplication.setAlternateIconName`.
- [ ] Смена иконки только при `isPro`; при потере права — молчаливый откат на основную.
- [ ] Написать тесты (маппинг для каждой палитры; основная даёт `nil`; неизвестный
      выбор не бросает; без Pro маппинг возвращает основную).
- [ ] run project test suite — must pass before Task 9

### Task 9: Виджет «Коллекция»

Files:
• Create: `PuddingWidget/` (таргет), `Sources/App/WidgetSnapshot.swift`,
  `Tests/WidgetSnapshotTests.swift`
• Modify: `project.yml`, `Sources/Features/MainTabView.swift`

- [ ] **Данные через снимок, а не общий стор.** Приложение пишет в App Group маленький
      JSON (id последних введённых продуктов + счётчик), виджет его читает. Переносить
      SwiftData-стор в App Group нельзя: это миграция существующих пользователей и
      риск для CloudKit ради виджета.
- [ ] `WidgetSnapshot` — запись/чтение, ограничение числа продуктов (влезающее в
      medium), атомарная запись.
- [ ] Обновление снимка при изменении журнала (там же, где сейчас `completeDueIntroductions`
      в `MainTabView.task`) + `WidgetCenter.shared.reloadAllTimelines()`.
- [ ] Таргет `PuddingWidget` в `project.yml`, App Group в entitlements обоих таргетов.
- [ ] Виджет small/medium — растущая сетка иконок; **системные материалы**, свои тени
      и градиенты не добавляем.
- [ ] Написать тесты (снимок сериализуется и читается обратно; пустой стор даёт пустой
      снимок, а не падение; число продуктов обрезается до лимита; порядок — по дате ввода).
- [ ] run project test suite — must pass before Task 10

### Task 10: App Store Connect и Review Notes

Files:
• Modify: `docs/appstore/ASC-METADATA.md`, `docs/appstore/GUIDELINES-AUDIT.md`,
  `docs/SUBMISSION.md`

- [ ] Завести non-consumable в ASC: product id, цена, **Family Sharing = on**,
      локализованные название и описание.
- [ ] **Переписать Review Notes.** Сейчас в них и в ответе на реджект 2.1 прямым
      текстом «NO paid content, IAP or subscriptions» — с релизом это станет ложью,
      и ревьюер найдёт расхождение. Указать: одна разовая покупка, что в неё входит,
      что дневник целиком бесплатный, что ранние пользователи получают Pro бесплатно.
- [ ] В `GUIDELINES-AUDIT.md` обновить строки 2.1(b) и 3.1.1.
- [ ] Тестов нет — документация и внешняя система.

### Task 11: Verify acceptance criteria

- [ ] Ранний пользователь (`AppInstall.firstVersion` ниже `proVersion`) видит Pro
      открытым **сразу после установки**, ничего не нажимая.
- [ ] Новый пользователь видит замки на палитрах, иконках и карусели; после покупки —
      всё открывается без перезапуска.
- [ ] «Восстановить покупки» возвращает Pro на чистой установке с тем же Apple ID.
- [ ] Покупка делится через Family Sharing на второго родителя.
- [ ] Отмена покупки не выставляет Pro и не показывает ошибку.
- [ ] Дневник, PDF «для педиатра», лист «Не давать», синк, мульти-профили и одиночная
      рекап-карточка работают **без Pro**.
- [ ] Карусель листается, каждая карточка шэрится картинкой, палитра применяется к
      тому, что уходит в сторис.
- [ ] Смена палитры применяется сразу, без перезапуска; смена иконки — с системным алертом.
- [ ] Виджет показывает растущую коллекцию и обновляется после новой записи.
- [ ] Тёмная тема не сломана ни в одной палитре (прогнать `DarkModeAuditUITests`).
- [ ] Вся новая логика покрыта юнит-тестами; полный прогон зелёный на устройстве.

### Task 12: Update documentation

- [ ] `CLAUDE.md` — раздел про Pro: право = куплено ИЛИ ранний, где живёт seam,
      правило «не паволить экспорт данных», палитры и правило приглушённости,
      виджет через снимок в App Group (и почему не через общий стор).
- [ ] `SPEC.md` — раздел про Pro и что остаётся бесплатным.
- [ ] `docs/TEST-CASES.md` — новые кейсы по правам, палитрам, карусели, снимку виджета.
- [ ] `README.md` — про `Prikorm.storekit` и как прогонять покупку локально.
