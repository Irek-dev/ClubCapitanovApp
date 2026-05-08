# AGENTS.md

## Project Stack

- `ClubKapitanovApp` is an internal iPad-only UIKit app for operating a rental shift.
- UI is built in Swift code without storyboards.
- Minimum iOS target is `16.0`; the Xcode target device family is iPad (`TARGETED_DEVICE_FAMILY = 2`).
- The project uses Swift 5 and an Xcode project, not Swift Package Manager.
- Current Xcode scheme and app target: `ClubKapitanovApp`.
- Data is currently in-memory. Repository protocols live in `Domain`, implementations live in `Data`.
- App architecture is layered:
  - `App`: launch, scene setup, DI container.
  - `Core`: design system, formatters, UIKit helpers.
  - `Domain`: entities, value objects, repository protocols, use cases.
  - `Data`: in-memory repositories and fixtures.
  - `Features`: user-facing flows.
- Feature modules follow VIP:
  - `ViewController` receives UI events and renders display models.
  - `Interactor` owns business actions and syncs state with repositories.
  - `Presenter` maps responses/state into view models.
  - `Router` handles navigation.
  - `Assembly` wires dependencies.
  - `Models` contains request/response/view model/state types.

## Key Product Flow

The working flow is:

`PIN login -> point selection -> open shift on iPad -> add shift participants -> rentals / fines / souvenir sales -> temporary report -> close shift -> save close report`

Important business rules:

- One point can have only one open shift at a time.
- The operational app is iPad-only. Do not add mobile/admin placeholder flows to `Features` or `App`.
- Admin users are not part of the current operational flow.
- Shift state belongs to `Shift`; employee participation in a shift belongs to `ShiftParticipant`, not `User`.
- Active rental orders must be completed before closing a shift.
- Historical entities must keep snapshot names, prices, tariffs, roles, and timestamps where later catalog/user changes could alter history.
- Money is represented by `Money` in kopecks. Do not replace it with raw `Int`, `Decimal`, or `Double` business calculations.
- One operation has one `PaymentMethod`.
- Close reports are immutable snapshots saved through `ReportRepository`.

## Build And Run Commands

List project targets and schemes:

```sh
xcodebuild -list -project ClubKapitanovApp.xcodeproj
```

Open the project for local iPad simulator/device runs:

```sh
open ClubKapitanovApp.xcodeproj
```

In Xcode, select the `ClubKapitanovApp` scheme and an iPad simulator or device, then run with `Cmd+R`.

Build the app without code signing, writing DerivedData to a writable temp directory:

```sh
xcodebuild \
  -project ClubKapitanovApp.xcodeproj \
  -scheme ClubKapitanovApp \
  -configuration Debug \
  -destination generic/platform=iOS \
  -derivedDataPath /private/tmp/ClubKapitanovDerived \
  CODE_SIGNING_ALLOWED=NO \
  build
```

There is currently no unit test target. When changing business calculations, run the full build above. If a Swift file list already exists from a recent Xcode build, a fast type-check can also be run with:

```sh
swiftc -typecheck \
  @/tmp/ClubKapitanovDerived/Build/Intermediates.noindex/ClubKapitanovApp.build/Debug-iphoneos/ClubKapitanovApp.build/Objects-normal/arm64/ClubKapitanovApp.SwiftFileList \
  -module-name ClubKapitanovApp \
  -sdk /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk \
  -target arm64-apple-ios16.0 \
  -swift-version 5 \
  -default-isolation=MainActor
```

Prefer the full `xcodebuild` command as the source of truth.

## Code Rules

- Keep `Domain` free of `UIKit`, Firebase, formatters, and view models.
- Keep repository protocols in `Domain/Repositories`; put concrete storage implementations under `Data`.
- Use `AppDIContainer` as the single place that selects concrete repository implementations.
- Do not hardcode catalogs, prices, rental types, souvenir products, or fine templates in view controllers.
- Use `Money`, `Money.sum`, `+`, and `multiplied(by:)` for money arithmetic.
- Put ruble display formatting in UI/presentation code through existing formatters.
- Keep navigation decisions in routers or assemblies, not in view controllers.
- For large workspace mappings and report text, use `ShiftWorkspaceContentFactory` rather than expanding view controllers or UIKit views.
- `ShiftWorkspaceInteractor` may hold mutable screen state, but after business operations it must persist the updated shift through `ShiftRepository`.
- Use existing `UIView+Pin` helpers consistently when editing UIKit layout. Avoid mixing large raw Auto Layout blocks into files that already use the helper style.
- Keep UI code code-only; do not introduce storyboards.
- Add snapshot fields to historical entities when live catalog/user data could change later.
- Avoid broad refactors while implementing a feature. Keep changes scoped to the requested behavior and the surrounding local pattern.

## Self-Check Instructions

Before finishing a change:

- Re-read the changed flow from UI event to interactor to presenter/factory to view rendering.
- Confirm affected business rules still hold, especially active-rental close blocking, shift participant history, payment method totals, and close report snapshot behavior.
- Check that report totals use shared `Money` arithmetic and do not duplicate ad hoc money calculations.
- Verify UI text and empty states are still coherent in the current iPad operational flow.
- Run:

```sh
xcodebuild \
  -project ClubKapitanovApp.xcodeproj \
  -scheme ClubKapitanovApp \
  -configuration Debug \
  -destination generic/platform=iOS \
  -derivedDataPath /private/tmp/ClubKapitanovDerived \
  CODE_SIGNING_ALLOWED=NO \
  build
```

- If full build is blocked by local Xcode/CoreSimulator permissions, record the exact failure and at least run Swift type-check when possible.
- Note that unit tests are not available until a test target is added.

## RTK usage for Codex

Use RTK for shell commands that may produce verbose output. Prefer compact RTK commands during project analysis, debugging, testing, code review, and architecture exploration.

Preferred commands:
- Use `rtk ls .` instead of `ls -la` or `tree`.
- Use `rtk read <file>` instead of `cat <file>` for source files and configuration files.
- Use `rtk grep "<pattern>" .` instead of raw recursive `grep` or `rg` for repository search.
- Use `rtk git status`, `rtk git diff`, and `rtk git log` instead of raw git commands.
- Use `rtk deps` to summarize dependencies.
- Use RTK wrappers for tests, linting, and type checks when available.

iOS-specific guidance:
- Use RTK for reading project structure, Swift files, Package.swift, Podfile, project configuration, and git state.
- Do not run `xcodebuild`, simulator commands, signing, archive, fastlane, TestFlight, App Store upload, CocoaPods install/update, or deployment commands without explicit user approval.
- Do not read or print secrets, certificates, provisioning profiles, private keys, `.env` files, tokens, or credentials.
- For architecture work, first inspect project structure with RTK, then propose a plan before editing code.

When not to use RTK:
- Do not use RTK when exact byte-for-byte output is required.
- Do not use RTK for commands involving secrets or credentials.
- Do not use RTK for deploy, publish, production migration, infrastructure mutation, or destructive commands.
- If full raw output is needed for debugging, explain why before running the raw command.

Behavior:
- During project analysis, use RTK first.
- Before modifying application code, summarize the files you plan to change.
- After modifying code, ask before running heavy iOS builds or tests.

@RTK.md
