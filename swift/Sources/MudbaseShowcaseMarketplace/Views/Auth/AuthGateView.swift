import SwiftUI

/// Shown in the Account tab whenever there is no real signed-in user — i.e. `sessionStore.user`
/// is still the anonymous guest session established at launch (see `SessionStore` doc comments).
/// The Browse tab is always browsable regardless — only account-specific actions (posting a
/// listing, submitting a proposal, messaging, viewing "My Listings"/"My Proposals") require
/// signing in.
struct AuthGateView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @State private var mode: Mode = .login

    private enum Mode { case login, register }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Text("Marketplace")
                    .font(.title2.bold())
                Text("Every listing, proposal, and message on this screen is served by a real Mudbase project.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.top, 24)
            .padding(.bottom, 12)

            Group {
                switch mode {
                case .login:
                    LoginView(sessionStore: sessionStore, onSwitchToRegister: { mode = .register })
                case .register:
                    RegisterView(sessionStore: sessionStore, onSwitchToLogin: { mode = .login })
                }
            }
        }
    }
}
