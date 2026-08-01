import SwiftUI

/// No direct web equivalent (the web app's account actions are split across the header's sign-out
/// button and the login/register pages) — collected here into one screen since a native tab bar
/// needs somewhere to put "who am I / sign out".
struct AccountView: View {
    let user: AppUser
    @EnvironmentObject private var sessionStore: SessionStore
    @State private var isSigningOut = false

    var body: some View {
        List {
            Section {
                LabeledContent("Name", value: user.displayName)
                LabeledContent("Email", value: user.email)
                LabeledContent("Role", value: user.customRole?.displayName ?? "—")
                LabeledContent("Email verified", value: user.emailVerified ? "Yes" : "No")
            }

            Section {
                Button(role: .destructive) {
                    Task {
                        isSigningOut = true
                        await sessionStore.logout()
                        isSigningOut = false
                    }
                } label: {
                    if isSigningOut {
                        ProgressView()
                    } else {
                        Text("Sign out")
                    }
                }
                .disabled(isSigningOut)
            }
        }
        .navigationTitle("Account")
    }
}
