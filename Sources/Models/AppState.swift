import Foundation

enum AppError: LocalizedError, Equatable {
    case network(String)
    case supabase(String)
    case storage(String)
    case validation(String)
    case cache(String)
    case cancelled
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .network(let message):
            return message.isEmpty ? "通信に失敗しました。接続状態を確認してください。" : message
        case .supabase(let message):
            return message.isEmpty ? "データベース処理に失敗しました。" : message
        case .storage(let message):
            return message.isEmpty ? "画像処理に失敗しました。" : message
        case .validation(let message):
            return message
        case .cache(let message):
            return message.isEmpty ? "ローカルキャッシュの処理に失敗しました。" : message
        case .cancelled:
            return "処理をキャンセルしました。"
        case .unknown(let message):
            return message.isEmpty ? "予期しないエラーが発生しました。" : message
        }
    }

    static func from(_ error: Error) -> AppError {
        if error is CancellationError {
            return .cancelled
        }
        if let appError = error as? AppError {
            return appError
        }
        if let supabaseError = error as? SupabaseError {
            return .supabase(supabaseError.localizedDescription)
        }
        if let authError = error as? AuthError {
            return .supabase(authError.localizedDescription)
        }
        if let repositoryError = error as? RepositoryError {
            return .supabase(repositoryError.localizedDescription)
        }
        if let validationError = error as? ValidationError {
            return .validation(validationError.localizedDescription)
        }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return .network(error.localizedDescription)
        }
        return .unknown(error.localizedDescription)
    }
}

enum NetworkState: String, Codable, Equatable {
    case online
    case syncing
    case offline
    case degraded

    var label: String {
        switch self {
        case .online:
            return "同期済み"
        case .syncing:
            return "同期中"
        case .offline:
            return "オフライン"
        case .degraded:
            return "一部同期"
        }
    }
}
