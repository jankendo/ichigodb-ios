import SwiftUI

struct AuthGateView<Content: View>: View {
    @ObservedObject var authVM: AuthViewModel
    var onSignedIn: () async -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        Group {
            if authVM.isRestoring {
                ProgressView("認証を確認中")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.surface)
            } else if authVM.isSignedIn {
                content()
            } else {
                SignInView(authVM: authVM, onSignedIn: onSignedIn)
            }
        }
        .task {
            if authVM.isRestoring {
                await authVM.restoreSession()
            }
        }
    }
}

private struct SignInView: View {
    @ObservedObject var authVM: AuthViewModel
    var onSignedIn: () async -> Void
    @State private var email = ""
    @State private var password = ""
    @FocusState private var focusedField: Field?

    enum Field {
        case email
        case password
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    AppScreenHeader(
                        title: "IchigoDBへログイン",
                        subtitle: "登録済みのSupabase AuthアカウントだけがDBを読み書きできます。",
                        systemImage: "lock.shield"
                    )
                }
                .listRowBackground(Color.clear)

                Section("認証") {
                    TextField("メールアドレス", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .textContentType(.username)
                        .focused($focusedField, equals: .email)

                    SecureField("パスワード", text: $password)
                        .textContentType(.password)
                        .focused($focusedField, equals: .password)
                }

                Section {
                    Button {
                        Task {
                            UIApplication.shared.dismissActiveKeyboard()
                            if await authVM.signIn(email: email, password: password) {
                                await onSignedIn()
                            }
                        }
                    } label: {
                        Label(authVM.isSigningIn ? "ログイン中" : "ログイン", systemImage: "person.badge.key")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(authVM.isSigningIn || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty)
                    ErrorBanner(message: authVM.errorMessage)
                }
                .listRowBackground(Color.clear)

                Section {
                    Label("このIPAを持っていても、許可されたアカウントでログインできない端末はDBへアクセスできません。", systemImage: "checkmark.shield")
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                }
            }
            .navigationTitle("ログイン")
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(AppTheme.surface)
            .keyboardDoneToolbar()
            .toolbar {
                ToolbarItem(placement: .keyboard) {
                    Button("次へ") {
                        focusedField = focusedField == .email ? .password : nil
                    }
                }
            }
        }
    }
}
