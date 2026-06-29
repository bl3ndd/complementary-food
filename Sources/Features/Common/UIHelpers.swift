import SwiftUI
import UIKit

extension View {
    /// Прячет клавиатуру по тапу по пустому месту (тапы по полям/кнопкам не перехватываются).
    func hideKeyboardOnTap() -> some View {
        onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                            to: nil, from: nil, for: nil)
        }
    }
}

extension AllergenStatus {
    var color: Color {
        switch self {
        case .ok:      return .green
        case .dueSoon: return .orange
        case .overdue: return .red
        }
    }
}

extension IntroState {
    var color: Color {
        switch self {
        case .notIntroduced: return .gray
        case .introducing:   return .blue
        case .introduced:    return .green
        case .paused:        return .orange
        case .allergy:       return .red
        }
    }
}

/// Капсула-бейдж со статусом.
struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}

/// Шкала вкуса крупными карточками (SPEC §5). Тап по выбранной снимает выбор.
struct LikingPicker: View {
    @Binding var selection: Liking?

    var body: some View {
        HStack(spacing: 12) {
            ForEach(Liking.allCases, id: \.self) { liking in
                card(liking)
            }
        }
        .animation(.snappy, value: selection)
    }

    private func card(_ liking: Liking) -> some View {
        let selected = selection == liking
        return Button {
            selection = selected ? nil : liking
        } label: {
            VStack(spacing: 8) {
                OpenMojiIcon(asset: "like_\(liking.rawValue)",
                             fallback: liking.emoji, size: 56)
                    .scaleEffect(selected ? 1.08 : 1)
                Text(liking.shortTitle)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(selected ? Theme.accent : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(selected ? Theme.accent.opacity(0.12) : Color.black.opacity(0.03),
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(selected ? Theme.accent : .clear, lineWidth: 2.5)
            )
            .opacity(selection == nil || selected ? 1 : 0.55)
        }
        .buttonStyle(BouncyButtonStyle())
    }
}

extension Date {
    /// Короткая дата «день месяц» в локали устройства (склонения/порядок — системные).
    var shortDate: String {
        formatted(.dateTime.day().month())
    }
}
