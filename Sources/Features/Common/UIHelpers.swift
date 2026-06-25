import SwiftUI

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

/// Шкала вкуса: 😣 / 😐 / 😋 (SPEC §5). Тап по выбранному снимает выбор.
struct LikingPicker: View {
    @Binding var selection: Liking?

    var body: some View {
        HStack(spacing: 16) {
            ForEach(Liking.allCases, id: \.self) { liking in
                Button {
                    selection = (selection == liking) ? nil : liking
                } label: {
                    Text(liking.emoji)
                        .font(.system(size: 36))
                        .opacity(selection == nil || selection == liking ? 1 : 0.3)
                        .scaleEffect(selection == liking ? 1.2 : 1)
                }
                .buttonStyle(.plain)
            }
        }
        .animation(.snappy, value: selection)
    }
}

extension Date {
    var shortDate: String {
        formatted(.dateTime.day().month())
    }
}
