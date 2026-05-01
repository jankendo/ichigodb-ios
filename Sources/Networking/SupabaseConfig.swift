import Foundation

struct SupabaseConfig {
    var url: URL
    var anonKey: String

    static var current: SupabaseConfig? {
        let rawURL = SupabaseGeneratedConfig.url.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = SupabaseGeneratedConfig.anonKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawURL.isEmpty, !key.isEmpty, let url = URL(string: rawURL) else {
            return nil
        }
        return SupabaseConfig(url: url, anonKey: key)
    }
}

enum SupabaseConfigState: Equatable {
    case ready(SupabaseConfig)
    case missing

    static var current: SupabaseConfigState {
        if let config = SupabaseConfig.current {
            return .ready(config)
        }
        return .missing
    }
}

extension SupabaseConfig: Equatable {}
