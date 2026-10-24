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
- **С версии 1.2 — НЕ «Data Not Collected».** Появилась анонимная статистика
  (TelemetryDeck, `Sources/Services/Analytics.swift`). До сабмита 1.2 руками в ASC
  (API для ярлыка нет): App Privacy → **Data Not Linked to You → Product Interaction**,
  цель **Analytics**, не используется для трекинга. Совпадает с `PrivacyInfo.xcprivacy`.
  В Review Notes 1.2 пункт EXTERNAL SERVICES переписать: «TelemetryDeck (anonymous
  feature-usage counts, no diary content, opt-out in Profile)» вместо «no analytics,
  no third-party packages».

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

## 8а. Покупка Pro — ЗАВЕДЕНА В ASC (12.10.2026)

| Поле | Значение |
|---|---|
| Тип | **Non-Consumable** (разовая покупка, НЕ подписка) |
| Product ID | `com.pudding.app.pro` (совпадает с `ProProductID.pro`) |
| ID в ASC | `6821919233` |
| Family Sharing | включено — родителей двое, платить дважды они не должны |
| Цена | базовая территория **USA, $4.99**; остальные страны Apple вывел сам |
| Локализации | 15/15, имя «Pudding Pro», описание ≤45 символов на витрину |
| Состояние | `MISSING_METADATA` — **не хватает скриншота для ревью** |

**Скриншот для ревью** (`appStoreReviewScreenshot`) обязателен, без него покупку не
отправить. Снять можно только с живого экрана Pro: `devicectl` команды screenshot не
имеет, симуляторы запрещены — значит кадр делает человек на телефоне (Профиль →
«Pudding Pro»), дальше загрузка через API.

**Что входит в Pro:** рекап-карусель, цветовые гаммы, альтернативные иконки,
виджет «Коллекция», **несколько детей** (бесплатно — один). **Что остаётся бесплатным:**
весь дневник, аллергены с напоминаниями, календарь, iCloud-синк, PDF «для педиатра»,
лист «Не давать», одиночная рекап-карточка, фото ребёнка.

### Review Notes 1.1.0 — залиты в ASC (21.10.2026, build 7: два виджета, iCloud по согласию, AppTransaction)

Лимит Apple — 4000 символов (сейчас ~3950).

```
Pudding is an offline diary for a baby's first solid foods. No account, no backend, no third-party SDKs.

1. IN-APP PURCHASE (new in 1.1.0): exactly ONE non-consumable product, "Pudding Pro" (com.pudding.app.pro) - a ONE-TIME purchase, NOT a subscription, Family Sharing enabled. No trial, no auto-renewal, no account. It unlocks optional extras only: a carousel of shareable recap cards, colour themes, alternate app icons, the "Collection" Home Screen widget (the "Introducing now" widget is free), and diaries for more than one child (the first child is free). Everything holding the user's own data stays free forever and is never gated: the whole diary, allergens, calendar, iCloud sync, the PDF export for a pediatrician, the single recap card, the child's photo. Purchase screen: Profile > "Pudding Pro" - StoreKit price, "Restore purchases", terms and privacy links.

2. WHY PRO MAY LOOK ALREADY UNLOCKED: users who installed before 1.1.0 were promised lifetime access and receive it free. Decided ON DEVICE, no server: a local first-launch record, or StoreKit's signed AppTransaction (original build below 6), trusted only in Production. Sandbox/TestFlight/App Review never qualify, so a fresh install shows the normal purchase screen with the price. The multi-child limit is enforced on ADDING a second child, never on reading data already entered.

3. TESTED ON: iPhone 17 / iOS 26.6 (manual, unit and UI tests), iPhone 15 Pro Max / iOS 26.6, iPhone 13 / iOS 26.4. iPhone only.

4. WHAT IT DOES / FOR WHOM: for parents of infants roughly 4-12 months old. A new food is given every few days and the parent must remember which, when, and how the child reacted. Pudding keeps that record: a bundled food catalog, a per-food introduction started manually, a feeding log (date, portion, liking, reaction, note, photo), a calendar diary, allergens with repeat reminders, and a PDF export for the pediatrician. It is a diary, not an advisor: no medical advice, no diagnosis, it never tells a parent what or when to feed. Every plan parameter (start age, observation windows, allergen list and frequency) is set by the user. A medical disclaimer is an onboarding step shown BEFORE any child data is entered, and stays in Profile > About.

5. SETUP / ACCESS: nothing required - no account or credentials. Install and open. Onboarding: welcome > disclaimer > where to keep the diary ("this iPhone and iCloud" or "only this iPhone", explicit choice, nothing preselected; plus "Restore diary from iCloud") > child > plan. Today tab: today's journal. Catalog tab: open a food > "Start introducing" > "Log a feeding"; a food becomes introduced automatically after feedings on several DIFFERENT days (2 by default, 3 for allergens). Allergens tab: repeat reminders. Calendar tab: the diary and recap cards. Profile tab: child, plan, language, theme, PDF export, iCloud on/off and restore, Pudding Pro, About.

6. EXTERNAL SERVICES: none. Apple frameworks only (SwiftUI, SwiftData, StoreKit 2, UserNotifications, PhotosUI, PDFKit, WidgetKit), no third-party packages. No backend, auth, analytics, ads or AI. The food catalog is a static JSON file bundled in the app. The only network use is Apple CloudKit to the user's own private iCloud database (we cannot access it), and only if the user opts in. Hence "Data Not Collected". The "remote-notification" background mode exists only so CloudKit can deliver silent sync pushes - we run no push server; every reminder is a local notification.

7. REGIONS: no regional differences; 14 UI languages affect wording only.

8. REGULATED INDUSTRY / THIRD-PARTY MATERIAL: not a medical device, no diagnostic service, no HealthKit, no clinical records - it stores only what the parent types and points to their pediatrician. The only third-party material is the OpenMoji icon set (openmoji.org) under CC BY-SA 4.0, credited as "Icons: OpenMoji (CC BY-SA 4.0)" in Profile > About. All other assets and text are ours.
```

## 8б. Ключевые слова 1.1.0 — залиты во все 15 локалей

Ключи в разделах 5–6 — история 1.0. В 1.0 треть места уходила на слова, которые уже
есть в названии и подзаголовке: Apple индексирует их и так, повтор в ключах ничего не
даёт. В 1.1.0 повторы убраны вместе с единственным числом от них же (`allergen` при
`allergens`), освободившееся место отдано под новые запросы.

**Правила:** без пробелов после запятых; ни одного слова из названия/подзаголовка;
никакого рецептного и советующего (меню, рецепты, «план прикорма») — приложение
ничего не советует, и такой трафик уйдёт с отказом.

| Локаль | Длина | Ключи |
|---|---|---|
| `en-US` | 98 | `baby,weaning,blw,tracker,diary,feeding,reaction,infant,log,puree,journal,allergy,introduce,toddler` |
| `ru` | 95 | `малыш,введение,кормление,реакция,ребёнок,питание,пюре,каша,аллергия,педприкорм,грудничок,трекер` |
| `uk` | 94 | `малюк,введення,годування,реакція,дитина,харчування,пюре,каша,алергія,немовля,педприкорм,трекер` |
| `de-DE` | 93 | `baby,blw,einführen,babybrei,reaktion,säugling,allergie,ernährung,kleinkind,protokoll,breifrei` |
| `fr-FR` | 98 | `bébé,dme,purée,allergie,sevrage,repas,réaction,carnet,suivi,nourrisson,solide,introduction,journal` |
| `es-ES` | 95 | `bebe,destete,blw,introduccion,alimentacion,complementaria,reaccion,comida,alergia,pure,registro` |
| `es-MX` | 95 | `bebe,destete,blw,introduccion,alimentacion,complementaria,reaccion,comida,alergia,pure,registro` |
| `it` | 94 | `neonato,blw,reazione,alimentazione,autosvezzamento,allergia,omogeneizzati,introduzione,bambino` |
| `pt-BR` | 98 | `introdução,blw,bebê,desmame,diário,alimentação,reação,comida,registro,alergia,neném,acompanhamento` |
| `pl` | 97 | `blw,niemowlę,karmienie,dziennik dziecka,reakcja,jedzenie,alergia,papki,obiadki,słoiczki,niemowlak` |
| `nl-NL` | 99 | `baby,bijvoeding,blw,zelf eten,allergie,dagboek,voeding,reactie,peuter,fruithapje,groentehapje,papje` |
| `tr` | 91 | `bebek,mama,alerji,beslenme,tepki,günlük,blw,katı,takip,çocuk,püre,kayıt,bebeğim,takvim,6 ay` |
| `ja` | 87 | `赤ちゃん,育児,子育て,アレルギー,手づかみ食べ,ベビーフード,初期,中期,後期,完了期,乳児,幼児,ベビー,食事,日記,反応,管理,カレンダー,メモ,ごっくん期,もぐもぐ期` |
| `ko` | 79 | `아기,이유식기록,이유식일지,첫이유식,초기이유식,중기이유식,후기이유식,자기주도이유식,유아식,알러지,육아,육아일기,반응,식단,아기식단,블위,캘린더` |
| `zh-Hans` | 60 | `辅食添加,喂养,食物,反应,婴儿,婴幼儿,育儿,母婴,断奶,自主进食,手指食物,米粉,果泥,日历,6个月,追踪,宝宝成长` |

## 8в. Описание и What's New 1.1.0 — залиты во все 15 локалей

Гайдлайн 2.3.2: из описания должно быть видно, что платное. Поэтому в каждое описание
вставлен абзац `PUDDING PRO — …` перед «без учётки» и дисклеймером. Исходники текстов
(абзац Pro + What's New по всем локалям) — `docs/appstore/store-1.1.0.json`.
Скрипт заливки пропускает локаль, где абзац уже есть, — повторный прогон не задвоит.

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
