import SwiftUI

/// `.keyboardType`, `.textInputAutocapitalization`, `.navigationBarTitleDisplayMode`, and
/// `.tabViewStyle(.page)` only exist on iOS/tvOS/watchOS — this target also builds for macOS (see
/// `Package.swift`'s platforms list, needed so `swift build` succeeds from the CLI without Xcode).
/// These no-op (or fall back to the platform default) on macOS instead of failing to compile.
/// Ported from the ecommerce/social Swift ports' `Support/PlatformCompat.swift`.
extension View {
    @ViewBuilder
    func emailKeyboard() -> some View {
        #if os(iOS) || os(tvOS) || os(watchOS)
        self.keyboardType(.emailAddress).textInputAutocapitalization(.never)
        #else
        self
        #endif
    }

    @ViewBuilder
    func numberPadKeyboard() -> some View {
        #if os(iOS) || os(tvOS) || os(watchOS)
        self.keyboardType(.decimalPad)
        #else
        self
        #endif
    }

    /// `.navigationBarTitleDisplayMode` is unavailable on macOS entirely (there is no navigation
    /// bar to compress) — this project's real target is iOS/iPadOS, where it applies normally.
    @ViewBuilder
    func inlineNavigationTitle() -> some View {
        #if os(iOS) || os(tvOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}
