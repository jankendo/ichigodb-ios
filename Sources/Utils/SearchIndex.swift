import Foundation

enum SearchIndex {
    static func normalize(_ text: String) -> String {
        let folded = text
            .folding(options: [.caseInsensitive, .widthInsensitive, .diacriticInsensitive], locale: Locale(identifier: "ja_JP"))
            .lowercased()
        return String(folded.unicodeScalars.map { scalar in
            if (0x30A1...0x30F6).contains(scalar.value),
               let converted = UnicodeScalar(scalar.value - 0x60) {
                return Character(converted)
            }
            return Character(scalar)
        })
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func compact(_ text: String) -> String {
        let separators = CharacterSet.whitespacesAndNewlines
            .union(.punctuationCharacters)
            .union(.symbols)
        return normalize(text).unicodeScalars
            .filter { !separators.contains($0) }
            .map(String.init)
            .joined()
    }

    static func matches(query: String, in candidate: String) -> Bool {
        let normalizedQuery = normalize(query)
        guard !normalizedQuery.isEmpty else { return true }
        let normalizedCandidate = normalize(candidate)
        let compactCandidate = compact(candidate)
        return normalizedQuery.searchTokens.allSatisfy { token in
            normalizedCandidate.contains(token) || compactCandidate.contains(compact(token))
        }
    }
}

extension String {
    var normalizedSearchText: String {
        SearchIndex.normalize(self)
    }

    var compactSearchText: String {
        SearchIndex.compact(self)
    }

    var searchTokens: [String] {
        normalizedSearchText
            .split { $0 == " " || $0 == "　" || $0 == "\t" || $0 == "\n" }
            .map(String.init)
            .filter { !$0.isEmpty }
    }
}

extension Variety {
    var searchBlob: String {
        ([name, japaneseName, registrationNumber, applicationNumber, developer, originPrefecture, description, characteristicsSummary]
            .compactMap { $0 } + aliasNames + tags)
            .joined(separator: " ")
            .normalizedSearchText
    }

    var exactSearchKeys: Set<String> {
        Set(([name, japaneseName].compactMap { $0 } + aliasNames).map(\.compactSearchText).filter { !$0.isEmpty })
    }

    func matchesSearch(_ query: String) -> Bool {
        let normalized = query.normalizedSearchText
        guard !normalized.isEmpty else { return true }
        let compactBlob = searchBlob.compactSearchText
        return normalized.searchTokens.allSatisfy { token in
            searchBlob.contains(token) || compactBlob.contains(token.compactSearchText)
        }
    }

    func isExactMatch(for query: String) -> Bool {
        let key = query.compactSearchText
        guard !key.isEmpty else { return false }
        return exactSearchKeys.contains(key)
    }
}
