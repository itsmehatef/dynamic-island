import AppKit

enum ScreenGeometry {
    static let fallbackNotchWidth: CGFloat = 200

    static func hasNotch(_ screen: NSScreen) -> Bool {
        screen.safeAreaInsets.top > 0
    }

    static func notchWidth(for screen: NSScreen) -> CGFloat {
        guard hasNotch(screen) else { return 0 }

        let leftWidth = screen.auxiliaryTopLeftArea?.width ?? 0
        let rightWidth = screen.auxiliaryTopRightArea?.width ?? 0
        let computed = screen.frame.width - leftWidth - rightWidth

        return computed > 0 ? computed : fallbackNotchWidth
    }
}
