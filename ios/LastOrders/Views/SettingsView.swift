import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var state
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss

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
                    FieldLabel("Email")
                    TextField("you@example.com", text: $state.email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .sheetField()
                }

                Text("The app authenticates the same way the web app's session does — it sends your email as the auth_session cookie with every request. Use the email your server's AUTHORIZED_EMAIL is set to.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(p.ink3)
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
}
