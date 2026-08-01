import Foundation
import MudbaseSDK

/// This project's two self-registerable Multi-Role roles (confirmed against `../web/plan/build-plan.md`
/// and the live project's registration validator: `POST /api/auth/local/signup/client` and
/// `/signup/freelancer` both succeed). Unlike the ecommerce Swift port (`customer`/`seller`, only
/// `seller` provisioned out-of-band) or the social Swift port (single `customer` role), this app's
/// register screen exposes a real role picker — see `RegisterView`/`RegisterViewModel`.
enum AppRole: String, Sendable, Equatable, CaseIterable, Identifiable {
    case client
    case freelancer

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .client: return "Client"
        case .freelancer: return "Freelancer"
        }
    }
}

/// Project end-user, as returned by `GET /api/auth/local/session` — mirrors the social Swift
/// port's `AppUser`, which also represents the anonymous guest browsing session (see
/// `plan/build-plan.md` "Auth flow": this app establishes an anonymous session so the public
/// listings feed reads without forcing signup, exactly like the web reference). The generated SDK
/// types that endpoint's `user` field as a raw `JSONValue` rather than a fixed struct — unlike
/// org/platform users, project end-users carry whatever custom roles the project's Multi-Role
/// feature defines, so the SDK can't model that shape ahead of time. This type is this app's own
/// typed read of that JSON.
struct AppUser: Sendable, Equatable, Identifiable {
    let id: String
    let email: String
    let firstName: String
    let lastName: String
    /// `nil` for the anonymous guest session; `.client` or `.freelancer` for a real signed-in
    /// account.
    let customRole: AppRole?
    let emailVerified: Bool
    let isAnonymous: Bool

    var displayName: String {
        let name = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "Guest" : name
    }

    /// Mirrors `../web/src/hooks/useAuth.ts`'s `isAuthenticated`: a "real" signed-in user is one
    /// with an actual application role, not the always-present anonymous guest identity
    /// (`isAnonymous: true`, `customRole: nil`).
    var isGuest: Bool { isAnonymous || customRole == nil }

    init?(json: JSONValue) {
        guard let dict = json.dictionaryValue,
              let id = dict["_id"]?.stringValue ?? dict["id"]?.stringValue
        else {
            return nil
        }
        self.id = id
        self.email = dict["email"]?.stringValue ?? ""
        self.firstName = dict["firstName"]?.stringValue ?? ""
        self.lastName = dict["lastName"]?.stringValue ?? ""
        self.emailVerified = dict["emailVerified"]?.boolValue ?? false
        self.customRole = dict["customRole"]?.stringValue.flatMap(AppRole.init(rawValue:))
        self.isAnonymous = dict["isAnonymous"]?.boolValue ?? false
    }

    /// From `RegisterWithRole201Response.user` — used by `SessionStore.register` to build the
    /// signed-in user directly from the register response instead of a follow-up
    /// `getLocalSession` round trip, matching the ecommerce/social Swift ports' own reasoning
    /// (see `Networking/AuthGateway.swift`'s doc comment on the SDK's typed register response).
    init?(registered: RegisterWithRole201ResponseUser) {
        guard let id = registered.id else { return nil }
        self.id = id
        self.email = registered.email ?? ""
        self.firstName = registered.firstName ?? ""
        self.lastName = registered.lastName ?? ""
        self.emailVerified = registered.emailVerified ?? false
        self.customRole = registered.customRole.flatMap(AppRole.init(rawValue:))
        self.isAnonymous = false
    }
}
