# App Store Connect — данные для заполнения

Всё ниже — готово к копипасту в ASC. Бандл: **`com.pudding.app`** (team `A89ST3SFXS`),
app id `6789296295`.

**Статус локализаций (2026-07):** метаданные магазина залиты через ASC REST API на
**15 витрин** — ru, en-US + de-DE, fr-FR, es-ES, es-MX, it, pt-BR, pl, tr, uk, nl-NL,
ja, ko, zh-Hans (name/subtitle + промо/описание/кейворды, всё в лимитах). Заливка —
скриптом (JWT-ключ `XQW63C6NF9`, `.p8` только в `~/.appstoreconnect/private_keys/`,
НЕ в репо). Русский/английский-исходники — ниже; переводы генерились фан-аутом агентов.
⚠️ **Скриншоты пока только для дефолтной локали** — по-языковые не заливались (см. §7).

## 1. Создание приложения (My Apps → «+»)

| Поле | Значение |
|---|---|
| Platform | iOS |
| Name | `Pudding — дневник прикорма` (26/30) |
| Primary language | Russian |
| Bundle ID | `com.pudding.app` (Identifier зарегистрирован; capabilities: iCloud + CloudKit-контейнер `iCloud.com.pudding.app`, Push Notifications) |
| SKU | `pudding-ios-001` |
| User Access | Full |

## 2. App Information

| Поле | Значение |
|---|---|
| Subtitle (RU) | `Первый прикорм и аллергены` (26/30) |
| Primary Category | Health & Fitness (Здоровье и фитнес) |
| Secondary Category | Lifestyle (Образ жизни) |
| Content Rights | **Yes, uses third-party content** (11.08). Иконки — OpenMoji под CC BY-SA 4.0: это лицензированное чужое творчество, и строчка «Иконки: OpenMoji (CC BY-SA 4.0)» видна ревьюеру в Профиле. Раньше стояло No — противоречило самому приложению. Лицензия публичная, при запросе показываем `CREDITS.md` + openmoji.org |
| Age Rating | Все вопросы «None» → **4+** |
| License Agreement | стандартный EULA |

## 3. Pricing

Free, все страны (монетизация придержана — пейвол добавим позже).

## 4. App Privacy

- Privacy Policy URL: `https://pudding-for-children.vercel.app/privacy`
- **Data Collection: «Data Not Collected»** — своего бэкенда нет, аналитики нет,
  трекинга нет. Данные лежат на устройстве и в **приватной базе CloudKit самого
  пользователя**, доступа к ним у нас нет.
  ⚠️ Позиция «Data Not Collected» при CloudKit — трактовка: Apple определяет
  «collect» как передачу данных, к которым **имеет доступ разработчик**; к приватной
  базе доступа нет. Перед сабмитом перечитать актуальную формулировку Apple.

## 5. Версия 1.0 — RU (primary)

**Promotional Text** (170):
```
Дневник прикорма без паники: записывай кормления и реакции, следи за окном наблюдения и не забывай повторять введённые аллергены.
```

**Description**:
```
Pudding — простой и тёплый дневник первого прикорма. Никаких советов и лекций: ты сама решаешь, что и когда давать малышу, а Pudding аккуратно всё записывает.

ЧТО УМЕЕТ:

• Дневник кормлений — записывай продукт, оценку «как зашло», заметку и фото в пару касаний
• Реакции — фиксируй кожные и ЖКТ-реакции с фото, вся история всегда под рукой
• Ввод новых продуктов — своё окно наблюдения для обычных продуктов и аллергенов: продукт становится введённым после нескольких кормлений в разные дни, прогресс «2 из 3 кормлений» прямо на карточке
• Поддержка аллергенов — Pudding напомнит вовремя повторить уже введённый аллерген, чтобы не растерять привыкание
• Коллекция продуктов — стена введённых продуктов пополняется с каждым успехом малыша
• Календарь-лента — вся история по дням, фильтры «реакции» и «планы», планирование ввода на будущее
• PDF для педиатра — вся история кормлений, реакций и статус аллергенов одним документом
• Лист «Не давать» — короткая памятка для няни или садика
• Рекап месяца — красивая карточка «что нового попробовали», которой хочется поделиться
• Свой план — настрой возраст старта, окна наблюдения, частоту и список аллергенов под рекомендации своего педиатра
• Свои продукты — добавляй то, чего нет в каталоге
• 14 языков, светлая и тёмная тема, маскот Пудинг

БЕЗ УЧЁТКИ И БЕЗ НАШИХ СЕРВЕРОВ: записи хранятся на твоём телефоне и синхронизируются через твой личный iCloud.

Pudding — дневник, а не доктор: приложение ничего не назначает и не советует. Все решения о питании малыша принимайте вместе с педиатром.
```

**Keywords** (100):
```
прикорм,дневник,малыш,аллергены,ввод,продукты,кормление,реакция,ребёнок,питание,бэби,еда
```

**What's New (1.0)**: `Первый релиз 🍮`

- Support URL: `https://pudding-for-children.vercel.app`
- Marketing URL: `https://pudding-for-children.vercel.app`

## 6. Версия 1.0 — EN (добавить локализацию English (U.S.))

- Name: `Pudding — Baby Food Diary` (25/30)
- Subtitle: `First foods & allergens` (23/30)

**Promotional Text**:
```
A calm first-foods diary: log feedings and reactions, watch the observation window, and keep introduced allergens on schedule.
```

**Description**:
```
Pudding is a simple, warm diary for starting solids. No lectures, no advice — you decide what and when to feed your baby; Pudding just keeps a neat record.

WHAT IT DOES:

• Feeding diary — log a food, a “how it went” rating, a note and photos in a couple of taps
• Reactions — record skin and tummy reactions with photos; the full history is always at hand
• Introducing new foods — separate observation windows for regular foods and allergens: a food counts as introduced after a few feedings on different days, with «2 of 3 feedings» progress right on the food card
• Allergen maintenance — gentle reminders to repeat introduced allergens so tolerance isn’t lost
• Food collection — a wall of introduced foods that fills up with every little win
• Calendar feed — full history by day, “reactions” and “plans” filters, plan future introductions
• PDF for your pediatrician — feedings, reactions and allergen status in one document
• “Do not give” sheet — a one-page memo for the nanny or daycare
• Monthly recap — a shareable card of everything new your baby tried
• Your own plan — set the starting age, observation windows, allergen frequency and list to match your pediatrician’s guidance
• Custom foods, 14 languages, light and dark themes, and Pudding the mascot

NO ACCOUNT, NO SERVERS OF OURS: your records stay on your phone and sync through your own iCloud.

Pudding is a diary, not a doctor: it prescribes nothing and advises nothing. Make all feeding decisions together with your pediatrician.
```

**Keywords** (100):
```
baby,solids,first foods,weaning,blw,allergen,tracker,diary,feeding,reaction,food,infant,log
```

## 7. Скриншоты (обязательно 6.9" iPhone; RU + EN)

Снять на iPhone 17 (тёмный статусбар, наполненные данные — можно `-seedSample`):
1. Главная «Стена Pudding» (маскот, плитки, коллекция)
2. Карточка продукта «вводится» (кольцо «2 из 3 кормлений»)
3. Календарь-лента с фильтрами
4. Аллергены (сводка «пора освежить»)
5. PDF для педиатра (превью share) или Рекап месяца
6. Запись кормления (оценка + фото)

## 8. App Review Information

| Поле | Значение |
|---|---|
| Sign-in required | **No** (учётки нет) |
| Contact | Evgeny Varzin · woodoo201818@gmail.com *(⚠️ подтвердить ящик — TODO из AppLinks)* |
| Notes | см. ниже |

**Review Notes** (перезалиты через API 14.08 — ответ на реджект 2.1, лимит 4000 символов;
полный ответ в Resolution Center — `docs/appstore/REVIEW-REPLY-2.1.md`):
```
Pudding is an offline diary for a baby's first solid foods. No account, no backend, no third-party SDKs, no in-app purchases.

1. DEMO VIDEO: attached, captured on a physical iPhone 17 running iOS 26.6 with the built-in iOS screen recorder. It begins with launching the app from the Home screen and walks through the full typical flow described in item 4, including the notification prompt. The app has NO registration/login/account deletion, NO paid content, IAP or subscriptions, NO user-generated content shared between users, and NO ATT prompt. The only system prompt is the notification request, shown in the video; the app works fully if it is denied. Photos are attached via the system PhotosPicker; the photo library is never requested.

2. TESTED ON: iPhone 17 (iPhone18,3) / iOS 26.6 - primary device, full manual pass plus automated unit and UI tests; iPhone 15 Pro Max (iPhone16,2) / iOS 26.6; iPhone 13 (iPhone14,5) / iOS 26.4. Tests also run on iPhone simulators from iOS 18.2 to 26.4, Xcode 26.4. iPhone only.

3. WHAT IT DOES / FOR WHOM: for parents of infants roughly 4-12 months old. When solids start, a new food is given every few days and the parent must remember which food, when, and how the child reacted - usually kept on paper. Pudding keeps that record: a bundled food catalog, a per-food introduction the parent starts manually, a feeding log (date, portion, how the child liked it, reaction, note, photo), a calendar diary, introduced allergens with reminders to repeat them, and a PDF export for the pediatrician. It is a diary, not an advisor: no medical advice, no diagnosis, it never tells a parent what or when to feed. Every plan parameter (start age, observation windows, allergen list and frequency) is set by the user. A medical disclaimer is an onboarding step shown BEFORE any child data is entered, and stays in Profile - About.

4. SETUP / ACCESS: nothing required - no account, no credentials, no sample files. Install and open. Onboarding: welcome -> disclaimer ("Before you start") -> child's name and birth date -> feeding plan -> optional list of foods already introduced -> "Let's go"; notifications are requested afterwards. Today tab: today's journal and foods being introduced. Catalog tab: search (in the interface language), open a food -> "Start introducing" -> "Log a feeding"; a food becomes introduced automatically after feedings on several DIFFERENT days (2 by default, 3 for allergens). Allergens tab: repeat reminders. Calendar tab: the full diary. Profile tab: child, plan, language, PDF export, recap card, About (disclaimer, privacy policy, terms, support, credits).

5. EXTERNAL SERVICES: none. Apple frameworks only (SwiftUI, SwiftData, UserNotifications, PhotosUI, PDFKit), no third-party packages. No backend of ours, no authentication, no payment processor, no analytics or ads, no AI, no external data provider. The food catalog is a static JSON file bundled in the app. The only network use is Apple CloudKit, syncing to the user's own private database in their personal iCloud; we have no access to it. Hence "Data Not Collected". The "remote-notification" background mode exists only so CloudKit can deliver silent sync pushes - we run no push server; every reminder is a local notification.

6. REGIONS: no regional differences. Identical features and content everywhere, free in all territories, no IAP, no server-side configuration. The UI is localized into 14 languages and follows the device language; that affects wording only, never functionality.

7. REGULATED INDUSTRY / THIRD-PARTY MATERIAL: not a medical device, no medical or diagnostic service, no HealthKit, no clinical records - it only stores what the parent types and points the user to their pediatrician. The only third-party material is the OpenMoji icon set (openmoji.org) under Creative Commons BY-SA 4.0, which allows use with attribution; the credit "Icons: OpenMoji (CC BY-SA 4.0)" is shown in Profile - About. All other assets and text are ours.
```

## 9. Технические перед загрузкой билда

- [x] `ITSAppUsesNonExemptEncryption = NO` (в project.yml — вопрос про шифрование не будет всплывать)
- [x] Зарегистрировать bundle id `com.pudding.app` в Developer Portal
- [x] Archive → Distribute (Xcode Organizer) — билды 1 (23.07) и 2 (25.07) залиты, оба `VALID`
- [x] Деплой privacy/terms на лендинге — `pudding-for-children.vercel.app/privacy` и `/terms` (200)
- [x] `MARKETING_VERSION` = `1.0.0` в `project.yml`
- [ ] Пересобрать и прикрепить свежий билд: к версии 1.0 привязан build 1, после него были
      коммиты по UI и локализации
- [x] **Review Notes** (§8) залиты через API
- [ ] ⚠️ Подтвердить support-email (`AppLinks.supportEmail` = `woodoo201818@gmail.com`)
- [x] Privacy Policy URL проставлен во всех 15 локалях

Полный чек-лист сабмита: `docs/SUBMISSION.md`.
