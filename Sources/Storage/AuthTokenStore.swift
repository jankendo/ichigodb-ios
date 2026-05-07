import Foundation

final class AuthTokenStore {
    private let lock = NSLock()
    private var token: String?

    var accessToken: String? {
        lock.lock()
        defer { lock.unlock() }
        return token
    }

    func update(_ token: String?) {
        lock.lock()
        self.token = token
        lock.unlock()
    }
}
