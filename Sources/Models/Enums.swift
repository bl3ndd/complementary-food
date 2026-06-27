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
        case .notIntroduced: return "Не введён"
        case .introducing:   return "Вводится"
        case .introduced:    return "Введён"
        case .paused:        return "Пауза"
        case .allergy:       return "Аллергия"
        }
    }
}

/// Категория продукта в каталоге.
enum FoodCategory: String, Codable, CaseIterable {
    case vegetable, porridge, fruit, meat, fish, dairy, egg, allergen, other

    var title: String {
        switch self {
        case .vegetable: return "Овощи"
        case .porridge:  return "Каши"
        case .fruit:     return "Фрукты"
        case .meat:      return "Мясо"
        case .fish:      return "Рыба"
        case .dairy:     return "Молочные"
        case .egg:       return "Яйцо"
        case .allergen:  return "Аллергены"
        case .other:     return "Другое"
        }
    }
}

/// Группа аллергенов.
enum AllergenGroup: String, Codable, CaseIterable {
    case egg, peanut, treenut, dairy, gluten, fish, shellfish, soy, sesame, other

    var title: String {
        switch self {
        case .egg:       return "Яйцо"
        case .peanut:    return "Арахис"
        case .treenut:   return "Орехи"
        case .dairy:     return "Молочные"
        case .gluten:    return "Глютен"
        case .fish:      return "Рыба"
        case .shellfish: return "Морепродукты"
        case .soy:       return "Соя"
        case .sesame:    return "Кунжут"
        case .other:     return "Другое"
        }
    }
}

/// Тип записи в журнале: первичный ввод или поддержка аллергена.
enum LogType: String, Codable {
    case intro
    case maintenance
}

/// Тип реакции при логировании.
enum ReactionType: String, Codable, CaseIterable {
    case none, skin, gi, breathing, other

    var title: String {
        switch self {
        case .none:      return "Нет реакции"
        case .skin:      return "Кожа (сыпь)"
        case .gi:        return "ЖКТ"
        case .breathing: return "Дыхание"
        case .other:     return "Другое"
        }
    }

    var emoji: String {
        switch self {
        case .none:      return "👍"
        case .skin:      return "🔴"
        case .gi:        return "🤢"
        case .breathing: return "😮‍💨"
        case .other:     return "❓"
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
        case .disliked: return "Не понравилось"
        case .neutral:  return "Нейтрально"
        case .liked:    return "Понравилось"
        }
    }

    /// Короткая подпись для компактных мест (карточки оценки вкуса).
    var shortTitle: String {
        switch self {
        case .disliked: return "Не оч"
        case .neutral:  return "Норм"
        case .liked:    return "Класс"
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
        case .ok:      return "В норме"
        case .dueSoon: return "Скоро пора"
        case .overdue: return "Просрочено"
        }
    }
}
