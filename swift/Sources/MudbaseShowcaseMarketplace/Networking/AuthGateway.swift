import Foundation
import MudbaseSDK

/// Thin wrapper over `AuthenticationAPI` + `MultiRoleFeatureAPI`'s async/await calls. Kept separate
/// from `SessionStore` (which owns observable app state) so the actual network calls stay
/// unit-testable independent of SwiftUI/Observation. Ported from the ecommerce/social Swift ports'
/// `Networking/AuthGateway.swift`, adapted for this app's two self-registerable roles (`client` /
/// `freelancer` — see `AppRole`) in place of those apps' single hardcoded role.
///
/// Every Mudbase call below is the real generated `MudbaseSDK` async/await method, read from
/// `../../mudbase-sdk/swift/Sources/MudbaseSDK/APIs/*.swift` before being used — none of the
/// signatures were guessed:
/// - `AuthenticationAPI.createAnonymousSession`, `.loginLocalUser`, `.getLocalSession`,
///   `.refreshToken`, `.logoutLocalUser`
/// - `MultiRoleFeatureAPI.registerWithRole(role:registerWithRoleRequest:)`
///
/// Two real, documented generated-SDK gaps shape this file, both already surfaced in the
/// ecommerce/social ports and unchanged here:
/// - `RegisterWithRole201Response.user` (`RegisterWithRole201ResponseUser`) already carries
///   `customRole` directly, so `registerUser` below builds the signed-in `AppUser` straight from
///   the register response instead of a follow-up `login` + `getLocalSession` round trip.
/// - `LoginLocalUser200ResponseUser` still has **no** `customRole` field — only
///   `GetLocalSession200Response.user` (a raw `JSONValue`, since the SDK can't know ahead of time
///   what custom roles a project's Multi-Role feature defines) carries it. Every *login* is
///   therefore followed by a `getLocalSession` call for exactly this reason — `currentUser()`.
struct AuthGateway {
    let projectId: String

    struct LoginResult {
        let accessToken: String
        let refreshToken: String
    }

    struct RegisterResult {
        /// True when the project requires email verification before a session is issued — in
        /// that case `session`/`user` are both `nil` and the caller shows a "check your email"
        /// message instead.
        let requiresVerification: Bool
        let session: LoginResult?
        let user: AppUser?
    }

    /// `POST /api/auth/anonymous` — establishes a guest session (role: viewer, customRole: nil,
    /// isAnonymous: true) so the public listings feed reads without forcing signup. See "Auth
    /// flow" in `plan/build-plan.md`.
    func loginAnonymous() async throws(ErrorResponse) -> LoginResult {
        let response = try await AuthenticationAPI.createAnonymousSession(
            createAnonymousSessionRequest: CreateAnonymousSessionRequest(projectId: projectId)
        )
        guard let token = response.token, let refreshToken = response.refreshToken else {
            throw ErrorResponse.error(-2, nil, nil, MudbaseClientError.missingTokenInResponse)
        }
        return LoginResult(accessToken: token, refreshToken: refreshToken)
    }

    /// `POST /api/auth/local/signup/{role}` — `role` is `"client"` or `"freelancer"`, whichever
    /// the register screen's role picker selected (unlike the ecommerce/social ports, this app's
    /// self-signup DOES expose a role picker — see `RegisterView`). `agreedToTerms` is enforced
    /// client-side by the register screen's own validation and transmitted to the server — the
    /// platform's registration validator requires it for a direct signup call.
    func registerUser(email: String, password: String, firstName: String, lastName: String, role: AppRole, agreedToTerms: Bool) async throws(ErrorResponse) -> RegisterResult {
        let response = try await MultiRoleFeatureAPI.registerWithRole(
            role: role.rawValue,
            registerWithRoleRequest: RegisterWithRoleRequest(
                email: email,
                password: password,
                firstName: firstName,
                lastName: lastName,
                projectId: projectId,
                agreedToTerms: agreedToTerms
            )
        )
        if response.requireVerification == true {
            return RegisterResult(requiresVerification: true, session: nil, user: nil)
        }
        guard let token = response.token,
              let refreshToken = response.refreshToken,
              let responseUser = response.user,
              let user = AppUser(registered: responseUser)
        else {
            throw ErrorResponse.error(-2, nil, nil, MudbaseClientError.missingTokenInResponse)
        }
        return RegisterResult(requiresVerification: false, session: LoginResult(accessToken: token, refreshToken: refreshToken), user: user)
    }

    /// `POST /api/auth/local/login`.
    func login(email: String, password: String) async throws(ErrorResponse) -> LoginResult {
        let response = try await AuthenticationAPI.loginLocalUser(
            loginLocalUserRequest: LoginLocalUserRequest(email: email, password: password, projectId: projectId)
        )
        guard let token = response.token, let refreshToken = response.refreshToken else {
            throw ErrorResponse.error(-2, nil, nil, MudbaseClientError.missingTokenInResponse)
        }
        return LoginResult(accessToken: token, refreshToken: refreshToken)
    }

    /// `GET /api/auth/local/session` — the only call that returns this project's custom role
    /// (`client`/`freelancer`) and the anonymous-session flag together (see the type doc comment
    /// above for why login alone can't).
    func currentUser() async throws(ErrorResponse) -> AppUser {
        let response = try await AuthenticationAPI.getLocalSession(projectId: projectId)
        guard let userJSON = response.user, let user = AppUser(json: userJSON) else {
            throw ErrorResponse.error(-2, nil, nil, MudbaseClientError.malformedSessionUser)
        }
        return user
    }

    /// `POST /api/auth/refresh` — rotates the refresh token on every use (platform-enforced,
    /// single-use); the caller is responsible for persisting the new pair.
    func refresh(refreshToken: String) async throws(ErrorResponse) -> LoginResult {
        let response = try await AuthenticationAPI.refreshToken(refreshTokenRequest: RefreshTokenRequest(refreshToken: refreshToken))
        guard let token = response.token, let newRefreshToken = response.refreshToken else {
            throw ErrorResponse.error(-2, nil, nil, MudbaseClientError.missingTokenInResponse)
        }
        return LoginResult(accessToken: token, refreshToken: newRefreshToken)
    }

    /// `POST /api/auth/local/logout` — best-effort; callers clear local state regardless of outcome.
    func logout() async throws(ErrorResponse) {
        _ = try await AuthenticationAPI.logoutLocalUser()
    }
}

enum MudbaseClientError: Error, Equatable {
    case missingTokenInResponse
    case malformedSessionUser
}
