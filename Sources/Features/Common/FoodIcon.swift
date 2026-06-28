import SwiftUI
import UIKit

/// Иллюстрация продукта в цветной скруглённой плитке.
/// Порядок фолбэка: иконка продукта → иконка категории → эмодзи.
/// Иллюстрации — OpenMoji (CC BY-SA 4.0).
/// Иллюстрация OpenMoji по имени ассета с фолбэком на системный эмодзи.
/// Используется там, где нужна «красивая» иконка вместо дефолтного эмодзи
/// (оценка вкуса, реакция) — единый стиль с иконками продуктов.
struct OpenMojiIcon: View {
    let asset: String
    let fallback: String
    var size: CGFloat = 30

    var body: some View {
        if let image = UIImage(named: asset) {
            Image(uiImage: image).resizable().scaledToFit()
                .frame(width: size, height: size)
        } else {
            Text(fallback).font(.system(size: size))
        }
    }
}

struct FoodIcon: View {
    let food: Food
    var size: CGFloat = 46

    private var image: UIImage? {
        // Свои продукты — OpenMoji-иконка по выбранному эмодзи (без подмены категорией).
        if food.id.hasPrefix("custom-") {
            return CustomFoodIcons.asset(for: food.emoji).flatMap { UIImage(named: $0) }
        }
        return UIImage(named: "food_\(food.id)") ?? UIImage(named: "cat_\(food.category.rawValue)")
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.30, style: .continuous)
                .fill(Theme.softGradient(Theme.categoryColor(food.category)))
                .overlay(RoundedRectangle(cornerRadius: size * 0.30, style: .continuous)
                    .stroke(.white.opacity(0.6), lineWidth: 1))
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
