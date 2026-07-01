import SwiftUI
import UIKit

/// Полноэкранный просмотр прикреплённых фото: листается между снимками, каждый
/// зумится (щипок + двойной тап). Тёмный фон, крестик закрытия.
struct PhotoViewer: View {
    let photos: [Data]
    @Environment(\.dismiss) private var dismiss
    @State private var index: Int

    init(photos: [Data], start: Int = 0) {
        self.photos = photos
        _index = State(initialValue: min(max(0, start), max(0, photos.count - 1)))
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            TabView(selection: $index) {
                ForEach(Array(photos.enumerated()), id: \.offset) { i, data in
                    if let ui = UIImage(data: data) {
                        ZoomableImage(image: ui).tag(i)
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: photos.count > 1 ? .automatic : .never))
            .ignoresSafeArea()

            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white, .white.opacity(0.25))
                    .padding()
            }
        }
    }
}

/// Зумируемое изображение: щипок 1×–4×, двойной тап переключает 1×/2.5×.
struct ZoomableImage: View {
    let image: UIImage
    @State private var scale: CGFloat = 1
    @GestureState private var pinch: CGFloat = 1

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .scaleEffect(scale * pinch)
            .gesture(
                MagnificationGesture()
                    .updating($pinch) { value, state, _ in state = value }
                    .onEnded { value in
                        scale = min(max(1, scale * value), 4)
                    }
            )
            .onTapGesture(count: 2) {
                withAnimation(.snappy) { scale = scale > 1 ? 1 : 2.5 }
            }
    }
}
