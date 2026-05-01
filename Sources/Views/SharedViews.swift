import PhotosUI
import SwiftUI

struct AsyncVarietyImage: View {
    var url: URL?
    var height: CGFloat = 120

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        placeholder
                    case .empty:
                        ProgressView()
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .clipped()
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var placeholder: some View {
        ZStack {
            AppTheme.surface
            Image(systemName: "camera.macro")
                .font(.largeTitle)
                .foregroundStyle(AppTheme.muted.opacity(0.65))
        }
    }
}

struct PhotoSelectionStrip: View {
    @Binding var images: [UIImage]
    @State private var items: [PhotosPickerItem] = []
    var maxCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PhotosPicker(
                selection: Binding(
                    get: { items },
                    set: { newItems in
                        items = newItems
                        load(newItems)
                    }
                ),
                maxSelectionCount: maxCount,
                matching: .images
            ) {
                Label("画像を追加", systemImage: "photo.badge.plus")
            }
            .buttonStyle(SecondaryButtonStyle())

            if !images.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 92, height: 92)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                Button {
                                    images.remove(at: index)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(.white, AppTheme.ink.opacity(0.7))
                                }
                                .padding(5)
                            }
                        }
                    }
                }
            }
        }
    }

    private func load(_ newItems: [PhotosPickerItem]) {
        Task {
            var loaded = [UIImage]()
            for item in newItems.prefix(maxCount) {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    loaded.append(image)
                }
            }
            await MainActor.run {
                images = Array((images + loaded).prefix(maxCount))
                items = []
            }
        }
    }
}

struct OptionalIntField: View {
    var title: String
    @Binding var value: Int?

    var body: some View {
        TextField(title, text: Binding(
            get: { value.map(String.init) ?? "" },
            set: { value = Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        ))
        .keyboardType(.numberPad)
    }
}

struct OptionalDoubleField: View {
    var title: String
    @Binding var value: Double?

    var body: some View {
        TextField(title, text: Binding(
            get: { value.map { IchigoFormat.trim($0) } ?? "" },
            set: { value = Double($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        ))
        .keyboardType(.decimalPad)
    }
}

struct ErrorBanner: View {
    var message: String?

    var body: some View {
        if let message, !message.isEmpty {
            Label(message, systemImage: "exclamationmark.circle")
                .font(.callout)
                .foregroundStyle(AppTheme.strawberry)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.strawberry.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct MessageBanner: View {
    var message: String?

    var body: some View {
        if let message, !message.isEmpty {
            Label(message, systemImage: "checkmark.circle")
                .font(.callout)
                .foregroundStyle(AppTheme.leaf)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.leaf.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}
