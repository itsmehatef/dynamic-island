import AppKit

final class NotchBlocker {
    private var spacer: NSStatusItem?

    var isActive: Bool { spacer != nil }

    func refresh() {
        guard let screen = NSScreen.main else {
            teardown()
            return
        }

        guard ScreenGeometry.shouldReserveSpace(for: screen) else {
            teardown()
            return
        }

        let width = ScreenGeometry.notchWidth(for: screen) + 8
        install(
            width: width,
            showsDebugColor: UserDefaults.standard.bool(forKey: ScreenGeometry.forceSpacerDefaultsKey)
        )
    }

    func teardown() {
        if let spacer {
            NSStatusBar.system.removeStatusItem(spacer)
        }
        spacer = nil
    }

    private func install(width: CGFloat, showsDebugColor: Bool) {
        teardown()

        let item = NSStatusBar.system.statusItem(withLength: width)
        if let button = item.button {
            if showsDebugColor {
                button.wantsLayer = true
                button.layer?.backgroundColor = NSColor.systemPink.withAlphaComponent(0.75).cgColor
                button.layer?.cornerRadius = 4
                button.layer?.masksToBounds = true
                button.image = nil
            } else {
                button.image = Self.transparentImage
            }
            button.imagePosition = .imageOnly
            button.isEnabled = false
        }
        spacer = item
    }

    private static let transparentImage: NSImage = {
        let image = NSImage(size: NSSize(width: 1, height: 1))
        image.lockFocus()
        NSColor.clear.set()
        NSRect(x: 0, y: 0, width: 1, height: 1).fill()
        image.unlockFocus()
        image.isTemplate = true
        return image
    }()
}
