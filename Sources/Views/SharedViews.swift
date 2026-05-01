import PhotosUI
import SwiftUI
import UIKit

struct AsyncVarietyImage: View {
    var image: UIImage?
    var url: URL?
    var height: CGFloat = 120

    init(image: UIImage? = nil, url: URL? = nil, height: CGFloat = 120) {
        self.image = image
        self.url = url
        self.height = height
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let url {
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
        .background(AppTheme.elevated)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var placeholder: some View {
        ZStack {
            AppTheme.elevated
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
