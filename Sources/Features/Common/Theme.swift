import SwiftUI

/// Детская мультяшная тема: тёплая палитра, скруглённые формы (SPEC §10).
enum Theme {
    static let accent = Color(red: 0.98, green: 0.52, blue: 0.22)   // тёплый коралл
    static let bgTop = Color(red: 1.00, green: 0.97, blue: 0.91)
    static let bgBottom = Color(red: 1.00, green: 0.91, blue: 0.92)

    /// Цвет-акцент для категории (для «плиток» с эмодзи).
    static func categoryColor(_ category: FoodCategory) -> Color {
        switch category {
        case .vegetable: return Color(red: 0.45, green: 0.78, blue: 0.45)
        case .porridge:  return Color(red: 0.93, green: 0.70, blue: 0.36)
        case .fruit:     return Color(red: 0.95, green: 0.55, blue: 0.62)
        case .meat:      return Color(red: 0.86, green: 0.45, blue: 0.42)
        case .fish:      return Color(red: 0.40, green: 0.68, blue: 0.90)
        case .dairy:     return Color(red: 0.55, green: 0.72, blue: 0.92)
        case .egg:       return Color(red: 0.97, green: 0.80, blue: 0.30)
        case .allergen:  return Color(red: 0.95, green: 0.60, blue: 0.30)
        case .other:     return Color(red: 0.70, green: 0.66, blue: 0.85)
        }
    }
}

/// Градиентный фон приложения.
struct AppBackground: View {
    var body: some View {
        LinearGradient(colors: [Theme.bgTop, Theme.bgBottom],
                       startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }
}

/// Эмодзи в цветной скруглённой плитке.
struct EmojiAvatar: View {
    let emoji: String
    var color: Color = Theme.accent
    var size: CGFloat = 46

    var body: some View {
        Text(emoji)
            .font(.system(size: size * 0.52))
            .frame(width: size, height: size)
            .background(color.opacity(0.22),
                        in: RoundedRectangle(cornerRadius: size * 0.32, style: .continuous))
    }
}

extension View {
    /// Белая карточка со скруглением и мягкой тенью.
    func cartoonCard(padding: CGFloat = 16) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
    }
}
