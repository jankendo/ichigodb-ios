import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    @Published private(set) var session: AuthSession?
    @Published private(set) var isRestoring = true
    @Published private(set) var isSigningIn = false
    @Published var errorMessage: String?

    private let authClient: SupabaseAuthClient
    private let tokenStore: AuthTokenStore
    private let keychain: KeychainStore
    private let keychainAccount = "supabase-auth-session"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(authClient: SupabaseAuthClient, tokenStore: AuthTokenStore, keychain: KeychainStore = KeychainStore()) {
        self.authClient = authClient
        self.tokenStore = tokenStore
        self.keychain = keychain
    }

    var isSignedIn: Bool {
        session != nil
    }

    var accessToken: String? {
        session?.accessToken
    }

    func restoreSession() async {
        defer { isRestoring = false }
        guard let stored = loadStoredSession() else {
            clearSession()
            return
        }
        if stored.shouldRefresh {
            do {
                let refreshed = try await authClient.refresh(refreshToken: stored.refreshToken)
                applySession(refreshed)
            } catch {
                clearSession()
            }
        } else {
            applySession(stored)
        }
    }

    func signIn(email: String, password: String) async -> Bool {
        isSigningIn = true
        errorMessage = nil
        defer { isSigningIn = false }
        do {
            let newSession = try await authClient.signIn(email: email, password: password)
            applySession(newSession)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func signOut() async {
        if let token = session?.accessToken {
            await authClient.signOut(accessToken: token)
        }
        clearSession()
    }

    private func applySession(_ newSession: AuthSession) {
        session = newSession
        tokenStore.update(newSession.accessToken)
        if let data = try? encoder.encode(newSession) {
            try? keychain.save(data, account: keychainAccount)
        }
    }

    private func clearSession() {
        session = nil
        tokenStore.update(nil)
        try? keychain.delete(account: keychainAccount)
    }

    private func loadStoredSession() -> AuthSession? {
        guard let data = try? keychain.load(account: keychainAccount) else { return nil }
        return try? decoder.decode(AuthSession.self, from: data)
    }
}
