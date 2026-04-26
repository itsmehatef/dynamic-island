import AppKit

final class NotchOverlay {
    private var window: NSWindow?
    private var tracker: MenuBarTracker?
    private var trackerDisplayID: CGDirectDisplayID?

    func refresh(showsDebugColor: Bool) {
        guard showsDebugColor,
              let screen = NSScreen.main,
              ScreenGeometry.shouldReserveSpace(for: screen) else {
            teardown()
            return
        }

        // NSScreen.main returns a fresh Swift instance on every call, so an identity
        // (===) compare always fires. Compare the underlying CGDirectDisplayID instead.
        let id = NotchOverlay.displayID(of: screen)
        if id != trackerDisplayID {
            tracker?.stop()
            trackerDisplayID = id
            tracker = MenuBarTracker(screen: screen) { [weak self] menuBarFrame in
                self?.handleMenuBarUpdate(menuBarFrame)
            }
            tracker?.start()
        }
    }

    func teardown() {
        tracker?.stop()
        tracker = nil
        trackerDisplayID = nil
        window?.orderOut(nil)
        window = nil
    }

    private static func displayID(of screen: NSScreen) -> CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return (screen.deviceDescription[key] as? NSNumber)?.uint32Value ?? 0
    }

    private func handleMenuBarUpdate(_ menuBarFrame: NSRect?) {
        guard let screen = NSScreen.main,
              ScreenGeometry.shouldReserveSpace(for: screen) else {
            window?.orderOut(nil)
            return
        }
        guard let menuBarFrame else {
            window?.orderOut(nil)
            return
        }
        // x and width come from the static notch geometry; y and height mirror
        // the live menu bar so the overlay slides in lock-step with it.
        let staticNotch = ScreenGeometry.notchFrame(on: screen)
        let liveFrame = NSRect(
            x: staticNotch.origin.x,
            y: menuBarFrame.origin.y,
            width: staticNotch.width,
            height: menuBarFrame.height
        )
        present(frame: liveFrame)
    }

    private func present(frame: NSRect) {
        let w = window ?? makeWindow(frame: frame)
        window = w
        w.setFrame(frame, display: true)
        w.contentView?.layer?.backgroundColor = NSColor.systemPink.withAlphaComponent(0.75).cgColor
        // Window is at .statusBar level, so level guarantees it's above the menu bar
        // (.mainMenu). Plain orderFront is enough; orderFrontRegardless is loud and
        // unnecessary at this level.
        if !w.isVisible {
            w.orderFront(nil)
        }
    }

    private func makeWindow(frame: NSRect) -> NSWindow {
        let w = NSWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        w.isReleasedWhenClosed = false
        w.level = .statusBar
        w.collectionBehavior = [.canJoinAllSpaces, .stationary]
        w.backgroundColor = .clear
        w.isOpaque = false
        w.hasShadow = false
        w.ignoresMouseEvents = true
        let view = NSView(frame: NSRect(origin: .zero, size: frame.size))
        view.wantsLayer = true
        w.contentView = view
        return w
    }
}
