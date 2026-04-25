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
            button.image = showsDebugColor ? nil : Self.transparentImage
            button.imagePosition = .imageOnly
            button.isEnabled = false

            if showsDebugColor {
                // Add overlay into the status item window's contentView so the colored
                // area fills the full menu bar height. The button's own frame is
                // inset, so coloring its layer leaves visible top/bottom gaps.
                DispatchQueue.main.async { [weak button] in
                    guard let contentView = button?.window?.contentView else { return }
                    let overlay = NSView(frame: contentView.bounds)
                    overlay.autoresizingMask = [.width, .height]
                    overlay.wantsLayer = true
                    overlay.layer?.backgroundColor = NSColor.systemPink.withAlphaComponent(0.75).cgColor
                    contentView.addSubview(overlay, positioned: .below, relativeTo: button)
                }
            }
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
