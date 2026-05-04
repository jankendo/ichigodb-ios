import Foundation

struct VarietySearchIndexEntry: Identifiable {
    let variety: Variety
    let searchBlob: String
    let compactSearchBlob: String
    let exactKeys: Set<String>
    let sortName: String

    var id: String { variety.id }

    init(variety: Variety) {
        self.variety = variety
        self.searchBlob = variety.searchBlob
        self.compactSearchBlob = variety.searchBlob.compactSearchText
        self.exactKeys = variety.exactSearchKeys
        self.sortName = variety.name
    }

    static func makeSorted(from varieties: [Variety]) -> [VarietySearchIndexEntry] {
        varieties
            .map(VarietySearchIndexEntry.init)
            .sorted { $0.sortName.localizedStandardCompare($1.sortName) == .orderedAscending }
    }

    func matches(normalizedQuery: String) -> Bool {
        guard !normalizedQuery.isEmpty else { return true }
        return normalizedQuery.searchTokens.allSatisfy { token in
            searchBlob.contains(token) || compactSearchBlob.contains(token.compactSearchText)
        }
    }

    func isExactMatch(for query: String) -> Bool {
        let key = query.compactSearchText
        guard !key.isEmpty else { return false }
        return exactKeys.contains(key)
    }
}

struct VarietySelectionSearchResult {
    var rows: [VarietySearchIndexEntry]
    var totalCount: Int

    var hiddenCount: Int {
        max(0, totalCount - rows.count)
    }
}

enum VarietySelectionSearch {
    static func result(
        entries: [VarietySearchIndexEntry],
        query: String,
        selectedIDs: Set<String> = [],
        emptyLimit: Int = 80,
        searchLimit: Int = 140
    ) -> VarietySelectionSearchResult {
        let cleaned = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            let selectedRows = entries.filter { selectedIDs.contains($0.id) }
            let unselectedRows = entries.filter { !selectedIDs.contains($0.id) }
            let limit = max(emptyLimit, selectedRows.count)
            return VarietySelectionSearchResult(
                rows: Array((selectedRows + unselectedRows).prefix(limit)),
                totalCount: entries.count
            )
        }

        let normalized = cleaned.normalizedSearchText
        let matched = entries
            .filter { $0.matches(normalizedQuery: normalized) }
            .sorted {
                let lhsExact = $0.isExactMatch(for: cleaned)
                let rhsExact = $1.isExactMatch(for: cleaned)
                if lhsExact != rhsExact {
                    return lhsExact
                }
                return $0.sortName.localizedStandardCompare($1.sortName) == .orderedAscending
            }

        return VarietySelectionSearchResult(
            rows: Array(matched.prefix(searchLimit)),
            totalCount: matched.count
        )
    }
}
