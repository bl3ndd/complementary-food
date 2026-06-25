import SwiftUI
import UIKit

/// Иллюстрация продукта в цветной скруглённой плитке.
/// Порядок фолбэка: иконка продукта → иконка категории → эмодзи.
/// Иллюстрации — OpenMoji (CC BY-SA 4.0).
struct FoodIcon: View {
    let food: Food
    var size: CGFloat = 46

    private var image: UIImage? {
        UIImage(named: "food_\(food.id)") ?? UIImage(named: "cat_\(food.category.rawValue)")
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.30, style: .continuous)
                .fill(Theme.categoryColor(food.category).opacity(0.18))
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.15)
            } else {
                Text(food.emoji).font(.system(size: size * 0.5))
            }
        }
        .frame(width: size, height: size)
    }
}
