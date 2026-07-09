# App Store Connect — данные для заполнения

Всё ниже — готово к копипасту в ASC. Бандл: **`com.pudding.app`** (team `A89ST3SFXS`).
ASC заполняется вручную на appstoreconnect.apple.com (API-ключа в проекте нет).

## 1. Создание приложения (My Apps → «+»)

| Поле | Значение |
|---|---|
| Platform | iOS |
| Name | `Pudding — дневник прикорма` (26/30) |
| Primary language | Russian |
| Bundle ID | `com.pudding.app` (сначала зарегистрировать Identifier в developer.apple.com → Identifiers, capabilities: пока ничего, Push/CloudKit добавим позже) |
| SKU | `pudding-ios-001` |
| User Access | Full |

## 2. App Information

| Поле | Значение |
|---|---|
| Subtitle (RU) | `Первый прикорм и аллергены` (26/30) |
| Primary Category | Health & Fitness (Здоровье и фитнес) |
| Secondary Category | Lifestyle (Образ жизни) |
| Content Rights | Не содержит стороннего контента… → **No** (OpenMoji — CC BY-SA, атрибуция в приложении; это ок) |
| Age Rating | Все вопросы «None» → **4+** |
| License Agreement | стандартный EULA |

## 3. Pricing

Free, все страны (монетизация придержана — пейвол добавим позже).

## 4. App Privacy

- Privacy Policy URL: `https://pudding-for-children.vercel.app/privacy.html`
- **Data Collection: «Data Not Collected»** — бэкенда нет, аналитики нет,
  трекинга нет; все данные (дневник, фото) хранятся только на устройстве.
  На каждый вопрос о сборе данных — «No».

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
• Ввод новых продуктов — своё окно наблюдения для обычных продуктов и аллергенов, прогресс «день 2 из 3» прямо на карточке
• Поддержка аллергенов — Pudding напомнит вовремя повторить уже введённый аллерген, чтобы не растерять привыкание
• Коллекция продуктов — стена введённых продуктов пополняется с каждым успехом малыша
• Календарь-лента — вся история по дням, фильтры «реакции» и «планы», планирование ввода на будущее
• PDF для педиатра — вся история кормлений, реакций и статус аллергенов одним документом
• Лист «Не давать» — короткая памятка для няни или садика
• Рекап месяца — красивая карточка «что нового попробовали», которой хочется поделиться
• Свой план — настрой возраст старта, окна наблюдения, частоту и список аллергенов под рекомендации своего педиатра
• Свои продукты — добавляй то, чего нет в каталоге
• Русский и английский, светлая мультяшная тема и маскот Пудинг

БЕЗ УЧЁТКИ И БЕЗ ОБЛАКА: все данные хранятся только на твоём телефоне.

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
• Introducing new foods — separate observation windows for regular foods and allergens, with “day 2 of 3” progress right on the food card
• Allergen maintenance — gentle reminders to repeat introduced allergens so tolerance isn’t lost
• Food collection — a wall of introduced foods that fills up with every little win
• Calendar feed — full history by day, “reactions” and “plans” filters, plan future introductions
• PDF for your pediatrician — feedings, reactions and allergen status in one document
• “Do not give” sheet — a one-page memo for the nanny or daycare
• Monthly recap — a shareable card of everything new your baby tried
• Your own plan — set the starting age, observation windows, allergen frequency and list to match your pediatrician’s guidance
• Custom foods, Russian & English, a light cartoon theme and Pudding the mascot

NO ACCOUNT, NO CLOUD: everything stays on your phone.

Pudding is a diary, not a doctor: it prescribes nothing and advises nothing. Make all feeding decisions together with your pediatrician.
```

**Keywords** (100):
```
baby,solids,first foods,weaning,blw,allergen,tracker,diary,feeding,reaction,food,infant,log
```

## 7. Скриншоты (обязательно 6.9" iPhone; RU + EN)

Снять на iPhone 17 (тёмный статусбар, наполненные данные — можно `-seedSample`):
1. Главная «Стена Pudding» (маскот, плитки, коллекция)
2. Карточка продукта «вводится» (кольцо «день 2 из 3»)
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

**Review Notes**:
```
Pudding is a local-only baby feeding diary (no account, no backend, no data collection).

- On first launch the app shows onboarding (child profile + feeding plan) and a persistent medical disclaimer gate ("Прежде чем начать") per guideline 1.4.1. The same disclaimer is always available in Profile → About.
- The app records feedings/reactions entered by the parent and never gives medical or feeding advice; all plan parameters are configured by the user.
- Notifications are optional reminders for the user's own schedule (requested in context, not at launch).
- PDF export and the recap card are generated on-device from the user's own records.
```

## 9. Технические перед загрузкой билда

- [x] `ITSAppUsesNonExemptEncryption = NO` (в project.yml — вопрос про шифрование не будет всплывать)
- [ ] Поднять `MARKETING_VERSION` до `1.0.0` перед релизным билдом
- [ ] Зарегистрировать bundle id `com.pudding.app` в Developer Portal
- [ ] Archive → Distribute (Xcode Organizer) под релизным профилем
- [ ] ⚠️ Подтвердить support-email (`AppLinks.supportEmail`) и деплой privacy/terms на лендинге

Полный чек-лист сабмита: `docs/SUBMISSION.md`.
