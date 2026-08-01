import SwiftUI

/// Three tabs: Browse (always browsable, real or guest), My Work (role-dependent — "My Listings"
/// for a client, "My Proposals" for a freelancer, hidden entirely for a guest), and Account (the
/// signed-in user's own profile, or the sign-in/register screen while still a guest).
struct MainTabView: View {
    let config: AppConfig
    let user: AppUser
    @EnvironmentObject private var tabRouter: TabRouter

    var body: some View {
        TabView(selection: $tabRouter.selection) {
            NavigationStack {
                BrowseListingsView(config: config)
                    .marketplaceNavigationDestinations(config: config)
            }
            .tabItem { Label("Browse", systemImage: "magnifyingglass") }
            .tag(TabRouter.Tab.browse)

            if user.customRole == .client {
                NavigationStack {
                    MyListingsView(config: config, clientId: user.id, clientName: user.displayName)
                        .marketplaceNavigationDestinations(config: config)
                }
                .tabItem { Label("My Listings", systemImage: "briefcase") }
                .tag(TabRouter.Tab.myWork)
            } else if user.customRole == .freelancer {
                NavigationStack {
                    MyProposalsView(config: config, freelancerId: user.id)
                        .marketplaceNavigationDestinations(config: config)
                }
                .tabItem { Label("My Proposals", systemImage: "doc.text") }
                .tag(TabRouter.Tab.myWork)
            }

            NavigationStack {
                AccountTabView(config: config)
            }
            .tabItem {
                Label(
                    user.isGuest ? "Sign In" : "Account",
                    systemImage: user.isGuest ? "person.crop.circle.badge.plus" : "person.crop.circle.fill"
                )
            }
            .tag(TabRouter.Tab.account)
        }
    }
}

/// The Account tab's root content: the signed-in user's own `AccountView` once real, or
/// `AuthGateView` while the session is still the anonymous guest.
private struct AccountTabView: View {
    let config: AppConfig
    @EnvironmentObject private var sessionStore: SessionStore

    var body: some View {
        Group {
            if let user = sessionStore.user, !user.isGuest {
                AccountView(user: user)
            } else {
                AuthGateView()
            }
        }
    }
}
