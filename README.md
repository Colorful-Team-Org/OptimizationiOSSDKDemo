# Optimization iOS Demo

Two iOS demo apps that prove the [Contentful Optimization iOS SDK](https://github.com/contentful/optimization) can power a real app with Contentful personalization. Both apps are functionally and visually identical to the React Native reference app [`ContentfulDemoOptimized`](https://github.com/contentful/ReactNativeOptimizationDemo).

- **SwiftUIDemo** — built with SwiftUI, uses the SDK's SwiftUI views (`OptimizationRoot`, `OptimizedEntry`, etc.)
- **UIKitDemo** — built with UIKit, uses the SDK's core client API directly

Each app lives in its own directory with its own `xcodeproj` and imports the SDK locally via Swift Package Manager from `../../optimization/packages/ios/ContentfulOptimization`.

## Repo layout

```
optimization-ios-demo/
├── SwiftUIDemo/
│   ├── project.yml                # xcodegen spec
│   ├── SwiftUIDemo.xcodeproj/
│   ├── SwiftUIDemo.xcworkspace/   # workspace for editing SDK + app together
│   └── SwiftUIDemo/
├── UIKitDemo/
│   ├── project.yml
│   ├── UIKitDemo.xcodeproj/
│   ├── UIKitDemo.xcworkspace/
│   └── UIKitDemo/
├── ios-app-spec.md                # high-level spec
└── uikit-demo-plan.md             # detailed UIKit implementation plan
```

## Prerequisites

- Xcode 26.4 (iPhone 17 Pro simulator, iOS 26.4)
- [xcodegen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- Node 20+ and [pnpm](https://pnpm.io) (`npm install -g pnpm`) — the SDK ships a JS-backed runtime bridge that has to be built before the iOS app compiles

## Setup

After cloning, run:

```sh
./scripts/setup.sh
```

This clones the [Optimization SDK](https://github.com/contentful/optimization) into `./optimization` (gitignored), installs its JS dependencies, builds the JSC bridge, and regenerates both Xcode projects. Re-running is idempotent.

To pull the latest SDK changes later:

```sh
./scripts/setup.sh --update
```

Override the SDK ref or repo URL via env vars when needed:

```sh
SDK_REF=main ./scripts/setup.sh
SDK_REPO=git@github.com:your-fork/optimization.git ./scripts/setup.sh
```

The SDK lives inside the demo repo at `./optimization`, so you can open its Swift sources from the Xcode workspace and edit them alongside the demo.

## Running an app

From either `SwiftUIDemo/` or `UIKitDemo/`:

```sh
xcodegen generate
xcodebuild \
  -project SwiftUIDemo.xcodeproj \
  -scheme SwiftUIDemo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' \
  build
```

Open the `.xcworkspace` to edit SDK Swift code and the demo app side-by-side.

## Configuration

Both apps use `Config.swift` for Contentful + Optimization credentials. Fields:

- `contentfulSpaceId`, `contentfulAccessToken`, `contentfulEnvironment`
- `optimizationClientId`, `optimizationEnvironment`

## What each app demonstrates

Same user-facing behavior in both:

1. Home screen with a list of blog posts fetched from Contentful
2. CTA banner (personalized via Optimization SDK) inserted after the first post
3. Blog post detail view with rich text body
4. Pull-to-refresh on the home list
5. Floating debug button (bottom-right) opening the Optimization Preview Panel
6. Screen / view / click tracking via the Optimization client

### SwiftUI vs UIKit integration

| Concern | SwiftUI | UIKit |
|---|---|---|
| Client setup | `OptimizationRoot` wrapper view | Manual `OptimizationClient.initialize()` in `SceneDelegate` |
| Personalized content | `OptimizedEntry` view | `client.personalizeEntry()` + manual `trackView` / `trackClick` |
| Screen tracking | `.trackScreen(name:)` modifier | `client.screen(name:)` in `viewDidAppear` |
| Rich text | SwiftUI `Text` composition | `NSAttributedString` in `UITextView` |
| Preview panel | `PreviewPanelOverlay` | Native `UIButton` FAB + `UIHostingController` hosting `PreviewPanelContent` |

## Implementation notes

- `ContentfulService.swift` uses raw `URLSession` calls against the Contentful CDN API with manual link resolution — the resulting `[String: Any]` dictionaries are the format the Optimization SDK expects.
- Rich text documents arrive as nested `[String: Any]` with `nodeType`, `content`, `value`, and `marks` keys.
- CTA hero image URL lives at `fields.media.fields.image.fields.file.url` and is protocol-relative — prefix with `https:`.
- `OptimizationClient` is `@MainActor`; call it from lifecycle methods or wrap in `Task { @MainActor in ... }`.
- The local SPM package path in each `project.yml` is `../optimization/packages/ios/ContentfulOptimization` (resolved against the SDK checkout that `./scripts/setup.sh` creates).
