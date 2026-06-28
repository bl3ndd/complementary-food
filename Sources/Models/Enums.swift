import Foundation

/// Состояние продукта в процессе введения (стейт-машина, SPEC §4.2/4.4).
enum IntroState: String, Codable, CaseIterable {
    case notIntroduced   // ещё не вводили
    case introducing     // в окне наблюдения
    case introduced      // введён успешно
    case paused          // реакция при первом вводе / отложили
    case allergy         // подтверждённая аллергия (реакция на уже введённый продукт)

    var title: String {
        switch self {
        case .notIntroduced: return String(localized: "Не введён")
        case .introducing:   return String(localized: "Вводится")
        case .introduced:    return String(localized: "Введён")
        case .paused:        return String(localized: "Пауза")
        case .allergy:       return String(localized: "Аллергия")
        }
    }
}

/// Категория продукта в каталоге.
enum FoodCategory: String, Codable, CaseIterable {
    case vegetable, porridge, fruit, meat, fish, dairy, egg, allergen, other

    var title: String {
        switch self {
        case .vegetable: return String(localized: "Овощи")
        case .porridge:  return String(localized: "Каши")
        case .fruit:     return String(localized: "Фрукты")
        case .meat:      return String(localized: "Мясо")
        case .fish:      return String(localized: "Рыба")
        case .dairy:     return String(localized: "Молочные")
        case .egg:       return String(localized: "Яйцо")
        case .allergen:  return String(localized: "Аллергены")
        case .other:     return String(localized: "Другое")
        }
    }
}

/// Группа аллергенов.
enum AllergenGroup: String, Codable, CaseIterable {
    case egg, peanut, treenut, dairy, gluten, fish, shellfish, soy, sesame, other

    var title: String {
        switch self {
        case .egg:       return String(localized: "Яйцо")
        case .peanut:    return String(localized: "Арахис")
        case .treenut:   return String(localized: "Орехи")
        case .dairy:     return String(localized: "Молочные")
        case .gluten:    return String(localized: "Глютен")
        case .fish:      return String(localized: "Рыба")
        case .shellfish: return String(localized: "Морепродукты")
        case .soy:       return String(localized: "Соя")
        case .sesame:    return String(localized: "Кунжут")
        case .other:     return String(localized: "Другое")
        }
    }
}

/// Тип записи в журнале: первичный ввод или поддержка аллергена.
enum LogType: String, Codable {
    case intro
    case maintenance
}

/// Тип реакции при логировании. Реакция — это только запись в журнале, она НЕ
/// двигает стейт-машину ввода (остановку выбирает пользователь вручную, SPEC §4.4).
/// Raw-значения `gi`/`breathing` сохранены ради совместимости со старыми логами.
enum ReactionType: String, Codable, CaseIterable {
    case none, skin, gi, constipation, diarrhea, breathing, other

    var title: String {
        switch self {
        case .none:         return String(localized: "Нет реакции")
        case .skin:         return String(localized: "Кожа (сыпь)")
        case .gi:           return String(localized: "Срыгивание / рвота")
        case .constipation: return String(localized: "Запор")
        case .diarrhea:     return String(localized: "Диарея")
        case .breathing:    return String(localized: "Затруднённое дыхание")
        case .other:        return String(localized: "Другое")
        }
    }

    var emoji: String {
        switch self {
        case .none:         return "👍"
        case .skin:         return "🔴"
        case .gi:           return "🤮"
        case .constipation: return "😖"
        case .diarrhea:     return "💩"
        case .breathing:    return "😮‍💨"
        case .other:        return "❓"
        }
    }
}

/// Насколько ребёнку понравился продукт (вкусовая оценка, НЕ аллергия).
enum Liking: String, Codable, CaseIterable {
    case disliked  // не понравилось
    case neutral   // нейтрально
    case liked     // понравилось

    var emoji: String {
        switch self {
        case .disliked: return "😣"
        case .neutral:  return "😐"
        case .liked:    return "😋"
        }
    }

    var title: String {
        switch self {
        case .disliked: return String(localized: "Не понравилось")
        case .neutral:  return String(localized: "Нейтрально")
        case .liked:    return String(localized: "Понравилось")
        }
    }

    /// Короткая подпись для компактных мест (карточки оценки вкуса).
    var shortTitle: String {
        switch self {
        case .disliked: return String(localized: "Не оч")
        case .neutral:  return String(localized: "Норм")
        case .liked:    return String(localized: "Класс")
        }
    }
}

/// Статус поддержки аллергена — вычисляемый, не хранится (SPEC §4.3).
enum AllergenStatus: String {
    case ok       // 🟢 давали в срок
    case dueSoon  // 🟡 скоро пора
    case overdue  // 🔴 просрочено

    var emoji: String {
        switch self {
        case .ok:      return "🟢"
        case .dueSoon: return "🟡"
        case .overdue: return "🔴"
        }
    }

    var title: String {
        switch self {
        case .ok:      return String(localized: "В норме")
        case .dueSoon: return String(localized: "Скоро пора")
        case .overdue: return String(localized: "Просрочено")
        }
    }
}
