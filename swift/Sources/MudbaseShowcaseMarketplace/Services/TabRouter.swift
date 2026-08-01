import Foundation

/// The SwiftUI equivalent of the web app's `router.push("/login")` redirect — the proposal
/// composer and message thread both need somewhere to send a guest who tries to write. A native
/// `TabView` has no URL to push, so a guest tapping one of those same actions instead switches to
/// the Account tab (which renders `AuthGateView` whenever `sessionStore.user` is the anonymous
/// guest). Injected as an `@EnvironmentObject` from the app root so any view several levels deep
/// in the Browse tab can request the switch without threading a callback through every
/// intermediate view.
@MainActor
final class TabRouter: ObservableObject {
    enum Tab: Hashable {
        case browse
        case myWork
        case account
    }

    @Published var selection: Tab = .browse

    func routeToSignIn() {
        selection = .account
    }
}
