import PhotosUI
import SwiftUI
import UIKit

extension UIApplication {
    func dismissActiveKeyboard() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

extension View {
    func dismissKeyboardOnTap() -> some View {
        simultaneousGesture(
            TapGesture().onEnded {
                UIApplication.shared.dismissActiveKeyboard()
            }
        )
    }

    func keyboardDoneToolbar() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("閉じる") {
                    UIApplication.shared.dismissActiveKeyboard()
                }
            }
        }
    }
}

struct AsyncVarietyImage: View {
    var image: UIImage?
    var url: URL?
    var height: CGFloat = 120
    var contentMode: ContentMode = .fit

    init(image: UIImage? = nil, url: URL? = nil, height: CGFloat = 120, contentMode: ContentMode = .fit) {
        self.image = image
        self.url = url
        self.height = height
        self.contentMode = contentMode
    }

    var body: some View {
        ZStack {
            AppTheme.elevated
            if let image {
                fittedImage(Image(uiImage: image))
            } else if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        fittedImage(image)
                    case .failure:
                        placeholder
                    case .empty:
                        ProgressView()
                            .tint(AppTheme.strawberry)
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
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(AppTheme.line.opacity(0.45)))
    }

    private func fittedImage(_ image: Image) -> some View {
        image
            .resizable()
            .aspectRatio(contentMode: contentMode)
            .frame(maxWidth: .infinity, maxHeight: height)
    }

    private var placeholder: some View {
        VStack(spacing: 5) {
            Image(systemName: "camera.macro")
                .font(.title2)
            Text("No Image")
                .font(.caption2.weight(.semibold))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(AppTheme.muted.opacity(0.65))
    }
}

struct FitThumbnail: View {
    var image: UIImage
    var size: CGFloat

    var body: some View {
        ZStack {
            AppTheme.elevated
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .padding(2)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(AppTheme.line.opacity(0.45)))
    }
}

struct CompactControlButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(prominent ? Color.white : AppTheme.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(background(configuration), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(prominent ? Color.clear : AppTheme.line)
            )
    }

    private func background(_ configuration: Configuration) -> Color {
        if prominent {
            return AppTheme.strawberry.opacity(configuration.isPressed ? 0.75 : 1)
        }
        return AppTheme.card.opacity(configuration.isPressed ? 0.65 : 1)
    }
}

struct IconBadgeButtonStyle: ButtonStyle {
    var tint: Color = AppTheme.strawberry

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .foregroundStyle(tint)
            .frame(width: 40, height: 40)
            .background(tint.opacity(configuration.isPressed ? 0.18 : 0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(tint.opacity(0.25)))
    }
}

struct LensChip: View {
    var title: String
    var systemImage: String
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .foregroundStyle(selected ? Color.white : AppTheme.ink)
                .background(selected ? AppTheme.strawberry : AppTheme.card, in: Capsule())
                .overlay(Capsule().stroke(selected ? Color.clear : AppTheme.line))
        }
        .buttonStyle(.plain)
        .accessibilityValue(selected ? "選択中" : "")
    }
}

struct ProgressStrip: View {
    var value: Double

    var body: some View {
        GeometryReader { geometry in
            let clamped = min(max(value, 0), 1)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AppTheme.line.opacity(0.35))
                Capsule()
                    .fill(AppTheme.strawberry)
                    .frame(width: clamped == 0 ? 0 : max(8, geometry.size.width * clamped))
            }
        }
        .frame(height: 6)
        .accessibilityLabel("図鑑進捗")
        .accessibilityValue("\(Int(value * 100))パーセント")
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
                                FitThumbnail(image: image, size: 92)
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

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 320
        let rows = rows(maxWidth: maxWidth, subviews: subviews)
        let height = rows.reduce(CGFloat.zero) { partial, row in
            partial + row.height
        } + CGFloat(max(rows.count - 1, 0)) * spacing
        return CGSize(width: maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = rows(maxWidth: bounds.width, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for item in row.items {
                subviews[item.index].place(
                    at: CGPoint(x: x, y: y),
                    proposal: ProposedViewSize(item.size)
                )
                x += item.size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private func rows(maxWidth: CGFloat, subviews: Subviews) -> [FlowRow] {
        var rows = [FlowRow]()
        var current = FlowRow()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if current.width + size.width + (current.items.isEmpty ? 0 : spacing) > maxWidth, !current.items.isEmpty {
                rows.append(current)
                current = FlowRow()
            }
            current.append(FlowItem(index: index, size: size), spacing: spacing)
        }
        if !current.items.isEmpty {
            rows.append(current)
        }
        return rows
    }
}

private struct FlowItem {
    var index: Int
    var size: CGSize
}

private struct FlowRow {
    var items = [FlowItem]()
    var width: CGFloat = 0
    var height: CGFloat = 0

    mutating func append(_ item: FlowItem, spacing: CGFloat) {
        if !items.isEmpty {
            width += spacing
        }
        items.append(item)
        width += item.size.width
        height = max(height, item.size.height)
    }
}
