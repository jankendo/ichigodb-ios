import Foundation

enum VarietyShareBuilder {
    static func makeText(
        variety: Variety,
        reviews: [Review],
        reviewCount: Int,
        averageOverall: Double?,
        parents: [Variety],
        children: [Variety],
        isDiscovered: Bool,
        maxReviews: Int = 3
    ) -> String {
        var lines = [
            "IchigoDB 品種レポート",
            "",
            "品種: \(variety.name)",
            "産地: \(clean(variety.originPrefecture) ?? "未設定")",
            "発見状態: \(isDiscovered ? "発見済み" : "未発見")",
            "評価: \(reviewCount)件\(averageText(averageOverall))"
        ]

        if !parents.isEmpty {
            lines.append("親品種: \(parents.prefix(4).map(\.name).joined(separator: " / "))")
        }
        if !children.isEmpty {
            lines.append("関連する子品種: \(children.prefix(4).map(\.name).joined(separator: " / "))")
        }
        if let summary = clean(variety.characteristicsSummary ?? variety.description) {
            lines.append("")
            lines.append("メモ: \(summary.truncated(to: 90))")
        }

        let recentReviews = Array(reviews.prefix(maxReviews))
        if !recentReviews.isEmpty {
            lines.append("")
            lines.append("最近の評価")
            for review in recentReviews {
                lines.append("- \(review.tastedDate) 総合 \(review.overall)/10（甘\(review.sweetness) 酸\(review.sourness) 香\(review.aroma) 食\(review.texture) 見\(review.appearance)）")
                if let comment = clean(review.comment) {
                    lines.append("  \(comment.truncated(to: 80))")
                }
                if let place = clean(review.purchasePlace) {
                    lines.append("  購入場所: \(place.truncated(to: 40))")
                }
            }
        }

        lines.append("")
        lines.append("IchigoDBで記録した品種・評価です。")
        lines.append("#IchigoDB #いちご #品種図鑑")
        return lines.joined(separator: "\n")
    }

    private static func averageText(_ average: Double?) -> String {
        guard let average else { return "" }
        return String(format: " / 平均 %.1f/10", average)
    }

    private static func clean(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension String {
    func truncated(to maxLength: Int) -> String {
        guard count > maxLength else { return self }
        return String(prefix(maxLength - 1)) + "…"
    }
}
