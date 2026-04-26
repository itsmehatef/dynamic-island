import AppKit

final class NotchOverlay {
    private var window: NSWindow?

    func refresh(showsDebugColor: Bool) {
        guard let screen = NSScreen.main, ScreenGeometry.shouldReserveSpace(for: screen) else {
            teardown()
            return
        }

        guard showsDebugColor else {
            teardown()
            return
        }

        let frame = ScreenGeometry.notchFrame(on: screen)
        present(frame: frame, color: NSColor.systemPink.withAlphaComponent(0.75))
    }

    func teardown() {
        window?.orderOut(nil)
        window = nil
    }

    private func present(frame: NSRect, color: NSColor) {
        let w: NSWindow
        if let existing = window {
            w = existing
        } else {
            w = NSWindow(
                contentRect: frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            w.isReleasedWhenClosed = false
            w.level = .statusBar
            w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            w.backgroundColor = .clear
            w.isOpaque = false
            w.hasShadow = false
            w.ignoresMouseEvents = true
            let view = NSView(frame: NSRect(origin: .zero, size: frame.size))
            view.wantsLayer = true
            w.contentView = view
            window = w
        }
        w.setFrame(frame, display: true)
        w.contentView?.layer?.backgroundColor = color.cgColor
        w.orderFrontRegardless()
    }
}
