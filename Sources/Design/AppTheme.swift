import SwiftUI

enum AppTheme {
    static let strawberry = Color(red: 0.86, green: 0.12, blue: 0.22)
    static let leaf = Color(red: 0.10, green: 0.48, blue: 0.32)
    static let gold = Color(red: 0.95, green: 0.66, blue: 0.12)
    static let ink = Color(uiColor: .label)
    static let muted = Color(uiColor: .secondaryLabel)
    static let surface = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    static let elevated = Color(uiColor: .tertiarySystemGroupedBackground)
    static let line = Color(uiColor: .separator)
    static let field = Color(uiColor: .systemBackground)
}

struct CapsuleBadge: View {
    var text: String
    var tint: Color = AppTheme.strawberry

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tint.opacity(0.10), in: Capsule())
    }
}

struct MetricPill: View {
    var title: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.muted)
            Text(value)
                .font(.headline)
                .foregroundStyle(AppTheme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.line))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppTheme.strawberry.opacity(configuration.isPressed ? 0.75 : 1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(AppTheme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppTheme.card.opacity(configuration.isPressed ? 0.65 : 1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.line))
    }
}

extension View {
    func cardSurface() -> some View {
        padding(14)
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.line))
    }
}

struct BrandMark: View {
    var size: CGFloat = 34

    var body: some View {
        Image("AppMark")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            .shadow(color: AppTheme.strawberry.opacity(0.18), radius: 6, y: 2)
    }
}

struct AppScreenHeader: View {
    var title: String
    var subtitle: String
    var systemImage: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            BrandMark(size: 42)
            VStack(alignment: .leading, spacing: 3) {
                Label(title, systemImage: systemImage)
                    .font(.title2.bold())
                    .foregroundStyle(AppTheme.ink)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)
                    .lineLimit(2)
            }
            Spacer()
        }
        .cardSurface()
    }
}
