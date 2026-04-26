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
        install(width: width)
    }

    func teardown() {
        if let spacer {
            NSStatusBar.system.removeStatusItem(spacer)
        }
        spacer = nil
    }

    private func install(width: CGFloat) {
        teardown()

        let item = NSStatusBar.system.statusItem(withLength: width)
        if let button = item.button {
            button.image = Self.transparentImage
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
