import AppKit

enum ScreenGeometry {
    static let forceSpacerDefaultsKey = "ForceSpacerForDebugging"
    static let fallbackNotchWidth: CGFloat = 200

    static func hasNotch(_ screen: NSScreen) -> Bool {
        screen.safeAreaInsets.top > 0
    }

    static func shouldReserveSpace(for screen: NSScreen) -> Bool {
        hasNotch(screen) || UserDefaults.standard.bool(forKey: forceSpacerDefaultsKey)
    }

    static func notchWidth(for screen: NSScreen) -> CGFloat {
        guard shouldReserveSpace(for: screen) else { return 0 }
        guard hasNotch(screen) else { return fallbackNotchWidth }

        let leftWidth = screen.auxiliaryTopLeftArea?.width ?? 0
        let rightWidth = screen.auxiliaryTopRightArea?.width ?? 0
        let computed = screen.frame.width - leftWidth - rightWidth

        return computed > 0 ? computed : fallbackNotchWidth
    }

    static func notchFrame(on screen: NSScreen) -> NSRect {
        let height = NSStatusBar.system.thickness
        let width = notchWidth(for: screen)
        let x: CGFloat
        if hasNotch(screen), let leftArea = screen.auxiliaryTopLeftArea {
            x = leftArea.maxX
        } else {
            x = screen.frame.minX + (screen.frame.width - width) / 2
        }
        let y = screen.frame.maxY - height
        return NSRect(x: x, y: y, width: width, height: height)
    }
}
