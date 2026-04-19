# Dynamic Island

A small, open-source macOS utility that puts the MacBook's notch to work. Long-term the goal is to mirror iPhone's Dynamic Island — a useful, interactive zone around the notch. **v1 has a single, narrow goal: stop menu-bar status icons from being silently hidden behind the notch.**

## The problem v1 solves

On notched MacBooks, when you have enough third-party status items in the menu bar (Slack, Dropbox, 1Password, Docker, Zoom, display utilities, battery widgets…), macOS lets them flow under the notch area and simply hides them. No warning, no overflow indicator — they just disappear.

Dynamic Island plants an invisible, fixed-width `NSStatusItem` next to the notch. The system then lays out the rest of your icons around it, pushing the ones that would have been hidden back into view (into the left auxiliary menu-bar area or further right on the main area).

## Status

- **v1 (this):** reserve space adjacent to the notch. No UI inside the notch yet.
- **Future:** widgets/content in the notch (now-playing, drag-drop targets, notifications), preferences, launch-at-login.

## Requirements

- macOS 13 Ventura or later
- A MacBook with a notch (MacBook Pro 14"/16" 2021+, MacBook Air 13"/15" 2022+)
- Xcode 15 or later to build

On non-notched Macs, the app auto-disables and shows "Inactive — no notch detected" in its menu.

## Build & run

The repo ships as Swift sources plus an `Info.plist`. To build:

1. Open Xcode and create a new macOS **App** project named `DynamicIsland` (SwiftUI, Swift).
2. Replace the generated sources with the files in `DynamicIsland/`.
3. Replace the generated `Info.plist` with the one in `DynamicIsland/Info.plist` (or merge the `LSUIElement = YES` key into yours).
4. Set the deployment target to macOS 13.0.
5. Build and run (`⌘R`). The Dock will not show an icon — look for the tiny menu-bar icon.

An `.xcodeproj` is intentionally not committed yet; it's churn-prone and easy to regenerate. Packaging as a Swift Package or notarized release will come with v1.1.

## How it works

1. On launch, `ScreenGeometry` asks `NSScreen.main` whether `safeAreaInsets.top > 0` (the notch tell).
2. If there's a notch, it computes the notch width from `screen.frame.width − auxiliaryTopLeftArea.width − auxiliaryTopRightArea.width`.
3. `NotchBlocker` creates an `NSStatusItem` with `length = notchWidth + buffer`, gives its button a transparent image, and leaves its action unset.
4. `NSApplication.didChangeScreenParametersNotification` rebuilds the spacer when displays change.
5. A separate SwiftUI `MenuBarExtra` gives you a visible icon, a status line, and a Quit button.

## Contributing

Issues and PRs welcome — especially:

- Reports of edge cases on different notched hardware / external-display configurations.
- Better heuristics for spacer width vs. notch width.
- Ideas for v1.1 content inside the notch.

## License

MIT. See [LICENSE](LICENSE).
