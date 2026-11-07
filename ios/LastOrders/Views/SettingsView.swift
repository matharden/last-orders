import SwiftUI
import AuthenticationServices

struct SettingsView: View {
    @Environment(AppState.self) private var state
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.webAuthenticationSession) private var webAuthenticationSession

    @State private var signingIn = false
    @State private var signInError: String?

    private var p: Palette { Palette.of(scheme) }

    var body: some View {
        @Bindable var state = state
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Settings")
                        .font(.serif(23, .semibold))
                        .foregroundStyle(p.ink)
                    Text("Where your journal lives.")
                        .font(.system(size: 14))
                        .foregroundStyle(p.ink2)
                }
                .padding(.top, 8)
                .padding(.bottom, 6)

                VStack(alignment: .leading, spacing: 7) {
                    FieldLabel("Server URL")
                    TextField(AppState.defaultServerURL, text: $state.serverURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .sheetField()
                }

                VStack(alignment: .leading, spacing: 7) {
                    FieldLabel("Account")
                    if state.isSignedIn {
                        HStack {
                            Text(state.email.isEmpty ? "Signed in" : state.email)
                                .font(.system(size: 15))
                                .foregroundStyle(p.ink)
                            Spacer()
                            Button("Sign out") { state.signOut() }
                                .font(.mono(11, .semibold))
                                .foregroundStyle(p.amber)
                        }
                        .sheetField()
                    } else {
                        Button {
                            Task { await signIn() }
                        } label: {
                            Text(signingIn ? "Signing in…" : "Sign in with Google")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(p.amber)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .sheetField()
                        .disabled(signingIn || state.loginURL == nil)
                    }
                }

                Text(signInError ?? "Sign in once with the Google account your server's AUTHORIZED_EMAIL is set to. You'll stay signed in for a year, renewed automatically while you use the app.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(signInError == nil ? p.ink3 : p.amber)
                    .padding(.top, 2)

                Button {
                    dismiss()
                    Task { await state.refresh() }
                } label: {
                    Text("Done")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .fill(p.fabGradient)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!state.isConfigured)
                .opacity(state.isConfigured ? 1 : 0.4)
                .padding(.top, 8)
            }
            .padding(20)
        }
        .background(p.card)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func signIn() async {
        guard let url = state.loginURL else { return }
        signingIn = true
        signInError = nil
        defer { signingIn = false }
        do {
            let callback = try await webAuthenticationSession.authenticate(
                using: url,
                callbackURLScheme: AuthCallback.scheme
            )
            if state.completeSignIn(callbackURL: callback) {
                await state.refresh()
            } else {
                signInError = "Sign-in didn't return a session. Check the server URL."
            }
        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            // User closed the sheet; nothing to report.
        } catch {
            signInError = error.localizedDescription
        }
    }
}
