import SwiftUI

enum AppTheme {
    static let strawberry = Color(red: 0.86, green: 0.12, blue: 0.22)
    static let leaf = Color(red: 0.10, green: 0.48, blue: 0.32)
    static let ink = Color(red: 0.08, green: 0.09, blue: 0.11)
    static let muted = Color(red: 0.42, green: 0.45, blue: 0.50)
    static let surface = Color(red: 0.98, green: 0.98, blue: 0.97)
    static let line = Color(red: 0.88, green: 0.88, blue: 0.86)
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
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
            .background(AppTheme.surface.opacity(configuration.isPressed ? 0.65 : 1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.line))
    }
}

extension View {
    func cardSurface() -> some View {
        padding(14)
            .background(.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.line))
    }
}
