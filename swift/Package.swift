// swift-tools-version:6.0
import PackageDescription

// This package is deliberately .xcodeproj-free. Xcode 14+ can open Package.swift directly and
// run an `executableTarget` that defines a SwiftUI `App`/`@main` as a real iOS app on a Simulator
// or device — it synthesizes the Info.plist/bundle at build time. See README.md "Why SPM, not an
// .xcodeproj" for the full rationale. `swift build` from the CLI also succeeds on macOS (the
// platforms list below just sets minimum deployment targets; no UIKit-only symbols are used
// anywhere in this target, so the same source compiles for both destinations).
let package = Package(
    name: "MudbaseShowcaseMarketplace",
    platforms: [
        .iOS(.v16),
        // v14, not v13 — a few `.textContentType` cases (`.givenName`, `.newPassword`, etc.) only
        // landed on macOS in 14.0, even though their iOS availability is much older. This only
        // affects the secondary macOS target used for `swift build` CLI verification (see the
        // note above); the real iOS 16 deployment target is unaffected.
        .macOS(.v14),
    ],
    products: [
        .executable(
            name: "MudbaseShowcaseMarketplace",
            targets: ["MudbaseShowcaseMarketplace"]
        ),
    ],
    dependencies: [
        // Sibling-clone dependency — see README.md "Setup" for the required directory layout.
        // The real Mudbase Swift SDK is not published to the Swift Package Registry or CocoaPods
        // trunk, so it is referenced by relative path rather than a version requirement.
        //
        // This points at `../mudbase-sdk-swift`, NOT `../../mudbase-sdk/swift` directly, because
        // of a real SwiftPM constraint: a local path dependency's package "identity" is the last
        // path component of the given path string, with no way to override it. This package's own
        // directory is named `swift` (per this project's required layout) and the SDK repo's
        // Swift subdirectory is ALSO named `swift` — pointing straight at `mudbase-sdk/swift`
        // would give both packages the identity "swift" and SwiftPM's dependency resolution
        // silently conflates them ("product 'MudbaseSDK' ... not found in package 'MudbaseSDK'",
        // even though the product plainly exists — verified against the sibling ecommerce/social
        // Swift ports, which hit this exact issue first). `../mudbase-sdk-swift` is a symlink
        // already committed at the monorepo root (`mudbase-showcase-marketplace/mudbase-sdk-swift
        // -> ../mudbase-sdk/swift`) that exists purely to give the dependency a distinct final
        // path segment. See README.md "Known limitations" for the full writeup.
        .package(name: "MudbaseSDK", path: "../mudbase-sdk-swift"),
    ],
    targets: [
        .executableTarget(
            name: "MudbaseShowcaseMarketplace",
            dependencies: [
                .product(name: "MudbaseSDK", package: "MudbaseSDK"),
            ],
            path: "Sources/MudbaseShowcaseMarketplace"
        ),
        // Standalone, headless verification against the real, live `cloud.mudbase.dev` project —
        // `@testable import` is the only way for a separate SPM target to reach this app's own
        // internal `Services`/`Networking`/`Models` types (Swift access control is per-module, not
        // per-package). Disabled by default — see `ManualLiveFlowTests.swift` — so a plain
        // `swift test` never makes network calls or writes real documents on its own.
        .testTarget(
            name: "ManualLiveFlowTests",
            dependencies: ["MudbaseShowcaseMarketplace"],
            path: "Tests/ManualLiveFlowTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
